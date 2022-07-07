import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

import 'bones_api_entity_adapter_mysql.dart';
import 'bones_api_test_utils.dart';

/// A [APITestConfigDockerDB] for `MySQL`.
class APITestConfigDockerMySQL extends APITestConfigDockerDB {
  APITestConfigDockerMySQL(Map<String, dynamic> apiConfig,
      {DockerHost? dockerHost, String? containerNamePrefix})
      : super(dockerHost ?? DockerHostLocal(), 'MySQL', apiConfig,
            containerNamePrefix: containerNamePrefix) {
    MySQLAdapter.boot();
  }

  @override
  Map<String, dynamic> get dbConfig => apiConfigMap['db']['mysql'];

  @override
  MySQLContainerConfig createDBContainerConfig(int dbPort) =>
      MySQLContainerConfig(
        dbUser: dbUser,
        dbPassword: dbPass,
        dbName: dbName,
        hostPort: dbPort,
      );

  @override
  Future<int> resolveFreePort(int port) =>
      getFreeListenPort(startPort: port - 100, endPort: port + 100)
          .then((freePort) => freePort ?? port);
}
