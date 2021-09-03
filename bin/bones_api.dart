import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:dart_spawner/dart_spawner.dart';

void _log(String ns, String message) {
  print('## [$ns]\t$message');
}

const String cliTitle = '[Bones_API/${APIRoot.VERSION}]';

void main(List<String> args) async {
  var commandRunner = CommandRunner<bool>('bones_api', '$cliTitle - CLI Tool')
    ..addCommand(CommandServe())
    ..addCommand(CommandConsole());

  commandRunner.argParser.addFlag('version',
      abbr: 'v', negatable: false, defaultsTo: false, help: 'Show version.');

  {
    var argsResult = commandRunner.argParser.parse(args);

    if (argsResult['version']) {
      showVersion();
      return;
    }
  }

  await commandRunner.run(args);
}

void showVersion() {
  print('Bones_API/${APIRoot.VERSION} - CLI Tool');
}

abstract class CommandSourceFileBase extends Command<bool> {
  final _argParser = ArgParser(allowTrailingOptions: false);

  @override
  ArgParser get argParser => _argParser;

  CommandSourceFileBase() {
    argParser.addFlag('verbose',
        abbr: 'v', help: 'Verbose mode', defaultsTo: false, negatable: false);

    argParser.addOption(
      'directory',
      abbr: 'd',
      help: 'Project directory.\n'
          '(defaults to current directory)',
    );
  }

  String? get argDirectory => argResults!['directory'];

  @override
  String get usage {
    var s = super.usage;
    return '$cliTitle\n\n($name) :: $s';
  }

  bool? _verbose;

  bool get verbose {
    _verbose ??= argResults!['verbose'] as bool;
    return _verbose!;
  }

  int get parametersStartIndex => 0;

  List<String>? _parameters;

  List<String> get parameters {
    if (_parameters == null) {
      var list = argResults!.rest;
      var startIndex = parametersStartIndex;
      if (list.length <= startIndex) return <String>[];
      _parameters = list.sublist(startIndex).toList();
    }
    return _parameters!;
  }

  String? getParameter(int index, [String? def]) {
    var params = parameters;
    return index < params.length ? params[index] : def;
  }

  String get sourceFilePath {
    var argResults = this.argResults!;

    if (argResults.rest.isEmpty) {
      throw StateError('Empty arguments: no source file path!');
    }

    return argResults.rest[0];
  }

  File get sourceFile => File(sourceFilePath);

  String get source => sourceFile.readAsStringSync();
}

class CommandServe extends CommandSourceFileBase {
  @override
  final String description = 'Serve an API';

  @override
  final String name = 'serve';

  CommandServe() {
    argParser.addOption('address',
        abbr: 'a',
        help: 'Server bind address',
        defaultsTo: 'localhost',
        valueHelp: 'localhost|*');

    argParser.addOption('port',
        abbr: 'p', help: 'Server listen port', defaultsTo: '8080');

    argParser.addOption('class', abbr: 'c', help: 'Project APIRoot Class name');

    argParser.addFlag('hotreload',
        abbr: 'r',
        help:
            'Runs APIServer with Hot Reload (spawns a Dart VM with `--enable-vm-service` if needed)');
  }

  String? get argClass => argResults!['class'];

  String get argAddress => argResults!['address']!;

  String get argPort => argResults!['port']!;

  bool get argHotReload => argResults!['hotreload']! as bool;

  @override
  FutureOr<bool> run() async {
    var directory = argDirectory;
    var apiRootClass = argClass;
    var address = argAddress;
    var port = argPort;
    var hotReload = argHotReload;

    var parametersMessage = <String>[];

    if (directory == null) {
      var filePubSpec = File('./pubspec.yaml').absolute;

      if (filePubSpec.existsSync()) {
        directory = Directory.current.absolute.path;
        parametersMessage
            .add('** Using current directory as Project directory.');
      }
    }

    var requiredParameters = <String>[];

    if (directory == null) {
      requiredParameters.add('--directory ./path/to/project');
    } else {
      directory = Directory(directory).absolute.path;
      if (directory.endsWith('/.')) {
        directory = directory.substring(0, directory.length - 2);
      }
    }

    if (apiRootClass == null) {
      requiredParameters.add('--class APIRootClassName');
    }

    if (requiredParameters.isNotEmpty) {
      print('[Bones_API/${APIRoot.VERSION}] :: CLI :: serve\n');

      if (parametersMessage.isNotEmpty) {
        for (var m in parametersMessage) {
          print(m);
        }
        print('');
      }

      print('** Required parameters:');
      for (var m in requiredParameters) {
        print('  $m');
      }

      print('\nTry --help for usage information.');
      return false;
    }

    var spawner = DartSpawner(directory: Directory(directory!));

    if (hotReload) {
      var hotReloadAllowed = await APIHotReload.get().isHotReloadAllowed();
      if (!hotReloadAllowed) {
        await _spawnDartVMForHotReload(spawner, directory, apiRootClass!,
            address, port, parametersMessage);
        return true;
      }
    }

    return await _spawnAPIServerIsolate(parametersMessage, directory,
        apiRootClass!, spawner, address, port, hotReload);
  }

  Future<bool> _spawnAPIServerIsolate(
      List<String> parametersMessage,
      String directory,
      String apiRootClass,
      DartSpawner spawner,
      String address,
      String port,
      bool hotReload) async {
    print(
        '________________________________________________________________________________');
    print('[Bones_API/${APIRoot.VERSION}] :: CLI :: serve\n');

    if (parametersMessage.isNotEmpty) {
      for (var m in parametersMessage) {
        print(m);
      }
      print('');
    }

    print('- Project directory: $directory');
    print('- API Class: $apiRootClass\n');

    print('Building API Server...');

    var projectBonesAPIVersions =
        spawner.getProjectDependencyVersion('bones_api');

    if (projectBonesAPIVersions == null) {
      throw StateError(
          'Target project (`${spawner.projectPackageName}`) is not using package `bones_api`: $directory');
    }

    var projectPackageName = (await spawner.projectPackageName)!;
    var projectLibraryName = (await spawner.projectLibraryName)!;

    var dartScript = buildDartScript(
        spawner.id, projectPackageName, projectLibraryName, apiRootClass);

    print('Spawning API Server Isolate...\n');

    String hotReloadIgnoreIsolate = '';
    if (hotReload) {
      hotReloadIgnoreIsolate =
          APIHotReload.get().getIsolateID(Isolate.current) ?? '';
    }

    var process = await spawner.spawnDartScript(
      dartScript,
      [address, port, '$hotReload', hotReloadIgnoreIsolate],
      usesSpawnedMain: true,
      debugName: apiRootClass,
    );

    var exit = await process.exitCode;

    await Future.delayed(Duration(milliseconds: 500));

    print(
        '________________________________________________________________________________');
    print('API Server exit: $exit');

    return true;
  }

  Future<void> _spawnDartVMForHotReload(
      DartSpawner spawner,
      String directory,
      String apiRootClass,
      String address,
      String port,
      List<String> parametersMessage) async {
    print(
        '________________________________________________________________________________');
    print('[Bones_API/${APIRoot.VERSION}]\n');

    if (parametersMessage.isNotEmpty) {
      for (var m in parametersMessage) {
        print(m);
      }
      print('');
    }

    print('Enabling Hot Reload...');
    print('Starting a Dart VM with `--enable-vm-service` for Hot Reload...');
    print(
        '================================================================================');

    var process = await spawner.runDartVM(
        'bones_api',
        [
          'serve',
          '--directory',
          directory,
          '--class',
          apiRootClass,
          '--address',
          address,
          '--port',
          port,
          '--hotreload',
        ],
        enableVMService: true,
        handleSignals: true,
        redirectOutput: true,
        onSignal: (s) => print('\n## SIGNAL: $s'));

    var exitCode = await process.exitCode;

    exit(exitCode);
  }

  String buildDartScript(int isolateID, String projectPackageName,
      String projectLibraryName, String apiRootClass) {
    var script = '''
import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/bones_api_dart_spawner.dart';

import 'package:$projectPackageName/$projectLibraryName.dart';

void main(List<String> args, dynamic parentPort) {
  spawnedMain(args, parentPort, $isolateID, (args) async {
    print('________________________________________________________________________________');
    print('[Bones_API/${APIRoot.VERSION}] :: HTTP Server\\n');
    print('- API Package: $projectPackageName/$projectLibraryName');
    print('- API Class: $apiRootClass');
    
    var address = args[0];
    var port = int.parse(args[1]);
    var hotReload = args[2] == 'true';
    var hotReloadIgnoreIsolate = args[3]; 
    
    print('- API Server: \$address:\$port\\n');
    
    if (hotReloadIgnoreIsolate.isNotEmpty) {
      print('Adding Isolate ID `\$hotReloadIgnoreIsolate` to Hot Reload ignore list...');
      APIHotReload.get().ignoreIsolate(hotReloadIgnoreIsolate);
    }
    
    print('Starting APIServer...\\n');
    
    var api = $apiRootClass();
    
    var apiServer = APIServer(api, address, port, hotReload: hotReload);
    await apiServer.start();
    
    print('\\n** APIServer Started.\\n');
    
    print('\$apiServer\\n');
    print('URL: \${ apiServer.url }');
    print('________________________________________________________________________________');
    
    await apiServer.waitStopped();
  });
}
    ''';

    return script;
  }
}

class CommandConsole extends CommandSourceFileBase {
  @override
  final String description = 'API Console';

  @override
  final String name = 'console';

  CommandConsole() {
    argParser.addOption('class',
        abbr: 'c', help: 'Project APIRoot Class name', defaultsTo: 'API');
  }

  String? get argClass => argResults!['class'];

  @override
  FutureOr<bool> run() async {
    var directory = argDirectory;
    var apiRootClass = argClass;

    if (directory == null) {
      throw ArgumentError.notNull('directory');
    }

    if (apiRootClass == null) {
      throw ArgumentError.notNull('apiRootClass');
    }

    if (verbose) {
      _log('CONSOLE', 'directory: $directory ; apiRootClass: $apiRootClass');
    }

    var spawner = DartSpawner(directory: Directory(directory));

    var projectBonesAPIVersions =
        spawner.getProjectDependencyVersion('bones_api');

    if (projectBonesAPIVersions == null) {
      throw StateError(
          'Target project (`${spawner.projectPackageName}`) is not using package `bones_api`: $directory');
    }

    var projectPackageName = (await spawner.projectPackageName)!;
    var projectLibraryName = (await spawner.projectLibraryName)!;

    var dartScript = buildDartScript(
        spawner.id, projectPackageName, projectLibraryName, apiRootClass);

    var process = await spawner.spawnDartScript(
      dartScript,
      [],
      usesSpawnedMain: true,
      debugName: apiRootClass,
    );

    var exit = await process.exitCode;

    print('Console exit: $exit');

    return true;
  }

  String buildDartScript(int isolateID, String projectPackageName,
      String projectLibraryName, String apiRootClass) {
    var script = '''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bones_api/bones_api_console.dart';
import 'package:bones_api/bones_api_dart_spawner.dart';

import 'package:$projectPackageName/$projectLibraryName.dart';

Stream<String> _stdinLineStreamBroadcaster = stdin
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .asBroadcastStream();

Future<String> _readStdinLine() async {
  stdout.write('CMD> ');
  
  var lineCompleter = Completer<String>();

  var listener = _stdinLineStreamBroadcaster.listen((line) {
    if (!lineCompleter.isCompleted) {
      lineCompleter.complete(line);
    }
  });

  return lineCompleter.future.then((line) {
    listener.cancel();
    return line;
  });
}

void _onRequest(APIRequest request) {
  print('>> REQUEST: \$request');
}

void _onResponse(APIResponse response) {
  print('>> RESPONSE: \${response.toInfos()}\\n\$response');
}

void main(List<String> args, dynamic parentPort) {
  spawnedMain(args, parentPort, $isolateID, (args) async {
    var api = $apiRootClass();
    
    var apiConsole = APIConsole(api);
    
    await Future.delayed(Duration(milliseconds: 100));
    
    print('------------------------------------------------------------------');
    print('- API Package: $projectPackageName/$projectLibraryName');
    print('- API Class: $apiRootClass\\n');
    
    print('Running \$apiConsole\\n');
    
    await apiConsole.run(_readStdinLine, onRequest: _onRequest, onResponse: _onResponse);
  });
}
    ''';

    return script;
  }
}
