@TestOn('vm')
library;

import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api_db_users_benchmark/db_users_api.dart';
import 'package:test/test.dart';

void main() {
  _testAPI('memory', () => {'sql.memory': <String, dynamic>{}});

  Directory? sqliteDir;
  _testAPI('sqlite', () {
    sqliteDir = Directory.systemTemp.createTempSync('db_users_test_');
    return {
      'sqlite': <String, dynamic>{'path': '${sqliteDir!.path}/test.db'},
    };
  }, onClose: () => sqliteDir?.deleteSync(recursive: true));
}

void _testAPI(
  String dbName,
  Map<String, dynamic> Function() dbConfig, {
  void Function()? onClose,
}) {
  group('UsersAPIRoot ($dbName)', () {
    late UsersAPIRoot api;

    setUpAll(() async {
      var db = dbConfig();
      for (var config in db.values) {
        (config as Map)['populate'] = {'generateTables': true};
      }

      api = UsersAPIRoot(apiConfig: {'db': db});
      await api.ensureInitialized();
    });

    tearDownAll(() async {
      api.close();
      onClose?.call();
    });

    Future<APIResponse> call(
      String path, [
      Map<String, dynamic>? parameters,
    ]) async => api.call(APIRequest.post(path, parameters: parameters));

    test('roles', () async {
      for (var name in ['admin', 'editor', 'viewer']) {
        var res = await call('/role/create', {'name': name});
        expect(res.isOK, isTrue, reason: '$res');
      }

      var res = await call('/role/list');
      expect((res.payload as List).length, equals(3));
    });

    test('CRUD', () async {
      var res = await call('/user/register', {
        'email': 'joe@example.com',
        'password': 'pass123',
        'name': 'Joe',
        'countryCode': 'US',
        'state': 'NY',
        'city': 'New York',
        'roles': 'admin,viewer',
      });
      expect(res.isOK, isTrue, reason: '$res');

      var user = res.payload as User;
      expect(user.id, isNotNull);
      expect(user.roles.map((r) => r.name), equals(['admin', 'viewer']));

      res = await call('/user/byId', {'id': '${user.id}'});
      expect(res.isOK, isTrue, reason: '$res');
      expect((res.payload as User).email, equals('joe@example.com'));
      expect((res.payload as User).address.city, equals('New York'));

      res = await call('/user/update', {
        'id': '${user.id}',
        'name': 'Joseph',
        'state': 'CA',
      });
      expect(res.isOK, isTrue, reason: '$res');

      res = await call('/user/byId', {'id': '${user.id}'});
      expect((res.payload as User).name, equals('Joseph'));
      expect((res.payload as User).address.state, equals('CA'));

      res = await call('/user/remove', {'id': '${user.id}'});
      expect(res.isOK, isTrue, reason: '$res');

      res = await call('/user/byId', {'id': '${user.id}'});
      expect(res.isNotFound, isTrue, reason: '$res');
    });

    test('queries and login', () async {
      for (var i = 0; i < 10; ++i) {
        var res = await call('/user/register', {
          'email': 'user$i@example.com',
          'password': 'pass$i',
          'name': 'User $i',
          'countryCode': 'US',
          'state': i.isEven ? 'NY' : 'TX',
          'city': 'City $i',
          'roles': 'viewer',
        });
        expect(res.isOK, isTrue, reason: '$res');
      }

      var res = await call('/user/count');
      expect(res.payload, equals(10));

      res = await call('/user/byEmail', {'email': 'user3@example.com'});
      expect(res.isOK, isTrue, reason: '$res');
      expect((res.payload as User).name, equals('User 3'));

      res = await call('/user/byState', {'state': 'TX'});
      expect((res.payload as List).length, equals(5));

      res = await call('/user/list', {'page': '1', 'pageSize': '4'});
      expect(
        (res.payload as List).map((u) => (u as User).name),
        equals(['User 4', 'User 5', 'User 6', 'User 7']),
      );

      var auth = await api.callAuthenticate('user3@example.com', 'pass3');
      expect(auth, isNotNull);
      expect(auth!.username, equals('user3@example.com'));

      auth = await api.callAuthenticate('user3@example.com', 'wrong');
      expect(auth, isNull);
    });
  });
}
