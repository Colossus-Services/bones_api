import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

import 'bones_api_entity_db_postgres.dart';
import 'bones_api_extension.dart';
import 'bones_api_test_utils_config.dart';
import 'bones_api_test_utils_freeport.dart' as freeport;

/// A [APITestConfigDockerDB] for `PostgreSQL`.
class APITestConfigDockerPostgreSQL
    extends APITestConfigDockerDBSQL<PostgreSQLContainer> {
  @override
  String get runtimeTypeNameSafe => 'APITestConfigDockerPostgreSQL';

  /// Runtime Postgres configuration: `-c port=$postgresPort`
  int? postgresPort;

  /// Runtime Postgres configuration: `-c max_connections=$maxConnections`
  int? maxConnections;

  /// Runtime Postgres configuration: `-c log_statement=$logStatement`
  String? logStatement;

  /// Further runtime settings, each passed as `-c key=value`.
  final Map<String, String>? settings;

  /// Arguments to `initdb` (`POSTGRES_INITDB_ARGS`).
  final String? initdbArgs;

  /// A throwaway database: durability off and the data directory in memory.
  /// See [PostgreSQLContainerConfig.ephemeral].
  final bool ephemeral;

  /// More environment variables for the container.
  final Map<String, String>? extraEnvironment;

  final String version;

  APITestConfigDockerPostgreSQL(
    Map<String, dynamic> apiConfig, {
    DockerHost? dockerHost,
    super.containerNamePrefix,
    this.postgresPort,
    this.maxConnections,
    this.logStatement,
    this.settings,
    this.initdbArgs,
    this.ephemeral = false,
    this.extraEnvironment,
    this.version = 'latest',
    super.cleanContainer,
    super.dockerChosenPort,
    super.runOptions,
  }) : super(dockerHost ?? DockerHostLocal(), 'PostgreSQL', apiConfig) {
    DBPostgreSQLAdapter.boot();
  }

  @override
  Map<String, dynamic> get dbConfig =>
      apiConfigMap.getAsMap('db')?['postgres'] ?? <String, dynamic>{};

  @override
  PostgreSQLContainerConfig createDBContainerConfig(int dbPort) =>
      PostgreSQLContainerConfig(
        version: version,
        pgUser: dbUser,
        pgPassword: dbPass,
        pgDatabase: dbName,
        hostPort: dbPort,
        postgresPort: postgresPort,
        maxConnections: maxConnections,
        logStatement: logStatement,
        settings: settings,
        initdbArgs: initdbArgs,
        ephemeral: ephemeral,
        extraEnvironment: extraEnvironment,
        options: runOptions,
      );

  @override
  Future<int> resolveFreePort(int port) => freeport.resolveFreePort(port);

  @override
  Future<String?> runSQL(String sqlInline) => container!.runSQL(sqlInline);

  @override
  Future<List<String>> listTables() async {
    var res = await container!.runSQL(r'\d');
    if (res == null || res.isEmpty) return <String>[];

    var body = res.split(RegExp(r'--+\+--+\+--+\+'))[1];
    var parts = body.split(RegExp(r'[\r\n]'));

    var names = parts
        .where((p) => p.contains(RegExp(r'\s+\|\s+\w+\s+\|')))
        .map((p) => p.split(RegExp(r'\s+\|\s+'))[1].trim())
        .toList();

    return names;
  }
}
