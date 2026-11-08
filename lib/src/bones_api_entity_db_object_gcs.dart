import 'dart:convert' as dart_convert;
import 'dart:io';
import 'dart:math' as math;

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart'
    show DetailedApiRequestError;
import 'package:async_extension/async_extension.dart';
import 'package:crclib/catalog.dart';
import 'package:crclib/crclib.dart';
import 'package:gcloud/storage.dart' as gcs;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_object.dart';
import 'bones_api_extension.dart';
import 'bones_api_extension_io.dart';
import 'bones_api_logging.dart';
import 'bones_api_types.dart';

final _log = logging.Logger('DBObjectGCSAdapter')..registerAsDbLogger();

class DBObjectGCSAdapterContext
    implements Comparable<DBObjectGCSAdapterContext> {
  final int id;

  DBObjectGCSAdapterContext(this.id);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBObjectGCSAdapterContext other) => id.compareTo(other.id);
}

/// A [DBObjectAdapter] that stores objects in Google Cloud Storage (GCS).
///
/// - See https://cloud.google.com/storage
///
/// Doesn't enforce unique fields: GCS (an object storage) has no index over
/// the objects' values, nor transactions over multiple objects (see
/// [DBObjectAdapter]: "Unique fields are not enforced").
class DBObjectGCSAdapter extends DBObjectAdapter<DBObjectGCSAdapterContext> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBObjectAdapter.boot();

    DBObjectAdapter.registerAdapter(
      ['object.gcs', 'obj.gcs', 'object.gcp', 'obj.gcp'],
      DBObjectGCSAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBObjectGCSAdapter?> _instantiate(
    Map<String, dynamic> config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBObjectGCSAdapter.fromConfig(
        config,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath,
      );
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final String projectName;
  final String bucketName;

  final bool cacheDevelopment;
  final Directory? cacheDirectory;
  final int? cacheLimit;
  final int? cacheFilesLimit;

  final int? cacheCheckMaxSkips;
  final Duration? cacheCheckTimeout;

  late final gcs.Storage storage;
  late final gcs.Bucket bucket;

  DBObjectGCSAdapter(
    http.Client client,
    this.projectName,
    this.bucketName, {
    bool? cacheDevelopment,
    this.cacheDirectory,
    this.cacheLimit,
    this.cacheFilesLimit,
    this.cacheCheckMaxSkips,
    this.cacheCheckTimeout,
    super.generateTables,
    super.populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.workingPath,
    super.log,
  }) : cacheDevelopment = cacheDevelopment ?? false,
       super(
         'object.gcs',
         1,
         3,
         const DBAdapterCapability(
           dialect: DBDialect('object'),
           transactions: true,
           transactionAbort: true,
           constraintSupport: false,
           multiIsolateSupport: true,
           connectivity: DBAdapterCapabilityConnectivity.secure,
         ),
         connectivity: DBAdapterConnectivity.secure,
       ) {
    boot();

    storage = gcs.Storage(client, projectName);

    bucket = storage.bucket(bucketName);

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);

    _checkCacheDirectoryLimit();
  }

  static Future<DBObjectGCSAdapter> fromConfig(
    Map<String, dynamic>? config, {
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) async {
    boot();

    var credential = config?.getIgnoreCase('credential');
    if (credential == null) {
      throw ArgumentError("Config without `credential`");
    }

    var project = config?.getAsString('project', ignoreCase: true);
    if (project == null || project.isEmpty) {
      throw ArgumentError("Config without `project`");
    }

    var bucket = config?.getAsString('bucket', ignoreCase: true);
    if (bucket == null || bucket.isEmpty) {
      throw ArgumentError("Config without `bucket`");
    }

    var cacheConfig = config?.getAsMap('cache', ignoreCase: true);

    bool cacheDevelopment = false;
    Directory? cacheDir;
    int? cacheLimit;
    int? cacheFilesLimit;

    if (cacheConfig != null) {
      cacheDevelopment = cacheConfig.getAsBool('development') ?? false;

      var path = cacheConfig.getAsString('path', ignoreCase: true)?.trim();
      if (path != null && path.isNotEmpty) {
        cacheDir = Directory(path);
      }

      var limitStr = cacheConfig.getAsString('limit', ignoreCase: true)?.trim();

      if (limitStr != null && limitStr.isNotEmpty) {
        limitStr = limitStr.replaceAll(RegExp(r'\s'), '').toLowerCase();

        var nPart = limitStr.length > 1
            ? limitStr.substring(0, limitStr.length - 1)
            : limitStr;

        int unit;
        if (limitStr.endsWith('g')) {
          cacheLimit = int.tryParse(nPart);
          unit = 1024 * 1024 * 1024;
        } else if (limitStr.endsWith('m')) {
          cacheLimit = int.tryParse(nPart);
          unit = 1024 * 1024;
        } else if (limitStr.endsWith('k')) {
          cacheLimit = int.tryParse(nPart);
          unit = 1024;
        } else {
          cacheLimit = int.tryParse(limitStr);
          unit = 1;
        }

        if (cacheLimit != null) {
          cacheLimit = cacheLimit * unit;

          if (cacheLimit <= 0) {
            cacheLimit = null;
          }
        }
      }

      var filesLimitStr =
          (cacheConfig.getAsString('filesLimit', ignoreCase: true) ??
                  cacheConfig.getAsString('files-limit', ignoreCase: true))
              ?.trim();

      if (filesLimitStr != null && filesLimitStr.isNotEmpty) {
        filesLimitStr = filesLimitStr.trim();
        cacheFilesLimit = int.tryParse(filesLimitStr);
        if (cacheFilesLimit != null && cacheFilesLimit <= 0) {
          cacheFilesLimit = null;
        }
      }
    }

    var populate = config?['populate'];

    var generateTables = false;
    Object? populateTables;
    Object? populateSource;
    Object? populateSourceVariables;

    if (populate is Map) {
      generateTables =
          populate.getAsBool('generateTables', ignoreCase: true) ??
          populate.getAsBool('generate-tables', ignoreCase: true) ??
          populate.getAsBool('generate_tables', ignoreCase: true) ??
          false;

      populateTables = populate['tables'];
      populateSource = populate['source'];
      populateSourceVariables = populate['variables'];
    }

    var client = await createGCSClient(credential);

    var adapter = DBObjectGCSAdapter(
      client,
      project,
      bucket,
      cacheDevelopment: cacheDevelopment,
      cacheDirectory: cacheDir,
      cacheLimit: cacheLimit,
      cacheFilesLimit: cacheFilesLimit,
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      populateSourceVariables: populateSourceVariables,
      workingPath: workingPath,
    );

    return adapter;
  }

  static Future<auth.AutoRefreshingAuthClient> createGCSClient(
    Object? credential,
  ) async {
    if (credential is String) {
      var credentialLC = credential.toLowerCase();
      if (credentialLC == 'metadata' || credentialLC == 'metadata.server') {
        return auth.clientViaMetadataServer();
      }
    }

    final accountCredentials = auth.ServiceAccountCredentials.fromJson(
      credential,
    );

    try {
      var client = await auth.clientViaServiceAccount(
        accountCredentials,
        gcs.Storage.SCOPES,
      );
      return client;
    } catch (e) {
      throw StateError("Error creating GCP client: $e");
    }
  }

  @override
  String getConnectionURL(DBObjectGCSAdapterContext connection) =>
      'object.gcs://${connection.id}';

  int _connectionCount = 0;

  @override
  DBObjectGCSAdapterContext createConnection() {
    var id = ++_connectionCount;
    return DBObjectGCSAdapterContext(id);
  }

  @override
  bool closeConnection(DBObjectGCSAdapterContext connection) {
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  Map<String, dynamic> information({bool extended = false, String? table}) {
    var info = <String, dynamic>{};
    info['project'] = projectName;
    info['bucket'] = bucketName;
    return info;
  }

  @override
  logging.Logger get adapterLogger => _log;

  @override
  DBObjectGCSAdapterException createAdapterException(
    String type,
    String message, {
    Object? parentError,
    StackTrace? parentStackTrace,
    Object? operation,
    Object? previousError,
  }) => DBObjectGCSAdapterException(
    type,
    message,
    parentError: parentError,
    parentStackTrace: parentStackTrace,
    operation: operation,
    previousError: previousError,
  );

  @override
  String toString() {
    final cacheDirectory = this.cacheDirectory;
    var closedStr = isClosed ? ', closed' : '';
    return 'DBObjectGCSAdapter#$instanceID'
        '{project: $projectName, bucket: $bucketName$closedStr}'
        '${cacheDirectory != null ? '@${cacheDirectory.path}' : ''}';
  }

  @override
  FutureOr<int> doCount(
    TransactionOperation op,
    String entityName,
    String table, {
    EntityMatcher? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<int, int>? preFinish,
  }) {
    return executeOperation(
      op,
      (conn) => _doCountImpl(op, table, matcher, parameters ?? namedParameters),
      preFinish,
    );
  }

  Future<int> _doCountImpl(
    TransactionOperation op,
    String table,
    EntityMatcher? matcher,
    Object? parameters,
  ) async {
    if (matcher != null) {
      if (matcher is ConditionID) {
        var id = matcher.resolveIDValue(parameters: parameters);

        var objFile = _resolveObjectFilePath(table, id);

        var objInfo = await _getObjectInfo(objFile);
        return objInfo != null && objInfo.length > 0 ? 1 : 0;
      }

      throw UnsupportedError("Relationship count not supported for: $matcher");
    }

    var list = await _listTableFiles(table);
    return list.length;
  }

  Future<List<String>> _listTableFiles(String table) async {
    var tablePath = _resolveTablePath(table);

    var entries = bucket.list(prefix: '$tablePath/', delimiter: '/');

    var listAll = await entries.map((e) => e.name).toList();
    return listAll;
  }

  @override
  FutureOr<List<I>> doExistIDs<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    List<I> ids,
  ) {
    return executeOperation<List<I>, List<I>>(
      op,
      (conn) => _doExistIDsImpl(op, table, ids),
      null,
    );
  }

  Future<List<I>> _doExistIDsImpl<I extends Object>(
    TransactionOperation op,
    String table,
    List<I> ids,
  ) async {
    var existsIDs = <I>[];

    for (var id in ids) {
      var objFile = _resolveObjectFilePath(table, id);
      var objInfo = await _getObjectInfo(objFile);
      if (objInfo != null && objInfo.length > 0) {
        existsIDs.add(id);
      }
    }

    return existsIDs;
  }

  @override
  FutureOr<R?> doSelectByID<R>(
    TransactionOperation op,
    String entityName,
    String table,
    Object id, {
    PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish,
  }) => executeOperation<Map<String, dynamic>?, R?>(
    op,
    (conn) => _doSelectByIDImpl<R>(table, id, entityName),
    preFinish,
  );

  FutureOr<Map<String, dynamic>?> _doSelectByIDImpl<R>(
    String table,
    Object id,
    String entityName,
  ) => _readObject(table, id);

  @override
  FutureOr<List<R>> doSelectByIDs<R>(
    TransactionOperation op,
    String entityName,
    String table,
    List<Object> ids, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<List<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeOperation<List<Map<String, dynamic>>, List<R>>(
    op,
    (conn) => _doSelectByIDsImpl<R>(
      table,
      ids,
      entityName,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ),
    preFinish,
  );

  FutureOr<List<Map<String, dynamic>>> _doSelectByIDsImpl<R>(
    String table,
    List<Object> ids,
    String entityName, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) async {
    var entries = await ids
        .map((id) => _readObject(table, id))
        .resolveAllNotNull();

    return applyTableOrderAndPagination(
      table,
      entries,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    );
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
    TransactionOperation op,
    String entityName,
    String table, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeOperation<Iterable<Map<String, dynamic>>, List<R>>(
    op,
    (conn) => _doSelectAllImpl<R>(
      table,
      entityName,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ),
    preFinish,
  );

  Future<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
    String table,
    String entityName, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) async {
    var files = await _listTableFiles(table);

    var entries = await files.map((f) {
      var fileName = f.split('/').last;
      var id = pack_path.withoutExtension(fileName);
      return _readObject(table, id);
    }).resolveAllNotNull();

    return applyTableOrderAndPagination(
      table,
      entries,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    );
  }

  @override
  FutureOr<R> doDelete<R>(
    TransactionOperation op,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  }) => executeOperation<Iterable<Map<String, dynamic>>, R>(
    op,
    (conn) =>
        _doDeleteImpl<R>(op, table, matcher, parameters ?? namedParameters),
    preFinish,
  );

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteImpl<R>(
    TransactionOperation op,
    String table,
    EntityMatcher<dynamic> matcher,
    Object? parameters,
  ) async {
    if (matcher is ConditionID) {
      var id = matcher.resolveIDValue(parameters: parameters);

      var entry = await _deleteObject(table, id);

      return entry == null ? [] : [entry];
    }

    throw UnsupportedError("Relationship delete not supported for: $matcher");
  }

  @override
  FutureOr<dynamic> doInsert<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation? preFinish,
  }) => executeOperation<dynamic, dynamic>(
    op,
    (conn) => _doInsertImpl<O>(op, table, fields, entityName),
    preFinish,
  );

  Future<Object> _doInsertImpl<O>(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
  ) async {
    var entry = normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    var idField = getTableIDFieldName(table);
    var id = entry[idField];

    _log.info(
      '[transaction:${op.transactionId}] doInsert> INSERT INTO $table OBJECT `$id`',
    );

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    await _saveObject(table, id, entry);

    return id;
  }

  @override
  FutureOr<dynamic> doUpdate<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Object id,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation? preFinish,
    bool allowAutoInsert = false,
  }) => executeOperation<dynamic, dynamic>(
    op,
    (conn) => _doUpdateImpl(op, table, fields, entityName, id),
    preFinish,
  );

  Future<Object> _doUpdateImpl(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
    Object id,
  ) async {
    _log.info(
      '[transaction:${op.transactionId}] doUpdate> UPDATE INTO $table OBJECT `$id`',
    );

    var changes = normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    // A partial update (only the changed `fields`): merged into the stored
    // object (if any: an auto-insert).
    // Only a not found object is `null` (an auto-insert): a read error fails
    // the update (merged with `null`, the other fields would be lost).
    var stored = await _readObject(table, id, failOnError: true);

    var entry = <String, dynamic>{...?stored, ...changes};

    var idField = getTableIDFieldName(table);
    entry[idField] = id;

    await _saveObject(table, id, entry);

    return id;
  }

  static final _jsonEncoder = dart_convert.JsonUtf8Encoder(
    null,
    DBObjectAdapter.toEncodableJson,
  );
  static const _jsonDecoder = dart_convert.JsonDecoder();
  static const _utf8Decoder = dart_convert.Utf8Decoder();

  static const String _objectContentType = 'application/json';

  Future<gcs.ObjectInfo?> _getObjectInfo(String file) async {
    try {
      var info = await bucket.info(file);
      return info;
    } catch (e, s) {
      var notFound = e is DetailedApiRequestError && e.status == 404;
      if (!notFound) {
        _log.severe(
          "Error getting info for bucket[$bucketName] file: `$file`",
          e,
          s,
        );
      }
      return null;
    }
  }

  Future<bool> _saveObject(
    String table,
    Object? id,
    Map<String, dynamic> obj,
  ) async {
    if (!_isValidId(id)) return false;

    var file = _resolveObjectFilePath(table, id);

    var jsonBytes = _jsonEncoder.convert(obj);

    var cacheFile = await _resolveCacheObjectFile(table, id);
    bool? cacheFileExists;

    // Cache enabled:
    if (cacheFile != null) {
      cacheFileExists = await cacheFile.exists();

      if (cacheFileExists) {
        var cacheFileLength = await cacheFile.length();

        if (cacheFileLength == jsonBytes.length) {
          var info = await _getObjectInfo(file);

          if (info != null && info.length == jsonBytes.length) {
            var crc32GCS = info.crc32CChecksumBytes;
            var crc32Json = Crc32C().convert(jsonBytes).crc32CChecksumBytes;

            var crc32JsonOk = crc32GCS.equalsElements(crc32Json);
            if (crc32JsonOk) {
              var cacheBytes = await cacheFile.readAsBytesLimited();
              if (!cacheBytes.equalsElements(jsonBytes)) {
                await cacheFile.writeAsBytes(jsonBytes);
              }
              return true;
            }
          }
        }
      }
    }

    var objInfo = await bucket.writeBytes(
      file,
      jsonBytes,
      contentType: _objectContentType,
    );

    var ok = objInfo.length == jsonBytes.length;

    // Cache enabled:
    if (cacheFile != null) {
      // If `cacheFile` does not exist yet, check its parent directory:
      if (cacheFileExists != true) {
        await _checkCacheFileParent(cacheFile);
      }

      _checkCacheDirectoryLimit();

      assert(cacheFile.parent.existsSync());
      await cacheFile.writeAsBytes(jsonBytes);

      _checkCacheDirectoryLimitUntrackedTotal += jsonBytes.length;
      _checkCacheDirectoryFilesLimitUntrackedTotal++;
    }

    return ok;
  }

  /// Reads the object [id] of [table], or `null` if not found.
  /// - [failOnError]: if `true`, an error other than not found (e.g. a
  ///   timeout or a 5xx response) is rethrown (otherwise logged, as not
  ///   found).
  Future<Map<String, dynamic>?> _readObject(
    String table,
    Object? id, {
    bool failOnError = false,
  }) async {
    if (!_isValidId(id)) return null;

    var cacheFile = await _resolveCacheObjectFile(table, id);

    List<int> bytes;

    if (cacheFile != null && await cacheFile.exists()) {
      bytes = await cacheFile.readAsBytesLimited();
    } else {
      var file = _resolveObjectFilePath(table, id);
      try {
        bytes = await bucket
            .read(file)
            .reduce((previous, element) => previous + element);
      } catch (e, s) {
        var notFound = e is DetailedApiRequestError && e.status == 404;
        if (!notFound) {
          _log.severe("Error reading bucket[$bucketName] file: `$file`", e, s);
          if (failOnError) rethrow;
        }
        return null;
      }

      if (cacheFile != null) {
        await _checkCacheFileParent(cacheFile);
        await cacheFile.writeAsBytes(bytes);
      }

      _checkCacheDirectoryLimitUntrackedTotal += bytes.length;
      _checkCacheDirectoryFilesLimitUntrackedTotal++;
    }

    var json = _utf8Decoder.convert(bytes);

    var obj = _jsonDecoder.convert(json) as Map<String, dynamic>;
    return obj;
  }

  Future<bool> _checkCacheFileParent(File cacheFile) async {
    var parent = cacheFile.parent;
    var parentExists = await parent.exists();
    if (!parentExists) {
      await parent.create(recursive: true);
    }
    return true;
  }

  Future<Map<String, dynamic>?> _deleteObject(String table, Object? id) async {
    var entry = await _readObject(table, id);
    if (entry == null) return null;

    var objFile = _resolveObjectFilePath(table, id);
    await bucket.delete(objFile);

    var cacheFile = await _resolveCacheObjectFile(table, id);
    await cacheFile?.deleteLimited();

    return entry;
  }

  DateTime _checkCacheDirectoryLimitLastTime = DateTime.utc(2020);
  int _checkCacheDirectoryLimitSkips = 0;
  int _checkCacheDirectoryLimitLastTotalSize = 0;
  int _checkCacheDirectoryLimitLastTotalFiles = 0;
  int _checkCacheDirectoryLimitUntrackedTotal = 0;
  int _checkCacheDirectoryFilesLimitUntrackedTotal = 0;

  Future<bool>? _checkCacheDirectoryLimitInFlight;
  Future<bool>? _checkCacheDirectoryLimitQueued;
  bool _checkCacheDirectoryLimitQueuedForce = false;

  /// Checks the cache directory limits, one check at a time. Concurrent
  /// checks (e.g. from parallel cache writes) listed the same files and
  /// deleted the same ones, the second delete failing.
  ///
  /// A call while a check is running queues one more check after it: the
  /// running one may have listed the files before this call's cache write.
  /// The calls until then share that queued check (forced if any of them
  /// is).
  Future<bool> _checkCacheDirectoryLimit({bool force = false}) {
    var inFlight = _checkCacheDirectoryLimitInFlight;
    if (inFlight == null) {
      return _startCheckCacheDirectoryLimit(force);
    }

    if (force) _checkCacheDirectoryLimitQueuedForce = true;

    return _checkCacheDirectoryLimitQueued ??= inFlight
        .catchError((_) => false)
        .then((_) {
          var queuedForce = _checkCacheDirectoryLimitQueuedForce;
          _checkCacheDirectoryLimitQueued = null;
          _checkCacheDirectoryLimitQueuedForce = false;
          return _checkCacheDirectoryLimit(force: queuedForce);
        });
  }

  Future<bool> _startCheckCacheDirectoryLimit(bool force) {
    // Nobody awaits a check (it runs alongside the cache writes): an error
    // (e.g. the cache directory removed, the adapter closed) is logged, not
    // left as an unhandled error.
    var check = _checkCacheDirectoryLimitImpl(force: force)
        .catchError((Object error, StackTrace stackTrace) {
          _log.warning('[CACHE] Limit check failed', error, stackTrace);
          return false;
        });
    _checkCacheDirectoryLimitInFlight = check;

    // Registered before any queued check's listener: it runs first.
    return check.whenComplete(() {
      if (identical(_checkCacheDirectoryLimitInFlight, check)) {
        _checkCacheDirectoryLimitInFlight = null;
      }
    });
  }

  Future<bool> _checkCacheDirectoryLimitImpl({bool force = false}) async {
    var cacheLimit = this.cacheLimit ?? 0;
    var cacheFilesLimit = this.cacheFilesLimit ?? 0;
    if (cacheLimit <= 0 && cacheFilesLimit <= 0) return false;

    var cacheCheckMaxSkips = math.max(10, this.cacheCheckMaxSkips ?? 200);

    var cacheCheckTimeout = this.cacheCheckTimeout ?? Duration(minutes: 10);
    if (cacheCheckTimeout.inSeconds < 10) {
      cacheCheckTimeout = Duration(seconds: 10);
    }

    if (!force) {
      var estimatedTotalSize =
          _checkCacheDirectoryLimitLastTotalSize +
          _checkCacheDirectoryLimitUntrackedTotal;

      var estimatedTotalFiles =
          _checkCacheDirectoryLimitLastTotalFiles +
          _checkCacheDirectoryFilesLimitUntrackedTotal;

      var inLimitSize = cacheLimit == 0 || estimatedTotalSize <= cacheLimit;
      var inLimitFiles =
          cacheFilesLimit == 0 || estimatedTotalFiles <= cacheFilesLimit;

      var lowSkips = _checkCacheDirectoryLimitSkips < cacheCheckMaxSkips;

      var notExpired =
          _checkCacheDirectoryLimitLastTime.elapsedTime < cacheCheckTimeout;

      // Skip check:
      if (inLimitSize && inLimitFiles && lowSkips && notExpired) {
        ++_checkCacheDirectoryLimitSkips;
        return false;
      }
    }

    final cacheDirectory = this.cacheDirectory;
    if (cacheDirectory == null) {
      return false;
    }

    var cacheDirectoryExists = await cacheDirectory.exists();

    if (!cacheDirectoryExists &&
        cacheDevelopment &&
        cacheDirectory.path.contains('/tmp/')) {
      cacheDirectory.createSync();
      cacheDirectoryExists = cacheDirectory.existsSync();
      if (cacheDirectoryExists) {
        _log.warning(
          "[cacheDevelopment] Auto-created `cacheDirectory`: ${cacheDirectory.path}",
        );
      }
    }

    if (!cacheDirectoryExists) {
      final errorMsg =
          "Invalid `cacheDirectory` — Directory does not exist: "
          "${cacheDirectory.path}";
      _log.severe(errorMsg);
      throw StateError(errorMsg);
    }

    var list = await cacheDirectory.list(recursive: true).toList();
    if (list.isEmpty) return false;

    final checkInitTime = DateTime.now();
    _checkCacheDirectoryLimitLastTime = checkInitTime;
    _checkCacheDirectoryLimitSkips = 0;

    var files = list
        .whereType<File>()
        .where((f) => f.path.endsWith(".json"))
        .toList();

    var totalFiles = files.length;

    var filesStats = await files
        .map((f) => MapEntry(f, f.statLimited()))
        .toMapFromEntries()
        .resolveAllValues();

    var totalSize = filesStats.values.map((s) => s.size).sum;

    _checkCacheDirectoryLimitLastTotalSize = totalSize;
    _checkCacheDirectoryLimitLastTotalFiles = totalFiles;
    _checkCacheDirectoryLimitUntrackedTotal = 0;
    _checkCacheDirectoryFilesLimitUntrackedTotal = 0;

    final checkTime = DateTime.now().difference(checkInitTime);

    final cacheLimitOk = cacheLimit == 0 || totalSize <= cacheLimit;
    final cacheFilesLimitOk =
        cacheFilesLimit == 0 || totalFiles <= cacheFilesLimit;

    if (cacheLimitOk && cacheFilesLimitOk) {
      var r = (totalSize / cacheLimit) * 100;
      _log.info(
        '[CACHE] Limit check[${checkTime.inMilliseconds} ms]: OK ($totalSize${cacheLimit > 0 ? ' / $cacheLimit' : ''} bytes ${r.toStringAsFixed(2)}%)  ($totalFiles${cacheFilesLimit > 0 ? ' / $cacheFilesLimit' : ''} files)',
      );
      return false;
    }

    var entries = filesStats.entries.toList();
    entries.sort((a, b) => a.value.modified.compareTo(b.value.modified));

    final delNeededFiles = cacheFilesLimit <= 0
        ? 0
        :
          // Del extra files + 20%:
          (totalFiles - (cacheFilesLimit * 0.80)).toInt();

    final delNeededSize = cacheLimit <= 0
        ? 0
        :
          // Del extra bytes + 20%:
          (totalSize - (cacheLimit * 0.80)).toInt();

    var releaseInfo = [
      if (delNeededFiles > 0) '$delNeededFiles files',
      if (delNeededSize > 0) '$delNeededSize bytes',
    ].join(' and ');

    _log.info(
      '[CACHE] Limit Check[${checkTime.inMilliseconds} ms] reached limit: $totalSize${cacheLimit > 0 ? ' / $cacheLimit' : ''} bytes '
      '(${entries.length}${cacheFilesLimit > 0 ? ' / $cacheFilesLimit' : ''} files)! '
      'Releasing $releaseInfo...',
    );

    var del = <File>[];
    var delSize = 0;

    for (var e in entries) {
      var f = e.key;
      var s = e.value;

      del.add(f);
      delSize += s.size;

      if (delSize >= delNeededSize && del.length >= delNeededFiles) break;
    }

    _log.info('[CACHE] Removing ${del.length} files... ($delSize bytes)');

    final removeInitTime = DateTime.now();

    // A file already removed (e.g. by another process sharing the cache
    // directory) is as good as deleted.
    var delResults = await del
        .map(
          (f) => f.deleteLimited().catchError(
            (_) {},
            test: (e) => e is PathNotFoundException,
          ),
        )
        .toList()
        .resolveAll();

    final removeTime = DateTime.now().difference(removeInitTime);

    _log.info(
      '[CACHE] Removed files[${removeTime.inMilliseconds} ms]: ${delResults.length} ($delSize bytes)',
    );

    return true;
  }

  bool _isValidId(Object? id) {
    if (id == null) return false;
    var idStr = id.toString().trim();
    return idStr.isNotEmpty;
  }

  String _resolveObjectFilePath(String table, Object? id) {
    var idStr = normalizeObjectID(id);
    var tablePath = _resolveTablePath(table);
    var file = '$tablePath/$idStr.json';
    return file;
  }

  String _resolveTablePath(String table) {
    var tableStr = normalizeTableName(table);
    return tableStr;
  }

  /// Returns the cache [File] for [table]/[id].
  /// Returns null if the cache is not enabled.
  FutureOr<File?> _resolveCacheObjectFile(
    String table,
    Object? id, {
    bool autoCreateDir = false,
  }) {
    return _resolveCacheTableDirectory(
      table,
      autoCreateDir: autoCreateDir,
    ).resolveMapped((tableDir) {
      if (tableDir == null) return null;
      var idStr = normalizeObjectID(id);
      var file = File(pack_path.join(tableDir.path, '$idStr.json'));
      return file;
    });
  }

  /// Returns the cache [Directory] for [table].
  /// Returns null if the cache is not enabled.
  FutureOr<Directory?> _resolveCacheTableDirectory(
    String table, {
    bool autoCreateDir = false,
  }) {
    var cacheDirectory = this.cacheDirectory;
    if (cacheDirectory == null) return null;

    var tableStr = normalizeTableName(table);
    var tableDir = Directory(pack_path.join(cacheDirectory.path, tableStr));

    if (autoCreateDir) {
      return _resolveCacheTableDirectoryAutoCreate(tableDir);
    } else {
      return tableDir;
    }
  }

  Future<Directory> _resolveCacheTableDirectoryAutoCreate(
    Directory tableDir,
  ) async {
    var tableDirExists = await tableDir.exists();
    if (!tableDirExists) {
      await tableDir.create(recursive: true);
    }
    return tableDir;
  }
}

/// Error thrown by [DBObjectGCSAdapter] operations.
class DBObjectGCSAdapterException extends DBObjectAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectGCSAdapterException';

  DBObjectGCSAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}

extension _ObjectInfoExtension on gcs.ObjectInfo {
  List<int> get crc32CChecksumBytes {
    var n = crc32CChecksum;
    return [(n) & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF];
  }
}

extension _CrcValueExtension on CrcValue {
  List<int> get crc32CChecksumBytes {
    var n = toBigInt().toInt();
    return [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, (n) & 0xFF];
  }
}
