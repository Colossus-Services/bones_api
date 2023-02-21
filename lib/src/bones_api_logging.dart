import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_base.dart';
import 'bones_api_logging_generic.dart'
    if (dart.library.io) 'bones_api_logging_io.dart';

final _log = logging.Logger('LoggerHandler');

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

StreamSubscription<logging.LogRecord>? _loggingListenSubscription;

void logToConsole() => _logToConsole(null);

void _logToConsole(LoggerHandler? loggerHandler) {
  if (_loggingListenSubscription != null) {
    return;
  }

  loggerHandler ??= _log.handler;

  var listen = logging.Logger.root.onRecord.listen(loggerHandler._log);
  _loggingListenSubscription = listen;
}

void cancelLogToConsole() => _cancelLogToConsole();

void _cancelLogToConsole() {
  var listen = _loggingListenSubscription;
  if (listen != null) {
    listen.cancel();
    _loggingListenSubscription = null;
  }
}

abstract class LoggerHandler {
  static LoggerHandler create(logging.Logger logger) =>
      createLoggerHandler(logger);

  static int _idCount = 0;

  final int id = ++_idCount;

  final logging.Logger logger;

  LoggerHandler(this.logger);

  void logAll() {
    logging.hierarchicalLoggingEnabled = true;
    logger.level = logging.Level.ALL;
  }

  void logToConsole() => _logToConsole(this);

  void cancelLogToConsole() => _cancelLogToConsole();

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

    var apiRequestIDStr = '';

    var apiRoot = APIRoot.get();

    if (apiRoot != null) {
      var apiRequest = apiRoot.currentAPIRequest.get(msg.zone);
      if (apiRequest != null) {
        apiRequestIDStr = '#${apiRequest.id}';
      }
    }

    var message = msg.message;

    var logMsg = StringBuffer(
        '$time $levelName $debugName $loggerName $apiRequestIDStr> $message\n');

    if (msg.error != null) {
      logMsg.write('[ERROR] ');
      logMsg.write(msg.error.toString());
      logMsg.write('\n');
    }

    if (msg.stackTrace != null) {
      logMsg.write(msg.stackTrace.toString());
      logMsg.write('\n');
    }

    printMessage(msg.level, logMsg.toString());
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
      s = '${s.substring(0, limit - 4)}..${s.substring(s.length - 2)}';
    }
    return s;
  }

  String get isolateDebugName;

  void printMessage(logging.Level level, String message);
}
