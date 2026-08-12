# Benchmarks

In-process benchmarks for the request path: building an `APIRequest`, resolving
the module/route, dispatching through `APIRoot.call`, and serializing the
response payload. No socket and no HTTP client are involved, so what is
measured is the framework's own overhead.

```bash
dart run benchmark/bones_api_benchmark.dart
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
