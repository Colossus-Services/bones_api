@TestOn('vm')
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

void main() {
  group('Time', () {
    test('constructor range checks', () {
      expect(() => Time(25), throwsArgumentError);
      expect(() => Time(-1), throwsArgumentError);
      expect(() => Time(1, 60), throwsArgumentError);
      expect(() => Time(1, 0, 60), throwsArgumentError);
      expect(() => Time(1, 0, 0, 1000), throwsArgumentError);
      expect(() => Time(1, 0, 0, 0, 1000), throwsArgumentError);
    });

    test('fromDateTime / DateTime.toTime', () {
      var dt = DateTime.utc(2020, 1, 2, 3, 4, 5, 6, 7);

      var t = Time.fromDateTime(dt);
      expect(t, equals(Time(3, 4, 5, 6, 7)));
      expect(Time.from(dt), equals(t));

      expect(dt.toTime(), equals(Time(3, 4, 5, 6, 7)));
      expect(
        dt.toTime(
          withMinute: false,
          withSecond: false,
          withMillisecond: false,
          withMicrosecond: false,
        ),
        equals(Time(3)),
      );
      expect(
        dt.toTime(withMillisecond: false, withMicrosecond: false),
        equals(Time(3, 4, 5)),
      );
    });

    test('fromBytes errors', () {
      // 4 bytes with a negative int32: falls back to string parsing.
      var negative = [0xFF, 0xFF, 0xFF, 0xFF];
      expect(() => Time.fromBytes(negative), throwsFormatException);
      expect(
        () => Time.fromBytes(negative, allowParseString: false),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid bytes format'),
          ),
        ),
      );

      // Not a valid time string:
      expect(
        () => Time.fromBytes('ab:cd'.codeUnits),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid bytes or string format'),
          ),
        ),
      );
    });

    test('fromBytes 64 bits and string format', () {
      var t = Time(10, 20, 30, 400, 500);
      expect(Time.fromBytes(t.toBytes64()), equals(t));
      expect(Time.fromBytes(t.toBytes32()), equals(Time(10, 20, 30, 400)));

      // String format bytes (with milliseconds and microseconds):
      expect(
        Time.fromBytes('10:20:30.400500'.codeUnits),
        equals(Time(10, 20, 30, 400, 500)),
      );
      expect(Time.fromBytes('10:20:30'.codeUnits), equals(Time(10, 20, 30)));

      // Postgres encoding (7 bytes):
      var bytes7 = Uint8List.fromList(t.toBytes64().sublist(0, 7));
      expect(Time.fromBytes(bytes7), isA<Time>());
    });

    test('parse', () {
      expect(() => Time.parse('  '), throwsFormatException);
      expect(
        () => Time.parse('abc', allowFromBytes: false),
        throwsFormatException,
      );

      // A non `hh:mm` string is parsed as bytes (64 bits microseconds):
      var s = String.fromCharCodes([0, 0, 0, 0, 0, 0, 0, 1]);
      expect(Time.parse(s), equals(Time(0, 0, 0, 0, 1)));

      expect(Time.parse('Time(01:02:03.004)'), equals(Time(1, 2, 3, 4)));
      expect(Time.parse('01:02'), equals(Time(1, 2)));
    });

    test('from', () {
      expect(Time.from(null), isNull);
      var t = Time(1, 2, 3);
      expect(identical(Time.from(t), t), isTrue);
      expect(
        Time.from(const Duration(hours: 2, minutes: 3)),
        equals(Time(2, 3)),
      );
      expect(Time.from(1000), equals(Time(0, 0, 1)));
      expect(
        Time.from({
          'hour': 4,
          'minute': '5',
          'second': 6,
          'millisecond': 7,
          'microsecond': 8,
        }),
        equals(Time(4, 5, 6, 7, 8)),
      );
      expect(Time.from({'hour': 4}), equals(Time(4)));
      expect(Time.from('04:05:06'), equals(Time(4, 5, 6)));
      expect(Time.from(Time(1).toBytes64()), equals(Time(1)));
    });

    test('copyWith / toDateTime / toString', () {
      var t = Time(1, 2, 3, 4, 5);

      expect(t.copyWith(), equals(t));
      expect(t.copyWith(hour: 9), equals(Time(9, 2, 3, 4, 5)));
      expect(
        t.copyWith(minute: 10, second: 11, millisecond: 12, microsecond: 13),
        equals(Time(1, 10, 11, 12, 13)),
      );

      expect(
        t.toDateTime(2021, 2, 3),
        equals(DateTime.utc(2021, 2, 3, 1, 2, 3, 4, 5)),
      );
      expect(
        t.toDateTime(2021, 2, 3, false),
        equals(DateTime(2021, 2, 3, 1, 2, 3, 4, 5)),
      );

      expect(t.toString(), equals('01:02:03.004005'));
      expect(t.toString(withMicrosecond: false), equals('01:02:03.004'));
      expect(Time(1, 2).toString(withSeconds: false), equals('01:02'));
      expect(Time(1, 2).toString(), equals('01:02:00'));
    });

    test('compareTo / equality / hashCode / operators', () {
      var a = Time(1, 2, 3, 4, 5);
      var b = Time(1, 2, 3, 4, 6);
      var c = Time(1, 2, 3, 5, 0);
      var d = Time(1, 2, 4);
      var e = Time(1, 3);

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(c), lessThan(0));
      expect(a.compareTo(d), lessThan(0));
      expect(a.compareTo(e), lessThan(0));
      expect(a.compareTo(Time(1, 2, 3, 4, 5)), equals(0));

      expect(a == Time(1, 2, 3, 4, 5), isTrue);
      expect(a.hashCode, equals(Time(1, 2, 3, 4, 5).hashCode));
      expect(a == b, isFalse);

      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(a <= Time(1, 2, 3, 4, 5), isTrue);
      expect(b > a, isTrue);
      expect(b >= a, isTrue);
      expect(a >= b, isFalse);
    });

    test('+ / -', () {
      var t = Time(10);

      expect(identical(t + null, t), isTrue);
      expect(identical(t + Duration.zero, t), isTrue);
      expect(t + 1000, equals(Time(10, 0, 1)));
      expect(t + Time(1, 30), equals(Time(11, 30)));
      expect(t + const Duration(minutes: 5), equals(Time(10, 5)));
      expect(() => t + 'x', throwsStateError);

      expect(identical(t - null, t), isTrue);
      expect(identical(t - Duration.zero, t), isTrue);
      expect(t - 1000, equals(Time(9, 59, 59)));
      expect(t - Time(1, 30), equals(Time(8, 30)));
      expect(t - const Duration(hours: 11), equals(Time(23)));
      expect(() => t - 'x', throwsStateError);
    });
  });

  group('OrderDirection', () {
    test('parse/resolve', () {
      expect(OrderDirection.parse(null), isNull);
      expect(OrderDirection.parse(''), isNull);
      expect(OrderDirection.parse('foo'), isNull);
      expect(OrderDirection.parse(' UP '), OrderDirection.ascending);
      expect(OrderDirection.parse('-'), OrderDirection.descending);
      expect(
        OrderDirection.parse(OrderDirection.descending),
        OrderDirection.descending,
      );
      expect(OrderDirection.resolve(null), OrderDirection.ascending);
      expect(OrderDirection.descending.sqlKeyword, 'DESC');
      expect(OrderDirection.ascending.sqlKeyword, 'ASC');
      expect(OrderDirection.resolveOrderByID(null, 10), isTrue);
      expect(OrderDirection.resolveOrderByID(false, 10), isFalse);
    });
  });

  group('EntityField', () {
    test('constructors and getters', () {
      const visible = EntityField.visible();
      expect(visible.isVisible, isTrue);
      expect(visible.isHidden, isFalse);

      const hidden = EntityField.hidden();
      expect(hidden.isHidden, isTrue);
      expect(hidden.isVisible, isFalse);

      const indexed = EntityField.indexed();
      expect(indexed.isIndexed, isTrue);
      expect(indexed.isUnique, isFalse);

      const min = EntityField.minimum(2);
      expect(min.minimum, equals(2));
      expect(min.maximum, isNull);

      const limits = EntityField.limits(2, 5);
      expect(limits.minimum, equals(2));
      expect(limits.maximum, equals(5));

      final validator = EntityField.validator((v) => v == 'ok');
      expect(validator.isValidValue('ok'), isTrue);
      expect(validator.isValidValue('no', fieldName: 'f'), isFalse);

      var invalid = validator.validateValue('no', fieldName: 'f');
      expect(invalid, isNotNull);
      expect(invalid!.reason, equals('validator'));
      expect(invalid.fieldName, equals('f'));
    });

    test('maximum validation', () {
      const max = EntityField.maximum(3);

      expect(max.isValidValue(3), isTrue);
      expect(max.isValidValue(4), isFalse);
      expect(max.isValidValue(3.5), isFalse);

      expect(max.isValidValue(BigInt.from(3)), isTrue);
      expect(max.isValidValue(BigInt.from(4)), isFalse);

      expect(max.isValidValue(DynamicInt.fromInt(3)), isTrue);
      expect(max.isValidValue(Decimal.parse('3.5')), isFalse);

      expect(max.isValidValue('abc'), isTrue);
      expect(max.isValidValue('abcd'), isFalse);

      expect(max.isValidValue([1, 2, 3]), isTrue);
      expect(max.isValidValue([1, 2, 3, 4]), isFalse);

      // Other types are not checked:
      expect(max.isValidValue(true), isTrue);
      expect(max.isValidValue(null), isTrue);

      var invalid = max.validateValue(
        'abcd',
        fieldName: 'name',
        entityType: String,
      );
      expect(invalid!.reason, equals('maximum(3)'));
      expect(invalid.entityType, equals(String));
    });

    test('minimum validation', () {
      const min = EntityField.minimum(2);

      expect(min.isValidValue(2), isTrue);
      expect(min.isValidValue(1), isFalse);
      expect(min.isValidValue(1.5), isFalse);

      expect(min.isValidValue(BigInt.from(2)), isTrue);
      expect(min.isValidValue(BigInt.from(1)), isFalse);

      expect(min.isValidValue(DynamicInt.fromInt(2)), isTrue);
      expect(min.isValidValue(Decimal.parse('1.5')), isFalse);

      expect(min.isValidValue('ab'), isTrue);
      expect(min.isValidValue('a'), isFalse);

      expect(min.isValidValue([1, 2]), isTrue);
      expect(min.isValidValue([1]), isFalse);

      var invalid = min.validateValue([1], fieldName: 'list');
      expect(invalid!.reason, equals('minimum(2)'));
    });

    test('regexp validation', () {
      const re = EntityField.regexp(r'^\d+$');
      expect(re.isValidValue('123'), isTrue);
      expect(re.isValidValue('12a'), isFalse);
      expect(re.isValidValue(null), isFalse);
      expect(re.validateValue('x')!.reason, equals(r'regexp(^\d+$)'));
    });

    test('Iterable<EntityAnnotation> extension', () {
      final annotations = <EntityAnnotation>[
        const EntityField.unique(),
        const EntityField.hidden(),
        const EntityField.limits(1, 10),
        const EntityField.regexp('x'),
        const EntityIndex(['a']),
      ];

      expect(annotations.entityFields.length, equals(4));
      expect(annotations.maximum, equals([10]));
      expect(annotations.minimum, equals([1]));
      expect(annotations.regexp, equals(['x']));
      expect(annotations.unique.length, equals(1));
      expect(annotations.hidden.length, equals(1));
      expect(annotations.visible.length, equals(3));
      expect(annotations.hasUnique, isTrue);
      expect(annotations.hasHidden, isTrue);
      expect(annotations.hasVisible, isTrue);

      final fields = annotations.entityFields;
      expect(fields.maximum, equals([10]));
      expect(fields.minimum, equals([1]));
      expect(fields.regexp, equals(['x']));
      expect(fields.unique.length, equals(1));
      expect(fields.hidden.length, equals(1));
      expect(fields.visible.length, equals(3));
      expect(fields.hasUnique, isTrue);
      expect(fields.hasIndexed, isFalse);
      expect(fields.hasHidden, isTrue);
      expect(fields.hasVisible, isTrue);

      final none = <EntityAnnotation>[];
      expect(none.hasUnique, isFalse);
      expect(none.hasHidden, isFalse);
      expect(none.hasVisible, isFalse);
    });
  });

  group('EntityFieldInvalid', () {
    test('copyWith', () {
      var e = EntityFieldInvalid('r', 1, fieldName: 'f', tableName: 't');
      var e2 = e.copyWith(
        reason: 'r2',
        value: 2,
        entityType: int,
        fieldsNames: ['a', 'b'],
      );
      expect(e2.reason, equals('r2'));
      expect(e2.value, equals(2));
      expect(e2.entityType, equals(int));
      expect(e2.fieldName, equals('f'));
      expect(e2.tableName, equals('t'));
      expect(e2.fieldsNames, equals(['a', 'b']));

      var e3 = e.copyWith();
      expect(e3.reason, equals('r'));
      expect(e3.value, equals(1));
    });

    test('toStringSimple / toString', () {
      var e = EntityFieldInvalid(
        'maximum(3)',
        'abcd',
        entityType: String,
        tableName: 'tab',
        fieldName: 'name',
      );

      expect(
        e.toStringSimple(),
        equals(
          'Invalid entity(String@table:tab) field(name)> reason: maximum(3)',
        ),
      );

      var e2 = EntityFieldInvalid('x', null);
      expect(e2.toStringSimple(), equals('Invalid entity field> reason: x'));

      var e3 = EntityFieldInvalid(
        'sub',
        'v',
        subEntityErrors: {'a': EntityFieldInvalid('inner', 1)},
        operation: ['op1', () => 'op2'],
        parentError: StateError('parent'),
      );

      var s = e3.toString();
      expect(s, contains('reason: sub'));
      expect(s, contains('reason: inner'));
      expect(s, contains('Operation>>'));
      expect(s, contains('op1'));
      expect(s, contains('op2'));
      expect(s, contains('Parent ERROR>>'));
      expect(s, contains('parent'));

      var e4 = EntityFieldInvalid(
        'rec',
        'v',
        operation: EntityFieldInvalid('op-invalid', 2),
      );
      expect(e4.toString(), contains('op-invalid'));
    });
  });

  group('RecursiveRelationshipLoopError', () {
    test('basic', () {
      var e = RecursiveRelationshipLoopError('loop!', entity: 'x');
      expect(e.runtimeTypeNameSafe, equals('RecursiveRelationshipLoopError'));
      expect(e.toString(), equals('RecursiveRelationshipLoopError: loop!'));
      expect(e.entity, equals('x'));
    });
  });

  group('EntityIndex', () {
    test('defaultName / indexName / equality', () {
      expect(EntityIndex.defaultName('t', ['a', 'b']), equals('t__a_b__idx'));
      expect(
        EntityIndex.defaultName('t', ['a'], unique: true),
        equals('t__a__unique'),
      );

      var long = EntityIndex.defaultName('a_very_long_table_name', [
        'first_column',
        'second_column',
      ], maxLength: 30);
      expect(long.length, lessThanOrEqualTo(30));
      expect(long, endsWith('__idx'));

      const idx = EntityIndex(['a'], name: 'my_index_name');
      expect(idx.indexName('t', ['a']), equals('my_index_name'));
      expect(
        () => idx.indexName('t', ['a'], maxLength: 5),
        throwsArgumentError,
      );

      expect(idx, equals(const EntityIndex(['a'], name: 'my_index_name')));
      expect(
        idx.hashCode,
        equals(const EntityIndex(['a'], name: 'my_index_name').hashCode),
      );
      expect(idx.toString(), equals('EntityIndex(a ; name: my_index_name)'));
      expect(
        const EntityIndex(['a', 'b'], unique: true).toString(),
        equals('EntityIndex(a, b ; unique)'),
      );
    });
  });
}
