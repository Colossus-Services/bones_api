import 'dart:math';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:shared_map/shared_map.dart';
import 'package:statistics/statistics.dart' hide IterableIntExtension;

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_session.dart';

final _log = logging.Logger('APISecurity');

abstract class APISecurity {
  final SharedStoreField _sharedStoreField;

  final Duration tokenDuration;
  final int tokenLength;

  late final APITokenStore _tokenStore;

  APISecurity(
      {Duration? tokenDuration,
      int? tokenLength,
      APIRoot? apiRoot,
      SharedStoreField? sharedStoreField,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedStoreProviderSync? storeProvider})
      : tokenDuration = tokenDuration ?? Duration(hours: 3),
        tokenLength =
            tokenLength != null && tokenLength > 32 ? tokenLength : 512,
        _sharedStoreField = SharedStoreField.tryFrom(
                sharedStoreField: sharedStoreField,
                sharedStoreReference: sharedStoreReference,
                sharedStore: sharedStore ?? apiRoot?.sharedStore,
                sharedStoreID: sharedStoreID,
                storeProvider: storeProvider) ??
            SharedStoreField.fromSharedStore(SharedStore.notShared()) {
    _tokenStore = resolveTokensStore();
  }

  APITokenStore resolveTokensStore() =>
      APITokenStore(sharedStoreField: _sharedStoreField);

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
      token: generateToken(username),
      duration: tokenDuration,
      withRefreshToken: true);

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

      return getAPIToken(credential.token).resolveMapped((apiToken) {
        if (apiToken == null) return false;
        return invalidateToken(apiToken);
      });
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
      return _resolveAuthentication(credential, resume, request)
          .resolveMapped((authentication) {
        if (request != null) {
          return resolveRequestAuthentication(request, authentication);
        } else {
          return authentication;
        }
      });
    });
  }

  FutureOr<APIAuthentication?> _resolveAuthentication(
      APICredential credential, bool resumed, APIRequest? request) {
    var token = credential.token;

    if (token == null) {
      return _resolveAuthenticationImpl(
          credential, resumed, null, null, null, request);
    }

    var prevToken = _tokenStore.get(token);

    return prevToken.resolveMapped((prevToken) {
      APIToken? prevAPIToken;
      Object? prevData;
      List<APIPermission>? prevPermissions;

      if (prevToken != null) {
        prevAPIToken = prevToken.apiToken;
        prevData = prevToken.data;
        prevPermissions = prevToken.permissions;
      }

      return _resolveAuthenticationImpl(credential, resumed, prevAPIToken,
          prevData, prevPermissions, request);
    });
  }

  FutureOr<APIAuthentication?> _resolveAuthenticationImpl(
      APICredential credential,
      bool resumed,
      APIToken? prevAPIToken,
      Object? prevData,
      List<APIPermission>? prevPermissions,
      APIRequest? request) {
    var permissions = getCredentialPermissions(credential, prevPermissions);
    var data = getAuthenticationData(credential, prevData);

    return permissions.resolveOther(data, (permissions, data) {
      return createAuthentication(credential, permissions,
              data: data, resumed: resumed)
          .resolveMapped((authentication) {
        var changedAPIToken = prevAPIToken != authentication.token;
        var changedData = !identical(prevData, data);
        var changedPermissions = !identical(prevPermissions, permissions);

        var changed = changedAPIToken || changedData || changedPermissions;

        if (!changed) {
          return authentication;
        }

        return _tokenStore
            .storeAPIToken(authentication.token, data, permissions)
            .resolveMapped((apiTokenInfo) {
          if (apiTokenInfo != null && changedAPIToken) {
            onNewAPIToken(apiTokenInfo.apiToken, false, request: request);
          }
          return authentication;
        });
      });
    });
  }

  void onNewAPIToken(APIToken token, bool refreshed, {APIRequest? request}) {}

  FutureOr<APIAuthentication> createAuthentication(
      APICredential credential, List<APIPermission> permissions,
      {Object? data, bool resumed = false}) {
    if (credential.token == null) {
      return _createAuthenticationImpl(credential, permissions, data, resumed);
    }

    var credentialToken =
        APIToken.fromCredential(credential, duration: tokenDuration);

    return validateToken(credentialToken).resolveMapped((token) {
      if (token != null) {
        return APIAuthentication(token,
            permissions: permissions,
            data: data,
            resumed: resumed,
            credential: credential);
      }

      return _createAuthenticationImpl(credential, permissions, data, resumed);
    });
  }

  FutureOr<APIAuthentication> _createAuthenticationImpl(
          APICredential credential,
          List<APIPermission> permissions,
          Object? data,
          bool resumed) =>
      getValidToken(credential.username, autoCreate: true)
          .resolveMapped((token) {
        return APIAuthentication(token!,
            permissions: permissions,
            data: data,
            resumed: resumed,
            credential: credential);
      });

  FutureOr<APIAuthentication?> resumeAuthentication(APIToken? apiToken,
      {APIRequest? request}) {
    if (apiToken == null) return null;

    var credential = APICredential(apiToken.username, token: apiToken.token);

    return prepareCredential(credential)
        .resolveMapped((c) => _resumeAuthenticationImpl(c, request: request));
  }

  FutureOr<APIAuthentication?> _resumeAuthenticationImpl(
          APICredential credential,
          {APIRequest? request}) =>
      _authenticateImpl(credential, request: request, resume: true);

  FutureOr<APIToken?> getValidToken(String username,
      {required bool autoCreate}) {
    return getUsernameValidTokens(username).resolveMapped((userTokens) {
      if (userTokens.isEmpty) {
        if (!autoCreate) return null;

        var token = createToken(username);
        userTokens.add(token);

        autoValidateAllTokens();

        return token;
      }

      if (userTokens.length == 1) {
        return userTokens.first;
      }

      userTokens.sort();
      var token = userTokens.last;
      return token;
    });
  }

  FutureOr<APIToken?> validateToken(APIToken token) {
    if (!token.token.startsWith('TK')) return null;

    return getUsernameValidTokens(token.username).resolveMapped((userTokens) {
      if (userTokens.isEmpty) return null;

      var idx = userTokens.indexOf(token);
      if (idx < 0) {
        return validateUnknownToken(token.username, token.token);
      }

      token = userTokens[idx];
      return token;
    });
  }

  /// This should be overridden to allow validation of tokens not stored in memory.
  /// If an [APIToken] with the same [token] is returned, the [token] will be
  /// treated as valid and authentication will be allowed.
  /// Default return: `null`
  FutureOr<APIToken?> validateUnknownToken(String username, String token) {
    // _log.info('Unknown Token: $token');
    return null;
  }

  FutureOr<APIToken?> getAPIToken(String? token) {
    if (token == null || token.isEmpty || !token.startsWith('TK')) return null;
    return _tokenStore.get(token).resolveMapped((token) => token?.apiToken);
  }

  FutureOr<APIToken?> refreshAPIToken(String? username, String? refreshToken,
      {APIRequest? request}) {
    if (username == null ||
        refreshToken == null ||
        username.isEmpty ||
        refreshToken.isEmpty) {
      return null;
    }

    return validateRefreshToken(username, refreshToken).resolveMapped((ok) {
      if (!ok) return null;

      return getUsernameValidTokens(username).resolveMapped((userTokens) {
        var token = createToken(username);
        userTokens.add(token);

        autoValidateAllTokens();

        var newTokenCredential = APICredential(username,
            token: token.token, refreshToken: token.refreshToken);

        return getCredentialPermissions(newTokenCredential, null)
            .resolveMapped((permission) {
          return _tokenStore
              .storeAPIToken(token, null, permission)
              .resolveMapped((apiTokenInfo) {
            var apiToken = apiTokenInfo?.apiToken;
            if (apiToken != null) {
              onNewAPIToken(apiToken, true, request: request);
            }
            return apiToken;
          });
        });
      });
    });
  }

  /// This should be overridden to allow refresh tokens.
  /// If `true` is returned, it will allow the generation of a
  /// new valid token and enable authentication.
  /// Default return: `true`
  FutureOr<bool> validateRefreshToken(String username, String refreshToken) {
    if (username.isEmpty || !refreshToken.startsWith('RTK')) return false;

    return false;
  }

  FutureOr<List<APIToken>> getUsernameValidTokens(String username) {
    return _tokenStore.getByUsername(username, checkExpiredTokens: true);
  }

  FutureOr<bool> isValidToken(String username, String token) {
    if (!token.startsWith('TK')) return false;

    return _tokenStore
        .getByUsername(username, checkExpiredTokens: true)
        .resolveMapped((userTokens) {
      if (userTokens.any((t) => t.token == token)) {
        return true;
      }

      return validateUnknownToken(username, token).resolveMapped((apiToken) {
        return apiToken?.token == token;
      });
    });
  }

  DateTime _autoValidateAllTokensLastTime = DateTime.now();

  void autoValidateAllTokens() {
    var now = DateTime.now();
    var elapsedTime = _autoValidateAllTokensLastTime.difference(now);

    if (elapsedTime.inMinutes < 5) return;
    _autoValidateAllTokensLastTime = now;

    // ignore: discarded_futures
    validateAllTokens(now);
  }

  FutureOr<int> validateAllTokens([DateTime? now]) =>
      _tokenStore.validateAllTokens(now).resolveMapped((l) => l.length);

  FutureOr<bool> invalidateUserTokens(String username) => _tokenStore
      .removeUsernameTokens(username, checkExpiredTokens: true)
      .resolveMapped((removed) => removed.isNotEmpty);

  FutureOr<bool> invalidateToken(APIToken apiToken) => _tokenStore
      .removeAPIToken(apiToken)
      .resolveMapped((removed) => removed != null);

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

  FutureOr<bool> disposeAuthenticationData(APICredential credential) {
    var disposeUsernameEntity = credential.usernameEntity != null;
    credential.usernameEntity = null;

    var token = credential.token;

    if (token == null) {
      return disposeUsernameEntity;
    }

    var prevToken = _tokenStore.removeTokenData(token);

    return prevToken.resolveMapped((prevToken) {
      var disposeTokenData = prevToken != null;
      return disposeUsernameEntity || disposeTokenData;
    });
  }

  FutureOr<bool> disposeAuthenticationToken(APICredential credential) {
    var disposeUsernameEntity = credential.usernameEntity != null;
    credential.usernameEntity = null;

    var token = credential.token;

    if (token == null) {
      return disposeUsernameEntity;
    }

    var prevToken = _tokenStore.removeToken(token);

    return prevToken.resolveMapped((prevToken) {
      var disposeTokenInfo = prevToken != null;
      return disposeUsernameEntity || disposeTokenInfo;
    });
  }

  FutureOr<APIAuthentication?> authenticateByRequest(APIRequest request,
      {bool allowLogout = false}) {
    return resolveRequestCredentials(request).resolveMapped((credentials) {
      if (credentials.isEmpty) {
        return resolveSessionCredential(request)
            .resolveMapped((sessionCredential) {
          if (sessionCredential != null) credentials.add(sessionCredential);
          return _authenticateByRequestImpl(credentials, request, allowLogout);
        });
      } else {
        return _authenticateByRequestImpl(credentials, request, allowLogout);
      }
    });
  }

  FutureOr<APIAuthentication?> _authenticateByRequestImpl(
      List<APICredential> credentials, APIRequest request, bool allowLogout) {
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
          onLogout(credential);
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

  void onLogout(APICredential credential) {}

  FutureOr<APIAuthentication?> resumeAuthenticationByRequest(
      APIRequest request) {
    return getSessionAPIToken(request).resolveMapped((apiToken) {
      if (apiToken != null) {
        return resumeAuthentication(apiToken, request: request);
      }

      var credential = request.credential;
      if (credential != null && credential.hasToken) {
        var token = credential.token!;

        return getAPIToken(token).resolveMapped((apiToken) {
          return resumeAuthentication(apiToken, request: request);
        });
      }

      return null;
    });
  }

  FutureOr<APICredential?> resolveSessionCredential(APIRequest request) {
    return getSessionAPIToken(request).resolveMapped((recentToken) {
      if (recentToken != null) {
        return APICredential(recentToken.username, token: recentToken.token);
      } else {
        return null;
      }
    });
  }

  FutureOr<APIToken?> getSessionAPIToken(APIRequest request) {
    return getSessionValidTokens(request).resolveMapped((tokens) {
      var recentToken = getMostRecentToken(tokens);
      return recentToken;
    });
  }

  APIToken? getMostRecentToken(Set<APIToken>? tokens) {
    if (tokens == null || tokens.isEmpty) return null;

    if (tokens.length == 1) return tokens.first;

    var list = tokens.toList();
    list.sort();

    return list.last;
  }

  late final APISessionSet _sessionSet =
      APISessionSet(Duration(hours: 3), sharedStoreField: _sharedStoreField);

  FutureOr<APIAuthentication?> resolveRequestAuthentication(
      APIRequest request, APIAuthentication? authentication) {
    request.authentication = authentication;
    if (authentication == null) return null;

    var token = authentication.token;
    token.markAccessTime();

    var sessionID = request.sessionID;
    if (sessionID == null) return authentication;

    return _sessionSet.getOrCreate(sessionID).resolveMapped((session) {
      session.tokens.add(token);
      return authentication;
    });
  }

  FutureOr<Set<APIToken>?> getSessionValidTokens(APIRequest request) {
    var sessionID = request.sessionID;
    if (sessionID == null) return null;

    return _sessionSet.getMarkingAccess(sessionID).resolveMapped((session) {
      var sessionTokens = session?.validateTokens();
      if (sessionTokens == null || sessionTokens.isEmpty) return null;

      var usernames = sessionTokens.map((e) => e.username);

      return _tokenStore
          .getByUsernames(usernames, checkExpiredTokens: true)
          .resolveMapped((validTokens) {
        sessionTokens.removeWhere((t) => !validTokens.contains(t));

        if (request.credential != null) {
          var credentialUsername = request.credential!.username;
          if (!usernames.contains(credentialUsername)) return null;

          var tokensWithUsername = sessionTokens
              .where((t) => t.username == credentialUsername)
              .toSet();
          return tokensWithUsername;
        } else {
          return sessionTokens;
        }
      });
    });
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

  FutureOr<List<APICredential>> resolveRequestCredentials(APIRequest request) {
    var credential = request.credential;
    if (credential == null) {
      return _resolveRequestCredentialsImpl(request, []);
    }

    if (credential.username.isEmpty && credential.hasToken) {
      var tokenKey = credential.token!;
      var sessionID = request.sessionID;

      if (sessionID != null && sessionID.isNotEmpty) {
        return _sessionSet.get(sessionID).resolveMapped((session) {
          var validToken = session?.getValidToken(tokenKey);
          return _resolveRequestCredentialsTokens(
              request, credential, tokenKey, validToken);
        });
      }

      return _resolveRequestCredentialsTokens(
          request, credential, tokenKey, null);
    }

    return _resolveRequestCredentialsImpl(request, [credential]);
  }

  FutureOr<List<APICredential>> _resolveRequestCredentialsTokens(
      APIRequest request,
      APICredential credential,
      String tokenKey,
      APIToken? validToken) {
    if (validToken != null) {
      var username = validToken.username;
      credential = credential.withUsername(username);
      return _resolveRequestCredentialsImpl(request, [credential]);
    } else {
      return getAPIToken(tokenKey).resolveMapped((validToken) {
        if (validToken != null) {
          var username = validToken.username;
          credential = credential.withUsername(username);
          return _resolveRequestCredentialsImpl(request, [credential]);
        } else {
          return validateUnknownToken(credential.username, tokenKey)
              .resolveMapped((validToken) {
            if (validToken != null) {
              var username = validToken.username;
              credential = credential.withUsername(username);
            }
            return _resolveRequestCredentialsImpl(request, [credential]);
          });
        }
      });
    }
  }

  FutureOr<List<APICredential>> _resolveRequestCredentialsImpl(
      APIRequest request, List<APICredential> credentials) {
    var username = getRequestParameterUsername(request).trim();
    var token = getRequestParameterToken(request).trim();
    var refreshToken =
        token.isEmpty ? getRequestParameterRefreshToken(request).trim() : '';

    if (username.isNotEmpty) {
      if (token.isNotEmpty) {
        var credential = APICredential(username, token: token);
        credentials.add(credential);
      } else if (refreshToken.isNotEmpty) {
        return refreshAPIToken(username, refreshToken, request: request)
            .resolveMapped((apiToken) {
          if (apiToken != null && !apiToken.isExpired()) {
            var credential = APICredential(apiToken.username,
                token: apiToken.token, refreshToken: apiToken.refreshToken);
            credentials.add(credential);
          }
          return credentials;
        });
      } else {
        var password = getRequestParameterPassword(request).trim();
        var credential = APICredential(username, passwordHash: password);
        credentials.add(credential);
      }
    } else if (token.isNotEmpty) {
      return getAPIToken(token).resolveMapped((apiToken) {
        if (apiToken != null && !apiToken.isExpired()) {
          var credential =
              APICredential(apiToken.username, token: apiToken.token);
          credentials.add(credential);
        }
        return credentials;
      });
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

  String getRequestParameterRefreshToken(APIRequest request) {
    var refreshToken = request.getParameterIgnoreCaseFirstOf(
        'refreshToken', 'refresh_token', 'refreshtoken');

    refreshToken ??=
        request.getHeaderFirstOf('x-refresh-token', 'refresh-token');

    return (refreshToken ?? '').toString();
  }

  String getRequestParameterUsername(APIRequest request) {
    return (request.getParameterIgnoreCaseFirstOf(
                'username', 'user', 'email', 'account') ??
            '')
        .toString();
  }
}

typedef APITokenInfo = ({
  APIToken apiToken,
  Object? data,
  List<APIPermission> permissions
});

/// The tokens store for the [APISecurity].
class APITokenStore {
  final SharedStoreField _sharedStoreField;

  APITokenStore(
      {SharedStoreField? sharedStoreField,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedStoreProviderSync? storeProvider})
      : _sharedStoreField = SharedStoreField.from(
          sharedStoreField: sharedStoreField,
          sharedStore: sharedStore,
          sharedStoreID: sharedStoreID,
          storeProvider: storeProvider,
        ) {
    // ignore: discarded_futures
    _resolveSharedTokens().then((_) async {
      _resolveSharedTokensByUsername();
    });
  }

  SharedStore get sharedStore => _sharedStoreField.sharedStore;

  String get sharedTokensID => 'APITokenStore';

  late final SharedMapField<String, APITokenInfo> _sharedTokensField =
      SharedMapField(
    sharedTokensID,
    sharedStore: sharedStore,
    onInitialize: _sharedTokensOnInitialize,
    onAbsent: _sharedTokensOnAbsent,
    onPut: _sharedTokensOnPut,
    onRemove: _sharedTokensOnRemove,
  );

  late final SharedMapField<String, List<APIToken>>
      _sharedTokensByUsernameField =
      SharedMapField('$sharedTokensID:byUsername', sharedStore: sharedStore);

  FutureOr<void> _sharedTokensOnInitialize(SharedMap sharedTokens) {
    if (sharedTokens.isAuxiliaryInstance) return null;

    _log.info("Initialized `sharedTokens`: $sharedTokens");
  }

  APITokenInfo? _sharedTokensOnAbsent(String token) {
    // _log.info("`sharedTokens` -> onAbsent: $token");
    return null;
  }

  FutureOr<void> _sharedTokensOnPut(String token, APITokenInfo? tokenInfo) {
    return _resolveSharedTokensByUsername()
        .resolveMapped((sharedTokensByUsername) {
      if (tokenInfo == null) return null;
      final apiToken = tokenInfo.apiToken;
      final username = apiToken.username;

      return sharedTokensByUsername
          .putIfAbsent(username, []).resolveMapped((userTokens) {
        if (!userTokens!.contains(apiToken)) {
          userTokens.add(apiToken);
        }
      });
    });
  }

  FutureOr<void> _sharedTokensOnRemove(String token, APITokenInfo? tokenInfo) {
    return _resolveSharedTokensByUsername()
        .resolveMapped((sharedTokensByUsername) {
      if (tokenInfo == null) return null;

      final apiToken = tokenInfo.apiToken;
      final username = apiToken.username;

      return sharedTokensByUsername.get(username).resolveMapped((userTokens) {
        if (userTokens != null) {
          var rm = userTokens.remove(apiToken);
          if (rm && userTokens.isEmpty) {
            return sharedTokensByUsername.remove(username);
          }
        }
      });
    });
  }

  static const Duration _cacheTimeout = Duration(seconds: 5);

  static final Expando<SharedMap<String, APITokenInfo>> _sharedTokens =
      Expando();

  static final Expando<SharedMap<String, List<APIToken>>>
      _sharedTokensByUsername = Expando();

  FutureOr<SharedMap<String, APITokenInfo>> _resolveSharedTokens() {
    var sharedTokens = _sharedTokens[this];
    if (sharedTokens != null) return sharedTokens;

    return _sharedTokensField
        .sharedMapCached(timeout: _cacheTimeout)
        .resolveMapped((sharedTokens) => _sharedTokens[this] = sharedTokens);
  }

  FutureOr<SharedMap<String, List<APIToken>>> _resolveSharedTokensByUsername() {
    var sharedTokensByUsername = _sharedTokensByUsername[this];
    if (sharedTokensByUsername != null) return sharedTokensByUsername;

    return _sharedTokensByUsernameField
        .sharedMapCached(timeout: _cacheTimeout)
        .resolveMapped((sharedTokensByUsername) =>
            _sharedTokensByUsername[this] = sharedTokensByUsername);
  }

  FutureOr<APITokenInfo?> get(String token) => _resolveSharedTokens()
      .resolveMapped((sharedTokens) => sharedTokens.get(token));

  FutureOr<List<APIToken>> getByUsername(String username,
      {required bool checkExpiredTokens}) {
    return _resolveSharedTokensByUsername()
        .resolveMapped((sharedTokensByUsername) {
      return sharedTokensByUsername.get(username).resolveMapped((userTokens) {
        if (userTokens == null) return [];

        if (!checkExpiredTokens) return userTokens;

        var expiredTokens = userTokens.removeExpiredTokens();
        if (expiredTokens.isEmpty) return userTokens;

        return removeTokens(expiredTokens, removeFromUsernames: true)
            .resolveWithValue(userTokens);
      });
    });
  }

  FutureOr<List<APIToken>> getByUsernames(Iterable<String> usernames,
          {required bool checkExpiredTokens}) =>
      usernames
          .toSet()
          .map((username) =>
              getByUsername(username, checkExpiredTokens: checkExpiredTokens))
          .resolveAllJoined((l) => l.expand((l) => l).toList());

  FutureOr<List<APIToken>> allTokens() =>
      _resolveSharedTokens().resolveMapped((sharedTokens) {
        return sharedTokens
            .values()
            .resolveMapped((l) => l.map((e) => e.apiToken).toList());
      });

  FutureOr<List<APIToken>> validateAllTokens([DateTime? now]) {
    now ??= DateTime.now();

    return allTokens().resolveMapped((allTokens) {
      if (allTokens.isEmpty) return [];

      var expiredTokens = allTokens.removeExpiredTokens();
      if (expiredTokens.isEmpty) return allTokens;

      return removeTokens(expiredTokens, removeFromUsernames: true)
          .resolveWithValue(allTokens);
    });
  }

  FutureOr<List<APIToken>> removeUsernameTokens(String username,
      {required bool checkExpiredTokens}) {
    return _resolveSharedTokensByUsername()
        .resolveMapped((sharedTokensByUsername) {
      return sharedTokensByUsername
          .remove(username)
          .resolveMapped((userTokens) {
        if (userTokens == null) return [];
        return removeTokens(userTokens, removeFromUsernames: true)
            .resolveWithValue(userTokens);
      });
    });
  }

  FutureOr<int> removeTokens(List<APIToken> apiTokens,
      {required bool removeFromUsernames}) {
    if (apiTokens.isEmpty) return 0;

    var tokens = apiTokens.map((e) => e.token).toList();

    return _resolveSharedTokens().resolveMapped((sharedTokens) {
      return sharedTokens.removeAll(tokens).then((removed) => removed.length);
    });
  }

  FutureOr<APITokenInfo?> removeAPIToken(APIToken apiToken) =>
      removeToken(apiToken.token);

  FutureOr<APITokenInfo?> removeToken(String token) {
    return _resolveSharedTokens().resolveMapped((sharedTokens) {
      return sharedTokens.remove(token).resolveMapped((tokenInfo) {
        if (tokenInfo == null) return null;

        if (sharedTokens.isMainInstance) {
          return tokenInfo;
        }

        final apiToken = tokenInfo.apiToken;

        return _resolveSharedTokensByUsername()
            .resolveMapped((sharedTokensByUsername) {
          return sharedTokensByUsername
              .get(apiToken.username)
              .resolveMapped((userTokens) {
            if (userTokens != null) {
              var rm = userTokens.remove(apiToken);
              if (rm && userTokens.isEmpty) {
                sharedTokensByUsername.remove(apiToken.username);
              }
            }
            return tokenInfo;
          });
        });
      });
    });
  }

  FutureOr<APITokenInfo?> removeTokenData(String token) {
    return _resolveSharedTokens().resolveMapped((sharedTokens) {
      return sharedTokens.get(token).resolveMapped((tokenInfo) {
        if (tokenInfo != null) {
          return sharedTokens.put(token, (
            apiToken: tokenInfo.apiToken,
            data: null,
            permissions: tokenInfo.permissions
          ));
        }

        return tokenInfo;
      });
    });
  }

  FutureOr<APITokenInfo?> storeAPIToken(
      APIToken apiToken, Object? data, List<APIPermission> permissions) {
    data = _toUnmodifiableData(data);
    permissions = permissions.asUnmodifiableListView();

    return _resolveSharedTokens().resolveMapped((sharedTokens) {
      return sharedTokens.put(apiToken.token,
          (apiToken: apiToken, data: data, permissions: permissions));
    });
  }

  Object? _toUnmodifiableData(Object? data) {
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
    return data;
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
