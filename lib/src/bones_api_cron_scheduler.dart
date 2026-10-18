import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart' as logging;

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_cron.dart';
import 'bones_api_cron_store.dart';

final _log = logging.Logger('APICron');

/// Calls the routes of the [APICronJob]s of an [APIRoot] on their schedules.
///
/// - Each occurrence runs once: its run is claimed in the [store]
///   ([APICronStore.claimRun]), also among several instances of the API.
/// - A job never runs in parallel: its lock ([APICronStore.acquireLock]) is
///   held (and renewed) while running. A run interrupted (the instance
///   stopped) is resumed by any instance after its lock lease expires,
///   from its last continuation token.
/// - A missed occurrence (the servers were down) runs once if not older than
///   [APICronJob.maxLateness]; older ones between the last run and it are
///   recorded as [APICronRunStatus.skipped].
/// - The calls follow the `X-Continuation` header ([APIResponse.continuation])
///   and are retried by [APICronJob.retry].
///
/// Started by [APIRoot] when the config `cron.enabled` is `true` (see
/// [APICronConfig]); one scheduler per process (not in the auxiliary
/// workers).
class APICronScheduler {
  /// The maximum missed occurrences recorded as skipped per check.
  static const int maxSkippedRecords = 100;

  final APIRoot apiRoot;

  final APICronStore store;

  /// How often the due jobs are checked.
  final Duration checkInterval;

  /// The days the run history is kept (`0`: forever).
  final int historyDays;

  /// The ID of this scheduler instance (the owner of its runs and locks).
  final String owner;

  final DateTime Function() _clock;

  final Future<void> Function(Duration delay) _sleep;

  final Map<String, APICronJob> _jobs;

  APICronScheduler(
    this.apiRoot,
    Iterable<APICronJob> jobs, {
    APICronStore? store,
    this.checkInterval = const Duration(seconds: 30),
    this.historyDays = 90,
    String? owner,
    DateTime Function()? clock,
    Future<void> Function(Duration delay)? sleep,
  }) : store = store ?? APICronStoreMemory(),
       owner = owner ?? _generateOwner(apiRoot),
       _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _jobs = _indexJobs(jobs);

  static Map<String, APICronJob> _indexJobs(Iterable<APICronJob> jobs) {
    var map = <String, APICronJob>{};
    for (var job in jobs) {
      if (map.containsKey(job.name)) {
        throw ArgumentError('Duplicated cron job name: ${job.name}');
      }
      map[job.name] = job;
    }
    return map;
  }

  static String _generateOwner(APIRoot apiRoot) {
    var rand = math.Random.secure().nextInt(0x7fffffff).toRadixString(36);
    var t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${apiRoot.name}#$t-$rand';
  }

  /// Merges the jobs of [sources] (by name: a later job replaces an earlier
  /// one) and applies [config] (the `cron.jobs` config): a config entry
  /// overrides the job of its name, or adds a new job (with `schedule` and
  /// `path`).
  static List<APICronJob> mergeJobs(
    Iterable<Iterable<APICronJob>> sources,
    Map<String, Map> config,
  ) {
    var jobs = <String, APICronJob>{};
    for (var source in sources) {
      for (var job in source) {
        jobs[job.name] = job;
      }
    }

    for (var e in config.entries) {
      var base = jobs[e.key];
      jobs[e.key] = base != null
          ? base.withConfig(e.value)
          : APICronJob.fromConfig(e.key, e.value);
    }

    return jobs.values.toList();
  }

  /// The jobs, by name.
  Map<String, APICronJob> get jobs => Map.unmodifiable(_jobs);

  DateTime get _now => _clock().toUtc();

  Timer? _timer;

  bool _started = false;

  bool get isStarted => _started;

  /// Set by [stop]: the running jobs stop after their current call.
  bool _stopping = false;

  /// The jobs running in this instance.
  final Map<String, Future<APICronJobRun?>> _running = {};

  Set<String> get runningJobs => _running.keys.toSet();

  /// Starts the periodic checks (and checks once now).
  void start() {
    if (_started) return;
    _started = true;
    _stopping = false;

    var now = _now;
    var enabled = _jobs.values.where((j) => j.enabled).toList();

    _log.info(
      'Started: owner=$owner, checkInterval=$checkInterval, '
      'jobs=${enabled.length}/${_jobs.length}',
    );
    for (var job in _jobs.values) {
      _log.info(
        '  - $job${job.enabled ? ' -> next: ${job.nextAfter(now)?.toIso8601String()}' : ''}',
      );
    }

    _timer = Timer.periodic(checkInterval, (_) => _tickSafe());
    _tickSafe();
  }

  /// Stops the periodic checks. A running job stops after its current call
  /// (not cancelled): its run is left `running` and its lock released, so
  /// another instance resumes it from its continuation. See [waitRunning].
  void stop() {
    if (!_started) return;
    _started = false;
    _stopping = true;
    _timer?.cancel();
    _timer = null;
    _log.info('Stopped: owner=$owner, running=${runningJobs.toList()}');
  }

  /// Waits for the jobs running in this instance (e.g. after [stop]).
  Future<void> waitRunning() async {
    while (_running.isNotEmpty) {
      await Future.wait(
        _running.values.map((f) => f.then((_) {}, onError: (_) {})),
      );
    }
  }

  void _tickSafe() {
    tick().catchError((e, s) {
      _log.severe('Tick error', e, s);
      return <APICronJobRun>[];
    });
  }

  /// Checks the due jobs and runs them. Completes when the runs started by
  /// this check finish (with their runs).
  Future<List<APICronJobRun>> tick() async {
    // Started by `APIRoot.initialize`: the modules and repositories may still
    // be initializing.
    await apiRoot.ensureInitialized();

    var futures = <Future<APICronJobRun?>>[];

    for (var job in _jobs.values) {
      if (!job.enabled) continue;
      if (_running.containsKey(job.name)) continue;

      var f = _checkJob(job);
      _running[job.name] = f;
      futures.add(
        f.whenComplete(() => _running.remove(job.name)).catchError((e, s) {
          _log.severe('Job `${job.name}` error', e, s);
          return null;
        }),
      );
    }

    var runs = await Future.wait(futures);
    return runs.nonNulls.toList();
  }

  /// Runs the job [name] now (an occurrence at the current time), with the
  /// same lock and claim of a scheduled run. `null` if the job is unknown,
  /// already running or locked by another instance.
  Future<APICronJobRun?> runNow(String name) async {
    var job = _jobs[name];
    if (job == null) {
      throw ArgumentError.value(name, 'name', 'Unknown cron job');
    }

    if (_running.containsKey(name)) return null;

    var now = _now;
    // A scheduled occurrence is at second `0`: a manual run never takes its
    // slot (seconds are kept by every DB, unlike milliseconds).
    var occurrence = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second == 0 ? 1 : now.second,
    );

    var f = _runWithLock(job, occurrence, manual: true);
    _running[name] = f;
    try {
      return await f;
    } finally {
      _running.remove(name);
    }
  }

  /// The latest runs of the job [name].
  FutureOr<List<APICronJobRun>> selectRuns(String name, {int limit = 20}) =>
      store.selectRuns(name, limit: limit);

  Future<APICronJobRun?> _checkJob(APICronJob job) async {
    var now = _now;

    var occurrence = job.previousBefore(now)?.toUtc();

    var stale = await _hasStaleRun(job, now);

    if (occurrence == null && !stale) return null;

    var lateness = occurrence != null ? now.difference(occurrence) : null;
    var tooLate = lateness != null && lateness > job.maxLateness;

    if (occurrence != null && !tooLate) {
      var existing = await store.getRun(job.name, occurrence);
      if (existing != null && existing.isFinished && !stale) return null;
    } else if (!stale) {
      return null;
    }

    return _runWithLock(job, tooLate ? null : occurrence);
  }

  /// A run of [job] still `running` without a valid lock: interrupted.
  Future<bool> _hasStaleRun(APICronJob job, DateTime now) async {
    var running = await store.selectRunningRuns(job.name);
    if (running.isEmpty) return false;

    var lock = await store.getLock(job.name);
    return lock == null || lock.isExpired(now);
  }

  Future<APICronJobRun?> _runWithLock(
    APICronJob job,
    DateTime? occurrence, {
    bool manual = false,
  }) async {
    var now = _now;

    var lock = await store.acquireLock(
      job.name,
      owner,
      job.leaseDuration,
      now: now,
    );

    if (lock == null) {
      var current = await store.getLock(job.name);
      _log.fine(
        'Job `${job.name}` locked by `${current?.owner}` until '
        '${current?.leaseUntil.toIso8601String()}',
      );
      return null;
    }

    var renewer = _LockRenewer(this, job, lock);

    try {
      // Interrupted runs first (resumed from their continuation):
      var running = await store.selectRunningRuns(job.name);
      running.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      APICronJobRun? last;

      for (var run in running) {
        var previousOwner = run.owner;
        if (previousOwner != owner) {
          _log.warning(
            'Resuming interrupted run of `${job.name}` '
            '(${run.scheduledAt.toIso8601String()}, owner `$previousOwner`, '
            'calls ${run.calls}, continuation: ${run.continuation != null})',
          );
        }
        run.owner = owner;
        last = await _execute(job, run, renewer, previousOwner: previousOwner);
        if (_isInterrupted(renewer)) return last;
      }

      if (occurrence == null) return last;

      var existing = await store.getRun(job.name, occurrence);
      if (existing != null) return last ?? existing;

      if (!manual) {
        await _recordSkipped(job, occurrence);
      }

      var run = await store.claimRun(
        APICronJobRun(job.name, occurrence, owner: owner, startedAt: _now),
      );

      if (run == null) {
        _log.fine(
          'Job `${job.name}` occurrence ${occurrence.toIso8601String()} '
          'already claimed',
        );
        return last;
      }

      return await _execute(job, run, renewer);
    } finally {
      renewer.stop();
      if (!renewer.lost) {
        await store.releaseLock(lock);
      }
      await _pruneHistory(job);
    }
  }

  /// Records the occurrences between the last run of [job] and [occurrence]
  /// (exclusive) as skipped.
  Future<void> _recordSkipped(APICronJob job, DateTime occurrence) async {
    var last = await store.lastRun(job.name);
    if (last == null) return;

    var skipped = <DateTime>[];
    var t = job.nextAfter(last.scheduledAt)?.toUtc();
    while (t != null &&
        t.isBefore(occurrence) &&
        skipped.length < maxSkippedRecords) {
      skipped.add(t);
      t = job.nextAfter(t)?.toUtc();
    }

    if (skipped.isEmpty) return;

    _log.warning(
      'Job `${job.name}`: ${skipped.length} missed occurrence(s) skipped '
      '(${skipped.first.toIso8601String()} .. ${skipped.last.toIso8601String()})',
    );

    var now = _now;
    for (var s in skipped) {
      var run = APICronJobRun(
        job.name,
        s,
        status: APICronRunStatus.skipped,
        owner: owner,
      )..finishedAt = now;
      await store.claimRun(run);
    }
  }

  /// Deletes the runs of [job] older than [historyDays], but never one still
  /// in the [APICronJob.maxLateness] window: without its run, that
  /// occurrence would be due (and run) again.
  Future<void> _pruneHistory(APICronJob job) async {
    if (historyDays <= 0) return;
    try {
      var now = _now;
      var before = now.subtract(Duration(days: historyDays));

      // One more day of margin (the occurrences checked are in the window):
      var lateness = now.subtract(job.maxLateness + const Duration(days: 1));
      if (lateness.isBefore(before)) before = lateness;

      var n = await store.deleteRunsBefore(job.name, before);
      if (n > 0) {
        _log.fine('Job `${job.name}`: $n old run(s) deleted');
      }
    } catch (e, s) {
      _log.warning('Job `${job.name}`: error deleting old runs', e, s);
    }
  }

  /// The run must stop: the lock was lost (taken over by another instance)
  /// or this scheduler is stopping.
  bool _isInterrupted(_LockRenewer renewer) => renewer.lost || _stopping;

  Future<APICronJobRun> _execute(
    APICronJob job,
    APICronJobRun run,
    _LockRenewer renewer, {
    String? previousOwner,
  }) async {
    var started = _now;
    run.startedAt ??= started;
    run.status = APICronRunStatus.running;

    if (!await store.updateRun(run, previousOwner: previousOwner)) {
      _log.warning(
        'Run `${job.name}` (${run.scheduledAt.toIso8601String()}): '
        'taken by another instance',
      );
      return run;
    }

    _log.info(
      'Run `${job.name}` (${run.scheduledAt.toIso8601String()}): started, '
      'owner=$owner${run.calls > 0 ? ', resuming after ${run.calls} call(s)' : ''}',
    );

    renewer.start();

    String? error;
    var succeeded = false;
    String? interrupted;

    try {
      while (true) {
        if (_isInterrupted(renewer)) break;

        if (run.calls >= job.maxCalls) {
          error = 'Max calls reached (${job.maxCalls}) with a continuation';
          _log.warning('Run `${job.name}`: $error');
          break;
        }

        var (response, callError) = await _callWithRetry(job, run, renewer);

        // Lost or stopping during the call: nothing more is written.
        if (_isInterrupted(renewer)) break;

        if (response == null) {
          error = callError;
          break;
        }

        run.calls++;

        var continuation = response.continuation;
        if (continuation != null &&
            continuation.length > APICronJobRun.maxContinuationLength) {
          error =
              'Continuation token too long: ${continuation.length} > '
              '${APICronJobRun.maxContinuationLength}';
          break;
        }

        run.continuation = continuation;

        if (!await store.updateRun(run)) {
          interrupted = 'taken by another instance';
          break;
        }

        if (continuation == null) {
          succeeded = true;
          break;
        }
      }
    } catch (e, s) {
      // Never left `running` by an error (it would be resumed again and
      // again): failed.
      error = 'Error: $e';
      _log.severe('Run `${job.name}`: error', e, s);
    }

    interrupted ??= renewer.lost
        ? 'lock lost'
        : (_stopping ? 'scheduler stopped' : null);

    if (interrupted != null) {
      // Left `running`: resumed by the new owner (or another instance).
      _log.warning(
        'Run `${job.name}` (${run.scheduledAt.toIso8601String()}): '
        '$interrupted, left running after ${run.calls} call(s)',
      );
      return run;
    }

    var finished = _now;
    run.finishedAt = finished;
    run.durationMs = finished
        .difference(run.startedAt ?? started)
        .inMilliseconds;
    run.status = succeeded
        ? APICronRunStatus.succeeded
        : APICronRunStatus.failed;
    run.lastError = succeeded ? null : error;

    var stored = false;
    try {
      stored = await store.updateRun(run);
    } catch (e, s) {
      _log.severe('Run `${job.name}`: error storing its result', e, s);
    }

    var msg =
        'Run `${job.name}` (${run.scheduledAt.toIso8601String()}): '
        '${run.status.name}, calls=${run.calls}, attempts=${run.attempts}, '
        'duration=${run.durationMs}ms${stored ? '' : ' (not stored)'}';

    if (succeeded) {
      _log.info(msg);
    } else {
      _log.severe('$msg, error: $error');
    }

    return run;
  }

  /// Calls the route of [job], with the [APICronJob.retry] attempts.
  ///
  /// A call slower than [APICronJob.timeout] is logged but not cancelled (a
  /// route can't be cancelled) nor retried while running: it's waited for,
  /// so the job never runs in parallel, and its result is used.
  Future<(APIResponse?, String?)> _callWithRetry(
    APICronJob job,
    APICronJobRun run,
    _LockRenewer renewer,
  ) async {
    var retry = job.retry;
    String? lastError;

    for (var attempt = 1; attempt <= retry.attempts; attempt++) {
      if (_isInterrupted(renewer)) return (null, 'Interrupted');

      run.attempts++;

      var request = _buildRequest(job, run, attempt);
      var callStart = _now;

      APIResponse? response;
      Object? error;
      var retryable = true;

      var call = Future<APIResponse>.sync(() => apiRoot.call(request));

      try {
        response = await _waitCall(job, run, call);
      } catch (e) {
        error = e;
      }

      var ms = _now.difference(callStart).inMilliseconds;

      if (response != null) {
        if (response.isOK || response.isNotModified) {
          _log.info(
            'Run `${job.name}`: call ${run.calls + 1} ${response.status.name} '
            '(${ms}ms)${response.continuation != null ? ', continuation' : ''}',
          );
          return (response, null);
        }

        retryable = retry.isRetryable(response);
        error =
            '${response.status.name}: ${response.error ?? response.payload}';
      }

      lastError = '$error';

      if (!retryable || attempt >= retry.attempts) {
        _log.warning(
          'Run `${job.name}`: call ${run.calls + 1} failed '
          '(attempt $attempt/${retry.attempts}, ${ms}ms): $lastError',
        );
        break;
      }

      var delay =
          _retryAfter(response, retry.maxDelay) ?? retry.delayFor(attempt);

      _log.warning(
        'Run `${job.name}`: call ${run.calls + 1} failed '
        '(attempt $attempt/${retry.attempts}, ${ms}ms), retrying in $delay: '
        '$lastError',
      );

      if (_isInterrupted(renewer)) return (null, lastError);
      await _sleep(delay);
    }

    return (null, lastError);
  }

  /// Waits for [call], logging it every [APICronJob.timeout] while it's
  /// still running (it's never abandoned: see [_callWithRetry]).
  Future<APIResponse> _waitCall(
    APICronJob job,
    APICronJobRun run,
    Future<APIResponse> call,
  ) async {
    var waited = Duration.zero;
    while (true) {
      try {
        var response = await call.timeout(job.timeout);
        if (waited > Duration.zero) {
          _log.warning(
            'Run `${job.name}`: call ${run.calls + 1} finished after its '
            'timeout (${job.timeout}): ${response.status.name}',
          );
        }
        return response;
      } on TimeoutException {
        waited += job.timeout;
        _log.warning(
          'Run `${job.name}`: call ${run.calls + 1} still running after '
          '$waited (timeout ${job.timeout}): waiting for it',
        );
      }
    }
  }

  /// The `Retry-After` delay (in seconds) of [response], at most [maxDelay].
  static Duration? _retryAfter(APIResponse? response, Duration maxDelay) {
    var v = response?.getHeader('Retry-After');
    if (v == null) return null;
    var secs = int.tryParse(v.trim());
    if (secs == null || secs < 0) return null;
    var delay = Duration(seconds: secs);
    return delay > maxDelay ? maxDelay : delay;
  }

  APIRequest _buildRequest(APICronJob job, APICronJobRun run, int attempt) {
    var parameters = <String, dynamic>{
      ...job.parameters,
      if (run.continuation != null)
        APICronJob.parameterContinuation: run.continuation,
    };

    var request = APIRequest(
      job.method,
      job.path,
      parameters: parameters,
      payload: job.payload,
      headers: {
        APICronJob.headerJob: job.name,
        APICronJob.headerScheduledAt: run.scheduledAt.toIso8601String(),
        if (run.id != null) APICronJob.headerRun: '${run.id}',
        APICronJob.headerAttempt: '$attempt',
      },
      requesterAddress: 'internal',
    );

    request.authentication = APIAuthentication.system('cron:${job.name}');

    return request;
  }

  @override
  String toString() =>
      'APICronScheduler{owner: $owner, started: $_started, jobs: ${_jobs.keys.toList()}}';
}

/// Renews the lock of a running job every `leaseDuration / 3`.
class _LockRenewer {
  final APICronScheduler scheduler;
  final APICronJob job;
  final APICronJobLock lock;

  _LockRenewer(this.scheduler, this.job, this.lock);

  Timer? _timer;

  bool lost = false;

  bool _renewing = false;

  Duration get _every => Duration(
    milliseconds: math.max(1, job.leaseDuration.inMilliseconds ~/ 3),
  );

  void start() {
    if (_timer != null || lost) return;
    _timer = Timer.periodic(_every, (_) => _renew());
  }

  Future<void> _renew() async {
    if (_renewing || lost) return;
    _renewing = true;
    try {
      var ok = await scheduler.store.renewLock(
        lock,
        job.leaseDuration,
        now: scheduler._now,
      );
      if (!ok) {
        _lose('taken over');
      }
    } catch (e, s) {
      _log.warning('Job `${job.name}`: error renewing lock', e, s);
      // Without a renewal the lease runs out, and another instance may take
      // the lock over: considered lost before that (one renewal of margin).
      if (!scheduler._now.isBefore(lock.leaseUntil.subtract(_every))) {
        _lose('lease about to expire without renewal');
      }
    } finally {
      _renewing = false;
    }
  }

  void _lose(String reason) {
    lost = true;
    _log.warning('Job `${job.name}`: lock lost ($reason)');
    stop();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
