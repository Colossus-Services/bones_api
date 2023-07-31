import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart' as logging;

import 'bones_api_logging.dart';

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
        var out = logDestiny.openWrite(mode: FileMode.writeOnlyAppend);
        return (l, ms) => _logToFile(logDestiny as File, out, l, ms);
      }
    }

    return null;
  }

  void _logToFile(File file, IOSink out, logging.Level l, String ms) =>
      logBuffered(file, (l, ms) async {
        var all = ms.join('');
        out.write(all);
      }, l, ms);
}

LoggerHandler createLoggerHandler(logging.Logger logger) {
  return LoggerHandlerIO(logger);
}
