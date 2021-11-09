@Timeout(Duration(seconds: 180))
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_logging.dart';
import 'package:docker_commander/docker_commander.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

final _log = logging.Logger('bones_api_test_adapter');

typedef SQLAdapterCreator = SQLAdapter Function(
    EntityRepositoryProvider? parentRepositoryProvider, int dbPort);

class TestEntityRepositoryProvider extends EntityRepositoryProvider {
  final EntityHandler<Address> addressEntityHandler;
  final EntityHandler<Role> roleEntityHandler;
  final EntityHandler<User> userEntityHandler;

  late final AddressAPIRepository addressAPIRepository;
  late final RoleAPIRepository roleAPIRepository;
  late final UserAPIRepository userAPIRepository;

  late final SQLAdapter sqlAdapter;

  TestEntityRepositoryProvider(
      this.addressEntityHandler,
      this.roleEntityHandler,
      this.userEntityHandler,
      SQLAdapterCreator sqlAdapterCreator,
      int dbPort) {
    sqlAdapter = sqlAdapterCreator(this, dbPort);

    SQLEntityRepository<Address>(sqlAdapter, 'address', addressEntityHandler);

    SQLEntityRepository<Role>(sqlAdapter, 'role', roleEntityHandler);

    SQLEntityRepository<User>(sqlAdapter, 'user', userEntityHandler);

    addressAPIRepository = AddressAPIRepository(this)..ensureConfigured();

    roleAPIRepository = RoleAPIRepository(this)..ensureConfigured();

    userAPIRepository = UserAPIRepository(this)..ensureConfigured();
  }
}

abstract class DBTestContainer {
  Future<bool> start(DockerCommander dockerCommander, int dbPort);

  Future<bool> waitReady();

  Future<bool> stop();

  Future<String?> runSQL(String sqlInline);

  Future<String> listTables();

  String get stdout;
}

void runAdapterTests(
    String dbName,
    DBTestContainer dbTestContainer,
    int dbPort,
    SQLAdapterCreator sqlAdapterCreator,
    String cmdQuote,
    String serialIntType,
    dynamic createTableMatcher,
    {required bool entityByReflection}) {
  _log.handler.logToConsole();

  var testDomain = dbName.toLowerCase() + '.com';

  group('SQLAdapter[$dbName${entityByReflection ? '+reflection' : ''}]', () {
    late final DockerHostLocal dockerHostLocal;
    late final DockerCommander dockerCommander;
    late bool dockerRunning;
    late final TestEntityRepositoryProvider entityRepositoryProvider;

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
        dbPort = (await getFreeListenPort(
            startPort: dbPort - 100, endPort: dbPort + 100))!;

        var startOk = await dbTestContainer.start(dockerCommander, dbPort);

        _log.info('Container start: $startOk > $dbTestContainer');

        entityRepositoryProvider = TestEntityRepositoryProvider(
          entityByReflection
              ? Address$reflection().entityHandler
              : addressEntityHandler,
          entityByReflection
              ? Role$reflection().entityHandler
              : roleEntityHandler,
          entityByReflection
              ? User$reflection().entityHandler
              : userEntityHandler,
          sqlAdapterCreator,
          dbPort,
        );
      } else {
        _log.warning('Docker NOT running! Skipping Docker tests!');
      }
    });

    tearDownAll(() async {
      _log.info('[[[ tearDownAll ]]]');

      if (dockerRunning) {
        entityRepositoryProvider.close();

        await dbTestContainer.stop();
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
      if (!checkDockerRunning('[$dbName] create table')) return;

      var ready = await dbTestContainer.waitReady();
      expect(ready, isTrue);

      print('----------------------------------------------');
      print(dbTestContainer.stdout);
      print('----------------------------------------------');

      var q = cmdQuote;

      var sqlCreateAddress = '''
      CREATE TABLE IF NOT EXISTS ${q}address$q (
        ${q}id$q serial,
        ${q}state$q text,
        ${q}city$q text,
        ${q}street$q text,
        ${q}number$q integer,
        PRIMARY KEY( ${q}id$q )
      )
      ''';

      var process1 = await dbTestContainer.runSQL(sqlCreateAddress);
      expect(process1, createTableMatcher);

      var sqlCreateUser = '''
      CREATE TABLE IF NOT EXISTS ${q}user$q (
        ${q}id$q serial,
        ${q}email$q text NOT NULL,
        ${q}password$q text NOT NULL,
        ${q}address$q $serialIntType NOT NULL,
        ${q}level$q integer,
        ${q}creation_time$q timestamp NOT NULL,
        PRIMARY KEY( ${q}id$q ),
        CONSTRAINT user_ref_address_fk FOREIGN KEY (${q}address$q) REFERENCES ${q}address$q(${q}id$q)
      );
      ''';

      var process2 = await dbTestContainer.runSQL(sqlCreateUser);
      expect(process2, createTableMatcher);

      var sqlCreateRole = '''
      CREATE TABLE IF NOT EXISTS ${q}role$q (
        ${q}id$q serial,
        ${q}type$q text NOT NULL,
        ${q}enabled$q boolean NOT NULL,
        PRIMARY KEY( ${q}id$q )
      );
      ''';

      var process3 = await dbTestContainer.runSQL(sqlCreateRole);
      expect(process3, createTableMatcher);

      var sqlCreateUserRole = '''
      CREATE TABLE IF NOT EXISTS ${q}user_role_ref$q (
        ${q}user_id$q $serialIntType NOT NULL,
        ${q}role_id$q $serialIntType NOT NULL,
        CONSTRAINT user_role_ref_pkey PRIMARY KEY (${q}user_id$q, ${q}role_id$q),
        CONSTRAINT user_role_ref_fk1 FOREIGN KEY (${q}user_id$q) REFERENCES ${q}user$q(${q}id$q) ON DELETE CASCADE,
        CONSTRAINT user_role_ref_fk2 FOREIGN KEY (${q}role_id$q) REFERENCES ${q}role$q(${q}id$q) ON DELETE CASCADE
      );
      ''';

      var process4 = await dbTestContainer.runSQL(sqlCreateUserRole);
      expect(process4, createTableMatcher);

      var processList = await dbTestContainer.listTables();

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

    test('TestEntityRepositoryProvider', () async {
      if (!checkDockerRunning('[$dbName] TestEntityRepositoryProvider')) return;

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

        var user = User('joe@$testDomain', '123', address, [Role('admin')],
            level: 100, creationTime: user1Time);
        var id = await userAPIRepository.store(user);
        expect(id, equals(1));
      }

      var user2Time = DateTime.utc(2021, 9, 21, 22, 11, 12, 0, 0);

      {
        var address = Address('CA', 'Los Angeles', 'street B', 201);
        var user = User('smith@$testDomain', 'abc', address, [Role('guest')],
            creationTime: user2Time);
        var id = await userAPIRepository.store(user);
        expect(id, equals(2));
      }

      expect(await addressAPIRepository.length(), equals(2));
      expect(await userAPIRepository.length(), equals(2));

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user!.email, equals('joe@$testDomain'));
        expect(user.address.state, equals('NY'));
        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals([
              {'id': 1, 'type': 'admin', 'enabled': true}
            ]));
        expect(user.level, equals(100));
        expect(user.creationTime, equals(user1Time));
      }

      {
        var user = await userAPIRepository.selectByID(2);
        expect(user!.email, equals('smith@$testDomain'));
        expect(user.address.state, equals('CA'));
        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals([
              {'id': 2, 'type': 'guest', 'enabled': true}
            ]));
        expect(user.level, isNull);
        expect(user.creationTime, equals(user2Time));
      }

      {
        var user = await userAPIRepository.selectByID(3000);
        expect(user, isNull);
      }

      {
        var sel = await userAPIRepository.selectByEmail('joe@$testDomain');
        var user = sel.first;
        expect(user.email, equals('joe@$testDomain'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByEmail('smith@$testDomain');
        var user = sel.first;
        expect(user.email, equals('smith@$testDomain'));
        expect(user.address.state, equals('CA'));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('NY');

        var user = sel.first;
        expect(user.email, equals('joe@$testDomain'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByRoleType('admin');

        var user = sel.first;
        print(entityByReflection ? user.toJsonFromFields() : user.toJson());

        expect(user.email, equals('joe@$testDomain'));
        expect(user.address.state, equals('NY'));

        var sel2 = await userAPIRepository.selectByRole(user.roles.first);
        var user2 = sel2.first;
        expect(user2.id, equals(user.id));
      }

      {
        var sel = await userAPIRepository.selectByRoleType('guest');

        var user = sel.first;
        print(entityByReflection ? user.toJsonFromFields() : user.toJson());

        expect(user.email, equals('smith@$testDomain'));
        expect(user.address.state, equals('CA'));

        var sel2 = await userAPIRepository.selectByRole(user.roles.first);
        var user2 = sel2.first;
        expect(user2.id, equals(user.id));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('CA');

        var user = sel.first;
        expect(user.email, equals('smith@$testDomain'));
        expect(user.address.state, equals('CA'));

        user.email = 'smith2@$testDomain';

        var ok = await userAPIRepository.store(user);
        expect(ok, equals(user.id));
      }

      {
        var sel = await userAPIRepository.selectByEmail('smith2@$testDomain');

        var user = sel.first;
        expect(user.email, equals('smith2@$testDomain'));
        expect(user.address.state, equals('CA'));

        user.email = 'smith3@$testDomain';

        var ok = await userAPIRepository.store(user);
        expect(ok, equals(user.id));

        var sel2 = await userAPIRepository.selectByEmail('smith3@$testDomain');
        var user2 = sel2.first;

        expect(user2.id, equals(user.id));
        expect(user2.email, equals('smith3@$testDomain'));
      }

      {
        var transaction = Transaction();

        var result = await transaction.execute(() async {
          var sel = await userAPIRepository.selectByEmail('smith3@$testDomain');

          var user = sel.first;
          expect(user.email, equals('smith3@$testDomain'));
          expect(user.address.state, equals('CA'));

          user.email = 'smith4@$testDomain';
          var ok = await userAPIRepository.store(user);
          expect(ok, equals(user.id));

          var sel2 =
              await userAPIRepository.selectByEmail('smith4@$testDomain');
          var user2 = sel2.first;

          expect(user2.email, equals('smith4@$testDomain'));

          return user2.email;
        });

        print(transaction);

        expect(result, equals('smith4@$testDomain'));

        expect(transaction.isAborted, isFalse);
        expect(transaction.isCommitted, isTrue);
        expect(transaction.length, equals(10));
        expect(transaction.abortedError, isNull);
      }

      {
        var transaction = Transaction();

        var result = await transaction.execute(() async {
          try {
            var sel =
                await userAPIRepository.selectByEmail('smith4@$testDomain');

            var user = sel.first;
            expect(user.email, equals('smith4@$testDomain'));

            user.email = 'smith5@$testDomain';
            var ok = await userAPIRepository.store(user);
            expect(ok, equals(user.id));

            transaction.abort(reason: 'Test');
          } catch (e, s) {
            print(e);
            print(s);
          }
        });

        print(transaction);

        expect(result, isNull);

        expect(transaction.isAborted, isTrue);
        expect(transaction.isCommitted, isFalse);
        expect(transaction.length, equals(6));
        expect(transaction.abortedError, isNotNull);
        expect(transaction.abortedError?.reason, equals('Test'));
      }

      {
        var user = await userAPIRepository.selectByID(2);

        expect(user!.email, equals('smith4@$testDomain'));

        user.roles.add(Role('foo2'));

        var ok = await userAPIRepository.store(user);
        expect(ok, equals(user.id));

        var rolesJson2 = [
          {'id': 2, 'type': 'guest', 'enabled': true},
          {'id': 3, 'type': 'foo2', 'enabled': true}
        ];
        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals(rolesJson2));

        var user2 = await userAPIRepository.selectByID(user.id);
        expect(user2!.email, equals(user.email));
        expect(
            user2.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals(rolesJson2));

        user2.roles.removeWhere((r) => r.type == 'guest');

        var ok2 = await userAPIRepository.store(user2);
        expect(ok2, equals(user.id));

        var user3 = await userAPIRepository.selectByID(user.id);
        expect(user3!.email, equals(user.email));

        var rolesJson3 = [
          {'id': 3, 'type': 'foo2', 'enabled': true}
        ];
        expect(
            user3.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals(rolesJson3));
      }

      {
        var del = await userAPIRepository
            .deleteByQuery(' #ID == ? ', parameters: [2]);
        var user = del.first;
        expect(user.email, equals('smith4@$testDomain'));
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
