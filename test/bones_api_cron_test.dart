@TestOn('vm')
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart' as tz;

part 'bones_api_cron_test.reflection.g.dart';

/// The calls received by the test routes.
class _Calls {
  final List<APIRequest> requests = [];

  int flakyFailures = 0;

  String? retryAfter;

  Duration slowDelay = Duration.zero;

  Completer<void>? block;

  void clear() {
    requests.clear();
    flakyFailures = 0;
    retryAfter = null;
    slowDelay = Duration.zero;
    block = null;
  }

  List<APIRequest> of(String route) =>
      requests.where((r) => r.path.endsWith('/$route')).toList();
}

final _calls = _Calls();

class _JobsModule extends APIModule {
  _JobsModule(APIRoot apiRoot) : super(apiRoot, 'jobs');

  @override
  void configure() {
    routes.any('ok', (request) {
      _calls.requests.add(request);
      return APIResponse.ok('ok');
    });

    // 3 pages: `continuation` is the last page done.
    routes.any('pages', (request) {
      _calls.requests.add(request);
      var done = int.tryParse('${request.getParameter('continuation')}') ?? 0;
      var page = done + 1;
      var response = APIResponse.ok('page $page');
      if (page < 3) response.continuation = '$page';
      return response;
    });

    // As `pages`, but the first call waits for `_calls.block`:
    routes.any('pages2', (request) async {
      _calls.requests.add(request);
      var done = int.tryParse('${request.getParameter('continuation')}') ?? 0;
      if (done == 0) await _calls.block?.future;
      var page = done + 1;
      var response = APIResponse.ok('page $page');
      if (page < 3) response.continuation = '$page';
      return response;
    });

    routes.any('longToken', (request) {
      _calls.requests.add(request);
      return APIResponse.ok('more')
        ..continuation = 'x' * (APICronJobRun.maxContinuationLength + 1);
    });

    routes.any('infinite', (request) {
      _calls.requests.add(request);
      return APIResponse.ok('more')..continuation = 'x';
    });

    routes.any('flaky', (request) {
      _calls.requests.add(request);
      if (_calls.flakyFailures > 0) {
        _calls.flakyFailures--;
        return APIResponse.error(
          error: 'flaky',
          headers: {
            if (_calls.retryAfter != null) 'Retry-After': _calls.retryAfter,
          },
        );
      }
      return APIResponse.ok('ok');
    });

    routes.any('bad', (request) {
      _calls.requests.add(request);
      return APIResponse.badRequest(payload: 'bad');
    });

    routes.any('throws', (request) {
      _calls.requests.add(request);
      throw StateError('boom');
    });

    routes.any('slow', (request) async {
      _calls.requests.add(request);
      await Future.delayed(_calls.slowDelay);
      return APIResponse.ok('slow');
    });

    routes.any('blocked', (request) async {
      _calls.requests.add(request);
      await _calls.block?.future;
      return APIResponse.ok('blocked');
    });

    routes.any('auth', (request) {
      _calls.requests.add(request);
      return APIResponse.ok(request.authentication?.username);
    }, rules: [const APIRouteAuthenticatedRule()]);
  }
}

@EnableReflection()
class CronReflectedModule extends APIModule {
  CronReflectedModule(APIRoot apiRoot) : super(apiRoot, 'reflected');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  @APICron('*/5 * * * *', timeZone: 'Europe/Paris', maxCalls: 7)
  APIResponse<String> refresh(APIRequest request) {
    _calls.requests.add(request);
    return APIResponse.ok('refreshed');
  }

  @APICron(
    '0 1 * * *',
    name: 'daily-report',
    parameters: {'kind': 'daily'},
    timeout: Duration(minutes: 2),
    maxLateness: Duration(hours: 6),
    leaseDuration: Duration(minutes: 10),
    retry: APICronRetry(attempts: 4, initialDelay: Duration(minutes: 1)),
  )
  APIResponse<String> report(APIRequest request) {
    _calls.requests.add(request);
    return APIResponse.ok('report ${request.getParameter('kind')}');
  }

  @APICron.at(
    minute: '*/15',
    hour: '9-18',
    dayOfWeek: 'MON-FRI',
    timeZone: 'America/Sao_Paulo',
    attempts: 2,
    retry: APICronRetry(attempts: 5, initialDelay: Duration(seconds: 10)),
  )
  APIResponse<String> workHours(APIRequest request) {
    _calls.requests.add(request);
    return APIResponse.ok('work');
  }

  APIResponse<String> notScheduled(APIRequest request) => APIResponse.ok('no');
}

class _CronAPIRoot extends APIRoot {
  final List<APICronJob> codeJobs;
  final APICronStore? store;

  _CronAPIRoot({
    Map<String, dynamic>? config,
    this.codeJobs = const [],
    this.store,
  }) : super('cron-test', '1.0', apiConfig: config);

  @override
  Set<APIModule> loadModules() => {
    _JobsModule(this),
    CronReflectedModule(this),
  };

  @override
  FutureOr<List<APICronJob>> loadCronJobs() => codeJobs;

  @override
  FutureOr<APICronStore> loadCronStore() => store ?? super.loadCronStore();
}

DateTime _utc(int y, int m, int d, [int h = 0, int min = 0, int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s);

/// An [APICronStoreMemory] with failures and counters, for the error paths.
class _TestStore extends APICronStoreMemory {
  bool failSelectRunning = false;
  bool failDelete = false;
  bool failRenew = false;

  /// [getRun] always returns `null` (a run claimed meanwhile by another
  /// instance, not seen by the check).
  bool hideRuns = false;

  int renewals = 0;

  /// [updateRun] throws after this many calls.
  int? failUpdateAfter;

  int updates = 0;

  @override
  APICronJobRun? getRun(String job, DateTime scheduledAt) =>
      hideRuns ? null : super.getRun(job, scheduledAt);

  @override
  bool updateRun(APICronJobRun run, {String? previousOwner}) {
    var failAfter = failUpdateAfter;
    if (failAfter != null && ++updates > failAfter) {
      throw StateError('update failed');
    }
    return super.updateRun(run, previousOwner: previousOwner);
  }

  @override
  List<APICronJobRun> selectRunningRuns(String job) {
    if (failSelectRunning) throw StateError('store down');
    return super.selectRunningRuns(job);
  }

  @override
  int deleteRunsBefore(String job, DateTime before) {
    if (failDelete) throw StateError('delete failed');
    return super.deleteRunsBefore(job, before);
  }

  @override
  bool renewLock(APICronJobLock lock, Duration lease, {DateTime? now}) {
    renewals++;
    if (failRenew) throw StateError('renew failed');
    return super.renewLock(lock, lease, now: now);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('CronExpression', () {
    test('parse: fields, lists, ranges, steps, names', () {
      var c = CronExpression.parse('*/15 9-17 1,15 JAN-MAR MON-FRI');
      expect(c.minutes, equals({0, 15, 30, 45}));
      expect(c.hours, equals({9, 10, 11, 12, 13, 14, 15, 16, 17}));
      expect(c.daysOfMonth, equals({1, 15}));
      expect(c.months, equals({1, 2, 3}));
      expect(c.daysOfWeek, equals({1, 2, 3, 4, 5}));

      expect(CronExpression.parse('5/20 * * * *').minutes, equals({5, 25, 45}));
      expect(
        CronExpression.parse('0-30/10 * * * *').minutes,
        equals({0, 10, 20, 30}),
      );
      expect(CronExpression.parse('0 0 * * 7').daysOfWeek, equals({0}));
      expect(
        CronExpression.parse('0 0 * * sun,SAT').daysOfWeek,
        equals({0, 6}),
      );
    });

    test('macros', () {
      expect(CronExpression.parse('@daily').matches(_utc(2026, 5, 3)), isTrue);
      expect(CronExpression.parse('@hourly').minutes, equals({0}));
      expect(CronExpression.parse('@weekly').daysOfWeek, equals({0}));
      expect(CronExpression.parse('@monthly').daysOfMonth, equals({1}));
      expect(CronExpression.parse('@yearly').months, equals({1}));
      expect(CronExpression.parse('@annually').expression, '@annually');
    });

    test('invalid', () {
      for (var e in [
        '* * * *',
        '* * * * * *',
        '60 * * * *',
        '* 24 * * *',
        '* * 0 * *',
        '* * * 13 *',
        '* * * * 8',
        '*/0 * * * *',
        '10-5 * * * *',
        'x * * * *',
        '1,,2 * * * *',
      ]) {
        expect(() => CronExpression.parse(e), throwsFormatException, reason: e);
        expect(CronExpression.tryParse(e), isNull);
      }
      expect(CronExpression.tryParse(null), isNull);
    });

    test('day of month OR day of week (both restricted)', () {
      // The 13th or any Friday:
      var c = CronExpression.parse('0 0 13 * 5');
      expect(c.matches(_utc(2026, 10, 13)), isTrue); // Tuesday 13th
      expect(c.matches(_utc(2026, 10, 16)), isTrue); // Friday
      expect(c.matches(_utc(2026, 10, 14)), isFalse);

      // Only the day of week restricted:
      var c2 = CronExpression.parse('0 0 * * 5');
      expect(c2.matches(_utc(2026, 10, 13)), isFalse);
      expect(c2.matches(_utc(2026, 10, 16)), isTrue);
    });

    test('nextAfter / previousBefore (UTC)', () {
      var c = CronExpression.parse('*/15 * * * *');
      expect(
        c.nextAfter(_utc(2026, 10, 18, 10, 7, 30)),
        equals(_utc(2026, 10, 18, 10, 15)),
      );
      expect(
        c.nextAfter(_utc(2026, 10, 18, 10, 15)),
        equals(_utc(2026, 10, 18, 10, 30)),
      );
      expect(
        c.previousBefore(_utc(2026, 10, 18, 10, 15)),
        equals(_utc(2026, 10, 18, 10, 15)),
      );
      expect(
        c.previousBefore(_utc(2026, 10, 18, 10, 14, 59)),
        equals(_utc(2026, 10, 18, 10, 0)),
      );

      var daily = CronExpression.parse('30 23 * * *');
      expect(
        daily.nextAfter(_utc(2026, 12, 31, 23, 30)),
        equals(_utc(2027, 1, 1, 23, 30)),
      );

      var leap = CronExpression.parse('0 12 29 2 *');
      expect(leap.nextAfter(_utc(2026, 3, 1)), equals(_utc(2028, 2, 29, 12)));
      expect(
        leap.previousBefore(_utc(2026, 3, 1)),
        equals(_utc(2024, 2, 29, 12)),
      );

      expect(
        CronExpression.parse('0 0 30 2 *').nextAfter(_utc(2026, 1, 1)),
        isNull,
      );
      expect(
        CronExpression.parse('0 0 30 2 *').previousBefore(_utc(2026, 1, 1)),
        isNull,
      );
    });

    test('time zone and daylight saving (Europe/Paris)', () {
      var paris = resolveCronTimeZone('Europe/Paris');

      // CET (UTC+1) in winter, CEST (UTC+2) in summer:
      var c = CronExpression.parse('30 23 * * *');
      expect(
        c.nextAfter(_utc(2026, 1, 10), paris)!.toUtc(),
        equals(_utc(2026, 1, 10, 22, 30)),
      );
      expect(
        c.nextAfter(_utc(2026, 7, 10), paris)!.toUtc(),
        equals(_utc(2026, 7, 10, 21, 30)),
      );

      // 2026-03-29: 02:00 -> 03:00 (02:30 doesn't exist): runs once that day,
      // at the first valid instant after it.
      var gap = CronExpression.parse('30 2 * * *');
      var spring = gap.nextAfter(_utc(2026, 3, 28, 12), paris)!;
      expect(spring.toUtc().isAfter(_utc(2026, 3, 29, 0, 59)), isTrue);
      expect(spring.toUtc().isBefore(_utc(2026, 3, 29, 2)), isTrue);
      var afterSpring = gap.nextAfter(spring, paris)!;
      expect(afterSpring.toUtc(), equals(_utc(2026, 3, 30, 0, 30)));

      // 2026-10-25: 03:00 -> 02:00 (02:30 happens twice): runs once.
      var fall = gap.nextAfter(_utc(2026, 10, 24, 12), paris)!;
      expect(fall.day, 25);
      var afterFall = gap.nextAfter(fall, paris)!;
      expect(afterFall.toUtc(), equals(_utc(2026, 10, 26, 1, 30)));
    });

    test('time zone without daylight saving (America/Sao_Paulo)', () {
      var sp = resolveCronTimeZone('America/Sao_Paulo');
      var c = CronExpression.parse('0 9 * * *');
      expect(
        c.nextAfter(_utc(2026, 1, 10), sp)!.toUtc(),
        equals(_utc(2026, 1, 10, 12)),
      );
      expect(
        c.nextAfter(_utc(2026, 7, 10), sp)!.toUtc(),
        equals(_utc(2026, 7, 10, 12)),
      );
    });

    test('previousBefore around daylight saving changes (Europe/Paris)', () {
      var paris = resolveCronTimeZone('Europe/Paris');
      var gap = CronExpression.parse('30 2 * * *');

      // Spring: the occurrence of the gap day is after `to` (01:10Z = 03:10
      // CEST): the previous one is the day before.
      expect(
        gap.previousBefore(_utc(2026, 3, 29, 1, 10), paris)!.toUtc(),
        equals(_utc(2026, 3, 28, 1, 30)),
      );

      // The same as reported by `nextAfter`, once passed:
      var spring = gap.nextAfter(_utc(2026, 3, 28, 12), paris)!;
      expect(
        gap.previousBefore(spring.add(const Duration(minutes: 1)), paris),
        equals(spring),
      );

      // Fall: 02:30 happens twice (CEST 00:30Z, CET 01:30Z) and runs once,
      // at 01:30Z, whether checked in the 1st or the 2nd 02:xx hour:
      expect(
        gap.nextAfter(_utc(2026, 10, 25, 0, 20), paris)!.toUtc(),
        equals(_utc(2026, 10, 25, 1, 30)),
      );
      expect(
        gap.nextAfter(_utc(2026, 10, 25, 1, 16), paris)!.toUtc(),
        equals(_utc(2026, 10, 25, 1, 30)),
      );
      expect(
        gap.nextAfter(_utc(2026, 10, 25, 1, 30), paris)!.toUtc(),
        equals(_utc(2026, 10, 26, 1, 30)),
      );
      // In the 1st 02:xx hour, the 02:30 of the day is still ahead:
      expect(
        gap.previousBefore(_utc(2026, 10, 25, 0, 40), paris)!.toUtc(),
        equals(_utc(2026, 10, 24, 0, 30)),
      );
    });

    test('==, hashCode, toString', () {
      var a = CronExpression.parse('0 10 * * *');
      var b = CronExpression.parse('0 10 * * *');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(CronExpression.parse('0 11 * * *'))));
      expect(a.toString(), '0 10 * * *');
    });

    test('resolveCronTimeZone', () {
      expect(resolveCronTimeZone(null), same(tz.UTC));
      expect(resolveCronTimeZone(' utc '), same(tz.UTC));
      expect(resolveCronTimeZone('Europe/Paris').name, 'Europe/Paris');
      expect(() => resolveCronTimeZone('Mars/Olympus'), throwsArgumentError);
    });
  });

  group('APICron config', () {
    test('parseCronDuration', () {
      expect(parseCronDuration('30s'), const Duration(seconds: 30));
      expect(parseCronDuration('5m'), const Duration(minutes: 5));
      expect(parseCronDuration('2h'), const Duration(hours: 2));
      expect(parseCronDuration('1d'), const Duration(days: 1));
      expect(parseCronDuration('250ms'), const Duration(milliseconds: 250));
      expect(parseCronDuration(90), const Duration(seconds: 90));
      expect(parseCronDuration('1.5m'), const Duration(seconds: 90));
      expect(
        parseCronDuration('x', const Duration(seconds: 1)),
        const Duration(seconds: 1),
      );
      expect(parseCronDuration(null), isNull);
    });

    test('APICronRetry', () {
      const r = APICronRetry();
      expect(r.delayFor(1), const Duration(seconds: 30));
      expect(r.delayFor(2), const Duration(minutes: 2));
      expect(r.delayFor(3), const Duration(minutes: 8));
      expect(r.delayFor(4), const Duration(minutes: 15));

      expect(r.isRetryable(APIResponse.error()), isTrue);
      expect(r.isRetryable(APIResponse.badRequest()), isFalse);
      expect(r.isRetryable(APIResponse.unauthorized()), isFalse);
      expect(r.isRetryable(APIResponse.notFound()), isFalse);

      var r2 = r.withConfig({
        'attempts': 5,
        'initial_delay': '1m',
        'multiplier': 2,
        'max_delay': '10m',
      });
      expect(r2.attempts, 5);
      expect(r2.delayFor(1), const Duration(minutes: 1));
      expect(r2.delayFor(2), const Duration(minutes: 2));
      expect(r2.delayFor(5), const Duration(minutes: 10));
    });

    test('APICronJob: validation, fromConfig, withConfig', () {
      expect(
        () => APICronJob(name: ' ', schedule: '* * * * *', path: '/a'),
        throwsArgumentError,
      );
      expect(
        () => APICronJob(
          name: 'a',
          schedule: '* * * * *',
          path: '/a',
          maxCalls: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => APICronJob(
          name: 'a',
          schedule: '* * * * *',
          path: '/a',
          timeZone: 'X/Y',
        ),
        throwsArgumentError,
      );
      expect(
        () => APICronJob(name: 'a', schedule: 'bad', path: '/a'),
        throwsFormatException,
      );

      var job = APICronJob.fromConfig('rates', {
        'path': '/currency/updateRates',
        'schedule': '30 23 * * *',
        'time_zone': 'Europe/Paris',
        'method': 'POST',
        'parameters': {'a': 1},
        'timeout': '2m',
        'max_calls': 50,
        'max_lateness': '6h',
        'lease_duration': '10m',
        'retry': {'attempts': 5},
      });

      expect(job.name, 'rates');
      expect(job.path, '/currency/updateRates');
      expect(job.method, APIRequestMethod.POST);
      expect(job.parameters, {'a': 1});
      expect(job.timeout, const Duration(minutes: 2));
      expect(job.maxCalls, 50);
      expect(job.maxLateness, const Duration(hours: 6));
      expect(job.leaseDuration, const Duration(minutes: 10));
      expect(job.retry.attempts, 5);
      expect(job.location.name, 'Europe/Paris');

      expect(
        () => APICronJob.fromConfig('x', {'path': '/x'}),
        throwsArgumentError,
      );

      var disabled = job.withConfig({'enabled': false, 'schedule': '@daily'});
      expect(disabled.enabled, isFalse);
      expect(disabled.schedule.expression, '@daily');
      expect(disabled.path, job.path);
      expect(disabled.retry.attempts, 5);
      expect(identical(job.withConfig(null), job), isTrue);
      expect(job.toString(), contains('rates'));
    });

    test('APICronScheduler.mergeJobs', () {
      var a = APICronJob(name: 'a', schedule: '@daily', path: '/m/a');
      var b = APICronJob(name: 'b', schedule: '@daily', path: '/m/b');
      var b2 = APICronJob(name: 'b', schedule: '@hourly', path: '/m/b2');

      var jobs = APICronScheduler.mergeJobs(
        [
          [a, b],
          [b2],
        ],
        {
          'a': {'enabled': false},
          'c': {'path': '/m/c', 'schedule': '*/5 * * * *'},
        },
      );

      var byName = {for (var j in jobs) j.name: j};
      expect(byName.keys.toSet(), {'a', 'b', 'c'});
      expect(byName['a']!.enabled, isFalse);
      expect(byName['b']!.path, '/m/b2');
      expect(byName['c']!.schedule.expression, '*/5 * * * *');

      expect(
        () => APICronScheduler(_CronAPIRoot(), [a, a]),
        throwsArgumentError,
      );
    });

    test('APICronConfig', () {
      var c = APICronConfig.fromMap({
        'enabled': 'true',
        'check_interval': '10s',
        'history_days': 7,
        'jobs': {
          'x': {'path': '/a', 'schedule': '@daily'},
          'bad': 'ignored',
        },
      });
      expect(c.enabled, isTrue);
      expect(c.checkInterval, const Duration(seconds: 10));
      expect(c.historyDays, 7);
      expect(c.jobs.keys, ['x']);

      var d = APICronConfig.fromMap(null);
      expect(d.enabled, isFalse);
      expect(d.checkInterval, const Duration(seconds: 30));
    });

    test('APIResponse.continuation', () {
      var r = APIResponse.ok('x');
      expect(r.continuation, isNull);

      r.continuation = ' abc ';
      expect(r.continuation, 'abc');
      expect(r.headers['X-Continuation'], 'abc');

      r.headers['x-continuation'] = 'lower';
      r.continuation = 'new';
      expect(
        r.headers.keys.where((k) => k.toLowerCase() == 'x-continuation'),
        hasLength(1),
      );
      expect(r.continuation, 'new');

      r.continuation = null;
      expect(r.continuation, isNull);
      expect(r.headers, isEmpty);

      expect(APIResponse.exposeHeaders, contains('X-Continuation'));
    });

    test('toString', () {
      expect(const APICronRetry().toString(), contains('attempts: 3'));
      expect(const APICron('@daily', name: 'x').toString(), contains('@daily'));
      expect(
        APICronConfig.fromMap({'enabled': true}).toString(),
        contains('enabled: true'),
      );
      expect(
        APICronJob(
          name: 'n',
          schedule: '@daily',
          path: '/a',
          enabled: false,
        ).toString(),
        contains('disabled'),
      );

      var job = const APICron('@daily', attempts: 2).toJob('m', 'r');
      expect(job.name, 'm.r');
      expect(job.retry.attempts, 2);
    });

    test('APICronJobRun and APICronJobLock fields', () {
      var run = APICronJobRun('job', _utc(2026, 10, 18, 10), owner: 'o');
      expect(run.status, APICronRunStatus.running);
      expect(run.isFinished, isFalse);

      // Values from a DB row (strings, numbers):
      run.setField('attempts', '3');
      run.setField('calls', 2.0);
      run.setField('startedAt', _utc(2026, 1, 2).millisecondsSinceEpoch);
      run.setField('finishedAt', '2026-01-02T00:05:00Z');
      run.setField('status', 'skipped');
      expect(run.attempts, 3);
      expect(run.calls, 2);
      expect(run.startedAt, _utc(2026, 1, 2));
      expect(run.finishedAt, _utc(2026, 1, 2, 0, 5));
      expect(run.status, APICronRunStatus.skipped);
      expect(run.isFinished, isTrue);

      run.setField('status', 'unknown');
      expect(run.status, APICronRunStatus.running);

      run.lastError = 'e' * 5000;
      expect(run.lastError!.length, APICronJobRun.maxErrorLength);

      expect(() => run.setField('nope', 1), throwsStateError);
      expect(run.fieldsNames, contains('scheduledAt'));
      expect(run.getFieldType('job'), TypeInfo.tString);
      expect(run.getFieldEntityAnnotations('job'), isNotEmpty);
      expect(run.toJson()['job'], 'job');
      expect(run.toString(), contains('job: job'));

      var lock = APICronJobLock('job', 'o', _utc(2026, 1, 1, 10));
      expect(lock.isExpired(_utc(2026, 1, 1, 9)), isFalse);
      expect(lock.isExpired(_utc(2026, 1, 1, 10)), isTrue);
      expect(lock.acquiredAt, isNotNull);
      expect(lock.toString(), contains('owner: o'));
    });

    test('APICronStoreMemory: not held / not stored', () {
      var store = APICronStoreMemory();
      var now = _utc(2026, 1, 1, 10);
      const lease = Duration(minutes: 5);

      expect(store.updateRun(APICronJobRun('j', now)), isFalse);

      var a = store.acquireLock('j', 'a', lease, now: now)!;
      // Expired: taken over by `b`.
      var b = store.acquireLock(
        'j',
        'b',
        lease,
        now: now.add(const Duration(minutes: 10)),
      )!;
      expect(b.id, isNot(a.id));

      expect(store.renewLock(a, lease), isFalse);
      expect(store.releaseLock(a), isFalse);
      expect(store.getLock('j')!.owner, 'b');
      expect(store.releaseLock(b), isTrue);
      expect(store.renewLock(b, lease), isFalse);
      expect(store.releaseLock(b), isFalse);

      expect(store.lastRun('j'), isNull);
      expect(store.deleteRunsBefore('j', now), 0);
    });

    test('APICronStoreDB.tryResolve: no repositories', () {
      expect(APICronStoreDB.tryResolve(), isNull);
    });

    test('APIAuthentication.system', () {
      var auth = APIAuthentication.system('cron:x');
      expect(auth.isSystem, isTrue);
      expect(auth.username, 'cron:x');
      expect(auth.isExpired(), isFalse);
      expect(
        auth.isExpired(now: DateTime.now().add(const Duration(days: 2))),
        isTrue,
      );

      expect(APIAuthentication(APIToken('u')).isSystem, isFalse);
    });

    test('@APICron on reflected routes', () {
      var api = _CronAPIRoot();
      // `getModule` configures the module (its routes and cron jobs):
      var module = api.getModule('reflected')!;

      var jobs = {for (var j in module.cronJobs) j.name: j};
      expect(jobs.keys.toSet(), {
        'reflected.refresh',
        'daily-report',
        'reflected.workHours',
      });

      var refresh = jobs['reflected.refresh']!;
      expect(refresh.path, '/reflected/refresh');
      expect(refresh.timeZone, 'Europe/Paris');
      expect(refresh.maxCalls, 7);
      // The defaults:
      expect(refresh.timeout, const Duration(minutes: 5));
      expect(refresh.maxLateness, const Duration(days: 1));
      expect(refresh.leaseDuration, const Duration(minutes: 5));
      expect(refresh.retry.attempts, 3);

      // The default constructor with the new options:
      var report = jobs['daily-report']!;
      expect(report.path, '/reflected/report');
      expect(report.parameters, {'kind': 'daily'});
      expect(report.timeout, const Duration(minutes: 2));
      expect(report.maxLateness, const Duration(hours: 6));
      expect(report.leaseDuration, const Duration(minutes: 10));
      expect(report.retry.attempts, 4);
      expect(report.retry.initialDelay, const Duration(minutes: 1));

      // `APICron.at`: the schedule by fields; `attempts` over `retry`:
      var workHours = jobs['reflected.workHours']!;
      expect(workHours.path, '/reflected/workHours');
      expect(workHours.schedule.expression, '*/15 9-18 * * MON-FRI');
      expect(workHours.timeZone, 'America/Sao_Paulo');
      expect(workHours.retry.attempts, 2);
      expect(workHours.retry.initialDelay, const Duration(seconds: 10));

      api.close();
    });

    test('APICron.at: fields and defaults', () {
      expect(const APICron.at().schedule, '* * * * *');
      expect(
        const APICron.at(minute: '0', hour: '3', dayOfMonth: '1').schedule,
        '0 3 1 * *',
      );
      expect(
        const APICron.at(month: 'JAN', dayOfWeek: '0').schedule,
        '* * * JAN 0',
      );

      // An invalid field: rejected when the job is built (the routes are
      // configured):
      expect(
        () => const APICron.at(minute: '61').toJob('m', 'r'),
        throwsFormatException,
      );

      var retry = const APICronRetry(attempts: 5);
      expect(
        identical(const APICron('@daily').jobRetry, APICronRetry.defaultRetry),
        isTrue,
      );
      expect(
        identical(APICron('@daily', retry: retry).jobRetry, retry),
        isTrue,
      );
      expect(APICron('@daily', retry: retry, attempts: 1).jobRetry.attempts, 1);
      expect(const APICron('@daily', attempts: 7).jobRetry.attempts, 7);
    });
  });

  group('APICronScheduler', () {
    late _CronAPIRoot api;
    late APICronStoreMemory store;
    late DateTime now;
    late List<Duration> sleeps;

    APICronScheduler scheduler(
      List<APICronJob> jobs, {
      String? owner,
      APICronStore? store2,
    }) => APICronScheduler(
      api,
      jobs,
      store: store2 ?? store,
      owner: owner ?? 'owner-1',
      clock: () => now,
      sleep: (d) async => sleeps.add(d),
      historyDays: 0,
    );

    APICronJob job(
      String route, {
      String schedule = '0 10 * * *',
      String? name,
      int maxCalls = 100,
      APICronRetry retry = const APICronRetry(),
      Duration timeout = const Duration(minutes: 5),
      Duration maxLateness = const Duration(days: 1),
      Duration leaseDuration = const Duration(minutes: 5),
    }) => APICronJob(
      name: name ?? route,
      schedule: schedule,
      path: '/jobs/$route',
      maxCalls: maxCalls,
      retry: retry,
      timeout: timeout,
      maxLateness: maxLateness,
      leaseDuration: leaseDuration,
    );

    setUp(() async {
      _calls.clear();
      api = _CronAPIRoot();
      await api.ensureInitialized();
      store = APICronStoreMemory();
      now = _utc(2026, 10, 18, 10, 0, 10);
      sleeps = [];
    });

    tearDown(() => api.close());

    test('runs a due occurrence once', () async {
      var s = scheduler([job('ok')]);

      var runs = await s.tick();
      expect(runs.single.status, APICronRunStatus.succeeded);
      expect(runs.single.scheduledAt, _utc(2026, 10, 18, 10));
      expect(runs.single.calls, 1);
      expect(runs.single.attempts, 1);
      expect(runs.single.owner, 'owner-1');
      expect(_calls.of('ok'), hasLength(1));

      // Again, same occurrence: nothing.
      expect(await s.tick(), isEmpty);
      expect(_calls.of('ok'), hasLength(1));

      // The next day:
      now = _utc(2026, 10, 19, 10, 0, 5);
      expect((await s.tick()).single.scheduledAt, _utc(2026, 10, 19, 10));
      expect(_calls.of('ok'), hasLength(2));

      expect(store.getLock('ok'), isNull, reason: 'Lock released');
    });

    test('a missed occurrence older than maxLateness is not run', () async {
      now = _utc(2026, 10, 18, 9, 0);
      var s = scheduler([job('ok', maxLateness: const Duration(hours: 1))]);
      expect(await s.tick(), isEmpty);
      expect(_calls.requests, isEmpty);
    });

    test('the latest missed occurrence runs, older ones are skipped', () async {
      store.claimRun(
        APICronJobRun(
          'ok',
          _utc(2026, 10, 15, 10),
          status: APICronRunStatus.succeeded,
        ),
      );

      var s = scheduler([job('ok')]);
      var runs = await s.tick();
      expect(runs.single.scheduledAt, _utc(2026, 10, 18, 10));
      expect(_calls.of('ok'), hasLength(1));

      var history = store.selectRuns('ok');
      expect(
        history.map((r) => (r.scheduledAt.day, r.status)),
        equals([
          (18, APICronRunStatus.succeeded),
          (17, APICronRunStatus.skipped),
          (16, APICronRunStatus.skipped),
          (15, APICronRunStatus.succeeded),
        ]),
      );
    });

    test('follows the continuation', () async {
      var run = (await scheduler([job('pages')]).tick()).single;

      expect(run.status, APICronRunStatus.succeeded);
      expect(run.calls, 3);
      expect(run.continuation, isNull);
      expect(
        _calls.of('pages').map((r) => r.getParameter('continuation')),
        equals([null, '1', '2']),
      );
    });

    test('maxCalls with a continuation: failed', () async {
      var run = (await scheduler([job('infinite', maxCalls: 4)]).tick()).single;
      expect(run.status, APICronRunStatus.failed);
      expect(run.calls, 4);
      expect(run.lastError, contains('Max calls'));
      expect(_calls.of('infinite'), hasLength(4));
    });

    test('retries an error with backoff', () async {
      _calls.flakyFailures = 2;
      var run = (await scheduler([job('flaky')]).tick()).single;
      expect(run.status, APICronRunStatus.succeeded);
      expect(run.attempts, 3);
      expect(run.calls, 1);
      expect(sleeps, [const Duration(seconds: 30), const Duration(minutes: 2)]);
      expect(
        _calls.of('flaky').map((r) => r.headers['X-Cron-Attempt']),
        equals(['1', '2', '3']),
      );
    });

    test('honors Retry-After', () async {
      _calls.flakyFailures = 1;
      _calls.retryAfter = '7';
      await scheduler([job('flaky')]).tick();
      expect(sleeps, [const Duration(seconds: 7)]);
    });

    test('all attempts failed: failed run with the last error', () async {
      _calls.flakyFailures = 10;
      var run = (await scheduler([
        job('flaky', retry: const APICronRetry(attempts: 2)),
      ]).tick()).single;
      expect(run.status, APICronRunStatus.failed);
      expect(run.attempts, 2);
      expect(run.lastError, contains('flaky'));
    });

    test('BAD_REQUEST is not retried', () async {
      var run = (await scheduler([job('bad')]).tick()).single;
      expect(run.status, APICronRunStatus.failed);
      expect(run.attempts, 1);
      expect(run.lastError, contains('BAD_REQUEST'));
      expect(sleeps, isEmpty);
    });

    test('a thrown error is retried', () async {
      var run = (await scheduler([
        job('throws', retry: const APICronRetry(attempts: 2)),
      ]).tick()).single;
      expect(run.status, APICronRunStatus.failed);
      expect(run.attempts, 2);
      expect(_calls.of('throws'), hasLength(2));
    });

    test('timeout: the slow call is waited for, never overlapped', () async {
      _calls.slowDelay = const Duration(milliseconds: 150);
      var run = (await scheduler([
        job('slow', timeout: const Duration(milliseconds: 20)),
      ]).tick()).single;

      // Not retried while running (no parallel calls), and its result used:
      expect(run.status, APICronRunStatus.succeeded);
      expect(run.attempts, 1);
      expect(_calls.of('slow'), hasLength(1));
      expect(sleeps, isEmpty);
    });

    test('Retry-After is capped by maxDelay', () async {
      _calls.flakyFailures = 1;
      _calls.retryAfter = '86400';
      await scheduler([job('flaky')]).tick();
      expect(sleeps, [const APICronRetry().maxDelay]);
    });

    test('a continuation token too long fails the run', () async {
      var run = (await scheduler([job('longToken')]).tick()).single;
      expect(run.status, APICronRunStatus.failed);
      expect(run.lastError, contains('too long'));
      expect(_calls.of('longToken'), hasLength(1));

      // Finished (not resumed again and again):
      now = now.add(const Duration(minutes: 1));
      expect(await scheduler([job('longToken')]).tick(), isEmpty);
      expect(_calls.of('longToken'), hasLength(1));
    });

    test(
      'a store error while running fails the run (not left running)',
      () async {
        var testStore = _TestStore()..failUpdateAfter = 1;
        var run = (await scheduler([
          job('pages'),
        ], store2: testStore).tick()).single;
        expect(run.status, APICronRunStatus.failed);
        expect(run.lastError, contains('update failed'));
        expect(_calls.of('pages'), hasLength(1));
      },
    );

    test('internal system authentication and headers', () async {
      var run = (await scheduler([job('auth')]).tick()).single;
      expect(run.status, APICronRunStatus.succeeded);

      var request = _calls.of('auth').single;
      expect(request.authentication?.isSystem, isTrue);
      expect(request.authentication?.username, 'cron:auth');
      expect(request.requesterSource, APIRequesterSource.internal);
      expect(request.headers['X-Cron-Job'], 'auth');
      expect(
        request.headers['X-Cron-Scheduled-At'],
        _utc(2026, 10, 18, 10).toIso8601String(),
      );
      expect(request.headers['X-Cron-Run'], '${run.id}');
    });

    test('locked by another owner: not run until the lease expires', () async {
      store.acquireLock('ok', 'other', const Duration(minutes: 5), now: now);

      var s = scheduler([job('ok')]);
      expect(await s.tick(), isEmpty);
      expect(_calls.requests, isEmpty);

      now = now.add(const Duration(minutes: 6));
      expect((await s.tick()).single.status, APICronRunStatus.succeeded);
      expect(_calls.of('ok'), hasLength(1));
    });

    test('two schedulers on one store: the occurrence runs once', () async {
      var s1 = scheduler([job('ok')], owner: 'a');
      var s2 = scheduler([job('ok')], owner: 'b');

      var runs = await Future.wait([s1.tick(), s2.tick()]);
      expect(runs.expand((r) => r), hasLength(1));
      expect(_calls.of('ok'), hasLength(1));

      expect(await s1.tick(), isEmpty);
      expect(await s2.tick(), isEmpty);
      expect(_calls.of('ok'), hasLength(1));
    });

    test('not in parallel: a running job is not started again', () async {
      _calls.block = Completer<void>();

      var s = scheduler([job('blocked', schedule: '* * * * *')]);
      var first = s.tick();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(s.runningJobs, {'blocked'});

      // The next minute, while still running:
      now = now.add(const Duration(minutes: 1));
      expect(await s.tick(), isEmpty);

      // Another instance:
      var other = scheduler([
        job('blocked', schedule: '* * * * *'),
      ], owner: 'b');
      expect(await other.tick(), isEmpty);

      _calls.block!.complete();
      expect((await first).single.status, APICronRunStatus.succeeded);
      expect(_calls.of('blocked'), hasLength(1));
      expect(s.runningJobs, isEmpty);
    });

    test('an interrupted run is resumed from its continuation', () async {
      // Interrupted after 2 calls (its instance stopped; no lock):
      var interrupted = store.claimRun(
        APICronJobRun(
            'pages',
            _utc(2026, 10, 18, 10),
            owner: 'dead',
            startedAt: _utc(2026, 10, 18, 10),
          )
          ..calls = 2
          ..continuation = '2',
      )!;

      var runs = await scheduler([job('pages')]).tick();
      var run = runs.single;

      expect(run.id, interrupted.id);
      expect(run.status, APICronRunStatus.succeeded);
      expect(run.owner, 'owner-1');
      expect(run.calls, 3);
      expect(
        _calls.of('pages').map((r) => r.getParameter('continuation')),
        equals(['2']),
      );
    });

    test('runNow', () async {
      var s = scheduler([job('ok', schedule: '0 0 1 1 *')]);
      var run = await s.runNow('ok');
      expect(run!.status, APICronRunStatus.succeeded);
      expect(run.scheduledAt, now);
      expect(_calls.of('ok'), hasLength(1));
      expect(s.selectRuns('ok'), hasLength(1));

      expect(() => s.runNow('unknown'), throwsArgumentError);
    });

    test('disabled job: not run', () async {
      var s = scheduler([
        job('ok').withConfig({'enabled': false}),
      ]);
      expect(await s.tick(), isEmpty);
      expect(_calls.requests, isEmpty);
    });

    test('history pruning', () async {
      store.claimRun(
        APICronJobRun(
          'ok',
          _utc(2026, 1, 1, 10),
          status: APICronRunStatus.succeeded,
        ),
      );

      var s = APICronScheduler(
        api,
        [job('ok', maxLateness: const Duration(hours: 1))],
        store: store,
        owner: 'o',
        clock: () => now,
        sleep: (d) async {},
        historyDays: 30,
      );

      await s.tick();
      expect(
        store.selectRuns('ok').map((r) => r.scheduledAt),
        equals([_utc(2026, 10, 18, 10)]),
      );
    });

    test('the lock is renewed while running', () async {
      var testStore = _TestStore();
      _calls.block = Completer<void>();

      var s = scheduler([
        job('blocked', leaseDuration: const Duration(milliseconds: 60)),
      ], store2: testStore);
      var running = s.tick();

      await _waitUntil(() => testStore.renewals >= 3);
      expect(testStore.renewals, greaterThanOrEqualTo(3));

      // Held (renewed): another instance can't run it.
      var other = scheduler(
        [job('blocked', leaseDuration: const Duration(milliseconds: 60))],
        owner: 'b',
        store2: testStore,
      );
      expect(await other.tick(), isEmpty);

      _calls.block!.complete();
      expect((await running).single.status, APICronRunStatus.succeeded);
      expect(_calls.of('blocked'), hasLength(1));
    });

    test('lock lost while running: left to the new owner', () async {
      _calls.block = Completer<void>();

      var s = scheduler([
        job('blocked', leaseDuration: const Duration(milliseconds: 60)),
      ]);
      var running = s.tick();
      await _waitUntil(() => _calls.of('blocked').isNotEmpty);

      // Another instance took the lock over (e.g. this one was paused past
      // its lease):
      store.releaseLock(store.getLock('blocked')!);
      store.acquireLock(
        'blocked',
        'thief',
        const Duration(minutes: 5),
        now: now,
      );

      await Future.delayed(const Duration(milliseconds: 80));
      _calls.block!.complete();

      var run = (await running).single;
      expect(run.status, APICronRunStatus.running, reason: 'Not finished');
      expect(store.getLock('blocked')!.owner, 'thief', reason: 'Not released');

      // Nothing written after the lock was lost (the call result included):
      var stored = store.getRun('blocked', _utc(2026, 10, 18, 10))!;
      expect(stored.status, APICronRunStatus.running);
      expect(stored.calls, 0);
      expect(stored.owner, 'owner-1');
    });

    test('lock considered lost when its lease runs out unrenewed', () async {
      var testStore = _TestStore()..failRenew = true;
      _calls.block = Completer<void>();

      var s = scheduler([
        job('blocked', leaseDuration: const Duration(milliseconds: 60)),
      ], store2: testStore);
      var running = s.tick();
      await _waitUntil(() => _calls.of('blocked').isNotEmpty);

      // The renewals fail and the clock passes the lease:
      now = now.add(const Duration(seconds: 1));
      await _waitUntil(() => testStore.renewals >= 2);
      _calls.block!.complete();

      var run = (await running).single;
      expect(run.status, APICronRunStatus.running, reason: 'Left running');
      expect(testStore.getRun('blocked', _utc(2026, 10, 18, 10))!.calls, 0);
    });

    test('updateRun: only by the owner, only while running', () {
      var t = _utc(2026, 10, 18, 10);
      var run = store.claimRun(APICronJobRun('j', t, owner: 'a'))!;

      var byB = store.getRun('j', t)!..owner = 'b';
      expect(store.updateRun(byB), isFalse, reason: 'Owned by a');
      expect(
        store.updateRun(byB, previousOwner: 'a'),
        isTrue,
        reason: 'Take over',
      );

      expect(store.updateRun(run), isFalse, reason: 'a lost it');

      byB.status = APICronRunStatus.succeeded;
      expect(store.updateRun(byB), isTrue);
      expect(
        store.updateRun(byB..status = APICronRunStatus.running),
        isFalse,
        reason: 'Finished: never back to running',
      );
      expect(store.getRun('j', t)!.status, APICronRunStatus.succeeded);
    });

    test('pruning never deletes a running run', () {
      store.claimRun(APICronJobRun('j', _utc(2026, 1, 1)));
      store.claimRun(
        APICronJobRun('j', _utc(2026, 1, 2), status: APICronRunStatus.failed),
      );
      expect(store.deleteRunsBefore('j', _utc(2026, 6, 1)), 1);
      expect(store.selectRuns('j').single.status, APICronRunStatus.running);
    });

    test(
      'stop: the running job stops after its call, resumed elsewhere',
      () async {
        _calls.block = Completer<void>();

        var s = APICronScheduler(
          api,
          [job('pages2', schedule: '0 10 * * *')],
          store: store,
          owner: 'stopping',
          checkInterval: const Duration(hours: 1),
          clock: () => now,
          sleep: (d) async {},
          historyDays: 0,
        );
        s.start();
        await _waitUntil(() => _calls.of('pages2').isNotEmpty);

        s.stop();
        _calls.block!.complete();
        await s.waitRunning();

        var stored = store.getRun('pages2', _utc(2026, 10, 18, 10))!;
        expect(stored.status, APICronRunStatus.running);
        expect(stored.calls, 0, reason: 'The call result not written');
        expect(store.getLock('pages2'), isNull, reason: 'Released');

        // Another instance resumes it:
        var other = scheduler([job('pages2')], owner: 'other');
        var resumed = (await other.tick()).single;
        expect(resumed.status, APICronRunStatus.succeeded);
        expect(resumed.owner, 'other');
      },
    );

    test('runNow at second 0: not the scheduled occurrence slot', () async {
      now = _utc(2026, 10, 18, 10, 0, 0);
      var s = scheduler([job('ok')]);
      var manual = (await s.runNow('ok'))!;
      expect(manual.scheduledAt, _utc(2026, 10, 18, 10, 0, 1));

      var scheduled = (await s.tick()).single;
      expect(scheduled.scheduledAt, _utc(2026, 10, 18, 10));
      expect(_calls.of('ok'), hasLength(2));
    });

    test('lock renewal errors are only logged', () async {
      var testStore = _TestStore()..failRenew = true;
      _calls.block = Completer<void>();

      var s = scheduler([
        job('blocked', leaseDuration: const Duration(milliseconds: 30)),
      ], store2: testStore);
      var running = s.tick();

      await _waitUntil(() => testStore.renewals >= 2);
      _calls.block!.complete();

      expect((await running).single.status, APICronRunStatus.succeeded);
    });

    test('a store error in a check is logged, not thrown', () async {
      var testStore = _TestStore()..failSelectRunning = true;
      var s = scheduler([job('ok')], store2: testStore);
      expect(await s.tick(), isEmpty);
      expect(_calls.requests, isEmpty);
      expect(s.runningJobs, isEmpty);
    });

    test('history pruning errors are only logged', () async {
      var testStore = _TestStore()..failDelete = true;
      var s = APICronScheduler(
        api,
        [job('ok')],
        store: testStore,
        clock: () => now,
        sleep: (d) async {},
        historyDays: 30,
      );
      expect((await s.tick()).single.status, APICronRunStatus.succeeded);
    });

    test('occurrence claimed by another instance after the check', () async {
      var testStore = _TestStore()..hideRuns = true;
      testStore.claimRun(
        APICronJobRun(
          'ok',
          _utc(2026, 10, 18, 10),
          owner: 'other',
          status: APICronRunStatus.succeeded,
        ),
      );

      var s = scheduler([job('ok')], store2: testStore);
      expect(await s.tick(), isEmpty);
      expect(_calls.requests, isEmpty);
      expect(testStore.getLock('ok'), isNull, reason: 'Lock released');
    });

    test('runNow: already running', () async {
      _calls.block = Completer<void>();
      var s = scheduler([job('blocked')]);
      var running = s.tick();
      await _waitUntil(() => s.runningJobs.isNotEmpty);

      expect(await s.runNow('blocked'), isNull);

      _calls.block!.complete();
      await running;
    });

    test('start / stop', () async {
      var s = APICronScheduler(
        api,
        [job('ok')],
        store: store,
        checkInterval: const Duration(milliseconds: 50),
        clock: () => now,
      );
      expect(s.isStarted, isFalse);

      s.start();
      expect(s.isStarted, isTrue);
      s.start();

      await Future.delayed(const Duration(milliseconds: 200));
      expect(_calls.of('ok'), hasLength(1));

      s.stop();
      expect(s.isStarted, isFalse);
      s.stop();
      expect(s.toString(), contains('started: false'));
    });
  });

  group('APIRoot cron', () {
    setUp(_calls.clear);

    test('disabled by default', () async {
      var api = _CronAPIRoot();
      await api.ensureInitialized();
      expect(api.cronScheduler, isNull);
      expect(api.cronConfig.enabled, isFalse);
      expect(await api.startCronScheduler(), isNull);
      api.close();
    });

    test('default store: in memory without the DB repositories', () async {
      var api = _CronAPIRoot(
        config: {
          'cron': {'enabled': true, 'check_interval': '1h'},
        },
      );
      await api.ensureInitialized();
      await api.cronSchedulerReady;
      expect(api.cronScheduler!.store, isA<APICronStoreMemory>());
      expect(
        identical(await api.startCronScheduler(), api.cronScheduler),
        isTrue,
      );
      api.close();
      expect(await api.startCronScheduler(), isNull, reason: 'Closed');
    });

    test('enabled: started with the jobs of code, routes and config', () async {
      var store = APICronStoreMemory();
      var api = _CronAPIRoot(
        store: store,
        config: {
          'cron': {
            'enabled': true,
            'check_interval': '1h',
            'jobs': {
              'reflected.refresh': {'enabled': false},
              'from-config': {'path': '/jobs/ok', 'schedule': '* * * * *'},
            },
          },
        },
        codeJobs: [
          APICronJob(name: 'from-code', schedule: '@yearly', path: '/jobs/ok'),
        ],
      );

      await api.ensureInitialized();

      var scheduler = (await api.cronSchedulerReady)!;
      expect(identical(scheduler, api.cronScheduler), isTrue);
      expect(scheduler.isStarted, isTrue);
      expect(identical(scheduler.store, store), isTrue);
      expect(scheduler.checkInterval, const Duration(hours: 1));
      expect(scheduler.jobs.keys.toSet(), {
        'reflected.refresh',
        'daily-report',
        'reflected.workHours',
        'from-code',
        'from-config',
      });
      expect(scheduler.jobs['reflected.refresh']!.enabled, isFalse);

      // The first check, at start: `from-config` runs every minute.
      for (var i = 0; i < 50 && _calls.of('ok').isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      expect(_calls.of('ok'), isNotEmpty);
      expect(_calls.of('ok').first.headers['X-Cron-Job'], 'from-config');

      api.close();
      expect(scheduler.isStarted, isFalse);
      expect(api.cronScheduler, isNull);
    });

    test('a scheduler that fails to start does not fail the API', () async {
      var api = _CronAPIRoot(
        config: {
          'cron': {
            'enabled': true,
            'jobs': {
              'broken': {'path': '/jobs/ok'},
            },
          },
        },
      );
      await api.ensureInitialized();
      expect(api.isInitialized, isTrue);
      expect(await api.cronSchedulerReady, isNull);
      expect(api.cronScheduler, isNull);
      api.close();
    });

    test('jobs run only after the modules are initialized', () async {
      var api = _SlowAPIRoot();

      await api.ensureInitialized();
      expect(api.slowModule.ready, isTrue);

      var scheduler = (await api.cronSchedulerReady)!;
      await _waitUntil(() => api.slowModule.calls.isNotEmpty);

      // The route was called once its module was ready:
      expect(api.slowModule.calls, [true]);

      api.close();
      await scheduler.waitRunning();
    });
  });
}

/// A module with a slow initialization (e.g. loading its repositories).
class _SlowModule extends APIModule {
  _SlowModule(APIRoot apiRoot) : super(apiRoot, 'slow');

  bool ready = false;

  /// For each call: was the module ready?
  final List<bool> calls = [];

  @override
  FutureOr<InitializationResult> initialize() async {
    await Future.delayed(const Duration(milliseconds: 200));
    ready = true;
    return super.initialize();
  }

  @override
  void configure() {
    routes.any('check', (request) {
      calls.add(ready);
      return APIResponse.ok(ready);
    });
  }
}

class _SlowAPIRoot extends APIRoot {
  _SlowAPIRoot()
    : super(
        'cron-slow-test',
        '1.0',
        apiConfig: {
          'cron': {
            'enabled': true,
            'check_interval': '1h',
            'jobs': {
              'check': {'path': '/slow/check', 'schedule': '* * * * *'},
            },
          },
        },
      );

  late final _SlowModule slowModule = _SlowModule(this);

  @override
  Set<APIModule> loadModules() => {slowModule};

  @override
  FutureOr<APICronStore> loadCronStore() => APICronStoreMemory();
}
