@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_platform_');
  });

  tearDownAll(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('APIPlatformType (coverage)', () {
    test('name', () {
      expect(APIPlatformType.values.map((e) => e.name).toList(), [
        'generic',
        'browser',
        'vm',
        'native',
        'ios',
        'android',
        'linux',
        'macos',
        'windows',
      ]);

      var platform = APIPlatform.get();
      expect(platform.name, equals(platform.type.name));
    });
  });

  group('APIPlatformCapability (coverage)', () {
    test('bits', () {
      var c64 = APIPlatformCapability.bits64(canReadFile: true);
      expect(c64.int64, isTrue);
      expect(c64.double64, isTrue);
      expect(c64.maxSafeInteger, equals(9223372036854775807));
      expect(c64.minSafeInteger, equals(-9223372036854775807 - 1));

      var c53 = APIPlatformCapability.bits53(canReadFile: false);
      expect(c53.canReadFile, isFalse);
      expect(c53.int53, isTrue);
      expect(c53.double53, isTrue);
      expect(c53.maxSafeInteger, equals(9007199254740991));
      expect(c53.minSafeInteger, equals(-9007199254740991));

      var c32 = APIPlatformCapability.bits32(canReadFile: false);
      expect(c32.int32, isTrue);
      expect(c32.double32, isTrue);
      expect(c32.maxSafeInteger, equals(2147483647));
      expect(c32.minSafeInteger, equals(-2147483648));

      var custom = APIPlatformCapability(
        canReadFile: true,
        maxSafeInteger: 100,
        minSafeInteger: -100,
      );
      expect(custom.maxSafeInteger, equals(100));
      expect(custom.minSafeInteger, equals(-100));

      expect(
        () => APIPlatformCapability(canReadFile: true),
        throwsA(isA<StateError>()),
      );
      expect(
        () => APIPlatformCapability(canReadFile: true, maxSafeInteger: 10),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('APIPlatformVM (coverage)', () {
    test('properties', () {
      var platform = APIPlatform.get();

      const key = '__BONES_API_COV_PLATFORM_KEY__';

      expect(platform.getProperty(null), isNull);
      expect(platform.getProperty(null, defaultValue: 'd'), equals('d'));
      expect(platform.getPropertyAs<int>(key), isNull);

      expect(platform.setProperty(key, '123'), isNull);
      expect(platform.getProperty(key), equals('123'));
      expect(platform.getPropertyAs<String>(key), equals('123'));
      expect(platform.getPropertyAs<int>(key), equals(123));
      expect(platform.getPropertyAs<double>(key), equals(123.0));
      expect(
        () => platform.getPropertyAs<APIPlatform>(key),
        throwsA(isA<StateError>()),
      );

      expect(platform.setProperty(key, '456'), equals('123'));
      expect(platform.propertiesKeys, contains(key));

      var envKey = Platform.environment.keys.firstOrNull;
      if (envKey != null) {
        expect(platform.propertiesKeys, contains(envKey));
        expect(
          platform.getProperty(envKey, caseSensitive: true),
          equals(Platform.environment[envKey]),
        );
      }
    });

    test('resolveFilePath', () {
      var platform = APIPlatform.get();

      expect(
        platform.resolveFilePath('foo.txt', parentPath: '/tmp/a'),
        equals('/tmp/a/foo.txt'),
      );
      expect(
        platform.resolveFilePath('foo.txt', parentPath: '/tmp/b/'),
        equals('/tmp/b/foo.txt'),
      );
      expect(
        platform.resolveFilePath('/abs/foo.txt', parentPath: '/tmp/b/'),
        equals('/abs/foo.txt'),
      );
      expect(
        platform.resolveFilePath('foo.txt', parentPath: ''),
        equals(File('foo.txt').absolute.path),
      );
      expect(
        platform.resolveFilePath('file:///tmp/c/foo.txt'),
        equals('/tmp/c/foo.txt'),
      );
    }, testOn: '!windows');

    test('readFile', () async {
      var platform = APIPlatform.get();

      var file = File('${tmpDir.path}/data.txt');
      await file.writeAsString('hello-platform');

      expect(await platform.readFileAsString(file.path), 'hello-platform');
      expect(
        await platform.readFileAsBytes(file.path),
        equals('hello-platform'.codeUnits),
      );
    });

    test('log', () async {
      var platform = APIPlatform.get();

      var records = <logging.LogRecord>[];
      var sub = logging.Logger.root.onRecord.listen((r) {
        if (r.loggerName == 'APIPlatform') records.add(r);
      });

      var prevLevel = logging.Logger.root.level;
      logging.Logger.root.level = logging.Level.ALL;

      try {
        platform.log('cov-fine');
        platform.logInfo('cov-info');
        platform.logWarning('cov-warning');
        platform.logError('cov-error', StateError('x'), StackTrace.current);
        await Future.delayed(Duration(milliseconds: 10));
      } finally {
        logging.Logger.root.level = prevLevel;
        await sub.cancel();
      }

      expect(records.map((r) => r.message), [
        'cov-fine',
        'cov-info',
        'cov-warning',
        'cov-error',
      ]);
      expect(records.map((r) => r.level), [
        logging.Level.FINE,
        logging.Level.INFO,
        logging.Level.WARNING,
        logging.Level.SEVERE,
      ]);
      expect(records.last.error, isA<StateError>());
    });

    test('stdout / stderr', () {
      var platform = APIPlatform.get();
      // Writes empty content to not pollute the test output:
      platform.stdout('');
      platform.stderr('');
      platform.stdoutLn('[APIPlatform.stdoutLn coverage]');
      platform.stderrLn('[APIPlatform.stderrLn coverage]');
      expect(platform.capability.canReadFile, isTrue);
    });
  });
}
