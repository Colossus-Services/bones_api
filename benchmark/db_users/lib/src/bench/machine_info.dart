import 'dart:io';

/// The machine a benchmark ran on, so recorded results can be compared only
/// with results from comparable hardware.
class MachineInfo {
  /// A free-form label given by `--machine` (e.g. "MacBook Pro M3 Max",
  /// "AWS c7g.xlarge"), since host names are rarely informative.
  final String? label;

  final String os;
  final String osVersion;
  final String? cpu;
  final int cores;
  final int? memoryBytes;
  final String dartVersion;

  MachineInfo._(
    this.label,
    this.os,
    this.osVersion,
    this.cpu,
    this.cores,
    this.memoryBytes,
    this.dartVersion,
  );

  factory MachineInfo.detect({String? label}) => MachineInfo._(
    label,
    Platform.operatingSystem,
    Platform.operatingSystemVersion,
    _detectCPU(),
    Platform.numberOfProcessors,
    _detectMemory(),
    Platform.version.split(' ').first,
  );

  String get memory => memoryBytes == null
      ? '?'
      : '${(memoryBytes! / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';

  Map<String, Object?> toJson() => {
    'label': label,
    'os': os,
    'osVersion': osVersion,
    'cpu': cpu,
    'cores': cores,
    'memoryBytes': memoryBytes,
    'dartVersion': dartVersion,
  };

  @override
  String toString() =>
      '${label != null ? '$label: ' : ''}${cpu ?? '?'}, $cores cores, '
      '$memory RAM, $os ($osVersion), Dart $dartVersion';

  static String? _detectCPU() {
    if (Platform.isMacOS) {
      return _run('sysctl', ['-n', 'machdep.cpu.brand_string']);
    } else if (Platform.isLinux) {
      var line = _readLines(
        '/proc/cpuinfo',
      )?.where((l) => l.startsWith('model name')).firstOrNull;
      return line?.split(':').skip(1).join(':').trim();
    }
    return null;
  }

  static int? _detectMemory() {
    if (Platform.isMacOS) {
      return int.tryParse(_run('sysctl', ['-n', 'hw.memsize']) ?? '');
    } else if (Platform.isLinux) {
      var line = _readLines(
        '/proc/meminfo',
      )?.where((l) => l.startsWith('MemTotal:')).firstOrNull;
      var kb = int.tryParse(line?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
      return kb != null ? kb * 1024 : null;
    }
    return null;
  }

  static String? _run(String executable, List<String> args) {
    try {
      var result = Process.runSync(executable, args);
      if (result.exitCode != 0) return null;
      var out = '${result.stdout}'.trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static List<String>? _readLines(String path) {
    try {
      return File(path).readAsLinesSync();
    } catch (_) {
      return null;
    }
  }

  /// The current `git` commit (short hash), if run inside a checkout.
  static String? gitCommit() {
    var hash = _run('git', ['rev-parse', '--short', 'HEAD']);
    if (hash == null) return null;
    var dirty = _run('git', ['status', '--porcelain']) != null;
    return dirty ? '$hash (modified)' : hash;
  }
}
