import 'package:logging/logging.dart';

import 'bones_api_logging.dart';

class LoggerHandlerGeneric extends LoggerHandler {
  LoggerHandlerGeneric(super.logger);

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
