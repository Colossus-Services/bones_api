// A helper script (not a test file) of `bones_api_entity_db_directory_test`:
// run in a process with a low limit of open files (`ulimit -n 256`), it
// fails with `Too many open files` (`errno = 24`) if the
// `DBObjectDirectoryAdapter` reads don't limit their concurrency.
//
// Usage:
//   dart --packages=.dart_tool/package_config.json \
//     test/bones_api_entity_db_directory_open_files.dart <dir>

import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/bones_api_db_directory.dart';

import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';

const totalObjects = 1000;
const concurrentSelects = 10;

Future<void> main(List<String> args) async {
  var dir = Directory(args.single);

  var provider = createEntityRepositoryProvider2(
    true,
    (p, dbPort, dbConfig) =>
        DBObjectDirectoryAdapter(dir, parentRepositoryProvider: p),
    0,
    null,
  );

  try {
    await provider.ensureInitialized();

    var photoRepo = provider.photoAPIRepository;
    var data = Uint8List(1024);

    for (var i = 0; i < totalObjects; ++i) {
      await photoRepo.store(Photo.fromData(data, id: 'PF-$i'));
    }

    // Unbounded, this opens about `totalObjects * concurrentSelects` files
    // at once:
    var results = await Future.wait([
      for (var i = 0; i < concurrentSelects; ++i)
        Future.sync(() => photoRepo.selectAll()),
    ]);

    for (var all in results) {
      if (all.length != totalObjects) {
        stderr.writeln('selectAll: ${all.length} != $totalObjects');
        exitCode = 1;
        return;
      }
    }

    stdout.writeln('OK: $concurrentSelects x $totalObjects objects');
  } catch (e, s) {
    stderr.writeln('ERROR: $e\n$s');
    exitCode = 1;
  } finally {
    provider.close();
  }
}
