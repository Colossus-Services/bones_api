@Timeout(Duration(seconds: 180))
import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:bones_api/src/bones_api_logging.dart';
import 'package:docker_commander/docker_commander_vm.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';
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

TestEntityRepositoryProvider createEntityRepositoryProvider(
        bool entityByReflection,
        SQLAdapterCreator sqlAdapterCreator,
        int dbPort) =>
    TestEntityRepositoryProvider(
      entityByReflection
          ? Address$reflection().entityHandler
          : addressEntityHandler
        ..inspectObject(Address.empty()),
      entityByReflection ? Role$reflection().entityHandler : roleEntityHandler
        ..inspectObject(Role(RoleType.unknown)),
      entityByReflection ? User$reflection().entityHandler : userEntityHandler
        ..inspectObject(User('', '', Address.empty(), [])),
      sqlAdapterCreator,
      dbPort,
    );

abstract class DBTestContainer<D> {
  D? get containerHandler;

  FutureOr<bool> setupContainerHandler();

  FutureOr<bool> tearDownContainerHandler();

  Future<bool> start(int dbPort);

  Future<bool> waitReady();

  Future<String?> prepare() async => null;

  Future<String?> finalize() async => null;

  Future<bool> stop();

  Future<String?> runSQL(String sqlInline);

  Future<String?> createTableSQL(String sqlInline);

  Future<String> listTables();

  String get stdout;
}

abstract class DBTestContainerDocker
    implements DBTestContainer<DockerCommander> {
  @override
  DockerCommander? containerHandler;

  @override
  FutureOr<bool> setupContainerHandler() async {
    var dockerHostLocal = DockerHostLocal();
    var dockerCommander = DockerCommander(dockerHostLocal);
    await dockerCommander.ensureInitialized();

    _log.info('DockerCommander: $dockerCommander');

    var daemonOK = false;
    try {
      daemonOK = await dockerCommander.isDaemonRunning();
    } catch (_) {}

    containerHandler = dockerCommander;

    return daemonOK;
  }

  @override
  FutureOr<bool> tearDownContainerHandler() async {
    await containerHandler?.close();
    return true;
  }

  @override
  Future<String?> createTableSQL(String sqlInline) => runSQL(sqlInline);
}

void runAdapterTests(
    String dbName,
    DBTestContainer dbTestContainer,
    int dbPort,
    SQLAdapterCreator sqlAdapterCreator,
    String cmdQuote,
    String serialIntType,
    dynamic createTableMatcher,
    {required bool entityByReflection,
    TestEntityRepositoryProvider? defaultEntityRepositoryProvider}) {
  _log.handler.logToConsole();

  var testDomain = dbName.toLowerCase() + '.com';

  group('SQLAdapter[$dbName${entityByReflection ? '+reflection' : ''}]', () {
    late bool containerHandlerOK;
    late final TestEntityRepositoryProvider entityRepositoryProvider;

    setUpAll(() async {
      _log.info('[[[ setUpAll ]]]');

      containerHandlerOK = await dbTestContainer.setupContainerHandler();

      _log.info('Container Daemon: $containerHandlerOK');

      if (containerHandlerOK) {
        dbPort = (await getFreeListenPort(
            startPort: dbPort - 100, endPort: dbPort + 100))!;

        var startOk = await dbTestContainer.start(dbPort);

        _log.info('Container start: $startOk > $dbTestContainer');

        var prepareOutput = await dbTestContainer.prepare();

        _log.info('Prepare: $prepareOutput');

        entityRepositoryProvider = defaultEntityRepositoryProvider ??
            createEntityRepositoryProvider(
                entityByReflection, sqlAdapterCreator, dbPort);
      } else {
        _log.warning('Docker NOT running! Skipping Docker tests!');
      }
    });

    tearDownAll(() async {
      _log.info('[[[ tearDownAll ]]]');

      if (containerHandlerOK) {
        entityRepositoryProvider.close();

        var finalizeMsg = await dbTestContainer.finalize();
        _log.info('Finalize:\n$finalizeMsg');

        await dbTestContainer.stop();
        await dbTestContainer.tearDownContainerHandler();
      }
    });

    bool checkDockerRunning(String test) {
      if (!containerHandlerOK) {
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

      var process1 = await dbTestContainer.createTableSQL(sqlCreateAddress);
      expect(process1, createTableMatcher);

      var sqlCreateUser = '''
      CREATE TABLE IF NOT EXISTS ${q}user$q (
        ${q}id$q serial,
        ${q}email$q text NOT NULL,
        ${q}password$q text NOT NULL,
        ${q}address$q $serialIntType NOT NULL,
        ${q}level$q integer,
        ${q}wake_up_time$q time,
        ${q}creation_time$q timestamp NOT NULL,
        PRIMARY KEY( ${q}id$q ),
        CONSTRAINT user_ref_address_fk FOREIGN KEY (${q}address$q) REFERENCES ${q}address$q(${q}id$q)
      );
      ''';

      var process2 = await dbTestContainer.createTableSQL(sqlCreateUser);
      expect(process2, createTableMatcher);

      var sqlCreateRole = '''
      CREATE TABLE IF NOT EXISTS ${q}role$q (
        ${q}id$q serial,
        ${q}type$q text NOT NULL,
        ${q}enabled$q boolean NOT NULL,
        ${q}value$q decimal(10,4) NULL,
        PRIMARY KEY( ${q}id$q )
      );
      ''';

      var process3 = await dbTestContainer.createTableSQL(sqlCreateRole);
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

      var process4 = await dbTestContainer.createTableSQL(sqlCreateUserRole);
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

      var user1CreationTime = DateTime.utc(2021, 9, 20, 10, 11, 12, 0, 0);

      {
        var address = Address('NY', 'New York', 'street A', 101);

        var user = User(
            'joe@$testDomain', '123', address, [Role(RoleType.admin)],
            level: 100, creationTime: user1CreationTime);
        var id = await userAPIRepository.store(user);
        expect(id, equals(1));
      }

      var user2CreationTime = DateTime.utc(2021, 9, 21, 22, 11, 12, 0, 0);
      var user2WakeupTime = Time(9, 10, 11);

      {
        var address = Address('CA', 'Los Angeles', 'street B', 201);

        var user = User('smith@$testDomain', 'abc', address,
            [Role(RoleType.guest, value: Decimal.parse('123.45'))],
            wakeUpTime: user2WakeupTime, creationTime: user2CreationTime);
        var id = await userAPIRepository.store(user);
        expect(id, equals(2));

        var user2 = await userAPIRepository.selectByID(id);
        expect(user2!.wakeUpTime, equals(user2WakeupTime));

        user2.wakeUpTime = null;
        id = await userAPIRepository.store(user2);
        expect(id, equals(2));

        user2 = await userAPIRepository.selectByID(id);
        expect(user2!.wakeUpTime, isNull);

        user2.wakeUpTime = user2WakeupTime;
        id = await userAPIRepository.store(user2);
        expect(id, equals(2));

        user2 = await userAPIRepository.selectByID(id);
        expect(user2!.wakeUpTime, equals(user2WakeupTime));
      }

      var user3CreationTime = DateTime.utc(2021, 9, 22);
      var user3WakeupTime = Time(12, 10, 11);

      {
        var address = Address('CA', 'Los Angeles', 'street B', 101);

        var user = User('john@$testDomain', '456', address, [],
            wakeUpTime: user3WakeupTime, creationTime: user3CreationTime);
        var id = await userAPIRepository.store(user);
        expect(id, equals(3));
      }

      expect(await addressAPIRepository.length(), equals(3));
      expect(await userAPIRepository.length(), equals(3));

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user!.email, equals('joe@$testDomain'));
        expect(user.address.state, equals('NY'));
        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            equals([
              {'enabled': true, 'id': 1, 'type': 'admin', 'value': null}
            ]));
        expect(user.level, equals(100));
        expect(user.wakeUpTime, isNull);
        expect(user.creationTime, equals(user1CreationTime));

        var user2 =
            (await userAPIRepository.selectByEmail('joe@$testDomain')).first;
        expect(user2.toJsonEncoded(), equals(user.toJsonEncoded()));

        var user3 = (await userAPIRepository.select(
                Condition.parse('email == ?'),
                parameters: ['joe@$testDomain']))
            .first;
        expect(user3.toJsonEncoded(), equals(user.toJsonEncoded()));

        var user4 = (await userAPIRepository.select(
                Condition.parse('email == ?'),
                parameters: ['joex@$testDomain']))
            .firstOrNull;
        expect(user4, isNull);
      }

      {
        var user = await userAPIRepository.selectByID(2);
        expect(user!.email, equals('smith@$testDomain'));
        expect(user.address.state, equals('CA'));
        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            anyOf(
                equals([
                  {
                    'id': 2,
                    'type': 'guest',
                    'enabled': true,
                    'value': '123.4500'
                  }
                ]),
                equals([
                  {
                    'id': 2,
                    'type': 'guest',
                    'enabled': true,
                    'value': '123.45',
                  }
                ])));
        expect(user.level, isNull);
        expect(user.wakeUpTime, user2WakeupTime);
        expect(user.creationTime, equals(user2CreationTime));
      }

      {
        var user = await userAPIRepository.selectByID(3);
        expect(user!.email, equals('john@$testDomain'));
        expect(user.address.state, equals('CA'));
        expect(user.roles, isEmpty);
        expect(user.level, isNull);
        expect(user.wakeUpTime, user3WakeupTime);
        expect(user.creationTime, equals(user3CreationTime));
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
        var sel = await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

        expect(sel.length, equals(3));
        expect(sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']));
      }

      {
        var transaction = Transaction();

        var result = await transaction.execute(() async {
          var sel =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel.length, equals(3));
          expect(sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          var sel2 =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel2.length, equals(3));
          expect(sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          return sel2;
        });

        print(transaction);

        expect(result!.length, equals(3));
        expect(transaction.length, equals(5));
        expect(transaction.cachedEntitiesLength, equals(8));
      }

      {
        var transaction = Transaction();

        var result = await transaction.execute(() async {
          var sel =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel.length, equals(3));
          expect(sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          var user1 = sel.first;

          user1.level = 123;

          var storeId = await userAPIRepository.store(user1);
          expect(storeId, equals(user1.id));

          var sel2 =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel2.length, equals(3));
          expect(sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          return sel2;
        });

        print(transaction);

        expect(result!.length, equals(3));
        expect(transaction.length, equals(7));
        expect(transaction.cachedEntitiesLength, equals(8));
      }

      {
        var transaction = Transaction();

        var result = await transaction.execute(() async {
          var sel =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel.length, equals(3));
          expect(sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          var user1 = sel.firstWhere((e) => e.address.state == 'NY');

          user1.address.city = 'Jersey City';

          var storeId = await userAPIRepository.store(user1);
          expect(storeId, equals(user1.id));

          var sel2 =
              await userAPIRepository.selectByINAddressStates(['NY', 'CA']);

          expect(sel2.length, equals(3));
          expect(sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']));

          var user2 = sel.firstWhere((e) => e.address.state == 'NY');

          expect(user2.address.city, equals('Jersey City'));

          return sel2;
        });

        print(transaction);

        expect(result!.length, equals(3));
        expect(transaction.length, equals(8));
        expect(transaction.cachedEntitiesLength, equals(8));
      }

      {
        var sel = await userAPIRepository
            .selectByINAddressStates(['NY', 'CA', 'N/A']);

        expect(sel.length, equals(3));
        expect(sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']));
        expect(sel.map((e) => e.address.city),
            unorderedEquals(['Los Angeles', 'Los Angeles', 'Jersey City']));
      }

      {
        var sel = await userAPIRepository.selectByINAddressStates(['NY']);

        expect(sel.length, equals(1));
        expect(sel.map((e) => e.address.state), equals(['NY']));
      }

      {
        var sel =
            await userAPIRepository.selectByINAddressStatesSingleValue('CA');

        expect(sel.length, equals(2));
        expect(sel.map((e) => e.address.state), unorderedEquals(['CA', 'CA']));
      }

      {
        var sel = await userAPIRepository.selectByINAddressStates(
            ['NY', 'CA', ...List.generate(10, (i) => '$i')]);

        expect(sel.length, equals(3));
        expect(sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']));
      }

      {
        var sel = await userAPIRepository.selectByINAddressStates(
            ['NY', 'CA', ...List.generate(100, (i) => '$i')]);

        expect(sel.length, equals(3));
        expect(sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']));
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
          var executingTransaction = Transaction.executingTransaction;
          expect(executingTransaction, isNotNull);
          expect(executingTransaction!.isEmpty, isTrue);

          var sel = await userAPIRepository.selectByEmail('smith3@$testDomain');

          expect(executingTransaction.isNotEmpty, isTrue);

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

        expect(transaction.isOpen, isTrue);
        expect(transaction.isAborted, isFalse);
        expect(transaction.isCommitted, isTrue);
        expect(transaction.length, equals(7));
        expect(transaction.abortedError, isNull);
      }

      // If `Transaction.abort` is supported:
      if (entityRepositoryProvider.sqlAdapter.capability.transactionAbort) {
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

        expect(transaction.isOpen, isTrue);
        expect(transaction.isAborted, isTrue);
        expect(transaction.isCommitted, isFalse);
        expect(transaction.length, equals(6));
        expect(transaction.abortedError, isNotNull);
        expect(transaction.abortedError?.reason, equals('Test'));
      }

      {
        var user = await userAPIRepository.selectByID(2);

        expect(user!.email, equals('smith4@$testDomain'));

        user.roles.add(Role(RoleType.unknown));

        var ok = await userAPIRepository.store(user);
        expect(ok, equals(user.id));

        var rolesJson2a = [
          {'id': 2, 'type': 'guest', 'enabled': true, 'value': '123.4500'},
          {'id': 3, 'type': 'unknown', 'enabled': true, 'value': null}
        ];

        var rolesJson2b = [
          {'id': 2, 'type': 'guest', 'enabled': true, 'value': '123.45'},
          {'id': 3, 'type': 'unknown', 'enabled': true, 'value': null}
        ];

        expect(
            user.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            anyOf(equals(rolesJson2a), equals(rolesJson2b)));

        var user2 = await userAPIRepository.selectByID(user.id);
        expect(user2!.email, equals(user.email));
        expect(
            user2.roles.map(
                (e) => entityByReflection ? e.toJsonFromFields() : e.toJson()),
            anyOf(equals(rolesJson2a), equals(rolesJson2b)));

        user2.roles.removeWhere((r) => r.type == RoleType.guest);

        var ok2 = await userAPIRepository.store(user2);
        expect(ok2, equals(user.id));

        var user3 = await userAPIRepository.selectByID(user.id);
        expect(user3!.email, equals(user.email));

        var rolesJson3 = [
          {'id': 3, 'type': 'unknown', 'enabled': true, 'value': null}
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
        expect(user.wakeUpTime, equals(user2WakeupTime));
        expect(user.creationTime, equals(user2CreationTime));
      }

      expect(await userAPIRepository.length(), equals(2));

      {
        var user = await userAPIRepository.selectByID(2);
        expect(user, isNull);
      }

      {
        var del1 = await userAPIRepository.delete(
            Condition.parse(' email == ? '),
            parameters: {'email': 'joex@$testDomain'});
        expect(del1, isEmpty);

        var del2 = await userAPIRepository.delete(
            Condition.parse(' email == ? '),
            parameters: {'email': 'joe@$testDomain'});
        expect(del2.length, equals(1));
        expect(del2.first.email, equals('joe@$testDomain'));
      }

      {
        var address1 = await addressAPIRepository.storeFromJson({
          'state': 'EX',
          'city': 'Extra',
          'street': 'Street x',
          'number': 888
        });

        expect(address1, isNotNull);
        expect(address1.id, isNotNull);
        expect(address1.number, 888);

        var address2 = await addressAPIRepository.selectByID(address1.id);
        expect(address2!.toJsonEncoded(), equals(address1.toJsonEncoded()));
      }

      {
        var address1 = await addressAPIRepository.storeFromJson({
          'id': 11001,
          'state': 'EX',
          'city': 'Extra',
          'street': 'Street x',
          'number': 999
        });

        expect(address1, isNotNull);
        expect(address1.id, 11001);
        expect(address1.number, 999);

        var address2 = await addressAPIRepository.selectByID(address1.id);
        expect(address2!.toJsonEncoded(), equals(address1.toJsonEncoded()));
      }
    });
  });
}
