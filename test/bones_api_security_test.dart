import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

final fooSha256 =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';
final barSha256 =
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9';

final users = {'foo': fooSha256, 'bar': barSha256};
final tokens = users.map((key, value) => MapEntry(value, key));

void main() {
  group('APISecurity', () {
    setUp(() {});

    test('createToken', () async {
      var apiSecurity = _MyAPISecurity();

      var token = apiSecurity.createToken('foo');

      expect(token.username, equals('foo'));
      expect(token.token.length, equals(64));
    });

    test('authenticate', () async {
      var apiSecurity = _MyAPISecurity();

      expect(
          apiSecurity.authenticate(APICredential('foo', passwordHash: 'foo')),
          isNotNull);

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

    test('authenticate', () async {
      var apiSecurity = _MyAPISecurity();

      var request1 = APIRequest(APIRequestMethod.GET, 'foo');
      request1.credential = APICredential('foo', passwordHash: 'foo');

      expect(apiSecurity.authenticateByRequest(request1), isNotNull);
      expect(request1.authentication, isNotNull);
      expect(request1.authentication!.username, equals('foo'));

      var request2 = APIRequest(APIRequestMethod.GET, 'foo');
      request2.credential = APICredential('bar', passwordHash: 'xxx');

      expect(apiSecurity.authenticateByRequest(request2), isNull);
      expect(request2.authentication, isNull);
    });
  });
}

class _MyAPISecurity extends APISecurity {
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
  FutureOr<bool> checkCredentialPassword(APICredential credential) {
    var pass = users[credential.username];
    var passOK = credential.checkPassword(pass);
    return passOK;
  }

  @override
  FutureOr<List<APIPermission>> getCredentialPermissions(
      APICredential credential) {
    return [
      APIPermission('basic'),
      if (credential.username.startsWith('admin')) APIPermission('admin'),
    ];
  }
}
