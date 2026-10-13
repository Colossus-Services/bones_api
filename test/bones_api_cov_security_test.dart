@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:shared_map/shared_map.dart';
import 'package:test/test.dart';

final fooSha256 =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';
final barSha256 =
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9';

final users = {'foo': fooSha256, 'bar': barSha256};

void main() {
  group('APISecurity (coverage)', () {
    test('constructor: tokenLength and tokenDuration', () {
      var s1 = _SimpleSecurity(tokenLength: 10);
      expect(s1.tokenLength, equals(512));
      expect(s1.tokenDuration, equals(Duration(hours: 3)));

      var s2 = _SimpleSecurity(
        tokenLength: 64,
        tokenDuration: Duration(minutes: 10),
      );
      expect(s2.tokenLength, equals(64));
      expect(s2.tokenDuration, equals(Duration(minutes: 10)));

      var s3 = _SimpleSecurity();
      expect(s3.tokenLength, equals(512));
    });

    test('secureRandom: periodic reset', () {
      var s = _SimpleSecurity();
      var r1 = s.secureRandom();
      expect(identical(s.secureRandom(), r1), isTrue);

      var changed = false;
      for (var i = 0; i < 1600; ++i) {
        if (!identical(s.secureRandom(), r1)) {
          changed = true;
          break;
        }
      }
      expect(changed, isTrue);

      var r2 = s.secureRandom();
      s.resetSecureRandom();
      expect(identical(s.secureRandom(), r2), isFalse);
    });

    test('default prepareCredential', () async {
      var s = _SimpleSecurity();
      var c = APICredential('foo', passwordHash: 'foo');
      expect(identical(await s.prepareCredential(c), c), isTrue);

      var auth = await s.authenticate(c);
      expect(auth, isNotNull);
      expect(auth!.username, equals('foo'));
      expect(auth.token.token, startsWith('TK'));
    });

    test('logout', () async {
      var s = _SimpleSecurity();

      expect(await s.logout(null), isFalse);
      expect(
        await s.logout(APICredential('foo', passwordHash: 'foo')),
        isFalse,
      );

      var auth = (await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      ))!;
      var token = auth.tokenKey;

      expect(await s.isValidToken('foo', token), isTrue);

      // Invalid credential:
      expect(
        await s.logout(
          APICredential('foo', passwordHash: 'wrong'),
          allTokens: true,
        ),
        isFalse,
      );

      // Logout all tokens:
      expect(
        await s.logout(
          APICredential('foo', passwordHash: 'foo'),
          allTokens: true,
        ),
        isTrue,
      );
      expect(await s.isValidToken('foo', token), isFalse);
      expect(await s.getUsernameValidTokens('foo'), isEmpty);

      // Nothing left to logout:
      expect(
        await s.logout(
          APICredential('foo', passwordHash: 'foo'),
          allTokens: true,
        ),
        isFalse,
      );

      // Logout a single token:
      var auth2 = (await s.authenticate(
        APICredential('bar', passwordHash: 'bar'),
      ))!;
      expect(
        await s.logout(APICredential('bar', token: auth2.tokenKey)),
        isTrue,
      );
      expect(await s.getAPIToken(auth2.tokenKey), isNull);
    });

    test('refreshAPIToken + getValidToken (multiple tokens)', () async {
      var s = _RefreshSecurity();

      expect(await s.refreshAPIToken(null, 'RTKx'), isNull);
      expect(await s.refreshAPIToken('foo', null), isNull);
      expect(await s.refreshAPIToken('', 'RTKx'), isNull);
      expect(await s.refreshAPIToken('foo', ''), isNull);
      expect(await s.refreshAPIToken('foo', 'XYZ'), isNull);

      var auth = (await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      ))!;
      var token1 = auth.token;
      expect(s.newTokens.map((e) => e.$1.token), contains(token1.token));
      expect(s.newTokens.last.$2, isFalse);

      var token2 = (await s.refreshAPIToken('foo', 'RTK123'))!;
      expect(token2.username, equals('foo'));
      expect(token2.token, isNot(equals(token1.token)));
      expect(token2.refreshToken, startsWith('RTK'));
      expect(s.newTokens.last.$1, equals(token2));
      expect(s.newTokens.last.$2, isTrue);

      var userTokens = await s.getUsernameValidTokens('foo');
      expect(userTokens.length, equals(2));

      var valid = await s.getValidToken('foo', autoCreate: false);
      expect(valid, isNotNull);
      expect([token1, token2], contains(valid));

      expect(await s.getValidToken('nobody', autoCreate: false), isNull);

      // Base class `validateRefreshToken`:
      var simple = _SimpleSecurity();
      expect(await simple.validateRefreshToken('foo', 'RTK123'), isFalse);
      expect(await simple.validateRefreshToken('', 'RTK123'), isFalse);
      expect(await simple.validateRefreshToken('foo', 'XX'), isFalse);
      expect(await simple.refreshAPIToken('foo', 'RTK123'), isNull);

      // `validateAllTokens` and `invalidateUserTokens`:
      expect(await s.validateAllTokens(), equals(2));
      expect(await s.invalidateUserTokens('foo'), isTrue);
      expect(await s.validateAllTokens(), equals(0));
      expect(await s.invalidateUserTokens('foo'), isFalse);
    });

    test('validateUnknownToken', () async {
      var s = _RefreshSecurity();

      // Ensure `foo` has a known token:
      var auth = await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      );
      expect(auth, isNotNull);

      var auth2 = await s.authenticate(
        APICredential('foo', token: _RefreshSecurity.unknownToken),
      );
      expect(auth2, isNotNull);
      expect(auth2!.username, equals('foo'));
      expect(auth2.tokenKey, equals(_RefreshSecurity.unknownToken));

      expect(
        await s.isValidToken('foo', _RefreshSecurity.unknownToken),
        isTrue,
      );
      expect(await s.isValidToken('foo', 'TKother'), isFalse);
      expect(await s.isValidToken('foo', 'other'), isFalse);
    });

    test('notifyAPITokenInfoChange / dispose*', () async {
      var s = _RefreshSecurity();

      var auth = (await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      ))!;
      var tokenKey = auth.tokenKey;

      await s.notifyAPITokenInfoChange(username: 'foo');
      expect(s.changedTokens, equals([tokenKey]));

      await s.notifyAPITokenInfoChange(token: 'TKnotStored');
      expect(s.changedTokens, equals([tokenKey, 'TKnotStored']));

      await s.notifyAPITokenInfoChange(token: tokenKey, username: 'foo');
      expect(s.changedTokens, equals([tokenKey, 'TKnotStored', tokenKey]));

      expect(await s.disposeAuthenticationPermission(null), isFalse);
      expect(await s.disposeAuthenticationPermission(tokenKey), isTrue);
      expect(await s.disposeAuthenticationPermission('TKnone'), isFalse);

      expect(await s.disposeAuthenticationDataAndPermission(null), isFalse);
      expect(await s.disposeAuthenticationDataAndPermission(tokenKey), isTrue);
      expect(await s.disposeAuthenticationDataAndPermission('TKnone'), isFalse);

      {
        var c = APICredential('foo')..usernameEntity = {'id': 1};
        expect(await s.disposeAuthenticationData(c), isTrue);
        expect(c.usernameEntity, isNull);
        expect(await s.disposeAuthenticationData(c), isFalse);

        var c2 = APICredential('foo', token: tokenKey);
        expect(await s.disposeAuthenticationData(c2), isTrue);
        var c3 = APICredential('foo', token: 'TKnone');
        expect(await s.disposeAuthenticationData(c3), isFalse);
      }

      {
        var c = APICredential('foo')..usernameEntity = {'id': 1};
        expect(await s.disposeAuthenticationToken(c), isTrue);
        expect(c.usernameEntity, isNull);
        expect(await s.disposeAuthenticationToken(c), isFalse);

        var c2 = APICredential('foo', token: tokenKey);
        expect(await s.disposeAuthenticationToken(c2), isTrue);
        expect(await s.getAPIToken(tokenKey), isNull);
        expect(await s.disposeAuthenticationToken(c2), isFalse);
      }
    });

    test('authenticateByRequest: session credential', () async {
      var s = _SimpleSecurity();

      var request1 = APIRequest(
        APIRequestMethod.GET,
        'foo',
        sessionID: 'SID-cov-1',
      );
      request1.credential = APICredential('foo', passwordHash: 'foo');
      var auth1 = await s.authenticateByRequest(request1);
      expect(auth1, isNotNull);

      // No credentials, only the session:
      var request2 = APIRequest(
        APIRequestMethod.GET,
        'foo',
        sessionID: 'SID-cov-1',
      );
      var auth2 = await s.authenticateByRequest(request2);
      expect(auth2, isNotNull);
      expect(auth2!.username, equals('foo'));
      expect(auth2.tokenKey, equals(auth1!.tokenKey));

      // No credentials and no session:
      var request3 = APIRequest(APIRequestMethod.GET, 'foo');
      expect(await s.authenticateByRequest(request3), isNull);
    });

    test('authenticateByRequest: logout', () async {
      var s = _SimpleSecurity();

      var auth = (await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      ))!;

      var request = APIRequest(
        APIRequestMethod.GET,
        'foo',
        parameters: {'logout': 'true'},
      );
      request.credential = APICredential('foo', token: auth.tokenKey);

      expect(await s.authenticateByRequest(request, allowLogout: true), isNull);
      expect(request.credential, isNull);
      expect(s.loggedOut.map((e) => e.username), equals(['foo']));
      expect(await s.getAPIToken(auth.tokenKey), isNull);
    });

    test('authenticateByRequest: multiple credentials all invalid', () async {
      var s = _SimpleSecurity();

      var request = APIRequest(
        APIRequestMethod.GET,
        'foo',
        parameters: {'username': 'bar', 'password': 'wrong'},
      );
      var cred = APICredential('foo', passwordHash: 'wrong');
      request.credential = cred;

      expect(await s.authenticateByRequest(request), isNull);
      expect(request.credential, equals(cred));
    });

    test('getMostRecentToken', () {
      var s = _SimpleSecurity();

      expect(s.getMostRecentToken(null), isNull);
      expect(s.getMostRecentToken({}), isNull);

      var t1 = APIToken(
        'foo',
        token: 'TK1',
        issueTime: DateTime(2020),
        duration: Duration(hours: 1),
      );
      var t2 = APIToken(
        'foo',
        token: 'TK2',
        issueTime: DateTime(2021),
        duration: Duration(hours: 1),
      );
      var t3 = APIToken(
        'foo',
        token: 'TK3',
        issueTime: DateTime(2019),
        duration: Duration(hours: 1),
      );

      expect(s.getMostRecentToken({t1}), equals(t1));
      expect(s.getMostRecentToken({t1, t2, t3}), equals(t2));
    });

    test('resolveRequestCredentials: tokens', () async {
      var s = _RefreshSecurity();

      var auth = (await s.authenticate(
        APICredential('foo', passwordHash: 'foo'),
      ))!;

      // Credential without username, with a known token, no session:
      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('', token: auth.tokenKey);
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
        expect(credentials[0].token, equals(auth.tokenKey));
      }

      // Credential without username, with a known token, unknown session:
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          sessionID: 'SID-cov-unknown',
        );
        request.credential = APICredential('', token: auth.tokenKey);
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
      }

      // Credential without username, token resolved by `validateUnknownToken`:
      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential(
          '',
          token: _RefreshSecurity.unknownToken,
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
      }

      // Token only in parameters:
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          parameters: {'access_token': auth.tokenKey},
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
        expect(credentials[0].token, equals(auth.tokenKey));
      }

      // Unknown token only in headers:
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          headers: {'x-token': 'TKnotKnown'},
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials, isEmpty);
      }

      // Username + token in parameters:
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          parameters: {'user': 'foo', 'token': auth.tokenKey},
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].token, equals(auth.tokenKey));
      }

      // Username + refresh token:
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          parameters: {'username': 'foo', 'refresh_token': 'RTKabc'},
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
        expect(credentials[0].token, startsWith('TK'));
        expect(credentials[0].token, isNot(equals(auth.tokenKey)));
        expect(credentials[0].refreshToken, startsWith('RTK'));
      }

      // Username + invalid refresh token (header):
      {
        var request = APIRequest(
          APIRequestMethod.GET,
          'foo',
          parameters: {'username': 'foo'},
          headers: {'x-refresh-token': 'BAD'},
        );
        var credentials = await s.resolveRequestCredentials(request);
        expect(credentials, isEmpty);
      }
    });
  });

  group('APITokenStore (coverage)', () {
    test('basic operations', () async {
      var store = APITokenStore(sharedStore: SharedStore.notShared());
      expect(store.sharedTokensID, equals('APITokenStore'));
      expect(store.sharedStore, isNotNull);

      expect(await store.allTokens(), isEmpty);
      expect(await store.validateAllTokens(), isEmpty);
      expect(await store.get('TKnone'), isNull);

      var t1 = APIToken('foo', token: 'TK1');
      var t2 = APIToken('foo', token: 'TK2');
      var tExpired = APIToken(
        'bar',
        token: 'TK3',
        issueTime: DateTime.now().subtract(Duration(hours: 10)),
        duration: Duration(hours: 1),
      );

      var info1 = await store.storeAPIToken(t1, [1, 2], [APIPermission('a')]);
      expect(info1, isNotNull);
      expect(info1!.data, isA<List>());
      expect(() => (info1.data as List).add(3), throwsUnsupportedError);
      expect(
        () => info1.permissions!.add(APIPermission('b')),
        throwsUnsupportedError,
      );

      var info2 = await store.storeAPIToken(t2, <String, Object?>{'a': 1}, []);
      expect(() => (info2!.data as Map)['b'] = 2, throwsUnsupportedError);

      var info3 = await store.storeAPIToken(tExpired, {1, 2}, []);
      expect(() => (info3!.data as Set).add(3), throwsUnsupportedError);

      var info4 = await store.storeAPIToken(
        APIToken('baz', token: 'TK4'),
        <int, int>{1: 2},
        [],
      );
      expect(() => (info4!.data as Map)[3] = 4, throwsUnsupportedError);

      var info5 = await store.storeAPIToken(
        APIToken('baz', token: 'TK5'),
        'plain',
        [],
      );
      expect(info5!.data, equals('plain'));

      expect((await store.allTokens()).length, equals(5));

      var byUsernames = await store.getByUsernames([
        'foo',
        'foo',
        'baz',
      ], checkExpiredTokens: false);
      expect(byUsernames.map((e) => e.token).toSet(), {
        'TK1',
        'TK2',
        'TK4',
        'TK5',
      });

      // Removes the expired token:
      var valid = await store.validateAllTokens();
      expect(valid.map((e) => e.token).toSet(), {'TK1', 'TK2', 'TK4', 'TK5'});
      expect(await store.get('TK3'), isNull);

      // removeTokenData / removeTokenPermissions:
      var r1 = await store.removeTokenData('TK1');
      expect(r1!.data, isNull);
      expect(r1.permissions, isNotEmpty);
      expect(await store.removeTokenData('TKnone'), isNull);

      var r2 = await store.removeTokenPermissions('TK2');
      expect(r2!.permissions, isNull);
      expect(r2.data, isNotNull);
      expect(await store.removeTokenPermissions('TKnone'), isNull);

      var r3 = await store.removeTokenDataAndPermissions('TK4');
      expect(r3!.permissions, isNull);
      expect(r3.data, isNull);
      expect(await store.removeTokenDataAndPermissions('TKnone'), isNull);

      expect(
        await store.removeTokens([], removeFromUsernames: true),
        equals(0),
      );
      expect(
        await store.removeTokens([
          APIToken('baz', token: 'TK5'),
        ], removeFromUsernames: true),
        equals(1),
      );
      expect(await store.get('TK5'), isNull);

      var removed = await store.removeUsernameTokens(
        'foo',
        checkExpiredTokens: true,
      );
      expect(removed.map((e) => e.token).toSet(), {'TK1', 'TK2'});
      expect(
        await store.removeUsernameTokens('foo', checkExpiredTokens: true),
        isEmpty,
      );

      expect(
        await store.removeAPIToken(APIToken('baz', token: 'TK4')),
        isNotNull,
      );
      expect(await store.removeToken('TK4'), isNull);
      expect(await store.allTokens(), isEmpty);
    });

    test('getByUsername: removes expired tokens', () async {
      var store = APITokenStore(sharedStore: SharedStore.notShared());

      await store.storeAPIToken(APIToken('foo', token: 'TKok'), null, []);
      await store.storeAPIToken(
        APIToken(
          'foo',
          token: 'TKold',
          issueTime: DateTime.now().subtract(Duration(days: 1)),
          duration: Duration(minutes: 1),
        ),
        null,
        [],
      );

      var tokens = await store.getByUsername('foo', checkExpiredTokens: true);
      expect(tokens.map((e) => e.token), equals(['TKok']));
      expect(await store.get('TKold'), isNull);
    });
  });

  group('APIRouteRule (coverage)', () {
    test('toString', () {
      expect(APIRoutePublicRule().toString(), equals('APIRoutePublicRule{}'));
      expect(
        APIRouteNotAuthenticatedRule().toString(),
        equals('APIRouteNotAuthenticatedRule{}'),
      );
      expect(
        APIRouteAuthenticatedRule().toString(),
        equals('APIRouteAuthenticatedRule{}'),
      );
      expect(
        APIRoutePermissionTypeRule([' Admin ', 'basic', '']).toString(),
        equals('APIRoutePermissionTypeRule{admin, basic}'),
      );
    });

    test(
      'APIEntityResolutionRules / APIEntityAccessRules / APIEntityRules',
      () {
        var request = APIRequest(APIRequestMethod.GET, 'foo');

        var resolution = EntityResolutionRules.fetch(allEager: true);
        var r1 = APIEntityResolutionRules(resolution, globalRules: true);
        expect(r1.validate(request), isTrue);
        expect(r1.globalRules, isTrue);
        expect(r1.noGlobalRules, isFalse);
        expect(r1.toString(), startsWith('APIEntityResolutionRules@'));
        expect(r1.toJson(), equals({'resolutionRules': resolution.toJson()}));

        var access = EntityAccessRules.innocuous;
        var r2 = APIEntityAccessRules(access, noGlobalRules: true);
        expect(r2.validate(request), isTrue);
        expect(r2.noGlobalRules, isTrue);
        expect(r2.toString(), startsWith('APIEntityAccessRules@'));
        expect(r2.toJson(), equals({'accessRules': access.toJson()}));

        var r3 = APIEntityRules([resolution, access]);
        expect(r3.validate(request), isTrue);
        expect(r3.entityResolutionRules, equals([resolution]));
        expect(r3.entityAccessRules, equals([access]));
        expect(r3.toString(), startsWith('APIEntityRules@'));
        expect(
          r3.toJson(),
          equals({
            'rules': [resolution.toJson(), access.toJson()],
          }),
        );
      },
    );
  });

  group('SecureRandom (coverage)', () {
    test('toString / isFallbackSecureRandom', () {
      var r1 = SecureRandom();
      expect(r1.isFallbackSecureRandom, isFalse);
      expect(
        r1.toString(),
        equals('SecureRandom{ fallbackSecureRandom: false }'),
      );

      var r2 = SecureRandom(forceFallbackSecureRandom: true);
      expect(r2.isFallbackSecureRandom, isTrue);
      expect(
        r2.toString(),
        equals('SecureRandom{ fallbackSecureRandom: true }'),
      );
    });

    test('nextSeed layers', () {
      var r = SecureRandom();
      for (var i = 0; i < 100; ++i) {
        expect(r.nextSeed(layers: 1).abs(), lessThan(2147000000));
        expect(r.nextSeed(layers: 0).abs(), lessThan(2147000000));
      }
      expect(r.advance(minSteps: 5, maxSteps: 6), equals(5));
    });
  });
}

class _SimpleSecurity extends APISecurity {
  _SimpleSecurity({super.tokenLength, super.tokenDuration})
    : super(sharedStore: SharedStore.notShared());

  final List<APICredential> loggedOut = [];

  @override
  void onLogout(APICredential credential) {
    loggedOut.add(credential);
    super.onLogout(credential);
  }

  @override
  FutureOr<bool> checkCredentialPassword(APICredential credential) =>
      credential.checkPassword(users[credential.username]);

  @override
  FutureOr<List<APIPermission>> getCredentialPermissions(
    APICredential credential,
    List<APIPermission>? previousPermissions,
  ) => [APIPermission('basic')];
}

class _RefreshSecurity extends _SimpleSecurity {
  static const unknownToken = 'TKunknownButValidToken';

  final List<(APIToken, bool)> newTokens = [];
  final List<String> changedTokens = [];

  @override
  FutureOr<bool> validateRefreshToken(String username, String refreshToken) =>
      refreshToken.startsWith('RTK');

  @override
  FutureOr<APIToken?> validateUnknownToken(String username, String token) {
    if (token == unknownToken) {
      return APIToken('foo', token: unknownToken);
    }
    return super.validateUnknownToken(username, token);
  }

  @override
  void onNewAPIToken(APIToken token, bool refreshed, {APIRequest? request}) {
    newTokens.add((token, refreshed));
    super.onNewAPIToken(token, refreshed, request: request);
  }

  @override
  Future<void> onAPITokenInfoChange(String token, {String? username}) async {
    changedTokens.add(token);
    await super.onAPITokenInfoChange(token, username: username);
  }
}
