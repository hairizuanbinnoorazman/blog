+++
title = "UUIDv4, UUIDv7, and Avoiding Deep OFFSET Pagination"
description = "UUIDv7 improves ordering and locality, but keyset pagination—not the UUID version—is the main fix for deep OFFSET queries."
tags = [
    "postgresql",
    "database",
    "uuid",
    "performance",
]
date = "2026-08-01"
categories = [
    "database",
]
+++

I initially thought UUIDv7 would be very important for avoiding expensive `OFFSET` pagination. UUIDv7 is time ordered, while UUIDv4 is random, so it seemed natural that changing the identifier would be the key to fast pagination.

After building a comparison in my [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab), my view became more nuanced. UUIDv7 has useful locality and ordering properties, but it is not what removes the cost of a deep offset. Keyset pagination does that, and keyset pagination can also work with UUIDv4.

The article [Your Database Is Slow Because You’re Using UUIDs (And How I Made It 500x Faster)](https://medium.com/@jamauriceholt.com/your-database-is-slow-because-youre-using-uuids-and-how-i-made-it-500x-faster-e57270d9b294) prompted this investigation. Rather than assume the same headline result would apply to my application, I wanted to separate three questions:

1. Does UUIDv7 improve PostgreSQL index and heap locality?
2. Does UUIDv7 fix deep `OFFSET` pagination?
3. Can UUIDv4 still use an efficient alternative to `OFFSET`?

## Why UUIDv7 is attractive

UUIDv4 values are effectively random. They are excellent identifiers, but new values are distributed throughout the primary-key index. Their sort order also has no relationship to creation time.

UUIDv7 includes a Unix-epoch timestamp in its high-order bits. Newly generated values therefore tend to sort together and in approximate creation order. For a database, that can mean better insertion locality, fewer disruptive B-tree page splits, a more compact index, and less scattered access when ID order aligns with heap insertion order.

That makes UUIDv7 a promising default for many new systems, but two qualifications matter. It gives approximate chronological order rather than a strict global event order, and it does not change the fundamental behavior of `OFFSET`.

## OFFSET still walks past rows

Consider a page near the end of a 250,000-row table:

```sql
SELECT id, payload, created_at
FROM uuid_study_v7
ORDER BY id
LIMIT 100 OFFSET 225000;
```

Even with a UUIDv7 primary-key index, PostgreSQL must advance past 225,000 entries before returning the next 100. UUIDv7 may make those visits cheaper because the index and heap have better locality, but the amount of work still grows with page depth.

The equivalent UUIDv4 query has the same algorithmic problem. Its random physical layout may add more scattered buffer access on top of that work.

## Keyset pagination changes the work

Keyset pagination keeps the last value from the previous page and asks for rows after it:

```sql
SELECT id, payload, created_at
FROM uuid_study_v7
WHERE id > $cursor
ORDER BY id
LIMIT 100;
```

PostgreSQL can seek into the B-tree at `$cursor` and read only the next page. The work is related to page size rather than how deep the user has travelled.

The important realization is that PostgreSQL can compare and index UUIDv4 values too:

```sql
SELECT id, payload, created_at
FROM uuid_study_v4
WHERE id > $cursor
ORDER BY id
LIMIT 100;
```

This is also efficient and stable. Its presentation order is random rather than chronological, but it proves that UUIDv7 is not required merely to avoid `OFFSET`.

## What the local comparison showed

I loaded two tables with 250,000 rows each. They had the same schema and payload; the intentional difference was UUIDv4 versus UUIDv7 primary keys. I then measured a 100-row page at offset 225,000 and an equivalent keyset page over 50 warm-cache runs.

| Measurement | UUIDv4 | UUIDv7 |
|---|---:|---:|
| Bulk COPY throughput | 502,176 rows/s | 586,935 rows/s |
| Primary-key index size | 9,863,168 B | 7,905,280 B |
| ID/heap physical correlation | -0.006 | 1.000 |
| Deep OFFSET p50 | 60.084 ms | 14.338 ms |
| Keyset p50 | 0.496 ms | 0.397 ms |

UUIDv7 did provide meaningful advantages in this test. Its primary-key index was about 20% smaller, bulk loading was about 17% faster, and its deep-offset query was about 4.2 times faster than UUIDv4.

But the query plans revealed the more important result:

| Query | Rows visited | Shared buffers | Plan execution time |
|---|---:|---:|---:|
| UUIDv4 OFFSET 225,000 | 225,100 | 226,130 | 70.492 ms |
| UUIDv7 OFFSET 225,000 | 225,100 | 5,655 | 23.362 ms |
| UUIDv4 keyset | 100 | 104 | 0.118 ms |
| UUIDv7 keyset | 100 | 6 | 0.045 ms |

Both offset queries still visited 225,100 index entries. UUIDv7 made that traversal much more cache-friendly, but keyset pagination reduced the visit count to the 100 rows actually requested for both UUID versions.

In the repeated timings, UUIDv4 keyset pagination was about 121 times faster than UUIDv4 deep-offset pagination. UUIDv7 keyset was about 36 times faster than its deep-offset counterpart. The exact ratios are not portable production promises; the query-shape result is the part that generalizes.

## Chronological UUIDv4 pagination is still possible

Ordering directly by a UUIDv4 primary key is arbitrary. Most products want a newest-first or oldest-first feed instead. UUIDv4 can still support this with an immutable creation timestamp and the UUID as a unique tie-breaker:

```sql
CREATE INDEX items_created_id_idx
ON items (created_at DESC, id DESC);
```

The continuation query becomes:

```sql
SELECT id, payload, created_at
FROM items
WHERE (created_at, id) < ($cursor_created_at, $cursor_id)
ORDER BY created_at DESC, id DESC
LIMIT 100;
```

The compound comparison handles rows that share the same timestamp. The client cursor carries both values, preferably encoded as an opaque token rather than exposing the storage contract directly.

This was the alternative approach I had overlooked. Even if an existing table uses UUIDv4, there is no need to migrate every identifier to UUIDv7 just to stop using a deep offset.

## UUIDv7 still adds value

UUIDv7 remains useful when approximate creation order is the desired order. It can combine identity, chronological locality, and a single-field cursor:

```sql
SELECT id, payload, created_at
FROM items
WHERE id < $cursor
ORDER BY id DESC
LIMIT 100;
```

It also gives newly generated IDs more predictable placement during an ongoing traversal. In the lab's live-insert simulation, about half of newly generated UUIDv4 values sorted behind a cursor that had already been passed. All UUIDv7 values generated later by the same process sorted ahead of the cursor.

That does not make UUIDv7 a strict distributed clock. Separate generators, clock skew, and values created within the same millisecond can weaken exact event ordering. When business correctness requires strict chronological semantics, I would use an explicit immutable ordering field plus a unique tie-breaker even if the primary key is UUIDv7.

## Choosing between the approaches

| Requirement | Practical choice |
|---|---|
| Fast continuation in any stable order | UUIDv4 or UUIDv7 with keyset pagination |
| Approximate chronological order with a one-field cursor | UUIDv7 keyset pagination |
| Chronological results from an existing UUIDv4 table | Keyset on `(created_at, id)` |
| Strict business sequence | A dedicated sequence or immutable ordering key with a tie-breaker |
| Direct arbitrary page-number access | `OFFSET`, accepting work that grows with page depth |

Keyset pagination has a product trade-off: it is designed for next/previous traversal, not jumping directly to page 2,251. That is normally a good fit for feeds, APIs, and infinite scrolling, but an administration screen that truly needs arbitrary numbered pages may still choose `OFFSET` and accept its cost.

## What I am taking away

My original thought was directionally right but assigned too much responsibility to the identifier. UUIDv7 can improve insertion and read locality, reduce index size, and provide approximate time order. Those are worthwhile properties.

However, UUIDv7 does not by itself avoid deep `OFFSET`. The main optimization is changing from positional pagination to a seekable cursor. UUIDv4 can do that efficiently in arbitrary ID order, or in chronological order with a composite `(created_at, id)` cursor and matching index.

So I would consider UUIDv7 for a new schema, especially when time-oriented IDs simplify the application. For an existing UUIDv4 schema, I would first change the pagination query and measure it before considering an identifier migration. The query design is the larger lever.

## References

- [PostgreSQL Load Lab](https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/postgres-load-lab)
- [Your Database Is Slow Because You’re Using UUIDs (And How I Made It 500x Faster)](https://medium.com/@jamauriceholt.com/your-database-is-slow-because-youre-using-uuids-and-how-i-made-it-500x-faster-e57270d9b294)
