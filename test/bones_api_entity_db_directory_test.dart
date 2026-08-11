@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/bones_api_db_directory.dart';
import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';

class MemoryTestConfig extends APITestConfigDBSQLMemory {
  MemoryTestConfig()
    : super({
        'db': {
          'sql.memory': {'port': 0},
        },
      });
}

Future<void> main() async {
  await _runTest(true, false);
  await _runTest(false, false);
  await _runTest(true, true);
  await _runTest(false, true);

  _runStoreVisibilityTest();
}

/// REGRESSION: `DBObjectDirectoryAdapter._saveObject` used to be `async`, and
/// `doInsert`/`doUpdate` dropped its `Future`. Since every reader in that
/// adapter inspects the filesystem synchronously, a `store` could return
/// before its object was on disk — and `selectAll` would then *silently omit*
/// it, because a not-yet-written file reads back as `null` and is discarded by
/// `resolveAllNotNull`.
///
/// That is what made `Pagination [objectAdapter]` flaky on CI: entries went
/// missing from the result, and which ones varied per run. Confirmed by adding
/// a 30ms delay before the (un-awaited) write, which reproduces that failure
/// exactly.
///
/// Note this test only *fails* where the write is slow enough to lose the
/// race — it does not on a fast local disk. It is kept as a cheap statement of
/// the invariant; `Pagination [objectAdapter]` remains the sensitive guard.
void _runStoreVisibilityTest() {
  group('DBObjectDirectoryAdapter', () {
    test('a stored object is immediately visible', () async {
      var tempDir = Directory.systemTemp.createTempSync(
        'bones_api_tests_object_dir_visibility',
      );

      var provider = createEntityRepositoryProvider2(
        true,
        (p, dbPort, dbConfig) =>
            DBObjectDirectoryAdapter(tempDir, parentRepositoryProvider: p),
        0,
        null,
      );

      addTearDown(() {
        provider.close();
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await provider.ensureInitialized();

      var photoRepo = provider.photoAPIRepository;

      // Big enough to give a slow filesystem a chance to lose the race:
      var data = Uint8List(512 * 1024);

      var ids = <String>[];

      for (var i = 1; i <= 4; ++i) {
        var id = 'PG-SYNC-0$i';
        ids.add(id);

        expect(await photoRepo.store(Photo.fromData(data, id: id)), equals(id));

        expect(
          await photoRepo.selectByID(id),
          isNotNull,
          reason: '`$id` not readable right after `store`',
        );
      }

      var all = await photoRepo.selectAll();

      expect(
        all.map((e) => e.id).where(ids.contains).toList()..sort(),
        equals(ids),
        reason: '`selectAll` dropped a stored object',
      );
    });
  });
}

Future<bool> _runTest(bool useReflection, bool populateSource) {
  final tempObjectDir = Directory.systemTemp.createTempSync(
    "bones_api_tests_object_dir",
  );

  return runAdapterTests(
    'DBSQLMemory+obj.dir',
    MemoryTestConfig(),
    (provider, dbPort, dbConfig) {
      var populate = dbConfig?['populate'] as Map?;
      return DBSQLMemoryAdapter(
        parentRepositoryProvider: provider,
        generateTables: false,
        checkTables: false,
        populateSource: populate?['source'],
        populateSourceVariables: populate?['variables'],
      );
    },
    (provider, dbPort, dbConfig) =>
        DBObjectDirectoryAdapter(
            tempObjectDir,
            parentRepositoryProvider: provider,
          )
          ..onClose.listen((_) {
            tempObjectDir.deleteSync(recursive: true);
          }),
    '"',
    'int',
    entityByReflection: useReflection,
    generateTables: false,
    checkTables: false,
    populateSource: populateSource,
  );
}
