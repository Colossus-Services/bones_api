import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

/// A pool of long-lived worker [Isolate]s, running computations like
/// [Isolate.run], with at most [maxIsolates] isolates at the same time.
///
/// - The workers are spawned on demand and reused: the state initialized
///   by a computation (e.g., the tables of an encoder) is kept between runs.
/// - A computation is queued (FIFO) while all the [maxIsolates] workers are
///   busy, instead of spawning a new isolate.
/// - A worker idle for [idleTimeout] exits (and is disposed): spawned
///   again on demand.
/// - An idle worker doesn't keep the current isolate (or the program)
///   alive.
/// - A computation that throws completes with a [RemoteError]. If a worker
///   exits (e.g., an unrecoverable error), its computation fails and the
///   worker is replaced on demand.
class APIIsolatePool {
  /// The default [maxIsolates]: see [defaultMaxIsolatesFor] (one worker).
  static int get defaultMaxIsolates => defaultMaxIsolatesFor();

  /// The default [maxIsolates] for each of [workers] isolates with their own
  /// pool (e.g., the `APIServerWorker`s): half of the processors divided by
  /// [workers], from `2` to `4`.
  static int defaultMaxIsolatesFor({int workers = 1}) => math.max(
    2,
    math.min(4, (Platform.numberOfProcessors ~/ 2) ~/ math.max(1, workers)),
  );

  /// The default [idleTimeout].
  static const Duration defaultIdleTimeout = Duration(seconds: 30);

  /// The maximum number of worker isolates (and concurrent computations).
  final int maxIsolates;

  /// The time a worker can stay idle before it exits and is disposed.
  /// If `null`, the workers don't exit when idle.
  final Duration? idleTimeout;

  /// The debug name of the worker isolates.
  final String debugName;

  APIIsolatePool({
    int? maxIsolates,
    this.idleTimeout = defaultIdleTimeout,
    this.debugName = 'APIIsolatePool',
  }) : maxIsolates = math.max(1, maxIsolates ?? defaultMaxIsolates);

  final List<_PoolWorker> _workers = [];
  final Queue<_PoolJob> _queue = Queue();

  bool _closed = false;

  /// Returns `true` if [close] was called.
  bool get isClosed => _closed;

  /// The number of worker isolates (spawned, spawning or exiting).
  int get isolatesLength => _workers.length;

  /// The number of computations running.
  int get runningLength => _workers.where((w) => w._job != null).length;

  /// The number of computations waiting for a worker.
  int get queuedLength => _queue.length;

  /// Runs [computation] in a worker isolate and returns its result.
  /// Same rules as [Isolate.run] for [computation] (it must be sendable)
  /// and its result.
  Future<R> run<R>(FutureOr<R> Function() computation) {
    if (_closed) {
      return Future.error(StateError("Closed `APIIsolatePool`: $debugName"));
    }

    final job = _PoolJob<R>(computation);
    _queue.add(job);
    _dispatch();
    return job.completer.future;
  }

  int _spawnCount = 0;

  void _dispatch() {
    while (_queue.isNotEmpty && !_closed) {
      var worker = _availableWorker();

      if (worker == null) {
        if (_workers.length >= maxIsolates) return;
        worker = _PoolWorker(this, '$debugName#${++_spawnCount}');
        _workers.add(worker);
      }

      worker._start(_queue.removeFirst());
    }
  }

  _PoolWorker? _availableWorker() {
    for (var w in _workers) {
      if (w._isAvailable) return w;
    }
    return null;
  }

  void _onWorkerExit(_PoolWorker worker) {
    _workers.remove(worker);
    _dispatch();
  }

  /// Closes this pool: the queued computations fail with a [StateError],
  /// the running ones complete, then the workers exit.
  void close() {
    if (_closed) return;
    _closed = true;

    while (_queue.isNotEmpty) {
      _queue.removeFirst()._fail(
        StateError("Closed `APIIsolatePool`: $debugName"),
        StackTrace.current,
      );
    }

    for (var w in _workers.toList()) {
      w._shutdown();
    }
  }

  @override
  String toString() =>
      'APIIsolatePool{name: $debugName, maxIsolates: $maxIsolates, '
      'isolates: $isolatesLength, running: $runningLength, queued: $queuedLength}';
}

class _PoolJob<R> {
  final FutureOr<R> Function() computation;
  final Completer<R> completer = Completer<R>();

  _PoolJob(this.computation);

  // The worker ran a `FutureOr<R> Function()`: the result is an `R`.
  void _complete(Object? result) {
    if (!completer.isCompleted) completer.complete(result as R);
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
  }
}

/// The message of a worker isolate idle for its `idleTimeout`.
const _workerIdleMessage = 'idle';

/// A worker isolate of an [APIIsolatePool].
///
/// Messages from the worker isolate:
/// - its [SendPort], when ready;
/// - `(true, result)` or `(false, (error, stackTrace))` per computation;
/// - [_workerIdleMessage] when idle for `idleTimeout`: the pool decides if
///   it exits (a computation may have been sent meanwhile);
/// - `null` when it exits (`onExit`).
///
/// Messages to the worker isolate: a computation, or `null` to exit.
class _PoolWorker {
  final APIIsolatePool _pool;
  final RawReceivePort _port = RawReceivePort();

  SendPort? _sendPort;
  _PoolJob? _job;
  bool _exiting = false;
  bool _exited = false;

  _PoolWorker(this._pool, String debugName) {
    _port.handler = _onMessage;
    // Only while computing (see `_start`):
    _port.keepIsolateAlive = false;

    Isolate.spawn(
      _workerMain,
      (_port.sendPort, _pool.idleTimeout?.inMicroseconds),
      onExit: _port.sendPort,
      errorsAreFatal: true,
      debugName: debugName,
    ).then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {
        _job?._fail(e, s);
        _job = null;
        _exit();
      },
    );
  }

  bool get _isAvailable => _job == null && !_exiting && !_exited;

  void _start(_PoolJob job) {
    _job = job;
    // Keeps the program alive while computing (as `Isolate.run` does):
    _port.keepIsolateAlive = true;

    final sendPort = _sendPort;
    if (sendPort != null) _send(sendPort, job);
  }

  void _send(SendPort sendPort, _PoolJob job) {
    try {
      sendPort.send(job.computation);
    } catch (e, s) {
      // Not sendable (e.g., the computation captures a `ReceivePort`):
      _jobDone();
      job._fail(e, s);
      _afterJob(sendPort);
    }
  }

  /// After a computation: exits if shutting down, otherwise takes the next.
  void _afterJob(SendPort? sendPort) {
    if (_exiting) {
      sendPort?.send(null);
    } else {
      _pool._dispatch();
    }
  }

  void _jobDone() {
    _job = null;
    _port.keepIsolateAlive = false;
  }

  void _onMessage(Object? message) {
    if (message == null) {
      _job?._fail(RemoteError("Worker isolate exited", ''), StackTrace.empty);
      _job = null;
      _exit();
      return;
    }

    if (message is SendPort) {
      _sendPort = message;
      final job = _job;
      if (job != null) {
        _send(message, job);
      } else if (_exiting) {
        message.send(null);
      }
      return;
    }

    if (message == _workerIdleMessage) {
      // Not if a computation was sent meanwhile (it resets the idle time):
      if (_job == null) _shutdown();
      return;
    }

    final job = _job;
    _jobDone();

    if (job != null) {
      var (ok, payload) = message as (bool, Object?);
      if (ok) {
        job._complete(payload);
      } else {
        var (error, stackTrace) = payload as (String, String);
        job._fail(
          RemoteError(error, stackTrace),
          StackTrace.fromString(stackTrace),
        );
      }
    }

    _afterJob(_sendPort);
  }

  /// Exits the worker isolate (after its current computation).
  /// It won't receive new computations.
  void _shutdown() {
    _exiting = true;
    if (_job == null) _sendPort?.send(null);
  }

  void _exit() {
    if (_exited) return;
    _exited = true;
    _port.close();
    _pool._onWorkerExit(this);
  }

  static void _workerMain((SendPort, int?) args) {
    final (reply, idleTimeoutUs) = args;

    final port = RawReceivePort();

    // The idle timer runs in the worker: in the pool's isolate it would keep
    // the program alive.
    Timer? idleTimer;
    void scheduleIdle() {
      if (idleTimeoutUs == null) return;
      idleTimer = Timer(
        Duration(microseconds: idleTimeoutUs),
        () => reply.send(_workerIdleMessage),
      );
    }

    port.handler = (Object? message) {
      idleTimer?.cancel();
      idleTimer = null;

      if (message == null) {
        port.close();
        return;
      }

      final computation = message as FutureOr<Object?> Function();

      Future.sync(computation)
          .then(
            (result) {
              try {
                reply.send((true, result));
              } catch (e, s) {
                // Result not sendable:
                reply.send((false, ('$e', '$s')));
              }
            },
            onError: (Object e, StackTrace s) {
              reply.send((false, ('$e', '$s')));
            },
          )
          .whenComplete(scheduleIdle);
    };

    reply.send(port.sendPort);
    scheduleIdle();
  }
}
