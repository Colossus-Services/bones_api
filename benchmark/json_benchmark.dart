import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:bones_api/bones_api.dart';

import 'src/bench_runner.dart';

/// Benchmarks for the JSON request/response path.
///
/// ```
/// dart run benchmark/json_benchmark.dart
/// ```
///
/// `Json.encodeToSink(..., toEncodable: ...)` is what `APIServer` uses to turn
/// a response payload into bytes, so it is measured here in exactly that shape,
/// next to a bare `dart:convert` encode of the same value for reference.
Future<void> main(List<String> args) async {
  var runner = BenchRunner();

  var small = _smallPayload();
  var list = List.generate(50, (i) => _smallPayload());
  var jsonSmall = dart_convert.json.encode(small);
  var jsonList = dart_convert.json.encode(list);

  // -----------------------------------------------------------------------
  // Reference: `dart:convert` with no bones_api machinery.
  // -----------------------------------------------------------------------

  runner.run(
    'dart:convert encode: small map',
    () => dart_convert.json.encode(small),
  );

  runner.run(
    'dart:convert encode: 50 maps',
    () => dart_convert.json.encode(list),
  );

  // -----------------------------------------------------------------------
  // `Json.encode`, the default (cached) encoder path.
  // -----------------------------------------------------------------------

  runner.run('Json.encode: small map', () => Json.encode(small));
  runner.run('Json.encode: 50 maps', () => Json.encode(list));

  // -----------------------------------------------------------------------
  // The response path: `encodeToSink` with a `toEncodable`.
  // -----------------------------------------------------------------------

  runner.run('Json.encodeToSink: small map [response path]', () {
    var sink = _BytesSink();
    Json.encodeToSink(
      small,
      sink,
      toEncodable: ReflectionFactory.toJsonEncodable,
    );
    return sink.length;
  });

  runner.run('Json.encodeToSink: 50 maps [response path]', () {
    var sink = _BytesSink();
    Json.encodeToSink(
      list,
      sink,
      toEncodable: ReflectionFactory.toJsonEncodable,
    );
    return sink.length;
  });

  // Same output, but through the default encoder (no `toEncodable`), to show
  // the cost attributable purely to building a per-call encoder.
  runner.run('Json.encodeToSink: small map [no toEncodable]', () {
    var sink = _BytesSink();
    Json.encodeToSink(small, sink);
    return sink.length;
  });

  // -----------------------------------------------------------------------
  // Decoding: the request payload path.
  //
  // `APIServer` parses a JSON request body with `dart:convert` directly
  // (`bones_api_server.dart`, `_resolvePayloadFromString`), so that is what is
  // measured; `Json.decode` is the entity-aware decoder used elsewhere.
  // -----------------------------------------------------------------------

  runner.run(
    'dart:convert decode: small map [request path]',
    () => dart_convert.json.decode(jsonSmall),
  );

  runner.run(
    'dart:convert decode: 50 maps [request path]',
    () => dart_convert.json.decode(jsonList),
  );

  runner.report(baseline: _baseline);

  if (args.contains('--emit-baseline')) {
    print('const _baseline = <String, double>{');
    runner.asBaseline().forEach((k, v) {
      print("  '$k': ${v.toStringAsFixed(0)},");
    });
    print('};');
  }

  exit(0);
}

Map<String, dynamic> _smallPayload() => {
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

/// See the note on `_baseline` in `bones_api_benchmark.dart`.
const _baseline = <String, double>{};

class _BytesSink implements Sink<List<int>> {
  int length = 0;

  @override
  void add(List<int> data) => length += data.length;

  @override
  void close() {}
}
