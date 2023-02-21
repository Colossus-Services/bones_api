@TestOn('vm')
@Tags(['docker', 'postgres', 'entities', 'slow'])
@Timeout(Duration(minutes: 4))
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:bones_api/bones_api_test_postgres.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

final dbUser = 'postgres';
final dbPass = '123456';
final dbName = 'postgres';

class PostgresTestConfig extends APITestConfigDockerPostgreSQL {
  @override
  String get runtimeTypeNameSafe => 'PostgresTestConfig';

  PostgresTestConfig()
      : super({
          'db': {
            'postgres': {
              'username': dbUser,
              'password': dbPass,
              'database': dbName,
              'port': -5432,
            }
          }
        }, containerNamePrefix: 'bones_api_test_postgres');
}

Future<void> main() async {
  await _runTest(true);
  await _runTest(false);
}

Future<bool> _runTest(bool useReflection) => runAdapterTests(
      'PostgreSQL',
      PostgresTestConfig(),
      (provider, dbPort) => DBPostgreSQLAdapter(
        dbName,
        dbUser,
        password: dbPass,
        port: dbPort,
        parentRepositoryProvider: provider,
      ),
      (provider, dbPort) =>
          DBMemoryObjectAdapter(parentRepositoryProvider: provider),
      '"',
      'bigint',
      entityByReflection: useReflection,
    );
