import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

import 'bones_api_entity_adapter_mysql.dart';
import 'bones_api_test_utils.dart';

/// A [APITestConfigDockerDB] for `MySQL`.
class APITestConfigDockerMySQL
    extends APITestConfigDockerDBSQL<MySQLContainer> {
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

  @override
  Future<String?> runSQL(String sqlInline) => container!.runSQL(sqlInline);

  @override
  Future<List<String>> listTables() async {
    var res = await container!.runSQL('SHOW TABLES');
    if (res == null || res.isEmpty) return <String>[];

    var parts = res.split(RegExp(r'[\r\n]'));

    return parts;
  }
}
