import 'dart:io';
import 'dart:isolate';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;

import 'bones_api_logging.dart';

final _log = logging.Logger('LogFileRotate');

class LoggerHandlerIO extends LoggerHandler {
  LoggerHandlerIO(logging.Logger logger) : super(logger);

  @override
  String get isolateDebugName {
    var s = Isolate.current.debugName as dynamic;
    return s != null ? '$s' : '?';
  }

  @override
  void printMessage(logging.Level level, String message) {
    var out = (level < logging.Level.SEVERE ? stdout : stderr);
    out.write(message);
  }

  @override
  MessageLogger? resolveLogDestiny(Object? logDestiny) {
    if (logDestiny == null) return null;

    var resolved = super.resolveLogDestiny(logDestiny);
    if (resolved != null) return resolved;

    if (logDestiny == 'console' || logDestiny == 'stderr') {
      return (l, m) => stderr.write(m);
    }

    if (logDestiny is String) {
      File? file;
      try {
        file = File(logDestiny);
      } catch (_) {}

      if (file != null && (file.existsSync() || file.parent.existsSync())) {
        logDestiny = file;
      }
    }

    if (logDestiny is File) {
      if (logDestiny.existsSync() || logDestiny.parent.existsSync()) {
        var logFileRotate = LogFileRotate(logDestiny);
        return (l, ms) => _logToFile(logFileRotate, l, ms);
      }
    }

    return null;
  }

  void _logToFile(LogFileRotate logFileRotate, logging.Level l, String ms) =>
      logBuffered(logFileRotate, (l, ms) async {
        var all = ms.join('');
        logFileRotate.write(all);
      }, l, ms);
}

LoggerHandler createLoggerHandler(logging.Logger logger) {
  return LoggerHandlerIO(logger);
}

/// Log rotates [file].
/// - [checkRotate] is called before [write] or [writeAll] to [ioSink].
class LogFileRotate {
  final File file;

  final int maxLength;

  final Duration maxAge;

  final Duration checkInterval;

  final int maxRotationFiles;

  late final String parentPath;
  late final String fileName;
  late final String fileExt;

  LogFileRotate(
    this.file, {
    this.maxLength = 1024 * 1024 * 100,
    this.maxAge = const Duration(days: 7),
    this.checkInterval = const Duration(minutes: 1),
    this.maxRotationFiles = 10,
  }) {
    parentPath = file.parent.path;
    var filePath = file.path;

    fileName = pack_path.basenameWithoutExtension(filePath);
    if (fileName.isEmpty) {
      throw ArgumentError("Invalid file name: $filePath");
    }

    var fileExt = pack_path.extension(filePath);
    if (fileExt.isEmpty) {
      fileExt = '.log';
    }

    this.fileExt = fileExt;
  }

  IOSink? _ioSink;

  FutureOr<IOSink> get ioSink {
    var flushing = _flushing;
    if (flushing != null) {
      return flushing.then((_) => _ioSink2());
    }

    return _ioSink2();
  }

  FutureOr<IOSink> _ioSink2() {
    var closing = _closing;
    if (closing != null) {
      return closing.then((_) => _ioSink3());
    }

    return _ioSink3();
  }

  FutureOr<IOSink> _ioSink3() {
    var rotating = _rotating;
    if (rotating != null) {
      return rotating.then((_) {
        return _ioSinkImpl();
      });
    }

    return _ioSinkImpl();
  }

  IOSink _ioSinkImpl() =>
      _ioSink ??= file.openWrite(mode: FileMode.writeOnlyAppend);

  Future<bool>? _flushing;

  Future<bool> flush() async {
    var flushing = _flushing;
    if (flushing != null) return flushing;

    final ioSink = _ioSink;
    if (ioSink == null) return false;

    return _flushing = ioSink.flush().then((_) {
      _flushing = null;
      return true;
    });
  }

  Future<bool>? _closing;

  Future<bool> close() async {
    var closing = _closing;
    if (closing != null) return closing;

    final ioSink = _ioSink;
    if (ioSink == null) return false;

    return _closing = flush().then((value) async {
      await ioSink.close();
      _ioSink = null;
      _closing = null;
      return true;
    });
  }

  DateTime _lastCheckRotate = DateTime.now().subtract(Duration(minutes: 10));

  Future<IOSink>? _rotating;

  FutureOr<IOSink> checkRotate({bool force = false}) {
    var call = _rotating;
    if (call != null) return call;

    if (!force) {
      var elapsedTime = DateTime.now().difference(_lastCheckRotate);
      if (elapsedTime < checkInterval) {
        return ioSink;
      }
    }

    return _rotating = _rotate().then((_) {
      _lastCheckRotate = DateTime.now();
      _rotating = null;
      return ioSink;
    });
  }

  Future<bool> _rotate() async {
    var needRotation = await this.needRotation();
    if (!needRotation) return false;

    var nextFile = await nextRotationFile();
    if (nextFile == null) {
      return false;
    }

    await close();

    assert(_ioSink == null);
    assert(_flushing == null);
    assert(_closing == null);

    await _rotateFiles(nextFile.i);

    var file1 = _rotationFile(1);
    if (await file1.exists()) {
      _logWarningAsync("Log rotation failed! File (1) exists: ${file1.path}");
      return false;
    }

    await file.rename(file1.path);

    assert(_ioSink == null);

    // Call asynchronously to avoid logging while rotating:
    _logInfoAsync(
        "Log rotated: ${file.path} -> ${pack_path.basename(file1.path)}${nextFile.i > 1 ? ' (1 .. ${nextFile.i})' : ''}");

    return true;
  }

  void _logInfoAsync(Object? m) => _logAsync(logging.Level.INFO, m);

  void _logWarningAsync(Object? m) => _logAsync(logging.Level.WARNING, m);

  void _logSevereAsync(Object? m) => _logAsync(logging.Level.SEVERE, m);

  void _logAsync(logging.Level level, Object? m) =>
      Future.delayed(Duration(microseconds: 100), () => _log.log(level, m));

  Future<void> _rotateFiles(int nextFileI) async {
    for (var i = nextFileI; i >= 2; --i) {
      var file = _rotationFile(i);
      var filePrev = _rotationFile(i - 1);

      if (!(await filePrev.exists())) {
        continue;
      }

      if (await file.exists()) {
        _logSevereAsync(
            "Destination file already exists! Can't rotate file: ${filePrev.path} -> ${file.path}");
      }

      await filePrev.rename(file.path);
    }

    if (maxRotationFiles > 1) {
      var maxI = maxRotationFiles + 1;
      var missingCount = 0;

      while (missingCount < 10) {
        var file = _rotationFile(maxI);

        if (await file.exists()) {
          await file.delete();
          missingCount = 0;
        } else {
          missingCount++;
        }

        ++maxI;
      }
    }
  }

  Future<({File file, int i})?> nextRotationFile() async {
    for (var i = 1; i <= 10000; ++i) {
      var file2 = _rotationFile(i);

      var exists = await file2.exists();
      if (!exists) {
        return (file: file2, i: i);
      }
    }

    _logWarningAsync(
        "Can't define the next log rotation file for: ${file.path}");

    return null;
  }

  File _rotationFile(int i) {
    var fileName2 = '$fileName.$i$fileExt';
    var path2 = pack_path.join(parentPath, fileName2);
    var file2 = File(path2);
    return file2;
  }

  Future<bool> needRotation() async {
    var fileExists = await file.exists();
    if (!fileExists) return false;

    if (await checkMaxLength()) return true;
    if (await checkMaxAge()) return true;
    return false;
  }

  Future<bool> checkMaxLength() async {
    var lng = await file.length();
    return lng > maxLength;
  }

  Future<bool> checkMaxAge() async {
    var fileTime = await file.lastModified();
    var elapsedTime = DateTime.now().difference(fileTime);
    return elapsedTime > maxAge;
  }

  FutureOr<bool> write(Object? o) {
    final ioSink0 = ioSink;
    return checkRotate().resolveMapped((ioSink) {
      ioSink.write(o);
      var rotated = !identical(ioSink0, ioSink);
      return rotated;
    });
  }

  FutureOr<bool> writeAll(Iterable os) {
    final ioSink0 = ioSink;
    return checkRotate().resolveMapped((ioSink) {
      ioSink.writeAll(os);
      var rotated = !identical(ioSink0, ioSink);
      return rotated;
    });
  }
}
