import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_logging.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('DBRelationalAdapter')..registerAsDbLogger();

/// Base class for Relational DB adapters.
///
/// A [DBRelationalAdapter] implementation is responsible to connect to the database and
/// perform operations.
///
/// All [DBRelationalAdapter]s comes with a built-in connection pool.
abstract class DBRelationalAdapter<C extends Object> extends DBAdapter<C> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBAdapter.boot();
    DBSQLAdapter.boot();
  }

  static final DBAdapterRegister<Object, DBRelationalAdapter<Object>>
      adapterRegister = DBAdapter.adapterRegister.createRegister();

  static List<String> get registeredAdaptersNames =>
      adapterRegister.registeredAdaptersNames;

  static List<Type> get registeredAdaptersTypes =>
      adapterRegister.registeredAdaptersTypes;

  static void
      registerAdapter<C extends Object, A extends DBRelationalAdapter<C>>(
          List<String> names,
          Type type,
          DBAdapterInstantiator<C, A> adapterInstantiator) {
    boot();
    adapterRegister.registerAdapter(names, type, adapterInstantiator);
  }

  static DBAdapterInstantiator<C, A>? getAdapterInstantiator<C extends Object,
          A extends DBRelationalAdapter<C>>({String? name, Type? type}) =>
      adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C extends Object,
              A extends DBRelationalAdapter<C>>(Map<String, dynamic> config) =>
          adapterRegister.getAdapterInstantiatorsFromConfig<C, A>(config);

  DBRelationalAdapter(
      super.name, super.minConnections, super.maxConnections, super.capability,
      {super.parentRepositoryProvider,
      super.populateSource,
      super.populateSourceVariables,
      super.workingPath}) {
    boot();
  }

  static FutureOr<A>
      fromConfig<C extends Object, A extends DBRelationalAdapter<C>>(
          Map<String, dynamic> config,
          {int minConnections = 1,
          int maxConnections = 3,
          EntityRepositoryProvider? parentRepositoryProvider,
          String? workingPath}) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
          "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}");
    }

    return DBAdapter.instantiateAdaptor<Object, DBRelationalAdapter<Object>>(
            instantiators, config,
            minConnections: minConnections,
            maxConnections: maxConnections,
            parentRepositoryProvider: parentRepositoryProvider,
            workingPath: workingPath)
        .resolveMapped((adapter) => adapter as A);
  }

  @override
  DBRelationalRepositoryAdapter<O>? createRepositoryAdapter<O>(String name,
          {String? tableName, Type? type}) =>
      super.createRepositoryAdapter<O>(name, tableName: tableName, type: type)
          as DBRelationalRepositoryAdapter<O>?;

  List<I> parseIDs<I extends Object>(Iterable<dynamic> ids) {
    var idParser = TypeParser.parserFor<I>(type: I);
    if (idParser != null) {
      return ids.map(idParser).nonNulls.toList();
    } else {
      return ids.whereType<I>().toList();
    }
  }

  FutureOr<R> doSelect<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish});

  FutureOr<List<I>> doSelectIDsBy<I extends Object>(TransactionOperation op,
      String entityName, String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit});

  FutureOr<bool> doInsertRelationship(
      TransactionOperation op,
      String entityName,
      String table,
      String field,
      dynamic id,
      String otherTableName,
      List otherIds,
      [PreFinishDBOperation<bool, bool>? preFinish]);

  FutureOr<R> doSelectRelationship<R>(
      TransactionOperation op,
      String entityName,
      String table,
      String field,
      dynamic id,
      String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]);

  FutureOr<R> doSelectRelationships<R>(
      TransactionOperation op,
      String entityName,
      String table,
      String field,
      List<dynamic> ids,
      String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]);
}

/// An adapter for [EntityRepository] and [DBRelationalAdapter].
class DBRelationalRepositoryAdapter<O> extends DBRepositoryAdapter<O> {
  @override
  DBRelationalAdapter get databaseAdapter =>
      super.databaseAdapter as DBRelationalAdapter;

  DBRelationalRepositoryAdapter(
      DBRelationalAdapter super.databaseAdapter, super.name,
      {super.tableName, super.type});

  FutureOr<R> doSelect<R>(TransactionOperation op, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit,
          PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>?
              preFinish}) =>
      databaseAdapter.doSelect<R>(op, name, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit,
          preFinish: preFinish);

  FutureOr<List<I>> doSelectIDsBy<I extends Object>(
          TransactionOperation op, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit}) =>
      databaseAdapter.doSelectIDsBy<I>(op, name, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);

  FutureOr<bool> doInsertRelationship(TransactionOperation op, String field,
          dynamic id, String otherTableName, List otherIds,
          [PreFinishDBOperation<bool, bool>? preFinish]) =>
      databaseAdapter.doInsertRelationship(
          op, name, tableName, field, id, otherTableName, otherIds, preFinish);

  FutureOr<R> doSelectRelationship<R>(TransactionOperation op, String field,
          dynamic id, String otherTableName,
          [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>?
              preFinish]) =>
      databaseAdapter.doSelectRelationship<R>(
          op, name, tableName, field, id, otherTableName, preFinish);

  FutureOr<R> doSelectRelationships<R>(TransactionOperation op, String field,
          List<dynamic> ids, String otherTableName,
          [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>?
              preFinish]) =>
      databaseAdapter.doSelectRelationships<R>(
          op, name, tableName, field, ids, otherTableName, preFinish);

  @override
  String toString() =>
      'DBRelRepositoryAdapter{name: $name, tableName: $tableName, type: $type}';
}

class DBRelationalEntityRepository<O extends Object>
    extends DBEntityRepository<O> {
  @override
  DBRelationalRepositoryAdapter<O> get repositoryAdapter =>
      super.repositoryAdapter as DBRelationalRepositoryAdapter<O>;

  DBRelationalEntityRepository(
      DBRelationalAdapter super.adapter, super.name, super.entityHandler,
      {DBRelationalRepositoryAdapter<O>? super.repositoryAdapter, super.type});

  @override
  FutureOr<dynamic> ensureStored(o,
      {Transaction? transaction, TransactionOperation? operation}) {
    checkNotClosed();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null || entityHasChangedFields(o)) {
      return _ensureStoredImpl(o, transaction, operation);
    } else {
      if (isTrackingEntity(o)) {
        return ensureReferencesStored(o, transaction: transaction)
            .resolveWithValue(id);
      }

      return existsID(id, transaction: transaction).resolveMapped((exists) {
        if (!exists) {
          return _ensureStoredImpl(o, transaction, operation);
        } else {
          return ensureReferencesStored(o, transaction: transaction)
              .resolveWithValue(id);
        }
      });
    }
  }

  FutureOr<dynamic> _ensureStoredImpl(
      o, Transaction? transaction, TransactionOperation? parentOperation) {
    if (transaction != null) {
      var storeOp =
          transaction.firstOperationWithEntity<TransactionOperationStore>(o);

      if (storeOp != null) {
        return storeOp.waitFinish(parentOperation: parentOperation).then((ok) {
          var id = getEntityID(storeOp.entity) ?? getEntityID(o);
          if (id == null && !ok) {
            throw RecursiveRelationshipLoopError.fromTransaction(
                transaction, storeOp, parentOperation, o);
          }
          return id;
        });
      }
    }

    return _storeImpl(o, transaction, parentOperation);
  }

  Map<String, TypeInfo>? _nonPrimitiveFields;

  Map<String, TypeInfo> _getNonPrimitiveFields(O o) =>
      _nonPrimitiveFields ??= entityHandler
          .fieldsNames(o)
          .map((fieldName) {
            var fieldType = entityHandler.getFieldType(o, fieldName)!;
            if (fieldType.isPrimitiveType) return null;
            return MapEntry(fieldName, fieldType);
          })
          .nonNulls
          .toMapFromEntries();

  @override
  FutureOr<bool> ensureReferencesStored(O o,
      {Transaction? transaction, TransactionOperation? operation}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew(autoCommit: true);

    var nonPrimitiveFields = _getNonPrimitiveFields(o);

    var futures = nonPrimitiveFields.entries
        .map((entry) {
          final fieldName = entry.key;
          final fieldType = entry.value;

          var fieldValue = entityHandler.getField(o, fieldName) as Object?;
          if (fieldValue == null) return null;

          Object? value = fieldValue;

          if (value is EntityReferenceList) {
            if (value.isNull) {
              return null;
            } else {
              value = value.entitiesOrIDs;
            }
          }

          if (value is List &&
              ((fieldType.isList && fieldType.hasArguments) ||
                  fieldType.isEntityReferenceListType)) {
            var elementType = fieldType.arguments.first;
            if (!EntityHandler.isValidEntityType(elementType.type)) return null;

            var elementRepository =
                provider.getEntityRepositoryByTypeInfo(elementType);
            if (elementRepository == null) return null;

            var futures = value.map((e) {
              if (!elementRepository.isOfEntityType(e)) return e;
              return elementRepository.ensureStored(e,
                  transaction: transaction, operation: operation);
            }).toList();

            return futures.resolveAll().resolveMapped((ids) {
              if (fieldValue is EntityReferenceList) {
                fieldValue.updateIDsFromEntities();
              }
              return ids;
            });
          } else {
            var entityType = fieldType.entityType;
            if (entityType == null) return null;

            var entity = value;

            if (value is EntityReference) {
              if (value.isNull) {
                return null;
              } else if (value.hasEntity) {
                entity = value.entity;
              } else {
                return value.id;
              }
            }

            var repository =
                provider.getEntityRepository(type: entityType, obj: entity);
            if (repository == null) return null;

            var stored = repository.ensureStored(entity as dynamic,
                transaction: transaction, operation: operation);
            return stored;
          }
        })
        .whereNotNullSync()
        .toList(growable: false);

    return futures.resolveAllWithValue(true);
  }

  @override
  FutureOr<Iterable<I>> selectIDsBy<I extends Object>(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    checkNotClosed();

    var op = TransactionOperationSelect(name, false, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doSelectIDsBy(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);
    } catch (e, s) {
      var message = 'selectIDsBy> '
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
      int? limit,
      EntityResolutionRules? resolutionRules}) {
    checkNotClosed();

    final resolutionRulesResolved =
        resolveEntityResolutionRules(resolutionRules);

    var canPropagate = hasReferencedEntities(resolutionRulesResolved);

    var op = TransactionOperationSelect(
        name, canPropagate, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doSelect(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit, preFinish: (results) {
        return resolveEntities(op.transaction, results,
            resolutionRules: resolutionRulesResolved);
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
  FutureOr<Iterable<O>> selectAll(
          {Transaction? transaction,
          int? limit,
          EntityResolutionRules? resolutionRules}) =>
      select(ConditionANY(), limit: limit, resolutionRules: resolutionRules);

  @override
  bool isStored(O o, {Transaction? transaction}) {
    var id = entityHandler.getID(o);
    return id != null;
  }

  @override
  void checkEntityFields(O o) {
    entityHandler.checkAllFieldsValues(o);

    repositoryAdapter.checkEntityFields(o, entityHandler);
  }

  @override
  FutureOr<dynamic> store(O o, {Transaction? transaction}) =>
      _storeImpl(o, transaction, null);

  FutureOr<dynamic> _storeImpl(
      O o, Transaction? transaction, TransactionOperation? parentOperation) {
    checkNotClosed();

    checkEntityFields(o);

    if (isStored(o, transaction: transaction)) {
      return _update(o, transaction, parentOperation, true);
    }

    var canPropagate = hasReferencedEntities(
        resolveEntityResolutionRules(EntityResolutionRules.instanceAllEager));

    var op = TransactionOperationStore(name, canPropagate, operationExecutor, o,
        transaction: transaction, parentOperation: parentOperation);

    try {
      return ensureReferencesStored(o,
              transaction: op.transaction, operation: op)
          .resolveWith(() {
        var idFieldsName = entityHandler.idFieldName(o);
        var fields = entityHandler.getFields(o);

        return repositoryAdapter.doInsert(op, o, fields,
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
          'transaction: ${op.transaction} ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  FutureOr<dynamic> _update(O o, Transaction? transaction,
      TransactionOperation? parentOperation, bool allowAutoInsert) {
    var canPropagate = hasReferencedEntities(
        resolveEntityResolutionRules(EntityResolutionRules.instanceAllEager));

    var op = TransactionOperationUpdate(
        name, canPropagate, operationExecutor, o,
        transaction: transaction, parentOperation: parentOperation);

    return ensureReferencesStored(o, transaction: op.transaction)
        .resolveWith(() {
      var idFieldsName = entityHandler.idFieldName(o);
      var id = entityHandler.getID(o);
      var fields = entityHandler.getFields(o);

      var changedFields = getEntityChangedFields(o);
      if (changedFields != null) {
        if (changedFields.isEmpty) {
          return _ensureRelationshipsStored(o, op.transaction, changedFields)
              .resolveWith(() {
            trackEntity(o);
            return op.finish(id);
          });
        }

        fields.removeWhere((key, value) => !changedFields.contains(key));
      }

      return repositoryAdapter.doUpdate(op, o, id, fields,
          idFieldName: idFieldsName,
          allowAutoInsert: allowAutoInsert, preFinish: (id) {
        return _ensureRelationshipsStored(o, op.transaction, changedFields)
            .resolveWith(() {
          trackEntity(o);
          return id; // pre-finish
        });
      });
    });
  }

  FutureOr<bool> _ensureRelationshipsStored(O o, Transaction? transaction,
      [List<String>? changedFields]) {
    var fieldsListEntity = entityHandler.fieldsWithTypeListEntityOrReference(o);
    if (fieldsListEntity.isEmpty) return false;

    if (changedFields != null) {
      fieldsListEntity = Map<String, TypeInfo>.fromEntries(
          fieldsListEntity.entries.where((e) => changedFields.contains(e.key)));
    }

    var ret = fieldsListEntity.entries.map((e) {
      var field = e.key;
      var fieldType = e.value;
      var values = entityHandler.getField(o, field);
      if (values is EntityReferenceList) {
        values = values.entitiesOrIDs;
      }

      var list = values is Iterable ? values.asList : [values];
      var listNotNull = list.nonNulls.toList();

      return setRelationship(o, field, listNotNull as dynamic,
          fieldType: fieldType, transaction: transaction);
    }).resolveAll();

    return ret.resolveWithValue(true);
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    fieldType ??= entityHandler.getFieldType(o, field)!;

    var op = TransactionOperationStoreRelationship(
        name, operationExecutor, o, values,
        transaction: transaction);

    var valuesType = fieldType.arguments0!.type;
    String valuesTableName = _resolveTableName(valuesType);
    var valuesEntityHandler = _resolveEntityHandler(valuesType);

    var oId = entityHandler.getID(o);

    var othersIds = values
        .map((e) => valuesEntityHandler.isEntityInstance(e)
            ? valuesEntityHandler.getID(e)
            : e)
        .toList();

    try {
      return repositoryAdapter.doInsertRelationship(
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

    var op = TransactionOperationSelectRelationship(
        name, operationExecutor, o ?? oId,
        transaction: transaction);

    var valuesType = fieldType.arguments0!.type;
    String valuesTableName = _resolveTableName(valuesType);

    try {
      return repositoryAdapter
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
            type: fieldType.isListEntityOrReference
                ? fieldType.listEntityOrReferenceType!.type
                : fieldType.type);

        if (fieldValue is EntityReferenceBase) {
          fieldValue = fieldValue.currentValue;
        }

        if (fieldEntityHandler != null) {
          if (fieldValue is Iterable) {
            var fieldIds = fieldValue
                .map((Object? e) => fieldEntityHandler.isEntityInstance(e)
                    ? fieldEntityHandler.getID(e)
                    : (e.isEntityIDType ? e : null))
                .toList();
            return fieldIds;
          } else {
            var fieldId = fieldEntityHandler.isEntityInstance(fieldValue)
                ? fieldEntityHandler.getID(fieldValue)
                : ((fieldValue as Object?).isEntityIDType ? fieldValue : null);
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
          type: fieldType.isListEntityOrReference
              ? fieldType.arguments0!.type
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
          } else if (fieldValue is EntityReferenceList) {
            var fieldIds = fieldValue.entities
                    ?.map((e) => fieldEntityHandler.getID(e))
                    .toList() ??
                [];
            return MapEntry(id, fieldIds);
          } else if (fieldValue is EntityReference) {
            var fieldId = fieldEntityHandler.getID(fieldValue.entity);
            return MapEntry(id, [fieldId]);
          } else {
            var fieldId = fieldEntityHandler.getID(fieldValue);
            return MapEntry(id, [fieldId]);
          }
        }

        return null;
      }).nonNulls;

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

    var valuesType = fieldType.arguments0!.type;
    String valuesTableName = _resolveTableName(valuesType);

    var op = TransactionOperationSelectRelationships(
        name, valuesTableName, operationExecutor, os ?? oIds,
        transaction: transaction);

    try {
      return repositoryAdapter
          .doSelectRelationships(op, field, oIds, valuesTableName, (sel) {
        var relationships = sel.groupListsBy((e) => e['source_id']!).map(
            (id, l) => MapEntry(id, l.map((m) => m['target_id']).toList()));

        if (cachedRelationships != null && cachedRelationships.isNotEmpty) {
          relationships = Map<dynamic, List<dynamic>>.fromEntries(oIdsOrig.map(
            (id) => MapEntry<dynamic, List<dynamic>>(
                id, relationships[id] ?? cachedRelationships[id] ?? []),
          ));
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
    var repository =
        repositoryAdapter.databaseAdapter.getRepositoryAdapterByType(type);
    if (repository == null) {
      throw StateError("Can't resolve `SQLRepositoryAdapter` for type: $type");
    }

    return repository.tableName;
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

  @override
  String toString() {
    var info = information();
    return '$runtimeTypeNameUnsafe[$name]@${provider.runtimeTypeNameUnsafe}$info';
  }
}

/// Base class for [EntityRepositoryProvider] with [DBRelationalAdapter]s.
abstract class DBRelationalEntityRepositoryProvider<
    A extends DBRelationalAdapter> extends DBEntityRepositoryProvider {
  @override
  FutureOr<A> buildAdapter() => DBRelationalAdapter.fromConfig(
        adapterConfig,
        parentRepositoryProvider: this,
        workingPath: workingPath,
      );
}
