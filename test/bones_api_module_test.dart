@TestOn('vm')
import 'package:test/test.dart';

import 'bones_api_test_modules.dart';

void main() {
  group('APIRoot', () {
    test('modules', () {
      var apiRoot = TestAPIRoot();

      expect(apiRoot.modulesNames, equals(['user']));

      var userModule = apiRoot.getModule('user');
      expect(userModule, isA<UserModule>());
    });
  });

  group('UserModule', () {
    test('routes', () {
      var apiRoot = TestAPIRoot();
      var userModule = apiRoot.getModule('user');
      expect(userModule, isA<UserModule>());

      userModule!.ensureConfigured();

      expect(
          userModule.allRoutesNames,
          equals({
            'geDynamicAsync',
            'geDynamicAsync2',
            'getDynamic',
            'getUser',
            'getUserAsync'
          }));
    });
  });
}
