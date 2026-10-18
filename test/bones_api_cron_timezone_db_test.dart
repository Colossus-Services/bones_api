// The time zones database is global: these tests run in their own file, in
// order, from an empty database.
@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_default;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('Cron time zones database', () {
    test('a database loaded by the application is kept', () {
      expect(tz.timeZoneDatabase.locations, isEmpty);

      // The application loads the `timezone` default database (no aliases):
      tz_default.initializeTimeZones();
      var count = tz.timeZoneDatabase.locations.length;
      expect(tz.timeZoneDatabase.locations.containsKey('Europe/Oslo'), isFalse);

      initializeCronTimeZones();
      expect(tz.timeZoneDatabase.locations.length, count, reason: 'Kept');

      expect(resolveCronTimeZone('Europe/Paris').name, 'Europe/Paris');
      expect(tz.timeZoneDatabase.locations.length, count, reason: 'Kept');
    });

    test('an alias loads the full database (a superset)', () {
      var count = tz.timeZoneDatabase.locations.length;

      expect(resolveCronTimeZone('Europe/Oslo').name, 'Europe/Oslo');
      expect(resolveCronTimeZone('GMT').name, 'GMT');
      expect(
        resolveCronTimeZone('Atlantic/Reykjavik').name,
        'Atlantic/Reykjavik',
      );

      expect(tz.timeZoneDatabase.locations.length, greaterThan(count));

      // The names of the previous database keep resolving (for the
      // application too):
      expect(tz.getLocation('Europe/Paris').name, 'Europe/Paris');
      expect(tz.getLocation('America/Sao_Paulo').name, 'America/Sao_Paulo');
    });

    test('an unknown time zone: ArgumentError', () {
      expect(() => resolveCronTimeZone('Mars/Olympus'), throwsArgumentError);
    });

    test('a cron job with an alias time zone', () {
      var job = APICronJob(
        name: 'oslo',
        schedule: '30 23 * * *',
        path: '/m/r',
        timeZone: 'Europe/Oslo',
      );
      job.validate();
      // Oslo is CET/CEST like Paris: 23:30 = 21:30Z in summer.
      expect(
        job.nextAfter(DateTime.utc(2026, 7, 10))!.toUtc(),
        DateTime.utc(2026, 7, 10, 21, 30),
      );
    });
  });
}
