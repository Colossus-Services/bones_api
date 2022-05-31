import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';
import 'package:async_extension/async_extension.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_mixin.dart';
import 'bones_api_platform.dart';
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

    SQLAdapter.registerAdapter(
        ['memory', 'mem'], MemorySQLAdapter, _instantiate);
  }

  static FutureOr<MemorySQLAdapter?> _instantiate(config,
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
  }

  static int _idCount = 0;

  final int id = ++_idCount;

  MemorySQLAdapter(
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider})
      : super(
          minConnections ?? 1,
          maxConnections ?? 3,
          const SQLAdapterCapability(
              dialect: 'generic', transactions: true, transactionAbort: false),
          parentRepositoryProvider: parentRepositoryProvider,
        ) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<MemorySQLAdapter> fromConfig(Map<String, dynamic>? config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    boot();

    minConnections ??= config?['minConnections'] ?? 1;
    maxConnections ??= config?['maxConnections'] ?? 3;

    var adapter = MemorySQLAdapter(
      minConnections: minConnections,
      maxConnections: maxConnections,
      parentRepositoryProvider: parentRepositoryProvider,
    );

    var populate = config?['populate'];

    if (populate != null) {
      adapter._populateSource = populate['source'];
    }

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
  FutureOr<bool> initialize() => _populateImpl();

  Object? _populateSource;

  FutureOr<bool> _populateImpl() {
    var populateSource = _populateSource;
    if (populateSource != null) {
      _populateSource = null;
      return populateFromSource(populateSource).resolveWithValue(true);
    } else {
      return true;
    }
  }

  static const _logSectionOpen =
      '\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
  static const _logSectionClose =
      '\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>';

  FutureOr<MemorySQLAdapter> populateFromSource(Object? source) {
    if (source == null) {
      return this;
    } else if (source is Map<String, Iterable<Map<String, dynamic>>>) {
      _log.info(
          'Populating adapter ($this) [Map entries: ${source.length}]...$_logSectionOpen');

      return storeAllFromJson(source).resolveMapped((_) {
        _log.info('Populate finished. $_logSectionClose');
        return this;
      });
    } else if (source is String) {
      if (RegExp(r'^\S+\.json$').hasMatch(source)) {
        var apiPlatform = APIPlatform.get();

        _log.info(
            'Reading $this populate source file: ${apiPlatform.resolveFilePath(source)}');

        var fileData = apiPlatform.readFileAsString(source);

        if (fileData != null) {
          return fileData.resolveMapped((data) {
            if (data != null) {
              _log.info(
                  'Populating $this [encoded JSON length: ${data.length}]...$_logSectionOpen');

              return storeAllFromJsonEncoded(data).resolveMapped((_) {
                _log.info('Populate finished. $_logSectionClose');
                return this;
              });
            } else {
              return this;
            }
          });
        }
      } else {
        _log.info(
            'Populating $this [encoded JSON length: ${source.length}]...$_logSectionOpen');

        return storeAllFromJsonEncoded(source).resolveMapped((_) {
          _log.info('Populate finished. $_logSectionClose');
          return this;
        });
      }
    }

    return this;
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
  FutureOr doInsertRelationshipSQL(
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return null;

    var entry = sql.namedParameters ?? sql.parametersByPlaceholder;

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

    var entry = sql.parametersByPlaceholder;

    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    entry[idField] = id;

    map[id] = entry;

    return id;
  }

  @override
  FutureOr doUpdateSQL(
      String entityName, String table, SQL sql, Object id, int connection,
      {bool allowAutoInsert = false, Transaction? transaction}) {
    if (sql.isDummy) return null;

    var map = _getTableMap(table, true)!;

    var prevEntry = map[id];

    var entry = sql.parametersByPlaceholder;

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
      prevEntry.addAll(entry);
    }

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
      String entityName, String table, SQL sql, int connection) {
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

    var tableScheme =
        getTableScheme(table, relationship: sql.relationship) as TableScheme?;

    var entityHandler = getEntityHandler(tableName: table);

    List<Map<String, dynamic>> sel;

    if (tableScheme == null ||
        (tableScheme.fieldsReferencedTablesLength == 0 &&
            tableScheme.tableRelationshipReferenceLength == 0)) {
      sel = map.values.where((e) {
        return sql.condition!.matchesEntityMap(e,
            positionalParameters: sql.positionalParameters,
            namedParameters: sql.namedParameters ?? sql.parametersByPlaceholder,
            entityHandler: entityHandler);
      }).toList();
    } else {
      sel = map.values.where((obj) {
        obj = _resolveEntityMap(obj, entityHandler, tableScheme);

        return sql.condition!.matchesEntityMap(obj,
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
      String entityName, String table, SQL sql, int connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var map = _getTableMap(table, false);
    if (map == null) {
      return <Map<String, dynamic>>[];
    }

    var tableScheme =
        getTableScheme(table, relationship: sql.relationship) as TableScheme?;

    var entityHandler = getEntityHandler(tableName: table);

    if (tableScheme == null || tableScheme.fieldsReferencedTablesLength == 0) {
      var entries = map.entries.where((e) {
        return sql.condition!.matchesEntityMap(e.value,
            namedParameters: sql.parametersByPlaceholder,
            entityHandler: entityHandler);
      }).toList();

      return _removeEntries(entries, map);
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

  Map<String, dynamic> _resolveEntityMap(Map<String, dynamic> obj,
      EntityHandler<dynamic>? entityHandler, TableScheme tableScheme) {
    var obj2 = obj.map((key, value) {
      var refField = tableScheme.getFieldsReferencedTables(key);
      if (refField != null) {
        var id = obj[key];

        if (id != null) {
          var obj2 = _getByID(refField.targetTable, id);

          if (obj2 != null) {
            var tableScheme2 =
                getTableScheme(refField.targetTable) as TableScheme?;

            if (tableScheme2 != null && tableScheme2.hasTableReferences) {
              var entityHandler2 =
                  getEntityHandler(tableName: tableScheme2.name);
              obj2 = _resolveEntityMap(obj2, entityHandler2, tableScheme2);
            }
          }

          value = obj2;
        }
      }

      return MapEntry(key, value);
    });

    var relationshipsTables = tableScheme.tableRelationshipReference.values
        .where((e) => e.sourceTable == tableScheme.name)
        .toList();

    if (relationshipsTables.isNotEmpty) {
      if (entityHandler == null) {
        throw StateError(
            "Can't resolve relationship fields without an `EntityHandler` for `${tableScheme.name}`");
      }

      var fieldId = entityHandler.idFieldName();
      var id = obj2[fieldId];

      var fieldsListEntity = entityHandler.fieldsWithTypeListEntity();

      for (var e in fieldsListEntity.entries) {
        var field = e.key;
        if (obj2.containsKey(field)) continue;

        var fieldType = e.value.listEntityType!;

        var targetTable = getTableForType(fieldType);

        if (targetTable == null) {
          continue;
        } else if (targetTable is Future) {
          throw StateError(
              "Async response not supported when calling `getTableForType`");
        }

        var relationshipTable =
            relationshipsTables.firstWhere((t) => t.targetTable == targetTable);

        var relMap = _getTableMap(relationshipTable.relationshipTable, false);
        if (relMap == null) continue;

        var entries = relMap.values
            .where((e) => e[relationshipTable.sourceRelationshipField] == id);

        var targetIds = entries
            .map((e) => e[relationshipTable.targetRelationshipField])
            .toList();

        var targetObjs =
            targetIds.map((tId) => _getByID(targetTable!, tId) ?? tId).toList();

        var tableScheme2 = getTableScheme(targetTable!) as TableScheme?;

        if (tableScheme2 != null && tableScheme2.hasTableReferences) {
          var entityHandler2 = getEntityHandler(tableName: tableScheme2.name);

          targetObjs = targetObjs
              .map((e) => _resolveEntityMap(e, entityHandler2, tableScheme2))
              .toList();
        }

        obj2[field] = targetObjs;
      }
    }

    return obj2;
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

    var idFieldName = entityHandler.idFieldName();

    var entityFieldsTypes = entityHandler.fieldsTypes();

    var fieldsTypes =
        entityFieldsTypes.map((key, value) => MapEntry(key, value.type));

    var fieldsReferencedTables = _findFieldsReferencedTables(table,
        entityHandler: entityHandler, entityFieldsTypes: entityFieldsTypes);

    var relationshipTables = _findRelationshipTables(table);

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
        targetName = getEntityRepository(type: targetEntityHandler.type)?.name;
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
        fieldType.isListEntity ? fieldType.listEntityType : fieldType;
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
        var sourceEntityHandler = repo.entityHandler;
        var sourceFieldId = sourceEntityHandler.idFieldName();
        var sourceFieldIdType =
            sourceEntityHandler.getFieldType(null, sourceFieldId)?.type ?? int;

        var relTable = ref.sourceTable + '_' + ref.targetTable + '_ref';
        var relSourceField = ref.sourceTable + '_' + sourceFieldId;
        var relTargetField = ref.targetTable + '_' + ref.targetField;

        return TableRelationshipReference(
          relTable,
          ref.sourceTable,
          sourceFieldId,
          sourceFieldIdType,
          relSourceField,
          ref.targetTable,
          ref.targetField,
          ref.targetFieldType,
          relTargetField,
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

  @override
  String toString() {
    var tablesSizes = _tables.map((key, value) => MapEntry(key, value.length));
    var tablesStr = tablesSizes.isNotEmpty ? ', tables: $tablesSizes' : '';
    return 'MemorySQLAdapter{id: $id$tablesStr}';
  }
}
