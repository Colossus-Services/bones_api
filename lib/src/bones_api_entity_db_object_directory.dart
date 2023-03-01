import 'dart:collection';
import 'dart:convert' as dart_convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:map_history/map_history.dart';
import 'package:path/path.dart' as pack_path;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';

final _log = logging.Logger('DBObjectDirectoryAdapter');

class DBObjectDirectoryAdapterContext
    implements Comparable<DBObjectDirectoryAdapterContext> {
  final int id;

  final Map<String, int> tablesVersions;

  DBObjectDirectoryAdapterContext(this.id, this.tablesVersions);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBObjectDirectoryAdapterContext other) =>
      id.compareTo(other.id);
}

/// A [SQLAdapter] that stores tables data in memory.
///
/// Simulates a SQL Database adapter. Useful for tests.
class DBObjectDirectoryAdapter
    extends DBAdapter<DBObjectDirectoryAdapterContext> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBAdapter.registerAdapter([
      'object.directory',
      'obj.dir',
    ], DBObjectDirectoryAdapter, _instantiate);
  }

  static FutureOr<DBObjectDirectoryAdapter?> _instantiate(config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    try {
      return DBObjectDirectoryAdapter.fromConfig(config,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath);
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final Directory directory;

  DBObjectDirectoryAdapter(this.directory,
      {bool generateTables = false,
      Object? populateTables,
      Object? populateSource,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath})
      : super(
          'object.directory',
          1,
          3,
          const DBAdapterCapability(
              dialect: DBDialect('object'),
              transactions: true,
              transactionAbort: true),
          populateSource: populateSource,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath,
        ) {
    boot();

    if (!directory.existsSync()) {
      throw ArgumentError("Directory doesn't exists: $directory");
    }

    var modeString = directory.statSync().modeString();
    if (!modeString.contains('rw')) {
      throw StateError("Can't read+write the directory: $directory");
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<DBObjectDirectoryAdapter> fromConfig(
      Map<String, dynamic>? config,
      {EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    boot();

    var directoryPath = config?['path'] ?? config?['directory'];

    if (directoryPath == null) {
      throw ArgumentError("Config without `path` entry!");
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

    var directory = Directory(directoryPath);

    var adapter = DBObjectDirectoryAdapter(
      directory,
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      workingPath: workingPath,
    );

    return adapter;
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[
      if (parentRepositoryProvider != null) parentRepositoryProvider
    ];
  }

  @override
  bool close() {
    if (!super.close()) return false;

    _tables.clear();
    return true;
  }

  @override
  String getConnectionURL(DBObjectDirectoryAdapterContext connection) =>
      'object.directory://${connection.id}';

  int _connectionCount = 0;

  @override
  DBObjectDirectoryAdapterContext createConnection() {
    var id = ++_connectionCount;
    var tablesVersions = this.tablesVersions;

    return DBObjectDirectoryAdapterContext(id, tablesVersions);
  }

  @override
  FutureOr<bool> closeConnection(DBObjectDirectoryAdapterContext connection) {
    connection.close();
    return true;
  }

  final Map<String, MapHistory<Object, Map<String, dynamic>>> _tables =
      <String, MapHistory<Object, Map<String, dynamic>>>{};

  Map<String, int> get tablesVersions =>
      _tables.map((key, value) => MapEntry(key, value.version));

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

    var fieldsReferencedTables = _findFieldsReferencedTables(table,
        entityHandler: entityHandler, entityFieldsTypes: entityFieldsTypes);

    var relationshipTables = _findRelationshipTables(table);

    fieldsTypes.removeWhere((key, value) =>
        relationshipTables.any((r) => r.relationshipField == key));

    tableScheme = TableScheme(table,
        relationship: relationship != null,
        idFieldName: idFieldName,
        fieldsTypes: fieldsTypes,
        fieldsReferencedTables: fieldsReferencedTables,
        relationshipTables: relationshipTables);

    _log.info('$tableScheme');

    return tableScheme;
  }

  Map<String, TableFieldReference> _findFieldsReferencedTables(String table,
      {Type? entityType,
      EntityHandler<dynamic>? entityHandler,
      Map<String, TypeInfo>? entityFieldsTypes,
      bool onlyCollectionReferences = false}) {
    entityHandler ??=
        getEntityHandler(tableName: table, entityType: entityType);

    entityFieldsTypes ??= entityHandler!.fieldsTypes();

    var relationshipFields =
        Map<String, TypeInfo>.fromEntries(entityFieldsTypes.entries.where((e) {
      var fieldType = e.value;
      if (fieldType.isCollection != onlyCollectionReferences) return false;

      var entityType = _resolveEntityType(fieldType);
      if (entityType == null || entityType.isBasicType) return false;

      var typeEntityHandler =
          entityHandler!.getEntityHandler(type: entityType.type);
      return typeEntityHandler != null;
    }));

    var fieldsReferencedTables = relationshipFields.map((field, fieldType) {
      var targetEntityType = _resolveEntityType(fieldType)!;
      var targetEntityHandler =
          getEntityHandler(entityType: targetEntityType.type);

      String? targetName;
      String? targetIdField;
      Type? targetIdType;
      if (targetEntityHandler != null) {
        targetName = getEntityRepositoryByType(targetEntityHandler.type)?.name;
        targetIdField = targetEntityHandler.idFieldName();
        targetIdType =
            targetEntityHandler.getFieldType(null, targetIdField)?.type;
      }

      targetName ??= targetEntityType.type.toString().toLowerCase();
      targetIdField ??= 'id';
      targetIdType ??= int;

      var tableRef = TableFieldReference(
          table, field, targetIdType, targetName, targetIdField, targetIdType);
      return MapEntry(field, tableRef);
    });
    return fieldsReferencedTables;
  }

  TypeInfo? _resolveEntityType(TypeInfo fieldType) {
    if (fieldType.isPrimitiveType) {
      return null;
    }

    var entityType =
        fieldType.isListEntityOrReference ? fieldType.arguments0! : fieldType;

    if (!EntityHandler.isValidEntityType(entityType.type)) {
      return null;
    }

    return entityType;
  }

  List<TableRelationshipReference> _findRelationshipTables(String table) {
    var allRepositories = this.allRepositories();

    var allTablesReferences = Map.fromEntries(allRepositories.values.map((r) {
      var referencedTables = _findFieldsReferencedTables(r.name,
          entityType: r.type,
          entityHandler: r.entityHandler,
          onlyCollectionReferences: true);
      return MapEntry(r, referencedTables);
    }).where((e) => e.value.isNotEmpty));

    for (var refs in allTablesReferences.values) {
      refs.removeWhere((field, refTable) => refTable.sourceTable != table);
    }

    allTablesReferences.removeWhere((repo, refs) => refs.isEmpty);

    var relationships = allTablesReferences.entries.expand((e) {
      var repo = e.key;
      var refs = e.value;

      return refs.values.map((ref) {
        var sourceTable = ref.sourceTable;
        var sourceField = ref.sourceField;

        var targetTable = ref.targetTable;
        var targetField = ref.targetField;

        var sourceEntityHandler = repo.entityHandler;
        var sourceFieldId = sourceEntityHandler.idFieldName();
        var sourceFieldIdType =
            sourceEntityHandler.getFieldType(null, sourceFieldId)?.type ?? int;

        var relTable = '${sourceTable}__${sourceField}__rel';
        var relSourceField = '${sourceTable}__$sourceFieldId';
        var relTargetField = '${targetTable}__$targetField';

        return TableRelationshipReference(
          relTable,
          sourceTable,
          sourceFieldId,
          sourceFieldIdType,
          relSourceField,
          targetTable,
          ref.targetField,
          ref.targetFieldType,
          relTargetField,
          relationshipField: sourceField,
        );
      });
    }).toList();

    return relationships;
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) {
    return tablesSchemes[table]?.fieldsTypes;
  }

  @override
  FutureOr<bool> isConnectionValid(connection) => true;

  final Map<DBObjectDirectoryAdapterContext, DateTime>
      _openTransactionsContexts = <DBObjectDirectoryAdapterContext, DateTime>{};

  @override
  DBObjectDirectoryAdapterContext openTransaction(Transaction transaction) {
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
      DBObjectDirectoryAdapterContext connection,
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
      Transaction transaction, DBObjectDirectoryAdapterContext? connection) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  final ListQueue<DBObjectDirectoryAdapterContext> _consolidateContextQueue =
      ListQueue<DBObjectDirectoryAdapterContext>();

  void _consolidateTransactionContext(DBObjectDirectoryAdapterContext context) {
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
    return 'DBObjectDirectoryAdapter#$instanceID{$tablesStr$closedStr}';
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
    var list = tableDir.listSync(recursive: false).whereType<File>().where((e) {
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
  FutureOr<R?> doSelectByID<R>(
          TransactionOperation op, String entityName, String table, Object id,
          {PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish}) =>
      executeTransactionOperation<R?>(
          op,
          (conn) => _doSelectByIDImpl<R>(table, id, entityName)
              .resolveMapped((res) => _finishOperation(op, res, preFinish)));

  FutureOr<Map<String, dynamic>?> _doSelectByIDImpl<R>(
      String table, Object id, String entityName) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return null;

    var entry = await _readObject(table, id);
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
      String table, List<Object> ids, String entityName) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

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

  FutureOr<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
      String table, String entityName) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var files = _listTableFiles(tableDir);

    var entries = files.map((f) {
      var fileName = pack_path.split(f.path).last;
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
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    var id = entry[idField];

    _log.info(
        '[transaction:${op.transactionId}] doInsert> INSERT INTO $table OBJECT `$id`');

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    _saveObject(table, id, entry);

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
      PreFinishDBOperation? preFinish) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    _log.info(
        '[transaction:${op.transactionId}] doUpdate> UPDATE INTO $table OBJECT `$id`');

    var entry =
        _normalizeEntityJSON(fields, entityName: entityName, table: table);

    var idField = _getTableIDFieldName(table);
    entry[idField] = id;

    _saveObject(table, id, entry);

    return _finishOperation(op, id, preFinish);
  }

  Future<void> _saveObject(
      String table, Object? id, Map<String, dynamic> obj) async {
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

  String _normalizeID(Object? o) {
    var id = o?.toString() ?? '';
    if (id.isEmpty) {
      throw StateError("Empty ID string.");
    }
    return id;
  }

  String _normalizeTableName(String table) {
    table = table.trim().replaceAll(RegExp(r'\W'), '_');
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

  Object resolveError(Object error, StackTrace stackTrace) =>
      DBObjectDirectoryAdapterException('error', '$error',
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
      FutureOr<R> Function(DBObjectDirectoryAdapterContext connection) f) {
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
                transaction.context as DBObjectDirectoryAdapterContext?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, DBObjectDirectoryAdapterContext>(
        (c) => f(c),
        errorResolver: resolveError,
        debugInfo: () => op.toString(),
      );
    });
  }
}

/// Error thrown by [DBObjectDirectoryAdapter] operations.
class DBObjectDirectoryAdapterException extends DBAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectDirectoryAdapterException';

  DBObjectDirectoryAdapterException(String type, String message,
      {Object? parentError, StackTrace? parentStackTrace})
      : super(type, message,
            parentError: parentError, parentStackTrace: parentStackTrace);
}
