import 'dart:convert';

import 'machine_info.dart';
import 'runner.dart';

/// A benchmark run: its setup, the machine it ran on, and its results.
class BenchReport {
  final DateTime date;
  final String bonesAPIVersion;
  final String? gitCommit;
  final MachineInfo machine;

  /// `memory`, `sqlite` or `postgres`.
  final String db;

  /// Details of the DB (server version, file, container...).
  final String dbDetails;

  final int users;
  final Duration duration;
  final Duration warmup;
  final List<BenchResult> results;

  BenchReport({
    required this.bonesAPIVersion,
    required this.gitCommit,
    required this.machine,
    required this.db,
    required this.dbDetails,
    required this.users,
    required this.duration,
    required this.warmup,
    required this.results,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  String get _dateStr => date.toIso8601String().substring(0, 10);

  String get _durationStr =>
      '${_seconds(duration)}s (warm-up ${_seconds(warmup)}s)';

  static String _seconds(Duration d) {
    var s = d.inMilliseconds / 1000;
    return s == s.roundToDouble() ? s.toStringAsFixed(0) : '$s';
  }

  String get header =>
      '''
bones_api: $bonesAPIVersion${gitCommit != null ? ' @ $gitCommit' : ''}
machine:   $machine
db:        $db ($dbDetails)
users:     $users
duration:  $_durationStr per operation''';

  /// A fixed-width table for the console.
  String toTable() {
    var nameWidth = [
      'OPERATION'.length,
      ...results.map((r) => r.name.length),
    ].reduce((a, b) => a > b ? a : b);

    String row(List<String> cols) =>
        '${cols[0].padRight(nameWidth)}'
        '${cols.skip(1).map((c) => c.padLeft(10)).join('  ')}';

    var s = StringBuffer()
      ..writeln(
        row([
          'OPERATION',
          ' OPS/SEC',
          'MEAN(us)',
          'P50(us)',
          'P95(us)',
          'P99(us)',
        ]),
      )
      ..writeln('-' * (nameWidth + 5 * 12 - 2));

    for (var r in results) {
      s.writeln(
        row([
          r.name,
          r.opsPerSecond.toStringAsFixed(0),
          r.meanMicroseconds.toStringAsFixed(1),
          '${r.p50}',
          '${r.p95}',
          '${r.p99}',
        ]),
      );
    }

    return s.toString();
  }

  /// A `HISTORY.md` entry, ready to paste.
  String toMarkdown() {
    var s = StringBuffer()
      ..writeln(
        '### $_dateStr — `$db` — ${machine.label ?? machine.cpu ?? machine.os}',
      )
      ..writeln()
      ..writeln(
        '- **bones_api:** $bonesAPIVersion'
        '${gitCommit != null ? ' (`$gitCommit`)' : ''}',
      )
      ..writeln(
        '- **Machine:** ${machine.label != null ? '${machine.label}, ' : ''}'
        '${machine.cpu ?? '?'}, ${machine.cores} cores, ${machine.memory} RAM',
      )
      ..writeln('- **OS:** ${machine.os} (${machine.osVersion})')
      ..writeln('- **Dart:** ${machine.dartVersion}')
      ..writeln('- **DB:** $db ($dbDetails)')
      ..writeln(
        '- **Users:** $users; **duration:** $_durationStr per operation',
      )
      ..writeln()
      ..writeln(
        '| Operation | ops/sec | mean (us) | p50 (us) | p95 (us) | p99 (us) |',
      )
      ..writeln('|---|--:|--:|--:|--:|--:|');

    for (var r in results) {
      s.writeln(
        '| `${r.name}` | ${r.opsPerSecond.toStringAsFixed(0)} '
        '| ${r.meanMicroseconds.toStringAsFixed(1)} '
        '| ${r.p50} | ${r.p95} | ${r.p99} |',
      );
    }

    return s.toString();
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'bonesAPIVersion': bonesAPIVersion,
    'gitCommit': gitCommit,
    'machine': machine.toJson(),
    'db': db,
    'dbDetails': dbDetails,
    'users': users,
    'durationMs': duration.inMilliseconds,
    'warmupMs': warmup.inMilliseconds,
    'results': results.map((r) => r.toJson()).toList(),
  };

  String toJsonEncoded() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}
