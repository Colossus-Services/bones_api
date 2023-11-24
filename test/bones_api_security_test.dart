@Timeout(Duration(seconds: 180))
// ignore_for_file: discarded_futures
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:shared_map/shared_map.dart';
import 'package:test/test.dart';

final fooSha256 =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';
final barSha256 =
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9';

final users = {'foo': fooSha256, 'bar': barSha256};
final tokens = users.map((key, value) => MapEntry(value, key));

void main() {
  group('SecureRandom', () {
    _testSecureRandom(SecureRandom());
  });

  group('SecureRandom(fallback)', () {
    _testSecureRandom(SecureRandom(forceFallbackSecureRandom: true));
  });

  group('APISecurity.secureRandom', () {
    var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());
    _testSecureRandom(apiSecurity.secureRandom());
  });

  group('APISecurity', () {
    test('createToken', () {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      var token = apiSecurity.createToken('foo');

      expect(token.username, equals('foo'));
      expect(token.token.length, equals(64));
    });

    test('createToken2', () {
      var apiSecurity = _MyAPISecurity2();

      var token = apiSecurity.createToken('foo');

      print('Token: ${token.token}');

      expect(token.username, equals('foo'));
      expect(
          token.token.length,
          allOf(greaterThanOrEqualTo(2 + 512 - 48),
              lessThanOrEqualTo(2 + 512 + 48)));
    });

    test('authenticate', () {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        var credential = APICredential('foo', passwordHash: 'foo');
        expect(apiSecurity.authenticate(credential), isNotNull);

        expect(credential.usernameEntity, isNotEmpty);

        expect(
            credential.copy(withUsernameEntity: false).usernameEntity, isNull);
      }

      expect(
          apiSecurity.authenticate(APICredential('bar', passwordHash: 'bar')),
          isNotNull);

      expect(
          apiSecurity.authenticate(APICredential('foo', passwordHash: 'bar')),
          isNull);

      expect(apiSecurity.authenticate(APICredential('foo', token: fooSha256)),
          isNotNull);

      expect(apiSecurity.authenticate(APICredential('bar', token: barSha256)),
          isNotNull);

      expect(apiSecurity.authenticate(APICredential('baz`', token: fooSha256)),
          isNull);

      expect(
          apiSecurity.authenticate(APICredential('foo', token: 'any')), isNull);
    });

    test('authenticateByRequest', () async {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        var request1 = APIRequest(APIRequestMethod.GET, 'foo');
        request1.credential = APICredential('foo', passwordHash: 'foo');

        expect(await apiSecurity.authenticateByRequest(request1), isNotNull);
        expect(request1.authentication, isNotNull);
        expect(request1.authentication!.username, equals('foo'));

        var request2 = APIRequest(APIRequestMethod.GET, 'foo');
        request2.credential = APICredential('bar', passwordHash: 'xxx');

        expect(await apiSecurity.authenticateByRequest(request2), isNull);
        expect(request2.authentication, isNull);
      }

      {
        var request1 = APIRequest(APIRequestMethod.GET, 'foo');
        request1.parameters['username'] = 'foo';
        request1.parameters['password'] = 'foo';

        expect(await apiSecurity.authenticateByRequest(request1), isNotNull);
        expect(request1.authentication, isNotNull);
        expect(request1.authentication!.username, equals('foo'));

        var request2 = APIRequest(APIRequestMethod.GET, 'foo');
        request2.parameters['username'] = 'foo';
        request2.parameters['password'] = 'not_foo';

        expect(await apiSecurity.authenticateByRequest(request2), isNull);
        expect(request2.authentication, isNull);
      }

      {
        var request1 = APIRequest(APIRequestMethod.GET, 'foo');
        request1.credential = APICredential('foo', passwordHash: 'foo');
        request1.parameters['username'] = 'bar';
        request1.parameters['password'] = 'bar';

        expect(await apiSecurity.authenticateByRequest(request1), isNotNull);
        expect(request1.authentication, isNotNull);
        expect(request1.authentication!.username, equals('foo'));
      }

      {
        var request1 = APIRequest(APIRequestMethod.GET, 'foo');
        request1.credential = APICredential('foo', passwordHash: 'not_foo');
        request1.parameters['username'] = 'bar';
        request1.parameters['password'] = 'bar';

        expect(await apiSecurity.authenticateByRequest(request1), isNotNull);
        expect(request1.authentication, isNotNull);
        expect(request1.authentication!.username, equals('bar'));
      }
    });

    test('resolveRequestCredential', () async {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('foo', passwordHash: 'foo');

        var credentials = await apiSecurity.resolveRequestCredentials(request);
        expect(credentials, isNotEmpty);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
      }

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');
        request.credential = APICredential('foo', passwordHash: 'foo');

        expect(apiSecurity.authenticateByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));
      }

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');
        request.credential = APICredential('', token: fooSha256);

        var credentials = await apiSecurity.resolveRequestCredentials(request);
        expect(credentials, isNotEmpty);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo',
            parameters: {'user': 'foo', 'pass': '123456'});

        var credentials = await apiSecurity.resolveRequestCredentials(request);
        expect(credentials, isNotEmpty);
        expect(credentials.length, equals(1));
        expect(credentials[0].username, equals('foo'));
        expect(credentials[0].password, equals(APIPassword('123456')));
      }
    });

    test('doRequestAuthentication', () async {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');
        request.credential = APICredential('foo', passwordHash: 'foo');

        var response = await apiSecurity.doRequestAuthentication(request);
        expect(response, isNotNull);
        expect(response.status, equals(APIResponseStatus.OK));

        var json = response.payload as Map;
        // ignore: avoid_dynamic_calls
        json['token']['issueTime'] = '...';
        // ignore: avoid_dynamic_calls
        json['token']['expireTime'] = '...';

        expect(
            json,
            equals({
              'token': {
                'username': 'foo',
                'token': fooSha256,
                'issueTime': '...',
                'duration': 10800,
                'expireTime': '...'
              },
              'permissions': [
                {'type': 'basic', 'enabled': true}
              ]
            }));
      }
    });

    test('resumeAuthenticationByRequest', () async {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');
        request.credential = APICredential('foo', passwordHash: 'foo');

        expect(apiSecurity.authenticateByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));

        var credential = await apiSecurity.resolveSessionCredential(request);
        expect(credential, isNotNull);
        expect(credential!.username, equals('foo'));
      }

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');
        request.credential = APICredential('foo', token: fooSha256);

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));
      }

      {
        var request =
            APIRequest(APIRequestMethod.GET, 'foo', sessionID: 'SID123abc');

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('foo', token: fooSha256);

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('foo', token: barSha256);

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNull);
        expect(request.authentication, isNull);

        var credential = apiSecurity.resolveSessionCredential(request);
        expect(credential, isNull);
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNull);
        expect(request.authentication, isNull);
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('bar', passwordHash: 'xxx');

        expect(apiSecurity.resumeAuthenticationByRequest(request), isNull);
        expect(request.authentication, isNull);
      }
    });

    test('APIRouteRule', () {
      var apiSecurity = _MyAPISecurity(sharedStore: SharedStore.notShared());

      {
        expect(APIRoutePublicRule().toJson(), equals({'rule': 'public'}));

        expect(APIRouteNotAuthenticatedRule().toJson(),
            equals({'rule': 'not_authenticated'}));

        expect(APIRouteAuthenticatedRule().toJson(),
            equals({'rule': 'authenticated'}));

        expect(
            APIRoutePermissionTypeRule(['basic']).toJson(),
            equals({
              'rule': 'permission',
              'types': ['basic']
            }));
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('foo', passwordHash: 'foo');

        expect(apiSecurity.authenticateByRequest(request), isNotNull);
        expect(request.authentication, isNotNull);
        expect(request.authentication!.username, equals('foo'));

        expect(APIRoutePublicRule().validate(request), isTrue);
        expect(APIRouteNotAuthenticatedRule().validate(request), isFalse);
        expect(APIRouteAuthenticatedRule().validate(request), isTrue);

        expect(APIRoutePermissionTypeRule(['basic']).validate(request), isTrue);
        expect(
            APIRoutePermissionTypeRule(['admin']).validate(request), isFalse);
      }

      {
        var request = APIRequest(APIRequestMethod.GET, 'foo');
        request.credential = APICredential('foo', passwordHash: 'foo');

        expect(APIRoutePublicRule().validate(request), isTrue);
        expect(APIRouteNotAuthenticatedRule().validate(request), isTrue);
        expect(APIRouteAuthenticatedRule().validate(request), isFalse);

        expect(
            APIRoutePermissionTypeRule(['basic']).validate(request), isFalse);
        expect(
            APIRoutePermissionTypeRule(['admin']).validate(request), isFalse);
      }
    });
  });
}

void _testSecureRandom(SecureRandom random) {
  test('nextInt', () {
    for (var i = 0; i < 1000; ++i) {
      expect(
          random.nextInt(100), allOf(greaterThanOrEqualTo(0), lessThan(100)));
    }
  });

  test('nextDouble', () {
    for (var i = 0; i < 1000; ++i) {
      expect(random.nextDouble(), allOf(greaterThanOrEqualTo(0), lessThan(1)));
    }
  });

  test('nextBool', () {
    var total = 10000;
    var count = 0;

    for (var i = 0; i < total; ++i) {
      if (random.nextBool()) {
        count++;
      }
    }

    var ratio = count / total;
    print('nextBool() ratio: $ratio');

    expect((0.50 - ratio).abs(), lessThan(0.05));
  });

  test('nextSeed', () {
    for (var i = 0; i < 1000; ++i) {
      expect(random.nextSeed(layers: 3), isNot(0));
    }
  });

  test('nextBytes', () {
    for (var i = 0; i < 1000; ++i) {
      var bs = Uint8List(10);
      expect(bs.toString(), equals('[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]'));

      expect(random.nextBytes(bs), equals(10));
      expect(bs.toString(), isNot('[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]'));
    }
  });

  test('nextBytes', () {
    for (var i = 0; i < 1000; ++i) {
      var bs = random.randomBytes(10);

      expect(bs.length, equals(10));
      expect(bs.toString(), isNot('[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]'));
    }
  });
}

class _MyAPISecurity extends APISecurity {
  _MyAPISecurity({super.sharedStore});

  @override
  String generateToken(String username) {
    if (username == 'foo') {
      return fooSha256;
    } else if (username == 'bar') {
      return barSha256;
    }

    return super.generateToken(username);
  }

  @override
  FutureOr<APICredential> prepareCredential(APICredential credential) {
    credential.usernameEntity = {
      'username': credential.username,
      if (credential.hasToken) 'token': credential.token,
    };

    return credential;
  }

  @override
  FutureOr<bool> checkCredentialPassword(APICredential credential) {
    var pass = users[credential.username];
    var passOK = credential.checkPassword(pass);
    return passOK;
  }

  @override
  FutureOr<List<APIPermission>> getCredentialPermissions(
      APICredential credential, List<APIPermission>? previousPermissions) {
    return [
      APIPermission('basic'),
      if (credential.username.startsWith('admin')) APIPermission('admin'),
    ];
  }
}

class _MyAPISecurity2 extends APISecurity {
  @override
  FutureOr<bool> checkCredentialPassword(APICredential credential) {
    var pass = users[credential.username];
    var passOK = credential.checkPassword(pass);
    return passOK;
  }

  @override
  FutureOr<List<APIPermission>> getCredentialPermissions(
      APICredential credential, List<APIPermission>? previousPermissions) {
    return [
      APIPermission('basic'),
      if (credential.username.startsWith('admin')) APIPermission('admin'),
    ];
  }
}
