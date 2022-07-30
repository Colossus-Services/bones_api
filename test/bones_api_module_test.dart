@TestOn('vm')
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

import 'bones_api_test_modules.dart';
import 'bones_api_test_entities.dart';

void main() {
  group('APIRoot', () {
    test('modules', () {
      var apiRoot = TestAPIRoot();

      expect(apiRoot.modulesNames, equals(['user']));

      var userModule = apiRoot.getModule('user');
      expect(userModule, isA<UserModule>());

      apiRoot.close();
    });
  });

  group('UserModule', () {
    setUpAll(() {
      User$reflection.boot();
    });

    test('routes', () async {
      var apiRoot = TestAPIRoot();
      var userModule = apiRoot.getModule('user');
      expect(userModule, isA<UserModule>());

      userModule!.ensureConfigured();

      expect(
          userModule.allRoutesNames,
          equals({
            'echoListUser',
            'echoListUser2',
            'echoUser',
            'geDynamicAsync',
            'geDynamicAsync2',
            'getDynamic',
            'getUser',
            'getUserAsync'
          }));

      expect((await apiRoot.call(APIRequest.get('/not'))).toString(),
          equals('NOT FOUND: No route for path "/not"'));

      expect(
          (await apiRoot.call(
                  APIRequest.get('/user/getUser', parameters: {'id': 11})))
              .payload
              .toJson(),
          equals({
            'email': 'joe@email.com',
            'password': 'pass123',
            'address': {
              'state': 'SC',
              'city': 'NY',
              'street': '',
              'number': 123,
              'stores': [],
              'closedStores': []
            },
            'roles': [],
            'level': null,
            'wakeUpTime': null,
            'creationTime': 1633965194000
          }));

      expect(
          (await apiRoot.call(APIRequest.post(
            '/user/echoUser',
            payload: _buildTestUser(),
          )))
              .payload
              .toJson(),
          equals(_buildTestUserJson(10001, 'smith@email.com.echo', 101)));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoUser',
                  payload: _buildTestUserJson(10002, 'jsmith@email.com', 102),
                  payloadMimeType: 'json')))
              .payload
              .toJson(),
          equals(_buildTestUserJson(10002, 'jsmith@email.com.echo', 102)));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoListUser',
                  payload: [
                    _buildTestUserJson(10003, 'jsmith3@email.com', 103),
                    _buildTestUserJson(10004, 'jsmith4@email.com', 104),
                  ],
                  payloadMimeType: 'json')))
              .payload
              .map((e) => e.toJson())
              .toList(),
          equals([
            _buildTestUserJson(10003, 'jsmith3@email.com.echo[0]', 103),
            _buildTestUserJson(10004, 'jsmith4@email.com.echo[1]', 104),
          ]));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoListUser2',
                  parameters: {'msg': 'the-msg'},
                  payload: [
                    _buildTestUserJson(10003, 'jsmith3@email.com', 103),
                    _buildTestUserJson(10004, 'jsmith4@email.com', 104),
                  ],
                  payloadMimeType: 'json')))
              .payload
              .map((e) => e.toJson())
              .toList(),
          equals([
            _buildTestUserJson(
                10003, 'jsmith3@email.com.echo[0]{the-msg}', 103),
            _buildTestUserJson(
                10004, 'jsmith4@email.com.echo[1]{the-msg}', 104),
          ]));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoListUser2',
                  payload: {
                    'msg': 'the-msg',
                    'users': [
                      _buildTestUserJson(10003, 'jsmith3@email.com', 103),
                      _buildTestUserJson(10004, 'jsmith4@email.com', 104),
                    ]
                  },
                  payloadMimeType: 'json')))
              .payload
              .map((e) => e.toJson())
              .toList(),
          equals([
            _buildTestUserJson(
                10003, 'jsmith3@email.com.echo[0]{the-msg}', 103),
            _buildTestUserJson(
                10004, 'jsmith4@email.com.echo[1]{the-msg}', 104),
          ]));

      apiRoot.close();
    });
  });
}

User _buildTestUser() {
  return User('smith@email.com', '123456', Address('CA', 'NY', '', 101), [],
      id: 10001,
      creationTime: DateTime.fromMillisecondsSinceEpoch(1665501194000));
}

Map<String, Object?> _buildTestUserJson(int id, String email, int n) {
  return {
    'id': id,
    'email': email,
    'password': '123456',
    'address': {
      'state': 'CA',
      'city': 'NY',
      'street': '',
      'number': n,
      'stores': [],
      'closedStores': []
    },
    'roles': [],
    'level': null,
    'wakeUpTime': null,
    'creationTime': 1665501194000
  };
}
