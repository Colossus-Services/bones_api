import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:dart_spawner/dart_spawner.dart';

void _log(String ns, String message) {
  print('## [$ns]\t$message');
}

const String cliTitle = '[Bones_API/${APIServer.VERSION}]';

void main(List<String> args) async {
  var commandRunner = CommandRunner<bool>('bones_api', '$cliTitle - CLI Tool')
    ..addCommand(CommandServe());

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
  print('Bones_API/${APIServer.VERSION} - CLI Tool');
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

    argParser.addOption('class',
        abbr: 'c', help: 'Project APIRoot Class name', defaultsTo: 'API');
  }

  String? get argDirectory => argResults!['directory'];

  String? get argClass => argResults!['class'];

  String get argAddress => argResults!['address']!;

  String get argPort => argResults!['port']!;

  @override
  FutureOr<bool> run() async {
    var directory = argDirectory;
    var apiRootClass = argClass;
    var address = argAddress;
    var port = argPort;

    if (directory == null) {
      throw ArgumentError.notNull('directory');
    }

    if (apiRootClass == null) {
      throw ArgumentError.notNull('apiRootClass');
    }

    if (verbose) {
      _log('SERVE',
          'directory: $directory ; apiRootClass: $apiRootClass ; address: $address ; port: $port');
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
      [address, port],
      usesSpawnedMain: true,
      debugName: apiRootClass,
    );

    var exit = await process.exitCode;

    print('Serve exit: $exit');

    return true;
  }

  String buildDartScript(int isolateID, String projectPackageName,
      String projectLibraryName, String apiRootClass) {
    var script = '''
import 'package:bones_api/bones_api_server.dart';
import 'package:$projectPackageName/$projectLibraryName.dart';

void main(List<String> args, dynamic parentPort) {
  spawnedMain(args, parentPort, $isolateID, (args) async {
    var address = args[0];
    var port = int.parse(args[1]); 
    
    var api = $apiRootClass();
    
    var apiServer = APIServer(api, address, port);
    await apiServer.start();
    
    print('------------------------------------------------------------------');
    print('- API Package: $projectPackageName/$projectLibraryName');
    print('- API Class: $apiRootClass\\n');
    print('Running \$apiServer');
    print('URL: \${ apiServer.url }');
    
    await apiServer.waitStopped();
  });
}
    ''';

    return script;
  }
}
