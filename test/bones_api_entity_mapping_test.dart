import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
  group('parseDateTimeISOUTCFast', () {
    test('the same as DateTime.parse for toUtc().toIso8601String()', () {
      var dates = [
        DateTime.utc(2026, 10, 13, 12, 34, 56),
        DateTime.utc(2026, 10, 13, 12, 34, 56, 789),
        DateTime.utc(2026, 10, 13, 12, 34, 56, 789, 123),
        DateTime.utc(2026, 10, 13, 12, 34, 56, 0, 1),
        DateTime.utc(1970),
        DateTime.utc(1999, 12, 31, 23, 59, 59, 999, 999),
        DateTime.utc(2024, 2, 29, 0, 0, 0, 5),
        DateTime(2026, 7, 1, 8, 15, 30, 250).toUtc(),
      ];

      for (var d in dates) {
        var s = d.toUtc().toIso8601String();
        var fast = parseDateTimeISOUTCFast(s);
        expect(fast, equals(DateTime.parse(s)), reason: s);
        expect(fast!.isUtc, isTrue, reason: s);
        expect(fast.microsecondsSinceEpoch, d.microsecondsSinceEpoch);
      }
    });

    test('fraction digits and the space separator', () {
      for (var s in [
        '2026-10-13T12:34:56.5Z',
        '2026-10-13T12:34:56.05Z',
        '2026-10-13T12:34:56.123Z',
        '2026-10-13T12:34:56.1234Z',
        '2026-10-13T12:34:56.12345Z',
        '2026-10-13T12:34:56.123456Z',
        '2026-10-13 12:34:56.123Z',
        '2026-10-13 12:34:56Z',
      ]) {
        expect(
          parseDateTimeISOUTCFast(s),
          equals(DateTime.parse(s)),
          reason: s,
        );
      }
    });

    test('other formats: null (parsed the usual way)', () {
      for (var s in [
        '2026-10-13T12:34:56', // Local time.
        '2026-10-13T12:34:56.123', // Local time.
        '2026-10-13T12:34:56+01:00', // An offset.
        '2026-10-13T12:34:56.1234567Z', // 7 fraction digits.
        '2026-10-13T12:34:56.Z', // No fraction digits.
        '2026-10-13', // A date only.
        '20261013T123456Z', // Basic format.
        '2026-10-13T12:34:5aZ', // Not a digit.
        '2026/10/13T12:34:56Z',
        ' 2026-10-13T12:34:56Z',
        '',
      ]) {
        expect(parseDateTimeISOUTCFast(s), isNull, reason: s);
      }
    });

    test('resolveValueByType(DateTime): the fast path and the fallback', () {
      var handler = Address$reflection().entityHandler;
      var t = TypeInfo<DateTime>.fromType(DateTime);

      var utc = '2026-10-13T12:34:56.789123Z';
      expect(handler.resolveValueByType(t, utc), equals(DateTime.parse(utc)));

      var local = '2026-10-13T12:34:56.789';
      expect(
        handler.resolveValueByType(t, local),
        equals(DateTime.parse(local)),
      );
    });
  });

  group('createFromMap: the keys of the fields per map layout', () {
    // The same handler, maps with different keys: each layout resolved on its
    // own (not reusing the previous one).
    void check(EntityHandler<Address> handler) {
      Map<String, Object?> base(Object id) => {
        'id': id,
        'state': 'NY',
        'city': 'New York',
        'street': 'Main St',
        'number': 10,
      };

      Future<void> expectAddress(
        Map<String, Object?> map, {
        required int id,
        String state = 'NY',
      }) async {
        var a = await handler.createFromMap(map);
        expect(a.id, equals(id));
        expect(a.state, equals(state));
        expect(a.city, equals('New York'));
        expect(a.street, equals('Main St'));
        expect(a.number, equals(10));
      }

      test('the same layout, repeated', () async {
        for (var i = 1; i <= 3; ++i) {
          await expectAddress(base(i), id: i);
        }
      });

      test('another order, another case, another layout', () async {
        await expectAddress(base(1), id: 1);

        // Upper case keys (a case insensitive match):
        await expectAddress(
          {
            'ID': 2,
            'STATE': 'CA',
            'CITY': 'New York',
            'STREET': 'Main St',
            'NUMBER': 10,
          },
          id: 2,
          state: 'CA',
        );

        // Another order:
        await expectAddress(
          {
            'number': 10,
            'street': 'Main St',
            'city': 'New York',
            'state': 'TX',
            'id': 3,
          },
          id: 3,
          state: 'TX',
        );

        // Back to the first layout:
        await expectAddress(base(4), id: 4);
      });

      test('a missing field and an extra key', () async {
        await expectAddress(base(1), id: 1);

        // Without `id` (another layout): no ID.
        var noID = Map<String, Object?>.from(base(0))..remove('id');
        var a = await handler.createFromMap(noID);
        expect(a.id, isNull);
        expect(a.state, equals('NY'));

        // An extra key (not a field), then the base layout again:
        await expectAddress({...base(5), 'extra': 'x'}, id: 5);
        await expectAddress(base(6), id: 6);
      });
    }

    group('reflection', () => check(Address$reflection().entityHandler));

    group(
      'generic',
      () => check(addressEntityHandler..inspectObject(Address.empty())),
    );
  });
}
