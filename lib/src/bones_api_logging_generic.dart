import 'package:logging/logging.dart';

import 'bones_api_logging.dart';

class LoggerHandlerGeneric extends LoggerHandler {
  LoggerHandlerGeneric(Logger logger) : super(logger);

  @override
  String get isolateDebugName => '';

  @override
  void printMessage(Level level, String message) {
    print(message);
  }
}

LoggerHandler createLoggerHandler(Logger logger) {
  return LoggerHandlerGeneric(logger);
}
