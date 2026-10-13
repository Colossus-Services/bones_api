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

  /// Rounds of [duration] measured per operation, back to back. The result
  /// is the median round (by ops/sec), with the range of all of them.
  ///
  /// Throughput can vary between rounds by more than a change being
  /// measured (e.g. CPU power states when calls wait on a database, see the
  /// README): the median of several rounds is far more stable than one.
  final int repeat;

  final List<BenchResult> _results = [];

  BenchRunner({
    this.duration = const Duration(seconds: 3),
    this.warmup = const Duration(seconds: 1),
    this.repeat = 1,
  }) {
    if (repeat < 1) {
      throw ArgumentError.value(repeat, 'repeat', 'must be >= 1');
    }
  }

  List<BenchResult> get results => List.unmodifiable(_results);

  /// Runs [body] repeatedly. [body] receives the iteration index, so each call
  /// can work on a different row.
  ///
  /// If [setup] is given it runs before each [body] call, untimed, and its
  /// result is passed to [body] (e.g. a row created only to be deleted).
  ///
  /// If [afterRound] is given it runs after the warm-up and after each
  /// round, untimed (e.g. to remove the rows a round inserted, so every
  /// round, and the next operations, run on the same table sizes).
  Future<BenchResult> run<S>(
    String name,
    FutureOr<void> Function(int i, S setupValue) body, {
    FutureOr<S> Function(int i)? setup,
    FutureOr<void> Function()? afterRound,
  }) async {
    var i = await _loop(body, setup, warmup, 0, null);
    await afterRound?.call();

    var rounds = <List<int>>[];
    for (var r = 0; r < repeat; ++r) {
      var latencies = <int>[];
      i = await _loop(body, setup, duration, i, latencies);
      await afterRound?.call();
      rounds.add(latencies);
    }

    var result = BenchResult.median(name, rounds);
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

  /// The ops/sec of each measured round, sorted (one entry without
  /// [BenchRunner.repeat]).
  final List<double> roundsOpsPerSecond;

  BenchResult(
    this.name,
    List<int> latencies, {
    List<double>? roundsOpsPerSecond,
  }) : latencies = List.unmodifiable(latencies.toList()..sort()),
       roundsOpsPerSecond = List.unmodifiable(
         (roundsOpsPerSecond ?? [_opsPerSecond(latencies)]).toList()..sort(),
       );

  /// The round with the median ops/sec of [rounds] (the lower middle one
  /// for an even count), keeping every round's ops/sec.
  factory BenchResult.median(String name, List<List<int>> rounds) {
    var byOps = rounds.toList()
      ..sort((a, b) => _opsPerSecond(a).compareTo(_opsPerSecond(b)));
    var median = byOps[(byOps.length - 1) ~/ 2];
    return BenchResult(
      name,
      median,
      roundsOpsPerSecond: rounds.map(_opsPerSecond).toList(),
    );
  }

  static double _opsPerSecond(List<int> latencies) {
    if (latencies.isEmpty) return 0;
    var mean = latencies.reduce((a, b) => a + b) / latencies.length;
    return mean > 0 ? 1000000 / mean : 0;
  }

  int get rounds => roundsOpsPerSecond.length;

  /// The ops/sec range of the rounds, e.g. `512–578` (empty for one round).
  String get roundsRange => rounds > 1
      ? '${roundsOpsPerSecond.first.toStringAsFixed(0)}'
            '–${roundsOpsPerSecond.last.toStringAsFixed(0)}'
      : '';

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
    'roundsOpsPerSecond': roundsOpsPerSecond,
  };

  @override
  String toString() =>
      '-- $name: ${opsPerSecond.toStringAsFixed(0)} ops/sec '
      '(mean ${meanMicroseconds.toStringAsFixed(1)} us, p50 $p50 us, '
      'p95 $p95 us, p99 $p99 us; $operations calls'
      '${rounds > 1 ? '; median of $rounds rounds: $roundsRange' : ''})';
}
