import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mercury_client/mercury_client.dart';

import 'bones_api_base.dart';
import 'bones_api_logging_generic.dart'
    if (dart.library.io) 'bones_api_logging_io.dart';

final _log = logging.Logger('LoggerHandler');

final Expando<LoggerHandler> _loggerHandlers = Expando<LoggerHandler>();

bool _bootCalled = false;

void _boot() {
  if (_bootCalled) return;
  _bootCalled = true;

  _setupRootLogger();
}

void _setupRootLogger() {
  var loggerHandler = _resolveLoggerHandler();
  var rootLogger = LoggerHandler.rootLogger;
  rootLogger.onRecord.listen(loggerHandler._logRootMsg);
}

LoggerHandler _resolveLoggerHandler([LoggerHandler? loggerHandler]) {
  _boot();
  return loggerHandler ?? LoggerHandler.root;
}

void logAllTo(
    {MessageLogger? messageLogger,
    Object? logDestiny,
    bool includeDBLogs = false}) {
  var loggerHandler = _resolveLoggerHandler();
  loggerHandler.logAllTo(
      messageLogger: messageLogger,
      logDestiny: logDestiny,
      includeDBLogs: includeDBLogs);
}

void logToConsole({bool enabled = true}) {
  var loggerHandler = _resolveLoggerHandler();
  loggerHandler.logToConsole(enabled: enabled);
}

void logErrorTo(
    {MessageLogger? messageLogger,
    Object? logDestiny,
    LoggerHandler? loggerHandler}) {
  loggerHandler = _resolveLoggerHandler(loggerHandler);
  loggerHandler.logErrorTo(
      messageLogger: messageLogger, logDestiny: logDestiny);
}

void logDbTo(
    {MessageLogger? messageLogger,
    Object? logDestiny,
    LoggerHandler? loggerHandler}) {
  loggerHandler = _resolveLoggerHandler(loggerHandler);
  loggerHandler.logDbTo(messageLogger: messageLogger, logDestiny: logDestiny);
}

extension LoggerExntesion on logging.Logger {
  LoggerHandler get handler {
    var handler = _loggerHandlers[this];
    if (handler == null) {
      handler = LoggerHandler.create(this);
      _loggerHandlers[this] = handler;
    }
    return handler;
  }

  FutureOr<bool> flushMessages(
          {Duration? delay = const Duration(milliseconds: 20)}) =>
      handler.flushMessages(delay: delay);

  static final Set<logging.Logger> _dbLoggers = {};

  List<logging.Logger> get dbLoggers => _dbLoggers.toList();

  bool get isDbLogger => _dbLoggers.contains(this);

  static final Set<String> _dbLoggersNames = {};

  bool registerAsDbLogger() {
    if (_dbLoggers.add(this)) {
      _dbLoggersNames.add(name);
      _setupDbLogger(handler);
      return true;
    }
    return false;
  }

  Future<bool> unregisterAsDbLogger() async {
    if (_dbLoggers.remove(this)) {
      _dbLoggersNames.remove(name);
      await _cancelDbLogger();
      return true;
    }
    return false;
  }

  static final Map<logging.Logger, StreamSubscription> _dbLoggersSubscriptions =
      {};

  void _setupDbLogger(LoggerHandler loggerHandler) {
    _boot();

    var subscription = onRecord.listen(loggerHandler._logDBMsg);

    _dbLoggersSubscriptions[this] = subscription;
  }

  Future<void> _cancelDbLogger() async {
    var subscription = _dbLoggersSubscriptions.remove(this);
    await subscription?.cancel();
  }

  void logDB(logging.Level logLevel, Object? message,
      [Object? error, StackTrace? stackTrace, Zone? zone]) {
    if (handler.isLoggingDB) {
      log(logLevel, DBLog(message));
    }
  }
}

class DBLog {
  final Object? message;

  DBLog(this.message);

  @override
  String toString() {
    final message = this.message;
    if (message is Function()) {
      var s = message();
      return s.toString();
    } else {
      return message.toString();
    }
  }
}

typedef MessageLogger = void Function(logging.Level level, String message);
typedef MessagesBlockLogger = Future<void> Function(
    logging.Level level, List<String> messages);

abstract class LoggerHandler {
  static LoggerHandler create(logging.Logger logger) =>
      createLoggerHandler(logger);

  static String truncateString(String s, int limit) {
    if (s.length > limit) {
      s = '${s.substring(0, limit - 4)}..${s.substring(s.length - 2)}';
    }
    return s;
  }

  static bool isDbLoggerName(String name) =>
      LoggerExntesion._dbLoggersNames.contains(name);

  static final logging.Logger rootLogger = logging.Logger.root;

  static final LoggerHandler root = rootLogger.handler;

  static List<logging.Logger> get dbLoggers =>
      LoggerExntesion._dbLoggers.toList();

  static int _idCount = 0;

  final int id = ++_idCount;

  final logging.Logger logger;

  LoggerHandler(this.logger) {
    _boot();
  }

  String get isolateDebugName;

  LoggerHandler? _parent;

  LoggerHandler? get parent {
    var p = _parent;
    if (p != null) return p;

    var l = logger.parent;
    if (l == null) return null;

    p = _parent = _loggerHandlers[l];
    return p;
  }

  String loggerName(logging.LogRecord msg) {
    var name = msg.loggerName;
    if (name == 'hotreloader') {
      name = 'APIHotReload';
    }
    return name;
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

  void _logRootMsg(logging.LogRecord msg) {
    var level = msg.level;
    var logMsg = _buildMsg(msg);

    var isDBLog = msg.object is DBLog;
    if (!isDBLog || _allMessageLoggerIncludeDBLogs) {
      logAllMessage(level, logMsg);
    }

    if (level == logging.Level.SEVERE) {
      logErrorMessage(level, logMsg);
    }

    if (isDBLog) {
      logDBMessage(level, logMsg);
      if (level < logging.Level.WARNING) {
        return;
      }
    } else {
      var isFromDBLogger = isDbLoggerName(msg.loggerName);
      if (isFromDBLogger) {
        logDBMessage(level, logMsg);
      }
    }

    if (_logToConsole) {
      printMessage(level, logMsg);
    }
  }

  void _logDBMsg(logging.LogRecord msg) {
    if (_dbMessageLogger == null) return;

    var level = msg.level;
    var logMsg = _buildMsg(msg);

    logDBMessage(level, logMsg);
  }

  String _buildMsg(logging.LogRecord msg) {
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

    return logMsg.toString();
  }

  void printMessage(logging.Level level, String message);

  static bool _useLogQueue = true;

  /// If `true` [printMessage] implementation can use a queue and delay
  /// the message to the output.
  ///
  /// See [disableLogQueue], [enableLogQueue] and [flushMessages]
  static bool get useLogQueue => _useLogQueue;

  /// Sets [useLogQueue] to `false`.
  static void disableLogQueue() {
    if (_useLogQueue) {
      _useLogQueue = false;
      _log.info("DISABLED LOG QUEUE.");
    }
  }

  /// Sets [useLogQueue] to `true`.
  static void enableLogQueue() {
    if (!_useLogQueue) {
      _useLogQueue = true;
      _log.info("ENABLED LOG QUEUE.");
    }
  }

  /// Flushes the messages in the queue (if the implementation has one).
  /// See [useLogQueue].
  FutureOr<bool> flushMessages(
      {Duration? delay = const Duration(milliseconds: 20)});

  void logAll() {
    logging.hierarchicalLoggingEnabled = true;
    logger.level = logging.Level.ALL;
  }

  static MessageLogger? _allMessageLogger;
  static bool _allMessageLoggerIncludeDBLogs = false;

  static MessageLogger? getLogAllTo() => _allMessageLogger;

  void logAllTo(
      {MessageLogger? messageLogger,
      Object? logDestiny,
      bool includeDBLogs = false}) {
    messageLogger ??= resolveLogDestiny(logDestiny);

    _allMessageLogger = messageLogger;
    _allMessageLoggerIncludeDBLogs = includeDBLogs;
  }

  bool get isLoggingAll => _allMessageLogger != null;

  /// [enabled]]/disable logs to the console.
  /// - VM: logs to the STDOUT/STDERR.
  /// - Browser: logs to the browser console.
  void logToConsole({bool enabled = true}) => _logToConsoleImpl(enabled);

  static bool _logToConsole = false;

  static bool getLogToConsole() => _logToConsole;

  static void _logToConsoleImpl(bool enabled) => _logToConsole = enabled;

  MessageLogger? _errorMessageLogger;

  MessageLogger? getLogErrorTo() => _errorMessageLogger;

  void logErrorTo({MessageLogger? messageLogger, Object? logDestiny}) {
    messageLogger ??= resolveLogDestiny(logDestiny);

    _errorMessageLogger = messageLogger;
  }

  MessageLogger? _dbMessageLogger;

  MessageLogger? getLogDbTo() => _dbMessageLogger;

  void logDbTo({MessageLogger? messageLogger, Object? logDestiny}) {
    messageLogger ??= resolveLogDestiny(logDestiny);

    _dbMessageLogger = messageLogger;
  }

  MessageLogger? _resolveDBMessageLogger() {
    var messageLogger = _dbMessageLogger;

    if (messageLogger == null) {
      var parent = this.parent;
      messageLogger = parent?._dbMessageLogger;
      messageLogger ??= LoggerHandler.root._dbMessageLogger;
    }

    return messageLogger;
  }

  bool get isLoggingDB => _resolveDBMessageLogger() != null;

  void logAllMessage(logging.Level level, String message) {
    var messageLogger = _allMessageLogger;

    if (messageLogger != null) {
      messageLogger(level, message);
    }
  }

  void logErrorMessage(logging.Level level, String message) {
    var messageLogger = _errorMessageLogger;

    if (messageLogger == null) {
      var parent = this.parent;
      messageLogger = parent?._errorMessageLogger;
      messageLogger ??= LoggerHandler.root._errorMessageLogger;
    }

    if (messageLogger != null) {
      messageLogger(level, message);
    }
  }

  void logDBMessage(logging.Level level, String message) {
    var messageLogger = _resolveDBMessageLogger();
    if (messageLogger != null) {
      messageLogger(level, message);
    }
  }

  MessageLogger? resolveLogDestiny(final Object? logDestiny) {
    if (logDestiny == null) return null;

    if (logDestiny is Map) {
      var destiny =
          logDestiny['to'] ?? logDestiny['path'] ?? logDestiny['file'];
      if (destiny != null) {
        return resolveLogDestiny(destiny);
      }
    }

    if (logDestiny is MessageLogger) return logDestiny;

    if (logDestiny == 'console' || logDestiny == 'stdout') {
      return printMessage;
    }

    if (logDestiny is Function(Object, Object)) {
      return (l, m) => logDestiny(l, m);
    } else if (logDestiny is Function(dynamic, dynamic)) {
      return (l, m) => logDestiny(l, m);
    }

    if (logDestiny is Function(Object)) {
      return (l, m) => logDestiny(m);
    } else if (logDestiny is Function(dynamic)) {
      return (l, m) => logDestiny(m);
    }

    if (logDestiny is HttpClient) {
      return (l, m) async => _logToHttpClient(logDestiny, l, m);
    }

    return null;
  }

  static final Expando<List<(logging.Level, List<String>)>> _buffers =
      Expando();

  static final Expando<Future<void>> _bufferedCalls = Expando();

  void logBuffered(Object identifier, MessagesBlockLogger messagesBlockLogger,
      logging.Level level, String message) {
    final buffer = _buffers[identifier] ??= [];

    if (buffer.isEmpty) {
      buffer.add((level, [message]));
    } else {
      var levelBuffer = buffer.last;
      if (levelBuffer.$1 == level) {
        levelBuffer.$2.add(message);
      } else {
        buffer.add((level, [message]));
      }
    }

    Future<void>? call;

    call = _bufferedCalls[identifier] ??=
        Future.delayed(Duration(milliseconds: 100), () async {
      for (var levelBlock in buffer) {
        var messages = levelBlock.$2;
        if (messages.isNotEmpty) {
          var level = levelBlock.$1;
          messagesBlockLogger(level, messages);
        }
      }

      buffer.clear();

      var prevCall = _bufferedCalls[identifier];
      if (identical(prevCall, call)) {
        _bufferedCalls[identifier] = null;
      }
    });
  }

  void _logToHttpClient(
          HttpClient client, logging.Level level, String message) =>
      logBuffered(
        client,
        (l, ms) async => _callHttpClientLog(client, l, ms),
        level,
        message,
      );

  Future<void> _callHttpClientLog(
      HttpClient client, logging.Level level, List<String> messages) async {
    await client.post(
      'log',
      body: {
        'level': level.name,
        'messages': messages,
      },
      contentType: 'json',
    );
  }
}
