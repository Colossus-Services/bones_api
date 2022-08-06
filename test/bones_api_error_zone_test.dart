import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('ZoneField', () {
    test('basic', () async {
      var errors = <StateError>[];

      var zone = createErrorZone(
          onUncaughtError: (e, s) => errors.add(e as StateError));

      zone.run(() => print('foo'));
      expect(errors, isEmpty);

      zone.run(() => Future.delayed(
          Duration(milliseconds: 1), () => throw StateError('e1')));

      await Future.delayed(Duration(milliseconds: 200), () => true);

      expect(errors.map((e) => e.message), equals(['e1']));
    });
  });

  group('ZoneField', () {
    test('basic', () {
      var zoneField = ZoneField<int>(Zone.current);

      var c1 = zoneField.createContextZone();
      var c2 = zoneField.createContextZone();

      expect(zoneField.get(), isNull);

      expect(zoneField.get(c1), isNull);
      expect(zoneField.get(c2), isNull);

      expect(zoneField.set(101, contextZone: c1), isNull);
      expect(zoneField.get(c1), equals(101));
      expect(zoneField.get(c2), isNull);

      expect(zoneField.set(102, contextZone: c1), equals(101));
      expect(zoneField.get(c1), equals(102));
      expect(zoneField.get(c2), isNull);

      expect(zoneField.set(201, contextZone: c2), isNull);
      expect(zoneField.get(c1), equals(102));
      expect(zoneField.get(c2), equals(201));

      expect(zoneField.set(202, contextZone: c2), equals(201));
      expect(zoneField.get(c1), equals(102));
      expect(zoneField.get(c2), equals(202));

      expect(zoneField.get(), isNull);
      c1.run(() {
        expect(zoneField.get(), equals(102));
      });

      zoneField.disposeContextZone(c1);
      expect(zoneField.get(c1), isNull);
    });
  });
}
