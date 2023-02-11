@TestOn('vm')
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';
import 'bones_api_test_modules.dart';

void main() {
  group('APIRoot', () {
    test('modules', () {
      var apiRoot = TestAPIRoot();

      expect(apiRoot.modulesNames, equals(['about', 'user']));

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
      var aboutModule = apiRoot.getModule('about');
      var userModule = apiRoot.getModule('user');
      expect(userModule, isA<UserModule>());

      aboutModule!.ensureConfigured();
      userModule!.ensureConfigured();

      print('DateTime.now: ${DateTime.now()}');

      const aboutRoutes = ['about'];

      const userRoutes = [
        'echoListUser',
        'echoListUser2',
        'echoUser',
        'geDynamicAsync',
        'geDynamicAsync2',
        'getContextEntityResolutionRules',
        'getDynamic',
        'getRequestEntityAccessRules',
        'getRequestEntityResolutionRules',
        'getUser',
        'getUserAsync'
      ];

      expect(aboutModule.allRoutesNames, equals({...aboutRoutes}));

      expect(userModule.allRoutesNames, equals({...userRoutes}));

      {
        var apiRootInfoJson =
            (await apiRoot.call(APIRequest.get('/API-INFO'))).payload.toJson();

        expect(Map.from(apiRootInfoJson)..remove('modules'),
            equals({'name': 'Test', 'version': '1.0'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) => e['name'])
                .toList(),
            equals(['about', 'user']));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) =>
                    List.from(e['routes']).map((e) => e['name']).toList())
                .toList(),
            equals([aboutRoutes, userRoutes]));
      }

      {
        var apiRootInfoJson =
            (await apiRoot.call(APIRequest.get('/API-INFO/about')))
                .payload
                .toJson();

        expect(
            Map.from(apiRootInfoJson)..remove('modules'),
            equals(
                {'name': 'Test', 'version': '1.0', 'selectedModule': 'about'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) => e['name'])
                .toList(),
            equals(aboutRoutes));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) =>
                    List.from(e['routes']).map((e) => e['name']).toList())
                .toList(),
            equals([aboutRoutes]));
      }

      {
        var apiRootInfoJson =
            (await apiRoot.call(APIRequest.get('/API-INFO/user')))
                .payload
                .toJson();

        expect(
            Map.from(apiRootInfoJson)..remove('modules'),
            equals(
                {'name': 'Test', 'version': '1.0', 'selectedModule': 'user'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) => e['name'])
                .toList(),
            equals(['user']));

        expect(
            List.from(apiRootInfoJson['modules'])
                .map((e) =>
                    List.from(e['routes']).map((e) => e['name']).toList())
                .toList(),
            equals([userRoutes]));
      }

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
              'closedStores': {'EntityReferenceList': 'Store'},
            },
            'roles': [],
            'level': null,
            'wakeUpTime': null,
            'userInfo': null,
            'creationTime': 1633954394000
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
          (await apiRoot.call(APIRequest.post('/user/echoUser',
                  payload: _buildTestUserJson(10002, 'jsmith@email.com', 102,
                      userInfo: 'the info', userInfoId: 1002),
                  payloadMimeType: 'json')))
              .payload
              .toJson(),
          equals(_buildTestUserJson(10002, 'jsmith@email.com.echo', 102,
              userInfo: 'the info', userInfoId: 1002, userInfoRef: true)));

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

      expect(
          (await apiRoot.call(
                  APIRequest.post('/user/getContextEntityResolutionRules')))
              .payload,
          equals({
            'context.resolutionRules': {
              'allowEntityFetch': true,
              'eagerEntityTypes': ['User']
            }
          }));

      expect(
          (await apiRoot.call(
                  APIRequest.post('/user/getRequestEntityResolutionRules')))
              .payload,
          equals({
            'resolutionRules': {
              'allowEntityFetch': true,
              'eagerEntityTypes': ['User']
            }
          }));

      expect(
          (await apiRoot
                  .call(APIRequest.post('/user/getRequestEntityAccessRules')))
              .payload,
          equals({
            'accessRules': {
              'ruleType': 'block',
              'entityType': 'User',
              'entityFields': ['email']
            }
          }));

      apiRoot.close();
    });
  });
}

User _buildTestUser() {
  return User('smith@email.com', '123456', Address('CA', 'NY', '', 101), [],
      id: 10001,
      creationTime:
          DateTime.fromMillisecondsSinceEpoch(1665501194000, isUtc: true));
}

Map<String, Object?> _buildTestUserJson(int id, String email, int n,
    {String? userInfo, int? userInfoId, bool userInfoRef = false}) {
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
      'closedStores': {'EntityReferenceList': 'Store'},
    },
    'roles': [],
    'level': null,
    'wakeUpTime': null,
    'userInfo': (userInfo == null)
        ? null
        : (userInfoRef
            ? {
                'EntityReference': 'UserInfo',
                if (userInfoId != null) 'id': userInfoId,
                'entity': {
                  if (userInfoId != null) 'id': userInfoId,
                  'info': userInfo,
                }
              }
            : {
                if (userInfoId != null) 'id': userInfoId,
                'info': userInfo,
              }),
    'creationTime': 1665501194000
  };
}
