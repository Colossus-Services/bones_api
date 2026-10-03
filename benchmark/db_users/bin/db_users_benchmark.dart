import 'dart:io';

import 'package:args/args.dart';
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:bones_api/bones_api_test_postgres.dart';
import 'package:bones_api_db_users_benchmark/db_users_api.dart';
import 'package:bones_api_db_users_benchmark/src/bench/machine_info.dart';
import 'package:bones_api_db_users_benchmark/src/bench/report.dart';
import 'package:bones_api_db_users_benchmark/src/bench/runner.dart';

/// Benchmarks the Users API (`UsersAPIRoot`) against a memory, SQLite or
/// PostgreSQL database. See `README.md`.
Future<void> main(List<String> args) async {
  var parser = _buildArgParser();

  ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }

  if (opts.flag('help')) {
    print('dart run bin/db_users_benchmark.dart [options]\n\n${parser.usage}');
    exit(0);
  }

  var db = opts.option('db')!;
  var users = int.parse(opts.option('users')!);
  var ops = opts.multiOption('ops');

  var runner = BenchRunner(
    duration: _parseDuration(opts.option('duration')!),
    warmup: _parseDuration(opts.option('warmup')!),
  );

  var setup = await _DBSetup.create(db, opts);

  UsersAPIRoot? api;
  var exitCode = 0;

  try {
    api = UsersAPIRoot(apiConfig: {'db': setup.dbConfig});
    await api.ensureInitialized();

    var dbDetails = await setup.details(api);

    print('** Users API benchmark: $db ($dbDetails)');

    var bench = _UsersBench(api, users);
    await bench.reset();
    await bench.seed();

    for (var op in _operations) {
      if (ops.isNotEmpty && !ops.contains(op)) continue;
      await bench.run(runner, op);
    }

    var report = BenchReport(
      bonesAPIVersion: BonesAPI.VERSION,
      gitCommit: MachineInfo.gitCommit(),
      machine: MachineInfo.detect(label: opts.option('machine')),
      db: db,
      dbDetails: dbDetails,
      users: users,
      duration: runner.duration,
      warmup: runner.warmup,
      results: runner.results,
    );

    print('\n${report.header}\n');
    print(report.toTable());

    if (opts.flag('markdown')) {
      print(report.toMarkdown());
    }

    var jsonFile = opts.option('json');
    if (jsonFile != null) {
      File(jsonFile).writeAsStringSync(report.toJsonEncoded());
      print('** Results saved to: $jsonFile');
    }
  } catch (e, s) {
    stderr.writeln('** Benchmark failed: $e\n$s');
    exitCode = 1;
  } finally {
    api?.close();
    await setup.close();
  }

  // An initialized `APIRoot` keeps the isolate alive (shared stores, timers).
  exit(exitCode);
}

/// The measured operations, in run order: reads first, then the writes that
/// change the table size.
const _operations = [
  'byId',
  'byEmail',
  'byState',
  'list',
  'count',
  'login',
  'register',
  'update',
  'remove',
];

ArgParser _buildArgParser() => ArgParser()
  ..addOption(
    'db',
    allowed: ['memory', 'sqlite', 'postgres'],
    defaultsTo: 'memory',
    help: 'The database to run against.',
  )
  ..addOption(
    'users',
    defaultsTo: '1000',
    help: 'Users registered before measuring.',
  )
  ..addOption(
    'duration',
    defaultsTo: '3s',
    help: 'Measured time per operation (e.g. `3s`, `500ms`).',
  )
  ..addOption(
    'warmup',
    defaultsTo: '1s',
    help: 'Unmeasured time per operation before measuring.',
  )
  ..addMultiOption(
    'ops',
    allowed: _operations,
    help: 'Operations to run (default: all).',
  )
  ..addOption(
    'sqlite-path',
    help:
        'SQLite database file, or `:memory:` '
        '(default: a temporary file, deleted at the end).',
  )
  ..addOption('pg-host', help: 'PostgreSQL host (env: PGHOST).')
  ..addOption('pg-port', help: 'PostgreSQL port (env: PGPORT).')
  ..addOption('pg-user', help: 'PostgreSQL user (env: PGUSER).')
  ..addOption('pg-password', help: 'PostgreSQL password (env: PGPASSWORD).')
  ..addOption('pg-database', help: 'PostgreSQL database (env: PGDATABASE).')
  ..addFlag(
    'docker',
    negatable: false,
    help: 'Start a throwaway PostgreSQL container (removed at the end).',
  )
  ..addOption(
    'pg-version',
    defaultsTo: 'latest',
    help:
        'PostgreSQL image tag for `--docker` '
        '(the report records the actual server version).',
  )
  ..addOption(
    'machine',
    help: 'A label for the machine (e.g. "MacBook Pro M3 Max").',
  )
  ..addFlag(
    'markdown',
    negatable: false,
    help: 'Print a HISTORY.md entry for this run.',
  )
  ..addOption('json', help: 'Save the results as JSON to this file.')
  ..addFlag('help', abbr: 'h', negatable: false);

Duration _parseDuration(String s) {
  s = s.trim();
  if (s.endsWith('ms')) {
    return Duration(milliseconds: int.parse(s.substring(0, s.length - 2)));
  }
  var seconds = double.parse(
    s.endsWith('s') ? s.substring(0, s.length - 1) : s,
  );
  return Duration(milliseconds: (seconds * 1000).round());
}

/// The users workload, driven through the API: every operation is a full
/// `APIRoot.call` (routing, parameter binding, security, repository, DB).
class _UsersBench {
  static const roles = ['admin', 'editor', 'viewer'];

  static const states = [
    'CA',
    'FL',
    'IL',
    'MA',
    'NY',
    'OH',
    'PA',
    'TX',
    'WA',
    'GA',
  ];

  final UsersAPIRoot api;
  final int users;

  final List<int> _userIds = [];

  _UsersBench(this.api, this.users);

  ModuleUser get _moduleUser => api.getModule('user') as ModuleUser;

  /// Removes the rows of a previous run (a persistent DB server).
  Future<void> reset() async {
    var users = _moduleUser.userRepository;
    var removed = await users.deleteByQuery(' id > ? ', parameters: [0]);

    var addresses = AddressAPIRepository(api.entityRepositoryProvider);
    await addresses.deleteByQuery(' id > ? ', parameters: [0]);

    if (removed.isNotEmpty) {
      print('** Removed ${removed.length} users from a previous run.');
    }
  }

  Future<void> seed() async {
    for (var role in roles) {
      await _call('/role/create', {'name': role});
    }

    var chronometer = Stopwatch()..start();

    for (var i = 0; i < users; ++i) {
      var user = await _register('user$i@bench.test', i) as User;
      _userIds.add(user.id!);
    }

    print('** Seeded $users users in ${chronometer.elapsedMilliseconds} ms.');
  }

  Future<Object?> _register(String email, int i) => _call('/user/register', {
    'email': email,
    'password': 'pass$i',
    'name': 'User $i',
    'countryCode': 'US',
    'state': states[i % states.length],
    'city': 'City ${i % 100}',
    'addressLine1': '$i Main St',
    'zipCode': '${10000 + i}',
    'roles': i % 10 == 0 ? 'admin,viewer' : 'viewer',
  });

  int _seededIndex(int i) => i % users;

  Future<void> run(BenchRunner runner, String op) async {
    switch (op) {
      case 'byId':
        await runner.run<void>(
          'user/byId',
          (i, _) => _call('/user/byId', {'id': _userIds[_seededIndex(i)]}),
        );
      case 'byEmail':
        await runner.run<void>(
          'user/byEmail',
          (i, _) => _call('/user/byEmail', {
            'email': 'user${_seededIndex(i)}@bench.test',
          }),
        );
      case 'byState':
        await runner.run<void>(
          'user/byState (join, limit 20)',
          (i, _) =>
              _call('/user/byState', {'state': states[i % states.length]}),
        );
      case 'list':
        var pages = (users / 20).ceil();
        await runner.run<void>(
          'user/list (page of 20)',
          (i, _) => _call('/user/list', {'page': i % pages, 'pageSize': 20}),
        );
      case 'count':
        await runner.run<void>('user/count', (i, _) => _call('/user/count'));
      case 'login':
        await runner.run<void>('authenticate (login)', (i, _) async {
          var n = _seededIndex(i);
          var auth = await api.callAuthenticate('user$n@bench.test', 'pass$n');
          if (auth == null) throw StateError('Login failed: user$n');
        });
      case 'register':
        var runID = DateTime.now().microsecondsSinceEpoch;
        await runner.run<void>(
          'user/register',
          (i, _) => _register('new-$runID-$i@bench.test', i),
        );
      case 'update':
        await runner.run<void>(
          'user/update',
          (i, _) => _call('/user/update', {
            'id': _userIds[_seededIndex(i)],
            'name': 'User $i (updated)',
            'state': states[(i + 1) % states.length],
          }),
        );
      case 'remove':
        var runID = DateTime.now().microsecondsSinceEpoch;
        await runner.run<int>(
          'user/remove',
          setup: (i) async =>
              (await _register('rm-$runID-$i@bench.test', i) as User).id!,
          (i, id) => _call('/user/remove', {'id': id}),
        );
    }
  }

  /// Calls the API, failing the run on any non-OK response: an error must not
  /// be measured as if it were a result.
  Future<Object?> _call(String path, [Map<String, dynamic>? parameters]) async {
    var response = await api.call(
      APIRequest.post(
        path,
        parameters: parameters?.map((k, v) => MapEntry(k, '$v')),
      ),
    );

    if (!response.isOK) {
      throw StateError(
        'Call failed: $path $parameters -> ${response.status} '
        '${response.error ?? response.payload}',
      );
    }

    return response.payload;
  }
}

/// Builds the `db` config for the selected database, and owns any resource
/// created for it (temporary file, Docker container).
class _DBSetup {
  final String db;
  final Map<String, dynamic> dbConfig;
  final Directory? _tempDir;
  final APITestConfigDockerPostgreSQL? _docker;
  final String? _dockerImage;

  _DBSetup._(
    this.db,
    this.dbConfig, {
    Directory? tempDir,
    APITestConfigDockerPostgreSQL? docker,
    String? dockerImage,
  }) : _tempDir = tempDir,
       _docker = docker,
       _dockerImage = dockerImage;

  static const _generateTables = {'generateTables': true};

  static Future<_DBSetup> create(String db, ArgResults opts) async {
    switch (db) {
      case 'sqlite':
        var path = opts.option('sqlite-path');
        Directory? tempDir;
        if (path == null) {
          tempDir = Directory.systemTemp.createTempSync('db_users_bench_');
          path = '${tempDir.path}/bench.db';
        }
        return _DBSetup._(db, {
          'sqlite': <String, dynamic>{
            'path': path,
            'populate': _generateTables,
          },
        }, tempDir: tempDir);

      case 'postgres':
        var env = Platform.environment;
        var config = <String, dynamic>{
          'host': opts.option('pg-host') ?? env['PGHOST'] ?? 'localhost',
          'port': int.parse(opts.option('pg-port') ?? env['PGPORT'] ?? '5432'),
          'username': opts.option('pg-user') ?? env['PGUSER'] ?? 'postgres',
          'password':
              opts.option('pg-password') ?? env['PGPASSWORD'] ?? 'postgres',
          'database':
              opts.option('pg-database') ?? env['PGDATABASE'] ?? 'postgres',
          'populate': _generateTables,
        };

        if (!opts.flag('docker')) {
          return _DBSetup._(db, {'postgres': config});
        }

        var version = opts.option('pg-version')!;
        var docker = APITestConfigDockerPostgreSQL(
          {
            'db': {'postgres': config},
          },
          containerNamePrefix: 'bones_api_db_users_bench',
          dockerChosenPort: true,
          version: version,
        );

        if (!await docker.resolveSupported()) {
          throw StateError('Docker is not available (is the daemon running?)');
        }

        print('** Starting PostgreSQL container (postgres:$version)...');
        if (!await docker.start()) {
          throw StateError("Can't start the PostgreSQL container.");
        }

        return _DBSetup._(
          db,
          {'postgres': docker.dbConfig},
          docker: docker,
          dockerImage: 'postgres:$version',
        );

      default:
        return _DBSetup._(db, {'sql.memory': <String, dynamic>{}});
    }
  }

  /// A description of the DB for the report.
  Future<String> details(UsersAPIRoot api) async {
    switch (db) {
      case 'sqlite':
        var path = (dbConfig['sqlite'] as Map)['path'];
        return _tempDir != null ? 'temporary file' : '$path';
      case 'postgres':
        var config = dbConfig['postgres'] as Map;
        var adapter =
            await api.entityRepositoryProvider.adapter as DBPostgreSQLAdapter;
        var rows = await adapter.executeWithPool(
          (c) => c.mappedResultsQuery('SHOW server_version'),
        );
        var version = rows.firstOrNull?.values.firstOrNull;
        var where = _docker != null
            ? 'Docker $_dockerImage'
            : '${config['host']}:${config['port']}';
        return 'PostgreSQL $version, $where';
      default:
        return 'DBSQLMemoryAdapter';
    }
  }

  Future<void> close() async {
    if (_docker != null) {
      print('** Stopping PostgreSQL container...');
      await _docker.stop();
    }
    _tempDir?.deleteSync(recursive: true);
  }
}
