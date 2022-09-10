import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
  group('Enum', () {
    test('enumFromName', () async {
      expect(enumFromName('admin', RoleType.values), RoleType.admin);
      expect(enumFromName(' admin ', RoleType.values), RoleType.admin);
      expect(enumFromName(' Guest ', RoleType.values), RoleType.guest);
      expect(enumFromName('x', RoleType.values), isNull);
      expect(enumFromName('', RoleType.values), isNull);
      expect(enumFromName(null, RoleType.values), isNull);
    });

    test('enumToName', () async {
      expect(enumToName(RoleType.admin), equals('admin'));
      expect(enumToName(RoleType.guest), equals('guest'));
    });

    test('parse', () async {
      expect(RoleType.values.parse('admin'), equals(RoleType.admin));
      expect(RoleType.values.parse(' Guest '), equals(RoleType.guest));
      expect(RoleType.values.parse(' X '), isNull);
    });
  });
}
