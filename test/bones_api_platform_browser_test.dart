@TestOn('browser')
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('APIPlatform (Browser)', () {
    test('get', () {
      var apiPlatform = APIPlatform.get();
      expect(apiPlatform, isNotNull);

      expect(
          apiPlatform.type,
          anyOf(
            APIPlatformType.browser,
          ));

      var capability = apiPlatform.capability;
      expect(capability.canReadFile, isTrue);

      expect(capability.int53, isTrue);
      expect(capability.double53, isTrue);

      expect(
          apiPlatform.resolveFilePath('pubspec.yaml'),
          allOf(contains('pubspec.yaml'),
              anyOf(startsWith('http:'), startsWith('https:'))));

      expect(
          apiPlatform.getProperty('__TEST__UNKNOWN_PROPERTY_KEY__',
              defaultValue: 'def_browser'),
          equals('def_browser'));
    });
  });
}
