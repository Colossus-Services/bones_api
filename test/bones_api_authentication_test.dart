import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

final fooSha256 =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';
final barSha256 =
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9';

void main() {
  group('APIPasswordSHA256', () {
    setUp(() {});

    test('basic', () async {
      expect(APIPasswordSHA256().hashPassword('foo'), equals(fooSha256));
      expect(APIPasswordSHA256().hashPassword('bar'), equals(barSha256));

      expect(APIPasswordSHA256().isHashedPassword(fooSha256), isTrue);
      expect(APIPasswordSHA256().isHashedPassword('foo'), isFalse);
      expect(APIPasswordSHA256().isHashedPassword(barSha256), isTrue);
      expect(APIPasswordSHA256().isHashedPassword('bar'), isFalse);
    });
  });

  group('APIPassword', () {
    setUp(() {});

    test('basic', () async {
      var pass1 = APIPassword('foo');
      expect(pass1.passwordHash, equals(fooSha256));

      expect(pass1.checkPassword('foo'), isTrue);
      expect(pass1.checkPassword(fooSha256), isTrue);
      expect(pass1.checkPassword('bar'), isFalse);
      expect(pass1.checkPassword(barSha256), isFalse);

      var pass2 = APIPassword('bar');
      expect(pass2.passwordHash, equals(barSha256));

      expect(pass2.checkPassword('bar'), isTrue);
      expect(pass2.checkPassword(barSha256), isTrue);
      expect(pass2.checkPassword('foo'), isFalse);
      expect(pass2.checkPassword(fooSha256), isFalse);
    });
  });

  group('APICredential', () {
    setUp(() {});

    test('passwordHash', () async {
      var credential1 = APICredential('joe@mail.com', passwordHash: 'foo');
      var credential2 = APICredential('smith@mail.com', passwordHash: 'bar');

      expect(credential1.hasPassword, isTrue);
      expect(credential1.hasToken, isFalse);

      expect(credential1.checkPassword('foo'), isTrue);
      expect(credential1.checkPassword('bar'), isFalse);

      expect(credential2.checkPassword('bar'), isTrue);
      expect(credential2.checkPassword('foo'), isFalse);
    });

    test('token', () async {
      var credential1 = APICredential('joe@mail.com', token: 'foo');
      var credential2 = APICredential('smith@mail.com', token: 'bar');

      expect(credential1.hasToken, isTrue);
      expect(credential1.hasPassword, isFalse);

      expect(credential1.token, equals('foo'));
      expect(credential2.token, equals('bar'));
    });
  });

  group('APIToken', () {
    setUp(() {});

    test('basic', () async {
      var apiToken = APIToken('joe');

      print(apiToken);

      expect(apiToken.username, equals('joe'));

      expect(apiToken.token.length,
          allOf(greaterThanOrEqualTo(514), lessThanOrEqualTo(514 + 32)));

      expect(apiToken.token, startsWith('TK'));

      await Future.delayed(Duration(milliseconds: 100));

      expect(apiToken.issueTime.compareTo(DateTime.now()), equals(-1));

      expect(apiToken.isExpired(), isFalse);
    });
  });

  group('APIAuthentication', () {
    setUp(() {});

    test('basic', () async {
      var apiToken = APIToken('joe');
      var authentication =
          APIAuthentication(apiToken, permissions: [APIPermission('guest')]);

      print(authentication);

      expect(authentication.username, equals('joe'));
      expect(authentication.tokenKey, equals(apiToken.token));

      await Future.delayed(Duration(milliseconds: 100));

      expect(authentication.isExpired(), isFalse);

      expect(authentication.enabledPermissions().length, equals(1));

      expect(
          authentication
              .enabledPermissionsWhere((p) => p.type.startsWith('g'))
              .length,
          equals(1));

      expect(
          authentication
              .enabledPermissionsWhere((p) => p.type.startsWith('x'))
              .length,
          equals(0));

      expect(authentication.containsPermissionOfType('guest'), isTrue);
      expect(authentication.containsPermissionOfType('admin'), isFalse);

      expect(authentication.firstPermissionOfType('guest'), isNotNull);
      expect(authentication.firstPermissionOfType('admin'), isNull);
    });
  });
}
