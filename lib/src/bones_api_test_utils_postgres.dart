import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

import 'bones_api_entity_adapter_postgres.dart';
import 'bones_api_test_utils.dart';

/// A [APITestConfigDockerDB] for `PostgreSQL`.
class APITestConfigDockerPostgreSQL extends APITestConfigDockerDB {
  APITestConfigDockerPostgreSQL(Map<String, dynamic> apiConfig,
      {DockerHost? dockerHost, String? containerNamePrefix})
      : super(dockerHost ?? DockerHostLocal(), 'PostgreSQL', apiConfig,
            containerNamePrefix: containerNamePrefix) {
    PostgreSQLAdapter.boot();
  }

  @override
  Map<String, dynamic> get dbConfig => apiConfigMap['db']['postgres'];

  @override
  PostgreSQLContainerConfig createDBContainerConfig(int dbPort) =>
      PostgreSQLContainerConfig(
        pgUser: dbUser,
        pgPassword: dbPass,
        pgDatabase: dbName,
        hostPort: dbPort,
      );

  @override
  Future<int> resolveFreePort(int port) =>
      getFreeListenPort(startPort: port - 100, endPort: port + 100)
          .then((freePort) => freePort ?? port);
}
