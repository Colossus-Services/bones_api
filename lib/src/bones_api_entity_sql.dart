import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_entity_adapter_sql.dart';
import 'bones_api_initializable.dart';
import 'bones_api_sql_builder.dart';

final _log = logging.Logger('SQLEntityRepository');

class SQLEntityRepository<O extends Object> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  final SQLRepositoryAdapter<O> sqlRepositoryAdapter;

  SQLEntityRepository(
      SQLAdapter adapter, String name, EntityHandler<O> entityHandler,
      {SQLRepositoryAdapter<O>? repositoryAdapter, Type? type})
      : sqlRepositoryAdapter =
            repositoryAdapter ?? adapter.createRepositoryAdapter<O>(name)!,
        super(adapter, name, entityHandler, type: type);

  @override
  FutureOr<InitializationResult> initialize() => provider
          .executeInitialized(
              () => sqlRepositoryAdapter.ensureInitialized(parent: this),
              parent: this)
          .resolveMapped((result) {
        return InitializationResult.ok(this, dependencies: [
          provider,
          sqlRepositoryAdapter,
          ...result.dependencies
        ]);
      });

  String get dialect => sqlRepositoryAdapter.dialect;

  String get tableName => sqlRepositoryAdapter.tableName;

  @override
  Map<String, dynamic> information({bool extended = false}) => {
        'queryType': 'SQL',
        'dialect': dialect,
        'table': name,
        if (extended)
          'sqlAdapter': sqlRepositoryAdapter.information(extended: true),
      };

  @override
  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) {
    var cachedEntityByID = transaction?.getCachedEntityByID(id, type: type);
    if (cachedEntityByID != null) return false;

    return count(matcher: ConditionID(id), transaction: transaction)
        .resolveMapped((count) => count > 0);
  }

  @override
  FutureOr<dynamic> ensureStored(o, {Transaction? transaction}) {
    checkNotClosed();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null || entityHasChangedFields(o)) {
      return store(o, transaction: transaction);
    } else {
      if (isTrackingEntity(o)) {
        return ensureReferencesStored(o, transaction: transaction)
            .resolveWithValue(id);
      }

      return existsID(id, transaction: transaction).resolveMapped((exists) {
        if (!exists) {
          return store(o, transaction: transaction);
        } else {
          return ensureReferencesStored(o, transaction: transaction)
              .resolveWithValue(id);
        }
      });
    }
  }

  @override
  FutureOr<bool> ensureReferencesStored(o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew();

    var fieldsNames = entityHandler.fieldsNames(o);

    var futures = fieldsNames
        .map((fieldName) {
          var value = entityHandler.getField(o, fieldName);
          if (value == null) return null;

          var fieldType = entityHandler.getFieldType(o, fieldName)!;

          if (value is List && fieldType.isList && fieldType.hasArguments) {
            var elementType = fieldType.arguments.first;
            if (!EntityHandler.isValidEntityType(elementType.type)) return null;

            var elementRepository =
                provider.getEntityRepositoryByType(elementType.type);
            if (elementRepository == null) return null;

            var futures = value.map((e) {
              return elementRepository.ensureStored(e,
                  transaction: transaction);
            }).toList();
            return futures.resolveAll();
          } else {
            if (!EntityHandler.isValidEntityType(fieldType.type)) return null;

            var repository =
                provider.getEntityRepository(type: fieldType.type, obj: value);
            if (repository == null) return null;

            return repository.ensureStored(value, transaction: transaction);
          }
        })
        .whereNotNullSync()
        .toList(growable: false);

    return futures.resolveAllWithValue(true);
  }

  @override
  FutureOr<int> length({Transaction? transaction}) =>
      count(transaction: transaction);

  @override
  FutureOr<int> count(
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var op = TransactionOperationCount(name, null, transaction);

    try {
      return sqlRepositoryAdapter.doCount(op,
          matcher: matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
    } catch (e, s) {
      var message = 'count> '
          'matcher: $matcher ; '
          'parameters: $parameters ; '
          'positionalParameters: $positionalParameters ; '
          'namedParameters: $namedParameters ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  @override
  FutureOr<List<O>> select(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    checkNotClosed();

    var op = TransactionOperationSelect(name, matcher, transaction);

    try {
      return sqlRepositoryAdapter.doSelect(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit, preFinish: (results) {
        return _resolveEntities(op.transaction, results);
      });
    } catch (e, s) {
      var message = 'select> '
          'matcher: $matcher ; '
          'parameters: $parameters ; '
          'positionalParameters: $positionalParameters ; '
          'namedParameters: $namedParameters ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  @override
  FutureOr<Iterable<O>> selectAll({Transaction? transaction, int? limit}) =>
      select(ConditionANY(), limit: limit);

  FutureOr<List<O>> _resolveEntities(
      Transaction transaction, Iterable<Map<String, dynamic>> results) {
    if (results.isEmpty) return <O>[];

    var fieldsEntity = entityHandler.fieldsWithTypeEntity();
    var fieldsListEntity = entityHandler.fieldsWithTypeListEntity();

    if (fieldsListEntity.isNotEmpty) {
      var retTableScheme = sqlRepositoryAdapter.getTableScheme();
      var retRelationshipFields =
          _getRelationshipFields(fieldsListEntity, retTableScheme);

      var ret = retTableScheme.resolveOther<List<FutureOr<O>>,
              Map<String, TableRelationshipReference>>(retRelationshipFields,
          (tableScheme, relationshipFields) {
        if (relationshipFields.isNotEmpty) {
          results = results is List ? results : results.toList();

          var resolveRelationshipsFields = _resolveRelationshipFields(
            transaction,
            tableScheme,
            results,
            relationshipFields,
            fieldsListEntity,
          );

          return resolveRelationshipsFields.resolveAllWith(() =>
              _resolveEntitiesSubEntities(transaction, results, fieldsEntity));
        } else {
          return _resolveEntitiesSubEntities(
              transaction, results, fieldsEntity);
        }
      });

      return _resolveEntitiesFutures(transaction, ret);
    } else {
      var ret = _resolveEntitiesSubEntities(transaction, results, fieldsEntity);
      return _resolveEntitiesFutures(transaction, ret);
    }
  }

  FutureOr<List<O>> _resolveEntitiesFutures(
      Transaction transaction, FutureOr<List<FutureOr<O>>> entitiesAsync) {
    if (entitiesAsync is List<O>) {
      transaction.cacheEntities<O>(entitiesAsync, getEntityID);
      return trackEntities(entitiesAsync);
    }

    return entitiesAsync
        .resolveMapped((e) => e.resolveAll().resolveMapped((entities) {
              transaction.cacheEntities<O>(entities, getEntityID);
              return trackEntities(entities);
            }));
  }

  List<FutureOr<O>> _resolveEntitiesSimple(
      Transaction transaction, Iterable<Map<String, dynamic>> results) {
    return results.map((e) {
      return entityHandler.createFromMap(e,
          entityProvider: transaction,
          entityCache: transaction,
          entityRepositoryProvider: provider,
          entityHandlerProvider: entityHandler.provider);
    }).toList();
  }

  FutureOr<List<FutureOr<O>>> _resolveEntitiesSubEntities(
      Transaction transaction,
      Iterable<Map<String, dynamic>> results,
      Map<String, TypeInfo> fieldsEntity) {
    if (fieldsEntity.isEmpty) {
      return _resolveEntitiesSimple(transaction, results);
    }

    var resultsList =
        results is List<Map<String, dynamic>> ? results : results.toList();

    if (resultsList.length == 1) {
      return _resolveEntitiesSimple(transaction, resultsList);
    }

    var fieldsEntityRepositories = fieldsEntity.entries
        .map((e) {
          var fieldEntityRepository = _resolveEntityRepository(e.value.type);
          return fieldEntityRepository != null
              ? MapEntry(e.key, fieldEntityRepository)
              : null;
        })
        .whereNotNull()
        .toMapFromEntries();

    if (fieldsEntityRepositories.isNotEmpty) {
      var fieldsEntitiesAsync = fieldsEntityRepositories.map((field, repo) {
        var tableColumn = _resolveEntityFieldToTableColumn(field);

        var fieldValues = resultsList.map((e) => e[tableColumn]).toList();
        var fieldValuesUniques = fieldValues.toSet().toList();

        var entities = repo
            .selectByIDs(fieldValuesUniques, transaction: transaction)
            .resolveMapped((entities) => fieldValuesUniques
                .mapIndexed((i, val) => MapEntry(val, entities[i]))
                .toList());

        return MapEntry(tableColumn, entities);
      }).resolveAllValues();

      return fieldsEntitiesAsync.resolveMapped((fieldsEntities) {
        for (var e in fieldsEntities.entries) {
          var field = e.key;
          var fieldEntities = Map.fromEntries(e.value);

          var length = resultsList.length;

          for (var i = 0; i < length; ++i) {
            var result = resultsList[i];
            var entityId = result[field];
            var entity = fieldEntities[entityId];
            result[field] = entity;
          }
        }

        return _resolveEntitiesSimple(transaction, resultsList);
      });
    }

    return _resolveEntitiesSimple(transaction, results);
  }

  Iterable<FutureOr<bool>> _resolveRelationshipFields(
    Transaction transaction,
    TableScheme tableScheme,
    Iterable<Map<String, dynamic>> results,
    Map<String, TableRelationshipReference> relationshipFields,
    Map<String, TypeInfo> fieldsListEntity,
  ) {
    var idFieldName = tableScheme.idFieldName!;
    var ids = results.map((e) => e[idFieldName]).toList();

    var databaseAdapter = sqlRepositoryAdapter.databaseAdapter;

    return relationshipFields.entries.map((e) {
      var fieldName = e.key;
      var fieldType = fieldsListEntity[fieldName]!;
      var targetTable = e.value.targetTable;

      var targetRepositoryAdapter =
          databaseAdapter.getRepositoryAdapterByTableName(targetTable)!;
      var targetType = targetRepositoryAdapter.type;
      var targetEntityRepository =
          provider.getEntityRepositoryByType(targetType)!;

      var relationshipsAsync = selectRelationships(null, fieldName,
          oIds: ids, fieldType: fieldType, transaction: transaction);

      var retRelationships = relationshipsAsync.resolveMapped((relationships) {
        var allTargetIds =
            relationships.values.expand((e) => e).toSet().toList();

        var targetsAsync = targetEntityRepository.selectByIDs(allTargetIds,
            transaction: transaction);

        return targetsAsync.resolveMapped((targets) {
          var allTargetsById = Map.fromEntries(targets
              .whereNotNull()
              .map((e) => MapEntry(targetEntityRepository.getEntityID(e)!, e)));

          return relationships.map((id, targetIds) {
            var targetEntities =
                targetIds.map((id) => allTargetsById[id]).toList();
            var targetEntitiesCast = targetEntityRepository.entityHandler
                .castList(targetEntities, targetType)!;
            return MapEntry(id, targetEntitiesCast);
          }).resolveAllValues();
        });
      });

      return retRelationships.resolveMapped((relationships) {
        for (var r in results) {
          var id = r[idFieldName];
          var values = relationships[id];
          values ??= targetEntityRepository.entityHandler
              .castList(<dynamic>[], targetType)!;
          r[fieldName] = values;
        }
      }).resolveWithValue(true);
    });
  }

  // ignore: unused_element
  String _resolveTableColumnToEntityField(String tableField, [O? o]) {
    var fieldsNames = entityHandler.fieldsNames(o);
    var entityFieldName =
        entityHandler.resolveFiledName(fieldsNames, tableField);
    if (entityFieldName == null) {
      throw StateError(
          "Can't resolve the table column `$tableField` to one of the entity `${entityHandler.type}` fields: $fieldsNames");
    }
    return entityFieldName;
  }

  String _resolveEntityFieldToTableColumn(String entityField) {
    var tableScheme = sqlRepositoryAdapter.getTableScheme() as TableScheme;

    var tableField = tableScheme.resolveTableFiledName(entityField);
    if (tableField == null) {
      throw StateError(
          "Can't resolve entity `${entityHandler.type}` field `$entityField` to one of the table `${tableScheme.name}` columns: ${tableScheme.fieldsNames}");
    }

    return tableField;
  }

  FutureOr<Map<String, TableRelationshipReference>> _getRelationshipFields(
      Map<String, TypeInfo> fieldsListEntity,
      [FutureOr<TableScheme>? retTableScheme]) {
    retTableScheme ??= sqlRepositoryAdapter.getTableScheme();

    return retTableScheme.resolveMapped((tableScheme) {
      var databaseAdapter = sqlRepositoryAdapter.databaseAdapter;

      var entries = fieldsListEntity.entries.map((e) {
        var fieldName = e.key;
        var targetType = e.value.listEntityType!.type;
        var targetRepositoryAdapter =
            databaseAdapter.getRepositoryAdapterByType(targetType);
        if (targetRepositoryAdapter == null) return null;
        var relationship = tableScheme.getTableRelationshipReference(
            sourceTable: tableName,
            sourceField: fieldName,
            targetTable: targetRepositoryAdapter.name);
        if (relationship == null) return null;
        return MapEntry(e.key, relationship);
      }).whereNotNull();

      return Map<String, TableRelationshipReference>.fromEntries(entries);
    });
  }

  @override
  bool isStored(O o, {Transaction? transaction}) {
    var id = entityHandler.getID(o);
    return id != null;
  }

  @override
  void checkEntityFields(O o) {
    entityHandler.checkAllFieldsValues(o);

    sqlRepositoryAdapter.checkEntityFields(o, entityHandler);
  }

  @override
  FutureOr<dynamic> store(O o, {Transaction? transaction}) {
    checkNotClosed();

    checkEntityFields(o);

    if (isStored(o, transaction: transaction)) {
      return _update(o, transaction, true);
    }

    var op = TransactionOperationStore(name, o, transaction);

    try {
      return ensureReferencesStored(o, transaction: op.transaction)
          .resolveWith(() {
        var idFieldsName = entityHandler.idFieldName(o);
        var fields = entityHandler.getFields(o);

        return sqlRepositoryAdapter.doInsert(op, o, fields,
            idFieldName: idFieldsName, preFinish: (id) {
          entityHandler.setID(o, id);

          return _ensureRelationshipsStored(o, op.transaction).resolveWith(() {
            trackEntity(o);
            return id; // pre-finish
          });
        });
      });
    } catch (e, s) {
      var message = 'store> '
          'o: $o ; '
          'transaction: $transaction ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  FutureOr<dynamic> _update(
      O o, Transaction? transaction, bool allowAutoInsert) {
    var op = TransactionOperationUpdate(name, o, transaction);

    return ensureReferencesStored(o, transaction: op.transaction)
        .resolveWith(() {
      var idFieldsName = entityHandler.idFieldName(o);
      var id = entityHandler.getID(o);
      var fields = entityHandler.getFields(o);

      var changedFields = getEntityChangedFields(o);
      if (changedFields != null) {
        if (changedFields.isEmpty) {
          return _ensureRelationshipsStored(o, op.transaction).resolveWith(() {
            trackEntity(o);
            return op.finish(id);
          });
        }

        fields.removeWhere((key, value) => !changedFields.contains(key));
      }

      return sqlRepositoryAdapter.doUpdate(op, o, id, fields,
          idFieldName: idFieldsName,
          allowAutoInsert: allowAutoInsert, preFinish: (id) {
        return _ensureRelationshipsStored(o, op.transaction).resolveWith(() {
          trackEntity(o);
          return id; // pre-finish
        });
      });
    });
  }

  FutureOr<bool> _ensureRelationshipsStored(O o, Transaction? transaction) {
    var fieldsListEntity = entityHandler.fieldsWithTypeListEntity(o);
    if (fieldsListEntity.isEmpty) return false;

    var ret = fieldsListEntity.entries.map((e) {
      var field = e.key;
      var fieldType = e.value;
      var values = entityHandler.getField(o, field);
      return setRelationship(o, field, values,
          fieldType: fieldType, transaction: transaction);
    }).resolveAll();

    return ret.resolveWithValue(true);
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    fieldType ??= entityHandler.getFieldType(o, field)!;

    var op =
        TransactionOperationStoreRelationship(name, o, values, transaction);

    var valuesType = fieldType.listEntityType!.type;
    String valuesTableName = _resolveTableName(valuesType);
    var valuesEntityHandler = _resolveEntityHandler(valuesType);

    var oId = entityHandler.getID(o);
    var othersIds = values.map((e) => valuesEntityHandler.getID(e)).toList();

    try {
      return sqlRepositoryAdapter.doInsertRelationship(
          op, field, oId, valuesTableName, othersIds);
    } catch (e, s) {
      var message = 'setRelationship[$valuesTableName]> '
          'o: $o ; '
          'field: $field ; '
          'fieldType: $fieldType ; '
          'values: $values ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction}) {
    fieldType ??= entityHandler.getFieldType(o, field)!;

    oId ??= entityHandler.getID(o!);

    var cachedRelationship =
        _getCachedEntityRelationship(oId, field, fieldType, transaction);
    if (cachedRelationship != null) {
      return cachedRelationship;
    }

    var op =
        TransactionOperationSelectRelationship(name, o ?? oId, transaction);

    var valuesType = fieldType.listEntityType!.type;
    String valuesTableName = _resolveTableName(valuesType);

    try {
      return sqlRepositoryAdapter
          .doSelectRelationship(op, field, oId, valuesTableName, (sel) {
        var valuesIds = sel.map((e) => e['target_id']!).cast<E>().toList();
        return valuesIds;
      });
    } catch (e, s) {
      var message = 'selectRelationship[valuesTableName]> '
          'o: $o ; '
          'oId: $oId ; '
          'field: $field ; '
          'fieldType: $fieldType ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  Iterable<dynamic>? _getCachedEntityRelationship<E>(
      dynamic id, String field, TypeInfo fieldType, Transaction? transaction) {
    var cachedEntity = transaction?.getCachedEntityByID(id, type: type);
    if (cachedEntity != null) {
      var fieldValue = entityHandler.getField(cachedEntity, field);
      if (fieldValue != null) {
        var fieldEntityHandler = entityHandler.getEntityHandler(
            type: fieldType.isListEntity
                ? fieldType.listEntityType!.type
                : fieldType.type);

        if (fieldEntityHandler != null) {
          if (fieldValue is Iterable) {
            var fieldIds =
                fieldValue.map((e) => fieldEntityHandler.getID(e)).toList();
            return fieldIds;
          } else {
            var fieldId = fieldEntityHandler.getID(fieldValue);
            return [fieldId];
          }
        }
      }
    }

    return null;
  }

  Map<dynamic, List<dynamic>>? _getCachedEntitiesRelationships<E>(
      List<dynamic> ids,
      String field,
      TypeInfo fieldType,
      Transaction? transaction) {
    if (transaction == null) return null;

    var cachedEntities = transaction.getCachedEntitiesByIDs(ids,
        type: type, removeCachedIDs: true);

    if (cachedEntities != null && cachedEntities.isNotEmpty) {
      var fieldEntityHandler = entityHandler.getEntityHandler(
          type: fieldType.isListEntity
              ? fieldType.listEntityType!.type
              : fieldType.type);

      if (fieldEntityHandler == null) return null;

      var relationshipEntries = cachedEntities.entries.map((e) {
        var id = e.key;
        var entity = e.value;

        var fieldValue = entityHandler.getField(entity as dynamic, field);

        if (fieldValue != null) {
          if (fieldValue is Iterable) {
            var fieldIds =
                fieldValue.map((e) => fieldEntityHandler.getID(e)).toList();
            return MapEntry(id, fieldIds);
          } else {
            var fieldId = fieldEntityHandler.getID(fieldValue);
            return MapEntry(id, [fieldId]);
          }
        }

        return null;
      }).whereNotNull();

      var relationships = Map.fromEntries(relationshipEntries);

      if (relationships.isNotEmpty) {
        return relationships;
      }
    }

    return null;
  }

  @override
  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
      List<O>? os, String field,
      {List<dynamic>? oIds, TypeInfo? fieldType, Transaction? transaction}) {
    oIds ??= os!
        .map((o) => getID(o, entityHandler: entityHandler)! as Object)
        .toList();

    fieldType ??= entityHandler.getFieldType(os?.first, field)!;

    if (oIds.isEmpty) {
      return <dynamic, Iterable<dynamic>>{};
    } else if (oIds.length == 1) {
      var id = oIds.first;

      return selectRelationship(null, field,
              oId: id, fieldType: fieldType, transaction: transaction)
          .resolveMapped((targetIds) {
        return <dynamic, Iterable<dynamic>>{
          id: targetIds is List ? targetIds : targetIds.toList()
        };
      });
    }

    var oIdsOrig = oIds.toList(growable: false);

    var cachedRelationships =
        _getCachedEntitiesRelationships(oIds, field, fieldType, transaction);

    if (cachedRelationships != null && oIds.isEmpty) {
      return cachedRelationships;
    }

    var op =
        TransactionOperationSelectRelationships(name, os ?? oIds, transaction);

    var valuesType = fieldType.listEntityType!.type;
    String valuesTableName = _resolveTableName(valuesType);

    try {
      return sqlRepositoryAdapter
          .doSelectRelationships(op, field, oIds, valuesTableName, (sel) {
        var relationships = sel.groupListsBy((e) => e['source_id']!).map(
            (id, l) => MapEntry(id, l.map((m) => m['target_id']).toList()));

        if (cachedRelationships != null && cachedRelationships.isNotEmpty) {
          relationships = Map<dynamic, List<dynamic>>.fromEntries(oIdsOrig.map(
              (id) => MapEntry<dynamic, List<dynamic>>(
                  id,
                  relationships[id] ??
                      cachedRelationships[id] as List<dynamic>)));
        }

        return relationships;
      });
    } catch (e, s) {
      var message = 'selectRelationships> '
          'os: $os ; '
          'oIds: $oIds ; '
          'field: $field ; '
          'fieldType: $fieldType ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  String _resolveTableName(Type type) {
    var repositoryAdapter =
        sqlRepositoryAdapter.databaseAdapter.getRepositoryAdapterByType(type);
    if (repositoryAdapter == null) {
      throw StateError("Can't resolve `SQLRepositoryAdapter` for type: $type");
    }

    return repositoryAdapter.tableName;
  }

  EntityHandler<E> _resolveEntityHandler<E>(Type type) {
    var entityRepository = entityHandler.getEntityRepositoryByType(type,
        entityRepositoryProvider: provider,
        entityHandlerProvider: entityHandler.provider);

    var entityHandler2 = entityRepository?.entityHandler;
    entityHandler2 ??= entityHandler.getEntityHandler(type: type);

    if (entityHandler2 == null) {
      throw StateError("Can't resolve EntityHandler for type: $type");
    }

    return entityHandler2 as EntityHandler<E>;
  }

  EntityRepository<E>? _resolveEntityRepository<E extends Object>(Type type) {
    var entityRepository = entityHandler.getEntityRepositoryByType(type,
        entityRepositoryProvider: provider,
        entityHandlerProvider: entityHandler.provider);
    if (entityRepository != null) {
      return entityRepository as EntityRepository<E>;
    }

    var typeEntityHandler = entityHandler.getEntityHandler(type: type);

    if (typeEntityHandler != null) {
      entityRepository = typeEntityHandler.getEntityRepositoryByType(type,
          entityRepositoryProvider: provider,
          entityHandlerProvider: entityHandler.provider);
      if (entityRepository != null) {
        return entityRepository as EntityRepository<E>;
      }
    }

    return null;
  }

  @override
  FutureOr<Iterable<dynamic>> storeAll(Iterable<O> os,
      {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew();

    var result = os.map((o) => store(o, transaction: transaction)).resolveAll();

    return result;
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var op = TransactionOperationDelete(name, matcher, transaction);

    try {
      return sqlRepositoryAdapter.doDelete(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters, preFinish: (results) {
        return _resolveEntities(op.transaction, results)
            .resolveMapped((entities) {
          untrackEntities(entities, deleted: true);
          return entities;
        });
      });
    } catch (e, s) {
      var message = 'delete> '
          'matcher: $matcher ; '
          'parameters: $parameters ; '
          'positionalParameters: $positionalParameters ; '
          'namedParameters: $namedParameters ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  @override
  String toString() {
    var info = information();
    return '$runtimeType[$name]@${provider.runtimeType}$info';
  }
}

/// Base class for [EntityRepositoryProvider] with [SQLAdapter]s.
abstract class SQLEntityRepositoryProvider<A extends SQLAdapter>
    extends DBEntityRepositoryProvider<A> {
  @override
  FutureOr<A> buildAdapter() => SQLAdapter.fromConfig(
        adapterConfig,
        parentRepositoryProvider: this,
      );

  @override
  List<SQLEntityRepository> buildRepositories(SQLAdapter adapter);

  FutureOr<List<SQLBuilder>> generateCreateTableSQLs() =>
      adapter.resolveMapped((adapter) => adapter.generateCreateTableSQLs());

  FutureOr<String> generateFullCreateTableSQLs(
          {String? title, bool withDate = true}) =>
      adapter.resolveMapped((adapter) => adapter.generateFullCreateTableSQLs(
          title: title, withDate: withDate));
}
