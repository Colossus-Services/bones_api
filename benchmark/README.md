# Benchmarks

In-process benchmarks for the framework's own overhead — no socket, no HTTP
client, and (for the DB suite) an in-memory adapter, so what is measured is
`bones_api` itself rather than I/O.

| Suite | Covers |
|---|---|
| `bones_api_benchmark.dart` | The request path: `APIRequest`, routing, `APIRoot.call` |
| `json_benchmark.dart` | JSON request/response encoding and decoding |
| `db_benchmark.dart` | The DB entity path against `DBSQLMemoryAdapter` |

```bash
dart run benchmark/bones_api_benchmark.dart
dart run benchmark/json_benchmark.dart
dart run benchmark/db_benchmark.dart
```

To compare a change, record a baseline on your machine first — throughput is
hardware- and load-specific, so numbers are only meaningful relative to a run
on the same machine:

```bash
# 1. before the change
dart run benchmark/bones_api_benchmark.dart --emit-baseline

# 2. paste the emitted map into `_baseline` in bones_api_benchmark.dart

# 3. after the change
dart run benchmark/bones_api_benchmark.dart
```

The report then gains a `VS BASE` column.

## Reading the results

The suite is deliberately layered, so a regression can be attributed instead of
just observed at the top:

| Layer | What it isolates |
|---|---|
| `APIRequest.get: *` | Path splitting, parameters, `requestedUri` |
| `APIRequest.pathParts` / `pathPart(0)` | Path accessors used on every dispatch |
| `APIRoot.getModuleByRequest`, `APIModule.getRouteHandlerByRequest` | Routing table lookups |
| `APIResponse.ok(String)` | Response construction |
| `APIRouteHandler.call (direct)` | A route call without the module/root layers |
| `APIModule.call (direct)` | Adds module resolution and security checks |
| `APIRoot.call: *` | Full dispatch, including the per-call `Zone` |

Each `APIRoot.call` benchmark builds a fresh `APIRequest`, so subtract the
matching `APIRequest.get` cost to isolate the dispatch itself.

## Note on route logging

`APIRouteConfig.log` defaults to `true`, and the `CALL>` / `RESPONSE>` records
it emits are a large share of the cost of an otherwise trivial route. The suite
measures both, as `APIRoot.call: ping (empty payload)` and
`APIRoot.call: ping [route log off]`, so the trade-off stays visible.

Disable it per route when throughput matters more than the audit trail:

```dart
routes.get('ping', handler, config: const APIRouteConfig(log: false));
```

## Where the DB and JSON time goes

Recorded once on one machine, as orders of magnitude rather than targets.

**JSON** is in reasonable shape. `Json.encodeToSink` — the response path — runs
close to a bare `dart:convert` encode of the same value (~1.5us vs ~1.2us for a
small map), and is *faster* for larger payloads because it writes bytes to a
sink instead of building a `String`. Request bodies are parsed with
`dart:convert` directly, so there is no `bones_api` layer to remove there.

**DB**, per `db_benchmark.dart` (50 rows):

| | us/op |
|---|---|
| `ConditionParseCache.parseQuery` (cached) | 0.009 |
| `Entity.toJson` | 0.074 |
| `generateSelectSQL` | 0.81 |
| `EntityHandler.createFromMap` | 1.11 |
| `ConditionParser.parse` (shared parser) | 2.67 |
| `Transaction.executeBlock` (empty) | 2.40 |
| `repository.selectByID` | 7.2 |
| `repository.selectByQuery` | 20.4 |

The two things a query is *assumed* to be expensive for are not: query parsing
is cached (~300x cheaper than parsing), and SQL generation is under a
microsecond.

**Read `selectByQuery` with the row count in mind.** `DBSQLMemoryAdapter`
answers a non-ID condition by scanning the table `Map` and evaluating the
condition per row, so that number is mostly the scan, not framework overhead.
Use `--rows=N` to separate the two:

```bash
dart run benchmark/db_benchmark.dart --rows=400
```

| rows | `selectByQuery` |
|---|---|
| 10 | 10.9us |
| 50 | 20.4us |
| 400 | 105.9us |

Linear: roughly 8.5us fixed plus ~0.24us per row. Only the fixed part is
framework cost shared with a real SQL adapter, where the database does the
filtering — so do not read 20us as "the cost of a query" in production.

Of that fixed part, an empty `Transaction.executeBlock` is 2.4us. That is the
most promising remaining target, and wants a real profiler
(`dart run --observe`) rather than more micro-benchmarks.

Note `ConditionParser` builds its PetitParser grammar lazily on first use
(~125us). `bones_api` holds it in a `static final`, so this is a one-off
startup cost — but constructing a `ConditionParser` per query would not be.
