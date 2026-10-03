import 'dart:async';

/// Runs each operation for a fixed time, timing every call individually so
/// latency percentiles can be reported alongside throughput.
///
/// Calls run sequentially (a single client), so throughput is derived from
/// the measured latencies: `1s / mean`. That keeps any untimed `setup` work
/// out of the result.
class BenchRunner {
  /// Time each operation is measured for, after [warmup].
  final Duration duration;

  /// Time each operation runs before measuring, to let the JIT and the DB
  /// caches settle.
  final Duration warmup;

  final List<BenchResult> _results = [];

  BenchRunner({
    this.duration = const Duration(seconds: 3),
    this.warmup = const Duration(seconds: 1),
  });

  List<BenchResult> get results => List.unmodifiable(_results);

  /// Runs [body] repeatedly. [body] receives the iteration index, so each call
  /// can work on a different row.
  ///
  /// If [setup] is given it runs before each [body] call, untimed, and its
  /// result is passed to [body] (e.g. a row created only to be deleted).
  Future<BenchResult> run<S>(
    String name,
    FutureOr<void> Function(int i, S setupValue) body, {
    FutureOr<S> Function(int i)? setup,
  }) async {
    var i = await _loop(body, setup, warmup, 0, null);

    var latencies = <int>[];
    await _loop(body, setup, duration, i, latencies);

    var result = BenchResult(name, latencies);
    _results.add(result);
    print(result);
    return result;
  }

  static Future<int> _loop<S>(
    FutureOr<void> Function(int i, S setupValue) body,
    FutureOr<S> Function(int i)? setup,
    Duration duration,
    int i,
    List<int>? latencies,
  ) async {
    var total = Stopwatch()..start();
    var call = Stopwatch();

    while (total.elapsed < duration) {
      var setupValue = setup != null ? await setup(i) : null as S;

      call
        ..reset()
        ..start();
      await body(i, setupValue);
      call.stop();

      latencies?.add(call.elapsedMicroseconds);
      ++i;
    }

    return i;
  }
}

class BenchResult {
  final String name;

  /// Latency of each call, in microseconds, sorted.
  final List<int> latencies;

  BenchResult(this.name, List<int> latencies)
    : latencies = List.unmodifiable(latencies.toList()..sort());

  int get operations => latencies.length;

  double get meanMicroseconds =>
      latencies.isEmpty ? 0 : latencies.reduce((a, b) => a + b) / operations;

  double get opsPerSecond =>
      meanMicroseconds > 0 ? 1000000 / meanMicroseconds : 0;

  /// The [p] percentile (`0..100`) latency, in microseconds.
  int percentile(num p) {
    if (latencies.isEmpty) return 0;
    var index = ((p / 100) * operations).ceil() - 1;
    return latencies[index.clamp(0, operations - 1)];
  }

  int get p50 => percentile(50);

  int get p95 => percentile(95);

  int get p99 => percentile(99);

  Map<String, Object> toJson() => {
    'name': name,
    'operations': operations,
    'opsPerSecond': opsPerSecond,
    'meanUs': meanMicroseconds,
    'p50Us': p50,
    'p95Us': p95,
    'p99Us': p99,
  };

  @override
  String toString() =>
      '-- $name: ${opsPerSecond.toStringAsFixed(0)} ops/sec '
      '(mean ${meanMicroseconds.toStringAsFixed(1)} us, p50 $p50 us, '
      'p95 $p95 us, p99 $p99 us; $operations calls)';
}
