import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/src/bones_api_isolate.dart';

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
        abbr: 'c', help: 'APIRoot Class name', defaultsTo: 'API');
  }

  String get mainFunction => argResults!['function'] ?? 'main';

  List<String> get parameters {
    var list = argResults!.rest;
    if (list.length <= 1) return <String>[];
    return list.sublist(1).toList();
  }

  @override
  FutureOr<bool> run() async {
    var parameters = this.parameters;

    if (verbose) {
      _log('SERVE', '$sourceFile > $mainFunction( $parameters )');
    }

    var directory = argResults!['directory'];
    var address = argResults!['address'];
    var port = argResults!['port'];
    var apiRootClass = argResults!['class'];

    var isolateSpawner = IsolateSpawner(directory);

    var projectBonesAPIVersions =
        isolateSpawner.getProjectDependencyVersion('bones_api');

    if (projectBonesAPIVersions == null) {
      throw StateError(
          'Target project (`${isolateSpawner.projectPackageName}`) is not using package `bones_api`: $directory');
    }

    var dartScript = buildDartScript(
        isolateSpawner.id,
        isolateSpawner.projectPackageName!,
        isolateSpawner.projectLibraryName!,
        apiRootClass);

    var process = await isolateSpawner.spawnDartScript(
      dartScript,
      [address, port],
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
  spawnMain(args, parentPort, $isolateID, () async {
    var address = args[0];
    var port = int.parse(args[1]); 
    
    var api = $apiRootClass();
    
    var apiServer = APIServer(api, address, port);
    await apiServer.start();
    
    print('Running \$apiServer');
    print('URL: \${ apiServer.url }');
  });
}
    ''';

    return script;
  }
}
