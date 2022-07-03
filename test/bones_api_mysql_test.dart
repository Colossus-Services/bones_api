@TestOn('vm')
@Tags(['docker', 'mysql', 'slow'])
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

class MySQLTestContainer extends DBTestContainerDocker {
  @override
  String get name => 'mysql';

  late final MySQLContainerConfig containerConfig;
  late MySQLContainer container;

  @override
  Future<bool> start(int dbPort) async {
    containerConfig = MySQLContainerConfig(
      dbUser: dbUser,
      dbPassword: dbPass,
      dbName: dbName,
      hostPort: dbPort,
      forceNativePasswordAuthentication: true,
    );

    container = await containerConfig.run(containerHandler!,
        name: 'dc_test_mysql_$dbPort', cleanContainer: true);
    return true;
  }

  @override
  Future<bool> waitReady() => container.waitReady();

  static const String configFile = '/etc/mysql/my.cnf';
  static const String configDirectory = '/etc/mysql/conf.d';

  @override
  Future<String?> prepare() async {
    var out = await container.execCat(configFile);
    var out2 = await container
        .execAndWaitStdoutAsString('ls', ['-al', configDirectory]);
    return '\n*** $configFile:\n$out\n*** configDirectory:\n$out2';
  }

  @override
  Future<String?> finalize() async {
    var out1 = await container.mysqlCMD('SHOW TABLES');
    var out2 = await container.mysqlCMD('select * from `user`;');
    return '$out1\n$out2';
  }

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

Future<void> main() async {
  await _runTest(false);
  await _runTest(true);
}

Future<bool> _runTest(bool useReflection) => runAdapterTests(
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
      entityByReflection: useReflection,
    );
