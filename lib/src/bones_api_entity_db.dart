import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_entity_db_object.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart' hide IterableIntExtension;

import 'bones_api_mixin.dart';

final _log = logging.Logger('DBAdapter');

typedef PasswordProvider = FutureOr<String> Function(String user);

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
    return '$runtimeTypeNameUnsafe{name: $name}';
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

    DBRelationalAdapter.boot();
    DBObjectAdapter.boot();
  }

  static final DBAdapterRegister<Object, DBAdapter<Object>> adapterRegister =
      DBAdapterRegister();

  static List<String> get registeredAdaptersNames =>
      adapterRegister.registeredAdaptersNames;

  static List<Type> get registeredAdaptersTypes =>
      adapterRegister.registeredAdaptersTypes;

  static void registerAdapter<C extends Object, A extends DBAdapter<C>>(
          List<String> names,
          Type type,
          DBAdapterInstantiator<C, A> adapterInstantiator) =>
      adapterRegister.registerAdapter(names, type, adapterInstantiator);

  static DBAdapterInstantiator<C, A>?
      getAdapterInstantiator<C extends Object, A extends DBAdapter<C>>(
              {String? name, Type? type}) =>
          adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C extends Object,
              A extends DBAdapter<C>>(Map<String, dynamic> config) =>
          adapterRegister.getAdapterInstantiatorsFromConfig<C, A>(config);

  static final WeakList<DBAdapter> _instances = WeakList<DBAdapter>();

  static List<DBAdapter> get instances => _instances.toList();

  /// The name of the adapter.
  final String name;

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

  static int _instanceIDCount = 0;

  @override
  final int instanceID = ++_instanceIDCount;

  DBAdapter(
      this.name, this.minConnections, this.maxConnections, this.capability,
      {this.parentRepositoryProvider,
      Object? populateSource,
      Object? populateSourceVariables,
      String? workingPath})
      : _populateSource = populateSource,
        _populateSourceVariables = populateSourceVariables,
        _workingPath = workingPath {
    boot();

    _instances.add(this);

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
  FutureOr<InitializationResult> initialize() {
    return checkDB().resolveMapped((dbOK) {
      if (!dbOK) {
        throw StateError("Can't initialize `DBAdapter`: Table check failed!");
      }

      return populateImpl();
    });
  }

  final StreamController<DBAdapter<C>> _onCloseController = StreamController();

  /// On [close] events.
  late final Stream<DBAdapter<C>> onClose = _onCloseController.stream;

  @override
  bool close() {
    // ignore: discarded_futures
    if (!(super.close() as bool)) return false;

    // ignore: discarded_futures
    clearPool();

    _onCloseController.add(this);

    return true;
  }

  Map<String, dynamic> information({bool extended = false, String? table}) =>
      <String, dynamic>{};

  final String? _workingPath;

  FutureOr<bool> checkDB() => true;

  Object? _populateSource;
  Object? _populateSourceVariables;

  FutureOr<InitializationResult> populateImpl() =>
      _populateSourceImpl(_populateSource, _populateSourceVariables);

  FutureOr<InitializationResult> _populateSourceImpl(
      Object? populateSource, Object? populateSourceVariables) {
    _populateSource = null;
    _populateSourceVariables = null;

    if (populateSource == null) {
      return InitializationResult.ok(this, dependencies: [
        if (parentRepositoryProvider != null) parentRepositoryProvider!
      ]);
    }

    return populateFromSource(populateSource,
            workingPath: _workingPath,
            resolutionRules: EntityResolutionRules(allowReadFile: true),
            variables: populateSourceVariables)
        .resolveMapped((val) {
      var result = InitializationResult.ok(this, dependencies: [
        if (parentRepositoryProvider != null) parentRepositoryProvider!,
        ...entityRepositories,
      ]);

      return result;
    });
  }

  @override
  FutureOr<O?> getEntityByID<O>(dynamic id,
      {Type? type, bool sync = false, EntityResolutionRules? resolutionRules}) {
    if (id == null || type == null) return null;

    var entityRepository = getEntityRepositoryByType(type);
    if (entityRepository != null) {
      if (sync) return null;
      return entityRepository
          .selectByID(id, resolutionRules: resolutionRules)
          .resolveMapped((o) => o as O?);
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
          .map((r) => MapEntry<EntityRepository, String>(
              r, getTableForEntityRepository(r)))
          .toMapFromEntries();

  @override
  String? getTableForType(TypeInfo type) {
    if (type.hasArguments) {
      if (type.isEntityReferenceBaseType) {
        type = type.arguments0!;
      } else if (type.isMap) {
        type = type.arguments[1];
      } else if (type.isIterable || type.isList || type.isSet) {
        type = type.arguments0!;
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
  Object? getEntityID(Object entity,
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

  void checkEntityFields<O>(O o, String entityName, String table,
      {EntityHandler<O>? entityHandler}) {}

  FutureOr<int> doCount(
      TransactionOperation op, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<int, int>? preFinish});

  FutureOr<R?> doSelectByID<R>(
      TransactionOperation op, String entityName, String table, Object id,
      {PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish});

  FutureOr<List<R>> doSelectByIDs<R>(TransactionOperation op, String entityName,
      String table, List<Object> ids,
      {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
          preFinish});

  FutureOr<List<R>> doSelectAll<R>(
      TransactionOperation op, String entityName, String table,
      {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
          preFinish});

  FutureOr<dynamic> doInsert<O>(TransactionOperation op, String entityName,
      String table, O o, Map<String, dynamic> fields,
      {String? idFieldName, PreFinishDBOperation<dynamic, dynamic>? preFinish});

  FutureOr<dynamic> doUpdate<O>(TransactionOperation op, String entityName,
      String table, O o, Object id, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishDBOperation<dynamic, dynamic>? preFinish,
      bool allowAutoInsert = false});

  FutureOr<R> doDelete<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish});

  bool isTransactionWithSingleOperation(TransactionOperation op) {
    var transaction = op.transaction;

    return transaction.length == 1 &&
        !transaction.canPropagate &&
        !op.canPropagate &&
        !transaction.isExecuting;
  }

  FutureOr<C> openTransaction(Transaction transaction);

  bool get cancelTransactionResultWithError;

  bool get throwTransactionResultWithError;

  FutureOr<dynamic> resolveTransactionResult(
      dynamic result, Transaction transaction, C? connection) async {
    // When aborted `_transactionCompleter.complete` will be called
    // with the error (not calling `completeError`), since it's
    // running in another error zone (won't reach `onError`):
    if (result is TransactionAbortedError) {
      if (cancelTransactionResultWithError) {
        await cancelTransaction(
            transaction, connection, result, result.stackTrace);

        if (throwTransactionResultWithError) {
          throw result;
        } else {
          return result;
        }
      } else if (throwTransactionResultWithError) {
        throw result;
      }
    }

    return result;
  }

  FutureOr<bool> cancelTransaction(Transaction transaction, C? connection,
      Object? error, StackTrace? stackTrace);

  bool get callCloseTransactionRequired;

  FutureOr<void> closeTransaction(Transaction transaction, C? connection);

  /// Returns the URL of the [connection].
  String getConnectionURL(C connection);

  /// Creates a connection [C] for this adapte
  FutureOr<C> createConnection();

  /// The maximum allowed duration of inactivity for a connection in the pool.
  /// Default: 15min
  Duration connectionInactivityLimit = Duration(minutes: 15);

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

  int _creatingConnectionsYieldCount = 0;

  /// Defaults: calls [createConnection].
  @override
  FutureOr<C?> createPoolElement({bool force = false}) {
    if (poolAliveElementsSize < maxConnections || force) {
      if (_creatingConnectionsCount > 3) {
        var yield1 = _yieldByCreatingConnections();
        var yield2 = _yieldByCreatingConnectionsYield();
        final yieldMs = yield1 + yield2;

        ++_creatingConnectionsYieldCount;

        return Future.delayed(Duration(milliseconds: yieldMs), () {
          --_creatingConnectionsYieldCount;

          var conn = catchFromPopulatedPool();
          if (conn == null) {
            //print('!!! yieldMs: $yield1 + $yield2 = $yieldMs >> _creatingConnectionsCount: $_creatingConnectionsCount > _creatingConnectionsYeldCount: $_creatingConnectionsYieldCount');
            if (poolAliveElementsSize < maxConnections || force) {
              super.createPoolElement(force: force);
              return _createPoolElementImpl();
            } else {
              return null;
            }
          }

          return conn.resolveMapped((conn) {
            if (conn != null) return conn;

            if (poolAliveElementsSize < maxConnections || force) {
              super.createPoolElement(force: force);
              return _createPoolElementImpl();
            } else {
              return null;
            }
          });
        });
      } else {
        super.createPoolElement(force: force);
        return _createPoolElementImpl();
      }
    } else {
      return null;
    }
  }

  int _yieldByCreatingConnectionsYield() {
    final count = _creatingConnectionsYieldCount;
    if (count > 20) {
      return 2000;
    } else if (count > 10) {
      return count * 50;
    } else {
      return count * 20;
    }
  }

  int _yieldByCreatingConnections() {
    final count = _creatingConnectionsCount;
    if (count > 20) {
      return 2000;
    } else if (count > 10) {
      return count * 50;
    } else {
      return count * 20;
    }
  }

  FutureOr<C?> _createPoolElementImpl() {
    var ret = createConnection();
    if (ret is! Future) {
      return ret;
    }

    return _createPoolElementAsync(ret);
  }

  int _creatingConnectionsCount = 0;

  FutureOr<C> _createPoolElementAsync(FutureOr<C> connAsync) async {
    try {
      ++_creatingConnectionsCount;

      var conn = await connAsync;
      return conn;
    } finally {
      --_creatingConnectionsCount;
      assert(_creatingConnectionsCount >= 0);
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

  List<EntityRepository> get entityRepositoriesBuildOrder => entityRepositories;

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
        entityRepository = _entityRepositories.values.where((e) {
          if (e is DBSQLEntityRepository) {
            return e.tableName == tableName;
          } else {
            return e.name == tableName;
          }
        }).firstOrNull;
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }
    }

    var entityRepository = parentRepositoryProvider?.getEntityRepository<O>(
        obj: obj, type: type, name: name);

    if (entityRepository != null) {
      return entityRepository;
    }

    return _knownEntityRepositoryProviders.getEntityRepository<O>(
        obj: obj,
        type: type,
        name: name,
        entityRepositoryProvider: this,
        removeClosedProviders: true);
  }

  @override
  EntityRepository<O>? getEntityRepositoryByTypeInfo<O extends Object>(
      TypeInfo typeInfo) {
    var entityType = typeInfo.entityType;
    if (entityType == null) return null;

    return getEntityRepositoryByType(entityType);
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
        entityRepositoryProvider: this, removeClosedProviders: true);
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

    for (var repo in entityRepositoriesBuildOrder) {
      allRepositories.putIfAbsent(repo.type, () => repo);
    }

    for (var e in _knownEntityRepositoryProviders) {
      e.allRepositories(allRepositories: allRepositories);
    }

    return allRepositories;
  }
}

/// Base class for a [DBAdapter] connection.
abstract class DBConnectionWrapper<C extends Object>
    implements WithRuntimeTypeNameSafe {
  static final Map<Type, int> _idCounter = {};

  static int _nextID(Type type) {
    var count = _idCounter[type] ?? 1;
    var id = _idCounter[type] = count + 1;
    return id;
  }

  late final int id = _nextID(runtimeType);

  final C nativeConnection;

  DBConnectionWrapper(this.nativeConnection);

  final DateTime creationTime = DateTime.now();

  late DateTime _lastAccessTime = creationTime;

  DateTime get lastAccessTime => _lastAccessTime;

  void updateLastAccessTime({DateTime? now}) {
    _lastAccessTime = now ?? DateTime.now();
  }

  Duration timeSinceAccess({DateTime? now}) {
    now ??= DateTime.now();
    return now.difference(_lastAccessTime);
  }

  bool isInactive(Duration inactivityLimit, {DateTime? now}) {
    return timeSinceAccess(now: now) > inactivityLimit;
  }

  String get connectionURL;

  bool _closed = false;

  bool get isClosed {
    if (_closed) {
      return true;
    } else {
      var connClosed = isClosedImpl();
      if (connClosed) {
        _closed = connClosed;
      }
      return connClosed;
    }
  }

  bool isClosedImpl();

  void close() {
    if (_closed) return;
    _closed = true;
    closeImpl();
  }

  void closeImpl();

  String get info => 'closed: $isClosed';

  @override
  String toString() {
    return '$runtimeTypeNameSafe#$id{$info}@$nativeConnection';
  }
}

/// [DBAdapter] register.
/// Handles the implementation of:
/// - [DBAdapter.registerAdapter]
/// - [DBAdapter.getAdapterInstantiator]
/// - [DBAdapter.getAdapterInstantiatorsFromConfig]
class DBAdapterRegister<C extends Object, A extends DBAdapter<C>> {
  final DBAdapterRegister? superRegister;

  DBAdapterRegister({this.superRegister});

  /// Creates a child register.
  DBAdapterRegister<C2, A2>
      createRegister<C2 extends Object, A2 extends DBAdapter<C2>>() =>
          DBAdapterRegister<C2, A2>(superRegister: this);

  final Map<String, DBAdapterInstantiator<C, A>> _registeredAdaptersByName = {};
  final Map<Type, DBAdapterInstantiator<C, A>> _registeredAdaptersByType = {};

  List<String> get registeredAdaptersNames =>
      _registeredAdaptersByName.keys.toList();

  List<Type> get registeredAdaptersTypes =>
      _registeredAdaptersByType.keys.toList();

  void registerAdapter(List<String> names, Type type,
      DBAdapterInstantiator<C, A> adapterInstantiator) {
    for (var name in names) {
      _registeredAdaptersByName[name] = adapterInstantiator;
    }

    _registeredAdaptersByType[type] = adapterInstantiator;

    superRegister?.registerAdapter(names, type, adapterInstantiator);
  }

  DBAdapterInstantiator<C2, A2>?
      getAdapterInstantiator<C2 extends C, A2 extends DBAdapter<C2>>(
          {String? name, Type? type}) {
    if (name == null && type == null) {
      throw ArgumentError(
          'One of the parameters `name` or `type` should NOT be null!');
    }

    if (name != null) {
      var adapter = _registeredAdaptersByName[name];
      if (adapter is DBAdapterInstantiator<C2, A2>) {
        return adapter as DBAdapterInstantiator<C2, A2>;
      }
    }

    if (type != null) {
      var adapter = _registeredAdaptersByType[type];
      if (adapter is DBAdapterInstantiator<C2, A2>) {
        return adapter as DBAdapterInstantiator<C2, A2>;
      }
    }

    return null;
  }

  List<MapEntry<DBAdapterInstantiator<C2, A2>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C2 extends C, A2 extends DBAdapter<C2>>(
              Map<String, dynamic> config) =>
          getAdapterInstantiatorsFromConfigImpl<C2, A2>(
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
}

/// An adapter for [EntityRepository] and [DBAdapter].
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

  void checkEntityFields(O o, EntityHandler<O> entityHandler) => databaseAdapter
      .checkEntityFields<O>(o, name, tableName, entityHandler: entityHandler);

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

  FutureOr<R?> doSelectByID<R>(TransactionOperation op, Object id,
          {PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish}) =>
      databaseAdapter.doSelectByID<R>(op, name, tableName, id,
          preFinish: preFinish);

  FutureOr<List<R>> doSelectByIDs<R>(TransactionOperation op, List<Object> ids,
          {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
              preFinish}) =>
      databaseAdapter.doSelectByIDs<R>(op, name, tableName, ids,
          preFinish: preFinish);

  FutureOr<List<R>> doSelectAll<R>(TransactionOperation op,
          {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
              preFinish}) =>
      databaseAdapter.doSelectAll<R>(op, name, tableName, preFinish: preFinish);

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

class DBEntityRepository<O extends Object> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  final DBRepositoryAdapter<O> repositoryAdapter;

  DBEntityRepository(
      DBAdapter adapter, String name, EntityHandler<O> entityHandler,
      {DBRepositoryAdapter<O>? repositoryAdapter, Type? type})
      : repositoryAdapter =
            repositoryAdapter ?? adapter.createRepositoryAdapter<O>(name)!,
        super(adapter, name, entityHandler, type: type);

  @override
  FutureOr<InitializationResult> initialize() => provider
          .executeInitialized(
              () => repositoryAdapter.ensureInitialized(parent: this),
              parent: this)
          .resolveMapped((result) {
        return InitializationResult.ok(this, dependencies: [
          provider,
          repositoryAdapter,
          ...result.dependencies
        ]);
      });

  DBDialect get dialect => repositoryAdapter.dialect;

  String get dialectName => repositoryAdapter.dialectName;

  String get tableName => repositoryAdapter.tableName;

  @override
  Map<String, dynamic> information({bool extended = false}) => {
        'dialect': dialectName,
        'table': name,
        if (extended) 'adapter': repositoryAdapter.information(extended: true),
      };

  @override
  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) {
    var cachedEntityByID = transaction?.getCachedEntityByID(id, type: type);
    if (cachedEntityByID != null) return false;

    return count(matcher: ConditionID(id), transaction: transaction)
        .resolveMapped((count) => count > 0);
  }

  @override
  FutureOr<dynamic> ensureStored(o,
      {Transaction? transaction, TransactionOperation? operation}) {
    checkNotClosed();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null || entityHasChangedFields(o)) {
      return _ensureStoredImpl(o, transaction, operation);
    } else {
      if (isTrackingEntity(o)) {
        return id;
      }

      return existsID(id, transaction: transaction).resolveMapped((exists) {
        if (!exists) {
          return _ensureStoredImpl(o, transaction, operation);
        } else {
          return id;
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

  @override
  FutureOr<bool> ensureReferencesStored(O o,
      {Transaction? transaction, TransactionOperation? operation}) {
    throw UnsupportedError("Relationships not supported for: $this");
  }

  @override
  FutureOr<int> length({Transaction? transaction}) =>
      count(transaction: transaction);

  DBAdapter get operationExecutor => repositoryAdapter.databaseAdapter;

  @override
  FutureOr<int> count(
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var op = TransactionOperationCount(name, operationExecutor,
        matcher: matcher, transaction: transaction);

    try {
      return repositoryAdapter.doCount(op,
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
  FutureOr<Iterable<O>> select(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules}) {
    if (matcher is ConditionID) {
      return _selectByID(transaction, matcher, parameters ?? namedParameters,
              resolutionRules)
          .resolveMapped((res) => res != null ? <O>[res] : <O>[]);
    }

    if (matcher is ConditionIdIN) {
      return _selectByIDs(
          transaction, matcher, parameters ?? namedParameters, resolutionRules);
    }

    if (matcher is ConditionANY) {
      return _selectAll(transaction, matcher, resolutionRules);
    }

    throw UnsupportedError(
        "Relationship select not supported for: (${matcher.runtimeTypeNameUnsafe}) $matcher @ $tableName ($this)");
  }

  FutureOr<O?> _selectByID(Transaction? transaction, ConditionID matcher,
      Object? parameters, EntityResolutionRules? resolutionRules) {
    var id = matcher.idValue ?? matcher.getID(parameters);

    if (id == null && parameters != null) {
      id = matcher.getID(parameters);
    }

    if (id == null) return null;

    final resolutionRulesResolved =
        resolveEntityResolutionRules(resolutionRules);

    var canPropagate = hasReferencedEntities(resolutionRulesResolved);

    var op = TransactionOperationSelect(
        name, canPropagate, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doSelectByID<O?>(op, id, preFinish: (results) {
        return resolveEntities(op.transaction, [results],
                resolutionRules: resolutionRulesResolved)
            .resolveMapped((os) => os.firstOrNull);
      });
    } catch (e, s) {
      var message = '_selectByID> '
          'matcher: $matcher ; '
          'id: $id ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  FutureOr<List<O>> _selectByIDs(
      Transaction? transaction,
      ConditionIdIN matcher,
      Object? parameters,
      EntityResolutionRules? resolutionRules) {
    var ids = matcher.idsValues.whereNotNull().toList();
    if (ids.isEmpty) return <O>[];

    final resolutionRulesResolved =
        resolveEntityResolutionRules(resolutionRules);

    var canPropagate = hasReferencedEntities(resolutionRulesResolved);

    var op = TransactionOperationSelect(
        name, canPropagate, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doSelectByIDs<O>(op, ids, preFinish: (results) {
        return resolveEntities(op.transaction, results,
            resolutionRules: resolutionRulesResolved);
      });
    } catch (e, s) {
      var message = '_selectByIDs> '
          'matcher: $matcher ; '
          'id: $ids ; '
          'op: $op';
      _log.severe(message, e, s);
      rethrow;
    }
  }

  FutureOr<List<O>> _selectAll(Transaction? transaction, ConditionANY matcher,
      EntityResolutionRules? resolutionRules) {
    final resolutionRulesResolved =
        resolveEntityResolutionRules(resolutionRules);

    var canPropagate = hasReferencedEntities(resolutionRulesResolved);

    var op = TransactionOperationSelect(
        name, canPropagate, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doSelectAll<O>(op, preFinish: (results) {
        return resolveEntities(op.transaction, results,
            resolutionRules: resolutionRulesResolved);
      });
    } catch (e, s) {
      var message = '_selectAll> '
          'matcher: $matcher ; '
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
  bool hasReferencedEntities([EntityResolutionRulesResolved? resolutionRules]) {
    final fieldsEntity = _fieldsEntity;
    final fieldsEntityRef = _fieldsEntityRef;

    final fieldsListEntity = _fieldsListEntity;
    final fieldsListEntityRef = _fieldsListEntityRef;

    if (fieldsEntity.isEmpty && fieldsListEntity.isEmpty) return false;

    var fieldsEntityNoRef = fieldsEntity.length - fieldsEntityRef.length;
    if (fieldsEntityNoRef > 0) return true;

    var fieldsListEntityNoRef =
        fieldsListEntity.length - fieldsListEntityRef.length;
    if (fieldsListEntityNoRef > 0) return true;

    if (resolutionRules == null || resolutionRules.isInnocuous) return false;

    if (fieldsEntityRef.isEmpty && fieldsListEntityRef.isNotEmpty) return false;

    var allEager = resolutionRules.allEager ?? false;
    var eagerEntityTypes = resolutionRules.eagerEntityTypes;
    var lazyEntityTypes = resolutionRules.lazyEntityTypes;

    if (allEager) {
      if (lazyEntityTypes != null && lazyEntityTypes.isNotEmpty) {
        var anyEager = CombinedIterableView(
          [fieldsEntityRef.values, fieldsListEntityRef.values],
        ).any((t) => resolutionRules.isEagerEntityTypeInfo(t));
        return anyEager;
      } else {
        return true;
      }
    }

    if (eagerEntityTypes != null && eagerEntityTypes.isNotEmpty) {
      var anyEager = CombinedIterableView(
        [fieldsEntityRef.values, fieldsListEntityRef.values],
      ).any((t) => resolutionRules.isEagerEntityTypeInfo(t));
      return anyEager;
    }

    return false;
  }

  FutureOr<List<O>> resolveEntities(
      Transaction transaction, Iterable<Map<String, dynamic>?>? results,
      {EntityResolutionRules? resolutionRules}) {
    if (results == null) return <O>[];

    if (results is List && results.isEmpty) return <O>[];

    final resolutionRulesResolved =
        resolveEntityResolutionRules(resolutionRules);

    Iterable<Map<String, dynamic>> entries;
    if (results is! Iterable<Map<String, dynamic>>) {
      entries = results.whereNotNull();
    } else {
      entries = results;
    }

    var fieldsListEntity = _fieldsListEntity;

    if (fieldsListEntity.isNotEmpty) {
      var retTableScheme = repositoryAdapter.getTableScheme();
      var retRelationshipFields =
          _getRelationshipFields(fieldsListEntity, retTableScheme);

      var ret = retTableScheme.resolveOther<List<FutureOr<O>>,
              Map<String, TableRelationshipReference>>(retRelationshipFields,
          (tableScheme, relationshipFields) {
        if (relationshipFields.isNotEmpty) {
          entries = entries is List ? entries : entries.toList();

          var resolveRelationshipsFields = _resolveRelationshipFields(
            transaction,
            tableScheme,
            entries,
            relationshipFields,
            fieldsListEntity,
            resolutionRulesResolved,
          );

          return resolveRelationshipsFields.resolveAllWith(() =>
              _resolveEntitiesSubEntities(
                  transaction, resolutionRulesResolved, entries));
        } else {
          return _resolveEntitiesSubEntities(
              transaction, resolutionRulesResolved, entries);
        }
      });

      return _resolveEntitiesFutures(transaction, ret);
    } else {
      var ret = _resolveEntitiesSubEntities(
          transaction, resolutionRulesResolved, entries);
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
      Transaction transaction,
      EntityResolutionRulesResolved resolutionRulesResolved,
      Iterable<Map<String, dynamic>> results) {
    final entityProvider = TransactionEntityProvider(
        transaction, provider, resolutionRulesResolved);

    return results.map((e) {
      // ignore: discarded_futures
      return entityHandler.createFromMap(e,
          entityProvider: entityProvider,
          entityCache: transaction,
          entityRepositoryProvider: provider,
          entityHandlerProvider: entityHandler.provider,
          resolutionRules: resolutionRulesResolved);
    }).toList();
  }

  FutureOr<List<FutureOr<O>>> _resolveEntitiesSubEntities(
      Transaction transaction,
      EntityResolutionRulesResolved resolutionRulesResolved,
      Iterable<Map<String, dynamic>> results) {
    if (_fieldsEntity.isEmpty) {
      return _resolveEntitiesSimple(
          transaction, resolutionRulesResolved, results);
    }

    var resultsList =
        results is List<Map<String, dynamic>> ? results : results.toList();

    if (resultsList.length == 1) {
      return _resolveEntitiesSimple(
          transaction, resolutionRulesResolved, resultsList);
    }

    var fieldsEntityRepositories =
        _resolveFieldsEntityRepositories(resolutionRulesResolved);

    if (fieldsEntityRepositories.isNotEmpty) {
      var fieldsEntitiesAsync =
          _fieldsColumnsAll().resolveMapped((fieldsColumns) {
        return fieldsEntityRepositories.map((field, repo) {
          var tableColumn = fieldsColumns[field]!;

          var ids = resultsList.map((e) => e[tableColumn]).toList();
          var idsUniques = ids.whereNotNull().toSet().toList();

          var entities = repo
              .selectByIDs(idsUniques,
                  transaction: transaction,
                  resolutionRules: resolutionRulesResolved)
              .resolveMapped((entities) => idsUniques
                  .mapIndexed((i, id) => MapEntry(id, entities[i]))
                  .toList());

          return MapEntry(tableColumn, entities);
        }).resolveAllValues();
      });

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

        return _resolveEntitiesSimple(
            transaction, resolutionRulesResolved, resultsList);
      });
    }

    return _resolveEntitiesSimple(
        transaction, resolutionRulesResolved, results);
  }

  Map<String, String>? _fieldsColumns;

  FutureOr<Map<String, String>> _fieldsColumnsAll() {
    var fieldsColumns = _fieldsColumns;
    if (fieldsColumns != null) return fieldsColumns;

    return _fieldsEntityRepositoriesAll()
        .map((f, _) => MapEntry(f, _resolveEntityFieldToTableColumn(f)))
        .resolveAllValues()
        .resolveMapped((fieldsColumns) {
      _fieldsColumns = fieldsColumns;
      return fieldsColumns;
    });
  }

  Map<String, TypeInfo> get _fieldsEntity =>
      entityHandler.fieldsWithTypeEntityOrReference();

  Map<String, TypeInfo> get _fieldsEntityRef =>
      entityHandler.fieldsWithEntityReference();

  Map<String, TypeInfo> get _fieldsListEntity =>
      entityHandler.fieldsWithTypeListEntityOrReference();

  Map<String, TypeInfo> get _fieldsListEntityRef =>
      entityHandler.fieldsWithEntityReferenceList();

  Map<String, EntityRepository<Object>>? _fieldsEntityRepositories;

  Map<String, EntityRepository<Object>> _fieldsEntityRepositoriesAll() =>
      _fieldsEntityRepositories ??= _fieldsEntity.entries
          .map((e) {
            var repo = _resolveEntityRepository(e.value);
            return repo != null ? MapEntry(e.key, repo) : null;
          })
          .whereNotNull()
          .toMapFromEntries();

  Map<String, EntityRepository<Object>> _resolveFieldsEntityRepositories(
      EntityResolutionRulesResolved resolutionRulesResolved) {
    final fieldsEntity = this._fieldsEntity;

    return _fieldsEntityRepositoriesAll()
        .entries
        .map((e) {
          var fieldType = fieldsEntity[e.key]!;
          if (fieldType.isEntityReferenceType) {
            var entityType = fieldType.arguments0!.type;
            var eagerEntityType =
                resolutionRulesResolved.isEagerEntityType(entityType);
            if (!eagerEntityType) return null;
          }
          return e;
        })
        .whereNotNull()
        .toMapFromEntries();
  }

  List<FutureOr<bool>> _resolveRelationshipFields(
    Transaction transaction,
    TableScheme tableScheme,
    Iterable<Map<String, dynamic>> results,
    Map<String, TableRelationshipReference> relationshipFields,
    Map<String, TypeInfo> fieldsListEntity,
    EntityResolutionRulesResolved resolutionRulesResolved,
  ) {
    var idFieldName = tableScheme.idFieldName!;
    var ids = results.map((e) => e[idFieldName]).toList();

    var databaseAdapter = repositoryAdapter.databaseAdapter;

    return relationshipFields.entries.map((e) {
      var fieldName = e.key;
      var fieldType = fieldsListEntity[fieldName]!;
      var targetTable = e.value.targetTable;

      var targetRepositoryAdapter =
          databaseAdapter.getRepositoryAdapterByTableName(targetTable)!;
      var targetType = targetRepositoryAdapter.type;
      var targetEntityRepository =
          provider.getEntityRepositoryByType(targetType)!;

      // ignore: discarded_futures
      var relationshipsAsync = selectRelationships(null, fieldName,
          oIds: ids, fieldType: fieldType, transaction: transaction);

      // ignore: discarded_futures
      var retRelationships = relationshipsAsync.resolveMapped((relationships) {
        var allTargetIds =
            relationships.values.expand((e) => e).toSet().toList();

        if (fieldType.isEntityReferenceListType &&
            !resolutionRulesResolved
                .isEagerEntityType(fieldType.arguments0!.type)) {
          return relationships.map((key, value) => MapEntry(key, value.asList));
        }

        // ignore: discarded_futures
        var targetsAsync = targetEntityRepository.selectByIDs(allTargetIds,
            transaction: transaction, resolutionRules: resolutionRulesResolved);

        // ignore: discarded_futures
        return targetsAsync.resolveMapped((targets) {
          var allTargetsById = Map.fromEntries(targets
              .whereNotNull()
              .map((e) => MapEntry(targetEntityRepository.getEntityID(e)!, e)));

          return relationships.map((id, targetIds) {
            var targetEntities = targetIds
                .map((id) => allTargetsById[id])
                .whereNotNull()
                .toList();
            var targetEntitiesCast = targetEntityRepository.entityHandler
                .castList(targetEntities, targetType)!;
            return MapEntry(id, targetEntitiesCast);
          }).resolveAllValues(); // ignore: discarded_futures
        });
      });

      // ignore: discarded_futures
      return retRelationships.resolveMapped((relationships) {
        for (var r in results) {
          var id = r[idFieldName];
          var values = relationships[id];
          values ??= targetEntityRepository.entityHandler
              .castList(<dynamic>[], targetType)!;
          r[fieldName] = values;
        }
      }).resolveWithValue(true); // ignore: discarded_futures
    }).toList(growable: false);
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

  FutureOr<String> _resolveEntityFieldToTableColumn(String entityField) =>
      repositoryAdapter.getTableScheme().resolveMapped((tableScheme) {
        var tableField = tableScheme.resolveTableFieldName(entityField);
        if (tableField == null) {
          throw StateError(
              "Can't resolve entity `${entityHandler.type}` field `$entityField` to one of the table `${tableScheme.name}` columns: ${tableScheme.fieldsNames}");
        }
        return tableField;
      });

  final Expando<
          MapEntry<Map<String, TypeInfo>,
              Map<String, TableRelationshipReference>>>
      _relationshipFieldsCache = Expando();

  FutureOr<Map<String, TableRelationshipReference>> _getRelationshipFields(
      Map<String, TypeInfo> fieldsListEntity,
      [FutureOr<TableScheme>? retTableScheme]) {
    retTableScheme ??= repositoryAdapter.getTableScheme();

    return retTableScheme.resolveMapped((tableScheme) {
      var cached = _relationshipFieldsCache[tableScheme];

      if (cached != null) {
        if (identical(cached.key, fieldsListEntity)) {
          return cached.value;
        }
      }

      var relationshipFields =
          _getRelationshipFieldsImpl(fieldsListEntity, tableScheme);

      _relationshipFieldsCache[tableScheme] =
          MapEntry(fieldsListEntity, relationshipFields);

      return relationshipFields;
    });
  }

  Map<String, TableRelationshipReference> _getRelationshipFieldsImpl(
      Map<String, TypeInfo<dynamic>> fieldsListEntity,
      TableScheme tableScheme) {
    var databaseAdapter = repositoryAdapter.databaseAdapter;

    var entries = fieldsListEntity.entries.map((e) {
      var fieldName = e.key;
      var targetType = e.value.arguments0!.type;

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

    var relationshipFields =
        Map<String, TableRelationshipReference>.fromEntries(entries);
    return relationshipFields;
  }

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
      var idFieldsName = entityHandler.idFieldName(o);
      var fields = entityHandler.getFields(o);

      return repositoryAdapter
          .doInsert(op, o, fields, idFieldName: idFieldsName, preFinish: (id) {
        entityHandler.setID(o, id);

        trackEntity(o);
        return id; // pre-finish
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

  FutureOr<dynamic> _update(O o, Transaction? transaction,
      TransactionOperation? parentOperation, bool allowAutoInsert) {
    var canPropagate = hasReferencedEntities(
        resolveEntityResolutionRules(EntityResolutionRules.instanceAllEager));

    var op = TransactionOperationUpdate(
        name, canPropagate, operationExecutor, o,
        transaction: transaction, parentOperation: parentOperation);

    var idFieldsName = entityHandler.idFieldName(o);
    var id = entityHandler.getID(o);
    var fields = entityHandler.getFields(o);

    var changedFields = getEntityChangedFields(o);
    if (changedFields != null) {
      if (changedFields.isEmpty) {
        trackEntity(o);
        return op.finish(id);
      }

      fields.removeWhere((key, value) => !changedFields.contains(key));
    }

    return repositoryAdapter.doUpdate(op, o, id, fields,
        idFieldName: idFieldsName,
        allowAutoInsert: allowAutoInsert, preFinish: (id) {
      trackEntity(o);
      return id; // pre-finish
    });
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    throw UnsupportedError("Relationship not supported for: $this");
  }

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
          {Object? oId, TypeInfo? fieldType, Transaction? transaction}) =>
      <dynamic>[];

  @override
  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
          List<O>? os, String field,
          {List<dynamic>? oIds,
          TypeInfo? fieldType,
          Transaction? transaction}) =>
      <dynamic, Iterable<dynamic>>{};

  EntityRepository<E>? _resolveEntityRepository<E extends Object>(
      TypeInfo type) {
    var entityRepository = entityHandler.getEntityRepositoryByTypeInfo(type,
        entityRepositoryProvider: provider,
        entityHandlerProvider: entityHandler.provider);
    if (entityRepository != null) {
      return entityRepository as EntityRepository<E>;
    }

    var entityType = type.entityType;
    if (entityType == null) return null;

    var typeEntityHandler = entityHandler.getEntityHandler(type: entityType);

    if (typeEntityHandler != null) {
      entityRepository = typeEntityHandler.getEntityRepositoryByType(entityType,
          entityRepositoryProvider: provider,
          entityHandlerProvider: entityHandler.provider);
      if (entityRepository != null) {
        return entityRepository as EntityRepository<E>;
      }
    }

    return null;
  }

  @override
  FutureOr<List<dynamic>> storeAll(Iterable<O> os, {Transaction? transaction}) {
    checkNotClosed();

    return Transaction.executeBlock((transaction) {
      var result = os
          .map((o) => store(o, transaction: transaction))
          .toList(growable: false)
          .resolveAll();

      return result;
    }, transaction: transaction);
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var canPropagate =
        hasReferencedEntities(resolveEntityResolutionRules(null));

    var op = TransactionOperationDelete(
        name, canPropagate, operationExecutor, matcher,
        transaction: transaction);

    try {
      return repositoryAdapter.doDelete(op, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters, preFinish: (results) {
        return resolveEntities(op.transaction, results)
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
    return '$runtimeTypeNameUnsafe[$name]@${provider.runtimeTypeNameUnsafe}$info';
  }
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
  FutureOr<List<Initializable>> initializeDependencies() {
    return requiredEntityRepositoryProviders().resolveOther(requiredAdapters(),
        (requiredRepoProviders, requiredAdapters) {
      var dependencies = [...requiredRepoProviders, ...requiredAdapters];
      return dependencies;
    });
  }

  @override
  FutureOr<InitializationResult> initialize() {
    return adapter.resolveMapped((adapter) {
      var repositories = buildRepositories(adapter);

      return extraDependencies().resolveMapped((extraDependencies) {
        return InitializationResult.ok(this,
            dependencies: [adapter, ...repositories, ...extraDependencies]);
      });
    });
  }

  /// List of adapters that need to be initialized to [buildRepositories].
  FutureOr<List<DBAdapter>> requiredAdapters() => <DBAdapter>[];

  /// List of [EntityRepositoryProvider] that need to be initialized to [buildRepositories].
  FutureOr<List<EntityRepositoryProvider>>
      requiredEntityRepositoryProviders() => <EntityRepositoryProvider>[];

  /// Builds the [EntityRepository], called by [initialize].
  /// See [extraDependencies].
  List<EntityRepository> buildRepositories(A adapter);

  /// Some extra [Initializable] dependencies to be initialized after [initialize].
  /// See [initializeDependencies].
  FutureOr<List<Initializable>> extraDependencies() => <Initializable>[];

  @override
  bool close() {
    if (!super.close()) return false;

    _adapter?.close();
    _adapter = null;

    return true;
  }
}

/// A [DBAdapter] [Exception].
class DBAdapterException implements Exception, WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'DBAdapterException';

  /// The type of the exception.
  final String type;

  /// The exception message.
  final String message;

  /// The parent error/exception.
  /// Usually the native [Exception] or [Error] of the database.
  final Object? parentError;
  final StackTrace? parentStackTrace;

  /// The operation that caused the [Exception].
  final Object? operation;

  DBAdapterException(this.type, this.message,
      {this.parentError, this.parentStackTrace, this.operation})
      : super();

  String? resolveToString(Object? o, {String indent = '-- '}) {
    if (o == null) {
      return null;
    } else if (o is Iterable) {
      return '$indent${o.map(resolveToString).whereNotNull().join('\n$indent')}';
    } else if (o is TransactionOperation) {
      return o.toString();
    } else if (o is Function()) {
      return resolveToString(o());
    } else if (o is TransactionOperation) {
      return o.toString();
    } else {
      return o.toString();
    }
  }

  @override
  String toString() {
    var s = '$runtimeTypeNameSafe[$type]: $message';

    if (operation != null) {
      var operationStr = resolveToString(operation, indent: '    -- ');
      s += '\n  -- Operation>>\n$operationStr';
    }

    if (parentError != null) {
      s +=
          '\n  -- Parent ERROR>> [${parentError.runtimeTypeNameUnsafe}] $parentError';
    }

    return s;
  }
}
