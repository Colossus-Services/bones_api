@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'bones_api_test_adapter.dart';

/// A fake [DBTestContainer] to run the same tests of [PostgreSQLAdapter]
/// with [MemorySQLAdapter].
class DBMemoryFakeTestContainer implements DBTestContainer<Object> {
  final defaultEntityRepositoryProvider = createEntityRepositoryProvider(
      true,
      (repoProvider, port) =>
          MemorySQLAdapter(parentRepositoryProvider: repoProvider),
      0);

  @override
  String get name => 'memory';

  @override
  Object? containerHandler;

  @override
  FutureOr<bool> setupContainerHandler() async {
    containerHandler = defaultEntityRepositoryProvider;
    return true;
  }

  @override
  FutureOr<bool> tearDownContainerHandler() async {
    containerHandler = null;
    return true;
  }

  @override
  Future<bool> start(int dbPort) async {
    return true;
  }

  @override
  Future<bool> waitReady() async => true;

  @override
  Future<String?> prepare() async => null;

  @override
  Future<String?> finalize() async => null;

  @override
  Future<bool> stop() async => true;

  @override
  Future<String?> runSQL(String sqlInline) async {
    print(sqlInline);
    return null;
  }

  @override
  Future<String?> createTableSQL(String sqlInline) async {
    return 'ok';
  }

  @override
  Future<String> listTables() async {
    var allRepositories =
        defaultEntityRepositoryProvider.allRepositories().values.toList();

    var tables = allRepositories.map((e) => e.name).toList();

    var memorySQLAdapter = defaultEntityRepositoryProvider.sqlAdapter;

    var tablesSchemes = await tables
        .map((t) => memorySQLAdapter.getTableScheme(t))
        .toList()
        .resolveAll();

    var relationshipTables = tablesSchemes
        .whereNotNull()
        .expand((e) => e.tableRelationshipReference.values);

    var allTables = [
      ...tables,
      ...relationshipTables.map((e) => e.relationshipTable)
    ];

    return allTables.map((e) => '|$e|').join('\n');
  }

  @override
  String get stdout => '';
}

Future<void> main() async {
  await _runTest(true);
  await _runTest(false);
}

Future<bool> _runTest(bool useReflection) => runAdapterTests(
      'DBMemory',
      DBMemoryFakeTestContainer(),
      0,
      (provider, dbPort) => MemorySQLAdapter(
        parentRepositoryProvider: provider,
      ),
      '"',
      'int',
      contains('ok'),
      entityByReflection: useReflection,
    );
