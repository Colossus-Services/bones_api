@Timeout(Duration(seconds: 180))
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_adapter_mysql.dart';
import 'package:docker_commander/docker_commander.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:test/test.dart';

import 'bones_api_test_adapter.dart';

final dbUser = 'myuser';
final dbPass = 'mypass';
final dbName = 'mydb';

class MySQLTestContainer extends DBTestContainer {
  late final MySQLContainerConfig containerConfig;
  late MySQLContainer container;

  @override
  Future<bool> start(DockerCommander dockerCommander, int dbPort) async {
    containerConfig = MySQLContainerConfig(
      dbUser: dbUser,
      dbPassword: dbPass,
      dbName: dbName,
      hostPort: dbPort,
      forceNativePasswordAuthentication: true,
    );

    container = await containerConfig.run(dockerCommander,
        name: 'dc_test_mysql_$dbPort', cleanContainer: true);
    return true;
  }

  @override
  Future<bool> waitReady() => container.waitReady();

  @override
  Future<bool> stop() => container.stop(timeout: Duration(seconds: 30));

  @override
  Future<String?> runSQL(String sqlInline) => container.runSQL(sqlInline);

  @override
  Future<String> listTables() async {
    var out = await container.mysqlCMD('SHOW TABLES');
    return out ?? '';
  }

  @override
  String get stdout => container.stdout?.asString ?? '';
}

void main() {
  _runTest(false);
  _runTest(true);
}

void _runTest(bool useReflection) {
  runAdapterTests(
    'MySQL',
    MySQLTestContainer(),
    3306,
    (provider, dbPort) => MySQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      host: '127.0.0.1',
      port: dbPort,
      parentRepositoryProvider: provider,
    ),
    '`',
    'bigint unsigned',
    anyOf(isNull, isEmpty),
    entityHandlerByReflection: useReflection,
  );
}
