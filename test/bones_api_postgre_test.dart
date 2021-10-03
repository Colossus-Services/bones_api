@Timeout(Duration(seconds: 180))
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_adapter_postgre.dart';
import 'package:bones_api/src/bones_api_logging.dart';
import 'package:docker_commander/docker_commander.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

final _log = logging.Logger('bones_api_postgre_test');

final postgreUser = 'postgre';
final postgrePass = '123456';
final postgreDB = 'postgre';
late final int postgrePort;

class PostgreEntityRepositoryProvider extends EntityRepositoryProvider {
  EntityHandler<Address> addressEntityHandler;

  EntityHandler<User> userEntityHandler;

  late final AddressAPIRepository addressAPIRepository;
  late final RoleAPIRepository roleAPIRepository;
  late final UserAPIRepository userAPIRepository;

  PostgreEntityRepositoryProvider(
      this.addressEntityHandler, this.userEntityHandler) {
    var postgreAdapter = PostgreSQLAdapter(
      postgreDB,
      postgreUser,
      password: postgrePass,
      port: postgrePort,
      parentRepositoryProvider: this,
    );

    SQLEntityRepository<Address>(
        postgreAdapter, 'address', addressEntityHandler);

    SQLEntityRepository<Role>(postgreAdapter, 'role', roleEntityHandler);

    SQLEntityRepository<User>(postgreAdapter, 'user', userEntityHandler);

    addressAPIRepository = AddressAPIRepository(this)..ensureConfigured();

    roleAPIRepository = RoleAPIRepository(this)..ensureConfigured();

    userAPIRepository = UserAPIRepository(this)..ensureConfigured();
  }
}

void main() {
  _log.handler.logToConsole();

  group('PostgreSQL', () {
    late final DockerHostLocal dockerHostLocal;
    late final DockerCommander dockerCommander;
    late bool dockerRunning;
    late final PostgreSQLContainerConfig postgreSQLContainerConfig;
    late final PostgreSQLContainer postgreContainer;
    late final PostgreEntityRepositoryProvider entityRepositoryProvider;

    setUpAll(() async {
      _log.info('[[[ setUpAll ]]]');

      dockerHostLocal = DockerHostLocal();
      dockerCommander = DockerCommander(dockerHostLocal);
      await dockerCommander.ensureInitialized();

      _log.info('DockerCommander: $dockerCommander');

      var daemonOK = false;
      try {
        daemonOK = await dockerCommander.isDaemonRunning();
      } catch (_) {}

      dockerRunning = daemonOK;

      _log.info('dockerRunning: $dockerRunning');

      if (dockerRunning) {
        postgrePort =
            (await getFreeListenPort(startPort: 5332, endPort: 5432))!;

        postgreSQLContainerConfig = PostgreSQLContainerConfig(
            pgUser: postgreUser,
            pgPassword: postgrePass,
            pgDatabase: postgreDB,
            hostPort: postgrePort);

        postgreContainer = await postgreSQLContainerConfig.run(dockerCommander,
            name: 'dc_test_postgre', cleanContainer: true);

        _log.info('Postgre Container: $postgreContainer');

        entityRepositoryProvider = PostgreEntityRepositoryProvider(
            addressEntityHandler, userEntityHandler);
      } else {
        _log.warning('Docker NOT running! Skipping Docker tests!');
      }
    });

    tearDownAll(() async {
      _log.info('[[[ tearDownAll ]]]');

      if (dockerRunning) {
        entityRepositoryProvider.close();

        await postgreContainer.stop(timeout: Duration(seconds: 30));
        await dockerCommander.close();
      }
    });

    bool checkDockerRunning(String test) {
      if (!dockerRunning) {
        _log.warning('Docker NOT running! Skip test: "$test"');
        return false;
      } else {
        return true;
      }
    }

    test('create table', () async {
      if (!checkDockerRunning('create table')) return;

      var ready = await postgreContainer.waitReady();
      expect(ready, isTrue);

      print('----------------------------------------------');
      print(postgreContainer.stdout?.asString);
      print('----------------------------------------------');

      var sqlCreateAddress = '''
      CREATE TABLE IF NOT EXISTS "address" (
        "id" serial,
        "state" text,
        "city" text,
        "street" text,
        "number" integer,
        PRIMARY KEY( id )
      )
      ''';

      var process1 = await postgreContainer.runSQL(sqlCreateAddress);
      expect(process1, contains('CREATE TABLE'));

      var sqlCreateUser = '''
      CREATE TABLE IF NOT EXISTS "user" (
        "id" serial,
        "email" text NOT NULL,
        "password" text NOT NULL,
        "address" integer NOT NULL CONSTRAINT address_ref_account_fk REFERENCES address(id),
        "creation_time" timestamp NOT NULL,
        PRIMARY KEY( id )
      );
      ''';

      var process2 = await postgreContainer.runSQL(sqlCreateUser);
      expect(process2, contains('CREATE TABLE'));

      var sqlCreateRole = '''
      CREATE TABLE IF NOT EXISTS "role" (
        "id" serial,
        "type" text NOT NULL,
        "enabled" boolean NOT NULL,
        PRIMARY KEY( id )
      );
      ''';

      var process3 = await postgreContainer.runSQL(sqlCreateRole);
      expect(process3, contains('CREATE TABLE'));

      var sqlCreateUserRole = '''
      CREATE TABLE IF NOT EXISTS "user_role_ref" (
        "user_id" integer REFERENCES "user"(id) ON DELETE CASCADE,
        "role_id" integer REFERENCES "role"(id) ON DELETE CASCADE,
        CONSTRAINT user_role_ref_pkey PRIMARY KEY ("user_id", "role_id")
      );
      ''';

      var process4 = await postgreContainer.runSQL(sqlCreateUserRole);
      expect(process4, contains('CREATE TABLE'));

      var processList = await postgreContainer.psqlCMD('\\d');

      print(processList);

      expect(
          processList,
          allOf(
            contains(RegExp(r'\Waddress\W')),
            contains(RegExp(r'\Wuser\W')),
            contains(RegExp(r'\Wrole\W')),
            contains(RegExp(r'\Wuser_role_ref\W')),
          ));
    });

    test('PostgreEntityRepositoryProvider', () async {
      if (!checkDockerRunning('PostgreEntityRepositoryProvider')) return;

      var addressAPIRepository = entityRepositoryProvider.addressAPIRepository;
      var roleAPIRepository = entityRepositoryProvider.roleAPIRepository;
      var userAPIRepository = entityRepositoryProvider.userAPIRepository;

      expect(await userAPIRepository.length(), equals(0));

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user, isNull);
      }

      {
        var del = await userAPIRepository.deleteByQuery(' email == "foo" ');
        expect(del, isEmpty);
      }

      {
        var role = await roleAPIRepository.selectByID(1);
        expect(role, isNull);
      }

      var user1Time = DateTime.utc(2021, 9, 20, 10, 11, 12, 0, 0);

      {
        var address = Address('NY', 'New York', 'street A', 101);

        var user = User('joe@postgre.com', '123', address, [Role('admin')],
            creationTime: user1Time);
        var id = await userAPIRepository.store(user);
        expect(id, equals(1));
      }

      var user2Time = DateTime.utc(2021, 9, 21, 22, 11, 12, 0, 0);

      {
        var address = Address('CA', 'Los Angeles', 'street B', 201);
        var user = User('smith@postgre.com', 'abc', address, [Role('guest')],
            creationTime: user2Time);
        var id = await userAPIRepository.store(user);
        expect(id, equals(2));
      }

      expect(await addressAPIRepository.length(), equals(2));
      expect(await userAPIRepository.length(), equals(2));

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user!.email, equals('joe@postgre.com'));
        expect(user.address.state, equals('NY'));
        expect(
            user.roles.map((e) => e.toJson()),
            equals([
              {'id': 1, 'type': 'admin', 'enabled': true}
            ]));
        expect(user.creationTime, equals(user1Time));
      }

      {
        var user = await userAPIRepository.selectByID(2);
        expect(user!.email, equals('smith@postgre.com'));
        expect(user.address.state, equals('CA'));
        expect(
            user.roles.map((e) => e.toJson()),
            equals([
              {'id': 2, 'type': 'guest', 'enabled': true}
            ]));
        expect(user.creationTime, equals(user2Time));
      }

      {
        var user = await userAPIRepository.selectByID(3000);
        expect(user, isNull);
      }

      {
        var sel = await userAPIRepository.selectByEmail('joe@postgre.com');
        var user = sel.first;
        expect(user.email, equals('joe@postgre.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByEmail('smith@postgre.com');
        var user = sel.first;
        expect(user.email, equals('smith@postgre.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('NY');

        var user = sel.first;
        expect(user.email, equals('joe@postgre.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('CA');

        var user = sel.first;
        expect(user.email, equals('smith@postgre.com'));
        expect(user.address.state, equals('CA'));

        user.email = 'smith2@postgre.com';

        var ok = await userAPIRepository.store(user);
        expect(ok, equals(user.id));
      }

      {
        var del = await userAPIRepository
            .deleteByQuery(' #ID == ? ', parameters: [2]);
        var user = del.first;
        expect(user.email, equals('smith2@postgre.com'));
        expect(user.address.state, equals('CA'));
        expect(user.creationTime, equals(user2Time));
      }

      expect(await userAPIRepository.length(), equals(1));

      {
        var user = await userAPIRepository.selectByID(2);
        expect(user, isNull);
      }
    });
  });
}
