@TestOn('vm')
@Timeout(Duration(minutes: 2))
import 'package:bones_api/bones_api_logging.dart';
import 'package:bones_api/bones_api_test_mysql.dart';
import 'package:bones_api/bones_api_test_postgres.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

part 'bones_api_test_utils_test.reflection.g.dart';

final _log = logging.Logger('APITestConfig');

const Map<String, dynamic> apiConfigMemory = <String, dynamic>{
  'db': {
    'memory': {},
  },
  'dialect': 'generic',
};

const Map<String, dynamic> apiConfigPostgres = <String, dynamic>{
  'db': {
    'postgres': {
      'port': -5432,
      'database': 'bones_api_test_postgres',
      'username': 'postgres',
      'password': '123456',
      'populate': {
        'tables': 'db-tables-postgres.sql',
      }
    },
  },
  'dialect': 'postgre',
};

const Map<String, dynamic> apiConfigMysql = <String, dynamic>{
  'db': {
    'mysql': {
      'port': -3306,
      'database': 'bones_api_test_mysql',
      'username': 'mysql',
      'password': '123456',
      'populate': {
        'tables': 'db-tables-postgres.sql',
      }
    },
  },
  'dialect': 'mysql',
};

final dockerHostLocal = DockerHostLocal();

APITestConfigDB _getAPITestConfig(String dbType) {
  _log.info('** DB TYPE: $dbType');

  var containerPrefix = 'bones_api_test_$dbType';

  if (dbType == 'postgres') {
    return APITestConfigDockerPostgreSQL(apiConfigPostgres,
        dockerHost: dockerHostLocal, containerNamePrefix: containerPrefix);
  } else if (dbType == 'mysql') {
    return APITestConfigDockerMySQL(apiConfigMysql,
        dockerHost: dockerHostLocal, containerNamePrefix: containerPrefix);
  } else {
    return APITestConfigDBMemory(apiConfigMemory);
  }
}

void main() async {
  logToConsole();

  var apiTestConfigMemory = _getAPITestConfig('memory');
  var apiTestConfigPostgres = _getAPITestConfig('postgres');
  var apiTestConfigMySQL = _getAPITestConfig('mysql');

  await [apiTestConfigMemory, apiTestConfigPostgres, apiTestConfigMySQL]
      .resolveSupported();

  group('APITestConfig (basic start/stop)', () {
    Future<void> _testDB(APITestConfigDB apiTestConfig) async {
      expect(apiTestConfig.isSupported, isTrue);

      var apiRootStarter = apiTestConfig
          .createAPIRootStarter((apiConfig) => MyAPI.withConfig(apiConfig));

      expect(await apiRootStarter.start(), isTrue);

      try {
        expect(apiRootStarter.isStarted, isTrue);

        var api = apiRootStarter.apiRoot!;
        expect(api.apiConfig['dialect'], isNotEmpty);

        expect(
            api.getModule('base')!.apiInfo().toJson(),
            equals({
              'name': 'base',
              'routes': [
                {'name': 'time', 'uri': '/base/time'},
                {'name': 'foo', 'method': 'GET', 'uri': '/base/foo'},
                {'name': 'foo', 'method': 'POST', 'uri': '/base/foo'}
              ]
            }));

        var adapter = await SQLAdapter.fromConfig(api.apiConfig['db']);
        print(adapter);

        expect(adapter, isNotNull);
        expect(adapter.dialect, api.apiConfig['dialect']);

        var connection = await adapter.createPoolElement();
        expect(connection, isNotNull);

        expect(adapter.disposePoolElement(connection!), isTrue);

        //apiTestConfig.list
      } finally {
        expect(await apiRootStarter.stop(), isTrue);
      }
    }

    test('memory', () => _testDB(apiTestConfigMemory),
        skip: apiTestConfigMemory.unsupportedReason);

    test('postgres', () => _testDB(apiTestConfigPostgres),
        skip: apiTestConfigPostgres.unsupportedReason, tags: ['docker']);

    test('mysql', () => _testDB(apiTestConfigMySQL),
        skip: apiTestConfigMySQL.unsupportedReason, tags: ['docker']);
  });
}

class MyAPI extends APIRoot {
  MyAPI.withConfig([dynamic apiConfig])
      : super('example', '1.0',
            apiConfig: apiConfig,
            preApiRequestHandlers: [_preRequest],
            posApiRequestHandlers: [_posRequest]);

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
        'foo', (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'));

    routes.any('time',
        (request) => APIResponse.ok(DateTime.now(), mimeType: 'text/plain'));
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
