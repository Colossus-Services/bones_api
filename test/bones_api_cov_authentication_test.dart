@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

const fooSha256 =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';

void main() {
  group('APICredential (coverage)', () {
    test('fromMap', () {
      expect(APICredential.fromMap(null), isNull);

      expect(
        () => APICredential.fromMap(null, requiresUsernameAndPassword: true),
        throwsArgumentError,
      );

      expect(
        () => APICredential.fromMap({
          'pass': 'x',
        }, requiresUsernameAndPassword: true),
        throwsArgumentError,
      );

      expect(
        () => APICredential.fromMap({
          'user': 'foo',
        }, requiresUsernameAndPassword: true),
        throwsArgumentError,
      );

      expect(APICredential.fromMap({'password': 'foo'}), isNull);

      var c1 = APICredential.fromMap({'USER': ' foo ', 'PASS': ' foo '})!;
      expect(c1.username, equals('foo'));
      expect(c1.checkPassword('foo'), isTrue);

      var c2 = APICredential.fromMap({
        'username': 'bar',
        'password': 'foo',
      }, requiresUsernameAndPassword: true)!;
      expect(c2.username, equals('bar'));
      expect(c2.password!.passwordHash, equals(fooSha256));

      var c3 = APICredential.fromMap({'username': 'baz'})!;
      expect(c3.hasPassword, isFalse);
    });

    test('copy / withUsername / checks / equality / toString', () {
      var c = APICredential(
        'foo',
        passwordHash: 'foo',
        token: 'TK1',
        refreshToken: 'RTK1',
      )..usernameEntity = {'id': 1};

      var copy = c.copy(withPassword: false, withToken: false);
      expect(copy.username, equals('foo'));
      expect(copy.password, isNull);
      expect(copy.token, isNull);
      expect(copy.refreshToken, equals('RTK1'));
      expect(copy.usernameEntity, equals({'id': 1}));

      var copy2 = c.copy(withRefreshToken: false);
      expect(copy2.refreshToken, isNull);
      expect(copy2, equals(c));
      expect(copy2.hashCode, equals(c.hashCode));

      var c2 = c.withUsername('bar');
      expect(c2.username, equals('bar'));
      expect(c2.token, equals('TK1'));
      expect(c2, isNot(equals(c)));

      expect(c.checkPassword(null), isFalse);
      expect(c.checkPassword(fooSha256), isTrue);
      expect(APICredential('x').checkPassword('foo'), isFalse);

      expect(c.checkCredential(null), isFalse);
      expect(c.checkCredential(APICredential('bar')), isFalse);
      expect(
        c.checkCredential(APICredential('foo', passwordHash: 'foo')),
        isTrue,
      );
      expect(
        c.checkCredential(APICredential('foo', passwordHash: 'bar')),
        isFalse,
      );
      expect(
        APICredential('foo').checkCredential(APICredential('foo')),
        isTrue,
      );

      expect(c.toString(), contains('token: TK1'));
      expect(
        APICredential('foo', passwordHash: 'foo').toString(),
        contains('password: APIPassword{hashAlgorithm: sha256'),
      );
    });
  });

  group('APIPassword (coverage)', () {
    test('basic', () {
      var p1 = APIPassword('foo');
      var p2 = APIPassword(fooSha256);
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.checkPassword('foo'), isTrue);
      expect(p1.checkPassword('bar'), isFalse);
      expect(
        p1.toString(),
        equals('APIPassword{hashAlgorithm: sha256, passwordHash: ***}'),
      );
    });

    test('hash algorithms', () {
      expect(APIPasswordHashAlgorithm.detect('foo'), isNull);
      expect(
        APIPasswordHashAlgorithm.detect(fooSha256),
        same(APIPasswordSHA256()),
      );

      var sha = APIPasswordSHA256();
      expect(sha.toString(), equals('APIPasswordHashAlgorithm{sha256}'));
      expect(sha.hashPassword(fooSha256), equals(fooSha256));
      expect(sha.ensureHashedPassword('foo'), equals(fooSha256));

      // ignore: deprecated_member_use_from_same_package, deprecated_member_use
      var none = APIPasswordNotHashed();
      expect(none.name, equals('none'));
      expect(none.isHashedPassword('foo'), isFalse);
      expect(none.hashPassword('foo'), equals('foo'));

      var p = APIPassword('foo', hashAlgorithm: none);
      expect(p.passwordHash, equals('foo'));
      expect(p.checkPassword('foo'), isTrue);
      expect(p, isNot(equals(APIPassword('foo'))));
    });
  });

  group('APIAuthentication (coverage)', () {
    test('permissions / json', () {
      var now = DateTime.now();
      var token = APIToken(
        'foo',
        token: 'TKabc',
        issueTime: DateTime(2020),
        duration: Duration(hours: 1),
      );

      var auth = APIAuthentication(
        token,
        permissions: [
          APIPermission('basic'),
          APIPermission('admin', enabled: false),
          APIPermission('future', initTime: now.add(Duration(days: 1))),
          APIPermission('past', endTime: now.subtract(Duration(days: 1))),
          APIPermission(
            'ranged',
            initTime: now.subtract(Duration(days: 1)),
            endTime: now.add(Duration(days: 1)),
          ),
        ],
        resumed: true,
        data: {'x': 1},
      );

      expect(auth.username, equals('foo'));
      expect(auth.tokenKey, equals('TKabc'));
      expect(auth.isExpired(), isTrue);

      // `isExpired(now:)`: the token issued at 2020-01-01 00:00 for 1h.
      expect(auth.isExpired(now: DateTime(2020, 1, 1, 0, 30)), isFalse);
      expect(auth.isExpired(now: DateTime(2020, 1, 1, 1, 0)), isFalse);
      expect(auth.isExpired(now: DateTime(2020, 1, 1, 1, 0, 1)), isTrue);
      expect(auth.isExpired(now: DateTime(2019, 12, 31)), isFalse);

      var cred = auth.credential;
      expect(cred.username, equals('foo'));
      expect(cred.token, equals('TKabc'));

      expect(auth.enabledPermissions().map((e) => e.type), ['basic', 'ranged']);
      expect(
        auth.enabledPermissionsWhere((p) => p.type.startsWith('r')).length,
        equals(1),
      );
      expect(auth.containsPermissionOfType('basic'), isTrue);
      expect(auth.containsPermissionOfType('admin'), isFalse);
      expect(auth.firstPermissionOfType('ranged')!.type, equals('ranged'));
      expect(auth.firstPermissionOfType('future'), isNull);

      var json = auth.toJson();
      expect(json['resumed'], isTrue);
      expect(json['data'], equals({'x': 1}));
      expect((json['permissions'] as List).length, equals(5));

      var auth2 = APIAuthentication.fromJson({
        'token': {'username': 'foo', 'token': 'TKabc'},
        'permissions': [
          {'type': 'basic', 'enabled': true},
        ],
      });
      expect(auth2.username, equals('foo'));
      expect(auth2.tokenKey, equals('TKabc'));
      expect(auth2.permissions.single.type, equals('basic'));
      expect(auth2.resumed, isFalse);
      expect(auth2.toJson().containsKey('data'), isFalse);
    });
  });

  group('APIToken (coverage)', () {
    test('basic', () {
      var t = APIToken('foo', token: 'TKx', duration: Duration(hours: 1));
      var a1 = t.accessTime;
      t.markAccessTime();
      expect(t.accessTime.compareTo(a1), greaterThanOrEqualTo(0));
      expect(t.toString(), startsWith('APIToken{username: foo, issueTime: '));
      expect(t.refreshToken, isNull);

      var t2 = APIToken.fromJson({
        'username': 'bar',
        'token': 'TKy',
        'refreshToken': 'RTKy',
      });
      expect(t2.username, equals('bar'));
      expect(t2.token, equals('TKy'));
      expect(t2.refreshToken, equals('RTKy'));
      // No `duration`: the default one.
      expect(t2.duration, equals(Duration(hours: 3)));

      // `toJson`/`fromJson` round trip keeps the `duration`:
      var t1 = APIToken(
        'foo',
        token: 'TKj',
        issueTime: DateTime.utc(2020, 1, 2, 3, 4, 5),
        duration: Duration(minutes: 90),
      );
      var t1b = APIToken.fromJson(t1.toJson());
      expect(t1b.duration, equals(Duration(minutes: 90)));
      expect(t1b.issueTime, equals(t1.issueTime));
      expect(t1b.expireTime, equals(t1.expireTime));

      expect(
        () => APIToken.fromCredential(APICredential('foo')),
        throwsArgumentError,
      );

      var t3 = APIToken.fromCredential(
        APICredential('foo', token: 'TKz', refreshToken: 'RTKz'),
        duration: Duration(minutes: 5),
      );
      expect(t3.token, equals('TKz'));
      expect(t3.refreshToken, equals('RTKz'));
      expect(t3.duration, equals(Duration(minutes: 5)));
    });

    test('expiredTokens', () {
      var valid = APIToken('foo', token: 'TK1');
      var expired = APIToken(
        'foo',
        token: 'TK2',
        issueTime: DateTime(2000),
        duration: Duration(hours: 1),
      );

      var list = [valid, expired];
      expect(list.expiredTokens(), equals([expired]));
      expect(list.removeExpiredTokens(), equals([expired]));
      expect(list, equals([valid]));
    });
  });

  group('APIPermission (coverage)', () {
    test('listFromJson', () {
      expect(APIPermission.listFromJson(null), isEmpty);
      var p = APIPermission('a');
      expect(APIPermission.listFromJson(p), equals([p]));
      expect(APIPermission.listFromJson('x'), isEmpty);
      var l = APIPermission.listFromJson([
        {'type': 'a', 'enabled': true},
        {'type': 'B', 'enabled': false},
      ]);
      expect(l.map((e) => e.type), equals(['a', 'b']));
      expect(l.map((e) => e.enabled), equals([true, false]));
    });

    test('constructor / copy / toString / json', () {
      expect(() => APIPermission('  '), throwsArgumentError);

      var init = DateTime.utc(2020, 1, 1);
      var end = DateTime.utc(2030, 1, 1);

      var p = APIPermission(
        ' Admin ',
        initTime: init,
        endTime: end,
        properties: {'level': 3},
      );
      expect(p.type, equals('admin'));
      expect(p.isEnabled(now: DateTime.utc(2025)), isTrue);
      expect(p.isEnabled(now: DateTime.utc(2019)), isFalse);
      expect(p.isEnabled(now: DateTime.utc(2031)), isFalse);

      var s = p.toString();
      expect(s, contains('type: admin'));
      expect(s, contains('initTime: '));
      expect(s, contains('endTime: '));
      expect(s, contains('properties: {level: 3}'));
      expect(
        APIPermission('x').toString(),
        equals('APIPermission{type: x, enabled: true}'),
      );

      var json = p.toJson();
      expect(json['type'], equals('admin'));
      expect(json['initTime'], equals(init));
      expect(json['endTime'], equals(end));
      expect(json['properties'], equals({'level': 3}));

      var p2 = APIPermission.fromJson({
        'type': 'admin',
        'enabled': 'true',
        'initTime': init.toIso8601String(),
        'endTime': end.toIso8601String(),
        'properties': {'level': 3},
      });
      expect(p2.type, equals('admin'));
      expect(p2.enabled, isTrue);
      expect(p2.initTime, equals(init));
      expect(p2.endTime, equals(end));
      expect(p2.properties, equals({'level': 3}));

      var p3 = p.copy(enabled: false, properties: {'level': 1});
      expect(p3.type, equals('admin'));
      expect(p3.enabled, isFalse);
      expect(p3.initTime, equals(init));
      expect(p3.properties, equals({'level': 1}));
      expect(p3.isEnabled(), isFalse);

      var p4 = p.copy();
      expect(p4.enabled, isTrue);
      expect(p4.endTime, equals(end));

      var now = DateTime.now();
      expect(
        APIPermission(
          'r',
          initTime: now.subtract(Duration(days: 1)),
          endTime: now.add(Duration(days: 1)),
        ).isEnabled(),
        isTrue,
      );
      expect(
        APIPermission(
          'r',
          endTime: now.subtract(Duration(days: 1)),
        ).isEnabled(),
        isFalse,
      );

      var auth = APIAuthentication(APIToken('foo', token: 'TKp'));
      expect(auth.permissions, isEmpty);
      expect(auth.toJson().containsKey('permissions'), isFalse);
    });
  });
}
