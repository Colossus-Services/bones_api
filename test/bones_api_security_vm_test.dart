@TestOn('vm')
@Timeout(Duration(seconds: 180))
// ignore_for_file: discarded_futures
import 'dart:isolate';

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
  group('APISecurity', () {
    test('authenticateByRequest (shared + Isolate)', () async {
      final sharedStore = SharedStore.fromUUID();

      var apiSecurity = _MyAPISecurity(sharedStore: sharedStore);

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
        var isolateOk = await Isolate.run<bool>(() async {
          var request1 = APIRequest(APIRequestMethod.GET, 'foo');
          request1.parameters['username'] = 'foo';
          request1.parameters['password'] = 'foo';

          var authentication1 = await apiSecurity.authenticateByRequest(
            request1,
          );
          if (authentication1 == null) {
            throw StateError("Null `authentication1`");
          }

          var requestAuthentication1 = request1.authentication;
          if (requestAuthentication1 == null) {
            throw StateError("Null `request1.authentication`");
          }

          if (requestAuthentication1.username != 'foo') {
            throw StateError("`request1.authentication!.username` != 'foo'");
          }

          var request2 = APIRequest(APIRequestMethod.GET, 'foo');
          request2.parameters['username'] = 'foo';
          request2.parameters['password'] = 'not_foo';

          var authentication2 = await apiSecurity.authenticateByRequest(
            request2,
          );
          if (authentication2 != null) {
            throw StateError("Expected null `authentication2`");
          }

          if (request2.authentication != null) {
            throw StateError("Expected null `request2.authentication`");
          }

          var request3 = APIRequest(
            APIRequestMethod.GET,
            'foo',
            credential: APICredential(
              'foo',
              token: requestAuthentication1.tokenKey,
            ),
          );

          var authentication3 = await apiSecurity.authenticateByRequest(
            request3,
          );
          if (authentication3 == null) {
            throw StateError("Null `authentication3`");
          }

          if (request3.authentication == null) {
            throw StateError("Null `request3.authentication`");
          }

          var request4 = APIRequest(APIRequestMethod.GET, 'foo');
          request4.parameters['username'] = 'foo';
          request4.parameters['password'] = 'foo';

          var authentication4 = await apiSecurity.authenticateByRequest(
            request4,
          );
          if (authentication4 == null) {
            throw StateError("Null `authentication4`");
          }

          var requestAuthentication4 = request4.authentication;
          if (requestAuthentication4 == null) {
            throw StateError("Null `request4.authentication`");
          }

          if (requestAuthentication4.username != 'foo') {
            throw StateError("`request4.authentication!.username` != 'foo'");
          }

          var request5 = APIRequest(APIRequestMethod.GET, 'foo');
          request5.parameters['username'] = 'foo';
          request5.parameters['password'] = 'foo';
          request5.parameters['logout'] = 'true';
          request5.parameters['token'] = requestAuthentication1.tokenKey;

          var authentication5 = await apiSecurity.authenticateByRequest(
            request5,
            allowLogout: true,
          );
          if (authentication5 != null) {
            throw StateError("Not `null` `authentication5`");
          }

          await Future.delayed(Duration(milliseconds: 1000));

          var request6 = APIRequest(
            APIRequestMethod.GET,
            'foo',
            credential: APICredential(
              'foo',
              token: requestAuthentication1.tokenKey,
            ),
          );

          var authentication6 = await apiSecurity.authenticateByRequest(
            request6,
          );
          if (authentication6 != null) {
            throw StateError("Not `null` `authentication6`");
          }

          return true;
        });

        expect(isolateOk, isTrue);
      }
    });
  });
}

class _MyAPISecurity extends APISecurity {
  _MyAPISecurity({super.sharedStore});

  @override
  String generateToken(String username) {
    if (username == 'foo') {
      return 'TK$fooSha256';
    } else if (username == 'bar') {
      return 'TK$barSha256';
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
    APICredential credential,
    List<APIPermission>? previousPermissions,
  ) {
    return [
      APIPermission('basic'),
      if (credential.username.startsWith('admin')) APIPermission('admin'),
    ];
  }
}
