import 'package:async_extension/async_extension.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_entity_sql.dart';
import 'bones_api_utils_json.dart';

/// The status of an [APICronJobRun].
enum APICronRunStatus {
  /// Running (or interrupted: resumed when its lock lease expires).
  running,

  /// All the calls succeeded.
  succeeded,

  /// A call failed after all its attempts (or `maxCalls` was reached).
  failed,

  /// A missed occurrence (the servers were down), not run.
  skipped,
}

APICronRunStatus? _parseRunStatus(Object? o) {
  if (o == null) return null;
  if (o is APICronRunStatus) return o;
  var s = o.toString().trim();
  for (var e in APICronRunStatus.values) {
    if (e.name == s) return e;
  }
  return null;
}

/// A base for the cron entities: the fields are kept in a [Map] (no
/// reflection), typed by [types].
abstract class _APICronEntity extends Entity {
  final Map<String, Object?> _values = {};

  Map<String, TypeInfo> get types;

  Map<String, List<EntityAnnotation>> get annotations;

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => types.keys.toList();

  @override
  V? getField<V>(String key) => _values[key] as V?;

  @override
  TypeInfo? getFieldType(String key) => types[key];

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      annotations[key];

  @override
  void setField<V>(String key, V? value) {
    var t = types[key];
    if (t == null) throw StateError('Unknown field: $key');
    _values[key] = _convert(t, value);
  }

  static Object? _convert(TypeInfo t, Object? value) {
    if (value == null) return null;
    if (t.type == int) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.parse(value.toString());
    } else if (t.type == DateTime) {
      if (value is DateTime) return value.toUtc();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return DateTime.parse(value.toString()).toUtc();
    } else if (t.type == String) {
      return value is String ? value : value.toString();
    }
    return value;
  }

  int? get id => getField<int>('id');

  set id(int? id) => setField('id', id);

  @override
  Map<String, dynamic> toJson() => {
    for (var e in _values.entries)
      if (e.value != null) e.key: Json.toJson(e.value),
  };
}

/// A run of an [APICronJob] occurrence (its [scheduledAt]), and its history.
///
/// Unique by ([job], [scheduledAt]): inserting it claims the occurrence, so
/// it runs once even with several instances (see [APICronStore.claimRun]).
class APICronJobRun extends _APICronEntity {
  static const int maxJobLength = 128;
  static const int maxOwnerLength = 128;
  static const int maxContinuationLength = 4096;
  static const int maxErrorLength = 4096;

  static final Map<String, TypeInfo> _types = {
    'id': TypeInfo.tInt,
    'job': TypeInfo.tString,
    'scheduledAt': TypeInfo.tDateTime,
    'status': TypeInfo.tString,
    'owner': TypeInfo.tString,
    'attempts': TypeInfo.tInt,
    'calls': TypeInfo.tInt,
    'continuation': TypeInfo.tString,
    'startedAt': TypeInfo.tDateTime,
    'finishedAt': TypeInfo.tDateTime,
    'durationMs': TypeInfo.tInt,
    'lastError': TypeInfo.tString,
  };

  static const Map<String, List<EntityAnnotation>> _annotations = {
    'job': [EntityField.maximum(maxJobLength)],
    'status': [EntityField.maximum(16)],
    'owner': [EntityField.maximum(maxOwnerLength)],
    'continuation': [EntityField.maximum(maxContinuationLength)],
    'lastError': [EntityField.maximum(maxErrorLength)],
  };

  APICronJobRun.empty();

  APICronJobRun(
    String job,
    DateTime scheduledAt, {
    APICronRunStatus status = APICronRunStatus.running,
    String? owner,
    DateTime? startedAt,
  }) {
    this.job = job;
    this.scheduledAt = scheduledAt;
    this.status = status;
    this.owner = owner;
    attempts = 0;
    calls = 0;
    this.startedAt = startedAt;
  }

  @override
  Map<String, TypeInfo> get types => _types;

  @override
  Map<String, List<EntityAnnotation>> get annotations => _annotations;

  String get job => getField<String>('job')!;

  set job(String job) => setField('job', job);

  DateTime get scheduledAt => getField<DateTime>('scheduledAt')!;

  set scheduledAt(DateTime d) => setField('scheduledAt', d);

  APICronRunStatus get status =>
      _parseRunStatus(getField('status')) ?? APICronRunStatus.running;

  set status(APICronRunStatus status) => setField('status', status.name);

  String? get owner => getField<String>('owner');

  set owner(String? owner) => setField('owner', owner);

  int get attempts => getField<int>('attempts') ?? 0;

  set attempts(int n) => setField('attempts', n);

  int get calls => getField<int>('calls') ?? 0;

  set calls(int n) => setField('calls', n);

  /// The continuation token of the last call: a resumed run continues from
  /// it.
  String? get continuation => getField<String>('continuation');

  set continuation(String? token) => setField('continuation', token);

  DateTime? get startedAt => getField<DateTime>('startedAt');

  set startedAt(DateTime? d) => setField('startedAt', d);

  DateTime? get finishedAt => getField<DateTime>('finishedAt');

  set finishedAt(DateTime? d) => setField('finishedAt', d);

  int? get durationMs => getField<int>('durationMs');

  set durationMs(int? ms) => setField('durationMs', ms);

  String? get lastError => getField<String>('lastError');

  set lastError(String? error) {
    if (error != null && error.length > maxErrorLength) {
      error = error.substring(0, maxErrorLength);
    }
    setField('lastError', error);
  }

  bool get isFinished =>
      status == APICronRunStatus.succeeded ||
      status == APICronRunStatus.failed ||
      status == APICronRunStatus.skipped;

  @override
  String toString() =>
      'APICronJobRun{id: $id, job: $job, scheduledAt: ${scheduledAt.toIso8601String()}, status: ${status.name}, owner: $owner, attempts: $attempts, calls: $calls${lastError != null ? ', lastError: $lastError' : ''}}';
}

/// The lock of an [APICronJob]: only its [owner] runs the job until
/// [leaseUntil] (renewed while running). Unique by [job].
class APICronJobLock extends _APICronEntity {
  static final Map<String, TypeInfo> _types = {
    'id': TypeInfo.tInt,
    'job': TypeInfo.tString,
    'owner': TypeInfo.tString,
    'leaseUntil': TypeInfo.tDateTime,
    'acquiredAt': TypeInfo.tDateTime,
  };

  static const Map<String, List<EntityAnnotation>> _annotations = {
    'job': [
      EntityField.unique(),
      EntityField.maximum(APICronJobRun.maxJobLength),
    ],
    'owner': [EntityField.maximum(APICronJobRun.maxOwnerLength)],
  };

  APICronJobLock.empty();

  APICronJobLock(
    String job,
    String owner,
    DateTime leaseUntil, {
    DateTime? acquiredAt,
  }) {
    this.job = job;
    this.owner = owner;
    this.leaseUntil = leaseUntil;
    this.acquiredAt = acquiredAt ?? DateTime.now().toUtc();
  }

  @override
  Map<String, TypeInfo> get types => _types;

  @override
  Map<String, List<EntityAnnotation>> get annotations => _annotations;

  String get job => getField<String>('job')!;

  set job(String job) => setField('job', job);

  String get owner => getField<String>('owner')!;

  set owner(String owner) => setField('owner', owner);

  DateTime get leaseUntil => getField<DateTime>('leaseUntil')!;

  set leaseUntil(DateTime d) => setField('leaseUntil', d);

  DateTime? get acquiredAt => getField<DateTime>('acquiredAt');

  set acquiredAt(DateTime? d) => setField('acquiredAt', d);

  bool isExpired(DateTime now) => !leaseUntil.isAfter(now);

  @override
  String toString() =>
      'APICronJobLock{id: $id, job: $job, owner: $owner, leaseUntil: ${leaseUntil.toIso8601String()}}';
}

/// The [EntityHandler] of [APICronJobRun].
final EntityHandler<APICronJobRun> apiCronJobRunEntityHandler =
    GenericEntityHandler<APICronJobRun>(
      instantiatorDefault: APICronJobRun.empty,
      entityIndexes: const [
        EntityIndex(['job', 'scheduledAt'], unique: true),
      ],
    );

/// The [EntityHandler] of [APICronJobLock].
final EntityHandler<APICronJobLock> apiCronJobLockEntityHandler =
    GenericEntityHandler<APICronJobLock>(
      instantiatorDefault: APICronJobLock.empty,
    );

/// The storage of the [APICronScheduler]: the runs of each occurrence and
/// the locks of the jobs. See [APICronStoreMemory] and [APICronStoreDB].
abstract class APICronStore {
  /// The run of the occurrence [scheduledAt] of [job], if any.
  FutureOr<APICronJobRun?> getRun(String job, DateTime scheduledAt);

  /// The run of [job] with the latest [APICronJobRun.scheduledAt].
  FutureOr<APICronJobRun?> lastRun(String job);

  /// Inserts [run], claiming its occurrence: `null` if the occurrence
  /// already has a run (another instance claimed it).
  FutureOr<APICronJobRun?> claimRun(APICronJobRun run);

  /// Updates the stored [run].
  FutureOr<bool> updateRun(APICronJobRun run);

  /// The runs of [job] with status [APICronRunStatus.running].
  FutureOr<List<APICronJobRun>> selectRunningRuns(String job);

  /// The latest runs of [job] (latest first), at most [limit].
  FutureOr<List<APICronJobRun>> selectRuns(String job, {int limit = 20});

  /// Deletes the runs of [job] scheduled before [before]. Returns the count.
  FutureOr<int> deleteRunsBefore(String job, DateTime before);

  /// The lock of [job], if any.
  FutureOr<APICronJobLock?> getLock(String job);

  /// Acquires the lock of [job] for [owner] until [now] + [lease]: `null` if
  /// another owner holds it (not expired). An expired lock is taken over;
  /// a lock of [owner] is renewed.
  FutureOr<APICronJobLock?> acquireLock(
    String job,
    String owner,
    Duration lease, {
    DateTime? now,
  });

  /// Renews [lock] until [now] + [lease]: `false` if it's no longer held by
  /// its owner (lost: expired and taken over).
  FutureOr<bool> renewLock(
    APICronJobLock lock,
    Duration lease, {
    DateTime? now,
  });

  /// Releases [lock] (only if still held by its owner).
  FutureOr<bool> releaseLock(APICronJobLock lock);
}

String _runKey(String job, DateTime scheduledAt) =>
    '$job@${scheduledAt.toUtc().microsecondsSinceEpoch}';

/// An in-memory [APICronStore]: for a single instance (and tests). Not
/// shared between processes.
class APICronStoreMemory extends APICronStore {
  final Map<String, APICronJobRun> _runs = {};
  final Map<String, APICronJobLock> _locks = {};

  int _runsIds = 0;
  int _locksIds = 0;

  @override
  APICronJobRun? getRun(String job, DateTime scheduledAt) =>
      _runs[_runKey(job, scheduledAt)];

  @override
  APICronJobRun? lastRun(String job) {
    APICronJobRun? last;
    for (var r in _runs.values) {
      if (r.job != job) continue;
      if (last == null || r.scheduledAt.isAfter(last.scheduledAt)) last = r;
    }
    return last;
  }

  @override
  APICronJobRun? claimRun(APICronJobRun run) {
    var key = _runKey(run.job, run.scheduledAt);
    if (_runs.containsKey(key)) return null;
    run.id ??= ++_runsIds;
    _runs[key] = run;
    return run;
  }

  @override
  bool updateRun(APICronJobRun run) {
    var key = _runKey(run.job, run.scheduledAt);
    if (!_runs.containsKey(key)) return false;
    _runs[key] = run;
    return true;
  }

  @override
  List<APICronJobRun> selectRunningRuns(String job) => _runs.values
      .where((r) => r.job == job && r.status == APICronRunStatus.running)
      .toList();

  @override
  List<APICronJobRun> selectRuns(String job, {int limit = 20}) {
    var runs = _runs.values.where((r) => r.job == job).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return runs.take(limit).toList();
  }

  @override
  int deleteRunsBefore(String job, DateTime before) {
    var keys = _runs.entries
        .where(
          (e) => e.value.job == job && e.value.scheduledAt.isBefore(before),
        )
        .map((e) => e.key)
        .toList();
    for (var k in keys) {
      _runs.remove(k);
    }
    return keys.length;
  }

  @override
  APICronJobLock? getLock(String job) => _locks[job];

  @override
  APICronJobLock? acquireLock(
    String job,
    String owner,
    Duration lease, {
    DateTime? now,
  }) {
    now ??= DateTime.now().toUtc();

    var lock = _locks[job];
    if (lock != null && lock.owner != owner && !lock.isExpired(now)) {
      return null;
    }

    if (lock != null && lock.owner == owner) {
      lock.leaseUntil = now.add(lease);
      return lock;
    }

    lock = APICronJobLock(job, owner, now.add(lease), acquiredAt: now)
      ..id = ++_locksIds;
    _locks[job] = lock;
    return lock;
  }

  @override
  bool renewLock(APICronJobLock lock, Duration lease, {DateTime? now}) {
    var current = _locks[lock.job];
    if (current == null || current.id != lock.id) return false;
    now ??= DateTime.now().toUtc();
    current.leaseUntil = now.add(lease);
    lock.leaseUntil = current.leaseUntil;
    return true;
  }

  @override
  bool releaseLock(APICronJobLock lock) {
    var current = _locks[lock.job];
    if (current == null || current.id != lock.id) return false;
    _locks.remove(lock.job);
    return true;
  }
}

/// An [APICronStore] in the database (tables `api_cron_job_run` and
/// `api_cron_job_lock`), shared by all the instances of the API:
///
/// - A run is claimed by inserting it: the unique ([job], [scheduledAt])
///   index lets only one instance insert it.
/// - A lock is acquired by inserting it (unique [job]). An expired lock is
///   deleted (only if still expired) and inserted again: only one instance
///   wins the insert.
///
/// Add [buildRepositories] to the [DBRelationalEntityRepositoryProvider] of
/// the API, so the tables are generated and checked with the others.
class APICronStoreDB extends APICronStore {
  static const String runsTable = 'api_cron_job_run';
  static const String locksTable = 'api_cron_job_lock';

  final EntityRepository<APICronJobRun> runsRepository;
  final EntityRepository<APICronJobLock> locksRepository;

  APICronStoreDB(this.runsRepository, this.locksRepository);

  /// The repositories of the cron tables for [adapter], to be returned by
  /// [DBRelationalEntityRepositoryProvider.buildRepositories].
  static List<EntityRepository<Object>> buildRepositories(
    DBSQLAdapter adapter,
  ) => [
    DBSQLEntityRepository<APICronJobRun>(
      adapter,
      runsTable,
      apiCronJobRunEntityHandler,
    ),
    DBSQLEntityRepository<APICronJobLock>(
      adapter,
      locksTable,
      apiCronJobLockEntityHandler,
    ),
  ];

  /// An [APICronStoreDB] with the repositories of the cron entities known by
  /// the entity handlers (registered with [buildRepositories]), or `null`.
  static APICronStoreDB? tryResolve() {
    var runs = apiCronJobRunEntityHandler.getEntityRepository<APICronJobRun>();
    var locks = apiCronJobLockEntityHandler
        .getEntityRepository<APICronJobLock>();
    if (runs == null || locks == null) return null;
    return APICronStoreDB(runs, locks);
  }

  static bool _isUniqueViolation(Object e) {
    if (e is EntityFieldInvalid) return e.reason == 'unique';
    var s = e.toString().toLowerCase();
    return s.contains('unique') || s.contains('duplicate');
  }

  @override
  FutureOr<APICronJobRun?> getRun(String job, DateTime scheduledAt) =>
      runsRepository.selectFirstByQuery(
        ' job == ? && scheduledAt == ? ',
        parameters: [job, scheduledAt.toUtc()],
      );

  @override
  FutureOr<APICronJobRun?> lastRun(String job) => runsRepository
      .selectByQuery(' job == ? ', parameters: [job])
      .resolveMapped((runs) {
        APICronJobRun? last;
        for (var r in runs) {
          if (last == null || r.scheduledAt.isAfter(last.scheduledAt)) {
            last = r;
          }
        }
        return last;
      });

  @override
  Future<APICronJobRun?> claimRun(APICronJobRun run) async {
    try {
      var id = await runsRepository.store(run);
      return id != null ? run : null;
    } catch (e) {
      if (_isUniqueViolation(e)) return null;
      rethrow;
    }
  }

  @override
  Future<bool> updateRun(APICronJobRun run) async {
    if (run.id == null) return false;
    var id = await runsRepository.store(run);
    return id != null;
  }

  @override
  FutureOr<List<APICronJobRun>> selectRunningRuns(String job) => runsRepository
      .selectByQuery(
        ' job == ? && status == ? ',
        parameters: [job, APICronRunStatus.running.name],
      )
      .resolveMapped((l) => l.toList());

  @override
  FutureOr<List<APICronJobRun>> selectRuns(String job, {int limit = 20}) =>
      runsRepository
          .selectByQuery(' job == ? ', parameters: [job])
          .resolveMapped((l) {
            var runs = l.toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
            return runs.take(limit).toList();
          });

  @override
  FutureOr<int> deleteRunsBefore(String job, DateTime before) => runsRepository
      .deleteByQuery(
        ' job == ? && scheduledAt < ? ',
        parameters: [job, before.toUtc()],
      )
      .resolveMapped((l) => l.length);

  @override
  FutureOr<APICronJobLock?> getLock(String job) =>
      locksRepository.selectFirstByQuery(' job == ? ', parameters: [job]);

  @override
  Future<APICronJobLock?> acquireLock(
    String job,
    String owner,
    Duration lease, {
    DateTime? now,
  }) async {
    now ??= DateTime.now().toUtc();

    var lock = await getLock(job);

    if (lock != null) {
      if (lock.owner == owner) {
        lock.leaseUntil = now.add(lease);
        await locksRepository.store(lock);
        return lock;
      }

      if (!lock.isExpired(now)) return null;

      // Only deletes it if still expired: a lock taken over meanwhile by
      // another instance (a new row) is not removed.
      await locksRepository.deleteByQuery(
        ' job == ? && leaseUntil <= ? ',
        parameters: [job, now],
      );
    }

    var newLock = APICronJobLock(job, owner, now.add(lease), acquiredAt: now);

    try {
      var id = await locksRepository.store(newLock);
      return id != null ? newLock : null;
    } catch (e) {
      if (_isUniqueViolation(e)) return null;
      rethrow;
    }
  }

  @override
  Future<bool> renewLock(
    APICronJobLock lock,
    Duration lease, {
    DateTime? now,
  }) async {
    var id = lock.id;
    if (id == null) return false;

    var current = await locksRepository.selectByID(id);
    if (current == null || current.owner != lock.owner) return false;

    now ??= DateTime.now().toUtc();
    current.leaseUntil = now.add(lease);
    await locksRepository.store(current);

    lock.leaseUntil = current.leaseUntil;
    return true;
  }

  @override
  Future<bool> releaseLock(APICronJobLock lock) async {
    var id = lock.id;
    if (id == null) return false;
    var deleted = await locksRepository.deleteByID(id);
    return deleted != null;
  }
}
