import 'package:bones_api/bones_api.dart';
import 'package:swiss_knife/swiss_knife.dart' show parseBool;

/// Base class for Object DB adapters.
///
/// A [DBObjectAdapter] implementation is responsible to connect to the database
/// and store/fecth/delete the objects.
///
/// All [DBObjectAdapter]s comes with a built-in connection pool.
///
/// ## Unique fields are not enforced
///
/// The [DBObjectAdapter]s ([DBObjectMemoryAdapter], `DBObjectDirectoryAdapter`
/// and `DBObjectGCSAdapter`) store each entity as an independent object (by
/// ID), and don't enforce the unique fields: [EntityField.unique] and
/// [EntityIndex.unique]. Two entities with the same unique value are both
/// stored, without an error.
///
/// Object storages (e.g. Google Cloud Storage, Amazon S3) are not designed
/// for that: there's no index over the objects' values, nor transactions over
/// multiple objects. Checking by scanning the stored objects is slow and,
/// with concurrent writers, not reliable.
///
/// When the uniqueness is required, use a SQL adapter (the database's
/// `UNIQUE` constraints: `DBPostgreSQLAdapter`, `DBMySQLAdapter`,
/// `DBSQLiteAdapter`), or [DBSQLMemoryAdapter] (in memory, it checks them).
abstract class DBObjectAdapter<C extends Object> extends DBAdapter<C> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBAdapter.boot();
    DBObjectMemoryAdapter.boot();
  }

  static final DBAdapterRegister<Object, DBObjectAdapter<Object>>
  adapterRegister = DBAdapter.adapterRegister.createRegister();

  static List<String> get registeredAdaptersNames =>
      adapterRegister.registeredAdaptersNames;

  static List<Type> get registeredAdaptersTypes =>
      adapterRegister.registeredAdaptersTypes;

  static void registerAdapter<C extends Object, A extends DBObjectAdapter<C>>(
    List<String> names,
    Type type,
    DBAdapterInstantiator<C, A> adapterInstantiator,
  ) {
    boot();
    adapterRegister.registerAdapter(names, type, adapterInstantiator);
  }

  static DBAdapterInstantiator<C, A>?
  getAdapterInstantiator<C extends Object, A extends DBObjectAdapter<C>>({
    String? name,
    Type? type,
  }) => adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
  getAdapterInstantiatorsFromConfig<
    C extends Object,
    A extends DBObjectAdapter<C>
  >(Map<String, dynamic> config) =>
      adapterRegister.getAdapterInstantiatorsFromConfig<C, A>(config);

  static bool? parseConfigLog(Map<String, dynamic>? config) {
    var log = config?['log'];
    return parseBool(log);
  }

  /// The `toEncodable` of the JSON encoding of a stored object: converts a
  /// value that is not JSON encodable (e.g. a [DateTime], an enum or a
  /// `Decimal`) as [Json.toJson] (parsed back by the entity's handler).
  static Object? toEncodableJson(Object? o) => Json.toJson(o);

  final bool log;

  DBObjectAdapter(
    super.name,
    super.minConnections,
    super.maxConnections,
    super.capability, {
    bool generateTables = false,
    Object? populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.connectivity,
    super.workingPath,
    this.log = false,
  }) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<A> fromConfig<C extends Object, A extends DBObjectAdapter<C>>(
    Map<String, dynamic> config, {
    int minConnections = 1,
    int maxConnections = 3,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
        "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}",
      );
    }

    return DBAdapter.instantiateAdaptor<C, A>(
      instantiators,
      config,
      minConnections: minConnections,
      maxConnections: maxConnections,
      parentRepositoryProvider: parentRepositoryProvider,
      workingPath: workingPath,
    );
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[
      if (parentRepositoryProvider != null) parentRepositoryProvider,
    ];
  }
}

/// Error thrown by [DBObjectAdapter] operations.
class DBObjectAdapterException extends DBAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectAdapterException';

  DBObjectAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}
