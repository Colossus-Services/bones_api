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

  group('IdenticalSet', () {
    test('basic', () {
      var s1 = IdenticalSet<String>();

      expect(s1.isEmpty, isTrue);
      expect(s1.length, equals(0));
      expect(s1.toList(), equals([]));

      expect(s1.contains('a'), isFalse);
      expect(s1.add('a'), isTrue);
      expect(s1.contains('a'), isTrue);

      expect(s1.length, equals(1));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a']));

      expect(s1.contains('b'), isFalse);
      expect(s1.add('b'), isTrue);
      expect(s1.contains('b'), isTrue);

      expect(s1.length, equals(2));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a', 'b']));

      expect(s1.contains('x'), isFalse);
      expect(s1.remove('x'), isFalse);

      expect(s1.contains('b'), isTrue);
      expect(s1.add('b'), isFalse);
      expect(s1.contains('b'), isTrue);

      expect(s1.length, equals(2));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a', 'b']));

      expect(s1.contains('a'), isTrue);
      expect(s1.remove('a'), isTrue);
      expect(s1.contains('a'), isFalse);

      expect(s1.length, equals(1));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['b']));
    });
  });
}
