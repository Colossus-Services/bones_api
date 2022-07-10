import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_base.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_config.dart';
import 'bones_api_root_starter.dart';
import 'bones_api_utils_collections.dart';

final _log = logging.Logger('APITestConfig');

/// An [APIRoot] test configuration.
class APITestConfig {
  final Map<String, dynamic> apiConfigMap;

  APITestConfig(Map<String, dynamic> apiConfig)
      : apiConfigMap = deepCopyMap<String, dynamic>(apiConfig)!;

  /// Resolves if this configuration test is supported.
  /// See [isSupported].
  FutureOr<bool> resolveSupported() => true;

  /// Returns `true` if this test configuration is supported.
  /// See [isUnsupported].
  bool get isSupported => true;

  /// Alias to ![isSupported];
  bool get isUnsupported => !isSupported;

  /// If [isUnsupported] is `true` should return a reason message.
  /// This can be used in tests to show the `skip` reason.
  String? get unsupportedReason => isUnsupported ? 'Unsupported: $this' : null;

  /// Returns `true` if already started.
  bool get isStarted => true;

  /// Returns `true` if starting.
  bool get isStarting => false;

  /// The start operation.
  FutureOr<bool> start() => true;

  /// Returns `true` if stopped.
  bool get isStopped => false;

  /// The stop operation.
  FutureOr<bool> stop() => true;

  @override
  String toString() => '$runtimeType$apiConfigMap';

  /// Creates an [APIRootStarter] using this [APITestConfig] as pre-initialization and stopper.
  APIRootStarter<A> createAPIRootStarter<A extends APIRoot>(
      A Function(APIConfig? apiConfig) apiRootInstantiator) {
    return APIRootStarter.fromInstantiator(
      apiRootInstantiator,
      apiConfig: () => APIConfig(apiConfigMap),
      preInitializer: () => start(),
      stopper: () => stop(),
    );
  }
}

extension APITestConfigExtension on Iterable<APITestConfig> {
  FutureOr<List<bool>> resolveSupported() =>
      map((e) => e.resolveSupported()).resolveAll();
}

/// A base implementation of an [APITestConfig]. See [startImpl] and [stopImpl].
abstract class APITestConfigBase extends APITestConfig {
  APITestConfigBase(Map<String, dynamic> apiConfigMap) : super(apiConfigMap);

  bool? _supported;

  /// Resolves if this configuration test is supported.
  /// See [isSupported].
  @override
  FutureOr<bool> resolveSupported() {
    var supported = _supported;
    if (supported != null) return supported;

    return resolveSupportedImpl().resolveMapped((ok) {
      _supported = ok;
      return ok;
    });
  }

  /// The [resolveSupported] implementation.
  FutureOr<bool> resolveSupportedImpl() => true;

  @override
  bool get isSupported => _supported ?? false;

  @override
  bool get isStarted => _started ?? false;

  @override
  bool get isStarting {
    var started = _started;
    return started != null && !started;
  }

  bool? _started;

  @override
  FutureOr<bool> start() {
    if (isStarted) {
      throw StateError("Already started!");
    } else if (isStarting) {
      throw StateError("Already starting!");
    }

    return startImpl();
  }

  /// The [start] implementation.
  FutureOr<bool> startImpl();

  @override
  bool get isStopped => _stopped;

  bool _stopped = false;

  @override
  FutureOr<bool> stop() async {
    if (_started == null) return false;
    if (_stopped) return true;

    bool ok = await stopImpl();

    _stopped = true;

    _log.info('** STOPPED[$ok]> $this');
    return ok;
  }

  /// The [stop] implementation.
  FutureOr<bool> stopImpl();
}

/// An [APITestConfig] for `Docker` containers.
abstract class APITestConfigDocker<C extends DockerContainer>
    extends APITestConfigBase {
  /// The [DockerHost] for [DockerCommander].
  DockerHost dockerHost;

  APITestConfigDocker(this.dockerHost, Map<String, dynamic> apiConfigMap)
      : super(apiConfigMap);

  /// The [DockerContainer] that was started.
  C? container;

  @override
  FutureOr<bool> resolveSupportedImpl() =>
      DockerHost.isDaemonRunning(dockerHost);

  @override
  String? get unsupportedReason =>
      isUnsupported ? 'Docker Daemon NOT running!' : null;

  @override
  Future<bool> startImpl() async {
    _started = false;

    var dockerCommander = DockerCommander(dockerHost);

    await dockerCommander.ensureInitialized();

    var daemonOk = await dockerCommander.isDaemonRunning();
    if (!daemonOk) {
      throw StateError("Docker Daemon not running!");
    }

    _log.info('** Creating container... >> $this');

    var container = this.container = await createContainer(dockerCommander);

    var ready = await container.waitReady();
    if (!ready) {
      throw StateError("Container not ready!");
    }

    _started = true;

    var logsStdout = await container.catLogs(stderr: false);
    var logsStderr = await container.catLogs(stderr: true);

    _log.info('Container $container LOGS:\n'
        '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< [LOGS STDOUT]\n'
        '$logsStdout\n'
        '======================================================== [LOGS STDERR]\n'
        '$logsStderr\n'
        '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> [LOGS END]');

    _log.info('** STARTED> $this');

    return true;
  }

  /// [DockerContainer] creation implementation.
  Future<C> createContainer(DockerCommander dockerCommander);

  @override
  FutureOr<bool> stopImpl() => stopContainer();

  /// The timeout to stop the [container].
  Duration get stopContainerTimeout => Duration(seconds: 60);

  /// Stops the [container]. Called by [stopImpl].
  FutureOr<bool> stopContainer() {
    var container = this.container;
    if (container == null) return false;
    return container.stop(timeout: stopContainerTimeout);
  }

  /// The STDOUT [Output] of the [container].
  Output? get stdout => container?.stdout;

  /// The [stdout] as [String].
  String get stdoutAsString => stdout?.asString ?? '';

  /// The STDERR [Output] of the [container].
  Output? get stderr => container?.stderr;

  /// The [stderr] as [String].
  String get stderrAsString => stderr?.asString ?? '';
}

/// Mixin for [APITestConfig] with DB configuration.
mixin APITestConfigDBMixin {
  /// The DB type/name.
  String get dbType;

  /// The database configuration [Map].
  Map<String, dynamic> get dbConfig;

  /// The [dbConfig] `username`.
  String get dbUser => dbConfig['username'];

  /// The [dbConfig] `password`.
  String get dbPass => dbConfig['password'];

  /// The [dbConfig] `database` name.
  String get dbName => dbConfig['database'];

  /// The [dbConfig] `port` (database exposed port for connections).
  FutureOr<int> get dbPort {
    var port = dbConfig['port'];

    if (port is String) {
      port = int.tryParse(port.trim()) ?? 0;
    }

    if (port is int) {
      if (port > 0) return port;

      if (port > -1000) {
        port = 5000;
      } else {
        port = -port;
      }

      return resolveFreePort(port).then((p) {
        dbConfig['port'] = p;
        return p;
      });
    } else if (port == '?' || port == '*') {
      return resolveFreePort(5000).then((p) {
        dbConfig['port'] = p;
        return p;
      });
    }

    throw StateError("Can't resolve `dbPort`: $port");
  }

  /// Resolves the database port.
  FutureOr<int> resolveDbPort(int port) =>
      resolveFreePort(port).resolveMapped((p) {
        dbConfig['port'] = p;
        return p;
      });

  /// Resolves a free-port to use for the database.
  FutureOr<int> resolveFreePort(int port);

  /// List the database tables names.
  FutureOr<List<String>> listTables() =>
      throw UnsupportedError("`listTables` not implemented");
}

/// A base class for [APITestConfig] with database.
abstract class APITestConfigDB extends APITestConfig with APITestConfigDBMixin {
  @override
  final String dbType;

  APITestConfigDB(this.dbType, Map<String, dynamic> apiConfig)
      : super(apiConfig);
}

/// A [APITestConfig] with in-memory database.
class APITestConfigDBMemory extends APITestConfigDB {
  APITestConfigDBMemory(Map<String, dynamic> apiConfig)
      : super('memory', apiConfig);

  @override
  Map<String, dynamic> get dbConfig => apiConfigMap['db']['memory'];

  @override
  FutureOr<int> resolveFreePort(int port) => 5000;
}

/// Mixin for [APITestConfig] with DB configuration + SQL.
mixin APITestConfigDBSQLMixin on APITestConfigDBMixin {
  /// Runs a SQL in the DB. The SQL shouldn't have multiple lines.
  Future<String?> runSQL(String sqlInline);

  /// Perform a create table SQL.
  Future<List<String?>> createTableSQL(String sqls) async {
    var list = SQLAdapter.extractTableSQLs(sqls);
    if (list.isEmpty) return <String>[];

    var results = Future.wait(list.map(runSQL));
    return results;
  }
}

/// A base class for [APITestConfig] with database with SQL.
abstract class APITestConfigDBSQL extends APITestConfigDB {
  APITestConfigDBSQL(String dbType, Map<String, dynamic> apiConfig)
      : super(dbType, apiConfig);

  /// Runs a SQL in the DB. The SQL shouldn't have multiple lines.
  Future<String?> runSQL(String sqlInline);

  /// Perform a create table SQL.
  Future<List<String?>> createTableSQL(String sqls) async {
    var list = SQLAdapter.extractTableSQLs(sqls);
    if (list.isEmpty) return <String>[];

    var results = Future.wait(list.map(runSQL));
    return results;
  }
}

/// A base class for [APITestConfig] `Docker` database containers.
abstract class APITestConfigDockerDB<C extends DockerContainer>
    extends APITestConfigDocker<C>
    with APITestConfigDBMixin
    implements APITestConfigDB {
  /// The DB type/name.
  @override
  final String dbType;

  /// The container name prefix.
  final String containerNamePrefix;

  APITestConfigDockerDB(
      DockerHost dockerHost, this.dbType, Map<String, dynamic> apiConfig,
      {String? containerNamePrefix})
      : containerNamePrefix =
            containerNamePrefix ?? 'api_test_${dbType.trim().toLowerCase()}',
        super(dockerHost, apiConfig);

  @override
  Future<C> createContainer(DockerCommander dockerCommander) async {
    var dbPort = await this.dbPort;

    _log.info('Initializing $dbType container at port: $dbPort');

    var containerConfig = createDBContainerConfig(dbPort);

    var container = await containerConfig.run(dockerCommander,
        name: '${containerNamePrefix}_$dbPort', cleanContainer: true);

    _log.info('Container initialized: $container');

    return container;
  }

  /// The [DockerContainerConfig] instantiator.
  DockerContainerConfig<C> createDBContainerConfig(int dbPort);
}

/// A base class for [APITestConfigDockerDB] with SQL support.
abstract class APITestConfigDockerDBSQL<C extends DockerContainer>
    extends APITestConfigDockerDB<C> with APITestConfigDBSQLMixin {
  APITestConfigDockerDBSQL(
      DockerHost dockerHost, String dbType, Map<String, dynamic> apiConfig,
      {String? containerNamePrefix})
      : super(dockerHost, dbType, apiConfig,
            containerNamePrefix: containerNamePrefix);
}
