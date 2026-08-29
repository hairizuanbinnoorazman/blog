+++
title = "PostgreSQL MVCC and Autovacuum Learnings"
description = "A practical look at dead tuples, autovacuum, table and index growth, ordinary VACUUM, and VACUUM FULL."
tags = [
    "postgresql",
    "database",
    "performance",
]
date = "2026-07-31"
categories = [
    "database",
]
+++

PostgreSQL can let readers and writers work concurrently because of multi-version concurrency control, or MVCC. The trade-off is that an update usually creates a new tuple version instead of replacing the old one in place. A delete also makes a tuple obsolete without immediately removing its storage.

I understood that description in theory, but I wanted to see the operational consequences. I extended my [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab) with two identical tables under sustained update traffic: one with aggressive autovacuum settings and one with autovacuum disabled.

The experiment made the relationship between MVCC, autovacuum, and bloat much clearer.

## A working mental model

The lifecycle I now keep in mind is:

```text
UPDATE or DELETE
  -> MVCC leaves an obsolete tuple version
  -> no active snapshot needs that version anymore
  -> VACUUM marks its space as reusable
  -> future writes can reuse that space
```

Autovacuum is the background system that decides when tables need `VACUUM` and `ANALYZE`. Vacuuming removes visibility of obsolete row versions and makes their space available for reuse. An ordinary vacuum generally does not return that allocated space to the operating system.

That last distinction matters. Dead tuples and bloat are related, but they are not interchangeable measurements. `n_dead_tup` is an estimate of obsolete tuples. Bloat is inefficient use of the pages already allocated to a table or index. A table can report few dead tuples immediately after vacuum while its file remains much larger than its live data requires.

## The comparison

The lab created two tables with 200,000 live rows each:

| Table | Maintenance policy |
|---|---|
| `mvcc_healthy` | Aggressive table-level autovacuum settings |
| `mvcc_unvacuumed` | Autovacuum deliberately disabled |

Each transaction updated the same kind of row in both tables. Both tables had an index on `updated_at`, and every transaction changed that column. This intentionally prevented HOT updates, making index-version maintenance visible. It is an educational stress case, not a schema recommendation.

The workload ran at a target of 500 transactions per second and completed about 3.05 million updates on each table.

## What happened under write churn

The healthy table showed the behavior I hoped to see. Its estimated dead tuples rose until vacuum thresholds were crossed, then fell when autovacuum ran. This repeated as a sawtooth pattern. The heap settled into reusing its allocated space instead of growing with every update.

The table without autovacuum behaved very differently. Its dead-tuple estimate continued to climb, and both its heap and indexes became much larger.

| Measurement | Healthy autovacuum | Autovacuum disabled |
|---|---:|---:|
| Updates | 3,049,253 | 3,049,252 |
| Autovacuums during load | 102 | 0 |
| Maximum estimated dead tuples | 30,347 | 3,049,252 |
| Final heap size | 40 MiB | 93 MiB |
| Final index size | 33 MiB | 78 MiB |
| Final total size | 73 MiB | 171 MiB |

The same logical dataset occupied about 2.34 times as much allocated space without autovacuum. That is not only a disk-capacity issue. Larger heaps and indexes increase the working set that must pass through memory and storage, so neglecting maintenance can eventually turn into query latency and I/O pressure.

Autovacuum did not keep every structure at its minimum possible size. The healthy table's indexes still grew from roughly 9 MiB to 33 MiB. This was an important correction to my expectations: successful autovacuum bounds obsolete data and enables reuse, but it does not promise perfectly compact tables and indexes.

## Ordinary VACUUM reuses space

After pausing writes, I re-enabled autovacuum on the unvacuumed table and ran:

```sql
VACUUM (VERBOSE, ANALYZE) mvcc_unvacuumed;
```

The vacuum finished in about 2.06 seconds of database time. It removed more than three million dead index item identifiers, reset the dead-tuple estimate to zero, and generated about 54 MB of WAL. However, total allocated relation size remained 171 MiB.

This is expected. Ordinary vacuum made the free space available for later PostgreSQL writes; it did not compact the relation file for the operating system.

There was another useful surprise. PostgreSQL reported only 4,495 heap tuples physically removed by vacuum even though the earlier estimate showed about 3.05 million dead tuples. Normal page pruning during updates had already removed many obsolete heap versions, while millions of dead index references still needed maintenance. It showed why `n_dead_tup` should be treated as a maintenance signal rather than an exact byte count of bloat.

## VACUUM FULL is a different operation

I then ran `VACUUM FULL` with writes still paused. It rewrote the table and indexes:

| Measurement | Before | After `VACUUM FULL` |
|---|---:|---:|
| Heap | 93 MiB | 20 MiB |
| Indexes | 78 MiB | 8.8 MiB |
| Total | 171 MiB | 28 MiB |
| Live rows | 200,000 | 200,000 |

This did return most of the unused allocation to the operating system. The cost is that `VACUUM FULL` performs a complete rewrite and takes an `ACCESS EXCLUSIVE` lock. It is therefore not a substitute for healthy routine vacuuming on a busy production table.

The better objective is usually prevention: allow autovacuum to keep up, make updates cheaper, and investigate unusual growth before emergency compaction becomes necessary.

## Index choices affect update cost

The experiment updated an indexed column specifically to force index work. In a normal schema, an update that does not change any indexed columns may qualify for a HOT update, allowing PostgreSQL to avoid adding new index entries when page conditions permit.

This connects directly to my earlier indexing lesson. Every index added to speed up reads also becomes part of the write and vacuum workload. Unnecessary indexes do not merely occupy space; they increase the maintenance created by each update.

Useful counters to inspect include:

```sql
SELECT relname,
       n_live_tup,
       n_dead_tup,
       n_tup_upd,
       n_tup_hot_upd,
       autovacuum_count,
       last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

I would look at those statistics alongside table and index sizes, transaction age, vacuum progress, application latency, and I/O. A single metric cannot explain the whole condition of a relation.

## Long transactions can hold cleanup back

Vacuum can only remove a tuple version after no active snapshot can still see it. A long-running transaction may therefore prevent cleanup even when autovacuum is configured and running.

This particular experiment did not have an old transaction blocking vacuum; the sampled oldest-transaction age stayed at zero. That is useful because it isolates the effect of disabled maintenance, but it also means the run does not demonstrate long-snapshot interference. I would treat that as a separate experiment rather than claim that the current results prove it.

In a real incident, I would check active transactions and their age before simply making autovacuum more aggressive. Otherwise I might tune the worker without removing the condition that prevents it from making progress.

## What I am taking away

My biggest misconception was treating vacuum as a periodic disk-shrinking task. Ordinary vacuum is mainly continuous space-reuse and visibility maintenance that PostgreSQL needs because of MVCC. Autovacuum is not optional housekeeping for a write-heavy database; it is part of its normal operation.

The practical lessons are:

- Expect updates and deletes to create cleanup work.
- Watch trends in dead tuples, relation sizes, and vacuum history together.
- Remember that ordinary `VACUUM` enables internal reuse but normally does not shrink files.
- Avoid routine reliance on `VACUUM FULL` because it rewrites and locks the table.
- Review indexes as part of write-performance and vacuum analysis.
- Investigate long-running transactions when vacuum cannot clear old versions.
- Tune autovacuum per high-churn table when the defaults do not keep up, then validate the result under representative load.

Seeing two identical logical datasets diverge from 73 MiB to 171 MiB made the cost of delayed cleanup concrete. MVCC gives PostgreSQL excellent concurrency, but the old versions it creates need space, time, and a maintenance process that is allowed to do its job.

## Reference

- [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab)
