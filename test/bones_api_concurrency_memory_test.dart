@TestOn('vm')
@Tags(['concurrency'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_directory.dart';
import 'package:bones_api/bones_api_db_gcp.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:test/test.dart';

import 'bones_api_concurrency_tests_base.dart';
import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';
import 'bones_api_test_fake_gcs.dart';

/// The `Store`, `Address`, `Role`, `UserInfo` and `User` repositories over an
/// object adapter.
class _ObjectProvider extends DBEntityRepositoryProvider<DBAdapter> {
  final DBAdapter Function(EntityRepositoryProvider provider) adapterCreator;

  _ObjectProvider(this.adapterCreator);

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBAdapter> buildAdapter() => adapterCreator(this);

  List<EntityRepository<Object>>? _repositories;

  @override
  List<EntityRepository<Object>> buildRepositories(
    DBAdapter adapter,
  ) => _repositories ??= [
    DBEntityRepository<Store>(
      adapter,
      'store',
      Store$reflection().entityHandler,
    ),
    DBEntityRepository<Address>(
      adapter,
      'address',
      Address$reflection().entityHandler,
    ),
    DBEntityRepository<Role>(adapter, 'role', Role$reflection().entityHandler),
    DBEntityRepository<UserInfo>(
      adapter,
      'user_info',
      UserInfo$reflection().entityHandler,
    ),
    DBEntityRepository<User>(adapter, 'user', User$reflection().entityHandler),
  ];
}

void main() {
  runConcurrencyTests(
    'DBSQLMemoryAdapter',
    setUp: () async {
      var provider = createEntityRepositoryProvider(
        true,
        (p, dbPort, dbConfig) => DBSQLMemoryAdapter(
          parentRepositoryProvider: p,
          generateTables: true,
        ),
        0,
        null,
      );
      await provider.ensureInitialized();
      return provider;
    },
    // An abort reverts its tables to a version (also the later writes of
    // concurrent transactions):
    capabilities: const ConcurrencyCapabilities(isolatedRollback: false),
  );

  late Directory sqliteDir;

  var sqlite = ConcurrencySQLProviders(
    (p, dbPort, dbConfig) => DBSQLiteAdapter(
      '${sqliteDir.path}/db.sqlite',
      parentRepositoryProvider: p,
      generateTables: true,
    ),
  );

  runConcurrencyTests(
    'DBSQLiteAdapter',
    setUp: () {
      sqliteDir = Directory.systemTemp.createTempSync('bones_api_cc_sqlite_');
      return sqlite.setUp();
    },
    tearDown: () {
      sqlite.close();
      sqliteDir.deleteSync(recursive: true);
    },
  );

  runConcurrencyTests(
    'DBObjectMemoryAdapter',
    setUp: () async {
      var provider = _ObjectProvider(
        (p) => DBObjectMemoryAdapter(parentRepositoryProvider: p),
      );
      await provider.ensureInitialized();
      return provider;
    },
    // An abort reverts its tables to a version (also the later writes of
    // concurrent transactions), as `DBSQLMemoryAdapter`:
    capabilities: const ConcurrencyCapabilities(
      generatesIDs: false,
      uniqueEnforced: false,
      isolatedRollback: false,
    ),
  );

  late Directory objectsDir;

  runConcurrencyTests(
    'DBObjectDirectoryAdapter',
    setUp: () async {
      objectsDir = Directory.systemTemp.createTempSync('bones_api_cc_dir_');
      var provider = _ObjectProvider(
        (p) =>
            DBObjectDirectoryAdapter(objectsDir, parentRepositoryProvider: p),
      );
      await provider.ensureInitialized();
      return provider;
    },
    tearDown: () => objectsDir.deleteSync(recursive: true),
    // Writes immediately (not rolled back on abort):
    capabilities: const ConcurrencyCapabilities(
      generatesIDs: false,
      uniqueEnforced: false,
      rollback: false,
    ),
  );

  runConcurrencyTests(
    'DBObjectGCSAdapter (fake GCS)',
    setUp: () async {
      var gcs = FakeGCS('cc-bucket');
      var provider = _ObjectProvider(
        (p) => DBObjectGCSAdapter(
          gcs.client,
          'cc-project',
          gcs.bucket,
          parentRepositoryProvider: p,
        ),
      );
      await provider.ensureInitialized();
      return provider;
    },
    // Writes immediately (not rolled back on abort); a partial update is a
    // read-modify-write (concurrent ones can lose an update):
    capabilities: const ConcurrencyCapabilities(
      generatesIDs: false,
      uniqueEnforced: false,
      rollback: false,
      concurrentPartialUpdates: false,
    ),
  );
}
