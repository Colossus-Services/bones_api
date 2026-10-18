// Integration tests of the `APICronStoreDB` (the cron runs and locks tables)
// over a DB adapter: see the `bones_api_cron_db_*_test.dart` files.

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

/// A provider with only the cron repositories
/// ([APICronStoreDB.buildRepositories]).
class CronDBProvider
    extends DBRelationalEntityRepositoryProvider<DBSQLAdapter> {
  final DBSQLAdapter Function(CronDBProvider provider) adapterCreator;

  CronDBProvider(this.adapterCreator);

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBSQLAdapter> buildAdapter() => adapterCreator(this);

  List<EntityRepository<Object>>? _repositories;

  @override
  List<EntityRepository<Object>> buildRepositories(DBAdapter adapter) =>
      _repositories ??= APICronStoreDB.buildRepositories(
        adapter as DBSQLAdapter,
      );

  APICronStoreDB get store => APICronStoreDB(
    getEntityRepository<APICronJobRun>()!,
    getEntityRepository<APICronJobLock>()!,
  );
}

/// The first call of `blockedPages` of a job waits for its completer.
final Map<String, Completer<void>> _blockers = {};

class _CronDBModule extends APIModule {
  final List<String> calls;

  _CronDBModule(APIRoot apiRoot, this.calls) : super(apiRoot, 'db');

  APIResponse _page(APIRequest request) {
    var c = request.getParameter('continuation');
    calls.add('${request.headers['X-Cron-Job']}:${c ?? ''}');
    var page = (int.tryParse('${c ?? ''}') ?? 0) + 1;
    var response = APIResponse.ok('page $page');
    if (page < 3) response.continuation = '$page';
    return response;
  }

  @override
  void configure() {
    routes.any('pages', _page);

    routes.any('blockedPages', (request) async {
      var job = '${request.headers['X-Cron-Job']}';
      if (request.getParameter('continuation') == null) {
        calls.add('$job:waiting');
        await _blockers[job]?.future;
      }
      return _page(request);
    });
  }
}

class _CronDBAPIRoot extends APIRoot {
  final List<String> calls = [];

  final List<EntityRepositoryProvider> providers;

  _CronDBAPIRoot(
    String name, {
    this.providers = const [],
    Map<String, dynamic>? config,
  }) : super(name, '1.0', apiConfig: config);

  @override
  Set<APIModule> loadModules() => {_CronDBModule(this, calls)};

  @override
  FutureOr<List<EntityRepositoryProvider>> loadEntityRepositoryProviders() =>
      providers;
}

Future<void> _waitUntil(FutureOr<bool> Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (await condition()) return;
    await Future.delayed(const Duration(milliseconds: 25));
  }
  fail('Condition not reached');
}

DateTime _utc(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min);

/// Runs the [APICronStoreDB] tests with the provider of [setUpProvider].
void runCronStoreDBTests(
  String name, {
  required Future<CronDBProvider> Function() setUpProvider,
  required Future<void> Function() tearDownProvider,
}) {
  group('APICronStoreDB[$name]', () {
    late CronDBProvider provider;
    late APICronStoreDB store;

    var jobCount = 0;
    late String job;

    setUpAll(() async {
      provider = await setUpProvider();
      store = provider.store;
    });

    tearDownAll(tearDownProvider);

    // Each test with its own job names (the tables are shared):
    setUp(() => job = 'job${++jobCount}');

    test('tryResolve: the registered repositories', () async {
      var resolved = APICronStoreDB.tryResolve()!;
      var t = _utc(2026, 10, 18, 10);
      expect(await resolved.claimRun(APICronJobRun(job, t)), isNotNull);
      expect((await store.getRun(job, t))?.job, job);
    });

    test('claimRun: each occurrence once', () async {
      var t = _utc(2026, 10, 18, 10);

      var run = await store.claimRun(APICronJobRun(job, t, owner: 'a'));
      expect(run, isNotNull);
      expect(run!.id, isNotNull);

      expect(await store.claimRun(APICronJobRun(job, t, owner: 'b')), isNull);

      // Another occurrence, another job: OK.
      expect(
        await store.claimRun(APICronJobRun(job, t.add(Duration(days: 1)))),
        isNotNull,
      );
      expect(await store.claimRun(APICronJobRun('$job-x', t)), isNotNull);
    });

    test('getRun, updateRun, lastRun, selectRuns', () async {
      var t1 = _utc(2026, 10, 16, 10);
      var t2 = _utc(2026, 10, 17, 10);
      var t3 = _utc(2026, 10, 18, 10);

      for (var t in [t2, t1, t3]) {
        await store.claimRun(APICronJobRun(job, t, owner: 'o', startedAt: t));
      }

      var run = (await store.getRun(job, t3))!;
      expect(run.job, job);
      expect(run.scheduledAt, t3);
      expect(run.status, APICronRunStatus.running);
      expect(run.owner, 'o');

      run
        ..status = APICronRunStatus.failed
        ..calls = 4
        ..attempts = 6
        ..continuation = 'token-4'
        ..lastError = 'boom'
        ..finishedAt = t3.add(Duration(minutes: 2))
        ..durationMs = 120000;
      expect(await store.updateRun(run), isTrue);

      var stored = (await store.getRun(job, t3))!;
      expect(stored.status, APICronRunStatus.failed);
      expect(stored.calls, 4);
      expect(stored.attempts, 6);
      expect(stored.continuation, 'token-4');
      expect(stored.lastError, 'boom');
      expect(stored.finishedAt, t3.add(Duration(minutes: 2)));
      expect(stored.durationMs, 120000);
      expect(stored.isFinished, isTrue);

      expect((await store.lastRun(job))!.scheduledAt, t3);
      expect(await store.lastRun('$job-none'), isNull);
      expect(await store.getRun(job, _utc(2026, 1, 1)), isNull);

      expect(
        (await store.selectRuns(job)).map((r) => r.scheduledAt),
        equals([t3, t2, t1]),
      );
      expect((await store.selectRuns(job, limit: 2)), hasLength(2));

      expect(
        (await store.selectRunningRuns(job)).map((r) => r.scheduledAt).toSet(),
        {t1, t2},
      );

      // A running run is never pruned:
      expect(await store.deleteRunsBefore(job, t2), 0);

      var r1 = (await store.getRun(job, t1))!
        ..status = APICronRunStatus.succeeded;
      expect(await store.updateRun(r1), isTrue);

      expect(await store.deleteRunsBefore(job, t2), 1);
      expect(
        (await store.selectRuns(job)).map((r) => r.scheduledAt),
        equals([t3, t2]),
      );

      // Only by its owner, and never back to running once finished:
      var r2 = (await store.getRun(job, t2))!..owner = 'other';
      expect(await store.updateRun(r2), isFalse);
      expect(await store.updateRun(r2, previousOwner: 'o'), isTrue);
      expect(
        await store.updateRun(stored..status = APICronRunStatus.running),
        isFalse,
      );

      expect(
        await store.updateRun(APICronJobRun(job, _utc(2026, 1, 1))),
        isFalse,
        reason: 'Not stored',
      );
    });

    test('locks: acquire, renew, take over, release', () async {
      var now = _utc(2026, 10, 18, 10);
      var lease = Duration(minutes: 5);

      var a = await store.acquireLock(job, 'a', lease, now: now);
      expect(a, isNotNull);
      expect(a!.leaseUntil, now.add(lease));

      // Held by `a`:
      expect(await store.acquireLock(job, 'b', lease, now: now), isNull);

      // `a` again: renewed.
      var a2 = await store.acquireLock(
        job,
        'a',
        lease,
        now: now.add(Duration(minutes: 1)),
      );
      expect(a2!.id, a.id);
      expect(a2.leaseUntil, now.add(Duration(minutes: 6)));

      expect(
        await store.renewLock(a, lease, now: now.add(Duration(minutes: 2))),
        isTrue,
      );
      expect(
        (await store.getLock(job))!.leaseUntil,
        now.add(Duration(minutes: 7)),
      );

      // Expired: taken over by `b`.
      var later = now.add(Duration(minutes: 20));
      var b = await store.acquireLock(job, 'b', lease, now: later);
      expect(b, isNotNull);
      expect(b!.owner, 'b');
      expect(b.id, isNot(a.id));

      // `a` lost it:
      expect(await store.renewLock(a, lease, now: later), isFalse);
      expect(await store.releaseLock(a), isFalse);
      expect((await store.getLock(job))!.owner, 'b');

      expect(await store.releaseLock(b), isTrue);
      expect(await store.getLock(job), isNull);
    });

    test('parallel claims and locks: one winner', () async {
      var t = _utc(2026, 10, 18, 10);
      var now = DateTime.now().toUtc();

      var claims = await Future.wait([
        for (var i = 0; i < 10; i++)
          store.claimRun(APICronJobRun(job, t, owner: 'o$i')),
      ]);
      expect(claims.nonNulls, hasLength(1));

      var locks = await Future.wait([
        for (var i = 0; i < 10; i++)
          Future.value(
            store.acquireLock(job, 'o$i', Duration(minutes: 5), now: now),
          ),
      ]);
      expect(locks.nonNulls, hasLength(1));
    });

    test('schedulers on the same DB: each occurrence runs once', () async {
      var api1 = _CronDBAPIRoot('cron-db-1');
      var api2 = _CronDBAPIRoot('cron-db-2');
      await api1.ensureInitialized();
      await api2.ensureInitialized();

      var now = _utc(2026, 10, 18, 10, 0);

      APICronScheduler scheduler(APIRoot api, String owner) => APICronScheduler(
        api,
        [APICronJob(name: job, schedule: '0 10 * * *', path: '/db/pages')],
        store: store,
        owner: owner,
        clock: () => now,
        sleep: (d) async {},
        historyDays: 0,
      );

      var s1 = scheduler(api1, 's1');
      var s2 = scheduler(api2, 's2');

      var runs = await Future.wait([s1.tick(), s2.tick()]);
      var all = runs.expand((r) => r).toList();
      expect(all, hasLength(1));
      expect(all.single.status, APICronRunStatus.succeeded);
      expect(all.single.calls, 3);

      expect([...api1.calls, ...api2.calls], ['$job:', '$job:1', '$job:2']);

      var stored = (await store.getRun(job, now))!;
      expect(stored.status, APICronRunStatus.succeeded);
      expect(stored.calls, 3);
      expect(await store.getLock(job), isNull);

      // An interrupted run (calls 1, continuation 1, no lock), resumed by
      // the other scheduler the next day:
      api1.calls.clear();
      api2.calls.clear();
      var next = _utc(2026, 10, 19, 10);
      await store.claimRun(
        APICronJobRun(job, next, owner: 'dead', startedAt: next)
          ..calls = 1
          ..continuation = '1',
      );

      now = next.add(Duration(seconds: 5));
      var resumed = (await s2.tick()).single;
      expect(resumed.scheduledAt, next);
      expect(resumed.status, APICronRunStatus.succeeded);
      expect(resumed.owner, 's2');
      // Pages 2 and 3, after the 1 done:
      expect(resumed.calls, 3);
      expect(api2.calls, ['$job:1', '$job:2']);
      expect(api1.calls, isEmpty);

      api1.close();
      api2.close();
    });

    Map<String, dynamic> cronConfig(String path) => {
      'cron': {
        'enabled': true,
        'check_interval': '1h',
        'history_days': 0,
        'jobs': {
          // Always the same occurrence (Jan 1st of this year), due at start:
          job: {'path': path, 'schedule': '0 0 1 1 *', 'max_lateness': '400d'},
        },
      },
    };

    DateTime occurrence() => CronExpression.parse(
      '0 0 1 1 *',
    ).previousBefore(DateTime.now())!.toUtc();

    test(
      'APIRoot: two instances on the same DB run the occurrence once',
      () async {
        var a = _CronDBAPIRoot(
          '$job-a',
          providers: [provider],
          config: cronConfig('/db/pages'),
        );
        var b = _CronDBAPIRoot(
          '$job-b',
          providers: [provider],
          config: cronConfig('/db/pages'),
        );

        await Future.wait([
          Future.value(a.ensureInitialized()),
          Future.value(b.ensureInitialized()),
        ]);

        var sa = (await a.cronSchedulerReady)!;
        var sb = (await b.cronSchedulerReady)!;

        // The DB store, resolved from the registered repositories:
        expect(sa.store, isA<APICronStoreDB>());
        expect(sb.store, isA<APICronStoreDB>());

        await _waitUntil(
          () async =>
              (await store.getRun(job, occurrence()))?.status ==
              APICronRunStatus.succeeded,
        );
        await sa.waitRunning();
        await sb.waitRunning();

        expect([...a.calls, ...b.calls], ['$job:', '$job:1', '$job:2']);
        expect(await store.getLock(job), isNull);

        a.close();
        b.close();
      },
    );

    test('APIRoot: a root closed mid-run is resumed by another', () async {
      var blocker = _blockers[job] = Completer<void>();

      var a = _CronDBAPIRoot(
        '$job-a',
        providers: [provider],
        config: cronConfig('/db/blockedPages'),
      );
      await a.ensureInitialized();
      var sa = (await a.cronSchedulerReady)!;

      await _waitUntil(() => a.calls.isNotEmpty);
      expect(a.calls, ['$job:waiting']);

      // Closed while its first call runs: the call finishes, nothing more.
      a.close();
      blocker.complete();
      await sa.waitRunning();

      var interrupted = (await store.getRun(job, occurrence()))!;
      expect(interrupted.status, APICronRunStatus.running);
      expect(interrupted.calls, 0);
      expect(await store.getLock(job), isNull, reason: 'Released');

      // Another instance starts and resumes it:
      var b = _CronDBAPIRoot(
        '$job-b',
        providers: [provider],
        config: cronConfig('/db/blockedPages'),
      );
      await b.ensureInitialized();
      var sb = (await b.cronSchedulerReady)!;

      await _waitUntil(
        () async =>
            (await store.getRun(job, occurrence()))?.status ==
            APICronRunStatus.succeeded,
      );
      await sb.waitRunning();

      var resumed = (await store.getRun(job, occurrence()))!;
      expect(resumed.id, interrupted.id);
      expect(resumed.owner, sb.owner);
      expect(resumed.calls, 3);
      expect(a.calls, ['$job:waiting', '$job:']);
      expect(b.calls, ['$job:waiting', '$job:', '$job:1', '$job:2']);

      b.close();
    });
  });
}
