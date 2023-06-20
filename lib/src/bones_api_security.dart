import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_session.dart';

final _log = logging.Logger('APISecurity');

abstract class APISecurity {
  final Duration tokenDuration;
  final int tokenLength;

  APISecurity({Duration? tokenDuration, int? tokenLength})
      : tokenDuration = tokenDuration ?? Duration(hours: 3),
        tokenLength =
            tokenLength != null && tokenLength > 32 ? tokenLength : 512;

  String generateToken(String username) => APIToken.generateToken(512,
      variableLength: 48, prefix: 'TK', random: secureRandom());

  final Random _securePeriodRandom = Random();
  SecureRandom? _secureRandom;
  int _secureRandomUseCount = 0;

  SecureRandom secureRandom() {
    // Create a new `SecureRandom` for every 500 usages
    // to avoid random period exhaustion:
    if (_secureRandomUseCount > 500 &&
        _secureRandomUseCount > 500 + _securePeriodRandom.nextInt(1000)) {
      resetSecureRandom();
    }

    var random = _secureRandom ??= SecureRandom();
    ++_secureRandomUseCount;

    return random;
  }

  void resetSecureRandom() {
    _secureRandom = null;
    _secureRandomUseCount = 0;
  }

  APIToken createToken(String username) => APIToken(username,
      token: generateToken(username), duration: tokenDuration);

  FutureOr<APICredential> prepareCredential(APICredential credential) =>
      credential;

  FutureOr<bool> logout(APICredential? credential,
      {bool allTokens = false, APIRequest? request}) {
    if (credential == null) return false;

    if (!allTokens) {
      if (credential.token == null) return false;
    }

    return checkCredential(credential).then((ok) {
      if (!ok) return false;

      if (allTokens) {
        return invalidateUserTokens(credential.username);
      }

      var apiToken = getTokenByKey(credential.token);
      if (apiToken == null) return false;

      return invalidateToken(apiToken);
    });
  }

  Future<APIAuthentication?> authenticateMultiple(
      List<APICredential> credentials,
      {APIRequest? request}) async {
    if (credentials.isEmpty) return null;

    for (var credential in credentials) {
      var auth = await prepareCredential(credential)
          .resolveMapped((c) => _authenticateImpl(c, request: request));

      if (auth != null) {
        return auth;
      }
    }

    return null;
  }

  FutureOr<APIAuthentication?> authenticate(APICredential? credential,
      {APIRequest? request}) {
    if (credential == null) return null;

    return prepareCredential(credential)
        .resolveMapped((c) => _authenticateImpl(c, request: request));
  }

  FutureOr<APIAuthentication?> _authenticateImpl(APICredential credential,
      {bool resume = false, APIRequest? request}) {
    var requestPath = '';
    if (request != null) {
      requestPath = ' path: ${request.path} >';
    }

    _log.info(
        "authenticate${resume ? '[resume]' : ''}>$requestPath ${credential.hasToken ? credential.token?.truncate(6) : credential.username}");

    return checkCredential(credential).then((ok) {
      if (!ok) return null;
      return _resolveAuthentication(credential, resume)
          .resolveMapped((authentication) {
        if (request != null) {
          resolveRequestAuthentication(request, authentication);
        }
        return authentication;
      });
    });
  }

  final Map<String, MapEntry<Object?, List<APIPermission>>> _tokensInfo =
      <String, MapEntry<Object?, List<APIPermission>>>{};

  void _storeTokenInfo(
      String token, Object? data, List<APIPermission> permissions) {
    permissions = permissions.asUnmodifiableView;

    if (data is List) {
      if (data is! UnmodifiableListView) {
        data = UnmodifiableListView(data);
      }
    } else if (data is Map) {
      if (data is! UnmodifiableMapView) {
        if (data is Map<String, Object?>) {
          data = UnmodifiableMapView<String, Object?>(data);
        } else if (data is Map<String, Object>) {
          data = UnmodifiableMapView<String, Object>(data);
        } else {
          data = UnmodifiableMapView(data);
        }
      }
    } else if (data is Set) {
      if (data is! UnmodifiableSetView) {
        data = UnmodifiableSetView(data);
      }
    }

    _tokensInfo[token] = MapEntry(data, permissions);
  }

  FutureOr<APIAuthentication?> _resolveAuthentication(
      APICredential credential, bool resumed) {
    var token = credential.token;

    Object? prevData;
    List<APIPermission>? prevPermissions;

    if (token != null) {
      var prevInfo = _tokensInfo[token];

      if (prevInfo != null) {
        prevData = prevInfo.key;
        prevPermissions = prevInfo.value;
      }
    }

    return getCredentialPermissions(credential, prevPermissions)
        .resolveMapped((permissions) {
      return getAuthenticationData(credential, prevData).resolveMapped((data) {
        var authentication = createAuthentication(credential, permissions,
            data: data, resumed: resumed);
        _storeTokenInfo(authentication.tokenKey, data, permissions);
        return authentication;
      });
    });
  }

  APIAuthentication createAuthentication(
      APICredential credential, List<APIPermission> permissions,
      {Object? data, bool resumed = false}) {
    APIToken? token;
    if (credential.token != null) {
      token =
          validateToken(APIToken(credential.username, token: credential.token));
    }

    token ??= getValidToken(credential.username)!;

    return APIAuthentication(token,
        permissions: permissions,
        data: data,
        resumed: resumed,
        credential: credential);
  }

  FutureOr<APIAuthentication?> resumeAuthentication(APIToken? token,
      {APIRequest? request}) {
    if (token == null) return null;

    var credential = APICredential(token.username, token: token.token);

    return prepareCredential(credential)
        .resolveMapped((c) => _resumeAuthenticationImpl(c, request: request));
  }

  FutureOr<APIAuthentication?> _resumeAuthenticationImpl(
          APICredential credential,
          {APIRequest? request}) =>
      _authenticateImpl(credential, request: request, resume: true);

  APIToken? getValidToken(String username, {bool autoCreate = true}) {
    List<APIToken> tokens = getUsernameValidTokens(username);

    if (tokens.isEmpty) {
      if (!autoCreate) return null;

      autoValidateAllTokens();

      var token = createToken(username);
      tokens.add(token);

      return token;
    }

    if (tokens.length == 1) {
      return tokens.first;
    }

    tokens.sort();
    var token = tokens.last;

    return token;
  }

  APIToken? validateToken(APIToken token) {
    List<APIToken> tokens = getUsernameValidTokens(token.username);
    if (tokens.isEmpty) return null;

    var idx = tokens.indexOf(token);
    if (idx < 0) return null;

    token = tokens[idx];
    return token;
  }

  final Map<String, List<APIToken>> _usersTokens = <String, List<APIToken>>{};

  APIToken? getTokenByKey(String? tokenKey) {
    if (tokenKey == null || tokenKey.isEmpty) return null;

    for (var l in _usersTokens.values) {
      for (var t in l) {
        if (t.token == tokenKey) {
          return t;
        }
      }
    }

    return null;
  }

  List<APIToken> getUsernameValidTokens(String username) {
    var tokens = _usersTokens.putIfAbsent(username, () => <APIToken>[]);
    tokens.removeExpiredTokens();
    return tokens;
  }

  bool isValidToken(String username, String token) {
    var tokens = _usersTokens[username];
    if (tokens == null || tokens.isEmpty) {
      return false;
    }

    return tokens.where((t) => t.token == token && !t.isExpired()).isNotEmpty;
  }

  DateTime _autoValidateAllTokensLastTime = DateTime.now();

  void autoValidateAllTokens() {
    var now = DateTime.now();
    var elapsedTime = _autoValidateAllTokensLastTime.difference(now);

    if (elapsedTime.inMinutes < 5) return;
    _autoValidateAllTokensLastTime = now;

    validateAllTokens(now);
  }

  void validateAllTokens([DateTime? now]) {
    now ??= DateTime.now();

    var emptyUsers = <String>[];

    for (var e in _usersTokens.entries) {
      var user = e.key;
      var tokens = e.value;

      var expired = tokens.removeExpiredTokens(now: now);

      _onInvalidateTokens(expired);

      if (tokens.isEmpty) {
        emptyUsers.add(user);
      }
    }

    _usersTokens.removeKeys(emptyUsers);
  }

  void _onInvalidateTokens(List<APIToken> tokens) {
    for (var t in tokens) {
      _onInvalidateToken(t);
    }
  }

  void _onInvalidateToken(APIToken apiToken) {
    _tokensInfo.remove(apiToken.token);
  }

  bool invalidateUserTokens(String username) {
    var userTokens = _usersTokens[username];
    if (userTokens == null || userTokens.isEmpty) return false;

    var tokens = userTokens.toList();

    userTokens.clear();
    _usersTokens.remove(username);

    _onInvalidateTokens(tokens);

    return true;
  }

  bool invalidateToken(APIToken apiToken) {
    var username = apiToken.username;

    var userTokens = _usersTokens[username];
    if (userTokens == null || userTokens.isEmpty) return false;

    if (userTokens.remove(apiToken)) {
      if (userTokens.isEmpty) {
        _usersTokens.remove(username);
      }

      _onInvalidateToken(apiToken);
      return true;
    } else {
      return false;
    }
  }

  FutureOr<bool> checkCredential(APICredential credential) {
    if (credential.hasToken) {
      return checkCredentialToken(credential);
    } else if (credential.hasPassword) {
      return checkCredentialPassword(credential);
    } else {
      return false;
    }
  }

  FutureOr<bool> checkCredentialToken(APICredential credential) {
    return isValidToken(credential.username, credential.token!);
  }

  FutureOr<bool> checkCredentialPassword(APICredential credential);

  FutureOr<List<APIPermission>> getCredentialPermissions(
      APICredential credential, List<APIPermission>? previousPermissions);

  FutureOr<Object?> getAuthenticationData(
          APICredential credential, Object? previousData) =>
      null;

  bool disposeAuthenticationData(APICredential credential) {
    var disposeUsernameEntity = credential.usernameEntity != null;
    credential.usernameEntity = null;

    var disposeTokenInfo = false;

    var token = credential.token;

    if (token != null) {
      var prevInfo = _tokensInfo.remove(token);
      disposeTokenInfo = prevInfo != null;
    }

    return disposeUsernameEntity || disposeTokenInfo;
  }

  FutureOr<APIAuthentication?> authenticateByRequest(APIRequest request,
      {bool allowLogout = false}) {
    var credentials = resolveRequestCredentials(request);

    if (credentials.isEmpty) {
      var sessionCredential = resolveSessionCredential(request);
      if (sessionCredential != null) credentials.add(sessionCredential);
    }

    if (credentials.isEmpty) {
      return null;
    }

    var logout = allowLogout &&
        (request.parameters.getAsBool('logout') ??
            request.parameters.getAsBool('logoff') ??
            false);

    if (logout) {
      var allTokens = allowLogout &&
          (request.parameters.getAsBool('all') ??
              request.parameters.getAsBool('allTokens', ignoreCase: true) ??
              false);

      var credential = credentials.last;
      request.credential = credential;
      request.originalCredential ??= credential;

      return this
          .logout(credential, allTokens: allTokens, request: request)
          .resolveMapped((ok) {
        if (ok) {
          request.credential = null;
        }

        return null;
      });
    }

    if (credentials.length == 1) {
      var credential = credentials.last;
      request.credential = credential;
      request.originalCredential ??= credential;

      return authenticate(credential, request: request);
    }

    request.credential ??= credentials.first;
    request.originalCredential ??= request.credential;

    return authenticateMultiple(credentials, request: request).then((auth) {
      APICredential? credential;
      if (auth != null) {
        credential = request.credential = auth.credential;
      } else {
        credential = request.credential = credentials.first;
      }

      request.originalCredential ??= credential;
      return auth;
    });
  }

  FutureOr<APIAuthentication?> resumeAuthenticationByRequest(
      APIRequest request) {
    var token = getSessionToken(request);
    if (token == null) {
      var credential = request.credential;

      if (credential != null && credential.hasToken) {
        var tokenKey = credential.token!;
        token = getTokenByKey(tokenKey);
        if (token == null) return null;
      } else {
        return null;
      }
    }

    return resumeAuthentication(token, request: request);
  }

  APICredential? resolveSessionCredential(APIRequest request) {
    APIToken? recentToken = getSessionToken(request);

    if (recentToken != null) {
      return APICredential(recentToken.username, token: recentToken.token);
    } else {
      return null;
    }
  }

  APIToken? getSessionToken(APIRequest request) {
    var tokens = getSessionValidTokens(request);
    var recentToken = getMostRecentToken(tokens);
    return recentToken;
  }

  APIToken? getMostRecentToken(Set<APIToken>? tokens) {
    if (tokens == null || tokens.isEmpty) return null;

    if (tokens.length == 1) return tokens.first;

    var list = tokens.toList();
    list.sort();

    return list.last;
  }

  final APISessionSet _sessionSet = APISessionSet(Duration(hours: 3));

  void resolveRequestAuthentication(
      APIRequest request, APIAuthentication? authentication) {
    request.authentication = authentication;

    if (authentication != null) {
      var token = authentication.token;
      token.markAccessTime();

      var sessionID = request.sessionID;
      if (sessionID != null) {
        var session = _sessionSet.getMarkingAccess(sessionID);
        if (session == null) {
          session = APISession(sessionID);
          _sessionSet.put(session);
        }

        session.tokens.add(token);
      }
    }
  }

  Set<APIToken>? getSessionValidTokens(APIRequest request) {
    var sessionID = request.sessionID;
    if (sessionID == null) return null;

    var session = _sessionSet.getMarkingAccess(sessionID);
    var tokens = session?.validateTokens();
    if (tokens == null || tokens.isEmpty) return null;

    var usernames = tokens.map((e) => e.username).toSet();

    var validTokens = usernames.expand(getUsernameValidTokens).toList();

    tokens.removeWhere((t) => !validTokens.contains(t));

    if (request.credential != null) {
      var credentialUsername = request.credential!.username;
      if (!usernames.contains(credentialUsername)) return null;

      var tokensUsername =
          tokens.where((t) => t.username == credentialUsername).toSet();
      return tokensUsername;
    } else {
      return tokens;
    }
  }

  FutureOr<APIResponse<T>> doRequestAuthentication<T>(APIRequest request) {
    var response = APIResponse<T>.unauthorized(payloadDynamic: 'UNAUTHORIZED');
    response.startMetric('authentication');

    return authenticateByRequest(request, allowLogout: true)
        .then((authentication) {
      response.stopMetric('authentication');

      if (authentication == null) {
        return response;
      }

      T payload;
      if (T == APIAuthentication) {
        payload = authentication as T;
      } else {
        payload = authentication.toJson() as T;
      }

      return response.asOk(payload: payload);
    });
  }

  List<APICredential> resolveRequestCredentials(APIRequest request) {
    var credentials = <APICredential>[];

    var credential = request.credential;

    if (credential != null) {
      if (credential.username.isEmpty && credential.hasToken) {
        var tokenKey = credential.token!;
        var sessionID = request.sessionID;

        APIToken? validToken;
        if (sessionID != null && sessionID.isNotEmpty) {
          validToken = _sessionSet.get(sessionID)?.getValidToken(tokenKey);
        }

        validToken ??= getTokenByKey(tokenKey);

        if (validToken != null) {
          var username = validToken.username;
          credential = credential.withUsername(username);
        }
      }

      credentials.add(credential);
    }

    var username = getRequestParameterUsername(request).trim();
    var tokenKey = getRequestParameterToken(request).trim();

    if (username.isNotEmpty) {
      if (tokenKey.isNotEmpty) {
        var credential = APICredential(username, token: tokenKey);
        credentials.add(credential);
      } else {
        var password = getRequestParameterPassword(request).trim();

        var credential = APICredential(username, passwordHash: password);
        credentials.add(credential);
      }
    } else if (tokenKey.isNotEmpty) {
      var token = getTokenByKey(tokenKey);
      if (token != null && !token.isExpired()) {
        var credential = APICredential(token.username, token: token.token);
        credentials.add(credential);
      }
    }

    return credentials;
  }

  String getRequestParameterPassword(APIRequest request) {
    return (request.getParameterIgnoreCaseFirstOf('password', 'pass',
                'passphrase', 'passwordHash', 'passwordOrHash') ??
            '')
        .toString();
  }

  String getRequestParameterToken(APIRequest request) {
    var token = request.getParameterIgnoreCaseFirstOf(
        'token', 'access_token', 'accessToken');

    token ??= request.getHeaderFirstOf(
        'x-token', 'token', 'x-access-token', 'access-token');

    return (token ?? '').toString();
  }

  String getRequestParameterUsername(APIRequest request) {
    return (request.getParameterIgnoreCaseFirstOf(
                'username', 'user', 'email', 'account') ??
            '')
        .toString();
  }
}

/// A route rule.
abstract class APIRouteRule {
  /// If `true` apply this [APIRouteRule] declaration to all routes/methods.
  /// If `false` this instance will be applied only to routes/methods without
  /// any [APIRouteRule] declaration.
  final bool globalRules;

  /// If `true` blocks [APIRouteRule] with [globalRules] to be applied to
  /// the route/method with this declaration.
  final bool noGlobalRules;

  const APIRouteRule({this.globalRules = false, this.noGlobalRules = false});

  /// Returns `true` if the [request] is valid by this rule.
  bool validate(APIRequest request);

  Map<String, Object> toJson();
}

/// A route rule for public access.
class APIRoutePublicRule extends APIRouteRule {
  const APIRoutePublicRule() : super();

  @override
  bool validate(APIRequest request) {
    return true;
  }

  @override
  String toString() {
    return 'APIRoutePublicRule{}';
  }

  @override
  Map<String, Object> toJson() => {'rule': 'public'};
}

/// A route rule for access only for NOT authenticated requests.
class APIRouteNotAuthenticatedRule extends APIRouteRule {
  const APIRouteNotAuthenticatedRule() : super();

  @override
  bool validate(APIRequest request) {
    var authentication = request.authentication;
    if (authentication == null) return true;
    return authentication.token.isExpired();
  }

  @override
  String toString() {
    return 'APIRouteNotAuthenticatedRule{}';
  }

  @override
  Map<String, Object> toJson() => {'rule': 'not_authenticated'};
}

/// A route rule for access only for authenticated requests ([APIAuthentication]).
class APIRouteAuthenticatedRule extends APIRouteRule {
  const APIRouteAuthenticatedRule() : super();

  @override
  bool validate(APIRequest request) {
    var authentication = request.authentication;
    if (authentication == null) return false;
    return !authentication.token.isExpired();
  }

  @override
  String toString() {
    return 'APIRouteAuthenticatedRule{}';
  }

  @override
  Map<String, Object> toJson() => {'rule': 'authenticated'};
}

/// A route rule for access only for authenticated requests with the required permissions ([APIAuthentication.permissions]).
class APIRoutePermissionTypeRule extends APIRouteAuthenticatedRule {
  final Iterable<String> _requiredPermissionTypes;

  const APIRoutePermissionTypeRule(Iterable<String> requiredPermissionTypes)
      : _requiredPermissionTypes = requiredPermissionTypes,
        super();

  static final Expando<Set<String>> _expandoNormalizedTypes =
      Expando<Set<String>>();

  /// The required permission types.
  Set<String> get requiredPermissionTypes {
    var normalizedType = _expandoNormalizedTypes[this];
    if (normalizedType != null) return normalizedType;

    normalizedType = _requiredPermissionTypes
        .map(APIPermission.normalizeType)
        .where(APIPermission.validateType)
        .toSet();

    _expandoNormalizedTypes[this] = normalizedType;
    return normalizedType;
  }

  @override
  bool validate(APIRequest request) {
    if (!super.validate(request)) return false;

    var authentication = request.authentication!;

    var requiredPermissionTypes = this.requiredPermissionTypes;

    var authPermissions = authentication
        .enabledPermissionsOfTypes(requiredPermissionTypes)
        .map((e) => e.type)
        .toSet();

    return authPermissions.length == requiredPermissionTypes.length;
  }

  @override
  String toString() {
    return 'APIRoutePermissionTypeRule{${requiredPermissionTypes.join(', ')}}';
  }

  @override
  Map<String, Object> toJson() =>
      {'rule': 'permission', 'types': requiredPermissionTypes.toList()};
}

/// Defines an [EntityResolutionRules] for a route.
class APIEntityResolutionRules extends APIRouteRule {
  final EntityResolutionRules resolutionRules;

  const APIEntityResolutionRules(this.resolutionRules,
      {super.globalRules, super.noGlobalRules});

  @override
  bool validate(APIRequest request) => true;

  @override
  String toString() {
    return 'APIEntityResolutionRules@$resolutionRules';
  }

  @override
  Map<String, Object> toJson() =>
      <String, Object>{'resolutionRules': resolutionRules.toJson()};
}

/// Defines an [EntityAccessRules] for a route.
class APIEntityAccessRules extends APIRouteRule {
  final EntityAccessRules accessRules;

  const APIEntityAccessRules(this.accessRules,
      {super.globalRules, super.noGlobalRules});

  @override
  bool validate(APIRequest request) => true;

  @override
  String toString() {
    return 'APIEntityAccessRules@$accessRules';
  }

  @override
  Map<String, Object> toJson() =>
      <String, Object>{'accessRules': accessRules.toJson()};
}

/// Defines an [EntityResolutionRules] for a route.
class APIEntityRules extends APIRouteRule {
  final List<EntityRules> rules;

  const APIEntityRules(this.rules, {super.globalRules, super.noGlobalRules});

  List<EntityResolutionRules> get entityResolutionRules =>
      rules.whereType<EntityResolutionRules>().toList();

  List<EntityAccessRules> get entityAccessRules =>
      rules.whereType<EntityAccessRules>().toList();

  @override
  bool validate(APIRequest request) => true;

  @override
  String toString() {
    return 'APIEntityRules@$rules';
  }

  @override
  Map<String, Object> toJson() =>
      <String, Object>{'rules': rules.map((e) => e.toJson()).toList()};
}

class SecureRandom implements Random {
  static final Random _globalRandom1 = Random()
    ..advance(maxSteps: 211, random: Random());

  static int _seedCounter = 0;

  static int _generateSeedBasic() {
    var c = ++_seedCounter;

    var r1 = Random()..advance(maxSteps: 97);
    var r2 = Random(_globalRandom1.nextSeed() ^ c);
    var r3 = Random(r1.nextSeed() ^ r2.nextSeed() ^ (c * 31));

    var s1 = r1.nextSeed();
    var s2 = r2.nextSeed();
    var s3 = r3.nextSeed();

    if (r1.nextBool()) {
      s2 ^= r3.nextSeed(layers: 7);
    }

    if (r2.nextBool()) {
      s3 ^= r1.nextSeed(layers: 11);
    }

    if (r3.nextBool()) {
      s1 ^= r2.nextSeed(layers: 13);
    }

    return s1 ^ s2 ^ s3;
  }

  /// Generates a seed to be used to instantiate [Random].
  static int generateSeed() {
    var s1 = _generateSeedBasic();
    var s2 = _globalRandom1.nextSeed();
    var s3 = _generateSeedBasic();
    var s4 = Random().nextSeed() * 33;

    return s1 ^ s2 ^ s3 ^ s4;
  }

  /// Tries to return [Random.secure()]. If not supported by the
  /// current platform, returns a fallback ([_SecureRandomFallback]).
  ///
  /// - [forceFallbackSecureRandom] if `true` forces to return a [_SecureRandomFallback] instance.
  static Random createPlatformSecureRandom(
      {bool forceFallbackSecureRandom = false}) {
    if (forceFallbackSecureRandom) {
      return _SecureRandomFallback();
    }

    try {
      return Random.secure();
    } catch (e) {
      return _SecureRandomFallback();
    }
  }

  final Random _random;

  SecureRandom({bool forceFallbackSecureRandom = false})
      : _random = createPlatformSecureRandom(
            forceFallbackSecureRandom: forceFallbackSecureRandom);

  @override
  bool nextBool() => _random.nextBool();

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int max) => _random.nextInt(max);

  bool get isFallbackSecureRandom => _random is _SecureRandomFallback;

  @override
  String toString() {
    return 'SecureRandom{ fallbackSecureRandom: $isFallbackSecureRandom }';
  }
}

class _SecureRandomFallback implements Random {
  final Random _random;

  _SecureRandomFallback() : _random = Random(SecureRandom.generateSeed()) {
    _random.advance(maxSteps: 211, random: Random(SecureRandom.generateSeed()));
  }

  @override
  bool nextBool() => _random.nextBool();

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int max) => _random.nextInt(max);
}

extension RandomExtension on Random {
  int nextSeed({int layers = 5}) {
    if (layers == 5) {
      return _nextSeedImpl() ^
          _nextSeedImpl() ^
          _nextSeedImpl() ^
          _nextSeedImpl() ^
          _nextSeedImpl();
    }

    if (layers <= 1) {
      return _nextSeedImpl();
    }

    var seed = _nextSeedImpl();
    for (var i = 1; i < layers; ++i) {
      seed ^= _nextSeedImpl();
    }
    return seed;
  }

  static final int _maxInt = 2147000000;

  int _nextSeedImpl() {
    var n = nextInt(_maxInt);
    return nextBool() ? -n : n;
  }

  int nextBytes(Uint8List bytes, [int? length]) {
    length ??= bytes.length;

    for (var i = 0; i < length; ++i) {
      var b = nextInt(256);
      bytes[i] = b;
    }

    return length;
  }

  Uint8List randomBytes(int length) {
    var bs = Uint8List(length);
    nextBytes(bs, length);
    return bs;
  }

  int advance({int minSteps = 0, int maxSteps = 97, Random? random}) {
    random ??= this;

    var steps = random.nextInt(maxSteps);
    if (steps < minSteps) {
      steps = minSteps;
    }

    for (var i = 0; i < steps; ++i) {
      nextDouble();
    }

    return steps;
  }
}
