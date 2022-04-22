import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('MemorySQLAdapter');

/// A [SQLAdapter] that stores tables data in memory.
///
/// Simulates a SQL Database adapter. Useful for tests.
class MemorySQLAdapter extends SQLAdapter<int> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    SQLAdapter.registerAdapter(['memory', 'mem'], MemorySQLAdapter, (config,
        {int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider}) {
      try {
        return MemorySQLAdapter.fromConfig(config,
            minConnections: minConnections,
            maxConnections: maxConnections,
            parentRepositoryProvider: parentRepositoryProvider);
      } catch (e, s) {
        _log.severe("Error instantiating from config", e, s);
        return null;
      }
    });
  }

  static int _idCount = 0;

  final int id = ++_idCount;

  MemorySQLAdapter(
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider})
      : super(minConnections ?? 1, maxConnections ?? 3, 'generic',
            parentRepositoryProvider: parentRepositoryProvider) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  factory MemorySQLAdapter.fromConfig(Map<String, dynamic>? config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    boot();

    minConnections ??= config?['minConnections'] ?? 1;
    maxConnections ??= config?['maxConnections'] ?? 3;

    return MemorySQLAdapter(
      minConnections: minConnections,
      maxConnections: maxConnections,
      parentRepositoryProvider: parentRepositoryProvider,
    );
  }

  @override
  String get sqlElementQuote => '';

  @override
  bool get sqlAcceptsOutputSyntax => false;

  @override
  bool get sqlAcceptsReturningSyntax => true;

  @override
  bool get sqlAcceptsTemporaryTableForReturning => false;

  @override
  bool get sqlAcceptsInsertIgnore => true;

  @override
  bool get sqlAcceptsInsertOnConflict => false;

  int _connectionCount = 0;

  @override
  String getConnectionURL(int connection) => 'memory://$connection';

  @override
  int createConnection() => ++_connectionCount;

  @override
  FutureOr<bool> closeConnection(int connection) => true;

  final Map<String, Map<Object, Map<String, dynamic>>> _tables =
      <String, Map<Object, Map<String, dynamic>>>{};

  final Map<String, int> _tablesIdCount = <String, int>{};

  Map<Object, Map<String, dynamic>>? _getTableMap(
      String table, bool autoCreate) {
    var map = _tables[table];
    if (map != null) {
      return map;
    } else if (autoCreate) {
      _tables[table] = map = <int, Map<String, dynamic>>{};
      return map;
    } else {
      return null;
    }
  }

  Map<String, dynamic>? _getByID(String table, Object id) {
    var map = _getTableMap(table, false);
    return map?[id];
  }

  @override
  FutureOr<int> doCountSQL(
      String entityName, String table, SQL sql, int connection) {
    var map = _getTableMap(table, false);
    return map == null ? 0 : map.length;
  }

  @override
  FutureOr doInsertRelationshipSQL(
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return null;

    var entry = sql.parameters;

    var map = _getTableMap(table, true)!;

    var prevEntry =
        map.entries.firstWhereOrNull((e) => isEqualsDeep(e.value, entry));
    if (prevEntry != null) {
      return prevEntry.key;
    }

    var id = nextID(table);
    map[id] = entry;

    return id;
  }

  @override
  FutureOr doInsertSQL(
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return null;

    var map = _getTableMap(table, true)!;

    var id = nextID(table);

    var entry = sql.parameters;

    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    entry[idField] = id;

    map[id] = entry;

    return id;
  }

  @override
  FutureOr doUpdateSQL(
      String entityName, String table, SQL sql, Object id, int connection) {
    if (sql.isDummy) return null;

    var map = _getTableMap(table, true)!;

    var entry = sql.parameters;

    var prevEntry = map[id];

    prevEntry!.addAll(entry);

    return id;
  }

  Object nextID(String table) {
    return _tablesIdCount.update(table, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme =
        getTableScheme(table, relationship: sql.relationship) as TableScheme?;

    var entityHandler = getEntityRepository(name: table)?.entityHandler;

    if (tableScheme == null ||
        (tableScheme.fieldsReferencedTablesLength == 0 &&
            tableScheme.tableRelationshipReferenceLength == 0)) {
      var sel = map.values.where((e) {
        return sql.condition!.matchesEntityMap(e,
            namedParameters: sql.parameters, entityHandler: entityHandler);
      }).toList();

      sel = _filterReturnColumns(sql, sel);
      return sel;
    }

    var sel = map.values.where((obj) {
      obj = _resolveEntityMap(obj, tableScheme);

      return sql.condition!.matchesEntityMap(obj,
          namedParameters: sql.parameters, entityHandler: entityHandler);
    }).toList();

    sel = _filterReturnColumns(sql, sel);
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

    return sel;
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme =
        getTableScheme(table, relationship: sql.relationship) as TableScheme?;

    var entityHandler = getEntityRepository(name: table)?.entityHandler;

    if (tableScheme == null || tableScheme.fieldsReferencedTablesLength == 0) {
      var entries = map.entries.where((e) {
        return sql.condition!.matchesEntityMap(e.value,
            namedParameters: sql.parameters, entityHandler: entityHandler);
      }).toList();

      return _removeEntries(entries, map);
    }

    var entries = map.entries
        .map((e) {
          var obj = _resolveEntityMap(e.value, tableScheme);

          var match = sql.condition!.matchesEntityMap(obj,
              namedParameters: sql.parameters, entityHandler: entityHandler);

          return match ? MapEntry(e.key, obj) : null;
        })
        .whereNotNull()
        .toList(growable: false);

    return _removeEntries(entries, map);
  }

  List<Map<String, dynamic>> _removeEntries(
      List<MapEntry<Object, Map<String, dynamic>>> entries,
      Map<Object, Map<String, dynamic>> map) {
    var del = entries.map((e) => e.value).toList();

    for (var e in entries) {
      map.remove(e.key);
    }

    return del;
  }

  Map<String, dynamic> _resolveEntityMap(
      Map<String, dynamic> obj, TableScheme tableScheme) {
    return obj.map((key, value) {
      var refField = tableScheme.getFieldsReferencedTables(key);
      if (refField != null) {
        var id = obj[key];

        if (id != null) {
          var obj2 = _getByID(refField.targetTable, id);

          if (obj2 != null) {
            var tableScheme2 =
                getTableScheme(refField.targetTable) as TableScheme?;

            if (tableScheme2 != null &&
                tableScheme2.fieldsReferencedTablesLength > 0) {
              obj2 = _resolveEntityMap(obj2, tableScheme2);
            }
          }

          value = obj2;
        }
      }

      return MapEntry(key, value);
    });
  }

  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  @override
  FutureOr<TableScheme?> getTableSchemeImpl(
      String table, TableRelationshipReference? relationship) {
    _log.info('getTableSchemeImpl> $table ; relationship: $relationship');

    var tableScheme = tablesSchemes[table];
    if (tableScheme != null) return tableScheme;

    var entityHandler = getEntityHandler(tableName: table);
    if (entityHandler == null) {
      if (relationship != null) {
        var sourceId =
            relationship.sourceTable + '_' + relationship.sourceField;
        var targetId =
            relationship.targetTable + '_' + relationship.targetField;

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

    var idFieldName = entityHandler.idFieldsName();

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

  @override
  String toString() {
    var tablesSizes = _tables.map((key, value) => MapEntry(key, value.length));
    return 'MemorySQLAdapter{id: $id, tables: $tablesSizes}';
  }
}
