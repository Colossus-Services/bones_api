import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:yaml/yaml.dart';

/// Class capable to spawn a Dart script into an [Isolate].
class IsolateSpawner {
  static int _idCounter = 0;

  final int id = ++_idCounter;

  /// The project directory of the spawned Dart script.
  final String? directory;

  IsolateSpawner([this.directory]);

  Directory? _projectDirectory;

  /// The resolved project [Directory].
  Directory? get projectDirectory {
    _projectDirectory ??= directory != null
        ? Directory(directory!).absolute
        : Directory.current.absolute;
    return _projectDirectory;
  }

  /// The resolved project `pubspec.yaml` [file].
  File get projectPubSpecFile =>
      File.fromUri(projectDirectory!.uri.resolve('pubspec.yaml'));

  Map<String, dynamic>? _pubSpec;

  /// The resolved project `pubspec.yaml` [Map].
  Map<String, dynamic> get projectPubSpec {
    if (_pubSpec == null) {
      final file = projectPubSpecFile;
      if (!file.existsSync()) {
        throw StateError(
            "Failed to locate 'pubspec.yaml' in project directory '${projectDirectory!.path}'");
      }
      var yamlContents = file.readAsStringSync();
      final yaml = loadYaml(yamlContents) as YamlMap;
      _pubSpec = yaml.cast<String, dynamic>();
    }

    return _pubSpec!;
  }

  Map<String, dynamic>? _projectLockFile;

  /// The resolved project `pubspec.lock` file as [YamlMap].
  Map<String, dynamic> get projectLockFile {
    if (_projectLockFile == null) {
      var lockFile =
          File.fromUri(projectDirectory!.uri.resolve('pubspec.lock'));
      if (!lockFile.existsSync()) {
        throw StateError('No pubspec.lock file. Run `pub get`.');
      }
      final yaml = loadYaml(lockFile.readAsStringSync()) as YamlMap;
      _projectLockFile = yaml.cast<String, dynamic>();
    }
    return _projectLockFile!;
  }

  /// Returns the version string of [package] at the target project dependencies.
  String? getProjectDependencyVersion(String package) {
    final ver = projectLockFile['packages'][package]?['version'] as String?;
    return ver;
  }

  /// The resolved project library name.
  String? get projectLibraryName => projectPackageName;

  /// The resolved project package name.
  String? get projectPackageName => projectPubSpec['name'] as String?;

  /// The resolved project `.packages` [Uri].
  Uri get projectPackageConfigUri => projectDirectory!.uri.resolve('.packages');

  /// The exit code of the spawned Dart script.
  final Completer<int> exitCode = Completer<int>();

  bool _spawned = false;

  /// Returns `true` if this instance already have spawned a script.
  bool get isSpawned => _spawned;

  Future<StoppableProcess> spawnDartScript(String dartScript, List<String> args,
      {bool shouldRunObservatory = false}) async {
    if (_spawned) {
      throw StateError('This instance can only can spawn 1 script!');
    }
    _spawned = true;

    final dataUri = Uri.parse(
        'data:application/dart;charset=utf-8,${Uri.encodeComponent(dartScript)}');

    final startupCompleter = Completer<SendPort>();

    var errorPort = ReceivePort();
    var messagePort = ReceivePort();

    errorPort.listen((msg) {
      if (msg is List) {
        startupCompleter.completeError(
            msg.first as Object, StackTrace.fromString(msg.last as String));
      }
    });

    late Isolate isolate;

    messagePort.listen((msg) {
      final message = msg as Map<dynamic, dynamic>;
      switch (message['status'] as String?) {
        case 'ok':
          {
            startupCompleter.complete(message['port'] as SendPort?);
          }
          break;
        case 'stopped':
          {
            exitCode.complete(0);
            messagePort.close();
            errorPort.close();

            Future.delayed(Duration(seconds: 1), () => isolate.kill());
          }
      }
    });

    isolate = await Isolate.spawnUri(dataUri, args, messagePort.sendPort,
        errorsAreFatal: true,
        onError: errorPort.sendPort,
        packageConfig: projectPackageConfigUri);

    if (shouldRunObservatory) {
      final observatory = await Service.controlWebServer(enable: true);
      if (await supportsLaunchObservatory()) {
        await launchObservatory(observatory.serverUri.toString());
      }
    }

    final sendPort =
        await startupCompleter.future.timeout(Duration(seconds: 45));

    final process = StoppableProcess((reason) async {
      sendPort.send({'command': 'stop'});
    });

    return process;
  }

  bool? _supportsLaunchObservatory;

  /// Returns `true` if this environment supports observatory launch.
  Future<bool> supportsLaunchObservatory() async {
    if (_supportsLaunchObservatory == null) {
      var locator = Platform.isWindows ? 'where' : 'which';
      var result = await Process.run(locator, ['open']);
      _supportsLaunchObservatory = result.exitCode == 0;
    }
    return _supportsLaunchObservatory!;
  }

  /// Launches the observatory [url].
  Future<ProcessResult> launchObservatory(String url) {
    return Process.run('open', [url]);
  }
}

typedef _StopProcess = Future Function(String reason);

/// The spawned Dart script isolate "process".
class StoppableProcess {
  StoppableProcess(Future Function(String reason) onStop) : _stop = onStop {
    var l1 = ProcessSignal.sigint.watch().listen((_) {
      stop(0, reason: 'Process interrupted.');
    });
    _listeners.add(l1);

    if (!Platform.isWindows) {
      var l2 = ProcessSignal.sigterm.watch().listen((_) {
        stop(0, reason: 'Process terminated by OS.');
      });
      _listeners.add(l2);
    }
  }

  /// The process exit code.
  Future<int> get exitCode => _completer.future;

  final List<StreamSubscription> _listeners = [];

  final _StopProcess _stop;
  final Completer<int> _completer = Completer<int>();

  /// Stops the process.
  Future stop(int exitCode, {String? reason}) async {
    if (_completer.isCompleted) {
      return;
    }

    await Future.forEach(_listeners, (StreamSubscription sub) => sub.cancel());
    await _stop(reason ?? 'Terminated normally.');

    _completer.complete(exitCode);
  }
}

/// Helper to executed a spawned Dart script by [IsolateSpawner].
void spawnMain(List<String> args, SendPort parentPort, int id,
    FutureOr<void> Function() run,
    [FutureOr<bool> Function()? stop]) {
  final port = ReceivePort();

  var isolateId = Isolate.current.debugName;
  isolateId = isolateId != null ? 'Isolate#$id($isolateId)' : 'Isolate#$id';

  port.listen((msg) async {
    if (msg['command'] == 'stop') {
      print('[$isolateId] Stopping isolate...');
      port.close();

      if (stop != null) {
        print('[$isolateId] triggering stop()');
        var stopOk = await stop();
        print('[$isolateId] stop(): $stopOk');
      }

      print('[$isolateId] Isolate stopped.');
      parentPort.send({'status': 'stopped'});
    }
  });

  run();

  parentPort.send({'status': 'ok', 'port': port.sendPort});
}
