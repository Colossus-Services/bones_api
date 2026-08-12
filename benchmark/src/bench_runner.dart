import 'dart:async';

/// A minimal benchmark runner.
///
/// Deliberately dependency-free: `bones_api` ships `benchmark/` inside the
/// published package, so adding a benchmarking dependency would push it onto
/// every consumer.
class BenchRunner {
  /// Time each benchmark is measured for, after warm-up.
  final Duration measure;

  /// Time each benchmark runs before any measurement, to let the JIT settle.
  final Duration warmup;

  final List<BenchResult> _results = [];

  BenchRunner({
    this.measure = const Duration(seconds: 2),
    this.warmup = const Duration(milliseconds: 500),
  });

  List<BenchResult> get results => List.unmodifiable(_results);

  /// Runs a synchronous [body] and records its throughput.
  ///
  /// [body] must return something derived from the work, which is accumulated
  /// into a sink so the optimizer can't eliminate the call.
  BenchResult run(String name, Object? Function() body) {
    _consume(_loopSync(body, warmup));

    var (ops, elapsed, sink) = _loopSync(body, measure);
    _consume(sink);

    var result = BenchResult(name, ops, elapsed);
    _results.add(result);
    print(result);
    return result;
  }

  /// Runs an asynchronous [body] and records its throughput.
  Future<BenchResult> runAsync(
    String name,
    FutureOr<Object?> Function() body,
  ) async {
    _consume(await _loopAsync(body, warmup));

    var (ops, elapsed, sink) = await _loopAsync(body, measure);
    _consume(sink);

    var result = BenchResult(name, ops, elapsed);
    _results.add(result);
    print(result);
    return result;
  }

  static (int, Duration, int) _loopSync(
    Object? Function() body,
    Duration duration,
  ) {
    var sink = 0;
    var ops = 0;
    var chronometer = Stopwatch()..start();

    // Checking the clock every iteration would dominate a cheap body:
    while (chronometer.elapsed < duration) {
      for (var i = 0; i < 64; ++i) {
        sink ^= body().hashCode;
      }
      ops += 64;
    }

    chronometer.stop();
    return (ops, chronometer.elapsed, sink);
  }

  static Future<(int, Duration, int)> _loopAsync(
    FutureOr<Object?> Function() body,
    Duration duration,
  ) async {
    var sink = 0;
    var ops = 0;
    var chronometer = Stopwatch()..start();

    while (chronometer.elapsed < duration) {
      for (var i = 0; i < 16; ++i) {
        sink ^= (await body()).hashCode;
      }
      ops += 16;
    }

    chronometer.stop();
    return (ops, chronometer.elapsed, sink);
  }

  /// Keeps the accumulated value observable, so the body can't be optimized
  /// away as dead code.
  static int blackHole = 0;

  static void _consume(Object? o) {
    if (o is (int, Duration, int)) {
      blackHole ^= o.$3;
    } else if (o is int) {
      blackHole ^= o;
    }
  }

  /// Prints a summary table, and a comparison against [baseline] if given.
  void report({Map<String, double>? baseline}) {
    if (_results.isEmpty) return;

    var nameWidth = _results
        .map((e) => e.name.length)
        .reduce((a, b) => a > b ? a : b);

    print('');
    print(
      '${'BENCHMARK'.padRight(nameWidth)}  ${'OPS/SEC'.padLeft(12)}  '
      '${'US/OP'.padLeft(10)}${baseline != null ? '  ${'VS BASE'.padLeft(9)}' : ''}',
    );
    print('-' * (nameWidth + (baseline != null ? 38 : 27)));

    for (var r in _results) {
      var line =
          '${r.name.padRight(nameWidth)}  '
          '${r.opsPerSecond.toStringAsFixed(0).padLeft(12)}  '
          '${r.microsecondsPerOp.toStringAsFixed(3).padLeft(10)}';

      var base = baseline?[r.name];
      if (base != null && base > 0) {
        var delta = ((r.opsPerSecond / base) - 1) * 100;
        var sign = delta >= 0 ? '+' : '';
        line += '  ${'$sign${delta.toStringAsFixed(1)}%'.padLeft(9)}';
      }

      print(line);
    }
    print('');
  }

  /// The results as a `name: opsPerSecond` map, to be pasted as a baseline.
  Map<String, double> asBaseline() => {
    for (var r in _results) r.name: r.opsPerSecond,
  };
}

class BenchResult {
  final String name;
  final int operations;
  final Duration elapsed;

  BenchResult(this.name, this.operations, this.elapsed);

  double get opsPerSecond => operations / (elapsed.inMicroseconds / 1000000);

  double get microsecondsPerOp => elapsed.inMicroseconds / operations;

  @override
  String toString() =>
      '-- $name: ${opsPerSecond.toStringAsFixed(0)} ops/sec '
      '(${microsecondsPerOp.toStringAsFixed(3)} us/op)';
}
