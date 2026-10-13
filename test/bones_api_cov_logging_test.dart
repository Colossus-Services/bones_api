@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:bones_api/src/bones_api_logging_io.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mercury_client/mercury_client.dart' as mercury;
import 'package:test/test.dart';

/// Lets the `Logger.onRecord` broadcast stream and buffered loggers deliver.
Future<void> _pump([int ms = 5]) => Future.delayed(Duration(milliseconds: ms));

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_logging_');
  });

  tearDownAll(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('LoggerHandler (coverage)', () {
    late MessageLogger? prevAll;
    late bool prevConsole;
    late MessageLogger? prevRootError;
    late MessageLogger? prevRootDb;
    late bool prevUseLogQueue;

    setUp(() {
      prevAll = LoggerHandler.getLogAllTo();
      prevConsole = LoggerHandler.getLogToConsole();
      prevRootError = LoggerHandler.root.getLogErrorTo();
      prevRootDb = LoggerHandler.root.getLogDbTo();
      prevUseLogQueue = LoggerHandler.useLogQueue;
    });

    tearDown(() {
      LoggerHandler.root.logAllTo(messageLogger: prevAll);
      LoggerHandler.root.logToConsole(enabled: prevConsole);
      LoggerHandler.root.logErrorTo(messageLogger: prevRootError);
      LoggerHandler.root.logDbTo(messageLogger: prevRootDb);
      if (prevUseLogQueue) {
        LoggerHandler.enableLogQueue();
      } else {
        LoggerHandler.disableLogQueue();
      }
    });

    test('create / isolateDebugName / truncateString', () {
      var handler = LoggerHandler.create(logging.Logger('cov.create'));
      expect(handler, isA<LoggerHandlerIO>());
      expect(handler.isolateDebugName, isNotEmpty);
      expect(handler.id, greaterThan(0));

      expect(LoggerHandler.truncateString('abc', 10), equals('abc'));
      expect(
        LoggerHandler.truncateString('0123456789abcdef', 10),
        equals('012345..ef'),
      );
    });

    test('resolveLogDestiny', () async {
      var handler = LoggerHandler.create(logging.Logger('cov.destiny'));

      expect(handler.resolveLogDestiny(null), isNull);
      expect(handler.resolveLogDestiny(123), isNull);
      expect(handler.resolveLogDestiny({'x': 1}), isNull);

      expect(handler.resolveLogDestiny('console'), isNotNull);
      expect(handler.resolveLogDestiny('stdout'), isNotNull);
      expect(handler.resolveLogDestiny('stderr'), isNotNull);

      var received = <String>[];
      void messageLogger(logging.Level l, String m) => received.add(m);

      var ml = handler.resolveLogDestiny(messageLogger)!;
      ml(logging.Level.INFO, 'a');
      expect(received, equals(['a']));

      var ml2 = handler.resolveLogDestiny({'to': messageLogger})!;
      ml2(logging.Level.INFO, 'b');
      expect(received, equals(['a', 'b']));

      var single = <Object>[];
      var ml3 = handler.resolveLogDestiny((Object m) => single.add(m))!;
      ml3(logging.Level.INFO, 'c');
      expect(single, equals(['c']));

      var noDir = '${tmpDir.path}/no-such-dir/sub/x.log';
      expect(handler.resolveLogDestiny(noDir), isNull);
      expect(handler.resolveLogDestiny(File(noDir)), isNull);
    });

    test('resolveLogDestiny: file path', () async {
      var handler = LoggerHandler.create(logging.Logger('cov.file'));

      var filePath = '${tmpDir.path}/cov-log.log';
      var ml = handler.resolveLogDestiny({'path': filePath})!;

      ml(logging.Level.INFO, 'line-1\n');
      ml(logging.Level.INFO, 'line-2\n');
      ml(logging.Level.WARNING, 'line-3\n');

      String content = '';
      for (var i = 0; i < 100; ++i) {
        await _pump(20);
        var file = File(filePath);
        if (file.existsSync()) {
          content = file.readAsStringSync();
          if (content.contains('line-3')) break;
        }
      }

      expect(content, equals('line-1\nline-2\nline-3\n'));
    });

    test('resolveLogDestiny: HttpClient', () async {
      var handler = LoggerHandler.create(logging.Logger('cov.http'));

      var requests = <String>[];
      var simulation = mercury.HttpClientRequesterSimulation()
        ..simulatePOST(RegExp('log'), (url, params) {
          requests.add(url);
          return 'ok';
        });

      var client = mercury.HttpClient('http://localhost/', simulation);

      var ml = handler.resolveLogDestiny(client)!;
      ml(logging.Level.INFO, 'm1');
      ml(logging.Level.INFO, 'm2');
      ml(logging.Level.SEVERE, 'm3');

      for (var i = 0; i < 100 && requests.length < 2; ++i) {
        await _pump(20);
      }

      expect(requests.length, equals(2));
      expect(requests.every((u) => u.endsWith('/log')), isTrue);
    });

    test('flushMessages / printMessage / log queue', () async {
      var handler = LoggerHandler.create(logging.Logger('cov.print'));

      expect(handler.flushMessages(delay: null), isFalse);
      expect(await handler.flushMessages(), isFalse);
      expect(handler.forceFlushMessages(), isFalse);

      LoggerHandler.enableLogQueue();
      expect(LoggerHandler.useLogQueue, isTrue);

      handler.printMessage(logging.Level.FINE, '');
      handler.printMessage(logging.Level.FINE, '');
      // Different level: flushes the previous queue:
      handler.printMessage(logging.Level.SHOUT, '');
      expect(handler.forceFlushMessages(), isTrue);
      expect(handler.forceFlushMessages(), isFalse);

      handler.printMessage(logging.Level.FINE, '');
      expect(await handler.flushMessages(delay: null), isTrue);

      handler.printMessage(logging.Level.FINE, '');
      expect(await handler.flushMessages(), isTrue);

      handler.printMessage(logging.Level.FINE, '');
      LoggerHandler.disableLogQueue();
      expect(LoggerHandler.useLogQueue, isFalse);
      // Without queue: flushes the pending queue and prints directly:
      handler.printMessage(logging.Level.FINE, '');
      expect(handler.forceFlushMessages(), isFalse);

      LoggerHandler.enableLogQueue();
      expect(LoggerHandler.useLogQueue, isTrue);

      // A message queued while `flushMessages` is waiting its delay:
      await _pump(50); // Let any previously scheduled flush complete.
      var flushing = handler.flushMessages(delay: Duration(milliseconds: 5));
      handler.printMessage(logging.Level.FINE, '');
      expect(await flushing, isTrue);

      // `stderr` destiny:
      handler.resolveLogDestiny('stderr')!(logging.Level.INFO, '');

      var logger = logging.Logger('cov.print2');
      expect(logger.forceFlushMessages(), isFalse);
      expect(await logger.flushMessages(delay: null), isFalse);
    });

    test('logBuffered: levels and batches', () async {
      var handler = LoggerHandler.create(logging.Logger('cov.buffered'));

      var blocks = <(logging.Level, List<String>)>[];
      Future<void> blockLogger(logging.Level l, List<String> ms) async =>
          blocks.add((l, List.of(ms)));

      var id = Object();
      handler.logBuffered(id, blockLogger, logging.Level.INFO, 'a');
      handler.logBuffered(id, blockLogger, logging.Level.INFO, 'b');
      handler.logBuffered(id, blockLogger, logging.Level.WARNING, 'c');

      for (var i = 0; i < 50 && blocks.isEmpty; ++i) {
        await _pump(20);
      }

      expect(blocks.length, equals(2));
      expect(blocks[0].$1, equals(logging.Level.INFO));
      expect(blocks[0].$2, equals(['a', 'b']));
      expect(blocks[1].$1, equals(logging.Level.WARNING));
      expect(blocks[1].$2, equals(['c']));

      // A new batch after the first one was delivered:
      handler.logBuffered(id, blockLogger, logging.Level.INFO, 'd');
      for (var i = 0; i < 50 && blocks.length < 3; ++i) {
        await _pump(20);
      }
      expect(blocks.length, equals(3));
      expect(blocks[2].$2, equals(['d']));
    });

    test('DB loggers', () async {
      var dbLogger = logging.Logger('cov_db_logger');
      var handler = dbLogger.handler;
      var prevHandlerDb = handler.getLogDbTo();

      var dbMessages = <String>[];
      var rootDbMessages = <String>[];

      try {
        expect(dbLogger.isDbLogger, isFalse);
        expect(dbLogger.registerAsDbLogger(), isTrue);
        expect(dbLogger.registerAsDbLogger(), isFalse);
        expect(dbLogger.isDbLogger, isTrue);
        expect(dbLogger.dbLoggers, contains(dbLogger));
        expect(LoggerHandler.dbLoggers, contains(dbLogger));
        expect(LoggerHandler.isDbLoggerName('cov_db_logger'), isTrue);

        // Not logging DB yet (unless the root has a DB logger):
        LoggerHandler.root.logDbTo(messageLogger: null);
        expect(handler.isLoggingDB, isFalse);

        handler.logDbTo(messageLogger: (l, m) => dbMessages.add(m));
        expect(handler.isLoggingDB, isTrue);

        dbLogger.logDB(logging.Level.INFO, () => 'db-msg-function');
        dbLogger.logDB(logging.Level.INFO, 'db-msg-plain');
        dbLogger.info('db-logger-info');
        await _pump(20);

        expect(dbMessages.any((m) => m.contains('db-msg-function')), isTrue);
        expect(dbMessages.any((m) => m.contains('db-msg-plain')), isTrue);
        expect(dbMessages.any((m) => m.contains('db-logger-info')), isTrue);

        // Root DB logger, receiving `DBLog`s through the root handler:
        LoggerHandler.root.logDbTo(
          messageLogger: (l, m) => rootDbMessages.add(m),
        );
        var otherLogger = logging.Logger('cov.db.other');
        expect(otherLogger.handler.isLoggingDB, isTrue);
        otherLogger.logDB(logging.Level.INFO, 'root-db-info');
        otherLogger.logDB(logging.Level.WARNING, 'root-db-warning');
        await _pump(20);

        expect(rootDbMessages.any((m) => m.contains('root-db-info')), isTrue);
        expect(
          rootDbMessages.any((m) => m.contains('root-db-warning')),
          isTrue,
        );
      } finally {
        handler.logDbTo(messageLogger: prevHandlerDb);
        expect(await dbLogger.unregisterAsDbLogger(), isTrue);
        expect(await dbLogger.unregisterAsDbLogger(), isFalse);
      }

      expect(dbLogger.isDbLogger, isFalse);
      expect(LoggerHandler.isDbLoggerName('cov_db_logger'), isFalse);
    });

    test('DBLog', () {
      expect(DBLog('x').toString(), equals('x'));
      expect(DBLog(() => 'y').toString(), equals('y'));
      expect(DBLog(null).toString(), equals('null'));
    });

    test('logAll / isLoggingAll', () async {
      var logger = logging.Logger('cov.logall');
      var prevHierarchical = logging.hierarchicalLoggingEnabled;

      try {
        logger.handler.logAll();
        expect(logging.hierarchicalLoggingEnabled, isTrue);
        expect(logger.level, equals(logging.Level.ALL));
      } finally {
        logger.level = null;
        logging.hierarchicalLoggingEnabled = prevHierarchical;
      }

      var all = <String>[];
      logAllTo(messageLogger: (l, m) => all.add(m));
      expect(LoggerHandler.root.isLoggingAll, isTrue);

      logging.Logger(
        'cov.a-very-long-logger-name-to-truncate.xxxxxxxxxxxxxxxx',
      ).info('long-name-message', StateError('err'), StackTrace.current);
      await _pump(20);

      var msg = all.firstWhere((m) => m.contains('long-name-message'));
      expect(msg, contains('[ERROR] Bad state: err'));

      logAllTo(messageLogger: null);
      expect(LoggerHandler.root.isLoggingAll, isFalse);
    });
  });

  group('LoggerHandlerIO (coverage)', () {
    test('platform properties', () {
      var platform = APIPlatform.get();
      var prevLength = platform.getProperty('bones_api.log.max_file_length');
      var prevRotation = platform.getProperty(
        'bones_api.log.max_rotation_files',
      );

      try {
        platform.setProperty('bones_api.log.max_file_length', '1234');
        platform.setProperty('bones_api.log.max_rotation_files', '3');

        var handler =
            LoggerHandler.create(logging.Logger('cov.io.props'))
                as LoggerHandlerIO;
        expect(handler.logMaxFileLength, equals(1234));
        expect(handler.logMaxRotationFiles, equals(3));
      } finally {
        platform.setProperty('bones_api.log.max_file_length', prevLength ?? '');
        platform.setProperty(
          'bones_api.log.max_rotation_files',
          prevRotation ?? '',
        );
      }
    });
  });

  group('LogFileRotate (coverage)', () {
    test('constructor', () {
      expect(() => LogFileRotate(File('')), throwsArgumentError);

      var r1 = LogFileRotate(File('${tmpDir.path}/abc'));
      expect(r1.fileName, equals('abc'));
      expect(r1.fileExt, equals('.log'));
      expect(r1.parentPath, equals(tmpDir.path));
      expect(r1.maxLength, equals(LogFileRotate.defaultMaxLength));
      expect(r1.maxAge, equals(LogFileRotate.defaultMaxAge));
      expect(r1.checkInterval, equals(LogFileRotate.defaultCheckInterval));
      expect(
        r1.maxRotationFiles,
        equals(LogFileRotate.defaultMaxRotationFiles),
      );

      var r2 = LogFileRotate(
        File('${tmpDir.path}/x.txt'),
        maxLength: 10,
        maxRotationFiles: 2,
        maxAge: Duration(hours: 1),
        checkInterval: Duration(seconds: 1),
      );
      expect(r2.fileName, equals('x'));
      expect(r2.fileExt, equals('.txt'));
      expect(r2.maxLength, equals(10));
      expect(r2.maxRotationFiles, equals(2));
    });

    test('write + rotate by length', () async {
      var dir = await tmpDir.createTemp('rotate_');
      var file = File('${dir.path}/app.log');

      var rotate = LogFileRotate(
        file,
        maxLength: 10,
        maxRotationFiles: 2,
        checkInterval: Duration.zero,
      );

      expect(await rotate.flush(), isFalse);
      expect(await rotate.close(), isFalse);
      expect(await rotate.needRotation(), isFalse);

      expect(await rotate.write('0123456789ABC\n'), isFalse);
      expect(await rotate.flush(), isTrue);
      expect(await rotate.checkMaxLength(), isTrue);
      expect(await rotate.checkMaxAge(), isFalse);
      expect(await rotate.needRotation(), isTrue);

      var next = await rotate.nextRotationFile();
      expect(next!.i, equals(1));
      expect(next.file.path, endsWith('app.1.log'));

      // Rotates (`app.log` -> `app.1.log`):
      expect(await rotate.writeAll(['second', '-', 'block\n']), isTrue);
      await rotate.close();

      expect(
        await File('${dir.path}/app.1.log').readAsString(),
        '0123456789ABC\n',
      );
      expect(await file.readAsString(), equals('second-block\n'));

      // Extra old rotation files, to be removed (> maxRotationFiles):
      await File('${dir.path}/app.2.log').writeAsString('old-2\n');
      await File('${dir.path}/app.3.log').writeAsString('old-3\n');

      // `app.log` exceeds `maxLength`: rotates before writing, shifting
      // `app.1..3` and removing the files beyond `maxRotationFiles`:
      expect(await rotate.write('more-data-more-data\n'), isTrue);
      await rotate.flush();

      expect(
        await File('${dir.path}/app.1.log').readAsString(),
        equals('second-block\n'),
      );
      expect(
        await File('${dir.path}/app.2.log').readAsString(),
        equals('0123456789ABC\n'),
      );
      expect(await File('${dir.path}/app.3.log').exists(), isFalse);
      expect(await File('${dir.path}/app.4.log').exists(), isFalse);

      var ioSink = await rotate.checkRotate(force: true);
      expect(ioSink, isNotNull);
      expect(await rotate.write('after-rotation\n'), isFalse);
      await rotate.close();

      expect(await file.readAsString(), equals('after-rotation\n'));
      expect(
        await File('${dir.path}/app.1.log').readAsString(),
        equals('more-data-more-data\n'),
      );
      expect(
        await File('${dir.path}/app.2.log').readAsString(),
        equals('second-block\n'),
      );
      expect(await File('${dir.path}/app.3.log').exists(), isFalse);

      // Let the async rotation logs be emitted:
      await _pump(20);
    });

    test('checkRotate: within check interval', () async {
      var dir = await tmpDir.createTemp('rotate_interval_');
      var file = File('${dir.path}/interval.log');

      var rotate = LogFileRotate(
        file,
        maxLength: 5,
        checkInterval: Duration(hours: 1),
      );

      // First write checks the rotation (the file doesn't exist yet):
      expect(await rotate.write('0123456789\n'), isFalse);
      await rotate.flush();
      expect(await rotate.needRotation(), isTrue);

      // Within the `checkInterval`: no rotation, even exceeding `maxLength`:
      expect(await rotate.write('abc\n'), isFalse);
      expect(await rotate.checkRotate(), isNotNull);
      await rotate.close();

      expect(await file.readAsString(), equals('0123456789\nabc\n'));
      expect(await File('${dir.path}/interval.1.log').exists(), isFalse);
    });

    test('rotate by age', () async {
      var dir = await tmpDir.createTemp('rotate_age_');
      var file = File('${dir.path}/old.log');
      await file.writeAsString('old-content\n');
      await file.setLastModified(DateTime.now().subtract(Duration(days: 30)));

      var rotate = LogFileRotate(file, maxAge: Duration(days: 1));

      expect(await rotate.checkMaxLength(), isFalse);
      expect(await rotate.checkMaxAge(), isTrue);
      expect(await rotate.needRotation(), isTrue);

      expect(await rotate.write('new-content\n'), isTrue);
      await rotate.close();

      expect(await file.readAsString(), equals('new-content\n'));
      expect(
        await File('${dir.path}/old.1.log').readAsString(),
        equals('old-content\n'),
      );

      await _pump(20);
    });
  });
}
