+++
title = "Initial PostgreSQL Index Optimization Lessons"
description = "What I learned from matching PostgreSQL indexes to real query shapes and checking the result with EXPLAIN ANALYZE."
tags = [
    "postgresql",
    "database",
    "performance",
]
date = "2026-07-01"
categories = [
    "database",
]
+++

I built a small Go CRUD service to learn where a PostgreSQL-backed application starts to slow down. The service manages companies, users, and inventory, while a separate load generator creates a repeatable mixture of reads and writes.

My first lesson was simple: an index is useful when it matches a query that the application actually runs. Adding indexes to columns because they look important is not optimization. The useful cycle is to find a slow query, inspect its execution plan, make one change, and measure the same query again.

The code and scripts for these experiments are in the [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab).

## Start with the query

One of the application's list queries looks like this:

```sql
SELECT id, name, created_at, updated_at
FROM companies
ORDER BY created_at DESC
LIMIT 50;
```

Without an index on `created_at`, PostgreSQL has to find the rows, sort them into descending creation order, and only then return the first 50. `LIMIT` reduces the number of rows returned to the application, but it does not automatically make all the work before the limit disappear.

The matching index is:

```sql
CREATE INDEX companies_created_at_idx
ON companies (created_at DESC);
```

The users and inventory endpoints have the same unfiltered ordering, so the lab adds equivalent indexes to those tables:

```sql
CREATE INDEX users_created_at_idx
ON users (created_at DESC);

CREATE INDEX inventory_created_at_idx
ON inventory (created_at DESC);
```

This lets PostgreSQL walk the index in the order the query needs and stop once it has enough rows. The important part is not merely that `created_at` appears in both places. The index supports the complete access pattern: ordered retrieval followed by a small limit.

## Measure the plan, not the feeling

I used `EXPLAIN (ANALYZE, BUFFERS)` before and after adding the company index:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, name, created_at, updated_at
FROM companies
ORDER BY created_at DESC
LIMIT 50;
```

On a local dataset of about 27,000 companies, the plan changed from a sequential scan plus a top-N sort to an index scan.

| Measurement | Before | After |
|---|---:|---:|
| Execution time | 3.767 ms | 0.101 ms |
| Shared buffers | 406 | 51 |
| Main plan shape | Sequential scan and sort | Index scan |

The exact timings are specific to this machine, dataset, and cache state. The reusable finding is the combination of evidence: the plan changed as intended, far fewer buffers were touched, and execution time fell for the same query against the same data.

An index existing in the schema is not proof that it helps. PostgreSQL might still choose a sequential scan when a table is small, when a predicate returns much of the table, or when statistics do not represent the current data. If the planner does not select the new index, I should first ask why instead of trying to force it.

Running `ANALYZE`, checking how selective the query is, and testing with a realistic dataset are better next steps.

## Column order follows the access pattern

The inventory endpoint also supports listing items within one company:

```sql
SELECT id, company_id, sku, name, quantity, price_cents,
       created_at, updated_at
FROM inventory
WHERE company_id = $1
ORDER BY updated_at DESC
LIMIT 100;
```

For that query, an index only on `company_id` can locate the company's rows, but PostgreSQL may still need to sort them by `updated_at`. A more useful index is:

```sql
CREATE INDEX inventory_company_updated_idx
ON inventory (company_id, updated_at DESC);
```

The leading column supports the equality filter and the next column supplies the required order. This was a helpful way to think about multi-column indexes: their column order should follow how the query narrows and orders its results.

Foreign-key indexes are a related concern. PostgreSQL does not automatically create an index on every referencing column. Indexing `users.company_id` and `inventory.company_id` can help joins and parent-row updates or deletes, but those indexes still have a cost.

## Indexes are not free

Every additional index consumes storage and has to be maintained when data changes. Inserts may add an entry to several index structures. Updates may need new index entries, and deletes leave cleanup work for vacuum. More indexes can therefore improve reads while making writes, vacuuming, backups, and cache usage more expensive.

That leads to a more disciplined workflow:

1. Reproduce a representative workload.
2. Find expensive statements using application metrics and `pg_stat_statements`.
3. Run `EXPLAIN (ANALYZE, BUFFERS)` for the exact query.
4. Add one index that matches its filter and ordering.
5. Repeat the same measurement with the same data and load.
6. Check write latency and storage as well as read latency.

This also prevents me from confusing database time with total HTTP latency. If HTTP latency rises while database query latency stays flat, the bottleneck may instead be the application, connection-pool waiting, the network, or the load generator itself.

## An index does not fix deep OFFSET pagination

The list endpoints initially use `LIMIT` and `OFFSET`. An ordering index helps, but a deep page still requires PostgreSQL to walk past the preceding entries:

```sql
SELECT id, name, created_at
FROM companies
ORDER BY created_at DESC
LIMIT 50 OFFSET 100000;
```

The index improves how those rows are visited; it does not make the first 100,000 entries free. If deep pages become a measured problem, keyset pagination is the next design to consider:

```sql
SELECT id, name, created_at
FROM companies
WHERE (created_at, id) < ($1, $2)
ORDER BY created_at DESC, id DESC
LIMIT 50;
```

That query needs a matching index such as `(created_at DESC, id DESC)`. It seeks from the previous cursor rather than recounting all earlier rows.

## What I am taking away

My initial view of PostgreSQL optimization was too focused on whether a table had indexes. The better question is whether a specific index allows PostgreSQL to do less work for a real, important query.

The most convincing optimization was not the approximately 37-times lower local execution time by itself. It was seeing the scan and sort become an ordered index scan, watching shared-buffer use fall, and knowing why the new plan fit the application's request. That is the pattern I want to repeat before reaching for database configuration changes or a larger server.

## Reference

- [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab)
