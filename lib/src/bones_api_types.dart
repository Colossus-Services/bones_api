import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_utils.dart';

/// A [Time] represents the time of the day,
/// independently of the day of the year, timezone or [DateTime].
class Time implements Comparable<Time> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    JsonDecoder.registerTypeDecoder(Time, (o, d, t) => Time.from(o));
  }

  int hour;
  int minute = 0;
  int second = 0;
  int millisecond = 0;
  int microsecond = 0;

  Time(this.hour,
      [this.minute = 0,
      this.second = 0,
      this.millisecond = 0,
      this.microsecond = 0]) {
    if (hour < 0 || hour > 24) {
      throw ArgumentError.value(hour, 'hour', 'Not in range: 0..24');
    }

    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Not in range: 0..59');
    }

    if (second < 0 || second > 59) {
      throw ArgumentError.value(second, 'second', 'Not in range: 0..59');
    }

    if (millisecond < 0 || millisecond > 1000) {
      throw ArgumentError.value(
          millisecond, 'millisecond', 'Not in range: 0..999');
    }

    if (microsecond < 0 || microsecond > 1000) {
      throw ArgumentError.value(
          microsecond, 'microsecond', 'Not in range: 0..999');
    }
  }

  /// Creates a [Time] instance from [duration].
  factory Time.fromDuration(Duration duration) {
    var h = duration.inHours;
    var m = duration.inMinutes - Duration(hours: h).inMinutes;
    var s = duration.inSeconds - Duration(hours: h, minutes: m).inSeconds;
    var ms = duration.inMilliseconds -
        Duration(hours: h, minutes: m, seconds: s).inMilliseconds;
    var mic = duration.inMicroseconds -
        Duration(hours: h, minutes: m, seconds: s, milliseconds: ms)
            .inMicroseconds;
    return Time(h, m, s, ms, mic);
  }

  /// Creates a [Time] instance from [dateTime].
  factory Time.fromDateTime(DateTime dateTime) {
    var h = dateTime.hour;
    var m = dateTime.minute;
    var s = dateTime.second;
    var ms = dateTime.millisecond;
    var mic = dateTime.microsecond;
    return Time(h, m, s, ms, mic);
  }

  /// Creates a [Time] period instance from a total [microseconds].
  factory Time.fromMicroseconds(int microseconds) {
    return Time.fromDuration(Duration(microseconds: microseconds));
  }

  /// Creates a [Time] period instance from a total [milliseconds].
  factory Time.fromMilliseconds(int milliseconds) {
    return Time.fromDuration(Duration(milliseconds: milliseconds));
  }

  /// Creates a [Time] period instance from a total [seconds].
  factory Time.fromSeconds(int seconds) {
    return Time.fromDuration(Duration(seconds: seconds));
  }

  /// Creates a [Time] period instance from a total [minutes].
  factory Time.fromMinutes(int minutes) {
    return Time.fromDuration(Duration(minutes: minutes));
  }

  static final int _char0 = '0'.codeUnitAt(0);
  static final int _char9 = '9'.codeUnitAt(0);
  static final int _charColon = ':'.codeUnitAt(0);
  static final int _charDot = '.'.codeUnitAt(0);

  static bool _isDigitByte(int b) {
    return b >= _char0 && b <= _char9;
  }

  static bool _bytesInStringFormat(List<int> value) {
    if (value.isEmpty) return false;

    if (!_isDigitByte(value[0])) return false;
    if (value.length < 2 && !_isDigitByte(value[1])) return false;

    if (value.length == 8 &&
        value[2] == _charColon &&
        value[5] == _charColon &&
        _isDigitByte(value[3]) &&
        _isDigitByte(value[4]) &&
        _isDigitByte(value[6]) &&
        _isDigitByte(value[7])) {
      return true;
    } else if (value.length >= 10 &&
        value[2] == _charColon &&
        value[5] == _charColon &&
        value[8] == _charDot &&
        _isDigitByte(value[3]) &&
        _isDigitByte(value[4]) &&
        _isDigitByte(value[6]) &&
        _isDigitByte(value[7]) &&
        _isDigitByte(value[9])) {
      for (var i = 10; i < value.length; ++i) {
        if (!_isDigitByte(value[i])) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  /// Parses [bytes] to [Time]. See [toBytes32] and [toBytes64].
  factory Time.fromBytes(List<int> bytes, {bool allowParseString = true}) {
    if (bytes.length == 4) {
      var milliseconds = bytes.asUint8List.getInt32(0);
      if (milliseconds >= 0) {
        var time = Time.fromMilliseconds(milliseconds);
        return time;
      }
    } else if (bytes.length >= 8 && !_bytesInStringFormat(bytes)) {
      var microseconds = bytes.asUint8List.getInt64();
      if (microseconds >= 0) {
        var time = Time.fromMicroseconds(microseconds);
        return time;
      }
    } else if (allowParseString) {
      try {
        var s = String.fromCharCodes(bytes);
        return Time.parse(s, allowFromBytes: false);
      } catch (_) {
        throw FormatException(
            'Invalid bytes or string format: ${bytes.runtimeTypeNameUnsafe}:${bytes.toList()}');
      }
    }

    throw FormatException(
        'Invalid bytes format: ${bytes.runtimeTypeNameUnsafe}:${bytes.toList()}');
  }

  /// Parses [s] to [Time].
  factory Time.parse(String s, {bool allowFromBytes = true}) {
    s = s.trim();
    if (s.isEmpty) {
      throw FormatException('Invalid `Time` format: $s');
    }

    var idx1 = s.indexOf(':');
    var idx2 = s.indexOf('.');

    if (idx1 != 2 || (idx2 > 0 && idx2 < idx1)) {
      if (allowFromBytes) {
        var bs = _string2bytes(s);
        return Time.fromBytes(bs, allowParseString: false);
      }

      throw FormatException('Invalid `Time` format: $s');
    }

    int ms = 0;
    int mic = 0;

    String hmsStr;
    if (idx2 >= 0) {
      hmsStr = s.substring(0, idx2).trim();
      var msMicStr = s.substring(idx2 + 1).trim();

      if (msMicStr.length <= 3) {
        ms = int.parse(msMicStr);
      } else {
        var msEnd = msMicStr.length - 3;
        var msStr = msMicStr.substring(0, msEnd);
        var micStr = msMicStr.substring(msEnd);

        ms = int.parse(msStr);
        mic = int.parse(micStr);
      }
    } else {
      hmsStr = s;
    }

    var parts = hmsStr.split(':');

    var hStr = parts[0].trim();
    var mStr = (parts.length > 1 ? parts[1] : '0').trim();
    var secStr = (parts.length > 2 ? parts[2] : '0').trim();

    var h = int.parse(hStr);
    var m = int.parse(mStr);
    var sec = int.parse(secStr);

    return Time(h, m, sec, ms, mic);
  }

  static Uint8List _string2bytes(String s) {
    try {
      return dart_convert.utf8.encode(s).asUint8List;
    } catch (_) {
      try {
        return dart_convert.latin1.encode(s);
      } catch (_) {
        return s.codeUnits.asUint8List;
      }
    }
  }

  static Time? from(Object? o) {
    if (o == null) return null;
    if (o is Time) return o;

    if (o is Duration) return Time.fromDuration(o);
    if (o is DateTime) return Time.fromDateTime(o);
    if (o is List<int>) return Time.fromBytes(o);

    if (o is int) return Time.fromMilliseconds(o);

    if (o is Map) {
      return Time(
        TypeParser.parseInt(o['hour'], 0)!,
        TypeParser.parseInt(o['minute'], 0)!,
        TypeParser.parseInt(o['second'], 0)!,
        TypeParser.parseInt(o['millisecond'], 0)!,
        TypeParser.parseInt(o['microsecond'], 0)!,
      );
    }

    return Time.parse(o.toString());
  }

  /// Converts this to 64-bits bytes ([Uint8List]), encoding [totalMicrosecond].
  Uint8List toBytes64() {
    var bytes = Uint8List(8);
    bytes.setUint64(totalMicrosecond, 0);
    return bytes;
  }

  /// Converts this to 32-bits bytes ([Uint8List]), encoding [totalMilliseconds].
  Uint8List toBytes32() {
    var bytes = Uint8List(4);
    bytes.setInt32(totalMilliseconds, 0);
    return bytes;
  }

  @override
  String toString(
      {bool withSeconds = true, bool? withMillisecond, bool? withMicrosecond}) {
    var h = _intToPaddedString(hour);
    var m = _intToPaddedString(minute);
    var s = _intToPaddedString(second);

    withMillisecond ??= millisecond != 0;
    if (withMillisecond) {
      var ms = _intToPaddedString(millisecond, 3);

      withMicrosecond ??= microsecond != 0;
      if (withMicrosecond) {
        var mic = _intToPaddedString(microsecond, 3);
        return '$h:$m:$s.$ms$mic';
      } else {
        return '$h:$m:$s.$ms';
      }
    } else if (!withSeconds) {
      return '$h:$m';
    } else {
      return '$h:$m:$s';
    }
  }

  static String _intToPaddedString(int n, [int padding = 2]) =>
      n.toString().padLeft(padding, '0');

  /// Creates a new [Time] from this one by updating individual properties.
  Time copyWith(
          {int? hour,
          int? minute,
          int? second,
          int? millisecond,
          int? microsecond}) =>
      Time(hour ?? this.hour, minute ?? this.minute, second ?? this.second,
          millisecond ?? this.millisecond, microsecond ?? this.microsecond);

  /// Converts this [Time] to [DateTime].
  DateTime toDateTime(int year,
          [int month = 1, int day = 1, bool utc = true]) =>
      utc
          ? DateTime.utc(
              year, month, day, hour, minute, second, millisecond, microsecond)
          : DateTime(
              year, month, day, hour, minute, second, millisecond, microsecond);

  /// Returns the total minutes of this [Time] period.
  int get totalMinutes => (hour * 60) + minute;

  /// Returns the total seconds of this [Time] period.
  int get totalSeconds => (totalMinutes * 60) + second;

  /// Returns the total milliseconds of this [Time] period.
  int get totalMilliseconds => (totalSeconds * 1000) + millisecond;

  /// Returns the total microsecond of this [Time] period.
  int get totalMicrosecond => (totalMilliseconds * 1000) + microsecond;

  /// Converts `this` instance to [Duration].
  Duration get asDuration => Duration(
      hours: hour,
      minutes: minute,
      seconds: second,
      milliseconds: millisecond,
      microseconds: microsecond);

  @override
  int compareTo(Time other) {
    var cmp = hour.compareTo(other.hour);
    if (cmp == 0) {
      cmp = minute.compareTo(other.minute);
      if (cmp == 0) {
        cmp = second.compareTo(other.second);
        if (cmp == 0) {
          cmp = millisecond.compareTo(other.millisecond);
          if (cmp == 0) {
            cmp = microsecond.compareTo(other.microsecond);
          }
        }
      }
    }
    return cmp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Time &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute &&
          second == other.second &&
          millisecond == other.millisecond &&
          microsecond == other.microsecond;

  @override
  int get hashCode =>
      hour.hashCode ^
      minute.hashCode ^
      second.hashCode ^
      millisecond.hashCode ^
      microsecond.hashCode;

  operator <(Time other) => totalMicrosecond < other.totalMicrosecond;

  operator <=(Time other) => totalMicrosecond <= other.totalMicrosecond;

  operator >(Time other) => totalMicrosecond > other.totalMicrosecond;

  operator >=(Time other) => totalMicrosecond >= other.totalMicrosecond;
}

extension DateTimeToTimeExtension on DateTime {
  Time toTime({
    bool withMinute = true,
    bool withSecond = true,
    bool withMillisecond = true,
    bool withMicrosecond = true,
  }) =>
      Time(
        hour,
        withMinute ? minute : 0,
        withSecond ? second : 0,
        withMillisecond ? millisecond : 0,
        withMicrosecond ? microsecond : 0,
      );
}
