import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:map_history/map_history.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_logging.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_collections.dart';

final _log = logging.Logger('DBSQLMemoryAdapter')..registerAsDbLogger();

class DBSQLMemoryAdapterContext
    implements Comparable<DBSQLMemoryAdapterContext> {
  final int id;

  final DBSQLMemoryAdapter sqlAdapter;

  final Map<String, int> tablesVersions;
  final Map<String, Map<String, int>> tablesIndexesVersions;

  DBSQLMemoryAdapterContext(this.id, this.sqlAdapter)
      : tablesVersions = sqlAdapter.tablesVersions,
        tablesIndexesVersions = sqlAdapter.tablesIndexesVersions;

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBSQLMemoryAdapterContext other) => id.compareTo(other.id);
}

@Deprecated("Renamed to 'DBSQLMemoryAdapter'")
typedef DBMemorySQLAdapter = DBSQLMemoryAdapter;

/// A [DBSQLAdapter] that stores tables data in memory.
///
/// Simulates a SQL Database adapter. Useful for tests and development.
class DBSQLMemoryAdapter extends DBSQLAdapter<DBSQLMemoryAdapterContext>
    implements WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'DBSQLMemoryAdapter';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBSQLAdapter.boot();

    DBSQLAdapter.registerAdapter([
      'sql.memory',
      'sql.mem',
    ], DBSQLMemoryAdapter, _instantiate);
  }

  static FutureOr<DBSQLMemoryAdapter?> _instantiate(config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    try {
      return DBSQLMemoryAdapter.fromConfig(config,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath);
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  DBSQLMemoryAdapter(
      {super.generateTables,
      super.checkTables,
      super.populateTables,
      super.populateSource,
      super.populateSourceVariables,
      super.parentRepositoryProvider,
      super.workingPath,
      super.logSQL})
      : super(
          'sql.memory',
          1,
          3,
          const DBSQLAdapterCapability(
              dialect: SQLDialect(
                'generic',
                acceptsReturningSyntax: true,
                acceptsInsertIgnore: true,
              ),
              transactions: true,
              transactionAbort: true,
              tableSQL: false,
              constraintSupport: false,
              multiIsolateSupport: false),
        ) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<DBSQLMemoryAdapter> fromConfig(Map<String, dynamic>? config,
      {EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    boot();

    var retCheckTablesAndGenerateTables =
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables(config);

    var generateTables = retCheckTablesAndGenerateTables[0];
    var checkTables = retCheckTablesAndGenerateTables[1];

    var populate = config?['populate'];
    Object? populateTables;
    Object? populateSource;
    Object? populateSourceVariables;

    if (populate is Map) {
      populateTables = populate['tables'];
      populateSource = populate['source'];
      populateSourceVariables = populate['variables'];
    }

    var logSql = DBSQLAdapter.parseConfigLogSQL(config) ?? false;

    var adapter = DBSQLMemoryAdapter(
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      checkTables: checkTables,
      populateTables: populateTables,
      populateSource: populateSource,
      populateSourceVariables: populateSourceVariables,
      workingPath: workingPath,
      logSQL: logSql,
    );

    return adapter;
  }

  @override
  SQLDialect get dialect => super.dialect as SQLDialect;

  @override
  Object resolveError(Object error, StackTrace stackTrace, Object? operation,
      Object? previousError) {
    if (error is DBSQLMemoryAdapterException) {
      return error;
    }

    return DBSQLMemoryAdapterException('error', '$error',
        parentError: error,
        parentStackTrace: stackTrace,
        previousError: previousError,
        operation: operation);
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
    _onTablesModification();

    return true;
  }

  @override
  String getConnectionURL(DBSQLMemoryAdapterContext connection) =>
      'sql.memory://${connection.id}';

  int _connectionCount = 0;

  @override
  DBSQLMemoryAdapterContext createConnection() {
    var id = ++_connectionCount;
    return DBSQLMemoryAdapterContext(id, this);
  }

  @override
  bool closeConnection(DBSQLMemoryAdapterContext connection) {
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  DBSQLMemoryAdapterContext catchFromPool({Duration? timeout}) {
    if (poolSize > 0) {
      // If the pool has elements, it won't return a `Future`:
      // ignore: discarded_futures
      return super.catchFromPool(timeout: timeout) as DBSQLMemoryAdapterContext;
    } else {
      return createConnection();
    }
  }

  final Map<String, MapHistory<Object, Map<String, dynamic>>> _tables =
      <String, MapHistory<Object, Map<String, dynamic>>>{};

  void _onTablesModification() {
    _tablesVersions = null;
  }

  Map<String, int>? _tablesVersions;

  Map<String, int> get tablesVersions =>
      _tablesVersions ??= UnmodifiableMapView(
          _tables.map((table, map) => MapEntry(table, map.version)));

  final Map<String, int> _tablesIdCount = <String, int>{};

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
      _onTablesModification();

      return map;
    } else {
      return null;
    }
  }

  bool _tableExists(String table) =>
      _hasTableScheme(table) || getEntityHandler(tableName: table) != null;

  Map<String, dynamic>? _getByID(String table, Object id) {
    var map = _getTableMap(table, false);
    return map?[id];
  }

  MapEntry<String, MapEntry<Object, MapEntry<String, Object>>>?
      _findAnyReference(String referencedTable, Object? id) {
    if (id == null) return null;

    for (var e in _tables.entries) {
      var table = e.key;
      var ref = _findReferenceInTable(table, referencedTable, id);
      if (ref != null) return MapEntry(table, ref);
    }

    return null;
  }

  MapEntry<Object, MapEntry<String, Object>>? _findReferenceInTable(
      String table, String referencedTable, Object? id) {
    if (id == null) return null;

    var tableScheme = getTableScheme(table);
    if (tableScheme == null) {
      throw StateError("Can't find `TableScheme` for table: `$table`");
    }

    var fieldsReferencedTables = tableScheme.fieldsReferencedTables;
    if (fieldsReferencedTables.isEmpty) return null;

    for (var e in fieldsReferencedTables.entries) {
      var ref = e.value;
      if (ref.targetTable == referencedTable) {
        var sourceField = ref.sourceField;

        var tableMap = _getTableMap(ref.sourceTable, false);

        var reference = tableMap?.entries
            .where((e) => e.value[sourceField] == id)
            .firstOrNull;

        if (reference != null) {
          var value = reference.value[sourceField];
          return MapEntry(reference.key, MapEntry(sourceField, value));
        }
      }
    }

    return null;
  }

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

  @override
  FutureOr<bool> executeTableSQL(String createTableSQL) {
    throw UnsupportedError("Can't execute create table SQL");
  }

  @override
  void checkEntityFields<O>(O o, String entityName, String table,
      {EntityHandler<O>? entityHandler}) {
    Map<Object, Map<String, dynamic>>? map = _getTableMap(table, false);
    if (map == null) return;

    entityHandler ??=
        getEntityHandler<O>(entityName: entityName, tableName: table);
    if (entityHandler == null) {
      throw StateError(
          "Can't define `EntityHandler`> entityName: $entityName ; table: $table ; entityType: $O");
    }

    var entityId = getEntityID(o!,
        entityHandler: entityHandler, entityName: entityName, tableName: table);

    var fieldsEntityAnnotations =
        entityHandler.getAllFieldsEntityAnnotations(o);

    var uniques = fieldsEntityAnnotations?.entries
        .where((e) => e.value.hasUnique)
        .toList();
    if (uniques == null || uniques.isEmpty) return;

    for (var e in uniques) {
      var field = e.key;
      var value = entityHandler.getField(o, field);
      if (value == null) continue;

      if (_containsEntryWithConflictFieldValue(
          map, entityHandler, entityId, field, value)) {
        throw EntityFieldInvalid('unique', value,
            fieldName: field, entityType: entityHandler.type, tableName: table);
      }
    }
  }

  bool _containsEntryWithConflictFieldValue<O>(
          Map<Object, Map<String, dynamic>> map,
          EntityHandler<O> entityHandler,
          Object? entityId,
          String field,
          value) =>
      map.entries.any((e) {
        if (entityId != null) {
          var id = e.key;
          if (entityId == id) return false;
        }

        var elem = e.value;
        var elemValue = elem[field];
        var conflict = elemValue == value;
        return conflict;
      });

  @override
  FutureOr<int> doCountSQL(String entityName, String table, SQL sql,
      Transaction transaction, DBSQLMemoryAdapterContext connection) {
    var map = _getTableMap(table, false);
    if (map == null) return 0;

    var condition = sql.condition;

    if (condition != null) {
      var sel = _selectEntries(table, sql);
      return sel.length;
    } else {
      return map.length;
    }
  }

  @override
  FutureOr doInsertRelationshipSQL(String entityName, String table, SQL sql,
      Transaction transaction, DBSQLMemoryAdapterContext connection) {
    if (sql.isDummy) return null;

    var entry = _normalizeEntityJSON(
        sql.namedParameters ?? sql.parametersByPlaceholder,
        entityName: entityName,
        table: table);

    var map = _getTableMap(table, true, relationship: true)!;

    var prevEntry =
        map.entries.firstWhereOrNull((e) => isEqualsDeep(e.value, entry));
    if (prevEntry != null) {
      return prevEntry.key;
    }

    var id = nextID(table);
    map[id] = entry;

    for (var e in entry.entries) {
      var field = e.key;
      var value = e.value;
      _indexAddEntry(table, id, field, value);
    }

    _onTablesModification();
    return id;
  }

  final _tablesIndexes =
      <String, Map<String, MapHistory<Object, Set<Object>>>>{};

  Map<String, Map<String, int>>? _tablesIndexesVersions;

  Map<String, Map<String, int>> get tablesIndexesVersions =>
      _tablesIndexesVersions ??= UnmodifiableMapView(_tablesIndexes.map(
          (table, fieldIndex) => MapEntry(
              table,
              fieldIndex
                  .map((field, index) => MapEntry(field, index.version)))));

  Map<String, MapHistory<Object, Set<Object>>> _getTableIndexes(String table) {
    var tableIndexes =
        _tablesIndexes[table] ??= <String, MapHistory<Object, Set<Object>>>{};

    return tableIndexes;
  }

  MapHistory<Object, Set<Object>> _getTableFieldIndex(
      String table, String field) {
    var tableIndexes = _getTableIndexes(table);

    var fieldIndex = tableIndexes[field] ??= MapHistory<Object, Set<Object>>();
    return fieldIndex;
  }

  void _indexAddEntry(String table, Object id, String field, Object value) {
    var fieldIndex = _getTableFieldIndex(table, field);

    var idsWithValue = fieldIndex[value] ??= {};
    idsWithValue.add(id);
  }

  bool _indexDeleteEntry(String table, Object id, String field, Object value,
      {Map<String, MapHistory<Object, Set<Object>>>? tableIndexes}) {
    tableIndexes ??= _tablesIndexes[table];
    if (tableIndexes == null) return false;

    var fieldIndex = tableIndexes[field];
    if (fieldIndex == null) return false;

    var idsWithValue = fieldIndex[value];
    if (idsWithValue == null) return false;

    var rm = idsWithValue.remove(id);

    if (idsWithValue.isEmpty) {
      fieldIndex.remove(value);
    }

    return rm;
  }

  @override
  FutureOr doInsertSQL(String entityName, String table, SQL sql,
      Transaction transaction, DBSQLMemoryAdapterContext connection) {
    if (sql.isDummy) return null;

    var map = _getTableMap(table, true)!;

    var id = nextID(table);

    var entry = _normalizeEntityJSON(sql.parametersByPlaceholder,
        entityName: entityName, table: table);

    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    entry[idField] = id;

    map[id] = entry;

    _onTablesModification();

    return id;
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
        if (fieldType.isEntityReferenceType && value is EntityReference) {
          if (value.isNull) {
            return MapEntry(key, null);
          }

          var id = value.id;

          if (id != null) {
            return MapEntry(key, id);
          } else if (value.isEntitySet) {
            fieldType = fieldType.arguments0!;
            value = value.entity;
          }
        } else if (fieldType.isEntityReferenceListType &&
            value is EntityReferenceList) {
          if (value.isNull) {
            return MapEntry(key, null);
          }

          var ids = value.ids;

          if (ids != null) {
            return MapEntry(key, ids);
          } else if (value.isEntitiesSet) {
            var entityType = fieldType.arguments0!;
            fieldType = entityType.callCasted(
                <E>() => TypeInfo<List<E>>.fromType(List, [entityType]));
            value = value.entities;
          }
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
        } else if (!fieldType.isPrimitiveType &&
            EntityHandler.isValidEntityType(fieldType.type)) {
          var fieldEntityRepository = getEntityRepositoryByTypeInfo(fieldType);
          if (fieldEntityRepository == null) {
            throw StateError(
                "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType");
          }

          value = fieldEntityRepository.getEntityID(value);
        }
      } else if (value is EntityReference) {
        if (value.isNull) {
          return MapEntry(key, null);
        }

        var id = value.id;

        if (id != null) {
          return MapEntry(key, id);
        } else if (value.isEntitySet) {
          value = value.entityToJson();
        }
      } else if (value is EntityReferenceList) {
        if (value.isNull) {
          return MapEntry(key, null);
        }

        var ids = value.ids;

        if (ids != null) {
          return MapEntry(key, ids);
        } else if (value.isEntitiesSet) {
          value = value.entitiesToJson()!;
        }
      }

      return MapEntry(key, value);
    });

    return entityJsonNormalized;
  }

  @override
  FutureOr doUpdateSQL(String entityName, String table, SQL sql, Object id,
      Transaction transaction, DBSQLMemoryAdapterContext connection,
      {bool allowAutoInsert = false}) {
    if (sql.isDummy) return id;

    var map = _getTableMap(table, true)!;

    var prevEntry = map[id];

    var entry = _normalizeEntityJSON(sql.parametersByPlaceholder,
        entityName: entityName, table: table);

    if (prevEntry == null) {
      if (!allowAutoInsert) {
        throw StateError(
            "Can't update not stored entity into table `$table`: $entry");
      }

      var tablesScheme = tablesSchemes[table];
      var idField = tablesScheme?.idFieldName ?? 'id';

      entry[idField] ??= id;

      map[id] = entry;

      _disposeNextIDCounter(table);
    } else {
      var updated = deepCopyMap(prevEntry)!;
      updated.addAll(entry);

      map[id] = updated;
    }

    _onTablesModification();

    return id;
  }

  Object nextID(String table) {
    return _tablesIdCount.update(table, (n) => n + 1,
        ifAbsent: () => _getTableHighestID(table) + 1);
  }

  void _disposeNextIDCounter(String table) => _tablesIdCount.remove(table);

  int _getTableHighestID(String table) {
    var map = _getTableMap(table, false);
    if (map == null || map.isEmpty) return 0;

    var tablesScheme = tablesSchemes[table];
    var idField = tablesScheme?.idFieldName ?? 'id';

    var maxId = map.values.map((e) => parseInt(e[idField], 0)!).max;
    return maxId;
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String entityName,
      String table,
      SQL sql,
      Transaction transaction,
      DBSQLMemoryAdapterContext connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var sel = _selectEntries(table, sql);
    sel = _filterReturnColumns(sql, sel);

    return sel;
  }

  List<Map<String, dynamic>> _selectEntries(String table, SQL sql) {
    var map = _getTableMap(table, false);

    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme = getTableScheme(table, relationship: sql.relationship);

    var entityHandler = getEntityHandler(tableName: table);

    final condition = sql.condition;

    List<Map<String, dynamic>> sel;

    if (condition == null) {
      sel = map.values.toList();
    } else if (tableScheme == null ||
        (tableScheme.fieldsReferencedTablesLength == 0 &&
            tableScheme.tableRelationshipReferenceLength == 0) ||
        condition.isIDCondition) {
      sel = map.values.where((e) {
        return condition.matchesEntityMap(e,
            positionalParameters: sql.positionalParameters,
            namedParameters: sql.namedParameters ?? sql.parametersByPlaceholder,
            entityHandler: entityHandler);
      }).toList();
    } else {
      sel = map.values.where((obj) {
        obj = _resolveEntityMap(obj, entityHandler, tableScheme);

        return condition.matchesEntityMap(obj,
            positionalParameters: sql.positionalParameters,
            namedParameters: sql.namedParameters ?? sql.parametersByPlaceholder,
            entityHandler: entityHandler);
      }).toList();
    }

    return sel;
  }

  List<Map<String, dynamic>> _filterReturnColumns(
      SQL sql, List<Map<String, dynamic>> sel) {
    var returnColumns = sql.returnColumns;

    if (returnColumns != null && returnColumns.isNotEmpty) {
      return sel.map((e) {
        return Map<String, dynamic>.fromEntries(
            e.entries.where((e) => returnColumns.contains(e.key)));
      }).toList();
    }

    var returnColumnsAliases = sql.returnColumnsAliases;

    if (returnColumnsAliases != null && returnColumnsAliases.isNotEmpty) {
      return sel.map((e) {
        return Map<String, dynamic>.fromEntries(e.entries
            .where((e) => returnColumnsAliases.containsKey(e.key))
            .map((e) => MapEntry(returnColumnsAliases[e.key]!, e.value)));
      }).toList();
    }

    var selIsolated = sel.map((e) => deepCopyMap(e)!).toList();
    return selIsolated;
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String entityName,
      String table,
      SQL sql,
      Transaction transaction,
      DBSQLMemoryAdapterContext connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme = getTableScheme(table, relationship: sql.relationship);

    var entityHandler = getEntityHandler(tableName: table);

    if (tableScheme == null || tableScheme.fieldsReferencedTablesLength == 0) {
      var entries = map.entries.where((e) {
        return sql.condition!.matchesEntityMap(e.value,
            namedParameters: sql.parametersByPlaceholder,
            entityHandler: entityHandler);
      }).toList();

      _checkNotReferencedEntities(entries, table, sql);

      return _removeEntries(table, entries, map);
    }

    var entries = map.entries
        .map((e) {
          var obj = _resolveEntityMap(e.value, entityHandler, tableScheme);

          var match = sql.condition!.matchesEntityMap(obj,
              namedParameters: sql.parametersByPlaceholder,
              entityHandler: entityHandler);

          return match ? MapEntry(e.key, obj) : null;
        })
        .whereNotNull()
        .toList(growable: false);

    _checkNotReferencedEntities(entries, table, sql);

    return _removeEntries(table, entries, map);
  }

  void _checkNotReferencedEntities(
      List<MapEntry<Object, Map<String, dynamic>>> entries,
      String table,
      SQL sql) {
    for (var e in entries) {
      var id = e.key;

      var ref = _findAnyReference(table, id);
      if (ref != null) {
        var refTable = ref.key;
        var refId = ref.value.key;
        var refFieldName = ref.value.value.key;
        var refFieldValue = ref.value.value.value;
        throw DBSQLMemoryAdapterException("delete.constraint",
            "Can't delete $table(#$id). Referenced by: $refTable.#$refId.$refFieldName => #$refFieldValue",
            operation: sql);
      }
    }
  }

  List<Map<String, dynamic>> _removeEntries(
      String table,
      List<MapEntry<Object, Map<String, dynamic>>> entries,
      Map<Object, Map<String, dynamic>> tableMap) {
    if (entries.isEmpty) return <Map<String, dynamic>>[];

    var del = entries.map((e) => e.value).toList();

    for (var e in entries) {
      var id = e.key;
      tableMap.remove(id);
    }

    var tableIndexes = _tablesIndexes[table];

    if (tableIndexes != null) {
      for (var e in entries) {
        var id = e.key;
        var values = e.value;

        for (var e2 in values.entries) {
          var field = e2.key;
          var fieldValue = e2.value;

          _indexDeleteEntry(table, id, field, fieldValue);
        }
      }
    }

    _onTablesModification();

    return del;
  }

  Map<String, dynamic> _resolveEntityMap(Map<String, dynamic> obj,
      EntityHandler<dynamic>? entityHandler, TableScheme tableScheme) {
    var obj2 = HashMap.fromEntries(obj.entries.map((e) {
      var key = e.key;
      var value = e.value;
      var refField = tableScheme.getFieldReferencedTable(key);
      if (refField != null) {
        value = _resolveEntityFieldReferencedTable(obj, key, refField);
      }
      return MapEntry(key, value);
    }));

    var relationshipsTables = tableScheme.tableRelationshipReference.values
        .expand((e) => e)
        .where((e) => e.sourceTable == tableScheme.name)
        .toList();

    if (relationshipsTables.isNotEmpty) {
      if (entityHandler == null) {
        throw StateError(
            "Can't resolve relationship fields without an `EntityHandler` for `${tableScheme.name}`");
      }

      var fieldId = entityHandler.idFieldName();
      var id = obj2[fieldId];

      var fieldsListEntity =
          entityHandler.fieldsWithTypeListEntityOrReference();

      for (var e in fieldsListEntity.entries) {
        var fieldKey = e.key;
        var fieldType = e.value.arguments0!;

        var targetObjs = _resolveEntityFieldRelationshipTable(
            tableScheme, relationshipsTables, id, fieldType, fieldKey);
        if (targetObjs != null) {
          obj2[fieldKey] = targetObjs;
        }
      }
    }

    return obj2;
  }

  Object? _resolveEntityFieldReferencedTable(
      Map<String, dynamic> obj, String key, TableFieldReference refField) {
    var id = obj[key];
    if (id == null) return null;

    var fieldObj = _getByID(refField.targetTable, id);

    if (fieldObj != null) {
      var tableScheme2 = getTableScheme(refField.targetTable);

      if (tableScheme2 != null && tableScheme2.hasTableReferences) {
        var entityHandler2 = getEntityHandler(tableName: tableScheme2.name);
        fieldObj = _resolveEntityMap(fieldObj, entityHandler2, tableScheme2);
      }
    }

    return fieldObj;
  }

  List? _resolveEntityFieldRelationshipTable(
      TableScheme tableScheme,
      List<TableRelationshipReference> relationshipsTables,
      Object id,
      TypeInfo fieldType,
      String fieldKey) {
    var sourceTable = tableScheme.name;
    var targetTable = getTableForType(fieldType);

    if (targetTable == null) {
      return null;
    } else if (targetTable is Future) {
      throw StateError(
          "Async response not supported when calling `getTableForType`");
    }

    //print('!!! ** _resolveEntityFieldRelationshipTable> $sourceTable -> $targetTable');

    var relationshipTable = tableScheme.getTableRelationshipReference(
        sourceTable: sourceTable,
        sourceField: fieldKey,
        targetTable: targetTable);

    if (relationshipTable == null) {
      throw StateError(
          "Can't find relationship table for `$sourceTable`.`$fieldKey` -> `$targetTable`. Relationships tables: ${relationshipsTables.map((e) => e.relationshipTable).toList()}");
    }

    final relTable = relationshipTable.relationshipTable;

    var relMap = _getTableMap(relTable, false, relationship: true);
    if (relMap == null) {
      return null;
    }

    final sourceRelationshipField = relationshipTable.sourceRelationshipField;
    final targetRelationshipField = relationshipTable.targetRelationshipField;

    var sourceFieldIndex =
        _getTableFieldIndex(relTable, sourceRelationshipField);

    var relWithID = sourceFieldIndex[id];
    if (relWithID == null) {
      return [];
    }

    var targetIds = relWithID
        .map((relId) => relMap[relId]?[targetRelationshipField])
        .whereNotNull()
        .toList();

    if (targetIds.isEmpty) {
      return [];
    }

    var targetObjs =
        targetIds.map((tId) => _getByID(targetTable, tId) ?? tId).toList();

    var tableScheme2 = getTableScheme(targetTable);

    if (tableScheme2 != null && tableScheme2.hasTableReferences) {
      var entityHandler2 = getEntityHandler(tableName: tableScheme2.name);

      targetObjs = targetObjs
          .map((e) {
            return e is! Map<String, Object?>
                ? null
                : _resolveEntityMap(e, entityHandler2, tableScheme2);
          })
          .whereNotNull()
          .toList();
    }

    return targetObjs;
  }

  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  bool _hasTableScheme(String table) => tablesSchemes.containsKey(table);

  @override
  TableScheme? getTableScheme(String table,
      {TableRelationshipReference? relationship, Object? contextID}) {
    // ignore: discarded_futures
    var ret = super.getTableScheme(table, relationship: relationship);

    if (ret is Future) {
      throw StateError("Expected sync return from `super.getTableScheme`");
    }

    return ret;
  }

  @override
  TableScheme? getTableSchemeImpl(
      String table, TableRelationshipReference? relationship,
      {Object? contextID}) {
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
      var isCollection =
          fieldType.isCollection || fieldType.isEntityReferenceListType;
      if (isCollection != onlyCollectionReferences) return false;

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
        fieldType.isListEntityOrReference || fieldType.isEntityReferenceType
            ? fieldType.arguments0
            : fieldType;

    if (entityType == null ||
        !EntityHandler.isValidEntityType(entityType.type)) {
      return null;
    }

    return entityType;
  }

  Map<EntityRepository<Object>, Map<String, TableFieldReference>>
      _allTablesReferences() {
    var allRepositories = this.allRepositories();

    var entries = allRepositories.values.map((r) {
      var referencedTables = _findFieldsReferencedTables(r.name,
          entityType: r.type,
          entityHandler: r.entityHandler,
          onlyCollectionReferences: true);
      return MapEntry(r, referencedTables);
    }).where((e) => e.value.isNotEmpty);

    var allTablesReferences = Map.fromEntries(entries);
    return allTablesReferences;
  }

  List<TableRelationshipReference> _findRelationshipTables(String table) {
    var allTablesReferences = _allTablesReferences();

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
  FutureOr<bool> isConnectionValid(connection, {bool checkUsage = true}) =>
      true;

  final Map<DBSQLMemoryAdapterContext, DateTime> _openTransactionsContexts =
      <DBSQLMemoryAdapterContext, DateTime>{};

  @override
  DBSQLMemoryAdapterContext openTransaction(Transaction transaction) {
    var conn = catchFromPool();

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
  FutureOr<dynamic> resolveTransactionResult(
      result, Transaction transaction, DBSQLMemoryAdapterContext? connection) {
    var result2 =
        super.resolveTransactionResult(result, transaction, connection);

    if (connection != null && result2 is! TransactionAbortedError) {
      var consolidated = _consolidateTransactionContext(connection);
      if (consolidated != null && consolidated) {
        releaseIntoPool(connection);
      } else {
        disposePoolElement(connection);
      }
    }

    return result2;
  }

  @override
  bool get cancelTransactionResultWithError => true;

  @override
  bool get throwTransactionResultWithError => false;

  @override
  bool cancelTransaction(
      Transaction transaction,
      DBSQLMemoryAdapterContext? connection,
      Object? error,
      StackTrace? stackTrace) {
    if (connection == null) return true;
    _openTransactionsContexts.remove(connection);

    _rollbackTables(
        connection.tablesVersions, connection.tablesIndexesVersions);

    // ignore: discarded_futures
    disposePoolElement(connection);
    return true;
  }

  @override
  bool get callCloseTransactionRequired => true;

  @override
  FutureOr<void> closeTransaction(
      Transaction transaction, DBSQLMemoryAdapterContext? connection) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  final ListQueue<DBSQLMemoryAdapterContext> _consolidateContextQueue =
      ListQueue<DBSQLMemoryAdapterContext>();

  bool? _consolidateTransactionContext(DBSQLMemoryAdapterContext context) {
    var open = _openTransactionsContexts.remove(context);
    if (open == null) return null;

    if (_openTransactionsContexts.isNotEmpty) {
      _consolidateContextQueue.add(context);
      return false;
    }

    if (_consolidateContextQueue.isEmpty) {
      _consolidateTables(context.tablesVersions, context.tablesIndexesVersions);
    } else {
      var list = [..._consolidateContextQueue, context];
      list.sort();

      for (var c in list) {
        _consolidateTables(c.tablesVersions, c.tablesIndexesVersions);
      }
    }

    return true;
  }

  void _consolidateTables(
    Map<String, int> tablesVersions,
    Map<String, Map<String, int>> tablesIndexesVersions,
  ) {
    for (var e in tablesVersions.entries) {
      var table = e.key;
      var version = e.value;
      _consolidateTable(table, version);
    }

    for (var e in tablesIndexesVersions.entries) {
      var table = e.key;
      var indexesVersions = e.value;
      _consolidateTableIndexes(table, indexesVersions);
    }
  }

  void _consolidateTable(String table, int targetVersion) {
    var tableMap = _tables[table];
    tableMap?.consolidate(targetVersion);

    _onTablesModification();
  }

  void _consolidateTableIndexes(
      String table, Map<String, int> indexesTargetVersion) {
    var tableIndexes = _tablesIndexes[table];

    for (var e in indexesTargetVersion.entries) {
      var field = e.key;
      var targetVersion = e.value;
      var index = tableIndexes?[field];
      index?.consolidate(targetVersion);
    }

    _onTablesModification();
  }

  void _rollbackTables(
    Map<String, int> tablesVersions,
    Map<String, Map<String, int>> tablesIndexesVersions,
  ) {
    for (var e in tablesVersions.entries) {
      var table = e.key;
      var version = e.value;
      _rollbackTable(table, version);
    }

    for (var e in tablesIndexesVersions.entries) {
      var table = e.key;
      var indexesVersions = e.value;
      _rollbackTableIndexes(table, indexesVersions);
    }
  }

  void _rollbackTable(String table, int targetVersion) {
    var tableMap = _tables[table];
    tableMap?.rollback(targetVersion);
    _onTablesModification();
  }

  void _rollbackTableIndexes(
      String table, Map<String, int> indexesTargetVersion) {
    var tableIndexes = _tablesIndexes[table];

    for (var e in indexesTargetVersion.entries) {
      var field = e.key;
      var targetVersion = e.value;
      var index = tableIndexes?[field];
      index?.rollback(targetVersion);
    }

    _onTablesModification();
  }

  @override
  String toString() {
    var tablesSizes = _tables.map((key, value) => MapEntry(key, value.length));
    var tablesStr = tablesSizes.isNotEmpty ? ', tables: $tablesSizes' : '';
    var closedStr = isClosed ? ', closed' : '';
    return 'DBSQLMemoryAdapter#$instanceID{id: $instanceID$tablesStr$closedStr}';
  }
}

@Deprecated("Renamed to 'DBSQLMemoryAdapterException'")
typedef DBMemorySQLAdapterException = DBSQLMemoryAdapterException;

/// Error thrown by [DBSQLMemoryAdapter] operations.
class DBSQLMemoryAdapterException extends DBSQLAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBSQLMemoryAdapterException';

  DBSQLMemoryAdapterException(super.type, super.message,
      {super.parentError,
      super.parentStackTrace,
      super.operation,
      super.previousError});
}
