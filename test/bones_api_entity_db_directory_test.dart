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
  _runOpenFilesTest();
}

/// REGRESSION: `DBObjectDirectoryAdapter` read all the objects of a
/// `selectAll` in parallel (an async `readAsString` per object file), so
/// concurrent selects of a large table opened thousands of files at once
/// (measured: 24000), failing with `Too many open files` (`errno = 24`) under
/// the macOS default limit (256). The reads are now limited by a
/// `FileLimited` semaphore.
///
/// Runs `bones_api_entity_db_directory_open_files.dart` in a process limited
/// to 256 open files (`ulimit -n 256`): the number of open files can't be
/// reliably measured from inside the process (on macOS, `/dev/fd` lists at
/// most 128 entries).
void _runOpenFilesTest() {
  group('DBObjectDirectoryAdapter', () {
    test(
      'concurrent `selectAll`s within 256 open files',
      () async {
        var tempDir = Directory.systemTemp.createTempSync(
          'bones_api_tests_object_dir_open_files',
        );
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        var dart = Platform.resolvedExecutable;
        var script = 'test/bones_api_entity_db_directory_open_files.dart';

        var result = await Process.run('/bin/sh', [
          '-c',
          'ulimit -n 256 && exec "$dart" run $script "${tempDir.path}"',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
        expect('${result.stdout}', contains('OK:'));
      },
      testOn: '!windows',
      timeout: Timeout(Duration(minutes: 2)),
    );
  });
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
