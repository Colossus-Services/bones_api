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

  final String version;

  APITestConfigDockerPostgreSQL(Map<String, dynamic> apiConfig,
      {DockerHost? dockerHost,
      String? containerNamePrefix,
      this.version = 'latest'})
      : super(dockerHost ?? DockerHostLocal(), 'PostgreSQL', apiConfig,
            containerNamePrefix: containerNamePrefix) {
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
