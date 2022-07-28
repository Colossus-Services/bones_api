import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart' hide IterableIntExtension;
import 'package:logging/logging.dart' as logging;

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter_sql.dart';
import 'bones_api_entity_sql.dart';
import 'bones_api_initializable.dart';
import 'bones_api_mixin.dart';

final _log = logging.Logger('DBAdapter');

typedef PasswordProvider = FutureOr<String> Function(String user);

/// [SQL] wrapper interface.
abstract class SQLWrapper {
  /// The amount of [SQL]s.
  int get sqlsLength;

  /// Returns the main [SQL].
  SQL get mainSQL;

  /// Returns all wrapped [SQL]s.
  Iterable<SQL> get allSQLs;
}

/// Class to wrap multiple [SQL]s.
class MultipleSQL implements SQLWrapper {
  final List<SQL> sqls;

  MultipleSQL(this.sqls);

  @override
  Iterable<SQL> get allSQLs => sqls;

  @override
  SQL get mainSQL => sqls.first;

  @override
  int get sqlsLength => sqls.length;
}

class DBDialect {
  final String name;

  const DBDialect(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DBDialect && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return '$runtimeType{name: $name}';
  }
}

/// [DBAdapter] capabilities.
class DBAdapterCapability {
  /// The dialect of the DB.
  final DBDialect dialect;

  /// `true` if the DB supports transactions.
  final bool transactions;

  /// `true` if the DB supports abortion of transactions.
  final bool transactionAbort;

  /// `true` if the DB fully supports [transactions] and [transactionAbort].
  bool get fullTransaction => transactions && transactionAbort;

  const DBAdapterCapability({
    required this.dialect,
    required this.transactions,
    required this.transactionAbort,
  });
}

typedef DBAdapterInstantiator<C extends Object, A extends DBAdapter<C>>
    = FutureOr<A?> Function(Map<String, dynamic> config,
        {int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider,
        String? workingPath});

typedef PreFinishDBOperation<T, R> = FutureOr<R> Function(T result);

/// Base class for DB adapters.
///
/// A [DBAdapter] implementation is responsible to connect to the database and
/// perform operations.
///
/// All [DBAdapter]s comes with a built-in connection pool.
abstract class DBAdapter<C extends Object> extends SchemeProvider
    with Initializable, Pool<C>, Closable
    implements EntityRepositoryProvider {
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

  static void registerAdapter<C extends Object, A extends DBAdapter<C>>(
      List<String> names,
      Type type,
      DBAdapterInstantiator<C, A> adapterInstantiator) {
    for (var name in names) {
      _registeredAdaptersByName[name] = adapterInstantiator;
    }

    _registeredAdaptersByType[type] = adapterInstantiator;
  }

  static DBAdapterInstantiator<C, A>?
      getAdapterInstantiator<C extends Object, A extends DBAdapter<C>>(
          {String? name, Type? type}) {
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
              A extends SQLAdapter<C>>(Map<String, dynamic> config) =>
          getAdapterInstantiatorsFromConfigImpl<C, A>(
              config, registeredAdaptersNames, getAdapterInstantiator);

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfigImpl<C extends Object,
                  A extends DBAdapter<C>>(
              Map<String, dynamic> config,
              List<String> registeredAdaptersNames,
              DBAdapterInstantiator<C, A>? Function({String? name, Type? type})
                  getAdapterInstantiator) =>
          registeredAdaptersNames
              .where((n) => config.containsKey(n))
              .map((n) {
                var instantiator = getAdapterInstantiator(name: n);
                if (instantiator == null) return null;
                var conf = config[n] ?? <String, dynamic>{};
                if (conf is! Map) return null;
                return MapEntry<DBAdapterInstantiator<C, A>,
                        Map<String, dynamic>>(
                    instantiator,
                    conf.map((key, value) => MapEntry<String, dynamic>(
                        key.toString(), value as dynamic)));
              })
              .whereNotNull()
              .toList()
            ..sort((a, b) => a.value.length.compareTo(b.value.length));

  /// The minimum number of connections in the pool of this adapter.
  final int minConnections;

  /// The maximum number of connections in the pool of this adapter.
  final int maxConnections;

  /// The [DBAdapter] capability.
  final DBAdapterCapability capability;

  /// The DB dialect of this adapter.
  DBDialect get dialect => capability.dialect;

  /// The DB dialect name of this adapter.
  String get dialectName => capability.dialect.name;

  final EntityRepositoryProvider? parentRepositoryProvider;

  DBAdapter(this.minConnections, this.maxConnections, this.capability,
      {this.parentRepositoryProvider,
      Object? populateSource,
      String? workingPath})
      : _populateSource = populateSource,
        _workingPath = workingPath {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<A> fromConfig<C extends Object, A extends DBAdapter<C>>(
      Map<String, dynamic> config,
      {int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig(config);

    if (instantiators.isEmpty) {
      throw StateError(
          "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}");
    }

    return instantiateAdaptor<Object, DBAdapter<Object>>(instantiators, config,
            minConnections: minConnections,
            maxConnections: maxConnections,
            parentRepositoryProvider: parentRepositoryProvider,
            workingPath: workingPath)
        .resolveMapped((adapter) => adapter as A);
  }

  static FutureOr<A>
      instantiateAdaptor<C extends Object, A extends DBAdapter<C>>(
          List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
              instantiators,
          Map<String, dynamic> config,
          {int minConnections = 1,
          int maxConnections = 3,
          EntityRepositoryProvider? parentRepositoryProvider,
          String? workingPath}) {
    if (instantiators.isEmpty) {
      throw StateError(
          "No `$A` instantiator for `config` keys: ${config.keys.toList()}");
    }

    var asyncInstantiators = <Future<A>>[];

    for (var e in instantiators) {
      var f = e.key;
      var conf = e.value;

      var ret = f(conf,
          minConnections: minConnections,
          maxConnections: maxConnections,
          parentRepositoryProvider: parentRepositoryProvider,
          workingPath: workingPath);

      if (ret == null) {
        continue;
      } else if (ret is A) {
        return ret;
      } else if (ret is Future<A>) {
        asyncInstantiators.add(ret);
      }
    }

    if (asyncInstantiators.isNotEmpty) {
      return asyncInstantiators.resolveAll().then((l) {
        for (var e in l) {
          return e;
        }

        throw StateError(
            "Can't async instantiate an `$A` for `config`: $config");
      });
    }

    throw StateError("Can't instantiate an `$A` for `config`: $config");
  }

  @override
  FutureOr<InitializationResult> initialize() => populateImpl();

  @override
  bool close() {
    if (!(super.close() as bool)) return false;

    clearPool();
    return true;
  }

  Map<String, dynamic> information({bool extended = false, String? table}) =>
      <String, dynamic>{};

  final String? _workingPath;

  Object? _populateSource;

  FutureOr<InitializationResult> populateImpl() =>
      _populateSourceImpl(_populateSource);

  FutureOr<InitializationResult> _populateSourceImpl(Object? populateSource) {
    _populateSource = null;

    if (populateSource == null) {
      return InitializationResult.ok(this, dependencies: [
        if (parentRepositoryProvider != null) parentRepositoryProvider!
      ]);
    }

    return populateFromSource(populateSource, workingPath: _workingPath)
        .resolveMapped((val) {
      var result = InitializationResult.ok(this, dependencies: [
        if (parentRepositoryProvider != null) parentRepositoryProvider!,
        ...entityRepositories,
      ]);

      return result;
    });
  }

  @override
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type}) {
    if (id == null || type == null) return null;

    var entityRepository = getEntityRepositoryByType(type);
    if (entityRepository != null) {
      return entityRepository.selectByID(id).resolveMapped((o) => o as O?);
    }

    var enumReflection = ReflectionFactory().getRegisterEnumReflection(type);
    if (enumReflection != null) {
      return null;
    }

    _log.warning(
        "Can't get entity by ID($id). Can't find `EntityRepository` for type: $type");

    return null;
  }

  @override
  Map<EntityRepository, Object> get registeredEntityRepositoriesInformation =>
      _entityRepositories.values
          .map((e) => MapEntry(e, e.information(extended: true)))
          .toMapFromEntries();

  FutureOr<Map<EntityRepository, String>> getEntityRepositoresTables() =>
      entityRepositories
          .map((r) => MapEntry<EntityRepository, FutureOr<String>>(
              r, getTableForEntityRepository(r)))
          .toMapFromEntries()
          .resolveAllValues();

  @override
  FutureOr<String?> getTableForType(TypeInfo type) {
    if (type.hasArguments) {
      if (type.isMap) {
        type = type.arguments[1];
      } else if (type.isIterable || type.isList || type.isSet) {
        type = type.arguments[0];
      }
    }

    var entityType = type.type;

    var entityRepository = getEntityRepositoryByType(entityType);

    if (entityRepository != null) {
      return getTableForEntityRepository(entityRepository);
    } else {
      return null;
    }
  }

  EntityRepository? _geAdapterEntityRepository(
      {String? entityName, String? tableName, Type? entityType}) {
    EntityRepository? entityRepository;

    if (entityName != null) {
      entityRepository = getEntityRepository(name: entityName);
    }

    if (entityRepository == null &&
        tableName != null &&
        tableName != entityName) {
      entityRepository = getEntityRepository(tableName: tableName);
    }

    if (entityRepository == null && entityType != null) {
      entityRepository = getEntityRepositoryByType(entityType);
    }

    return entityRepository;
  }

  @override
  FutureOr<TypeInfo?> getFieldType(String field,
      {String? entityName, String? tableName, Type? entityType}) {
    var entityRepository = _geAdapterEntityRepository(
        entityName: entityName, tableName: tableName, entityType: entityType);

    if (entityRepository != null) {
      var type = entityRepository.entityHandler.getFieldType(null, field);
      return type;
    }

    return null;
  }

  @override
  FutureOr<Object?> getEntityID(Object entity,
      {String? entityName,
      String? tableName,
      Type? entityType,
      EntityHandler? entityHandler}) {
    if (entity is num) {
      return entity;
    }

    entityType ??= entity.runtimeType;

    entityHandler ??= getEntityHandler(
        entityName: entityName, tableName: tableName, entityType: entityType);

    if (entityHandler == null) return null;

    if (entity is Map) {
      var idFieldsName = entityHandler.idFieldName();
      return entity[idFieldsName];
    } else {
      return entityHandler.getID(entity);
    }
  }

  EntityHandler<T>? getEntityHandler<T>(
      {String? entityName, String? tableName, Type? entityType}) {
    var entityRepository = _geAdapterEntityRepository(
        entityName: entityName, tableName: tableName, entityType: entityType);

    var entityHandler = entityRepository?.entityHandler;
    return entityHandler as EntityHandler<T>?;
  }

  FutureOr<int> doCount(
      TransactionOperation op, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<int, int>? preFinish});

  FutureOr<R> doSelect<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish});

  FutureOr<dynamic> doInsert<O>(TransactionOperation op, String entityName,
      String table, O o, Map<String, dynamic> fields,
      {String? idFieldName, PreFinishDBOperation<dynamic, dynamic>? preFinish});

  FutureOr<dynamic> doUpdate<O>(TransactionOperation op, String entityName,
      String table, O o, Object id, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishDBOperation<dynamic, dynamic>? preFinish,
      bool allowAutoInsert = false});

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

  FutureOr<R> doDelete<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish});

  FutureOr<C> openTransaction(Transaction transaction);

  FutureOr<bool> cancelTransaction(Transaction transaction, C connection,
      Object? error, StackTrace? stackTrace);

  bool get callCloseTransactionRequired;

  FutureOr<void> closeTransaction(Transaction transaction, C? connection);

  static int temporaryTableIdCount = 0;

  static String createTemporaryTableName(String prefix) {
    var id = ++temporaryTableIdCount;
    var seed = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${seed}_$id';
  }

  /// Returns the URL of the [connection].
  String getConnectionURL(C connection);

  /// Creates a connection [C] for this adapte
  FutureOr<C> createConnection();

  /// Returns `true` if [connection] is valid for usage.
  FutureOr<bool> isConnectionValid(C connection);

  FutureOr<bool> closeConnection(C connection);

  /// Checks the connections of the pool. Defaults: calls [removeInvalidElementsFromPool].
  FutureOr<bool> checkConnections() => removeInvalidElementsFromPool();

  /// Defaults: calls [isConnectionValid].
  @override
  FutureOr<bool> isPoolElementValid(C o) => isConnectionValid(o);

  /// Checks the pool connections and limits.
  @override
  FutureOr<bool> checkPool() =>
      checkPoolSize(minConnections, maxConnections, 30000);

  @override
  int get poolSizeDesiredLimit => maxConnections;

  /// Defaults: calls [createConnection].
  @override
  FutureOr<C?> createPoolElement() {
    super.createPoolElement();

    if (poolSize < maxConnections) {
      return createConnection();
    } else {
      return null;
    }
  }

  /// Defaults: calls [closeConnection].
  @override
  FutureOr<bool> closePoolElement(C o) {
    super.closePoolElement(o);
    return closeConnection(o);
  }

  final Map<String, DBRepositoryAdapter> _repositoriesAdapters =
      <String, DBRepositoryAdapter>{};

  DBRepositoryAdapter<O>? createRepositoryAdapter<O>(String name,
      {String? tableName, Type? type}) {
    if (isClosed) {
      return null;
    }

    return _repositoriesAdapters.putIfAbsent(
            name, () => instantiateRepositoryAdapter<O>(name, tableName, type))
        as DBRepositoryAdapter<O>;
  }

  DBRepositoryAdapter<O> instantiateRepositoryAdapter<O>(
      String name, String? tableName, Type? type) {
    return DBRepositoryAdapter<O>(this, name, tableName: tableName, type: type);
  }

  DBRepositoryAdapter<O>? getRepositoryAdapterByName<O>(
    String name,
  ) {
    if (isClosed) return null;
    return _repositoriesAdapters[name] as DBRepositoryAdapter<O>?;
  }

  DBRepositoryAdapter<O>? getRepositoryAdapterByType<O>(Type type) {
    if (isClosed) return null;
    return _repositoriesAdapters.values.firstWhereOrNull((e) => e.type == type)
        as DBRepositoryAdapter<O>?;
  }

  DBRepositoryAdapter<O>? getRepositoryAdapterByTableName<O>(String tableName) {
    if (isClosed) return null;
    return _repositoriesAdapters.values
            .firstWhereOrNull((e) => e.tableName == tableName)
        as DBRepositoryAdapter<O>?;
  }

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  List<EntityRepository> get entityRepositories =>
      _entityRepositories.values.toList();

  @override
  void registerEntityRepository<O extends Object>(
      EntityRepository<O> entityRepository) {
    checkNotClosed();

    _entityRepositories[entityRepository.type] = entityRepository;
  }

  @override
  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  bool _callingGetEntityRepository = false;

  @override
  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName}) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    try {
      return _getEntityRepositoryImpl<O>(
              obj: obj, type: type, name: name, tableName: tableName) ??
          EntityRepositoryProvider.globalProvider
              .getEntityRepository<O>(obj: obj, type: type, name: name);
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName}) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[O];
      if (entityRepository != null && !entityRepository.isClosed) {
        return entityRepository as EntityRepository<O>;
      }

      if (obj != null) {
        entityRepository = _entityRepositories[obj.runtimeType];
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }

      if (type != null) {
        entityRepository = _entityRepositories[type];
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }

      if (name != null) {
        var nameSimplified = EntityAccessor.simplifiedName(name);

        entityRepository = _entityRepositories.values
            .where((e) => e.name == name || e.nameSimplified == nameSimplified)
            .firstOrNull;
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }

      if (tableName != null) {
        entityRepository = _entityRepositories.values
            .where((e) => e is SQLEntityRepository && e.tableName == tableName)
            .firstOrNull;
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }
    }

    var entityRepository =
        parentRepositoryProvider?.getEntityRepository<O>(obj: obj, type: type);

    if (entityRepository != null) {
      return entityRepository;
    }

    return _knownEntityRepositoryProviders.getEntityRepository<O>(
        obj: obj, type: type, name: name, entityRepositoryProvider: this);
  }

  @override
  EntityRepository<O>? getEntityRepositoryByType<O extends Object>(Type type) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    try {
      return _getEntityRepositoryByTypeImpl<O>(type) ??
          EntityRepositoryProvider.globalProvider
              .getEntityRepositoryByType<O>(type);
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryByTypeImpl<O extends Object>(
      Type type) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[type];
      if (entityRepository != null && !entityRepository.isClosed) {
        return entityRepository as EntityRepository<O>;
      }
    }

    var entityRepository =
        parentRepositoryProvider?.getEntityRepositoryByType<O>(type);

    if (entityRepository != null) {
      return entityRepository;
    }

    return _knownEntityRepositoryProviders.getEntityRepositoryByType<O>(type,
        entityRepositoryProvider: this);
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  @override
  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    _knownEntityRepositoryProviders.add(provider);
  }

  @override
  Map<Type, EntityRepository> allRepositories(
      {Map<Type, EntityRepository>? allRepositories,
      Set<EntityRepositoryProvider>? traversedProviders}) {
    allRepositories ??= <Type, EntityRepository>{};
    traversedProviders ??= <EntityRepositoryProvider>{};

    if (traversedProviders.contains(this)) {
      return allRepositories;
    }

    traversedProviders.add(this);

    for (var e in _entityRepositories.entries) {
      allRepositories.putIfAbsent(e.key, () => e.value);
    }

    for (var e in _knownEntityRepositoryProviders) {
      e.allRepositories(allRepositories: allRepositories);
    }

    return allRepositories;
  }
}

class DBRepositoryAdapter<O> with Initializable {
  final DBAdapter databaseAdapter;

  final String name;

  final String tableName;

  final Type type;

  DBRepositoryAdapter(this.databaseAdapter, this.name,
      {String? tableName, Type? type})
      : tableName = tableName ?? name,
        type = type ?? O;

  @override
  FutureOr<InitializationResult> initialize() =>
      databaseAdapter.ensureInitialized(parent: this);

  DBDialect get dialect => databaseAdapter.dialect;

  String get dialectName => databaseAdapter.dialectName;

  SchemeProvider get schemeProvider => databaseAdapter;

  FutureOr<TableScheme> getTableScheme() =>
      databaseAdapter.getTableScheme(tableName).resolveMapped((t) => t!);

  Map<String, dynamic> information({bool extended = false}) =>
      databaseAdapter.information(extended: extended, table: tableName);

  FutureOr<int> doCount(TransactionOperation op,
          {EntityMatcher? matcher,
          Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          PreFinishDBOperation<int, int>? preFinish}) =>
      databaseAdapter.doCount(op, name, tableName,
          matcher: matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          preFinish: preFinish);

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

  FutureOr<dynamic> doInsert(
          TransactionOperation op, O o, Map<String, dynamic> fields,
          {String? idFieldName,
          PreFinishDBOperation<dynamic, dynamic>? preFinish}) =>
      databaseAdapter.doInsert(op, name, tableName, o, fields,
          idFieldName: idFieldName, preFinish: preFinish);

  FutureOr<dynamic> doUpdate(
          TransactionOperation op, O o, Object id, Map<String, dynamic> fields,
          {String? idFieldName,
          PreFinishDBOperation<dynamic, dynamic>? preFinish,
          bool allowAutoInsert = false}) =>
      databaseAdapter.doUpdate(op, name, tableName, o, id, fields,
          idFieldName: idFieldName,
          preFinish: preFinish,
          allowAutoInsert: allowAutoInsert);

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

  FutureOr<R> doDelete<R>(TransactionOperation op, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>?
              preFinish}) =>
      databaseAdapter.doDelete<R>(op, name, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          preFinish: preFinish);

  @override
  String toString() =>
      'DBRepositoryAdapter{name: $name, tableName: $tableName, type: $type}';
}

/// Base class for [EntityRepositoryProvider] with [DBAdapter]s.
abstract class DBEntityRepositoryProvider<A extends DBAdapter>
    extends EntityRepositoryProvider {
  String? get workingPath => null;

  Map<String, dynamic> get adapterConfig;

  A? _adapter;

  FutureOr<A> get adapter {
    var adapter = _adapter;
    if (adapter != null) return adapter;
    return buildAdapter().resolveMapped((adapter) {
      _adapter = adapter;
      return adapter;
    });
  }

  FutureOr<A> buildAdapter() => DBAdapter.fromConfig(
        adapterConfig,
        parentRepositoryProvider: this,
        workingPath: workingPath,
      );

  @override
  Future<InitializationResult> initialize() async {
    var adapter = await this.adapter;
    var repositories = buildRepositories(adapter);

    return InitializationResult.ok(this,
        dependencies: [adapter, ...repositories]);
  }

  List<EntityRepository> buildRepositories(A adapter);

  @override
  bool close() {
    if (!super.close()) return false;

    _adapter?.close();
    _adapter = null;

    return true;
  }
}

/// A [DBAdapter] [Exception].
class DBAdapterException implements Exception {
  /// The type of the exception.
  final String type;

  /// The exception message.
  final String message;

  /// The parent error/exception.
  /// Usually the native [Exception] or [Error] of the database.
  Object? parentError;
  StackTrace? parentStackTrace;

  DBAdapterException(this.type, this.message,
      {this.parentError, this.parentStackTrace})
      : super();

  @override
  String toString() {
    var s = '$runtimeType[$type]: $message';
    if (parentError != null) {
      s += '\n  -- Parent ERROR>> [${parentError.runtimeType}] $parentError';
    }
    return s;
  }
}
