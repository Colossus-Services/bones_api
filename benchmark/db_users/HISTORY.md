# Benchmark history

Results of `bin/db_users_benchmark.dart`, newest first. Each entry is the
`--markdown` output of a run, pasted as printed; add a short note under it
when something about the run needs context (a change being measured, an
unusual setup).

Numbers are only comparable between entries from **the same machine**, DB and
settings. See [README.md](README.md#reading-the-results) for how to read them
and [README.md](README.md#recording-a-result) for how to add an entry.

A commit marked `(modified)` was run from a working tree with uncommitted
changes on top of that commit.

---

### 2026-10-03 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`84102a8 (modified)`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 12143 | 82.4 | 78 | 99 | 148 |
| `user/byEmail` | 13458 | 74.3 | 71 | 86 | 134 |
| `user/byState (join, limit 20)` | 1477 | 676.9 | 651 | 760 | 832 |
| `user/list (page of 20)` | 1516 | 659.7 | 641 | 727 | 786 |
| `user/count` | 121357 | 8.2 | 8 | 9 | 11 |
| `authenticate (login)` | 12311 | 81.2 | 77 | 94 | 154 |
| `user/register` | 7023 | 142.4 | 126 | 180 | 835 |
| `user/update` | 6871 | 145.5 | 129 | 217 | 362 |
| `user/remove` | 10514 | 95.1 | 84 | 145 | 284 |

First recorded run, made while creating the benchmark (uncommitted tree on
top of `84102a8`).

### 2026-10-03 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`84102a8 (modified)`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 2378 | 420.5 | 407 | 500 | 587 |
| `user/byEmail` | 993 | 1007.2 | 1001 | 1563 | 1670 |
| `user/byState (join, limit 20)` | 611 | 1637.5 | 1616 | 1764 | 1855 |
| `user/list (page of 20)` | 421 | 2373.9 | 2362 | 2510 | 2638 |
| `user/count` | 192172 | 5.2 | 5 | 6 | 7 |
| `authenticate (login)` | 960 | 1041.8 | 1037 | 1645 | 1811 |
| `user/register` | 561 | 1783.1 | 1770 | 2349 | 2827 |
| `user/update` | 555 | 1803.1 | 1726 | 2253 | 2811 |
| `user/remove` | 207 | 4840.9 | 4796 | 5237 | 5626 |

Slower than SQLite on everything but `count`, and slower with more rows: a
short trial run with 200 users gave `byId` ~250 us and `byEmail` ~290 us.
`DBSQLMemoryAdapter` scans tables for non-ID conditions and joins (see
[`../README.md`](../README.md#where-the-db-and-json-time-goes)); `byId`
growing too suggests the `roles` relationship is resolved by a similar scan
(not profiled).
