import 'package:async_extension/async_extension.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_entity_adapter_sql.dart';

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

    SQLAdapter.boot();
  }

  static final Map<String, DBAdapterInstantiator> _registeredAdaptersByName =
      <String, DBAdapterInstantiator>{};
  static final Map<Type, DBAdapterInstantiator> _registeredAdaptersByType =
      <Type, DBAdapterInstantiator>{};

  static List<String> get registeredAdaptersNames =>
      _registeredAdaptersByName.keys.toList();

  static List<Type> get registeredAdaptersTypes =>
      _registeredAdaptersByType.keys.toList();

  static void
      registerAdapter<C extends Object, A extends DBRelationalAdapter<C>>(
          List<String> names,
          Type type,
          DBAdapterInstantiator<C, A> adapterInstantiator) {
    for (var name in names) {
      _registeredAdaptersByName[name] = adapterInstantiator;
    }

    _registeredAdaptersByType[type] = adapterInstantiator;

    DBAdapter.registerAdapter(names, type, adapterInstantiator);
  }

  static DBAdapterInstantiator<C, A>? getAdapterInstantiator<C extends Object,
      A extends DBRelationalAdapter<C>>({String? name, Type? type}) {
    if (name == null && type == null) {
      throw ArgumentError(
          'One of the parameters `name` or `type` should NOT be null!');
    }

    if (name != null) {
      var adapter = _registeredAdaptersByName[name];
      if (adapter is DBAdapterInstantiator<C, A>) {
        return adapter;
      }
    }

    if (type != null) {
      var adapter = _registeredAdaptersByType[type];
      if (adapter is DBAdapterInstantiator<C, A>) {
        return adapter;
      }
    }

    return null;
  }

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C extends Object,
              A extends DBRelationalAdapter<C>>(Map<String, dynamic> config) =>
          DBAdapter.getAdapterInstantiatorsFromConfigImpl<C, A>(
              config, registeredAdaptersNames, getAdapterInstantiator);

  DBRelationalAdapter(
      int minConnections, int maxConnections, DBAdapterCapability capability,
      {EntityRepositoryProvider? parentRepositoryProvider,
      Object? populateSource,
      String? workingPath})
      : super(minConnections, maxConnections, capability,
            parentRepositoryProvider: parentRepositoryProvider,
            populateSource: populateSource,
            workingPath: workingPath) {
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

  FutureOr<R> doSelect<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish});

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
      DBRelationalAdapter databaseAdapter, String name,
      {String? tableName, Type? type})
      : super(databaseAdapter, name, tableName: tableName, type: type);

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
