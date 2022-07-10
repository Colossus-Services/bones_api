import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class Foo {
  int id;

  String name;

  Foo(this.id, this.name);

  @override
  String toString() {
    return '#$id[$name]';
  }
}

void main() {
  group('Types', () {
    setUp(() {});

    test('TypeInfo', () async {
      var t1 = TypeInfo(List);
      var t2 = TypeInfo(List);

      expect(t1.type, equals(t2.type));

      var t3 = TypeInfo.from([]);
      expect(t3.type, equals(t1.type));
      expect(t3.isFuture, isFalse);
      expect(t3.isFutureOr, isFalse);
      expect(t3.isDynamic, isFalse);

      var fieldRolesType = User.empty().getFieldType('roles')!;

      expect(fieldRolesType.type, equals(t1.type));

      var t4 = TypeInfo.from([Role.empty()], [Role.empty()]);
      expect(t4.isFuture, isFalse);
      expect(t4.isFutureOr, isFalse);
      expect(t4.isDynamic, isFalse);
      expect(fieldRolesType.type, equals(t4.type));
      expect(fieldRolesType, equals(t4));

      var t5 = TypeInfo.fromType(Future, [bool]);
      expect(t5.isFuture, isTrue);
      expect(t5.isFutureOr, isFalse);
      expect(t5.isDynamic, isFalse);
      expect(t5.arguments[0], equals(TypeInfo.tBool));

      var t6 = TypeInfo.fromType(FutureOr, [bool]);
      expect(t6.isFutureOr, isTrue);
      expect(t6.isFuture, isFalse);
      expect(t6.arguments[0], equals(TypeInfo.tBool));

      var t7 = TypeInfo.fromType(Future, [bool]);
      expect(t7.isFuture, isTrue);
      expect(t7.isFutureOr, isFalse);
      expect(t7.arguments[0], equals(TypeInfo.tBool));

      var t8 = TypeInfo.fromType(Future);
      expect(t8.isFuture, isTrue);
      expect(t8.isFutureOr, isFalse);
      expect(t8.hasArguments, isFalse);
    });

    test('Time', () async {
      _testTime(Time(1, 2, 3), '01:02:03');

      _testTime(Time(20, 11, 31), '20:11:31');
      _testTime(Time(20, 11, 31), '20:11:31.000', withMillisecond: true);
      _testTime(Time(20, 11, 31), '20:11:31.000000',
          withMillisecond: true, withMicrosecond: true);

      _testTime(Time(20, 11, 31, 123), '20:11:31.123');

      _testTime(Time(20, 11, 31, 123), '20:11:31.123');
      _testTime(Time(20, 11, 31, 12), '20:11:31.012');

      _testTime(Time(20, 11, 31, 123, 456), '20:11:31.123456');
      _testTime(Time(20, 11, 31, 12, 456), '20:11:31.012456');

      expect(Time(20, 11, 31).toDateTime(2020, 1, 2, false),
          equals(DateTime(2020, 1, 2, 20, 11, 31)));
      expect(Time(20, 11, 31).toDateTime(2020, 1, 2, true),
          equals(DateTime.utc(2020, 1, 2, 20, 11, 31)));

      expect(Time.fromMinutes(120), equals(Time(2)));
      expect(Time.fromMinutes(120 + 30), equals(Time(2, 30)));

      expect(Time.fromSeconds((60 * 60) * 3), equals(Time(3)));
      expect(Time.fromSeconds((60 * 60) * 3 + (60 * 15) + (31)),
          equals(Time(3, 15, 31)));

      expect(Time.fromMilliseconds((1000 * 60 * 60) * 5), equals(Time(5)));
      expect(
          Time.fromMilliseconds(
              (1000 * 60 * 60) * 5 + (1000 * 60 * 11) + (1000 * 20) + 123),
          equals(Time(5, 11, 20, 123)));

      expect(
          Time.fromMicroseconds((1000 * 1000 * 60 * 60) * 7), equals(Time(7)));
      expect(
          Time.fromMicroseconds((1000 * 1000 * 60 * 60) * 7 +
              (1000 * 1000 * 60 * 12) +
              (1000 * 1000 * 13) +
              (1000 * 321) +
              654),
          equals(Time(7, 12, 13, 321, 654)));

      expect(Time(20, 11, 31).asDuration,
          equals(Duration(hours: 20, minutes: 11, seconds: 31)));
      expect(
          Time(20, 11, 31, 123, 456).asDuration,
          equals(Duration(
              hours: 20,
              minutes: 11,
              seconds: 31,
              milliseconds: 123,
              microseconds: 456)));

      expect(Time(20, 11, 31).totalSeconds,
          equals(Duration(hours: 20, minutes: 11, seconds: 31).inSeconds));
      expect(
          Time(20, 11, 31, 123).totalMilliseconds,
          equals(
              Duration(hours: 20, minutes: 11, seconds: 31, milliseconds: 123)
                  .inMilliseconds));
      expect(
          Time(20, 11, 31, 123, 456).totalMicrosecond,
          equals(Duration(
                  hours: 20,
                  minutes: 11,
                  seconds: 31,
                  milliseconds: 123,
                  microseconds: 456)
              .inMicroseconds));

      _testTimeLessThan(Time(20, 11, 31), Time(21, 11, 31), false);
      _testTimeLessThan(Time(21, 10, 31), Time(21, 11, 31), false);
      _testTimeLessThan(Time(21, 11, 30), Time(21, 11, 31), false);
      _testTimeLessThan(Time(21, 11, 31, 90), Time(21, 11, 31, 100), false);
      _testTimeLessThan(
          Time(21, 11, 31, 100, 90), Time(21, 11, 31, 100, 100), false);

      _testTimeLessThan(Time(20, 11, 31), Time(20, 11, 31), true);

      var times = [Time(20, 11, 31), Time(14, 11, 31), Time(12, 11, 31)];
      times.sort();
      expect(times.map((t) => '$t').join(' '),
          equals('12:11:31 14:11:31 20:11:31'));

      expect(Time.fromBytes(Time(21, 11, 31, 100, 90).toBytes64()),
          equals(Time(21, 11, 31, 100, 90)));

      expect(Time.fromBytes(Time(23, 59, 59, 999).toBytes64()),
          equals(Time(23, 59, 59, 999)));

      expect(Time.fromBytes(Time(21, 11, 31, 100).toBytes32()),
          equals(Time(21, 11, 31, 100)));

      expect(Time.fromBytes(Time(23, 59, 59, 999).toBytes32()),
          equals(Time(23, 59, 59, 999)));
    });
  });
}

void _testTimeLessThan(Time t1, Time t2, bool expectEquals) {
  if (expectEquals) {
    expect(t1, equals(t2));
    expect(t1, lessThanOrEqualTo(t2));
    expect(t2, greaterThanOrEqualTo(t1));
  } else {
    expect(t1, lessThan(t2));
    expect(t1, lessThanOrEqualTo(t2));
    expect(t2, greaterThan(t1));
    expect(t2, greaterThanOrEqualTo(t1));
  }
}

void _testTime(Time t, String ts,
    {bool withSeconds = true, bool? withMillisecond, bool? withMicrosecond}) {
  expect(
      t.toString(
          withSeconds: withSeconds,
          withMillisecond: withMillisecond,
          withMicrosecond: withMicrosecond),
      equals(ts));
  expect(Time.parse(ts), equals(t));
}

class AB {
  final int a;

  final int b;

  AB(this.a, this.b);

  AB.fromMap(Map<String, dynamic> o) : this(o['a'], o['b']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AB &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;

  @override
  String toString() => 'AB{a: $a, b: $b}';
}
