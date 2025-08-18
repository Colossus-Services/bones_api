import 'dart:convert' as dart_convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
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

final _log = logging.Logger('DBObjectDirectoryAdapter')..registerAsDbLogger();

class DBObjectDirectoryAdapterContext
    implements Comparable<DBObjectDirectoryAdapterContext> {
  final int id;

  DBObjectDirectoryAdapterContext(this.id);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBObjectDirectoryAdapterContext other) =>
      id.compareTo(other.id);
}

/// A [DBObjectAdapter] that stores objects in a [Directory].
///
/// Simulates an Object Database adapter. Useful for development.
class DBObjectDirectoryAdapter
    extends DBObjectAdapter<DBObjectDirectoryAdapterContext> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBObjectAdapter.boot();

    DBObjectAdapter.registerAdapter(
      ['object.directory', 'obj.dir'],
      DBObjectDirectoryAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBObjectDirectoryAdapter?> _instantiate(
    config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBObjectDirectoryAdapter.fromConfig(
        config,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath,
      );
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final Directory directory;

  DBObjectDirectoryAdapter(
    this.directory, {
    super.generateTables,
    super.populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.workingPath,
    super.log,
  }) : super(
         'object.directory',
         1,
         3,
         const DBAdapterCapability(
           dialect: DBDialect('object'),
           transactions: true,
           transactionAbort: true,
           constraintSupport: false,
           multiIsolateSupport: true,
           connectivity: DBAdapterCapabilityConnectivity.none,
         ),
       ) {
    boot();

    if (!directory.existsSync()) {
      throw ArgumentError(
        "[DBObjectDirectoryAdapter]: Directory doesn't exists: $directory",
      );
    }

    var modeString = directory.statSync().modeString();
    if (!modeString.contains('rw')) {
      throw StateError(
        "[DBObjectDirectoryAdapter]: Can't read+write the directory: $directory",
      );
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<DBObjectDirectoryAdapter> fromConfig(
    Map<String, dynamic>? config, {
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var directoryPath = config?['path'] ?? config?['directory'];

    if (directoryPath == null) {
      throw ArgumentError("Config without `path` entry!");
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

    var directory = Directory(directoryPath);

    var adapter = DBObjectDirectoryAdapter(
      directory,
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      populateSourceVariables: populateSourceVariables,
      workingPath: workingPath,
    );

    return adapter;
  }

  @override
  String getConnectionURL(DBObjectDirectoryAdapterContext connection) =>
      'object.directory://${connection.id}';

  int _connectionCount = 0;

  @override
  DBObjectDirectoryAdapterContext createConnection() {
    var id = ++_connectionCount;

    return DBObjectDirectoryAdapterContext(id);
  }

  @override
  bool closeConnection(DBObjectDirectoryAdapterContext connection) {
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  Map<String, dynamic> information({bool extended = false, String? table}) {
    var info = <String, dynamic>{};
    info['tables'] = _listTablesNames();
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
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) {
    //_log.info('getTableSchemeImpl> $table ; relationship: $relationship');

    var tableScheme = tablesSchemes[table];
    if (tableScheme != null) return tableScheme;

    var entityHandler = getEntityHandler(tableName: table);
    if (entityHandler == null) {
      if (relationship != null) {
        var sourceId =
            '${relationship.sourceTable}_${relationship.sourceField}';
        var targetId =
            '${relationship.targetTable}_${relationship.targetField}';

        tableScheme = TableScheme(
          table,
          relationship: true,
          idFieldName: sourceId,
          fieldsTypes: {
            sourceId: relationship.sourceFieldType,
            targetId: relationship.targetFieldType,
          },
        );

        _log.info('relationship> $tableScheme');

        return tableScheme;
      }

      throw StateError(
        "Can't resolve `TableScheme` for table `$table`. No `EntityHandler` found for table `$table`!",
      );
    }

    var idFieldName = entityHandler.idFieldName();

    var entityFieldsTypes = entityHandler.fieldsTypes();

    var fieldsTypes = entityFieldsTypes.map(
      (key, value) => MapEntry(key, value.type),
    );

    tableScheme = TableScheme(
      table,
      relationship: relationship != null,
      idFieldName: idFieldName,
      fieldsTypes: fieldsTypes,
    );

    _log.info('$tableScheme');

    return tableScheme;
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) {
    return tablesSchemes[table]?.fieldsTypes;
  }

  @override
  FutureOr<bool> isConnectionValid(connection, {bool checkUsage = true}) =>
      true;

  final Map<DBObjectDirectoryAdapterContext, DateTime>
  _openTransactionsContexts = <DBObjectDirectoryAdapterContext, DateTime>{};

  @override
  DBObjectDirectoryAdapterContext openTransaction(Transaction transaction) {
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
    DBObjectDirectoryAdapterContext? connection,
    Object? error,
    StackTrace? stackTrace,
  ) {
    _openTransactionsContexts.remove(connection);
    return true;
  }

  @override
  bool get callCloseTransactionRequired => true;

  @override
  FutureOr<void> closeTransaction(
    Transaction transaction,
    DBObjectDirectoryAdapterContext? connection,
  ) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  void _consolidateTransactionContext(DBObjectDirectoryAdapterContext context) {
    _openTransactionsContexts.remove(context);
  }

  @override
  String toString() {
    var closedStr = isClosed ? '{closed}' : '';
    return 'DBObjectDirectoryAdapter#$instanceID$closedStr@${directory.path}';
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
    return executeTransactionOperation(
      op,
      (conn) => _doCountImpl(
        op,
        table,
        matcher,
        parameters,
      ).resolveMapped((res) => _finishOperation(op, res, preFinish)),
    );
  }

  int _doCountImpl(
    TransactionOperation op,
    String table,
    EntityMatcher? matcher,
    Object? parameters,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return 0;

    if (matcher != null) {
      if (matcher is ConditionID) {
        var id = matcher.idValue ?? matcher.getID(parameters);

        var objFile = _resolveObjectFile(table, id);
        return objFile.existsSync() ? 1 : 0;
      }

      throw UnsupportedError("Relationship count not supported for: $matcher");
    }

    var list = _listTableFiles(tableDir);
    return list.length;
  }

  List<File> _listTableFiles(Directory tableDir) {
    var list =
        tableDir.listSync(recursive: false).whereType<File>().where((e) {
          var path = e.path;
          return path.endsWith('.json') && !path.startsWith('.');
        }).toList();
    return list;
  }

  List<Directory> _listTablesDirs() {
    var dirs = directory.listSync().whereType<Directory>().toList();
    return dirs;
  }

  List<String> _listTablesNames() =>
      _listTablesDirs().map((d) => pack_path.split(d.path).last).toList();

  @override
  FutureOr<List<I>> doExistIDs<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    List<I> ids,
  ) {
    return executeTransactionOperation(
      op,
      (conn) => _doExistIDsImpl(
        op,
        table,
        ids,
      ).resolveMapped((res) => _finishOperation(op, res, null)),
    );
  }

  List<I> _doExistIDsImpl<I extends Object>(
    TransactionOperation op,
    String table,
    List<I> ids,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var existIDs =
        ids.where((id) {
          var objFile = _resolveObjectFile(table, id);
          return objFile.existsSync();
        }).toList();

    return existIDs;
  }

  @override
  FutureOr<R?> doSelectByID<R>(
    TransactionOperation op,
    String entityName,
    String table,
    Object id, {
    PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish,
  }) => executeTransactionOperation<R?>(
    op,
    (conn) => _doSelectByIDImpl<R>(
      table,
      id,
      entityName,
    ).resolveMapped((res) => _finishOperation(op, res, preFinish)),
  );

  FutureOr<Map<String, dynamic>?> _doSelectByIDImpl<R>(
    String table,
    Object id,
    String entityName,
  ) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return null;

    var entry = await _readObject(table, id);
    return entry;
  }

  @override
  FutureOr<List<R>> doSelectByIDs<R>(
    TransactionOperation op,
    String entityName,
    String table,
    List<Object> ids, {
    PreFinishDBOperation<List<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeTransactionOperation<List<R>>(
    op,
    (conn) => _doSelectByIDsImpl<R>(
      table,
      ids,
      entityName,
    ).resolveMapped((res) => _finishOperation(op, res, preFinish)),
  );

  FutureOr<List<Map<String, dynamic>>> _doSelectByIDsImpl<R>(
    String table,
    List<Object> ids,
    String entityName,
  ) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var entries =
        await ids.map((id) => _readObject(table, id)).resolveAllNotNull();

    return entries;
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
    TransactionOperation op,
    String entityName,
    String table, {
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeTransactionOperation<List<R>>(
    op,
    (conn) => _doSelectAllImpl<R>(
      table,
      entityName,
    ).resolveMapped((res) => _finishOperation(op, res, preFinish)),
  );

  FutureOr<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
    String table,
    String entityName,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var files = _listTableFiles(tableDir);

    var entries =
        files.map((f) {
          var fileName = pack_path.split(f.path).last;
          var id = pack_path.withoutExtension(fileName);
          return _readObject(table, id);
        }).resolveAllNotNull();

    return entries;
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
  }) => executeTransactionOperation(
    op,
    (conn) => _doDeleteImpl<R>(
      op,
      table,
      matcher,
      parameters,
    ).resolveMapped((res) => _finishOperation(op, res, preFinish)),
  );

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteImpl<R>(
    TransactionOperation op,
    String table,
    EntityMatcher<dynamic> matcher,
    Object? parameters,
  ) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    if (matcher is ConditionID) {
      var id = matcher.idValue ?? matcher.getID(parameters);

      var objFile = _resolveObjectFile(table, id);
      if (!objFile.existsSync()) return [];

      var entry = await _readObject(table, id);
      objFile.deleteSync();

      return entry != null ? [entry] : [];
    }

    throw UnsupportedError("Relationship delete not supported for: $matcher");
  }

  String _getTableIDFieldName(String table) {
    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    return idField;
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
  }) => executeTransactionOperation<dynamic>(
    op,
    (conn) => _doInsertImpl<O>(op, table, fields, entityName, preFinish),
  );

  FutureOr<dynamic> _doInsertImpl<O>(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
    PreFinishDBOperation? preFinish,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    var entry = _normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    var idField = _getTableIDFieldName(table);
    var id = entry[idField];

    _log.info(
      '[transaction:${op.transactionId}] doInsert> INSERT INTO $table OBJECT `$id`',
    );

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    _saveObject(table, id, entry);

    return _finishOperation(op, id, preFinish);
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
  }) => executeTransactionOperation(
    op,
    (conn) => _doUpdateImpl(op, table, fields, entityName, id, preFinish),
  );

  FutureOr<dynamic> _doUpdateImpl(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
    Object id,
    PreFinishDBOperation? preFinish,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    _log.info(
      '[transaction:${op.transactionId}] doUpdate> UPDATE INTO $table OBJECT `$id`',
    );

    var entry = _normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    var idField = _getTableIDFieldName(table);
    entry[idField] = id;

    _saveObject(table, id, entry);

    return _finishOperation(op, id, preFinish);
  }

  Future<void> _saveObject(
    String table,
    Object? id,
    Map<String, dynamic> obj,
  ) async {
    var file = _resolveObjectFile(table, id);
    var enc = dart_convert.json.encode(obj);
    await file.writeAsString(enc);
  }

  Future<Map<String, dynamic>?> _readObject(String table, Object? id) async {
    var file = _resolveObjectFile(table, id);
    if (!file.existsSync()) return null;
    var enc = await file.readAsString();
    var obj = dart_convert.json.decode(enc) as Map<String, dynamic>;
    return obj;
  }

  File _resolveObjectFile(String table, Object? id) {
    var idStr = _normalizeID(id);
    var tableDir = _resolveTableDirectory(table);
    var file = File(pack_path.join(tableDir.path, '$idStr.json'));
    return file;
  }

  Directory _resolveTableDirectory(String table) {
    var tableStr = _normalizeTableName(table);
    var tableDir = Directory(pack_path.join(directory.path, tableStr));
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

  Map<String, dynamic> _normalizeEntityJSON(
    Map<String, dynamic> entityJson, {
    String? entityName,
    String? table,
    EntityRepository? entityRepository,
  }) {
    entityRepository ??= getEntityRepository(
      name: entityName,
      tableName: table,
    );

    if (entityRepository == null) {
      throw StateError(
        "Can't determine `EntityRepository` for: entityName=$entityName ; tableName=$table",
      );
    }

    var entityHandler = entityRepository.entityHandler;

    var entityJsonNormalized = entityJson.map((key, value) {
      if (value == null || (value as Object).isPrimitiveValue) {
        return MapEntry(key, value);
      } else if (value is Uint8List) {
        var dataURLBase64 = DataURLBase64.from(value);
        return MapEntry(key, dataURLBase64.toString());
      }

      var fieldType = entityHandler.getFieldType(
        null,
        key,
        resolveFiledName: false,
      );

      if (fieldType != null) {
        if (fieldType.isEntityReferenceType) {
          var entityType = fieldType.arguments0!.type;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType",
            );
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

          var fieldListEntityRepository = getEntityRepositoryByTypeInfo(
            listEntityType,
          );
          if (fieldListEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType",
            );
          }

          var valIter = value is Iterable ? value : [value];

          value =
              valIter
                  .map(
                    (v) =>
                        fieldListEntityRepository.isOfEntityType(v)
                            ? fieldListEntityRepository.getEntityID(v)
                            : v,
                  )
                  .toList();
        } else if (fieldType.isListEntity) {
          var listEntityType = fieldType.listEntityType!;

          var fieldListEntityRepository = getEntityRepositoryByTypeInfo(
            listEntityType,
          );
          if (fieldListEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType",
            );
          }

          var valIter = value is Iterable ? value : [value];

          value =
              valIter
                  .map(
                    (v) =>
                        fieldListEntityRepository.isOfEntityType(v)
                            ? fieldListEntityRepository.getEntityID(v)
                            : v,
                  )
                  .toList();
        } else if (!fieldType.isPrimitiveType && fieldType.entityType != null) {
          var entityType = fieldType.entityType!;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType",
            );
          }

          value = fieldEntityRepository.getEntityID(value);
        }
      }

      return MapEntry(key, value);
    });

    return entityJsonNormalized;
  }

  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) => DBObjectDirectoryAdapterException(
    'error',
    '$error',
    parentError: error,
    parentStackTrace: stackTrace,
    previousError: previousError,
    operation: operation,
  );

  FutureOr<R> _finishOperation<T, R>(
    TransactionOperation op,
    T res,
    PreFinishDBOperation<T, R>? preFinish,
  ) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  FutureOr<R> executeTransactionOperation<R>(
    TransactionOperation op,
    FutureOr<R> Function(DBObjectDirectoryAdapterContext connection) f,
  ) {
    var transaction = op.transaction;

    if (isTransactionWithSingleOperation(op)) {
      return executeWithPool(
        f,
        onError:
            (e, s) => transaction.notifyExecutionError(
              e,
              s,
              errorResolver: resolveError,
              operation: op,
              debugInfo: () => op.toString(),
            ),
      );
    }

    if (transaction.isOpen) {
      return transaction.addExecution<R, DBObjectDirectoryAdapterContext>(
        (c) => f(c),
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
              transaction,
              transaction.context as DBObjectDirectoryAdapterContext?,
            )
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, DBObjectDirectoryAdapterContext>(
        (c) => f(c),
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => op.toString(),
      );
    });
  }
}

/// Error thrown by [DBObjectDirectoryAdapter] operations.
class DBObjectDirectoryAdapterException extends DBObjectAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectDirectoryAdapterException';

  DBObjectDirectoryAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}
