@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api_test.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:test/test.dart';

void main() {
  group('APITestConfig (coverage)', () {
    test('base defaults', () async {
      var config = APITestConfig({'a': 1});

      expect(config.isStarted, isTrue);
      expect(config.isStarting, isFalse);
      expect(config.isStopped, isFalse);
      expect(await config.start(), isTrue);
      expect(await config.stop(), isTrue);
      expect(config.isSupported, isTrue);
      expect(config.unsupportedReason, isNull);
      expect(await [config].resolveSupported(), equals([true]));
    });

    test('APITestConfigDBSQLMemory: start/stop/listTables', () async {
      var config = APITestConfigDBSQLMemory({
        'db': {
          'sql.memory': {'port': '?'},
        },
      });

      expect(config.dbType, equals('memory'));
      expect(await config.resolveSupported(), isTrue);
      expect(config.isStarted, isFalse);
      expect(config.isStarting, isFalse);
      expect(await config.stop(), isFalse);

      expect(await config.start(), isTrue);
      expect(config.isStarted, isTrue);
      expect(config.isStarting, isFalse);

      expect(() => config.start(), throwsA(isA<StateError>()));

      expect(await config.listTables(), isEmpty);

      expect(await config.stop(), isTrue);
      expect(config.isStopped, isTrue);
      expect(await config.stop(), isTrue);
    });
  });

  group('APITestConfigDBMixin (coverage)', () {
    test('dbPort', () async {
      var config = _DBConfig({'port': ' 1234 '});
      expect(await config.dbPort, equals(1234));

      config = _DBConfig({'port': 'abc'});
      expect(await config.dbPort, equals(5001));
      expect(config.dbConfig['port'], equals(5001));

      config = _DBConfig({'port': -2000});
      expect(await config.dbPort, equals(2001));

      config = _DBConfig({'port': -10});
      expect(await config.dbPort, equals(5001));

      config = _DBConfig({});
      expect(await config.dbPort, equals(5001));
      expect(config.dbConfig['port'], equals(5001));

      config = _DBConfig({'port': '*'});
      expect(await config.dbPort, equals(5001));

      config = _DBConfig({'port': 1.5});
      expect(() => config.dbPort, throwsA(isA<StateError>()));

      config = _DBConfig({});
      expect(await config.resolveDbPort(3000), equals(3001));
      expect(config.dbConfig['port'], equals(3001));
    });

    test('credentials / listTables', () {
      var config = _DBConfig({'user': 'u', 'pass': 123, 'db': 'd'});
      expect(config.dbUser, equals('u'));
      expect(config.dbPass, equals('123'));
      expect(config.dbName, equals('d'));
      expect(() => config.listTables(), throwsUnsupportedError);

      var config2 = _DBConfig({'username': 'u2', 'database': 'd2'});
      expect(config2.dbUser, equals('u2'));
      expect(config2.dbPass, equals(''));
      expect(config2.dbName, equals('d2'));
    });

    test('createTableSQL', () async {
      const sqls = '''
-- comment
CREATE TABLE a (id int);
CREATE TABLE b (id int);
''';

      var c1 = _DBSQLConfig();
      var r1 = await c1.createTableSQL(sqls);
      expect(r1.length, equals(2));
      expect(c1.executed.length, equals(2));
      expect(c1.executed[0], contains('CREATE TABLE a'));
      expect(c1.executed[1], contains('CREATE TABLE b'));
      expect(await c1.createTableSQL('-- nothing'), isEmpty);

      var c2 = _DBSQLMixinConfig();
      var r2 = await c2.createTableSQL(sqls);
      expect(r2, equals(['ok', 'ok']));
      expect(c2.executed.length, equals(2));
      expect(await c2.createTableSQL(''), isEmpty);
    });
  });

  group('APITestConfigDockerDB (coverage)', () {
    test('without container', () async {
      var config = _DockerDBConfig(DockerHostLocal(), 'MyDB', {});

      expect(config.dbType, equals('MyDB'));
      expect(config.containerNamePrefix, equals('api_test_mydb'));
      expect(config.cleanContainer, isTrue);
      expect(config.dockerChosenPort, isFalse);
      expect(config.container, isNull);
      expect(config.stdout, isNull);
      expect(config.stderr, isNull);
      expect(config.stdoutAsString, isEmpty);
      expect(config.stderrAsString, isEmpty);
      expect(await config.stopContainer(), isFalse);
      expect(config.stopContainerTimeout, equals(Duration(seconds: 60)));
      expect(config.isSupported, isFalse);
      expect(config.unsupportedReason, equals('Docker Daemon NOT running!'));

      var config2 = _DockerDBConfig(
        DockerHostLocal(),
        'x',
        {},
        containerNamePrefix: 'custom',
      );
      expect(config2.containerNamePrefix, equals('custom'));
    });
  });
}

class _DBConfig extends APITestConfigDB {
  @override
  final Map<String, dynamic> dbConfig;

  _DBConfig(this.dbConfig) : super('test', {});

  @override
  FutureOr<int> resolveFreePort(int port) => port + 1;
}

class _DBSQLConfig extends APITestConfigDBSQL {
  final List<String> executed = [];

  _DBSQLConfig() : super('sql', {});

  @override
  Map<String, dynamic> get dbConfig => {};

  @override
  FutureOr<int> resolveFreePort(int port) => port;

  @override
  Future<String?> runSQL(String sqlInline) async {
    executed.add(sqlInline);
    return null;
  }
}

class _DBSQLMixinConfig extends APITestConfig
    with APITestConfigDBMixin, APITestConfigDBSQLMixin {
  final List<String> executed = [];

  _DBSQLMixinConfig() : super({});

  @override
  String get dbType => 'sql-mixin';

  @override
  Map<String, dynamic> get dbConfig => {};

  @override
  FutureOr<int> resolveFreePort(int port) => port;

  @override
  Future<String?> runSQL(String sqlInline) async {
    executed.add(sqlInline);
    return 'ok';
  }
}

class _DockerDBConfig extends APITestConfigDockerDB<DockerContainer> {
  _DockerDBConfig(
    super.dockerHost,
    super.dbType,
    super.apiConfig, {
    super.containerNamePrefix,
  });

  @override
  Map<String, dynamic> get dbConfig => {};

  @override
  FutureOr<int> resolveFreePort(int port) => port;

  @override
  String get runtimeTypeNameSafe => '_DockerDBConfig';

  @override
  DockerContainerConfig<DockerContainer> createDBContainerConfig(int dbPort) =>
      throw UnimplementedError();
}
