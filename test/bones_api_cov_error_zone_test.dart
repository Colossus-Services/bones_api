@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorZone (coverage)', () {
    test('runGuardedAsync: error', () async {
      var zone = createErrorZone(onUncaughtError: (e, s) {});

      var r = await zone.runGuardedAsync(() => 123);
      expect(r, equals(123));

      await expectLater(
        zone.runGuardedAsync<int>(() => throw StateError('guarded-error')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'guarded-error',
          ),
        ),
      );
    });

    test('createErrorZone: default handler (print)', () async {
      var printed = <String>[];

      var printZone = Zone.current.fork(
        specification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      var zone = createErrorZone(
        uncaughtErrorTitle: 'COV-TITLE:',
        printErrorToStderr: false,
        parentZone: printZone,
      );

      zone.run(() {
        scheduleMicrotask(() => throw StateError('cov-uncaught'));
      });

      await Future.delayed(Duration(milliseconds: 20));

      expect(printed.length, equals(1));
      var out = printed.first;
      expect(out, contains('COV-TITLE:'));
      expect(out, contains('Bad state: cov-uncaught'));
      expect(out, contains('StackTrace:'));
    });

    test('printZoneError', () {
      var printed = <String>[];

      runZoned(
        () {
          printZoneError(
            StateError('e1'),
            StackTrace.current,
            title: 'T1',
            message: 'extra-message',
            printErrorToStderr: false,
          );
          printZoneError(
            StateError('e2'),
            StackTrace.current,
            printErrorToStderr: false,
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(printed.length, equals(2));
      expect(printed[0], contains('T1\n\n'));
      expect(printed[0], contains('extra-message'));
      expect(printed[0], contains('-----'));
      expect(printed[1], isNot(contains('-----')));
      expect(printed[1], contains('Bad state: e2'));

      // To STDERR:
      printZoneError(
        StateError('[printZoneError coverage]'),
        StackTrace.empty,
        title: '[COVERAGE]',
      );
    });
  });

  group('ZoneField (coverage)', () {
    test('set / get / remove', () {
      var zoneField = ZoneField<String>(Zone.current);

      var z1 = zoneField.createContextZone();
      var z2 = zoneField.createContextZone(zoneValues: {'k': 'v'});

      expect(zoneField.set('a', contextZone: z1), isNull);
      expect(zoneField.set('b', contextZone: z2), isNull);
      expect(zoneField.get(z1), equals('a'));
      expect(zoneField.get(z2), equals('b'));

      expect(z2.run(() => zoneField.get()), equals('b'));
      expect(z2.run(() => zoneField.contextZone), same(z2));
      expect(z2['k'], equals('v'));

      expect(zoneField.remove(contextZone: z1), equals('a'));
      expect(zoneField.get(z1), isNull);

      // Dispose a zone that is not the last one:
      zoneField.set('a2', contextZone: z1);
      zoneField.disposeContextZone(z1);
      expect(zoneField.get(z1), isNull);
      expect(zoneField.get(z2), equals('b'));

      zoneField.disposeContextZone(z2);
      expect(zoneField.get(z2), isNull);

      // Dispose with no registered zones:
      zoneField.disposeContextZone(z2);
      expect(zoneField.get(z2), isNull);
    });

    test('createSafeContextZone', () async {
      var zoneField = ZoneField<String>(Zone.current);

      expect(
        () => zoneField.createSafeContextZone(),
        throwsA(isA<ArgumentError>()),
      );

      var errors = <Object>[];
      var zone = zoneField.createSafeContextZone(
        handleUncaughtError: (e, s) => errors.add(e),
        zoneValues: {'x': 1},
      );

      expect(zone['x'], equals(1));

      zone.run(() {
        scheduleMicrotask(() => throw StateError('safe-zone-error'));
      });

      await Future.delayed(Duration(milliseconds: 20));

      expect(errors.length, equals(1));
      expect(errors.first, isA<StateError>());

      zoneField.disposeContextZone(zone);
    });
  });
}
