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

## Progression

ops/sec per operation (higher is better), one column per date, oldest
first, from the entries below; in parentheses, the change from the
previous date. A date with more than one run shows its
last one (2026-10-03: the optimized runs at `98cc744 (modified)`; the
first runs of that day are in their entries). When adding an entry, add
its date's column here too.

### `memory`

| Operation | 2026-10-03 | 2026-10-13 | 2026-10-14 | 2026-10-15 |
|---|--:|--:|--:|--:|
| `user/byId` | 25303 | 30312 (+19.8%) | 30937 (+2.1%) | 35186 (+13.7%) |
| `user/byEmail` | 1407 | 1449 (+3.0%) | 1437 (-0.8%) | 1478 (+2.9%) |
| `user/byState (join, limit 20)` | 1409 | 1594 (+13.1%) | 1601 (+0.4%) | 1750 (+9.3%) |
| `user/list (page of 20)` | 682 | 720 (+5.6%) | 719 (-0.1%) | 741 (+3.1%) |
| `user/count` | 193802 | 320214 (+65.2%) | 320629 (+0.1%) | 321185 (+0.2%) |
| `authenticate (login)` | 1393 | 1459 (+4.7%) | 1491 (+2.2%) | 1474 (-1.1%) |
| `user/register` | 2623 | 3514 † | 3525 (+0.3%) | 3522 (-0.1%) |
| `user/update` | 1881 | 5215 † | 5190 (-0.5%) | 5331 (+2.7%) |
| `user/remove` | 19969 | 12506 † | 12476 (-0.2%) | 13410 (+7.5%) |

### `sqlite`

| Operation | 2026-10-03 | 2026-10-13 | 2026-10-14 | 2026-10-15 |
|---|--:|--:|--:|--:|
| `user/byId` | 17138 | 21220 (+23.8%) | 24721 (+16.5%) | 28183 (+14.0%) |
| `user/byEmail` | 16580 | 20528 (+23.8%) | 24067 (+17.2%) | 27357 (+13.7%) |
| `user/byState (join, limit 20)` | 2326 | 3184 (+36.9%) | 3283 (+3.1%) | 3874 (+18.0%) |
| `user/list (page of 20)` | 2405 | 3352 (+39.4%) | 3433 (+2.4%) | 4098 (+19.4%) |
| `user/count` | 121903 | 162445 (+33.3%) | 195377 (+20.3%) | 195471 (+0.0%) |
| `authenticate (login)` | 14764 | 18140 (+22.9%) | 20985 (+15.7%) | 23181 (+10.5%) |
| `user/register` | 7727 | 8284 (+7.2%) | 9719 (+17.3%) | 9794 (+0.8%) |
| `user/update` | 10302 | 11665 (+13.2%) | 13774 (+18.1%) | 14748 (+7.1%) |
| `user/remove` | 13036 | 14247 (+9.3%) | 16953 (+19.0%) | 17716 (+4.5%) |

### `postgres`

| Operation | 2026-10-03 | 2026-10-13 | 2026-10-14 | 2026-10-15 |
|---|--:|--:|--:|--:|
| `user/byId` | 1453 | 1436 (-1.2%) | 1795 (+25.0%) | 1740 (-3.1%) |
| `user/byEmail` | 1518 | 1414 (-6.9%) | 1823 (+28.9%) | 1793 (-1.6%) |
| `user/byState (join, limit 20)` | 537 | 733 (+36.5%) | 887 (+21.0%) | 885 (-0.2%) |
| `user/list (page of 20)` | 490 | 810 (+65.3%) | 888 (+9.6%) | 898 (+1.1%) |
| `user/count` | 6167 | 5424 (-12.0%) | 6693 (+23.4%) | 6625 (-1.0%) |
| `authenticate (login)` | 1474 | 1350 (-8.4%) | 1724 (+27.7%) | 1750 (+1.5%) |
| `user/register` | 611 | 629 (+2.9%) | 718 (+14.1%) | 732 (+1.9%) |
| `user/update` | 713 | 684 (-4.1%) | 850 (+24.3%) | 820 (-3.5%) |
| `user/remove` | 803 | 762 (-5.1%) | 890 (+16.8%) | 888 (-0.2%) |

2026-10-15: 1.23.1 at `6eb32fa`, the median of 5 rounds (`--repeat 5`),
on AC power with the machine idle. Since 2026-10-14: direct constructor
calls with `reflection_factory` 2.12 (1.23.0), so entities are built
without the reflective invocation path. SQLite gained the most: the
operations that build 20 entities (`byState`, `list`) +18–19%,
single-entity reads +14%, `login` +10%; `count`, which builds no entity,
is unchanged. Memory, where table scans dominate, gained less (`byId`
+14%, `byState` +9%). PostgreSQL is unchanged (−3.5% to +1.9%, within its
Docker noise): each call waits on the database for far longer than it
spends building the entities.

2026-10-14: 1.22.0 at `a508d8f`, the median of 5 rounds (`--repeat 5`),
on AC power with the machine idle. Since 2026-10-13: the IDs of ID
conditions as parameters (Phase 4), prepared statements (SQLite and
PostgreSQL), the fixes of its review, and inline pragmas. On PostgreSQL the
change from 2026-10-13 also carries that date's Docker drift (see below):
alternating `master`, Phase 4 and prepared statements on one container
measured reads +8–12% and writes about the same, so take its single-row
and write numbers here as an upper bound. SQLite gained the most from
prepared statements (a statement compiled once per SQL text): reads
+16–17%, writes +17–19%; memory, which uses no SQL, is unchanged.

2026-10-13 shows its last runs: Phase 3a at `7c9ba77`, the median of 5
rounds per operation (`--repeat 5`; see its entries, and the Phase 0
baseline at `afe1fd5` below them). PostgreSQL runs in Docker Desktop, where
results vary a lot between runs of the same code (see the entries'
notes): compare medians of several rounds, ideally alternating the
versions on one container. Its single-row operations here are within that
noise (`count`, which builds no entity, too).

† Not comparable with earlier dates: the users that `register` inserted
used to stay, so the tables grew during a run (by thousands of users with
`--repeat`), and `update` and `remove` ran on that bigger table. Since
`afe1fd5` they're removed after each round: every round, and the
operations after it, run on the seeded 1000 users. The memory adapter
scans tables, so its numbers depend the most on the table size.

---

### 2026-10-15 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.23.1 (`6eb32fa`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 1740 | 574.6 | 560 | 688 | 772 | 1679–1839 |
| `user/byEmail` | 1793 | 557.9 | 552 | 596 | 645 | 1751–1815 |
| `user/byState (join, limit 20)` | 885 | 1129.7 | 1134 | 1204 | 1238 | 868–967 |
| `user/list (page of 20)` | 898 | 1113.6 | 1118 | 1177 | 1206 | 896–915 |
| `user/count` | 6625 | 150.9 | 149 | 163 | 189 | 6571–6683 |
| `authenticate (login)` | 1750 | 571.3 | 569 | 605 | 645 | 1709–1758 |
| `user/register` | 732 | 1366.8 | 1335 | 1733 | 1818 | 703–777 |
| `user/update` | 820 | 1219.5 | 1209 | 1264 | 1413 | 784–826 |
| `user/remove` | 888 | 1126.2 | 1124 | 1163 | 1218 | 883–913 |

1.23.1, on AC power with the machine idle (`--docker`, `--repeat 5`).
Unchanged from 1.22.0 (2026-10-14), within the Docker noise: direct
constructor calls (1.23.0) save CPU time that is small next to the
database round trips. An earlier run this day, with the machine in use,
measured `byState` and `list` at ~1000–1030 ops/sec; it was replaced by
this one.

### 2026-10-15 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.23.1 (`6eb32fa`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 28183 | 35.5 | 34 | 40 | 82 | 28076–28230 |
| `user/byEmail` | 27357 | 36.6 | 35 | 41 | 82 | 27295–27428 |
| `user/byState (join, limit 20)` | 3874 | 258.1 | 251 | 306 | 322 | 3859–3883 |
| `user/list (page of 20)` | 4098 | 244.0 | 238 | 298 | 311 | 4092–4101 |
| `user/count` | 195471 | 5.1 | 5 | 5 | 6 | 195198–195947 |
| `authenticate (login)` | 23181 | 43.1 | 41 | 47 | 104 | 23164–23200 |
| `user/register` | 9794 | 102.1 | 86 | 109 | 902 | 9762–9939 |
| `user/update` | 14748 | 67.8 | 65 | 72 | 91 | 14675–14825 |
| `user/remove` | 17716 | 56.4 | 48 | 53 | 105 | 17477–17933 |

### 2026-10-15 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.23.1 (`6eb32fa`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 35186 | 28.4 | 27 | 32 | 48 | 34992–35218 |
| `user/byEmail` | 1478 | 676.8 | 674 | 1253 | 1328 | 1419–1567 |
| `user/byState (join, limit 20)` | 1750 | 571.6 | 561 | 635 | 648 | 1741–1757 |
| `user/list (page of 20)` | 741 | 1349.5 | 1350 | 1425 | 1458 | 731–769 |
| `user/count` | 321185 | 3.1 | 3 | 3 | 4 | 320028–321355 |
| `authenticate (login)` | 1474 | 678.3 | 701 | 1204 | 1286 | 1443–1569 |
| `user/register` | 3522 | 283.9 | 280 | 417 | 451 | 3484–3701 |
| `user/update` | 5331 | 187.6 | 187 | 222 | 235 | 5323–5332 |
| `user/remove` | 13410 | 74.6 | 75 | 92 | 97 | 11646–13566 |

### 2026-10-14 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.22.0 (`a508d8f`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 1795 | 557.1 | 553 | 593 | 634 | 1689–1842 |
| `user/byEmail` | 1823 | 548.6 | 545 | 584 | 623 | 1792–1827 |
| `user/byState (join, limit 20)` | 887 | 1128.0 | 1120 | 1216 | 1273 | 883–902 |
| `user/list (page of 20)` | 888 | 1126.0 | 1125 | 1199 | 1251 | 859–921 |
| `user/count` | 6693 | 149.4 | 148 | 161 | 177 | 6655–6698 |
| `authenticate (login)` | 1724 | 580.2 | 574 | 622 | 697 | 1685–1741 |
| `user/register` | 718 | 1392.0 | 1343 | 1751 | 1815 | 696–725 |
| `user/update` | 850 | 1176.7 | 1195 | 1252 | 1314 | 781–898 |
| `user/remove` | 890 | 1123.2 | 1121 | 1164 | 1209 | 884–926 |

1.22.0, on AC power with the machine idle (`--docker`, `--repeat 5`).
Prepared statements are reused per connection, prepared when a SQL repeats
outside a transaction; the IDs of ID conditions are parameters, so a
`byId` reuses one statement for any ID. Alternating the versions on one
container (see #180): prepared statements made reads +8–12% vs `master`,
writes about the same (they run in transactions, where nothing new is
prepared). The change from the 2026-10-13 entry is larger, as that run
drifted (its note).

### 2026-10-14 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.22.0 (`a508d8f`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 24721 | 40.5 | 39 | 46 | 89 | 24709–24784 |
| `user/byEmail` | 24067 | 41.6 | 40 | 47 | 90 | 24038–24085 |
| `user/byState (join, limit 20)` | 3283 | 304.6 | 295 | 357 | 377 | 3255–3288 |
| `user/list (page of 20)` | 3433 | 291.3 | 283 | 345 | 361 | 3429–3437 |
| `user/count` | 195377 | 5.1 | 5 | 5 | 6 | 195242–195435 |
| `authenticate (login)` | 20985 | 47.7 | 46 | 53 | 107 | 20951–21006 |
| `user/register` | 9719 | 102.9 | 86 | 111 | 938 | 9471–9872 |
| `user/update` | 13774 | 72.6 | 69 | 78 | 98 | 13755–13818 |
| `user/remove` | 16953 | 59.0 | 52 | 56 | 105 | 16645–17053 |

1.22.0. Prepared statements: each SQL text compiled once (on its first
use) and reused, so every operation that runs SQL gained, reads and writes
alike. Alternating with `master` (see #180): single-user reads +17–19%,
writes +13–15%, `list`/`byState` +4–5% (building 20 entities takes most of
their time). The inline pragmas added ~3% to `byState`.

### 2026-10-14 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.22.0 (`a508d8f`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 30937 | 32.3 | 31 | 37 | 85 | 30825–30975 |
| `user/byEmail` | 1437 | 695.7 | 713 | 1229 | 1305 | 1153–1562 |
| `user/byState (join, limit 20)` | 1601 | 624.5 | 611 | 689 | 704 | 1565–1604 |
| `user/list (page of 20)` | 719 | 1391.4 | 1378 | 1446 | 1466 | 717–720 |
| `user/count` | 320629 | 3.1 | 3 | 3 | 4 | 320434–321296 |
| `authenticate (login)` | 1491 | 670.8 | 676 | 1223 | 1292 | 1428–1518 |
| `user/register` | 3525 | 283.7 | 279 | 413 | 448 | 3494–3691 |
| `user/update` | 5190 | 192.7 | 191 | 228 | 249 | 5181–5208 |
| `user/remove` | 12476 | 80.2 | 81 | 97 | 105 | 12100–12820 |

1.22.0. The memory adapter runs no SQL, so the SQL changes since
2026-10-13 (ID parameters, prepared statements) don't apply to it: within
about 2% of that date.

### 2026-10-13 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.3 (`7c9ba77`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 1436 | 696.3 | 694 | 748 | 802 | 1318–1470 |
| `user/byEmail` | 1414 | 707.2 | 704 | 758 | 838 | 1128–1439 |
| `user/byState (join, limit 20)` | 733 | 1364.2 | 1357 | 1441 | 1512 | 656–742 |
| `user/list (page of 20)` | 810 | 1234.5 | 1235 | 1307 | 1354 | 755–822 |
| `user/count` | 5424 | 184.4 | 182 | 199 | 224 | 5295–5503 |
| `authenticate (login)` | 1350 | 740.7 | 736 | 793 | 838 | 1343–1388 |
| `user/register` | 629 | 1590.4 | 1543 | 2013 | 2145 | 607–634 |
| `user/update` | 684 | 1462.3 | 1442 | 1570 | 1635 | 643–696 |
| `user/remove` | 762 | 1312.5 | 1302 | 1385 | 1431 | 758–782 |

Phase 3a, the entity mapping (see the `sqlite` entry below). Since the
baseline (`afe1fd5`): Phase 1 (fewer write statements, no `StackTrace` per
commit), Phase 2 (a `LIMIT` ordered by ID) and Phase 3a. `list` and
`byState`, which build 20 users per call, gained the most, and steadily:
alternating runs with `master` (Phase 2) on one container gave `list`
826 vs 418 and 637 vs 448 ops/sec. The single-row operations varied by
±15–20% in both directions between those alternating runs, `count` (no
entity built) included: this machine drifted during the session, so they
are noise here, not a change.

### 2026-10-13 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.3 (`7c9ba77`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 21220 | 47.1 | 45 | 54 | 97 | 21137–21257 |
| `user/byEmail` | 20528 | 48.7 | 47 | 54 | 99 | 20481–20538 |
| `user/byState (join, limit 20)` | 3184 | 314.1 | 304 | 367 | 386 | 3156–3192 |
| `user/list (page of 20)` | 3352 | 298.3 | 291 | 353 | 367 | 3329–3354 |
| `user/count` | 162445 | 6.2 | 6 | 6 | 7 | 162245–162751 |
| `authenticate (login)` | 18140 | 55.1 | 53 | 61 | 118 | 18073–18167 |
| `user/register` | 8284 | 120.7 | 102 | 131 | 1009 | 8209–8665 |
| `user/update` | 11665 | 85.7 | 83 | 93 | 107 | 11614–11686 |
| `user/remove` | 14247 | 70.2 | 62 | 68 | 113 | 13861–14552 |

Phase 3a: turning rows into entities. The values of a row are resolved
into one map (no intermediate entries, maps and futures), the column of
each field is matched once per row layout (not per row), a value isn't
inspected (`TypeInfo.from`) when it can't be returned as is, and the
`DateTime`s SQLite stores are parsed without a regular expression. Run
alternately with `master` (Phase 2: `byId` 18976, `byEmail` 18348,
`byState` 2431, `list` 2567, `login` 16358): the reads +11–12% and the
20-user reads +31%, with no overlap of the rounds.

### 2026-10-13 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.3 (`7c9ba77`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 30312 | 33.0 | 31 | 38 | 84 | 30049–30544 |
| `user/byEmail` | 1449 | 690.1 | 716 | 1223 | 1282 | 1192–1570 |
| `user/byState (join, limit 20)` | 1594 | 627.5 | 614 | 692 | 705 | 1555–1598 |
| `user/list (page of 20)` | 720 | 1388.6 | 1376 | 1444 | 1455 | 719–721 |
| `user/count` | 320214 | 3.1 | 3 | 3 | 4 | 319926–320745 |
| `authenticate (login)` | 1459 | 685.4 | 713 | 1218 | 1288 | 1435–1543 |
| `user/register` | 3514 | 284.6 | 280 | 413 | 449 | 3494–3704 |
| `user/update` | 5215 | 191.8 | 189 | 229 | 250 | 5208–5242 |
| `user/remove` | 12506 | 80.0 | 81 | 97 | 104 | 12072–12838 |

Same code as the `postgres` entry above. Run alternately with `master`
(Phase 2): `byId` +12%, `byState` +8%, `list` +4%. The memory adapter's
time is mostly its table scans (`byEmail`, `login`, `list`), not the
entity mapping.

---

### 2026-10-13 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`afe1fd5`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 1575 | 634.9 | 629 | 683 | 728 | 1450–1583 |
| `user/byEmail` | 1528 | 654.6 | 645 | 706 | 764 | 1518–1555 |
| `user/byState (join, limit 20)` | 571 | 1749.8 | 1735 | 2322 | 2664 | 442–644 |
| `user/list (page of 20)` | 477 | 2094.7 | 2108 | 2597 | 3071 | 417–665 |
| `user/count` | 6060 | 165.0 | 163 | 179 | 203 | 6001–6081 |
| `authenticate (login)` | 1490 | 671.1 | 664 | 726 | 785 | 1443–1498 |
| `user/register` | 589 | 1697.1 | 1636 | 2067 | 2249 | 575–595 |
| `user/update` | 761 | 1314.5 | 1306 | 1395 | 1537 | 730–762 |
| `user/remove` | 843 | 1186.2 | 1180 | 1256 | 1323 | 843–845 |

The baseline for the optimization phases (Phase 0: `executedSQLsCount`,
`--repeat`, the per-round cleanup of `register`), with the median of 5
rounds. The rounds show the spread of this setup: `byState` and `list`
range from ~420 to ~660 ops/sec within one run, while the single-row
operations stay within a few percent. Their medians are back in the range
of the 2026-10-03 entries (the 2026-10-13 release run's single round was a
low one).

### 2026-10-13 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`afe1fd5`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 17403 | 57.5 | 55 | 65 | 113 | 17248–17538 |
| `user/byEmail` | 16611 | 60.2 | 58 | 67 | 114 | 15867–16703 |
| `user/byState (join, limit 20)` | 2456 | 407.2 | 395 | 463 | 496 | 2431–2472 |
| `user/list (page of 20)` | 2517 | 397.3 | 388 | 448 | 476 | 2495–2520 |
| `user/count` | 122401 | 8.2 | 8 | 8 | 10 | 116824–122789 |
| `authenticate (login)` | 14983 | 66.7 | 64 | 74 | 133 | 14673–15073 |
| `user/register` | 7168 | 139.5 | 120 | 155 | 1131 | 7119–7281 |
| `user/update` | 10363 | 96.5 | 92 | 105 | 148 | 10298–10402 |
| `user/remove` | 12300 | 81.3 | 72 | 82 | 150 | 12195–12491 |

Same code as the `postgres` entry above. The index on `address.state` (new
in the benchmark's entities) makes `byState` ~5% faster, and costs ~5% on
the writes that insert an address (`register`, and the untimed
registration before each `remove`): measured by alternating runs with and
without it (`register` ~7430 vs ~7050 ops/sec, `remove` ~13175 vs
~12175), and the same without the per-round cleanup (it isn't the cause).

### 2026-10-13 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`afe1fd5`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) × 5 rounds, median shown per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) | rounds (ops/sec) |
|---|--:|--:|--:|--:|--:|--:|
| `user/byId` | 25288 | 39.5 | 38 | 45 | 94 | 24516–25369 |
| `user/byEmail` | 1533 | 652.2 | 657 | 1200 | 1262 | 1118–1545 |
| `user/byState (join, limit 20)` | 1469 | 680.5 | 665 | 748 | 778 | 1415–1474 |
| `user/list (page of 20)` | 693 | 1442.2 | 1430 | 1521 | 1709 | 686–701 |
| `user/count` | 195230 | 5.1 | 5 | 5 | 6 | 194973–195665 |
| `authenticate (login)` | 1459 | 685.3 | 715 | 1204 | 1277 | 1440–1564 |
| `user/register` | 3438 | 290.9 | 282 | 426 | 553 | 3430–3626 |
| `user/update` | 4928 | 202.9 | 204 | 239 | 257 | 4867–4978 |
| `user/remove` | 11401 | 87.7 | 89 | 104 | 113 | 11346–12117 |

Same code as the `postgres` entry above. `register`, `update` and `remove`
now run on the seeded 1000 users (see † in the progression): a run of
`0e0109a`, before the per-round cleanup, had `register` from 942 to 2675
ops/sec across its 5 rounds as the tables grew, and `update` at 884.

---

### 2026-10-13 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`1c10511`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 1461 | 684.3 | 676 | 761 | 818 |
| `user/byEmail` | 1521 | 657.3 | 648 | 710 | 833 |
| `user/byState (join, limit 20)` | 403 | 2483.8 | 2487 | 3758 | 4586 |
| `user/list (page of 20)` | 302 | 3314.2 | 2749 | 6418 | 7273 |
| `user/count` | 6199 | 161.3 | 159 | 178 | 204 |
| `authenticate (login)` | 1482 | 674.7 | 667 | 735 | 791 |
| `user/register` | 592 | 1689.1 | 1631 | 2059 | 2293 |
| `user/update` | 713 | 1402.9 | 1338 | 1678 | 1978 |
| `user/remove` | 882 | 1133.4 | 1150 | 1207 | 1239 |

The release with #169 (auth token fixes) and #170 (concurrency tests;
SQLite transactions queued, leaked auto-commit transaction, pool size);
`1c10511` has the same tree as master's merge of #170, `a7ec311`. Single
reads and writes match the previous entry.

`list` and `byState` are lower here, but that is the Docker Desktop
variance noted below, not a regression. Re-runs of the two gave `list`
484–578/s. An A/B against v1.21.1, alternating 3 runs each on one
container, overlapped: `byState` 429–485/s (v1.21.1) vs 354–570/s, and
`list` 357–575/s vs 534–578/s.

### 2026-10-13 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`1c10511`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 17403 | 57.5 | 55 | 65 | 111 |
| `user/byEmail` | 16535 | 60.5 | 59 | 68 | 114 |
| `user/byState (join, limit 20)` | 2348 | 426.0 | 415 | 484 | 519 |
| `user/list (page of 20)` | 2419 | 413.4 | 403 | 471 | 496 |
| `user/count` | 122422 | 8.2 | 8 | 8 | 10 |
| `authenticate (login)` | 14835 | 67.4 | 65 | 74 | 133 |
| `user/register` | 7690 | 130.0 | 115 | 152 | 470 |
| `user/update` | 10282 | 97.3 | 93 | 106 | 160 |
| `user/remove` | 13250 | 75.5 | 73 | 82 | 127 |

Same code as the `postgres` entry above. Within noise of the previous
entry on every operation, writes included: queueing SQLite transactions
(one at a time, for concurrent callers) costs nothing for a single client.

### 2026-10-13 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.21.2 (`1c10511`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 25688 | 38.9 | 37 | 45 | 94 |
| `user/byEmail` | 1526 | 655.1 | 657 | 1202 | 1270 |
| `user/byState (join, limit 20)` | 1454 | 687.7 | 674 | 757 | 775 |
| `user/list (page of 20)` | 690 | 1450.0 | 1448 | 1519 | 1557 |
| `user/count` | 153540 | 6.5 | 5 | 15 | 29 |
| `authenticate (login)` | 1426 | 701.3 | 725 | 1247 | 1325 |
| `user/register` | 2611 | 383.1 | 380 | 505 | 565 |
| `user/update` | 1944 | 514.3 | 509 | 574 | 596 |
| `user/remove` | 21245 | 47.1 | 45 | 56 | 104 |

Same code as the `postgres` entry above. Within noise of the previous
entry (`count`'s p95/p99 vary between runs at ~5 us per call).

### 2026-10-03 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`98cc744 (modified)`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 1453 | 688.3 | 679 | 769 | 833 |
| `user/byEmail` | 1518 | 658.8 | 651 | 712 | 777 |
| `user/byState (join, limit 20)` | 537 | 1860.7 | 1846 | 2684 | 3207 |
| `user/list (page of 20)` | 490 | 2039.1 | 1929 | 2832 | 3516 |
| `user/count` | 6167 | 162.1 | 160 | 177 | 206 |
| `authenticate (login)` | 1474 | 678.6 | 671 | 738 | 804 |
| `user/register` | 611 | 1635.5 | 1615 | 2051 | 2204 |
| `user/update` | 713 | 1402.9 | 1348 | 1664 | 1740 |
| `user/remove` | 803 | 1245.9 | 1199 | 1379 | 2449 |

The optimizations of branch `perf/db-users-optimizations` (the
modifications: the dependency bump to reflection_factory 2.10.1 and
map_history 1.0.7, committed right after). The PostgreSQL gain is mostly
`readsOutsideTransaction`: a read of a user went from `BEGIN`, 4 `SELECT`s
and `COMMIT` to the 4 `SELECT`s, so single-entity reads doubled.

`list`/`byState` vary a lot from run to run with this server in Docker
Desktop: 490–579/s across runs of the same code. An A/B on one server and
process (`readsOutsideTransaction` on vs off) measured `list` 29% faster.

### 2026-10-03 — `sqlite` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`98cc744 (modified)`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** sqlite (temporary file)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 17138 | 58.4 | 56 | 67 | 113 |
| `user/byEmail` | 16580 | 60.3 | 58 | 68 | 115 |
| `user/byState (join, limit 20)` | 2326 | 429.9 | 416 | 492 | 535 |
| `user/list (page of 20)` | 2405 | 415.8 | 403 | 475 | 509 |
| `user/count` | 121903 | 8.2 | 8 | 8 | 11 |
| `authenticate (login)` | 14764 | 67.7 | 64 | 77 | 135 |
| `user/register` | 7727 | 129.4 | 114 | 154 | 736 |
| `user/update` | 10302 | 97.1 | 92 | 108 | 163 |
| `user/remove` | 13036 | 76.7 | 73 | 86 | 137 |

Same code as the `postgres` entry above. The SQLite gain is the CPU of
decoding entities: tracking references by ID instead of deep copies, and
reflection_factory 2.10.1's faster constructor lookup.

### 2026-10-03 — `memory` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`98cc744 (modified)`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** memory (DBSQLMemoryAdapter)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 25303 | 39.5 | 37 | 45 | 94 |
| `user/byEmail` | 1407 | 710.9 | 727 | 1269 | 1425 |
| `user/byState (join, limit 20)` | 1409 | 709.8 | 693 | 787 | 854 |
| `user/list (page of 20)` | 682 | 1467.0 | 1454 | 1558 | 1670 |
| `user/count` | 193802 | 5.2 | 5 | 5 | 7 |
| `authenticate (login)` | 1393 | 717.7 | 733 | 1285 | 1360 |
| `user/register` | 2623 | 381.2 | 381 | 507 | 571 |
| `user/update` | 1881 | 531.8 | 519 | 611 | 694 |
| `user/remove` | 19969 | 50.1 | 47 | 65 | 119 |

Same code as the `postgres` entry above. The memory adapter's
relationship selects/deletes now use its indexes, a delete by ID takes its
row by key, and map_history 1.0.7 no longer visits every row on each
commit. `byEmail` and `login` still scan the `user` table (no index on
entity tables' fields yet).

### 2026-10-03 — `postgres` — Mac17,3 (Apple M5)

- **bones_api:** 1.17.1 (`af958b4`)
- **Machine:** Mac17,3 (Apple M5), Apple M5, 10 cores, 16 GB RAM
- **OS:** macos (Version 26.6.2 (Build 25G83))
- **Dart:** 3.13.5
- **DB:** postgres (PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2), Docker postgres:latest)
- **Users:** 1000; **duration:** 3s (warm-up 1s) per operation

| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |
|---|--:|--:|--:|--:|--:|
| `user/byId` | 699 | 1430.8 | 1418 | 1536 | 1734 |
| `user/byEmail` | 735 | 1361.1 | 1345 | 1444 | 1664 |
| `user/byState (join, limit 20)` | 464 | 2154.5 | 2073 | 2790 | 3053 |
| `user/list (page of 20)` | 465 | 2149.2 | 2069 | 2823 | 3080 |
| `user/count` | 6321 | 158.2 | 157 | 175 | 206 |
| `authenticate (login)` | 754 | 1325.9 | 1330 | 1428 | 1500 |
| `user/register` | 601 | 1663.7 | 1623 | 2050 | 2277 |
| `user/update` | 471 | 2124.9 | 2065 | 2403 | 2597 |
| `user/remove` | 853 | 1172.5 | 1180 | 1265 | 1327 |

Server in Docker Desktop on the same machine (`--docker`), so every query
crosses the Docker VM's network. Round trips likely dominate (`count`, a
single query, is ~160 us; `byId`, which also loads the address and roles,
~1.4 ms) — not profiled. Not comparable to a native or remote server.

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
