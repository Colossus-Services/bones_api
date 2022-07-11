import 'package:async_extension/async_extension.dart';
import 'package:docker_commander/docker_commander_vm.dart';

import 'bones_api_entity_adapter_mysql.dart';
import 'bones_api_test_utils.dart';
import 'bones_api_test_utils_freeport.dart' as freeport;

/// A [APITestConfigDockerDB] for `MySQL`.
class APITestConfigDockerMySQL
    extends APITestConfigDockerDBSQL<MySQLContainer> {
  final bool forceNativePasswordAuthentication;

  APITestConfigDockerMySQL(Map<String, dynamic> apiConfig,
      {DockerHost? dockerHost,
      String? containerNamePrefix,
      this.forceNativePasswordAuthentication = false})
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
        forceNativePasswordAuthentication: forceNativePasswordAuthentication,
      );

  @override
  Future<int> resolveFreePort(int port) => freeport.resolveFreePort(port);

  @override
  Future<String?> runSQL(String sqlInline) => container!.runSQL(sqlInline);

  @override
  Future<List<String>> listTables() async {
    var res = await container!.runSQL('SHOW TABLES');
    if (res == null || res.isEmpty) return <String>[];

    var parts = res.split(RegExp(r'[\r\n]'));

    if (parts.isNotEmpty) {
      if (parts[0].contains('Tables_in_mydb')) {
        parts.removeAt(0);
      }

      parts = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return parts;
  }
}
