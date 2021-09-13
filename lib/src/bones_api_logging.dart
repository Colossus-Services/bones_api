import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_logging_generic.dart'
    if (dart.library.io) 'bones_api_logging_io.dart';

final Expando<LoggerHandler> _loggerHandlers = Expando<LoggerHandler>();

extension LoggerExntesion on logging.Logger {
  LoggerHandler get handler {
    var handler = _loggerHandlers[this];
    if (handler == null) {
      handler = LoggerHandler.create(this);
      _loggerHandlers[this] = handler;
    }
    return handler;
  }
}

abstract class LoggerHandler {
  static LoggerHandler create(logging.Logger logger) =>
      createLoggerHandler(logger);

  final logging.Logger logger;

  LoggerHandler(this.logger);

  void logAll() {
    logging.hierarchicalLoggingEnabled = true;
    logger.level = logging.Level.ALL;
  }

  StreamSubscription<logging.LogRecord>? _loggingListenSubscription;

  void logToConsole() {
    if (_loggingListenSubscription != null) {
      return;
    }
    var listen = logging.Logger.root.onRecord.listen(_log);
    _loggingListenSubscription = listen;
  }

  static final Map<String, QueueList<int>> _maxKeys =
      <String, QueueList<int>>{};

  static int _maxKey(String key, String s, int limit) {
    var maxList = _maxKeys[key];
    var sLength = s.length;

    if (maxList == null) {
      var max = sLength;
      _maxKeys[key] = QueueList.from([sLength]);
      return max;
    } else {
      maxList.addLast(sLength);
      while (maxList.length > 20) {
        maxList.removeFirst();
      }
      var max = _listMax(maxList);
      return max;
    }
  }

  static int _listMax(List<int> l) {
    var max = l.first;
    for (var n in l.skip(1)) {
      if (n > max) {
        max = n;
      }
    }
    return max;
  }

  void _log(logging.LogRecord msg) {
    var time = '${msg.time}'.padRight(26, '0');
    var levelName = '[${msg.level.name}]'.padRight(9);

    var debugName = isolateDebugName;
    if (debugName.isNotEmpty) {
      var max = _maxKey('debugName', debugName, 10);
      debugName = truncateString(debugName, max);
      debugName = '($debugName)'.padRight(max + 2);
    }

    var loggerName = this.loggerName(msg);
    if (loggerName.isNotEmpty) {
      var max = _maxKey('loggerName', loggerName, 20);
      loggerName = truncateString(loggerName, max);
      loggerName = loggerName.padRight(max);
    }

    var message = msg.message;

    var logMsg = '$time $levelName $debugName $loggerName > $message\n';

    printMessage(msg.level, logMsg);
  }

  String loggerName(logging.LogRecord msg) {
    var name = msg.loggerName;
    if (name == 'hotreloader') {
      name = 'APIHotReload';
    }
    return name;
  }

  static String truncateString(String s, int limit) {
    if (s.length > limit) {
      s = s.substring(0, limit - 4) + '..' + s.substring(s.length - 2);
    }
    return s;
  }

  String get isolateDebugName;

  void printMessage(logging.Level level, String message);
}
