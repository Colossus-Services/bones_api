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
}

LoggerHandler createLoggerHandler(logging.Logger logger) {
  return LoggerHandlerIO(logger);
}
