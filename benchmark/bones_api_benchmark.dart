import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:bones_api/bones_api.dart';

import 'src/bench_runner.dart';

/// Benchmarks for the request path: building an [APIRequest], resolving the
/// module/route, dispatching through [APIRoot.call] and serializing the
/// response payload.
///
/// Run with:
/// ```
/// dart run benchmark/bones_api_benchmark.dart
/// ```
///
/// These are all in-process: they measure the framework's own overhead,
/// without a socket or an HTTP client in the way.
Future<void> main(List<String> args) async {
  var api = BenchmarkAPI();
  await api.ensureInitialized();

  var runner = BenchRunner();

  // ---------------------------------------------------------------------
  // `APIRequest` construction: path splitting, parameters, `requestedUri`.
  // ---------------------------------------------------------------------

  runner.run(
    'APIRequest.get: simple path',
    () => APIRequest.get('/bench/ping'),
  );

  runner.run(
    'APIRequest.get: deep path',
    () => APIRequest.get('/bench/a/b/c/d/e/f'),
  );

  runner.run(
    'APIRequest.get: with parameters',
    () => APIRequest.get(
      '/bench/echo',
      parameters: {'a': '1', 'b': '2', 'c': '3'},
    ),
  );

  // ---------------------------------------------------------------------
  // Path accessors, called on every dispatch.
  // ---------------------------------------------------------------------

  var pathRequest = APIRequest.get('/bench/a/b/c/d/e/f');

  runner.run('APIRequest.pathParts', () => pathRequest.pathParts);
  runner.run('APIRequest.pathPart(0)', () => pathRequest.pathPart(0));

  // ---------------------------------------------------------------------
  // Routing: module lookup and route-handler resolution.
  // ---------------------------------------------------------------------

  var routeRequest = APIRequest.get('/bench/ping');

  runner.run(
    'APIRoot.getModuleByRequest',
    () => api.getModuleByRequest(routeRequest),
  );

  var module = api.getModuleByRequest(routeRequest)!;

  runner.run(
    'APIModule.getRouteHandlerByRequest',
    () => module.getRouteHandlerByRequest(routeRequest),
  );

  runner.run('APIRoot.acceptsRequest', () => api.acceptsRequest(routeRequest));

  // ---------------------------------------------------------------------
  // Dispatch breakdown: each layer measured on its own, so a regression can
  // be attributed instead of just observed at the top.
  // ---------------------------------------------------------------------

  runner.run('APIResponse.ok(String)', () => APIResponse.ok('pong'));

  var handler = module.getRouteHandlerByRequest(routeRequest)!;

  await runner.runAsync(
    'APIRouteHandler.call (direct)',
    () => handler.call(APIRequest.get('/bench/ping')),
  );

  await runner.runAsync(
    'APIModule.call (direct)',
    () => module.call(APIRequest.get('/bench/ping')),
  );

  // ---------------------------------------------------------------------
  // Full in-process dispatch.
  // ---------------------------------------------------------------------

  await runner.runAsync(
    'APIRoot.call: ping (empty payload)',
    () => api.call(APIRequest.get('/bench/ping')),
  );

  await runner.runAsync(
    'APIRoot.call: echo (parameters)',
    () => api.call(
      APIRequest.get('/bench/echo', parameters: {'a': '1', 'b': '2'}),
    ),
  );

  await runner.runAsync(
    'APIRoot.call: json (entity payload)',
    () => api.call(APIRequest.get('/bench/json')),
  );

  await runner.runAsync(
    'APIRoot.call: 404 (unmatched route)',
    () => api.call(APIRequest.get('/bench/nope')),
  );

  // Route logging is on by default (`APIRouteConfig.log`), and dominates the
  // cost of an otherwise trivial route. Measured side by side so the trade-off
  // is visible rather than surprising.
  await runner.runAsync(
    'APIRoot.call: ping [route log off]',
    () => api.call(APIRequest.get('/bench/quiet')),
  );

  // ---------------------------------------------------------------------
  // Response payload serialization.
  // ---------------------------------------------------------------------

  var payload = _samplePayload();
  var jsonResponse = APIResponse.ok(payload);

  runner.run(
    'APIResponse.payload -> JSON',
    () => dart_convert.json.encode(jsonResponse.payload),
  );

  runner.report(baseline: _baseline);

  if (args.contains('--emit-baseline')) {
    print('const _baseline = <String, double>{');
    runner.asBaseline().forEach((k, v) {
      print("  '$k': ${v.toStringAsFixed(0)},");
    });
    print('};');
  }

  api.close();

  // An initialized `APIRoot` keeps the isolate alive (shared stores, log
  // queue, timers), so a benchmark run would otherwise hang after reporting.
  exit(0);
}

Map<String, dynamic> _samplePayload() => {
  'id': 12345,
  'name': 'Joe Smith',
  'email': 'joe@example.com',
  'enabled': true,
  'score': 98.6,
  'tags': ['alpha', 'beta', 'gamma'],
  'address': {
    'street': '123 Main St',
    'city': 'Springfield',
    'state': 'NY',
    'zip': '12345',
  },
};

/// Reference numbers to compare a run against, shown as a `VS BASE` column.
///
/// Left empty on purpose: throughput is hardware- and load-specific, so a
/// baseline recorded on one machine would only produce misleading deltas on
/// another. To compare a change, record a baseline on *your* machine first:
///
/// ```
/// dart run benchmark/bones_api_benchmark.dart --emit-baseline
/// ```
///
/// then paste the emitted map here, apply the change, and run again.
const _baseline = <String, double>{};

class BenchmarkModule extends APIModule {
  BenchmarkModule(APIRoot apiRoot) : super(apiRoot, 'bench');

  @override
  void configure() {
    routes.get('ping', (request) => APIResponse.ok('pong'));

    routes.get('echo', (request) => APIResponse.ok(request.parameters));

    routes.get('json', (request) => APIResponse.ok(_samplePayload()));

    // Same work as `ping`, with the per-route call/response logging disabled.
    routes.get(
      'quiet',
      (request) => APIResponse.ok('pong'),
      config: const APIRouteConfig(log: false),
    );
  }
}

class BenchmarkAPI extends APIRoot {
  BenchmarkAPI() : super('benchmark', '1.0');

  @override
  Set<APIModule> loadModules() => {BenchmarkModule(this)};
}
