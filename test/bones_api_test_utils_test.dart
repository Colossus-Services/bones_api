@TestOn('vm')
@Timeout(Duration(minutes: 5))
import 'package:bones_api/bones_api_logging.dart';
import 'package:bones_api/bones_api_test_mysql.dart';
import 'package:bones_api/bones_api_test_postgres.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

part 'bones_api_test_utils_test.reflection.g.dart';

final _log = logging.Logger('APITestConfig');

const Map<String, dynamic> apiConfigMemory = <String, dynamic>{
  'db': {'sql.memory': {}},
  'dialect': 'generic',
};

const Map<String, dynamic> apiConfigPostgres = <String, dynamic>{
  'db': {
    'postgres': {
      'port': -5432,
      'database': 'bones_api_test_postgres',
      'username': 'postgres',
      'password': '123456',
      'populate': {'tables': 'db-tables-postgres.sql'},
    },
  },
  'dialect': 'PostgreSQL',
};

const Map<String, dynamic> apiConfigMysql = <String, dynamic>{
  'db': {
    'mysql': {
      'port': -3306,
      'database': 'bones_api_test_mysql',
      'username': 'mysql',
      'password': '123456',
      'populate': {'tables': 'db-tables-postgres.sql'},
    },
  },
  'dialect': 'MySQL',
};

final dockerHostLocal = DockerHostLocal();

APITestConfigDB _getAPITestConfig(String dbType) {
  _log.info('** DB TYPE: $dbType');

  var containerPrefix = 'bones_api_test_$dbType';

  if (dbType == 'postgres') {
    return APITestConfigDockerPostgreSQL(
      apiConfigPostgres,
      dockerHost: dockerHostLocal,
      containerNamePrefix: containerPrefix,
    );
  } else if (dbType == 'mysql') {
    return APITestConfigDockerMySQL(
      apiConfigMysql,
      dockerHost: dockerHostLocal,
      containerNamePrefix: containerPrefix,
      // TODO: update package `mysql1` with support for MySQL 8.4.0
      version: '8.0.37',
    );
  } else {
    return APITestConfigDBSQLMemory(apiConfigMemory);
  }
}

Future<void> main() async {
  logToConsole();

  var apiTestConfigMemory = _getAPITestConfig('memory');
  var apiTestConfigPostgres = _getAPITestConfig('postgres');
  var apiTestConfigMySQL = _getAPITestConfig('mysql');

  await [
    apiTestConfigMemory,
    apiTestConfigPostgres,
    apiTestConfigMySQL,
  ].resolveSupported();

  group('APITestConfig (basic start/stop)', () {
    Future<void> testDB(APITestConfigDB apiTestConfig) async {
      expect(apiTestConfig.isSupported, isTrue);

      var apiRootStarter = apiTestConfig.createAPIRootStarter(
        (apiConfig) => MyAPI.withConfig(apiConfig),
      );

      expect(await apiRootStarter.start(), isTrue);

      try {
        expect(apiRootStarter.isStarted, isTrue);
        expect(apiTestConfig.isStarted, isTrue);

        var api = apiRootStarter.apiRoot!;
        expect(api.apiConfig['dialect'], isNotEmpty);

        expect(
          api.getModule('base')!.apiInfo().toJson(),
          equals({
            'name': 'base',
            'routes': [
              {'name': 'time', 'uri': '/base/time'},
              {'name': 'foo', 'method': 'GET', 'uri': '/base/foo'},
              {'name': 'foo', 'method': 'POST', 'uri': '/base/foo'},
            ],
          }),
        );

        var adapter = await DBSQLAdapter.fromConfig(api.apiConfig['db']);
        print(adapter);

        expect(adapter, isNotNull);
        expect(adapter.dialect.name, api.apiConfig['dialect']);

        var connection = await adapter.createPoolElement();
        expect(connection, isNotNull);

        expect(adapter.disposePoolElement(connection!), isTrue);

        var fullCreateTableSQLs = await adapter.generateFullCreateTableSQLs(
          title: 'Test',
        );

        // No repositories:
        expect(fullCreateTableSQLs, equals(''));
      } finally {
        expect(await apiRootStarter.stop(), isTrue);
      }
    }

    test(
      'memory',
      () => testDB(apiTestConfigMemory),
      skip: apiTestConfigMemory.unsupportedReason,
    );

    test(
      'postgres',
      () => testDB(apiTestConfigPostgres),
      skip: apiTestConfigPostgres.unsupportedReason,
      tags: ['docker', 'slow'],
    );

    test(
      'mysql',
      () => testDB(apiTestConfigMySQL),
      skip: apiTestConfigMySQL.unsupportedReason,
      tags: ['docker', 'slow'],
    );
  });

  group('APITestConfig (Docker-chosen port)', () {
    APITestConfigDockerPostgreSQL newPostgresConfig() =>
        APITestConfigDockerPostgreSQL(
          apiConfigPostgres,
          dockerHost: dockerHostLocal,
          containerNamePrefix: 'bones_api_test_postgres',
          dockerChosenPort: true,
          ephemeral: true,
          settings: {'max_connections': '42'},
          runOptions: DockerRunOptions(
            labels: {'bones_api.test': 'docker-chosen-port'},
          ),
        );

    test(
      'postgres: two in parallel, each API on its own port',
      () async {
        var configs = [newPostgresConfig(), newPostgresConfig()];

        var starters = configs
            .map(
              (c) => c.createAPIRootStarter(
                (apiConfig) => MyAPI.withConfig(apiConfig),
              ),
            )
            .toList();

        try {
          expect(
            await Future.wait(starters.map((s) async => await s.start())),
            everyElement(isTrue),
          );

          var ports = configs.map((c) => c.dbConfig['port'] as int).toList();
          _log.info('Ports chosen by Docker: $ports');
          expect(ports.toSet(), hasLength(2));

          for (var (i, config) in configs.indexed) {
            var container = config.container!;
            expect(container.hostPortFor(5432), equals(ports[i]));
            expect(container.name, startsWith('bones_api_test_postgres_'));

            // The API connects on the chosen port:
            var api = starters[i].apiRoot!;
            var apiDbConfig = api.apiConfig['db'] as Map;
            expect((apiDbConfig['postgres'] as Map)['port'], equals(ports[i]));

            var adapter = await DBSQLAdapter.fromConfig(api.apiConfig['db']);
            var connection = await adapter.createPoolElement();
            expect(connection, isNotNull);
            expect(adapter.disposePoolElement(connection!), isTrue);

            // `settings`, `ephemeral` and `runOptions` reached the container:
            expect(
              await container.runSQLScript('SHOW max_connections;'),
              contains('42'),
            );
            expect(
              await container.runSQLScript('SHOW fsync;'),
              contains('off'),
            );
          }

          var dockerCommander = DockerCommander(dockerHostLocal);
          expect(
            await dockerCommander.listContainersByLabel({
              'bones_api.test': 'docker-chosen-port',
            }),
            containsAll(configs.map((c) => c.container!.name)),
          );
        } finally {
          for (var s in starters) {
            expect(await s.stop(), isTrue);
          }
        }
      },
      skip: apiTestConfigPostgres.unsupportedReason,
      tags: ['docker', 'slow'],
    );

    test('postgres: container config with a Docker-chosen port', () {
      var config = newPostgresConfig();
      var containerConfig = config.createDBContainerConfig(0);

      expect(containerConfig.hostPorts, equals([0]));
      expect(containerConfig.ephemeral, isTrue);
      expect(
        containerConfig.imageArgs,
        containsAllInOrder(['-c', 'max_connections=42']),
      );
      expect(
        containerConfig.options!.labels,
        equals({'bones_api.test': 'docker-chosen-port'}),
      );
    });

    test('mysql: container config', () {
      var config = APITestConfigDockerMySQL(
        apiConfigMysql,
        dockerHost: dockerHostLocal,
        version: '8.0.37',
        dockerChosenPort: true,
        ephemeral: true,
        settings: {'max-connections': '50'},
        runOptions: DockerRunOptions(memory: '512m'),
      );

      var containerConfig = config.createDBContainerConfig(0);
      expect(containerConfig.hostPorts, equals([0]));
      expect(containerConfig.imageArgs, contains('--max-connections=50'));
      expect(containerConfig.imageArgs, contains('--skip-log-bin'));
      expect(containerConfig.options!.memory, equals('512m'));
      expect(config.dockerChosenPort, isTrue);
    });
  });
}

class MyAPI extends APIRoot {
  MyAPI.withConfig([dynamic apiConfig])
    : super(
        'example',
        '1.0',
        apiConfig: apiConfig,
        preApiRequestHandlers: [_preRequest],
        posApiRequestHandlers: [_posRequest],
      );

  static APIResponse<T>? _preRequest<T>(APIRoot apiRoot, APIRequest request) {
    if (request.pathPartFirst.startsWith('pre')) {
      return APIResponse.ok('Pre request: ${request.path}' as T);
    }
    return null;
  }

  static APIResponse<T>? _posRequest<T>(APIRoot apiRoot, APIRequest request) {
    if (request.pathPartFirst.startsWith('pos')) {
      return APIResponse.ok('Pos request: ${request.path}' as T);
    }
    return null;
  }

  @override
  Set<APIModule> loadModules() => {MyBaseModule(this), MyInfoModule(this)};
}

class MyBaseModule extends APIModule {
  MyBaseModule(APIRoot apiRoot) : super(apiRoot, 'base');

  @override
  String? get defaultRouteName => '404';

  @override
  void configure() {
    routes.get('foo', (request) => APIResponse.ok('Hi[GET]!'));
    routes.post(
      'foo',
      (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'),
    );

    routes.any(
      'time',
      (request) => APIResponse.ok(DateTime.now(), mimeType: 'text/plain'),
    );
  }
}

@EnableReflection()
class MyInfoModule extends APIModule {
  MyInfoModule(APIRoot apiRoot) : super(apiRoot, 'info');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  FutureOr<APIResponse<String>> echo(String msg, APIRequest request) {
    var method = request.method.name;
    var agent = request.headers['user-agent'];
    var reply = '[method: $method ; msg: ${msg.toUpperCase()} ; agent: $agent]';
    return APIResponse.ok(reply);
  }

  FutureOr<APIResponse<String>> toUpperCase(String msg) {
    var reply = 'Upper case: ${msg.toUpperCase()}';
    return APIResponse.ok(reply);
  }
}
