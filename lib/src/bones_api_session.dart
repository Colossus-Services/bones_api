import 'dart:math';

import 'package:collection/collection.dart';

import 'bones_api_base.dart';
import 'bones_api_authentication.dart';
import 'bones_api_security.dart';

/// An [APIRoot] session.
/// Used by [APISecurity].
class APISession {
  static final Random _sessionIdPeriodRandom = Random();
  static SecureRandom? _sessionIdRandomInstance;

  static int _sessionIdRandomUseCount = 0;

  static SecureRandom get _sessionIdRandom {
    if (_sessionIdRandomUseCount > 500 &&
        _sessionIdRandomUseCount > 500 + _sessionIdPeriodRandom.nextInt(1000)) {
      _sessionIdRandomInstance = null;
      _sessionIdRandomUseCount = 0;
    }

    var random = _sessionIdRandomInstance ??= SecureRandom();
    ++_sessionIdRandomUseCount;

    return random;
  }

  static String generateSessionID(
      {int length = 128, int variableLength = 32, String? prefix}) {
    if (length < 32) {
      length = 32;
    }

    if (prefix != null) {
      prefix = prefix.trim();
    } else {
      prefix = 'SID';
    }

    return APIToken.generateToken(length,
        variableLength: variableLength,
        prefix: prefix,
        random: _sessionIdRandom);
  }

  String id;

  APISession(this.id);

  DateTime lastAccessTime = DateTime.now();

  void markAccessTime() => lastAccessTime = DateTime.now();

  Duration get lastAccessElapsedTime =>
      DateTime.now().difference(lastAccessTime);

  bool isExpired(Duration timeout, {DateTime? now}) {
    now ??= DateTime.now();

    var elapsedTime = lastAccessElapsedTime;
    return elapsedTime.compareTo(timeout) > 0;
  }

  Set<APIToken>? _tokens;

  Set<APIToken> get tokens => _tokens ??= <APIToken>{};

  Set<APIToken> validateTokens() {
    var tokens = this.tokens;
    if (tokens.isEmpty) return tokens;

    var now = DateTime.now();
    tokens.removeWhere((t) => t.isExpired(now: now));
    return tokens;
  }

  APIToken? getValidToken(String token) =>
      validateTokens().firstWhereOrNull((t) => t.token == token);
}

/// Handles a set of [APISession].
class APISessionSet {
  /// The session timeout.
  final Duration timeout;

  late final Duration autoCheckInterval;

  APISessionSet(this.timeout, {Duration? autoCheckInterval}) {
    var autoCheckIntervalResolved = autoCheckInterval;
    if (autoCheckIntervalResolved == null) {
      autoCheckIntervalResolved =
          Duration(milliseconds: timeout.inMilliseconds ~/ 3);
      if (autoCheckIntervalResolved.inMinutes > 5) {
        autoCheckIntervalResolved = Duration(minutes: 5);
      }
    }

    this.autoCheckInterval = autoCheckIntervalResolved;
  }

  final Map<String, APISession> _sessions = <String, APISession>{};

  int get length => _sessions.length;

  APISession? get(String sessionID) {
    autoCheckSessions();
    return _sessions[sessionID];
  }

  APISession? getMarkingAccess(String sessionID) {
    var session = get(sessionID);
    session?.markAccessTime();
    return session;
  }

  put(APISession session) {
    autoCheckSessions();
    return _sessions[session.id] = session;
  }

  List<APISession> expiredSessions(DateTime now) =>
      _sessions.values.where((e) => e.isExpired(timeout, now: now)).toList();

  void checkSessions() {
    var now = DateTime.now();
    var expired = expiredSessions(now);

    for (var e in expired) {
      _sessions.remove(e.id);
    }
  }

  DateTime _autoCheckSessionsLastTime = DateTime.now();

  void autoCheckSessions() {
    var now = DateTime.now();
    var elapsedTime = now.difference(_autoCheckSessionsLastTime);

    if (elapsedTime.inMilliseconds < autoCheckInterval.inMilliseconds) return;
    _autoCheckSessionsLastTime = now;

    checkSessions();
  }

  void clear() => _sessions.clear();
}
