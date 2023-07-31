import 'dart:convert' as dart_convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:crclib/catalog.dart';
import 'package:crclib/crclib.dart';
import 'package:gcloud/storage.dart' as gcs;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_object.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';
import 'bones_api_logging.dart';

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
class DBObjectGCSAdapter extends DBObjectAdapter<DBObjectGCSAdapterContext> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBObjectAdapter.boot();

    DBObjectAdapter.registerAdapter([
      'object.gcs',
      'obj.gcs',
      'object.gcp',
      'obj.gcp',
    ], DBObjectGCSAdapter, _instantiate);
  }

  static FutureOr<DBObjectGCSAdapter?> _instantiate(config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    try {
      return DBObjectGCSAdapter.fromConfig(config,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath);
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final String projectName;
  final String bucketName;

  final Directory? cacheDirectory;
  final int? cacheLimit;

  late final gcs.Storage storage;
  late final gcs.Bucket bucket;

  DBObjectGCSAdapter(http.Client client, this.projectName, this.bucketName,
      {this.cacheDirectory,
      this.cacheLimit,
      super.generateTables,
      super.populateTables,
      super.populateSource,
      super.parentRepositoryProvider,
      super.workingPath,
      super.log})
      : super(
          'object.gcs',
          1,
          3,
          const DBAdapterCapability(
              dialect: DBDialect('object'),
              transactions: true,
              transactionAbort: true),
        ) {
    boot();

    storage = gcs.Storage(client, projectName);

    bucket = storage.bucket(bucketName);

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);

    _checkCacheDirectoryLimit();
  }

  static Future<DBObjectGCSAdapter> fromConfig(Map<String, dynamic>? config,
      {EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) async {
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

    Directory? cacheDir;
    int? cacheLimit;

    if (cacheConfig != null) {
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
    }

    var populate = config?['populate'];

    var generateTables = false;
    Object? populateTables;
    Object? populateSource;

    if (populate is Map) {
      generateTables = populate.getAsBool('generateTables', ignoreCase: true) ??
          populate.getAsBool('generate-tables', ignoreCase: true) ??
          populate.getAsBool('generate_tables', ignoreCase: true) ??
          false;

      populateTables = populate['tables'];
      populateSource = populate['source'];
    }

    var client = await createGCSClient(credential);

    var adapter = DBObjectGCSAdapter(
      client,
      project,
      bucket,
      cacheDirectory: cacheDir,
      cacheLimit: cacheLimit,
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      workingPath: workingPath,
    );

    return adapter;
  }

  static Future<auth.AutoRefreshingAuthClient> createGCSClient(
      credential) async {
    if (credential is String) {
      var credentialLC = credential.toLowerCase();
      if (credentialLC == 'metadata' || credentialLC == 'metadata.server') {
        return auth.clientViaMetadataServer();
      }
    }

    final accountCredentials =
        auth.ServiceAccountCredentials.fromJson(credential);

    try {
      var client = await auth.clientViaServiceAccount(
          accountCredentials, gcs.Storage.SCOPES);
      return client;
    } catch (e) {
      throw StateError("Error creating GCP client: $e");
    }
  }

  @override
  String getConnectionURL(DBObjectGCSAdapterContext connection) =>
      'object.directory://${connection.id}';

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

  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  @override
  TableScheme? getTableSchemeImpl(
      String table, TableRelationshipReference? relationship) {
    _log.info('getTableSchemeImpl> $table ; relationship: $relationship');

    var tableScheme = tablesSchemes[table];
    if (tableScheme != null) return tableScheme;

    var entityHandler = getEntityHandler(tableName: table);
    if (entityHandler == null) {
      if (relationship != null) {
        var sourceId =
            '${relationship.sourceTable}_${relationship.sourceField}';
        var targetId =
            '${relationship.targetTable}_${relationship.targetField}';

        tableScheme = TableScheme(table,
            relationship: true,
            idFieldName: sourceId,
            fieldsTypes: {
              sourceId: relationship.sourceFieldType,
              targetId: relationship.targetFieldType,
            });

        _log.info('relationship> $tableScheme');

        return tableScheme;
      }

      throw StateError(
          "Can't resolve `TableScheme` for table `$table`. No `EntityHandler` found for table `$table`!");
    }

    var idFieldName = entityHandler.idFieldName();

    var entityFieldsTypes = entityHandler.fieldsTypes();

    var fieldsTypes =
        entityFieldsTypes.map((key, value) => MapEntry(key, value.type));

    tableScheme = TableScheme(table,
        relationship: relationship != null,
        idFieldName: idFieldName,
        fieldsTypes: fieldsTypes);

    _log.info('$tableScheme');

    return tableScheme;
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) {
    return tablesSchemes[table]?.fieldsTypes;
  }

  @override
  FutureOr<bool> isConnectionValid(connection) => true;

  final Map<DBObjectGCSAdapterContext, DateTime> _openTransactionsContexts =
      <DBObjectGCSAdapterContext, DateTime>{};

  @override
  DBObjectGCSAdapterContext openTransaction(Transaction transaction) {
    var conn = createConnection();

    _openTransactionsContexts[conn] = DateTime.now();

    transaction.transactionFuture
        // ignore: discarded_futures
        .then(
      // ignore: discarded_futures
      (res) => resolveTransactionResult(res, transaction, conn),
      onError: (e, s) {
        cancelTransaction(transaction, conn, e, s);
        throw e;
      },
    );

    return conn;
  }

  @override
  bool get cancelTransactionResultWithError => true;

  @override
  bool get throwTransactionResultWithError => false;

  @override
  bool cancelTransaction(
      Transaction transaction,
      DBObjectGCSAdapterContext? connection,
      Object? error,
      StackTrace? stackTrace) {
    _openTransactionsContexts.remove(connection);
    return true;
  }

  @override
  bool get callCloseTransactionRequired => true;

  @override
  FutureOr<void> closeTransaction(
      Transaction transaction, DBObjectGCSAdapterContext? connection) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  void _consolidateTransactionContext(DBObjectGCSAdapterContext context) {
    _openTransactionsContexts.remove(context);
  }

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
      TransactionOperation op, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<int, int>? preFinish}) {
    return executeTransactionOperation(
        op,
        (conn) => _doCountImpl(op, table, matcher, parameters)
            .resolveMapped((res) => _finishOperation(op, res, preFinish)));
  }

  Future<int> _doCountImpl(TransactionOperation op, String table,
      EntityMatcher? matcher, Object? parameters) async {
    if (matcher != null) {
      if (matcher is ConditionID) {
        var id = matcher.idValue ?? matcher.getID(parameters);

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
  FutureOr<R?> doSelectByID<R>(
          TransactionOperation op, String entityName, String table, Object id,
          {PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish}) =>
      executeTransactionOperation<R?>(
          op,
          (conn) => _doSelectByIDImpl<R>(table, id, entityName)
              .resolveMapped((res) => _finishOperation(op, res, preFinish)));

  FutureOr<Map<String, dynamic>?> _doSelectByIDImpl<R>(
          String table, Object id, String entityName) =>
      _readObject(table, id);

  @override
  FutureOr<List<R>> doSelectByIDs<R>(TransactionOperation op, String entityName,
          String table, List<Object> ids,
          {PreFinishDBOperation<List<Map<String, dynamic>>, List<R>>?
              preFinish}) =>
      executeTransactionOperation<List<R>>(
          op,
          (conn) => _doSelectByIDsImpl<R>(table, ids, entityName)
              .resolveMapped((res) => _finishOperation(op, res, preFinish)));

  FutureOr<List<Map<String, dynamic>>> _doSelectByIDsImpl<R>(
      String table, List<Object> ids, String entityName) async {
    var entries =
        await ids.map((id) => _readObject(table, id)).resolveAllNotNull();

    return entries;
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
          TransactionOperation op, String entityName, String table,
          {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
              preFinish}) =>
      executeTransactionOperation<List<R>>(
          op,
          (conn) => _doSelectAllImpl<R>(table, entityName)
              .resolveMapped((res) => _finishOperation(op, res, preFinish)));

  Future<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
      String table, String entityName) async {
    var files = await _listTableFiles(table);

    var entries = files.map((f) {
      var fileName = f.split('/').last;
      var id = pack_path.withoutExtension(fileName);
      return _readObject(table, id);
    }).resolveAllNotNull();

    return entries;
  }

  @override
  FutureOr<R> doDelete<R>(TransactionOperation op, String entityName,
          String table, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>?
              preFinish}) =>
      executeTransactionOperation(
          op,
          (conn) => _doDeleteImpl<R>(op, table, matcher, parameters)
              .resolveMapped((res) => _finishOperation(op, res, preFinish)));

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteImpl<R>(
      TransactionOperation op,
      String table,
      EntityMatcher<dynamic> matcher,
      Object? parameters) async {
    if (matcher is ConditionID) {
      var id = matcher.idValue ?? matcher.getID(parameters);

      var entry = await _deleteObject(table, id);

      return entry == null ? [] : [entry];
    }

    throw UnsupportedError("Relationship delete not supported for: $matcher");
  }

  String _getTableIDFieldName(String table) {
    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    return idField;
  }

  @override
  FutureOr<dynamic> doInsert<O>(TransactionOperation op, String entityName,
          String table, O o, Map<String, dynamic> fields,
          {String? idFieldName, PreFinishDBOperation? preFinish}) =>
      executeTransactionOperation<dynamic>(op,
          (conn) => _doInsertImpl<O>(op, table, fields, entityName, preFinish));

  FutureOr<dynamic> _doInsertImpl<O>(
      TransactionOperation op,
      String table,
      Map<String, dynamic> fields,
      String entityName,
      PreFinishDBOperation? preFinish) async {
    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    var id = entry[idField];

    _log.info(
        '[transaction:${op.transactionId}] doInsert> INSERT INTO $table OBJECT `$id`');

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    await _saveObject(table, id, entry);

    return _finishOperation(op, id, preFinish);
  }

  @override
  FutureOr<dynamic> doUpdate<O>(TransactionOperation op, String entityName,
          String table, O o, Object id, Map<String, dynamic> fields,
          {String? idFieldName,
          PreFinishDBOperation? preFinish,
          bool allowAutoInsert = false}) =>
      executeTransactionOperation(
          op,
          (conn) =>
              _doUpdateImpl(op, table, fields, entityName, id, preFinish));

  FutureOr<dynamic> _doUpdateImpl(
      TransactionOperation op,
      String table,
      Map<String, dynamic> fields,
      String entityName,
      Object id,
      PreFinishDBOperation? preFinish) async {
    _log.info(
        '[transaction:${op.transactionId}] doUpdate> UPDATE INTO $table OBJECT `$id`');

    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    entry[idField] = id;

    await _saveObject(table, id, entry);

    return _finishOperation(op, id, preFinish);
  }

  static final _jsonEncoder = dart_convert.JsonUtf8Encoder();
  static const _jsonDecoder = dart_convert.JsonDecoder();
  static const _utf8Decoder = dart_convert.Utf8Decoder();

  static const String _objectContentType = 'application/json';

  Future<gcs.ObjectInfo?> _getObjectInfo(String file) async {
    try {
      var info = await bucket.info(file);
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _saveObject(
      String table, Object? id, Map<String, dynamic> obj) async {
    if (!_isValidId(id)) return false;

    var file = _resolveObjectFilePath(table, id);

    var jsonBytes = _jsonEncoder.convert(obj);

    var cacheFile = _resolveCacheObjectFile(table, id);
    if (cacheFile != null && cacheFile.existsSync()) {
      var info = await _getObjectInfo(file);

      if (info != null && info.length == jsonBytes.length) {
        var crc32GCS = info.crc32CChecksumBytes;
        var crc32Json = Crc32C().convert(jsonBytes).crc32CChecksumBytes;

        var crc32JsonOk = crc32GCS.equalsElements(crc32Json);

        if (crc32JsonOk) {
          var cacheBytes = cacheFile.readAsBytesSync();

          if (!cacheBytes.equalsElements(jsonBytes)) {
            cacheFile.writeAsBytesSync(jsonBytes);
          }

          return true;
        }
      }
    }

    var objInfo = await bucket.writeBytes(file, jsonBytes,
        contentType: _objectContentType);
    var ok = objInfo.length == jsonBytes.length;

    cacheFile = _resolveCacheObjectFile(table, id, autoCreateDir: true);

    if (cacheFile != null) {
      _checkCacheDirectoryLimit();
      cacheFile.writeAsBytesSync(jsonBytes);
      _checkCacheDirectoryLimitUntrackedTotal += jsonBytes.length;
    }

    return ok;
  }

  Future<Map<String, dynamic>?> _readObject(String table, Object? id) async {
    if (!_isValidId(id)) return null;

    var cacheFile = _resolveCacheObjectFile(table, id);

    List<int> bytes;

    if (cacheFile != null && cacheFile.existsSync()) {
      bytes = cacheFile.readAsBytesSync();
    } else {
      var file = _resolveObjectFilePath(table, id);

      try {
        bytes = await bucket
            .read(file)
            .reduce((previous, element) => previous + element);
      } catch (e) {
        return null;
      }
    }

    cacheFile?.writeAsBytesSync(bytes);
    _checkCacheDirectoryLimitUntrackedTotal += bytes.length;

    var json = _utf8Decoder.convert(bytes);

    var obj = _jsonDecoder.convert(json) as Map<String, dynamic>;
    return obj;
  }

  Future<Map<String, dynamic>?> _deleteObject(String table, Object? id) async {
    var entry = await _readObject(table, id);
    if (entry == null) return null;

    var objFile = _resolveObjectFilePath(table, id);
    await bucket.delete(objFile);

    var cacheFile = _resolveCacheObjectFile(table, id);
    cacheFile?.deleteSync();

    return entry;
  }

  DateTime _checkCacheDirectoryLimitLastTime = DateTime.utc(2020);
  int _checkCacheDirectoryLimitSkips = 0;
  int _checkCacheDirectoryLimitLastTotal = 0;
  int _checkCacheDirectoryLimitUntrackedTotal = 0;

  void _checkCacheDirectoryLimit({bool force = false}) async {
    var cacheLimit = this.cacheLimit ?? 0;
    if (cacheLimit <= 0) return;

    if (!force) {
      var estimatedTotal = _checkCacheDirectoryLimitLastTotal +
          _checkCacheDirectoryLimitUntrackedTotal;

      var inLimit = estimatedTotal <= cacheLimit;
      var lowSkips = _checkCacheDirectoryLimitSkips < 100;
      var notExpired =
          _checkCacheDirectoryLimitLastTime.elapsedTime < Duration(minutes: 5);

      // Skip check:
      if (inLimit && lowSkips && notExpired) {
        ++_checkCacheDirectoryLimitSkips;
        return;
      }
    }

    var list = cacheDirectory?.listSync(recursive: true);
    if (list == null || list.isEmpty) return;

    _checkCacheDirectoryLimitLastTime = DateTime.now();
    _checkCacheDirectoryLimitSkips = 0;

    var files =
        list.whereType<File>().where((f) => f.path.endsWith(".json")).toList();

    var filesStats = await files
        .map((f) => MapEntry(f, f.stat()))
        .toMapFromEntries()
        .resolveAllValues();

    var totalSize = filesStats.values.map((s) => s.size).sum;

    _checkCacheDirectoryLimitLastTotal = totalSize;
    _checkCacheDirectoryLimitUntrackedTotal = 0;

    if (totalSize <= cacheLimit) {
      var r = (totalSize / cacheLimit) * 100;
      _log.info(
          '[CACHE] Limit check: OK ($totalSize / $cacheLimit bytes ${r.toStringAsFixed(2)}%)  (${filesStats.length} files)');
      return;
    }

    var entries = filesStats.entries.toList();
    entries.sort((a, b) => a.value.modified.compareTo(b.value.modified));

    final delNeededSize = ((totalSize * 0.80) - cacheLimit).toInt();

    _log.info(
        '[CACHE] Reached limit: $totalSize / $cacheLimit bytes (${entries.length} files)! Releasing $delNeededSize bytes...');

    var del = <File>[];
    var delSize = 0;

    for (var e in entries) {
      var f = e.key;
      var s = e.value;

      del.add(f);

      delSize += s.size;
      if (delSize >= delNeededSize) break;
    }

    _log.info('[CACHE] Removing ${del.length} files...');

    var delResuls = await del.map((f) => f.delete()).toList().resolveAll();

    _log.info('[CACHE] Removed files: ${delResuls.length} ($delSize bytes)');
  }

  bool _isValidId(Object? id) {
    if (id == null) return false;
    var idStr = id.toString().trim();
    return idStr.isNotEmpty;
  }

  String _resolveObjectFilePath(String table, Object? id) {
    var idStr = _normalizeID(id);
    var tablePath = _resolveTablePath(table);
    var file = '$tablePath/$idStr.json';
    return file;
  }

  String _resolveTablePath(String table) {
    var tableStr = _normalizeTableName(table);
    return tableStr;
  }

  File? _resolveCacheObjectFile(String table, Object? id,
      {bool autoCreateDir = false}) {
    var tableDir =
        _resolveCacheTableDirectory(table, autoCreateDir: autoCreateDir);
    if (tableDir == null) return null;
    var idStr = _normalizeID(id);
    var file = File(pack_path.join(tableDir.path, '$idStr.json'));
    return file;
  }

  Directory? _resolveCacheTableDirectory(String table,
      {bool autoCreateDir = false}) {
    var cacheDirectory = this.cacheDirectory;
    if (cacheDirectory == null) return null;
    var tableStr = _normalizeTableName(table);
    var tableDir = Directory(pack_path.join(cacheDirectory.path, tableStr));

    if (autoCreateDir && !tableDir.existsSync()) {
      tableDir.createSync();
    }

    return tableDir;
  }

  static final _regExpNormalizeIDInvalidChars = RegExp(r'[^\w.-]+');
  static final _regExpNormalizeIDInvalidPrefix = RegExp(r'^\.+');

  String _normalizeID(Object? o) {
    var id = o?.toString() ?? '';
    if (id.isEmpty) {
      throw StateError("Empty ID string.");
    }

    id = id
        .replaceAll(_regExpNormalizeIDInvalidChars, '')
        .replaceAll(_regExpNormalizeIDInvalidPrefix, '');
    id = id.truncate(220);
    return id;
  }

  static final _regExpNormalizeTableNonWord = RegExp(r'\W');

  String _normalizeTableName(String table) {
    table = table.trim().replaceAll(_regExpNormalizeTableNonWord, '_');
    if (table.isEmpty) {
      throw StateError("Empty table name.");
    }
    return table;
  }

  Map<String, dynamic> _normalizeEntityJSON(Map<String, dynamic> entityJson,
      {String? entityName, String? table, EntityRepository? entityRepository}) {
    entityRepository ??=
        getEntityRepository(name: entityName, tableName: table);

    if (entityRepository == null) {
      throw StateError(
          "Can't determine `EntityRepository` for: entityName=$entityName ; tableName=$table");
    }

    var entityHandler = entityRepository.entityHandler;

    var entityJsonNormalized = entityJson.map((key, value) {
      if (value == null || (value as Object).isPrimitiveValue) {
        return MapEntry(key, value);
      } else if (value is Uint8List) {
        var dataURLBase64 = DataURLBase64.from(value);
        return MapEntry(key, dataURLBase64.toString());
      }

      var fieldType = entityHandler.getFieldType(null, key);

      if (fieldType != null) {
        if (fieldType.isEntityReferenceType) {
          var entityType = fieldType.arguments0!.type;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
                "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType");
          }

          if (value is EntityReference) {
            if (value.isNull) {
              value = null;
            } else if (value.isIdSet) {
              value = value.id;
            } else if (value.isEntitySet) {
              value = fieldEntityRepository.getEntityID(value.entity);
            } else {
              throw StateError("Invalid state: $value");
            }
          } else if (!value.isPrimitiveValue) {
            value = fieldEntityRepository.getEntityID(value);
          }
        } else if (fieldType.isEntityReferenceListType) {
          var listEntityType = fieldType.arguments0!;

          var fieldListEntityRepository =
              getEntityRepositoryByTypeInfo(listEntityType);
          if (fieldListEntityRepository == null) {
            throw StateError(
                "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType");
          }

          var valIter = value is Iterable ? value : [value];

          value = valIter
              .map((v) => fieldListEntityRepository.isOfEntityType(v)
                  ? fieldListEntityRepository.getEntityID(v)
                  : v)
              .toList();
        } else if (fieldType.isListEntity) {
          var listEntityType = fieldType.listEntityType!;

          var fieldListEntityRepository =
              getEntityRepositoryByTypeInfo(listEntityType);
          if (fieldListEntityRepository == null) {
            throw StateError(
                "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType");
          }

          var valIter = value is Iterable ? value : [value];

          value = valIter
              .map((v) => fieldListEntityRepository.isOfEntityType(v)
                  ? fieldListEntityRepository.getEntityID(v)
                  : v)
              .toList();
        } else if (!fieldType.isPrimitiveType && fieldType.entityType != null) {
          var entityType = fieldType.entityType!;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
                "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType");
          }

          value = fieldEntityRepository.getEntityID(value);
        }
      }

      return MapEntry(key, value);
    });

    return entityJsonNormalized;
  }

  Object resolveError(Object error, StackTrace stackTrace, Object? operation) =>
      DBObjectGCSAdapterException('error', '$error',
          parentError: error,
          parentStackTrace: stackTrace,
          operation: operation);

  FutureOr<R> _finishOperation<T, R>(
      TransactionOperation op, T res, PreFinishDBOperation<T, R>? preFinish) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
      FutureOr<R> Function(DBObjectGCSAdapterContext connection) f) {
    var transaction = op.transaction;

    if (isTransactionWithSingleOperation(op)) {
      return executeWithPool(f,
          onError: (e, s) => transaction.notifyExecutionError(
                e,
                s,
                errorResolver: resolveError,
                operation: op,
                debugInfo: () => op.toString(),
              ));
    }

    if (transaction.isOpen) {
      return transaction.addExecution<R, DBObjectGCSAdapterContext>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => op.toString(),
      );
    }

    if (!transaction.isOpening) {
      transaction.open(
        () => openTransaction(transaction),
        callCloseTransactionRequired
            ? () => closeTransaction(
                transaction, transaction.context as DBObjectGCSAdapterContext?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, DBObjectGCSAdapterContext>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => op.toString(),
      );
    });
  }
}

/// Error thrown by [DBObjectGCSAdapter] operations.
class DBObjectGCSAdapterException extends DBObjectAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectGCSAdapterException';

  DBObjectGCSAdapterException(String type, String message,
      {super.parentError, super.parentStackTrace, super.operation})
      : super(type, message);
}

extension _ObjectInfoExtension on gcs.ObjectInfo {
  List<int> get crc32CChecksumBytes {
    var n = crc32CChecksum;
    return [
      (n) & 0xFF,
      (n >> 8) & 0xFF,
      (n >> 16) & 0xFF,
      (n >> 24) & 0xFF,
    ];
  }
}

extension _CrcValueExtension on CrcValue {
  List<int> get crc32CChecksumBytes {
    var n = toBigInt().toInt();
    return [
      (n >> 24) & 0xFF,
      (n >> 16) & 0xFF,
      (n >> 8) & 0xFF,
      (n) & 0xFF,
    ];
  }
}
