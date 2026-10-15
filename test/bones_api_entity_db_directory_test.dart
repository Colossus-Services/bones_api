@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
import 'dart:io';
import 'dart:isolate';
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
  _runConcurrentDeletesTest();
}

/// The reads of a select wait for the [DBObjectDirectoryAdapter.fileLimited]
/// semaphore, so an object can be deleted between its listing and its read:
/// it's skipped (not a `PathNotFoundException`). Concurrent deletes of the
/// same object: one deletes it, the others delete nothing (no exception).
void _runConcurrentDeletesTest() {
  group('DBObjectDirectoryAdapter', () {
    late Directory tempDir;
    late TestEntityRepositoryProvider2 provider;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'bones_api_tests_object_dir_deletes',
      );
      provider = createEntityRepositoryProvider2(
        true,
        (p, dbPort, dbConfig) =>
            DBObjectDirectoryAdapter(tempDir, parentRepositoryProvider: p),
        0,
        null,
      );
      await provider.ensureInitialized();
    });

    tearDown(() {
      DBObjectDirectoryAdapter.fileLimited.setSemaphoreLimit(
        FileLimited.defaultSemaphoreLimit,
      );
      provider.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('concurrent deletes and selects', () async {
      var photoRepo = provider.photoAPIRepository;

      const total = 300;
      var data = Uint8List(64);
      for (var i = 0; i < total; ++i) {
        await photoRepo.store(Photo.fromData(data, id: 'PD-$i'));
      }

      var deletedIDs = [for (var i = 0; i < total; i += 2) 'PD-$i'];

      var selects = [
        for (var i = 0; i < 5; ++i) Future.sync(() => photoRepo.selectAll()),
      ];

      // Each object deleted twice, concurrently:
      var deletes = [
        for (var id in deletedIDs) ...[
          Future.sync(() => photoRepo.deleteByID(id)),
          Future.sync(() => photoRepo.deleteByID(id)),
        ],
      ];

      var selectResults = await Future.wait(selects);
      var deleteResults = await Future.wait(deletes);

      for (var all in selectResults) {
        expect(all.length, inInclusiveRange(total - deletedIDs.length, total));
      }

      // Each object deleted exactly once:
      for (var i = 0; i < deleteResults.length; i += 2) {
        var deleted = [
          deleteResults[i],
          deleteResults[i + 1],
        ].nonNulls.toList();
        expect(deleted, hasLength(1), reason: deletedIDs[i ~/ 2]);
        expect(deleted.single.id, equals(deletedIDs[i ~/ 2]));
      }

      var remaining = await photoRepo.selectAll();
      expect(remaining.length, equals(total - deletedIDs.length));
      expect(await photoRepo.deleteByID(deletedIDs.first), isNull);
    });

    test('`fileLimited`: tunable (reads in batches of its limit)', () async {
      expect(
        DBObjectDirectoryAdapter.fileLimited.getSemaphoreLimit(),
        equals(FileLimited.defaultSemaphoreLimit),
      );

      var photoRepo = provider.photoAPIRepository;

      for (var i = 0; i < 7; ++i) {
        await photoRepo.store(Photo.fromData(Uint8List(8), id: 'PB-$i'));
      }

      DBObjectDirectoryAdapter.fileLimited.setSemaphoreLimit(2);

      var all = await photoRepo.selectAll();
      expect(all.map((e) => e.id).toList()..sort(), [
        for (var i = 0; i < 7; ++i) 'PB-$i',
      ]);

      var some = await photoRepo.selectByIDs(['PB-6', 'PB-0', 'PB-x', 'PB-3']);
      expect(
        some.nonNulls.map((e) => e.id).toList()..sort(),
        equals(['PB-0', 'PB-3', 'PB-6']),
      );
    });
  });
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

        // The package root, independent of the working directory:
        var libUri = await Isolate.resolvePackageUri(
          Uri.parse('package:bones_api/bones_api.dart'),
        );
        var root = File.fromUri(libUri!).parent.parent.path;

        var dart = Platform.resolvedExecutable;
        var packages = '$root/.dart_tool/package_config.json';
        var script = '$root/test/bones_api_entity_db_directory_open_files.dart';

        // Runs the script directly (not `dart run`: no package resolution or
        // build hooks under the low limit). Exit code 77: can't set the limit
        // (a lower hard limit).
        var command =
            'ulimit -n 256 || exit 77; '
            'exec "$dart" --packages="$packages" "$script" "${tempDir.path}"';

        var result = await Process.run('/bin/sh', [
          '-c',
          command,
        ], workingDirectory: root);

        if (result.exitCode == 77) {
          markTestSkipped("Can't set the open files limit: ${result.stderr}");
          return;
        }

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
