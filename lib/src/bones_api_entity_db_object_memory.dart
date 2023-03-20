import 'dart:collection';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:map_history/map_history.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_object.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';

final _log = logging.Logger('DBObjectMemoryAdapter');

class DBObjectMemoryAdapterContext
    implements Comparable<DBObjectMemoryAdapterContext> {
  final int id;

  final Map<String, int> tablesVersions;

  DBObjectMemoryAdapterContext(this.id, this.tablesVersions);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBObjectMemoryAdapterContext other) => id.compareTo(other.id);
}

@Deprecated("Renamed to 'DBObjectMemoryAdapter'")
typedef DBMemoryObjectAdapter = DBObjectMemoryAdapter;

/// A [DBObjectAdapter] that stores objects in memory.
///
/// Simulates an Object Database adapter. Useful for tests.
class DBObjectMemoryAdapter
    extends DBObjectAdapter<DBObjectMemoryAdapterContext> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBObjectAdapter.registerAdapter([
      'object.memory',
      'obj.memory',
    ], DBObjectMemoryAdapter, _instantiate);
  }

  static FutureOr<DBObjectMemoryAdapter?> _instantiate(config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    try {
      return DBObjectMemoryAdapter.fromConfig(config,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath);
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  DBObjectMemoryAdapter(
      {super.generateTables = false,
      super.populateTables,
      super.populateSource,
      super.parentRepositoryProvider,
      super.workingPath,
      super.log})
      : super(
          'object.memory',
          1,
          3,
          const DBAdapterCapability(
              dialect: DBDialect('object'),
              transactions: true,
              transactionAbort: true),
        ) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<DBObjectMemoryAdapter> fromConfig(
      Map<String, dynamic>? config,
      {EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    boot();

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

    var adapter = DBObjectMemoryAdapter(
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      workingPath: workingPath,
    );

    return adapter;
  }

  @override
  bool close() {
    if (!super.close()) return false;

    _tables.clear();
    return true;
  }

  @override
  String getConnectionURL(DBObjectMemoryAdapterContext connection) =>
      'object.memory://${connection.id}';

  int _connectionCount = 0;

  @override
  DBObjectMemoryAdapterContext createConnection() {
    var id = ++_connectionCount;
    var tablesVersions = this.tablesVersions;

    return DBObjectMemoryAdapterContext(id, tablesVersions);
  }

  @override
  FutureOr<bool> closeConnection(DBObjectMemoryAdapterContext connection) {
    connection.close();
    return true;
  }

  final Map<String, MapHistory<Object, Map<String, dynamic>>> _tables =
      <String, MapHistory<Object, Map<String, dynamic>>>{};

  Map<String, int> get tablesVersions =>
      _tables.map((key, value) => MapEntry(key, value.version));

  Map<Object, Map<String, dynamic>>? _getTableMap(String table, bool autoCreate,
      {bool relationship = false}) {
    var map = _tables[table];
    if (map != null) {
      return map;
    } else if (autoCreate) {
      if (!relationship && !_tableExists(table)) {
        throw StateError("Table doesn't exists: $table");
      }

      _tables[table] = map = MapHistory<Object, Map<String, dynamic>>();
      return map;
    } else {
      return null;
    }
  }

  bool _tableExists(String table) =>
      _hasTableScheme(table) || getEntityHandler(tableName: table) != null;

  @override
  Map<String, dynamic> information({bool extended = false, String? table}) {
    var info = <String, dynamic>{};

    var tables = <String>{};
    if (table != null) {
      tables.add(table);
    }

    if (extended && tables.isEmpty) {
      tables = _tables.keys.toSet();
    }

    if (tables.isNotEmpty) {
      info['tables'] = <String, dynamic>{};
    }

    for (var t in tables) {
      var tableMap = _getTableMap(t, false);

      if (tableMap != null) {
        var tables = info['tables'] as Map;
        tables[t] = {'ids': tableMap.keys.toList()};
      }
    }

    return info;
  }

  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  bool _hasTableScheme(String table) => tablesSchemes.containsKey(table);

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

  final Map<DBObjectMemoryAdapterContext, DateTime> _openTransactionsContexts =
      <DBObjectMemoryAdapterContext, DateTime>{};

  @override
  DBObjectMemoryAdapterContext openTransaction(Transaction transaction) {
    var conn = createConnection();

    _openTransactionsContexts[conn] = DateTime.now();

    // ignore: discarded_futures
    transaction.transactionFuture.catchError((e, s) {
      cancelTransaction(transaction, conn, e, s);
      throw e;
    });

    return conn;
  }

  @override
  bool cancelTransaction(
      Transaction transaction,
      DBObjectMemoryAdapterContext connection,
      Object? error,
      StackTrace? stackTrace) {
    _openTransactionsContexts.remove(connection);
    _rollbackTables(connection.tablesVersions);
    return true;
  }

  @override
  bool get callCloseTransactionRequired => true;

  @override
  FutureOr<void> closeTransaction(
      Transaction transaction, DBObjectMemoryAdapterContext? connection) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  final ListQueue<DBObjectMemoryAdapterContext> _consolidateContextQueue =
      ListQueue<DBObjectMemoryAdapterContext>();

  void _consolidateTransactionContext(DBObjectMemoryAdapterContext context) {
    _openTransactionsContexts.remove(context);

    if (_openTransactionsContexts.isNotEmpty) {
      _consolidateContextQueue.add(context);
      return;
    }

    if (_consolidateContextQueue.isEmpty) {
      _consolidateTables(context.tablesVersions);
    } else {
      var list = [..._consolidateContextQueue, context];
      list.sort();

      for (var c in list) {
        _consolidateTables(c.tablesVersions);
      }
    }
  }

  void _consolidateTables(Map<String, int> tablesVersions) {
    for (var e in tablesVersions.entries) {
      var table = e.key;
      var version = e.value;
      _consolidateTable(table, version);
    }
  }

  void _consolidateTable(String table, int targetVersion) {
    var tableMap = _tables[table];
    tableMap?.consolidate(targetVersion);
  }

  void _rollbackTables(Map<String, int> tablesVersions) {
    for (var e in tablesVersions.entries) {
      var table = e.key;
      var version = e.value;
      _rollbackTable(table, version);
    }
  }

  void _rollbackTable(String table, int targetVersion) {
    var tableMap = _tables[table];
    tableMap?.rollback(targetVersion);
  }

  @override
  String toString() {
    var tablesSizes = _tables.map((key, value) => MapEntry(key, value.length));
    var tablesStr = tablesSizes.isNotEmpty ? ', tables: $tablesSizes' : '';
    var closedStr = isClosed ? ', closed' : '';
    return 'DBObjectMemoryAdapter#$instanceID{$tablesStr$closedStr}';
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

  int _doCountImpl(TransactionOperation op, String table,
      EntityMatcher? matcher, Object? parameters) {
    var map = _getTableMap(table, false);
    if (map == null) return 0;

    if (matcher != null) {
      if (matcher is ConditionID) {
        var id = matcher.idValue ?? matcher.getID(parameters);
        return map.containsKey(id) ? 1 : 0;
      }

      throw UnsupportedError("Relationship count not supported for: $matcher");
    }

    return map.length;
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
      String table, Object id, String entityName) {
    var map = _getTableMap(table, false);
    if (map == null) return null;

    var entry = map[id];

    if (entry == null) {
      return null;
    }

    return entry;
  }

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
      String table, List<Object> ids, String entityName) {
    var map = _getTableMap(table, false);
    if (map == null) return [];

    var entries = ids
        .map((id) {
          var entry = map[id];

          if (entry == null) {
            return null;
          }

          return entry;
        })
        .whereNotNull()
        .toList();

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

  FutureOr<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
      String table, String entityName) {
    var map = _getTableMap(table, false);
    if (map == null) return [];

    var entries = map.values.toList();
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
      Object? parameters) {
    var map = _getTableMap(table, false);
    if (map == null) return [];

    if (matcher is ConditionID) {
      var id = matcher.idValue ?? matcher.getID(parameters);
      var entry = map.remove(id);
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
      PreFinishDBOperation? preFinish) {
    var map = _getTableMap(table, true)!;

    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    var id = entry[idField];

    _logTransactionOperation('doInsert', op, 'INSERT INTO $table OBJECT `$id`');

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    map[id] = entry;

    return _finishOperation(op, id, preFinish);
  }

  void _logTransactionOperation(
      String method, TransactionOperation op, Object query) {
    if (log) {
      _log.info('[transaction:${op.transactionId}] $method> $query');
    }
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
      PreFinishDBOperation? preFinish) {
    _logTransactionOperation('doUpdate', op, 'UPDATE INTO $table OBJECT `$id`');

    var map = _getTableMap(table, true)!;

    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    entry[idField] = id;

    map[id] = entry;

    return _finishOperation(op, id, preFinish);
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

  Object resolveError(Object error, StackTrace stackTrace) =>
      DBObjectMemoryAdapterException('error', '$error',
          parentError: error, parentStackTrace: stackTrace);

  FutureOr<R> _finishOperation<T, R>(
      TransactionOperation op, T res, PreFinishDBOperation<T, R>? preFinish) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
      FutureOr<R> Function(DBObjectMemoryAdapterContext connection) f) {
    var transaction = op.transaction;

    if (transaction.length == 1 && !transaction.isExecuting) {
      return executeWithPool(f,
          onError: (e, s) => transaction.notifyExecutionError(
                e,
                s,
                errorResolver: resolveError,
                debugInfo: () => op.toString(),
              ));
    }

    if (!transaction.isOpen && !transaction.isOpening) {
      transaction.open(
        () => openTransaction(transaction),
        callCloseTransactionRequired
            ? () => closeTransaction(transaction,
                transaction.context as DBObjectMemoryAdapterContext?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, DBObjectMemoryAdapterContext>(
        (c) => f(c),
        errorResolver: resolveError,
        debugInfo: () => op.toString(),
      );
    });
  }
}

@Deprecated("Renamed to 'DBObjectMemoryAdapterException'")
typedef DBMemoryObjectAdapterException = DBObjectMemoryAdapterException;

/// Error thrown by [DBObjectMemoryAdapter] operations.
class DBObjectMemoryAdapterException extends DBObjectAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectMemoryAdapterException';

  DBObjectMemoryAdapterException(String type, String message,
      {Object? parentError, StackTrace? parentStackTrace})
      : super(type, message,
            parentError: parentError, parentStackTrace: parentStackTrace);
}
