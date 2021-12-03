@Tags(['docker', 'postgre', 'entities'])
@Timeout(Duration(seconds: 180))
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_adapter_postgre.dart';
import 'package:docker_commander/docker_commander.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:test/test.dart';

import 'bones_api_test_adapter.dart';

final dbUser = 'postgre';
final dbPass = '123456';
final dbName = 'postgre';

class PostgreTestContainer extends DBTestContainer {
  late final PostgreSQLContainerConfig containerConfig;
  late PostgreSQLContainer container;

  @override
  Future<bool> start(DockerCommander dockerCommander, int dbPort) async {
    containerConfig = PostgreSQLContainerConfig(
        pgUser: dbUser,
        pgPassword: dbPass,
        pgDatabase: dbName,
        hostPort: dbPort);

    container = await containerConfig.run(dockerCommander,
        name: 'dc_test_postgre_$dbPort', cleanContainer: true);
    return true;
  }

  @override
  Future<bool> waitReady() => container.waitReady();

  static const String configFile = '/var/lib/postgresql/data/postgresql.conf';

  @override
  Future<String?> prepare() async {
    var out = await container.execCat(configFile);
    return '$configFile: ${out?.length}';
  }

  @override
  Future<String?> finalize() async {
    var out = await container.psqlCMD('\\d');
    return out;
  }

  @override
  Future<bool> stop() => container.stop(timeout: Duration(seconds: 30));

  @override
  Future<String?> runSQL(String sqlInline) => container.runSQL(sqlInline);

  @override
  Future<String> listTables() async {
    var out = await container.psqlCMD('\\d');
    return out ?? '';
  }

  @override
  String get stdout => container.stdout?.asString ?? '';
}

void main() {
  _runTest(true);
  _runTest(false);
}

void _runTest(bool useReflection) {
  runAdapterTests(
    'PostgreSQL',
    PostgreTestContainer(),
    5432,
    (provider, dbPort) => PostgreSQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      port: dbPort,
      parentRepositoryProvider: provider,
    ),
    '"',
    'bigint',
    contains('CREATE TABLE'),
    entityByReflection: useReflection,
  );
}
