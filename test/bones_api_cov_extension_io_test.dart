@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_ext_io_');
  });

  tearDownAll(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('FileLimited (coverage)', () {
    test('semaphore limit', () {
      var fl = FileLimited(name: 'cov', semaphoreLimit: 3);
      expect(fl.name, equals('cov'));
      expect(fl.getSemaphoreLimit(), equals(3));
      expect(
        fl.toString(),
        equals('FileLimited{name: cov, semaphoreLimit: 3}'),
      );

      fl.setSemaphoreLimit(3);
      expect(fl.getSemaphoreLimit(), equals(3));

      fl.setSemaphoreLimit(5);
      expect(fl.getSemaphoreLimit(), equals(5));

      expect(() => fl.setSemaphoreLimit(0), throwsArgumentError);
      expect(() => fl.setSemaphoreLimit(-1), throwsArgumentError);
      expect(fl.getSemaphoreLimit(), equals(5));

      expect(FileLimited.global.name, equals('[GLOBAL]'));
      expect(
        FileLimited().getSemaphoreLimit(),
        equals(FileLimited.defaultSemaphoreLimit),
      );
    });

    test('file operations', () async {
      var fl = FileLimited(semaphoreLimit: 2);
      var file = File('${tmpDir.path}/limited.bin');

      expect(await fl.exists(file), isFalse);

      var written = await fl.writeAsBytes(file, [1, 2, 3]);
      expect(written.path, equals(file.path));
      expect(await fl.exists(file), isTrue);

      await fl.writeAsBytes(file, [4, 5], mode: FileMode.append, flush: true);
      expect(await fl.readAsBytes(file), equals([1, 2, 3, 4, 5]));

      var stat = await fl.stat(file);
      expect(stat.size, equals(5));

      // Concurrent calls above the limit:
      var reads = await Future.wait(
        List.generate(6, (_) => fl.readAsBytes(file)),
      );
      expect(reads.every((bs) => bs.length == 5), isTrue);

      await fl.delete(file);
      expect(await fl.exists(file), isFalse);

      await expectLater(
        fl.readAsBytes(file),
        throwsA(isA<FileSystemException>()),
      );
      // The semaphore is released after an error:
      expect(await fl.exists(file), isFalse);
    });
  });

  group('FileLimitExtension (coverage)', () {
    test('operations', () async {
      var prevLimit = FileLimitExtension.getSemaphoreLimit();
      try {
        FileLimitExtension.setSemaphoreLimit(7);
        expect(FileLimitExtension.getSemaphoreLimit(), equals(7));
      } finally {
        FileLimitExtension.setSemaphoreLimit(prevLimit);
      }
      expect(FileLimitExtension.getSemaphoreLimit(), equals(prevLimit));

      var file = File('${tmpDir.path}/ext.bin');

      await file.writeAsBytesLimited([9, 8, 7], flush: true);
      expect(await file.readAsBytesLimited(), equals([9, 8, 7]));
      expect((await file.statLimited()).size, equals(3));
      await file.exists();
      expect(file.existsSync(), isTrue);

      await file.deleteLimited();
      expect(file.existsSync(), isFalse);
    });
  });
}
