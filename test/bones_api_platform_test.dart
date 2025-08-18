import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('APIPlatform', () {
    test('basic', () {
      var apiPlatform = APIPlatform.get();
      expect(apiPlatform, isNotNull);

      var capability = apiPlatform.capability;

      expect(capability.int32 || capability.int53 || capability.int64, isTrue);
      expect(
        capability.double32 || capability.double53 || capability.double64,
        isTrue,
      );

      expect(apiPlatform.getProperty(null), isNull);
      expect(apiPlatform.getProperty(null, defaultValue: 'def'), equals('def'));

      expect(
        apiPlatform.getProperty(
          '__TEST__UNKNOWN_PROPERTY_KEY__',
          defaultValue: 'def_generic',
        ),
        equals('def_generic'),
      );
    });
  });
}
