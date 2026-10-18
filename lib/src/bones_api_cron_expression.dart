// The full database (with the links/aliases, like `GMT` or `Europe/Oslo`,
// not in the `timezone` default one: `data/latest.dart`).
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _fullDatabaseLoaded = false;

void _loadFullDatabase() {
  if (_fullDatabaseLoaded) return;
  _fullDatabaseLoaded = true;
  tz_data.initializeTimeZones();
}

/// Ensures a time zones database is loaded, needed by [CronExpression] with
/// a time zone other than `UTC`: the full one if none is loaded yet. A
/// database already loaded (e.g. by the application) is kept.
void initializeCronTimeZones() {
  if (tz.timeZoneDatabase.locations.isEmpty) _loadFullDatabase();
}

/// Returns the [tz.Location] of [timeZone] (an IANA name, like
/// `Europe/Paris`). `null`, empty or `UTC`: [tz.UTC].
///
/// A name not in the database loaded (e.g. an alias, not in the `timezone`
/// default database) loads the full database (a superset: the names already
/// resolved, here or by the application, keep resolving) and is tried again.
///
/// Throws an [ArgumentError] for an unknown time zone.
tz.Location resolveCronTimeZone(String? timeZone) {
  timeZone = timeZone?.trim();
  if (timeZone == null ||
      timeZone.isEmpty ||
      timeZone.toUpperCase() == 'UTC' ||
      timeZone.toUpperCase() == 'Z') {
    return tz.UTC;
  }

  initializeCronTimeZones();

  try {
    return tz.getLocation(timeZone);
  } on tz.LocationNotFoundException {
    if (!_fullDatabaseLoaded) {
      _loadFullDatabase();
      return resolveCronTimeZone(timeZone);
    }
    throw ArgumentError.value(timeZone, 'timeZone', 'Unknown time zone');
  }
}

/// A standard 5 fields cron expression: `minute hour day-of-month month
/// day-of-week`.
///
/// - Each field accepts `*`, values, lists (`1,15`), ranges (`1-5`) and
///   steps (`*/15`, `0-30/10`, `5/10`).
/// - Months accept names (`JAN`-`DEC`) and days of week names
///   (`SUN`-`SAT`); day of week `0` and `7` are Sunday.
/// - When both day of month and day of week are restricted (not `*`), a day
///   matches if any of them matches (standard cron behavior).
/// - Macros: `@yearly` (`@annually`), `@monthly`, `@weekly`, `@daily`
///   (`@midnight`) and `@hourly`.
///
/// The times are matched in the wall clock of a time zone ([nextAfter],
/// [previousBefore]): a time that doesn't exist (a daylight saving gap) runs
/// at the first valid instant after it, and a repeated time (the clock set
/// back) runs only once.
class CronExpression {
  static const Map<String, String> _macros = {
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
    '@monthly': '0 0 1 * *',
    '@weekly': '0 0 * * 0',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@hourly': '0 * * * *',
  };

  static const List<String> _monthsNames = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static const List<String> _daysNames = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  /// The expression, as given.
  final String expression;

  final Set<int> minutes;
  final Set<int> hours;
  final Set<int> daysOfMonth;
  final Set<int> months;

  /// Days of week: `0` (Sunday) to `6` (Saturday).
  final Set<int> daysOfWeek;

  final bool _anyDayOfMonth;
  final bool _anyDayOfWeek;

  CronExpression._(
    this.expression,
    this.minutes,
    this.hours,
    this.daysOfMonth,
    this.months,
    this.daysOfWeek,
    this._anyDayOfMonth,
    this._anyDayOfWeek,
  );

  /// Parses [expression]. Throws a [FormatException] if invalid.
  factory CronExpression.parse(String expression) {
    var expr = expression.trim();
    expr = _macros[expr.toLowerCase()] ?? expr;

    var fields = expr.split(RegExp(r'\s+'));
    if (fields.length != 5) {
      throw FormatException(
        'Invalid cron expression (5 fields expected): $expression',
      );
    }

    try {
      var minutes = _parseField(fields[0], 0, 59);
      var hours = _parseField(fields[1], 0, 23);
      var daysOfMonth = _parseField(fields[2], 1, 31);
      var months = _parseField(fields[3], 1, 12, names: _monthsNames);
      var daysOfWeek = _parseField(
        fields[4],
        0,
        7,
        names: _daysNames,
      ).map((d) => d == 7 ? 0 : d).toSet();

      return CronExpression._(
        expression,
        minutes,
        hours,
        daysOfMonth,
        months,
        daysOfWeek,
        _isAny(fields[2]),
        _isAny(fields[4]),
      );
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid cron expression `$expression`: ${e.message}',
      );
    }
  }

  /// Parses [expression], or returns `null` if invalid.
  static CronExpression? tryParse(String? expression) {
    if (expression == null) return null;
    try {
      return CronExpression.parse(expression);
    } on FormatException {
      return null;
    }
  }

  static bool _isAny(String field) => field == '*' || field == '?';

  static Set<int> _parseField(
    String field,
    int min,
    int max, {
    List<String>? names,
  }) {
    var values = <int>{};

    for (var part in field.split(',')) {
      part = part.trim();
      if (part.isEmpty) throw FormatException('Empty element in `$field`');

      var step = 1;
      var slash = part.indexOf('/');
      if (slash >= 0) {
        step = int.tryParse(part.substring(slash + 1)) ?? 0;
        if (step <= 0) throw FormatException('Invalid step in `$part`');
        part = part.substring(0, slash);
      }

      int from, to;
      if (part == '*' || part == '?') {
        from = min;
        to = max;
      } else {
        var dash = part.indexOf('-', 1);
        if (dash > 0) {
          from = _parseValue(part.substring(0, dash), min, max, names);
          to = _parseValue(part.substring(dash + 1), min, max, names);
          if (to < from) throw FormatException('Invalid range `$part`');
        } else {
          from = _parseValue(part, min, max, names);
          // `5/10`: from 5 to the max.
          to = slash >= 0 ? max : from;
        }
      }

      for (var v = from; v <= to; v += step) {
        values.add(v);
      }
    }

    return values;
  }

  static int _parseValue(String s, int min, int max, List<String>? names) {
    s = s.trim();

    int? v = int.tryParse(s);
    if (v == null && names != null) {
      var idx = names.indexOf(s.toUpperCase());
      if (idx >= 0) {
        // Months are 1-based, days of week 0-based:
        v = min == 1 ? idx + 1 : idx;
      }
    }

    if (v == null) throw FormatException('Invalid value `$s`');
    if (v < min || v > max) {
      throw FormatException('Value out of range [$min..$max]: $v');
    }
    return v;
  }

  bool _matchesDay(DateTime wall) {
    var dom = daysOfMonth.contains(wall.day);
    var dow = daysOfWeek.contains(wall.weekday % 7);

    if (_anyDayOfMonth && _anyDayOfWeek) return true;
    if (_anyDayOfMonth) return dow;
    if (_anyDayOfWeek) return dom;
    return dom || dow;
  }

  /// Returns `true` if the wall clock time [wall] (its fields; seconds are
  /// ignored) matches this expression.
  bool matches(DateTime wall) =>
      months.contains(wall.month) &&
      _matchesDay(wall) &&
      hours.contains(wall.hour) &&
      minutes.contains(wall.minute);

  /// The maximum wall clock span searched by [nextAfter] and
  /// [previousBefore] (an expression like `0 0 30 2 *` never matches).
  static const int maxSearchYears = 5;

  static DateTime _wallOf(DateTime instant, tz.Location location) {
    var t = tz.TZDateTime.from(instant, location);
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  static tz.TZDateTime _instantOf(DateTime wall, tz.Location location) =>
      tz.TZDateTime(
        location,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      );

  /// The next time after [from] (exclusive) that matches this expression in
  /// [location] (default `UTC`), or `null` if none in [maxSearchYears].
  tz.TZDateTime? nextAfter(DateTime from, [tz.Location? location]) {
    location ??= tz.UTC;

    var wall = _wallOf(from, location);
    // The next minute (seconds truncated):
    var cursor = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    ).add(const Duration(minutes: 1));

    var limit = DateTime.utc(wall.year + maxSearchYears, wall.month);

    while (cursor.isBefore(limit)) {
      var next = _nextWallMatch(cursor, limit);
      if (next == null) return null;

      var instant = _instantOf(next, location);
      // A repeated wall time (clock set back): the instant chosen may be
      // before `from`, already passed.
      if (instant.isAfter(from)) return instant;

      cursor = next.add(const Duration(minutes: 1));
    }

    return null;
  }

  DateTime? _nextWallMatch(DateTime cursor, DateTime limit) {
    var c = cursor;
    while (c.isBefore(limit)) {
      if (!months.contains(c.month)) {
        c = DateTime.utc(c.year, c.month + 1, 1);
        continue;
      }
      if (!_matchesDay(c)) {
        c = DateTime.utc(c.year, c.month, c.day + 1);
        continue;
      }
      if (!hours.contains(c.hour)) {
        c = DateTime.utc(c.year, c.month, c.day, c.hour + 1);
        continue;
      }
      if (!minutes.contains(c.minute)) {
        c = DateTime.utc(c.year, c.month, c.day, c.hour, c.minute + 1);
        continue;
      }
      return c;
    }
    return null;
  }

  /// The latest time not after [to] (inclusive) that matches this
  /// expression in [location] (default `UTC`), or `null` if none in
  /// [maxSearchYears].
  tz.TZDateTime? previousBefore(DateTime to, [tz.Location? location]) {
    location ??= tz.UTC;

    var wall = _wallOf(to, location);
    var cursor = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    );

    var limit = DateTime.utc(wall.year - maxSearchYears, wall.month);

    while (cursor.isAfter(limit)) {
      var prev = _previousWallMatch(cursor, limit);
      if (prev == null) return null;

      var instant = _instantOf(prev, location);
      if (!instant.isAfter(to)) return instant;

      cursor = prev.subtract(const Duration(minutes: 1));
    }

    return null;
  }

  DateTime? _previousWallMatch(DateTime cursor, DateTime limit) {
    var c = cursor;
    while (c.isAfter(limit)) {
      if (!months.contains(c.month)) {
        // The last minute of the previous month:
        c = DateTime.utc(
          c.year,
          c.month,
          1,
        ).subtract(const Duration(minutes: 1));
        continue;
      }
      if (!_matchesDay(c)) {
        c = DateTime.utc(
          c.year,
          c.month,
          c.day,
        ).subtract(const Duration(minutes: 1));
        continue;
      }
      if (!hours.contains(c.hour)) {
        c = DateTime.utc(
          c.year,
          c.month,
          c.day,
          c.hour,
        ).subtract(const Duration(minutes: 1));
        continue;
      }
      if (!minutes.contains(c.minute)) {
        c = c.subtract(const Duration(minutes: 1));
        continue;
      }
      return c;
    }
    return null;
  }

  @override
  String toString() => expression;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CronExpression && expression == other.expression;

  @override
  int get hashCode => expression.hashCode;
}
