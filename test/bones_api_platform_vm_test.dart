@TestOn('vm')
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('APIPlatform (VM)', () {
    test('get', () {
      var apiPlatform = APIPlatform.get();
      expect(apiPlatform, isNotNull);

      expect(
        apiPlatform.type,
        anyOf(
          APIPlatformType.vm,
          APIPlatformType.native,
          APIPlatformType.linux,
          APIPlatformType.windows,
          APIPlatformType.macos,
        ),
      );

      var capability = apiPlatform.capability;
      expect(capability.canReadFile, isTrue);

      expect(capability.int32 || capability.int64, isTrue);
      expect(capability.double32 || capability.double64, isTrue);

      expect(
        apiPlatform.resolveFilePath('pubspec.yaml'),
        contains('pubspec.yaml'),
      );

      expect(
        apiPlatform.getProperty(
          '__TEST__UNKNOWN_PROPERTY_KEY__',
          defaultValue: 'def_vm',
        ),
        equals('def_vm'),
      );
    });
  });
}
