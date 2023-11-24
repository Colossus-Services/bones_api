import 'dart:math';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:shared_map/shared_map.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
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
  final SharedStoreField _sharedStoreField;

  /// The session timeout.
  final Duration timeout;

  late final Duration autoCheckInterval;

  APISessionSet(this.timeout,
      {Duration? autoCheckInterval,
      APIRoot? apiRoot,
      SharedStoreField? sharedStoreField,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedStoreProviderSync? storeProvider})
      : _sharedStoreField = SharedStoreField.tryFrom(
                sharedStoreField: sharedStoreField,
                sharedStoreReference: sharedStoreReference,
                sharedStore: sharedStore ?? apiRoot?.sharedStore,
                sharedStoreID: sharedStoreID,
                storeProvider: storeProvider) ??
            SharedStoreField.fromSharedStore(SharedStore.notShared()) {
    var autoCheckIntervalResolved = autoCheckInterval;
    if (autoCheckIntervalResolved == null) {
      autoCheckIntervalResolved =
          Duration(milliseconds: timeout.inMilliseconds ~/ 3);
      if (autoCheckIntervalResolved.inMinutes > 5) {
        autoCheckIntervalResolved = Duration(minutes: 5);
      }
    }

    this.autoCheckInterval = autoCheckIntervalResolved;

    // ignore: discarded_futures
    _resolveSharedSessions();
  }

  SharedStore get sharedStore => _sharedStoreField.sharedStore;

  String get sharedSessionsID => 'APISessionSet';

  late final SharedMapField<String, APISession> _sharedSessionsField =
      SharedMapField(sharedSessionsID, sharedStore: sharedStore);

  static const Duration _cacheTimeout = Duration(seconds: 1);

  static final Expando<SharedMap<String, APISession>> _sharedSessions =
      Expando();

  FutureOr<SharedMap<String, APISession>> _resolveSharedSessions() {
    var sharedSessions = _sharedSessions[this];
    if (sharedSessions != null) return sharedSessions;

    return _sharedSessionsField
        .sharedMapCached(timeout: _cacheTimeout)
        .resolveMapped((sharedSessions) {
      _sharedSessions[this] = sharedSessions;
      return sharedSessions;
    });
  }

  FutureOr<int> get length => _resolveSharedSessions().length();

  FutureOr<APISession?> get(String sessionID) {
    autoCheckSessions();
    return _resolveSharedSessions().get(sessionID);
  }

  FutureOr<APISession?> getMarkingAccess(String sessionID) {
    return get(sessionID).resolveMapped((session) {
      session?.markAccessTime();
      return session;
    });
  }

  FutureOr<APISession> put(APISession session) {
    autoCheckSessions();
    return _resolveSharedSessions()
        .put(session.id, session)
        .resolveMapped((s) => s ?? session);
  }

  FutureOr<APISession> getOrCreate(String sessionID) {
    return getMarkingAccess(sessionID).resolveMapped((session) {
      if (session == null) {
        session = APISession(sessionID);
        return put(session);
      }
      return session;
    });
  }

  FutureOr<List<APISession>> expiredSessions([DateTime? now]) {
    now ??= DateTime.now();
    return _resolveSharedSessions()
        .where((id, session) => session.isExpired(timeout, now: now))
        .resolveMapped((entries) => entries.map((e) => e.value).toList());
  }

  FutureOr<int> checkSessions() {
    var now = DateTime.now();

    return expiredSessions(now).resolveMapped((expired) {
      var expiredIDs = expired.map((e) => e.id).toList();
      return _resolveSharedSessions()
          .removeAll(expiredIDs)
          .resolveWithValue(expired.length);
    });
  }

  DateTime _autoCheckSessionsLastTime = DateTime.now();

  void autoCheckSessions() {
    var now = DateTime.now();
    var elapsedTime = now.difference(_autoCheckSessionsLastTime);

    if (elapsedTime.inMilliseconds < autoCheckInterval.inMilliseconds) return;
    _autoCheckSessionsLastTime = now;

    // ignore: discarded_futures
    checkSessions();
  }

  FutureOr<int> clear() => _resolveSharedSessions().clear();
}
