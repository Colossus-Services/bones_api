@TestOn('vm')
import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:logging/logging.dart' as logging;
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
        'asyncError',
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
        var apiRootInfoJson = (await apiRoot.call(APIRequest.get('/API-INFO')))
            .payloadAs<APIRootInfo>()
            .toJson();

        expect(Map.from(apiRootInfoJson)..remove('modules'),
            equals({'name': 'Test', 'version': '1.0'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => e['name'])
                .toList(),
            equals(['about', 'user']));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => List.from(e['routes'])
                    .cast<Map>()
                    .map((e) => e['name'])
                    .toList())
                .toList(),
            equals([aboutRoutes, userRoutes]));
      }

      {
        var apiRootInfoJson =
            (await apiRoot.call(APIRequest.get('/API-INFO/about')))
                .payloadAs<APIRootInfo>()
                .toJson();

        expect(
            Map.from(apiRootInfoJson)..remove('modules'),
            equals(
                {'name': 'Test', 'version': '1.0', 'selectedModule': 'about'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => e['name'])
                .toList(),
            equals(aboutRoutes));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => List.from(e['routes'])
                    .cast<Map>()
                    .map((e) => e['name'])
                    .toList())
                .toList(),
            equals([aboutRoutes]));
      }

      {
        var apiRootInfoJson =
            (await apiRoot.call(APIRequest.get('/API-INFO/user')))
                .payloadAs<APIRootInfo>()
                .toJson();

        expect(
            Map.from(apiRootInfoJson)..remove('modules'),
            equals(
                {'name': 'Test', 'version': '1.0', 'selectedModule': 'user'}));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => e['name'])
                .toList(),
            equals(['user']));

        expect(
            List.from(apiRootInfoJson['modules'])
                .cast<Map>()
                .map((e) => List.from(e['routes'])
                    .cast<Map>()
                    .map((e) => e['name'])
                    .toList())
                .toList(),
            equals([userRoutes]));
      }

      expect((await apiRoot.call(APIRequest.get('/not'))).toString(),
          equals('NOT FOUND: No route for path "/not"'));

      expect(
          (await apiRoot.call(
                  APIRequest.get('/user/getUser', parameters: {'id': 11})))
              .payloadAs<User>()
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
              'latitude': 0.0,
              'longitude': 0.0
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
              .payloadAs<User>()
              .toJson(),
          equals(_buildTestUserJson(10001, 'smith@email.com.echo', 101)));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoUser',
                  payload: _buildTestUserJson(10002, 'jsmith@email.com', 102),
                  payloadMimeType: 'json')))
              .payloadAs<User>()
              .toJson(),
          equals(_buildTestUserJson(10002, 'jsmith@email.com.echo', 102)));

      expect(
          (await apiRoot.call(APIRequest.post('/user/echoUser',
                  payload: _buildTestUserJson(10002, 'jsmith@email.com', 102,
                      userInfo: 'the info', userInfoId: 1002),
                  payloadMimeType: 'json')))
              .payloadAs<User>()
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
              .payloadAs<List<User>>()
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
              .payloadAs<List<User>>()
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
              .payloadAs<List<User>>()
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
              .payloadAs<Map>(),
          equals({
            'context.resolutionRules': {
              'allowEntityFetch': true,
              'eagerEntityTypes': ['User']
            }
          }));

      expect(
          (await apiRoot.call(
                  APIRequest.post('/user/getRequestEntityResolutionRules')))
              .payloadAs<Map>(),
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

      var logAPIRoot = logging.Logger('APIRoot');

      var severeLog = Completer<logging.LogRecord>();

      logAPIRoot.onRecord.listen((logRecord) {
        if (logRecord.level == logging.Level.SEVERE) {
          severeLog.completeSafe(logRecord);
        }
      });

      var messageDate = 'Date: ${DateTime.now()}';

      expect(
          (await apiRoot.call(APIRequest.post(
            '/user/asyncError',
            payload: messageDate,
          )))
              .payloadAs<String>(),
          equals('Message: $messageDate'));

      expect(
          (await severeLog.future).message,
          allOf(
            contains('Asynchronous error while calling:'),
            contains('APIRequest#15{ method: POST, path: /user/asyncError'),
          ));

      apiRoot.close();
    });
  });

  group('APIRouteBuilder.resolveValueType', () {
    test('int', () {
      var t = TypeInfo(int);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals(123));
      expect(APIRouteBuilder.resolveValueByType(t, '456'), equals(456));
      expect(APIRouteBuilder.resolveValueByType(t, '"567"'), equals(567));
    });

    test('double', () {
      var t = TypeInfo(double);
      expect(APIRouteBuilder.resolveValueByType(t, 123),
          allOf(equals(123.0), isA<double>()));
      expect(APIRouteBuilder.resolveValueByType(t, 12.3), equals(12.3));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals(45.6));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals(56.7));
    });

    test('num', () {
      var t = TypeInfo(num);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals(123));
      expect(APIRouteBuilder.resolveValueByType(t, 12.3), equals(12.3));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals(45.6));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals(56.7));
    });

    test('String', () {
      var t = TypeInfo(String);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals('123'));
      expect(APIRouteBuilder.resolveValueByType(t, 12.3), equals('12.3'));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals('45.6'));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals('"56.7"'));
    });

    test('List', () {
      var t = TypeInfo<List>(List);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals([123]));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals(['123']));
      expect(APIRouteBuilder.resolveValueByType(t, [12, 34.5]),
          equals([12, 34.5]));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals(['45.6']));
      expect(
          APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals(['"56.7"']));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45, 6'), equals(['45', '6']));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45;6'), equals(['45', '6']));
    });

    test('List<int>', () {
      var t = TypeInfo<List<int>>(List, [int]);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals([123]));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals([123]));
      expect(
          APIRouteBuilder.resolveValueByType(t, [12, 34.5]), equals([12, 34]));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals([45]));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals([56]));
      expect(APIRouteBuilder.resolveValueByType(t, '45, 6'), equals([45, 6]));
      expect(APIRouteBuilder.resolveValueByType(t, '45;6'), equals([45, 6]));
    });

    test('List<double>', () {
      var t = TypeInfo<List<double>>(List, [double]);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals([123.0]));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals([123.0]));
      expect(APIRouteBuilder.resolveValueByType(t, [12, 34.5]),
          equals([12, 34.5]));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals([45.6]));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals([56.7]));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45, 6'), equals([45.0, 6.0]));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45;6.1'), equals([45.0, 6.1]));
    });

    test('Set', () {
      var t = TypeInfo<Set>(Set);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals({123}));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals({'123'}));
      expect(APIRouteBuilder.resolveValueByType(t, [12, 34.5]),
          equals([12, 34.5]));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals({'45.6'}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals({'"56.7"'}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45, 6'), equals({'45', '6'}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45;6'), equals({'45', '6'}));
    });

    test('Set<int>', () {
      var t = TypeInfo<Set<int>>(Set, [int]);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals({123}));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals({123}));
      expect(
          APIRouteBuilder.resolveValueByType(t, [12, 34.5]), equals({12, 34}));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals({45}));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals({56}));
      expect(APIRouteBuilder.resolveValueByType(t, '45, 6'), equals({45, 6}));
      expect(APIRouteBuilder.resolveValueByType(t, '45;6'), equals({45, 6}));
    });

    test('Set<double>', () {
      var t = TypeInfo<Set<double>>(Set, [double]);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals({123.0}));
      expect(APIRouteBuilder.resolveValueByType(t, '123'), equals({123.0}));
      expect(APIRouteBuilder.resolveValueByType(t, {12, 34.5}),
          equals([12, 34.5]));
      expect(APIRouteBuilder.resolveValueByType(t, '45.6'), equals({45.6}));
      expect(APIRouteBuilder.resolveValueByType(t, '"56.7"'), equals({56.7}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45, 6'), equals({45.0, 6.0}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '45;6.1'), equals({45.0, 6.1}));
    });

    test('Map', () {
      var t = TypeInfo<Map>(Map);
      expect(APIRouteBuilder.resolveValueByType(t, 123), equals({123: null}));
      expect(
          APIRouteBuilder.resolveValueByType(t, '123'), equals({'123': null}));
      expect(APIRouteBuilder.resolveValueByType(t, [12, 34]),
          equals({12: null, 34: null}));
      expect(APIRouteBuilder.resolveValueByType(t, 'a:123 ; b:456'),
          equals({'a': '123', 'b': '456'}));
    });

    test('Map<String,int>', () {
      var t = TypeInfo<Map<String, int>>(Map, [String, int]);
      expect(APIRouteBuilder.resolveValueByType(t, 'a:123 ; b:456'),
          equals({'a': 123, 'b': 456}));
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
      'latitude': 0.0,
      'longitude': 0.0
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
