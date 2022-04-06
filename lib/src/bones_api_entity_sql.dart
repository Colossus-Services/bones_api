import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

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
  void initialize() {
    sqlRepositoryAdapter.ensureInitialized();
  }

  String get dialect => sqlRepositoryAdapter.dialect;

  String get tableName => sqlRepositoryAdapter.tableName;

  @override
  Map<String, dynamic> information() =>
      {'queryType': 'SQL', 'dialect': dialect};

  @override
  FutureOr<dynamic> ensureStored(o, {Transaction? transaction}) {
    checkNotClosed();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null) {
      return store(o, transaction: transaction);
    } else {
      return ensureReferencesStored(o, transaction: transaction)
          .resolveWithValue(id);
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

          if (!EntityHandler.isValidType(fieldType.type)) {
            return null;
          }

          if (value is List && fieldType.isList && fieldType.hasArguments) {
            var elementType = fieldType.arguments.first;
            var elementRepository =
                provider.getEntityRepository(type: elementType.type);
            if (elementRepository == null) return null;

            var futures = value.map((e) {
              return elementRepository.ensureStored(e,
                  transaction: transaction);
            }).toList();
            return futures.resolveAll();
          } else {
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
      Transaction? transaction,
      TransactionOperation? op}) {
    checkNotClosed();

    var op = TransactionOperationCount(null, transaction);

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
          'op: $op > '
          '[ERROR] $e';
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

    var op = TransactionOperationSelect(matcher, transaction);

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
          'op: $op > '
          '[ERROR] $e';
      _log.severe(message, e, s);
      rethrow;
    }
  }

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
          Transaction transaction, FutureOr<List<FutureOr<O>>> entitiesAsync) =>
      entitiesAsync
          .resolveMapped((e) => e.resolveAll().resolveMapped((entities) {
                transaction.cacheEntities<O>(entities, getEntityID);
                return trackEntities(entities);
              }));

  List<FutureOr<O>> _resolveEntitiesSimple(
      Transaction transaction, Iterable<Map<String, dynamic>> results) {
    return results
        .map((e) => entityHandler.createFromMap(e, entityProvider: transaction))
        .toList();
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

    var fieldsEntityRepositories =
        Map.fromEntries(fieldsEntity.entries.map((e) {
      var fieldEntityRepository = _resolveEntityRepository(e.value.type);
      return fieldEntityRepository != null
          ? MapEntry(e.key, fieldEntityRepository)
          : null;
    }).whereNotNull());

    if (fieldsEntityRepositories.isNotEmpty) {
      var fieldsEntitiesAsync = fieldsEntityRepositories.map((field, repo) {
        var fieldValues = resultsList.map((e) => e[field]).toList();
        var fieldValuesUniques = fieldValues.toSet().toList();

        var entitiesAsync =
            repo.selectByIDs(fieldValuesUniques, transaction: transaction);

        var entities = entitiesAsync.resolveMapped((entities) {
          var entries = List<MapEntry<dynamic, Object?>>.generate(
              fieldValuesUniques.length,
              (i) => MapEntry(fieldValuesUniques[i], entities[i]));

          return entries;
        });

        return MapEntry(field, entities);
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
          provider.getEntityRepository(type: targetType)!;

      var retRelationships = Map.fromEntries(ids.map((id) {
        var targetIdsAsync = selectRelationship(null, fieldName,
            oId: id, transaction: transaction, fieldType: fieldType);

        var targetEntities = targetIdsAsync
            .resolveMapped((targetIds) => targetEntityRepository
                .selectByIDs(targetIds.toList(), transaction: transaction))
            .resolveMapped((l) =>
                targetEntityRepository.entityHandler.castList(l, targetType)!);

        return MapEntry(id, targetEntities);
      })).resolveAllValues();

      return retRelationships.resolveMapped((relationships) {
        for (var r in results) {
          var id = r[idFieldName];
          var values = relationships[id];
          r[fieldName] = values;
        }
      }).resolveWithValue(true);
    });
  }

  FutureOr<Map<String, TableRelationshipReference>> _getRelationshipFields(
      Map<String, TypeInfo> fieldsListEntity,
      [FutureOr<TableScheme>? retTableScheme]) {
    retTableScheme ??= sqlRepositoryAdapter.getTableScheme();

    return retTableScheme.resolveMapped((tableScheme) {
      var databaseAdapter = sqlRepositoryAdapter.databaseAdapter;

      var entries = fieldsListEntity.entries.map((e) {
        var targetType = e.value.listEntityType!.type;
        var targetRepositoryAdapter =
            databaseAdapter.getRepositoryAdapterByType(targetType);
        if (targetRepositoryAdapter == null) return null;
        var relationship = tableScheme
            .getTableRelationshipReference(targetRepositoryAdapter.name);
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
  FutureOr<dynamic> store(O o, {Transaction? transaction}) {
    checkNotClosed();

    if (isStored(o, transaction: transaction)) {
      return _update(o, transaction);
    }

    var op = TransactionOperationStore(o, transaction);

    try {
      return ensureReferencesStored(o, transaction: op.transaction)
          .resolveWith(() {
        var idFieldsName = entityHandler.idFieldsName(o);
        var fields = entityHandler.getFields(o);

        return sqlRepositoryAdapter.doInsert(op, o, fields,
            idFieldName: idFieldsName, preFinish: (id) {
          entityHandler.setID(o, id);

          return _ensureRelationshipsStored(o, op.transaction).resolveWith(() {
            trackEntity(o);
            return id;
          });
        });
      });
    } catch (e, s) {
      var message = 'store> '
          'o: $o ; '
          'transaction: $transaction ; '
          'op: $op > '
          '[ERROR] $e';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  FutureOr<dynamic> _update(O o, Transaction? transaction) {
    var op = TransactionOperationUpdate(o, transaction);

    return ensureReferencesStored(o, transaction: op.transaction)
        .resolveWith(() {
      var idFieldsName = entityHandler.idFieldsName(o);
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
          idFieldName: idFieldsName, preFinish: (id) {
        return _ensureRelationshipsStored(o, op.transaction).resolveWith(() {
          trackEntity(o);
          return id;
        });
      });
    });
  }

  FutureOr<bool> _ensureRelationshipsStored(O o, Transaction? transaction) {
    var fieldsListEntity = entityHandler.fieldsWithTypeListEntity(o);
    if (fieldsListEntity.isEmpty) return false;

    var ret = fieldsListEntity.entries.map((e) {
      var values = entityHandler.getField(o, e.key);
      return setRelationship(o, e.key, values,
          fieldType: e.value, transaction: transaction);
    }).resolveAll();

    return ret.resolveWithValue(true);
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    fieldType ??= entityHandler.getFieldType(o, field)!;

    var op = TransactionOperationStoreRelationship(o, values, transaction);

    var valuesType = fieldType.listEntityType!.type;
    String valuesTableName = _resolveTableName(valuesType);
    var valuesEntityHandler = _resolveEntityHandler(valuesType);

    var oId = entityHandler.getID(o);
    var othersIds = values.map((e) => valuesEntityHandler.getID(e)).toList();

    try {
      return sqlRepositoryAdapter.doInsertRelationship(
          op, oId, valuesTableName, othersIds);
    } catch (e, s) {
      var message = 'setRelationship> '
          'o: $o ; '
          'field: $field ; '
          'fieldType: $fieldType ; '
          'values: $values ; '
          'op: $op > '
          '[ERROR] $e';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction}) {
    fieldType ??= entityHandler.getFieldType(o, field)!;

    oId ??= entityHandler.getID(o!);

    var op = TransactionOperationSelectRelationship(o ?? oId, transaction);

    var valuesType = fieldType.listEntityType!.type;
    String valuesTableName = _resolveTableName(valuesType);

    try {
      return sqlRepositoryAdapter.doSelectRelationship(op, oId, valuesTableName,
          (sel) {
        var valuesIds = sel.map((e) => e.values.first).cast<E>().toList();
        return valuesIds;
      });
    } catch (e, s) {
      var message = 'selectRelationship> '
          'o: $o ; '
          'oId: $oId ; '
          'field: $field ; '
          'fieldType: $fieldType ; '
          'op: $op > '
          '[ERROR] $e';
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
    var entityRepository = entityHandler.getEntityRepository(type: type);
    var entityHandler2 = entityRepository?.entityHandler;
    entityHandler2 ??= entityHandler.getEntityHandler(type: type);
    if (entityHandler2 == null) {
      throw StateError("Can't resolve EntityHandler for type: $type");
    }
    return entityHandler2 as EntityHandler<E>;
  }

  EntityRepository<E>? _resolveEntityRepository<E extends Object>(Type type) {
    var entityRepository = entityHandler.getEntityRepository(type: type);
    if (entityRepository != null) {
      return entityRepository as EntityRepository<E>;
    }

    var typeEntityHandler = entityHandler.getEntityHandler(type: type);
    if (typeEntityHandler != null) {
      entityRepository = typeEntityHandler.getEntityRepository(type: type);
      if (entityRepository != null) {
        return entityRepository as EntityRepository<E>;
      }
    }
    return null;
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew();

    var result = os.map((o) => store(o, transaction: transaction)).toList();

    return result;
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var op = TransactionOperationDelete(matcher, transaction);

    try {
      return sqlRepositoryAdapter.doDelete(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters, preFinish: (results) {
        return _resolveEntities(op.transaction, results);
      });
    } catch (e, s) {
      var message = 'delete> '
          'matcher: $matcher ; '
          'parameters: $parameters ; '
          'positionalParameters: $positionalParameters ; '
          'namedParameters: $namedParameters ; '
          'op: $op > '
          '[ERROR] $e';
      _log.severe(message, e, s);
      rethrow;
    }
  }
}
