import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api_logging.dart';
import 'package:bones_api/bones_api_test_vm.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';
import 'bones_api_test_entities_orders.dart';

final _log = logging.Logger('bones_api_test_adapter');

typedef DBAdapterCreator<A extends DBAdapter> = A Function(
  EntityRepositoryProvider? parentRepositoryProvider,
  int dbPort,
  Map<String, dynamic>? dbConfig,
);

class TestEntityRepositoryProvider extends DBSQLEntityRepositoryProvider {
  final DBAdapterCreator<DBSQLAdapter> sqlAdapterCreator;
  final int dbPort;
  final Map<String, dynamic>? dbConfig;

  final EntityHandler<Store> storeEntityHandler;
  final EntityHandler<Address> addressEntityHandler;
  final EntityHandler<Role> roleEntityHandler;
  final EntityHandler<UserInfo> userInfoEntityHandler;
  final EntityHandler<User> userEntityHandler;

  final EntityHandler<CampaignConfig> campaignConfigEntityHandler;
  final EntityHandler<Campaign> campaignEntityHandler;
  final EntityHandler<Bonus> bonusEntityHandler;
  final EntityHandler<Item> itemEntityHandler;
  final EntityHandler<Order> orderEntityHandler;

  late final StoreAPIRepository storeAPIRepository;
  late final AddressAPIRepository addressAPIRepository;
  late final RoleAPIRepository roleAPIRepository;
  late final UserInfoAPIRepository userInfoAPIRepository;
  late final UserAPIRepository userAPIRepository;

  late final CampaignConfigAPIRepository campaignConfigAPIRepository;
  late final CampaignAPIRepository campaignAPIRepository;
  late final BonusAPIRepository bonusAPIRepository;
  late final ItemAPIRepository itemAPIRepository;
  late final OrderAPIRepository orderAPIRepository;

  TestEntityRepositoryProvider(
    this.storeEntityHandler,
    this.addressEntityHandler,
    this.roleEntityHandler,
    this.userInfoEntityHandler,
    this.userEntityHandler,
    this.campaignConfigEntityHandler,
    this.campaignEntityHandler,
    this.bonusEntityHandler,
    this.itemEntityHandler,
    this.orderEntityHandler,
    this.sqlAdapterCreator,
    this.dbPort,
    this.dbConfig,
  );

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBSQLAdapter<Object>> buildAdapter() =>
      sqlAdapterCreator(this, dbPort, dbConfig);

  List<DBSQLEntityRepository<Object>>? _repositories;

  @override
  List<DBSQLEntityRepository<Object>> buildRepositories(
    DBSQLAdapter<Object> adapter,
  ) {
    return _repositories ??= [
      DBSQLEntityRepository<Store>(adapter, 'store', storeEntityHandler),
      DBSQLEntityRepository<Address>(adapter, 'address', addressEntityHandler),
      DBSQLEntityRepository<Role>(adapter, 'role', roleEntityHandler),
      DBSQLEntityRepository<UserInfo>(
        adapter,
        'user_info',
        userInfoEntityHandler,
      ),
      DBSQLEntityRepository<User>(adapter, 'user', userEntityHandler),
      // Order-related tables
      DBSQLEntityRepository<CampaignConfig>(
        adapter,
        'campaign_config',
        campaignConfigEntityHandler,
      ),
      DBSQLEntityRepository<Campaign>(
        adapter,
        'campaign',
        campaignEntityHandler,
      ),
      DBSQLEntityRepository<Bonus>(adapter, 'bonus', bonusEntityHandler),
      DBSQLEntityRepository<Item>(adapter, 'item', itemEntityHandler),
      DBSQLEntityRepository<Order>(adapter, 'order', orderEntityHandler),
    ].asUnmodifiableListView();
  }

  @override
  FutureOr<List<Initializable>> extraDependencies() => [
    storeAPIRepository = StoreAPIRepository(this),
    addressAPIRepository = AddressAPIRepository(this),
    roleAPIRepository = RoleAPIRepository(this),
    userInfoAPIRepository = UserInfoAPIRepository(this),
    userAPIRepository = UserAPIRepository(this),
    // Order related repositories
    campaignConfigAPIRepository = CampaignConfigAPIRepository(this),
    campaignAPIRepository = CampaignAPIRepository(this),
    bonusAPIRepository = BonusAPIRepository(this),
    itemAPIRepository = ItemAPIRepository(this),
    orderAPIRepository = OrderAPIRepository(this),
  ];
}

class TestEntityRepositoryProvider2 extends DBEntityRepositoryProvider {
  final DBAdapterCreator<DBAdapter> objectAdapterCreator;
  final int dbPort;
  final Map<String, dynamic>? dbConfig;

  final EntityHandler<Photo> photoEntityHandler;

  late final PhotoAPIRepository photoAPIRepository;

  TestEntityRepositoryProvider2(
    this.photoEntityHandler,
    this.objectAdapterCreator,
    this.dbPort,
    this.dbConfig,
  );

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBAdapter<Object>> buildAdapter() =>
      objectAdapterCreator(this, dbPort, dbConfig);

  List<DBEntityRepository<Object>>? _repositories;

  @override
  List<DBEntityRepository<Object>> buildRepositories(
    DBAdapter<Object> adapter,
  ) {
    return _repositories ??= [
      DBEntityRepository<Photo>(adapter, 'photo', photoEntityHandler),
    ].asUnmodifiableListView();
  }

  @override
  FutureOr<List<Initializable>> extraDependencies() => [
    photoAPIRepository = PhotoAPIRepository(this),
  ];
}

TestEntityRepositoryProvider createEntityRepositoryProvider(
  bool entityByReflection,
  DBAdapterCreator<DBSQLAdapter> sqlAdapterCreator,
  int dbPort,
  Map<String, dynamic>? dbConfig,
) => entityByReflection
    ? TestEntityRepositoryProvider(
        Store$reflection().entityHandler,
        Address$reflection().entityHandler,
        Role$reflection().entityHandler,
        UserInfo$reflection().entityHandler,
        User$reflection().entityHandler,
        CampaignConfig$reflection().entityHandler,
        Campaign$reflection().entityHandler,
        Bonus$reflection().entityHandler,
        Item$reflection().entityHandler,
        Order$reflection().entityHandler,
        sqlAdapterCreator,
        dbPort,
        dbConfig,
      )
    : TestEntityRepositoryProvider(
        storeEntityHandler..inspectObject(Store.empty()),
        addressEntityHandler..inspectObject(Address.empty()),
        roleEntityHandler..inspectObject(Role.empty()),
        userInfoEntityHandler..inspectObject(UserInfo.empty()),
        userEntityHandler..inspectObject(User.empty()),
        campaignConfigEntityHandler..inspectObject(CampaignConfig.empty()),
        campaignEntityHandler..inspectObject(Campaign.empty()),
        bonusEntityHandler..inspectObject(Bonus.empty()),
        itemEntityHandler..inspectObject(Item.empty()),
        orderEntityHandler..inspectObject(Order.empty()),
        sqlAdapterCreator,
        dbPort,
        dbConfig,
      );

TestEntityRepositoryProvider2 createEntityRepositoryProvider2(
  bool entityByReflection,
  DBAdapterCreator<DBAdapter> objectAdapterCreator,
  int dbPort,
  Map<String, dynamic>? dbConfig,
) => entityByReflection
    ? TestEntityRepositoryProvider2(
        Photo$reflection().entityHandler,
        objectAdapterCreator,
        dbPort,
        dbConfig,
      )
    : TestEntityRepositoryProvider2(
        photoEntityHandler..inspectObject(Photo.empty()),
        objectAdapterCreator,
        dbPort,
        dbConfig,
      );

const String png1PixelBase64 =
    'R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==';

const String png1PixelSha256 =
    'b1442e85b03bdcaf66dc58c7abb98745dd2687d86350be9a298a1d9382ac849b';

/// The suggested SQLs of a `checkDBTables` error (its `Suggestion of SQLs`),
/// without the comments.
List<String> _suggestedSQLs(String errorMessage) {
  var idx = errorMessage.indexOf('Suggestion of SQLs');
  if (idx < 0) return [];

  return errorMessage
      .substring(idx)
      .split('\n')
      .skip(1)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('--'))
      .toList();
}

/// `checkDBTables` fails, and its suggested SQLs ([expectedSQLs] among them)
/// fix it in this DB: it passes after running them.
Future<void> _checkFixedBySuggestedSQLs(
  DBSQLAdapter sqlAdapter,
  APITestConfigDBSQL testConfigSQL, {
  List<String> expectedSQLs = const [],
}) async {
  String? error;
  try {
    await sqlAdapter.checkDBTables(force: true);
  } on StateError catch (e) {
    error = e.message;
  }

  expect(error, isNotNull, reason: 'checkDBTables should fail');

  var sqls = _suggestedSQLs(error!);
  expect(sqls, isNotEmpty, reason: error);

  for (var expected in expectedSQLs) {
    expect(sqls.join('\n'), contains(expected), reason: error);
  }

  for (var sql in sqls) {
    await testConfigSQL.runSQL(sql);
  }

  expect(await sqlAdapter.checkDBTables(force: true), isTrue);
}

Future<bool> runAdapterTests(
  String dbName,
  APITestConfigDB testConfigDB,
  DBAdapterCreator<DBSQLAdapter> sqlAdapterCreator,
  DBAdapterCreator<DBAdapter> objectAdapterCreator,
  String cmdQuote,
  String serialIntType, {
  required bool entityByReflection,
  required bool checkTables,
  required bool generateTables,
  required bool populateSource,
  Map<String, Future<void> Function(DBSQLAdapter sqlAdapter)>? adapterTests,
}) async {
  _log.handler.logToConsole();
  LoggerHandler.disableLogQueue();

  User$reflection.boot();

  final testLog = logging.Logger(
    'TEST:SQLAdapter:$dbName${entityByReflection ? '+reflection' : ''}',
  );

  testLog.info('[[[ Checking $testConfigDB ]]]');

  var configSupported = await testConfigDB.resolveSupported();

  if (!configSupported) {
    testLog.warning(
      '[[[ ${testConfigDB.unsupportedReason} -> Skipping tests ]]]',
    );
  }

  var testDomain = '${dbName.toLowerCase()}.com';

  group(
    'SQLAdapter[$dbName${entityByReflection ? '+reflection' : ''}${generateTables ? '+generateTables' : ''}${checkTables ? '+checkTables' : ''}${populateSource ? '+populateSource' : ''}]',
    () {
      late final TestEntityRepositoryProvider entityRepositoryProvider;
      late final TestEntityRepositoryProvider2 entityRepositoryProvider2;

      setUpAll(() async {
        testLog.info('[[[ setUpAll ]]]');

        expect(configSupported, isTrue);

        var startOk = await testConfigDB.start();

        var dbPort = await testConfigDB.dbPort;

        testLog.info(
          'Container start: $startOk > dbPort: $dbPort > $testConfigDB',
        );

        var dbConfig = testConfigDB.apiConfigMap['db'] as Map<String, dynamic>?;

        if (populateSource) {
          dbConfig?['populate'] ??= {
            'source': {
              'user_info': {'info': '%SECRET_KEY%', 'id': 1},
            },
            'variables': {'SECRET_KEY': 'abc123xyz'},
          };
        }

        entityRepositoryProvider = createEntityRepositoryProvider(
          entityByReflection,
          sqlAdapterCreator,
          dbPort,
          dbConfig,
        );

        entityRepositoryProvider2 = createEntityRepositoryProvider2(
          entityByReflection,
          objectAdapterCreator,
          dbPort,
          dbConfig,
        );

        await entityRepositoryProvider2.ensureInitialized();
        await entityRepositoryProvider.ensureInitialized();

        var sqlAdapter = await entityRepositoryProvider.adapter;
        await sqlAdapter.ensureInitialized();

        expect(
          sqlAdapter.isInitialized,
          isTrue,
          reason: "`DBSQLAdapter` not initialized: $sqlAdapter",
        );

        if (checkTables) {
          var checkOK = await sqlAdapter.checkDBTables();
          expect(checkOK, isTrue, reason: "sqlAdapter.checkDBTables()");
        }

        await Future.delayed(Duration(seconds: 1));
      });

      tearDownAll(() async {
        testLog.info('[[[ tearDownAll ]]]');

        expect(configSupported, isTrue);

        entityRepositoryProvider.close();
        entityRepositoryProvider2.close();

        await testConfigDB.stop();
      });

      test('initialization: the providers, adapter and repositories', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;

        void expectInitialized(Initializable o) {
          var status = o.initializationStatus;
          expect(o.isInitialized, isTrue, reason: '$status');
          expect(o.isInitializing, isFalse, reason: '$status');
          expect(status.failed, isFalse, reason: '$status');
          expect(status.error, isNull, reason: '$status');
        }

        expectInitialized(entityRepositoryProvider);
        expectInitialized(entityRepositoryProvider2);
        expectInitialized(sqlAdapter);

        var repositories = entityRepositoryProvider.allRepositories().values;
        expect(repositories, isNotEmpty);
        for (var r in repositories) {
          expectInitialized(r);
        }

        // The cyclic dependencies (not waited in the cycle): also done.
        for (var o in <Initializable>[
          entityRepositoryProvider,
          sqlAdapter,
          ...repositories,
        ]) {
          for (var dep in o.cyclicDependencies) {
            expectInitialized(dep);
          }
        }

        // Already initialized: synchronous, the same attempt (no new one).
        var id = entityRepositoryProvider.initializationStatus.id;
        var result = entityRepositoryProvider.ensureInitialized();
        expect(result, isA<InitializationResult>());
        expect((result as InitializationResult).ok, isTrue);
        expect(result.cyclic, isFalse);
        expect(entityRepositoryProvider.initializationStatus.id, id);

        // The provider's dependencies: its adapter and repositories.
        expect(result.dependencies, contains(sqlAdapter));

        // A repository's dependencies: its adapter and repository adapter,
        // not the other repositories (no clique of every repository waiting
        // for every other).
        var repositoriesSet = repositories.toSet();
        for (var r in repositories) {
          var deps =
              (r.ensureInitialized() as InitializationResult).dependencies;
          expect(deps, isNotEmpty, reason: '$r');
          expect(
            deps.where((d) => d != r && repositoriesSet.contains(d)),
            isEmpty,
            reason: '$r -> $deps',
          );
        }

        // Initialized: the same result instance on every call.
        expect(
          identical(
            entityRepositoryProvider.ensureInitialized(),
            entityRepositoryProvider.ensureInitialized(),
          ),
          isTrue,
        );

        // Checks and executions: synchronous, no error.
        sqlAdapter.checkInitialized();
        expect(sqlAdapter.executeInitialized(() => 123), 123);
        for (var r in repositories) {
          r.checkInitialized();
        }
      });

      test('generateFullCreateTableSQLs', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        expect(sqlAdapter, isNotNull);

        var dialect = sqlAdapter.dialect;

        expect(sqlAdapter.isInitialized, isTrue);
        expect(sqlAdapter.generatedTables, generateTables);
        expect(sqlAdapter.checkedTables, checkTables);

        var fullCreateTableSQLs = await sqlAdapter.generateFullCreateTableSQLs(
          title: 'Test Generated SQL',
          withDate: false,
        );

        print(fullCreateTableSQLs);

        expect(fullCreateTableSQLs, contains('-- Test Generated SQL'));
        expect(
          fullCreateTableSQLs,
          contains('-- SQLAdapter: ${sqlAdapter.runtimeType}'),
        );
        expect(
          fullCreateTableSQLs,
          contains('-- Dialect: ${sqlAdapter.dialect.name}'),
        );
        expect(
          fullCreateTableSQLs,
          contains('-- Generator: BonesAPI/${BonesAPI.VERSION}'),
        );

        expect(fullCreateTableSQLs, contains('-- Entity: Address @ address'));

        var q = sqlAdapter.dialect.elementQuote;
        var reS = r'(?:\s+|--[^\n]+\n?)+';
        var reAnyType = r'\w+[^\n]*?';
        var reArg = r'(?:\([^ \t\(\)]+\))';
        // SQLite declares an auto-assigning ID as `INTEGER PRIMARY KEY
        // AUTOINCREMENT` (it has no `SERIAL`/`AUTO_INCREMENT`).
        var rePK = r'PRIMARY KEY(?:\s+AUTOINCREMENT)?';

        var tableAddressRegexp = RegExp(
          'CREATE TABLE IF NOT EXISTS ${q}address$q \\($reS'
          '${q}id$q $reAnyType $rePK,$reS'
          '${q}city$q VARCHAR$reArg?,$reS'
          '${q}latitude$q DECIMAL$reArg?,$reS'
          '${q}longitude$q DECIMAL$reArg?,$reS'
          '${q}number$q INT,$reS'
          '${q}state$q VARCHAR$reArg?,$reS'
          '${q}street$q VARCHAR$reArg?$reS'
          '\\)$reS;',
        );

        expect(
          fullCreateTableSQLs,
          contains(tableAddressRegexp),
          reason: "`address` table SQL",
        );

        var indexAddressRegexp = RegExp(
          [
            'CREATE INDEX',
            if (dialect.createIndexIfNotExists) 'IF NOT EXISTS',
            '${q}address__state__idx$q ON',
            '${q}address$q \\(${q}state$q\\)',
          ].join(' '),
        );

        expect(
          fullCreateTableSQLs,
          contains(indexAddressRegexp),
          reason: "`address` index SQL",
        );

        var tableRoleRegexp = RegExp(
          'CREATE TABLE IF NOT EXISTS ${q}role$q \\($reS'
          '${q}id$q $reAnyType $rePK,$reS'
          '${q}enabled$q BOOLEAN,$reS'
          '${q}type$q $reAnyType,$reS'
          '${q}value$q DECIMAL$reArg?$reS'
          '\\)$reS;',
        );

        expect(
          fullCreateTableSQLs,
          contains(tableRoleRegexp),
          reason: "`role` table SQL",
        );

        var tableUserRegexp = RegExp(
          'CREATE TABLE IF NOT EXISTS ${q}user$q \\(\\s*'
          '${q}id$q $reAnyType $rePK,\\s*'
          '${q}address$q BIGINT[^,\\n]*?,\\s*'
          '${q}creation_time$q TIMESTAMP,\\s*'
          '${q}email$q VARCHAR$reArg?,\\s*'
          '${q}level$q INT,\\s*'
          '${q}password$q VARCHAR$reArg?,\\s*'
          '${q}photo$q VARCHAR$reArg?,\\s*'
          '${q}user_info$q BIGINT[^,\\n]*?,\\s*'
          '${q}wake_up_time$q TIME[^,\\n]*?,\\s*'
          'CONSTRAINT',
        );

        print('-- Checking `user` table SQL...');

        var fullCreateTableSQLsNoComments = fullCreateTableSQLs.replaceAll(
          RegExp(r'--[^\n]+'),
          '',
        );

        expect(
          fullCreateTableSQLsNoComments,
          contains(tableUserRegexp),
          reason: "`user` table SQL",
        );

        var tableUserUniqueRegexp = RegExp('UNIQUE\\s\\(${q}email$q\\)');

        expect(
          fullCreateTableSQLs,
          contains(tableUserUniqueRegexp),
          reason: "`user.email` unique SQL",
        );

        print('-- Tables SQL OK');
      });

      test('sqlAdapter', () async {
        _log.info('APITestConfigDB: $testConfigDB');

        expect(testConfigDB.isStarted, isTrue);

        var sqlAdapter = await entityRepositoryProvider.adapter;
        expect(sqlAdapter, isNotNull);

        _log.info('SQLDialect: ${sqlAdapter.dialect}');

        expect(sqlAdapter.capability.transactions, isTrue);
        expect(sqlAdapter.capability.transactionAbort, isTrue);
        expect(sqlAdapter.capability.fullTransaction, isTrue);

        expect(
          DBAdapter.registeredAdaptersNames.contains(sqlAdapter.name),
          isTrue,
        );

        expect(
          DBAdapter.registeredAdaptersTypes.contains(sqlAdapter.runtimeType),
          isTrue,
        );
      });

      test('objectAdapter', () async {
        _log.info('APITestConfigDB: $testConfigDB');

        expect(testConfigDB.isStarted, isTrue);

        var objectAdapter = await entityRepositoryProvider2.adapter;
        expect(objectAdapter, isNotNull);

        _log.info('ObjectDialect: ${objectAdapter.dialect}');

        expect(objectAdapter.capability.transactions, isTrue);
        expect(objectAdapter.capability.transactionAbort, isTrue);
        expect(objectAdapter.capability.fullTransaction, isTrue);

        expect(
          DBAdapter.registeredAdaptersNames.contains(objectAdapter.name),
          isTrue,
        );

        expect(
          DBAdapter.registeredAdaptersTypes.contains(objectAdapter.runtimeType),
          isTrue,
        );
      });

      test('create table', () async {
        if (testConfigDB is! APITestConfigDBSQL) {
          _log.info(
            "Not a `APITestConfigDBSQL`: skipping table creation SQLs.",
          );
          return;
        }

        expect(testConfigDB.isStarted, isTrue);

        if (testConfigDB is APITestConfigDocker) {
          var testConfigDocker = testConfigDB as APITestConfigDocker;
          print('----------------------------------------------');
          print(testConfigDocker.stdout);
          print('----------------------------------------------');
        }

        var sqlAdapter = await entityRepositoryProvider.adapter;
        expect(sqlAdapter, isA<DBSQLAdapter>());

        var fullCreateTableSQLs = await sqlAdapter.generateFullCreateTableSQLs(
          title: 'Test Generated SQL',
          withDate: false,
        );

        var tables = await sqlAdapter.populateTables(fullCreateTableSQLs);

        _log.info("Populated tables: $tables");

        expect(
          tables,
          allOf(
            contains('address'),
            contains('user'),
            contains('role'),
            contains('address__stores__rel'),
            contains('address__closed_stores__rel'),
            contains('user__roles__rel'),
          ),
        );

        var tablesNames = await testConfigDB.listTables();

        _log.info("Created tables: $tablesNames");

        expect(
          tablesNames,
          allOf(
            contains('address'),
            contains('user'),
            contains('role'),
            contains('address__stores__rel'),
            contains('address__closed_stores__rel'),
            contains('user__roles__rel'),
          ),
        );
      });

      test('checkTables: a missing column (the suggested SQL runs)', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        var q = sqlAdapter.dialect.elementQuote;

        if (testConfigDB is! APITestConfigDBSQL) {
          _log.info("Not a `APITestConfigDBSQL`: skipping.");
          return;
        }

        var testConfigSQL = testConfigDB;

        // Independent of the other tests (e.g. run alone): the tables are
        // created if not yet.
        sqlAdapter.disposeTableSchemeCache('store');
        if (await sqlAdapter.getTableScheme('store') == null) {
          await sqlAdapter.populateTables(
            await sqlAdapter.generateFullCreateTableSQLs(withDate: false),
          );
        }

        sqlAdapter.disposeTableSchemeCache('store');
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        // `store.number` missing (renamed: its values kept):
        await testConfigSQL.runSQL(
          'ALTER TABLE ${q}store$q RENAME COLUMN ${q}number$q TO '
          '${q}number_tmp$q',
        );
        sqlAdapter.disposeTableSchemeCache('store');

        // The suggested `ADD COLUMN` runs in this DB (MySQL and SQLite: no
        // `IF NOT EXISTS`):
        var ifNotExists = sqlAdapter.dialect.alterTableAddColumnIfNotExists;
        await _checkFixedBySuggestedSQLs(
          sqlAdapter,
          testConfigSQL,
          expectedSQLs: [
            ifNotExists
                ? 'ADD COLUMN IF NOT EXISTS ${q}number$q'
                : 'ADD COLUMN ${q}number$q',
          ],
        );

        // The original column back:
        await testConfigSQL.runSQL(
          'ALTER TABLE ${q}store$q DROP COLUMN ${q}number$q',
        );
        await testConfigSQL.runSQL(
          'ALTER TABLE ${q}store$q RENAME COLUMN ${q}number_tmp$q TO '
          '${q}number$q',
        );
        sqlAdapter.disposeTableSchemeCache('store');
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
      });

      test(
        'generateTables: an existing table missing an indexed column',
        () async {
          var sqlAdapter = await entityRepositoryProvider.adapter;
          var q = sqlAdapter.dialect.elementQuote;

          if (testConfigDB is! APITestConfigDBSQL) {
            _log.info("Not a `APITestConfigDBSQL`: skipping.");
            return;
          }

          var testConfigSQL = testConfigDB;

          var fullCreateTableSQLs = await sqlAdapter
              .generateFullCreateTableSQLs(withDate: false);

          // Independent of the other tests (e.g. run alone): the tables are
          // created if not yet.
          sqlAdapter.disposeTableSchemeCache('address');
          if (await sqlAdapter.getTableScheme('address') == null) {
            await sqlAdapter.populateTables(fullCreateTableSQLs);
          }

          sqlAdapter.disposeTableSchemeCache('address');
          expect(await sqlAdapter.checkDBTables(force: true), isTrue);

          var isMySQL = sqlAdapter.dialect.name.toLowerCase().contains('mysql');

          // The indexes over `address.city` (if present):
          Future<void> dropCityIndexes() async {
            sqlAdapter.disposeTableSchemeCache('address');
            var scheme = (await sqlAdapter.getTableScheme('address'))!;
            var cityIndexes = scheme.indexes!.entries
                .where((e) => e.value.contains('city'))
                .map((e) => e.key);
            for (var name in cityIndexes) {
              await testConfigSQL.runSQL(
                isMySQL
                    ? 'DROP INDEX $q$name$q ON ${q}address$q'
                    : 'DROP INDEX $q$name$q',
              );
            }
            sqlAdapter.disposeTableSchemeCache('address');
          }

          // A table created before `city` was added to the entity: `city`
          // (renamed: its values kept) and its indexes missing.
          await dropCityIndexes();
          await testConfigSQL.runSQL(
            'ALTER TABLE ${q}address$q RENAME COLUMN ${q}city$q TO '
            '${q}city_tmp$q',
          );
          sqlAdapter.disposeTableSchemeCache('address');

          try {
            if (sqlAdapter.dialect.createIndexIfNotExists) {
              // `checkTables` not pending (already checked): an error naming
              // the missing column (not only the DB error).
              await expectLater(
                () async =>
                    await sqlAdapter.populateTables(fullCreateTableSQLs),
                throwsA(
                  isA<StateError>().having(
                    (e) => e.message,
                    'message',
                    contains(
                      'table `address` exists without the columns [city]',
                    ),
                  ),
                ),
              );
            } else {
              // MySQL (no `CREATE INDEX IF NOT EXISTS`): the `CREATE INDEX`
              // errors are ignored.
              expect(
                await sqlAdapter.populateTables(fullCreateTableSQLs),
                contains('address'),
              );
            }

            // SQLite: a new adapter is another database (in memory) and
            // replaces the test config's one (see `bones_api_cov_sqlite_test`).
            var isSQLite = sqlAdapter.dialect.name.toLowerCase().contains(
              'sqlite',
            );

            if (generateTables && checkTables && !isSQLite) {
              // A new provider, as at boot: `generateTables` passes, and
              // `checkTables` reports the missing column, with the SQLs to fix
              // it (also its indexes).
              var dbConfig = Map<String, dynamic>.of(
                testConfigDB.apiConfigMap['db'] as Map<String, dynamic>,
              )..remove('populate');

              var provider = createEntityRepositoryProvider(
                entityByReflection,
                sqlAdapterCreator,
                await testConfigDB.dbPort,
                dbConfig,
              );

              try {
                // Its initialization fails (logged): at `checkTables`.
                await provider.ensureInitialized();
                var adapter = await provider.adapter;

                expect(adapter.generatedTables, isTrue);
                expect(adapter.checkedTables, isFalse);
              } finally {
                provider.close();
              }
            }

            // The suggested SQLs fix it (also the `city` indexes):
            var ifNotExists = sqlAdapter.dialect.alterTableAddColumnIfNotExists;
            await _checkFixedBySuggestedSQLs(
              sqlAdapter,
              testConfigSQL,
              expectedSQLs: [
                ifNotExists
                    ? 'ADD COLUMN IF NOT EXISTS ${q}city$q'
                    : 'ADD COLUMN ${q}city$q',
                '${q}address__city__idx$q ON ${q}address$q (${q}city$q)',
              ],
            );
          } finally {
            // The original column (and indexes) back:
            await dropCityIndexes();
            var scheme = (await sqlAdapter.getTableScheme('address'))!;
            if (scheme.fieldsNames.contains('city')) {
              await testConfigSQL.runSQL(
                'ALTER TABLE ${q}address$q DROP COLUMN ${q}city$q',
              );
            }
            await testConfigSQL.runSQL(
              'ALTER TABLE ${q}address$q RENAME COLUMN ${q}city_tmp$q TO '
              '${q}city$q',
            );
            sqlAdapter.disposeTableSchemeCache('address');
            await sqlAdapter.populateTables(fullCreateTableSQLs);
            sqlAdapter.disposeTableSchemeCache('address');
          }

          expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        },
      );

      test('store: insert, multiple and partial updates', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;

        // Independent of the other tests (e.g. run alone): the tables are
        // created if not yet.
        sqlAdapter.disposeTableSchemeCache('store');
        if (await sqlAdapter.getTableScheme('store') == null) {
          await sqlAdapter.populateTables(
            await sqlAdapter.generateFullCreateTableSQLs(withDate: false),
          );
        }

        final storeAPIRepository = entityRepositoryProvider.storeAPIRepository;

        // A new instance, from the DB (not the tracked one):
        Future<Map<String, Object?>> stored(Object id, Store s) async {
          var o = (await storeAPIRepository.selectByID(id))!;
          expect(o, isNot(same(s)));
          return {'id': o.id, 'name': o.name, 'number': o.number};
        }

        // Insert:
        var s = Store('pu-1', 10);
        var id = await storeAPIRepository.store(s);
        expect(id, isNotNull);

        try {
          expect(await stored(id, s), {'id': id, 'name': 'pu-1', 'number': 10});

          // A partial update (only `name`): `number` kept.
          s.name = 'pu-2';
          expect(await storeAPIRepository.store(s), equals(id));
          expect(await stored(id, s), {'id': id, 'name': 'pu-2', 'number': 10});

          // A partial update (only `number`): `name` kept.
          s.number = 11;
          expect(await storeAPIRepository.store(s), equals(id));
          expect(await stored(id, s), {'id': id, 'name': 'pu-2', 'number': 11});

          // Both, and then unchanged (multiple updates):
          s.name = 'pu-3';
          s.number = 12;
          expect(await storeAPIRepository.store(s), equals(id));
          expect(await storeAPIRepository.store(s), equals(id));
          expect(await stored(id, s), {'id': id, 'name': 'pu-3', 'number': 12});

          // A `null` (a partial update to `null`):
          s.number = null;
          expect(await storeAPIRepository.store(s), equals(id));
          expect(await stored(id, s), {
            'id': id,
            'name': 'pu-3',
            'number': null,
          });

          // The `null` also through a query with a parameter (MySQL: a
          // statement with parameters left `NULL` columns out of its rows):
          var byName = await storeAPIRepository.selectByQuery(
            ' name == ? ',
            parameters: {'name': 'pu-3'},
          );
          expect(
            byName.map((e) => [e.id, e.number]),
            equals([
              [id, null],
            ]),
          );

          // Another instance with the same ID (an updated copy):
          var copy = Store('pu-4', 14, id: id as int);
          expect(await storeAPIRepository.store(copy), equals(id));
          expect(await stored(id, copy), {
            'id': id,
            'name': 'pu-4',
            'number': 14,
          });
        } finally {
          // The other tests count the stores:
          await storeAPIRepository.deleteByID(id);
        }

        expect(await storeAPIRepository.selectByID(id), isNull);
      });

      test('prepared statements: reused, in transactions and after a '
          'schema change', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        var info = sqlAdapter.preparedStatementsInfo;
        if (info == null) {
          _log.info("No prepared statements: skipping.");
          return;
        }

        var isPostgres = sqlAdapter.dialect.name == 'PostgreSQL';
        var q = sqlAdapter.dialect.elementQuote;

        // Independent of the other tests (e.g. run alone): the tables are
        // created if not yet.
        sqlAdapter.disposeTableSchemeCache('store');
        if (await sqlAdapter.getTableScheme('store') == null) {
          await sqlAdapter.populateTables(
            await sqlAdapter.generateFullCreateTableSQLs(withDate: false),
          );
        }

        final storeAPIRepository = entityRepositoryProvider.storeAPIRepository;

        var id = await storeAPIRepository.store(Store('ps-1', 1));
        Object? id2;

        try {
          // Repeated: prepared (PostgreSQL: when it repeats; maybe already by
          // a previous test), then reused.
          var hits0 = info.hits;
          for (var i = 0; i < 4; ++i) {
            expect((await storeAPIRepository.selectByID(id))!.name, 'ps-1');
          }
          expect(info.prepared, greaterThan(0));
          expect(info.hits, greaterThanOrEqualTo(hits0 + 2));

          // Inside a transaction (with a write, so the reads are in it too):
          // the cached statements are used, and (PostgreSQL) none is
          // prepared on the transaction's session.
          var prepared1 = info.prepared;
          var hits1 = info.hits;
          await Transaction().execute(() async {
            id2 = await storeAPIRepository.store(Store('ps-2', 2));
            expect((await storeAPIRepository.selectByID(id))!.name, 'ps-1');
          });
          expect(info.hits, greaterThan(hits1));
          if (isPostgres) {
            expect(info.prepared, equals(prepared1));
          }

          // A schema change by another session, changing the columns of
          // `SELECT *`: still selected (PostgreSQL: the stale statement is
          // replaced; SQLite recompiles it).
          if (testConfigDB is APITestConfigDBSQL) {
            var testConfigSQL = testConfigDB;
            var stale0 = info.stale;

            await testConfigSQL.runSQL(
              'ALTER TABLE ${q}store$q ADD COLUMN ${q}ps_extra$q INT',
            );
            try {
              expect((await storeAPIRepository.selectByID(id))!.name, 'ps-1');
              expect((await storeAPIRepository.selectByID(id))!.name, 'ps-1');
            } finally {
              await testConfigSQL.runSQL(
                'ALTER TABLE ${q}store$q DROP COLUMN ${q}ps_extra$q',
              );
              sqlAdapter.disposeTableSchemeCache('store');
            }

            expect((await storeAPIRepository.selectByID(id))!.name, 'ps-1');

            if (isPostgres) {
              expect(info.stale, greaterThan(stale0));
            }
          }
        } finally {
          // The other tests count the stores.
          await storeAPIRepository.deleteByID(id);
          if (id2 != null) await storeAPIRepository.deleteByID(id2);
        }
      });

      test('selectByIDs: a list over the parameters limit', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;

        // Independent of the other tests (e.g. run alone).
        sqlAdapter.disposeTableSchemeCache('store');
        if (await sqlAdapter.getTableScheme('store') == null) {
          await sqlAdapter.populateTables(
            await sqlAdapter.generateFullCreateTableSQLs(withDate: false),
          );
        }

        final storeAPIRepository = entityRepositoryProvider.storeAPIRepository;

        var id = await storeAPIRepository.store(Store('ids-1', 1)) as int;

        try {
          // Beyond the parameters of a statement (SQLite: 32766; PostgreSQL:
          // 65535): written as values (`SQLDialect.maxIDsAsParameters`).
          var ids = [id, for (var i = 1; i < 70000; ++i) id + 1000000 + i];

          var sel = await storeAPIRepository.selectByIDs(ids);
          expect(sel.nonNulls.map((e) => e.id), equals([id]));

          // `existIDs` (also an `IN` of the IDs):
          expect(await storeAPIRepository.existIDs(ids), equals([id]));

          // Within the limit (as parameters), at it, and just beyond it (as
          // values):
          var max = sqlAdapter.dialect.maxIDsAsParameters;
          for (var n in {300, if (max > 1) max, max + 1}) {
            var sel2 = await storeAPIRepository.selectByIDs(ids.sublist(0, n));
            expect(
              sel2.nonNulls.map((e) => e.id),
              equals([id]),
              reason: '$n IDs',
            );
            expect(
              await storeAPIRepository.existIDs(ids.sublist(0, n)),
              equals([id]),
              reason: '$n IDs',
            );
          }
        } finally {
          // The other tests count the stores.
          await storeAPIRepository.deleteByID(id);
        }
      });

      // The tests of this adapter only (see `adapterTests`):
      for (var e in (adapterTests ?? const {}).entries) {
        test(
          e.key,
          () async => e.value(await entityRepositoryProvider.adapter),
        );
      }

      test('EntityIndex: generated, introspected and checked', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        var q = sqlAdapter.dialect.elementQuote;

        // `Address`: `@EntityIndex(['state', 'city'])` (default name) and
        // `@EntityIndex(['city', 'number'], name: ...)`:
        var fullCreateTableSQLs = await sqlAdapter.generateFullCreateTableSQLs(
          withDate: false,
        );

        var defaultIndexSQL =
            '${q}address__state_city__idx$q ON ${q}address$q '
            '(${q}state$q, ${q}city$q)';
        var namedIndexSQL =
            '${q}address_city_number_custom_idx$q ON ${q}address$q '
            '(${q}city$q, ${q}number$q)';

        expect(fullCreateTableSQLs, contains(defaultIndexSQL));
        expect(fullCreateTableSQLs, contains(namedIndexSQL));

        if (testConfigDB is! APITestConfigDBSQL) {
          _log.info("Not a `APITestConfigDBSQL`: skipping index checks.");
          return;
        }

        var testConfigSQL = testConfigDB;

        // Independent of the other tests (e.g. run alone): the tables are
        // created if not yet.
        sqlAdapter.disposeTableSchemeCache('address');
        if (await sqlAdapter.getTableScheme('address') == null) {
          await sqlAdapter.populateTables(fullCreateTableSQLs);
          sqlAdapter.disposeTableSchemeCache('address');
        }

        var scheme = await sqlAdapter.getTableScheme('address');
        expect(scheme, isNotNull);

        // The adapter must introspect the indexes (not `null`):
        expect(scheme!.indexes, isNotNull, reason: '${sqlAdapter.runtimeType}');
        expect(scheme.hasIndexOn(['state', 'city']), isTrue);
        expect(scheme.hasIndexOn(['city', 'number']), isTrue);
        expect(scheme.indexes!.keys, contains('address__state_city__idx'));
        expect(
          scheme.indexes!.keys,
          contains('address_city_number_custom_idx'),
        );
        // The columns' order matters:
        expect(scheme.hasIndexOn(['city', 'state']), isFalse);

        // Single-field indexes, besides the composite (`state, city`): each
        // one its own index, read with its column. `state` is also
        // `@EntityField.indexed()`: one index (the same name).
        expect(scheme.hasIndexOn(['state']), isTrue);
        expect(scheme.hasIndexOn(['city']), isTrue);
        expect(scheme.indexes!['address__state__idx'], ['state']);
        expect(scheme.indexes!['address__city__idx'], ['city']);
        expect(scheme.indexes!['address__state_city__idx'], ['state', 'city']);
        expect(scheme.indexes!['address_city_number_custom_idx'], [
          'city',
          'number',
        ]);
        expect(
          scheme.indexes!.values.where((c) => c.length == 1 && c[0] == 'state'),
          hasLength(1),
          reason: '${scheme.indexes}',
        );

        // The tables are OK (`force`: checked again, whatever the config):
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        expect(sqlAdapter.checkedTables, isTrue);

        var isMySQL = sqlAdapter.dialect.name.toLowerCase().contains('mysql');

        String dropIndexSQL(String indexName) => isMySQL
            ? 'DROP INDEX $q$indexName$q ON ${q}address$q'
            : 'DROP INDEX $q$indexName$q';

        String createIndexSQL(String indexName, List<String> columns) =>
            'CREATE INDEX $q$indexName$q ON ${q}address$q '
            '(${columns.map((c) => '$q$c$q').join(', ')})';

        Future<void> expectMissingStateCity() => expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('missingEntityIndexes'),
                contains('address__state_city__idx(state, city)'),
                // The other `@EntityIndex`es are there: not reported (the
                // single-field ones don't make the composite).
                isNot(contains('address_city_number_custom_idx(')),
                isNot(contains('address__state__idx(')),
                isNot(contains('address__city__idx(')),
              ),
            ),
          ),
        );

        // A single-field index (B: `city`) missing, while the composite
        // (A+B) and the other single one (A: `state`) are there: only it.
        // The composites starting with `city` (`city, number`) aren't it.
        await testConfigSQL.runSQL(dropIndexSQL('address__city__idx'));

        sqlAdapter.disposeTableSchemeCache('address');
        var schemeNoCity = await sqlAdapter.getTableScheme('address');
        expect(schemeNoCity!.hasIndexOn(['city']), isFalse);
        expect(schemeNoCity.hasIndexOn(['state']), isTrue);
        expect(schemeNoCity.hasIndexOn(['state', 'city']), isTrue);
        expect(schemeNoCity.hasIndexOn(['city', 'number']), isTrue);

        await expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('address__city__idx(city)'),
                isNot(contains('address__state__idx(')),
                isNot(contains('address__state_city__idx(')),
                isNot(contains('address_city_number_custom_idx(')),
              ),
            ),
          ),
        );
        // A failed (forced) check: not checked.
        expect(sqlAdapter.checkedTables, isFalse);

        if (!isMySQL) {
          // The name in use by another table's index (PostgreSQL, SQLite:
          // unique per schema): reported, `CREATE INDEX IF NOT EXISTS`
          // would do nothing. (MySQL: unique per table, no conflict.)
          await testConfigSQL.runSQL(
            'CREATE TABLE ${q}index_name_tmp$q (${q}x$q INT)',
          );
          await testConfigSQL.runSQL(
            'CREATE INDEX ${q}address__city__idx$q ON ${q}index_name_tmp$q '
            '(${q}x$q)',
          );

          await expectLater(
            () async => await sqlAdapter.checkDBTables(force: true),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains(
                  'address__city__idx(city) <name in use on table '
                  '`index_name_tmp`: drop it first>',
                ),
              ),
            ),
          );

          await testConfigSQL.runSQL('DROP TABLE ${q}index_name_tmp$q');
        }

        // The name in use by an index of the table not usable as it: a
        // prefix (MySQL) or expression (PostgreSQL, SQLite) index. Ignored
        // by the scheme, but its name reported.
        await testConfigSQL.runSQL(
          isMySQL
              ? 'CREATE INDEX ${q}address__city__idx$q ON ${q}address$q '
                    '(${q}city$q(10))'
              : 'CREATE INDEX ${q}address__city__idx$q ON ${q}address$q '
                    '(lower(${q}city$q))',
        );

        sqlAdapter.disposeTableSchemeCache('address');
        var schemeUnusable = await sqlAdapter.getTableScheme('address');
        expect(schemeUnusable!.hasIndexOn(['city']), isFalse);
        expect(
          schemeUnusable.indexes!.keys,
          isNot(contains('address__city__idx')),
        );

        await expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'address__city__idx(city) <name in use by an index not usable',
              ),
            ),
          ),
        );
        await testConfigSQL.runSQL(dropIndexSQL('address__city__idx'));

        // Another name, the same column: OK.
        await testConfigSQL.runSQL(
          createIndexSQL('address_city_other_name', ['city']),
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        expect(sqlAdapter.checkedTables, isTrue);
        await testConfigSQL.runSQL(dropIndexSQL('address_city_other_name'));

        await testConfigSQL.runSQL(
          'CREATE INDEX ${q}address__city__idx$q ON ${q}address$q '
          '(${q}city$q)',
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        // Without the index: `checkTables` reports it (only it).
        await testConfigSQL.runSQL(dropIndexSQL('address__state_city__idx'));

        sqlAdapter.disposeTableSchemeCache('address');
        var scheme2 = await sqlAdapter.getTableScheme('address');
        expect(scheme2!.hasIndexOn(['state', 'city']), isFalse);
        expect(
          scheme2.indexes!.keys,
          isNot(contains('address__state_city__idx')),
        );

        await expectMissingStateCity();

        // The suggested SQL (in the error) fixes it in this DB:
        await _checkFixedBySuggestedSQLs(
          sqlAdapter,
          testConfigSQL,
          expectedSQLs: ['${q}address__state_city__idx$q'],
        );
        await testConfigSQL.runSQL(dropIndexSQL('address__state_city__idx'));
        await expectMissingStateCity();

        // A prefix (`state`) or other order (`city`, `state`): not the index.
        await testConfigSQL.runSQL(
          createIndexSQL('address_prefix_tmp_idx', ['state']),
        );
        await testConfigSQL.runSQL(
          createIndexSQL('address_reversed_tmp_idx', ['city', 'state']),
        );
        await expectMissingStateCity();
        await testConfigSQL.runSQL(dropIndexSQL('address_prefix_tmp_idx'));
        await testConfigSQL.runSQL(dropIndexSQL('address_reversed_tmp_idx'));

        // Another name, the same columns (e.g. a hand-made migration): OK.
        await testConfigSQL.runSQL(
          createIndexSQL('address_state_city_other_name', ['state', 'city']),
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        await testConfigSQL.runSQL(
          dropIndexSQL('address_state_city_other_name'),
        );

        await expectMissingStateCity();

        if (!isMySQL) {
          // Not usable as the index: a partial index (`WHERE`) over the
          // same columns, or an expression index (PostgreSQL, SQLite).
          await testConfigSQL.runSQL(
            '${createIndexSQL('address_partial_tmp_idx', ['state', 'city'])} '
            'WHERE ${q}number$q > 0',
          );
          await testConfigSQL.runSQL(
            'CREATE INDEX ${q}address_expr_tmp_idx$q ON ${q}address$q '
            '(lower(${q}state$q), ${q}city$q)',
          );

          sqlAdapter.disposeTableSchemeCache('address');
          var schemeTmp = await sqlAdapter.getTableScheme('address');
          expect(
            schemeTmp!.indexes!.keys,
            isNot(
              anyOf(
                contains('address_partial_tmp_idx'),
                contains('address_expr_tmp_idx'),
              ),
            ),
          );

          await expectMissingStateCity();
          await testConfigSQL.runSQL(dropIndexSQL('address_partial_tmp_idx'));
          await testConfigSQL.runSQL(dropIndexSQL('address_expr_tmp_idx'));
        }

        // The name in use by an index over other columns: reported, to be
        // dropped first (`CREATE INDEX IF NOT EXISTS` would do nothing).
        await testConfigSQL.runSQL(
          dropIndexSQL('address_city_number_custom_idx'),
        );
        await testConfigSQL.runSQL(
          createIndexSQL('address_city_number_custom_idx', ['number', 'city']),
        );
        await expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('address_city_number_custom_idx(city, number)'),
                contains('name in use over (number, city)'),
              ),
            ),
          ),
        );
        await testConfigSQL.runSQL(
          dropIndexSQL('address_city_number_custom_idx'),
        );
        await testConfigSQL.runSQL('CREATE INDEX $namedIndexSQL');

        // Created again (the generated SQL): OK again.
        await testConfigSQL.runSQL('CREATE INDEX $defaultIndexSQL');

        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        sqlAdapter.disposeTableSchemeCache('address');
        var scheme3 = await sqlAdapter.getTableScheme('address');
        expect(scheme3!.indexes!['address__state_city__idx'], [
          'state',
          'city',
        ]);
        expect(scheme3.indexes!['address_city_number_custom_idx'], [
          'city',
          'number',
        ]);
      });

      test('duplicated indexes and CHECK constraints: warned', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        var q = sqlAdapter.dialect.elementQuote;

        if (testConfigDB is! APITestConfigDBSQL) {
          _log.info("Not a `APITestConfigDBSQL`: skipping duplicates checks.");
          return;
        }

        var testConfigSQL = testConfigDB;

        var fullCreateTableSQLs = await sqlAdapter.generateFullCreateTableSQLs(
          withDate: false,
        );
        sqlAdapter.disposeTableSchemeCache('address');
        if (await sqlAdapter.getTableScheme('address') == null) {
          await sqlAdapter.populateTables(fullCreateTableSQLs);
        }

        // A copy of `address__state_city__idx` (the same columns):
        await testConfigSQL.runSQL(
          'CREATE INDEX ${q}address_state_city_copy$q ON ${q}address$q '
          '(${q}state$q, ${q}city$q)',
        );

        // The same columns, of another kind (`DESC`): not a duplicate.
        await testConfigSQL.runSQL(
          'CREATE INDEX ${q}address_state_city_desc$q ON ${q}address$q '
          '(${q}state$q DESC, ${q}city$q)',
        );

        var isPostgres = sqlAdapter.dialect.name.toLowerCase().contains(
          'postgres',
        );

        // An old enum `CHECK` never dropped (PostgreSQL; `NOT VALID`: the
        // existing rows aren't checked). MySQL: a native `ENUM`; SQLite: no
        // `ADD CONSTRAINT`.
        if (isPostgres) {
          await testConfigSQL.runSQL(
            'ALTER TABLE ${q}role$q ADD CONSTRAINT ${q}role_type_old_check$q '
            "CHECK (${q}type$q IN ('admin', 'guest')) NOT VALID",
          );
        }

        sqlAdapter.disposeTableSchemeCache('address');
        sqlAdapter.disposeTableSchemeCache('role');

        var addressScheme = await sqlAdapter.getTableScheme('address');
        expect(
          addressScheme!.duplicatedIndexes,
          contains(
            equals(['address__state_city__idx', 'address_state_city_copy']),
          ),
        );
        expect(
          addressScheme.duplicatedIndexes!.expand((g) => g),
          isNot(contains('address_state_city_desc')),
        );
        expect(
          addressScheme.indexes!.keys,
          contains('address_state_city_desc'),
        );

        var isMySQL = sqlAdapter.dialect.name.toLowerCase().contains('mysql');

        // The primary key's index (SQLite: the rowid, none):
        expect(
          addressScheme.primaryKeyIndex,
          isPostgres
              ? 'address_pkey'
              : isMySQL
              ? 'PRIMARY'
              : isNull,
        );

        var roleScheme = await sqlAdapter.getTableScheme('role');
        if (isPostgres) {
          expect(roleScheme!.checkConstraints, isNotNull);
          expect(
            roleScheme.duplicatedCheckConstraints?['type'],
            containsAll(['role_type_check', 'role_type_old_check']),
          );

          var roleDuplicates = sqlAdapter.findTableDuplicates(
            roleScheme,
            entityHandler: entityRepositoryProvider
                .getEntityRepositoryByType(Role)!
                .entityHandler,
          );
          // Kept: the one with the entity's values (admin, guest, unknown).
          expect(
            roleDuplicates.checkConstraints['type']?.first,
            'role_type_check',
          );
        }

        // Warned, not an error: also the old `CHECK` without the enum's
        // `unknown` (the current one has all the values).
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        var addressDuplicates = sqlAdapter.tablesDuplicates['address'];
        expect(addressDuplicates, isNotNull);
        expect(
          addressDuplicates!.indexes,
          contains(
            equals(['address__state_city__idx', 'address_state_city_copy']),
          ),
        );
        expect(sqlAdapter.tablesDuplicates.containsKey('role'), isPostgres);

        // The suggested SQLs, run in the DB, drop the duplicates:
        var dropSQLs = [
          ...addressDuplicates.dropSQLs,
          ...?sqlAdapter.tablesDuplicates['role']?.dropSQLs,
        ].where((s) => !s.startsWith('--')).map((s) => s.split('  --').first);

        for (var sql in dropSQLs) {
          await testConfigSQL.runSQL(sql);
        }

        sqlAdapter.disposeTableSchemeCache('address');
        sqlAdapter.disposeTableSchemeCache('role');

        var addressScheme2 = await sqlAdapter.getTableScheme('address');
        // None reported (MySQL `SERIAL`'s unique index, of the `CREATE
        // TABLE`, is in the scheme's `duplicatedIndexes`, but not reported):
        expect(sqlAdapter.findTableDuplicates(addressScheme2!).isEmpty, isTrue);
        expect(addressScheme2.hasIndexOn(['state', 'city']), isTrue);
        // The other kind wasn't dropped:
        expect(
          addressScheme2.indexes!.keys,
          contains('address_state_city_desc'),
        );
        if (isPostgres) {
          var roleScheme2 = await sqlAdapter.getTableScheme('role');
          expect(roleScheme2!.duplicatedCheckConstraints, isEmpty);
          expect(roleScheme2.checkConstraints!.keys, ['role_type_check']);
        }

        await testConfigSQL.runSQL(
          sqlAdapter.generateDropIndexSQL('address', 'address_state_city_desc'),
        );
        sqlAdapter.disposeTableSchemeCache('address');
      });

      test('EntityIndex unique: generated, introspected and checked', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        var q = sqlAdapter.dialect.elementQuote;

        // `User`: `@EntityIndex(['email', 'address'], unique: true)`, and
        // `@EntityIndex(['email'], unique: true)` (the same as `email`'s
        // `@EntityField.unique()`: one constraint).
        var fullCreateTableSQLs = await sqlAdapter.generateFullCreateTableSQLs(
          withDate: false,
        );

        expect(
          fullCreateTableSQLs,
          contains(
            'CONSTRAINT ${q}user__email_address__unique$q '
            'UNIQUE (${q}email$q, ${q}address$q)',
          ),
        );
        expect(
          'UNIQUE (${q}email$q)'.allMatches(fullCreateTableSQLs).length,
          1,
        );
        expect(fullCreateTableSQLs, isNot(contains('UNIQUE INDEX')));

        if (testConfigDB is! APITestConfigDBSQL) {
          _log.info("Not a `APITestConfigDBSQL`: skipping index checks.");
          return;
        }

        var testConfigSQL = testConfigDB;

        sqlAdapter.disposeTableSchemeCache('user');
        if (await sqlAdapter.getTableScheme('user') == null) {
          await sqlAdapter.populateTables(fullCreateTableSQLs);
          sqlAdapter.disposeTableSchemeCache('user');
        }

        var scheme = await sqlAdapter.getTableScheme('user');
        expect(scheme, isNotNull);
        expect(scheme!.indexes, isNotNull, reason: '${sqlAdapter.runtimeType}');
        expect(
          scheme.uniqueIndexes,
          isNotNull,
          reason: '${sqlAdapter.runtimeType}',
        );

        // The unique constraints: unique indexes over their columns.
        expect(scheme.hasIndexOn(['email', 'address'], unique: true), isTrue);
        expect(scheme.hasIndexOn(['email'], unique: true), isTrue);
        expect(scheme.hasIndexOn(['email', 'address']), isTrue);
        expect(scheme.hasIndexOn(['address', 'email'], unique: true), isFalse);
        expect(scheme.hasIndexOn(['address'], unique: true), isFalse);

        var dialectName = sqlAdapter.dialect.name.toLowerCase();
        var isMySQL = dialectName.contains('mysql');
        var isSQLite = dialectName.contains('sqlite');

        // PostgreSQL, MySQL: the constraint's index has its name (SQLite:
        // `sqlite_autoindex_*`).
        if (!isSQLite) {
          expect(scheme.indexes!['user__email_address__unique'], [
            'email',
            'address',
          ]);
          expect(scheme.uniqueIndexes, contains('user__email_address__unique'));
        }

        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        // SQLite can't drop a table's `UNIQUE` constraint.
        if (isSQLite) return;

        String dropIndexSQL(String indexName) => isMySQL
            ? 'DROP INDEX $q$indexName$q ON ${q}user$q'
            : 'DROP INDEX $q$indexName$q';

        Future<void> expectMissingUnique({String? conflict}) => expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('missingEntityIndexes'),
                contains('user__email_address__unique(email, address) UNIQUE'),
                if (conflict != null) contains('name in use $conflict'),
                // The single-field one is there:
                isNot(contains('user__email__unique(')),
              ]),
            ),
          ),
        );

        // Without the constraint: reported.
        await testConfigSQL.runSQL(
          isMySQL
              ? 'ALTER TABLE ${q}user$q DROP INDEX '
                    '${q}user__email_address__unique$q'
              : 'ALTER TABLE ${q}user$q DROP CONSTRAINT '
                    '${q}user__email_address__unique$q',
        );

        sqlAdapter.disposeTableSchemeCache('user');
        var scheme2 = await sqlAdapter.getTableScheme('user');
        expect(
          scheme2!.hasIndexOn(['email', 'address'], unique: true),
          isFalse,
        );

        await expectMissingUnique();

        // The suggested SQL (a constraint, as in the `CREATE TABLE`) fixes it
        // in this DB:
        var addConstraintSQL =
            'ADD CONSTRAINT ${q}user__email_address__unique$q '
            'UNIQUE (${q}email$q, ${q}address$q)';
        await _checkFixedBySuggestedSQLs(
          sqlAdapter,
          testConfigSQL,
          expectedSQLs: [addConstraintSQL],
        );
        await testConfigSQL.runSQL(
          isMySQL
              ? 'ALTER TABLE ${q}user$q DROP INDEX '
                    '${q}user__email_address__unique$q'
              : 'ALTER TABLE ${q}user$q DROP CONSTRAINT '
                    '${q}user__email_address__unique$q',
        );
        await expectMissingUnique();

        // A non-unique index over the same columns: not it.
        await testConfigSQL.runSQL(
          'CREATE INDEX ${q}user_email_address_tmp_idx$q ON ${q}user$q '
          '(${q}email$q, ${q}address$q)',
        );
        await expectMissingUnique();
        await testConfigSQL.runSQL(dropIndexSQL('user_email_address_tmp_idx'));

        // A unique index over the same columns in another order: not it.
        await testConfigSQL.runSQL(
          'CREATE UNIQUE INDEX ${q}user_address_email_tmp_uq$q ON ${q}user$q '
          '(${q}address$q, ${q}email$q)',
        );
        sqlAdapter.disposeTableSchemeCache('user');
        var schemeReversed = await sqlAdapter.getTableScheme('user');
        expect(
          schemeReversed!.hasIndexOn(['address', 'email'], unique: true),
          isTrue,
        );
        expect(
          schemeReversed.hasIndexOn(['email', 'address'], unique: true),
          isFalse,
        );
        await expectMissingUnique();
        await testConfigSQL.runSQL(dropIndexSQL('user_address_email_tmp_uq'));

        if (isMySQL) {
          // A unique prefix index (`email(50)`): not usable as it (and
          // stricter: unique by the prefix; long enough for the test data).
          await testConfigSQL.runSQL(
            'CREATE UNIQUE INDEX ${q}user__email_address__unique$q ON '
            '${q}user$q (${q}email$q(50), ${q}address$q)',
          );
        } else {
          // A partial unique index (`WHERE`): unique only for some rows.
          await testConfigSQL.runSQL(
            'CREATE UNIQUE INDEX ${q}user__email_address__unique$q ON '
            '${q}user$q (${q}email$q, ${q}address$q) '
            'WHERE ${q}level$q > 0',
          );
        }
        sqlAdapter.disposeTableSchemeCache('user');
        var schemeUnusable = await sqlAdapter.getTableScheme('user');
        expect(
          schemeUnusable!.indexes!.keys,
          isNot(contains('user__email_address__unique')),
        );
        expect(
          schemeUnusable.uniqueIndexes,
          isNot(contains('user__email_address__unique')),
        );
        expect(
          schemeUnusable.hasIndexOn(['email', 'address'], unique: true),
          isFalse,
        );
        // Its name in use (`CREATE UNIQUE INDEX IF NOT EXISTS` would skip):
        await expectMissingUnique(
          conflict:
              'by an index not usable as it (partial, expression or '
              'prefix)',
        );
        await testConfigSQL.runSQL(dropIndexSQL('user__email_address__unique'));

        if (!isMySQL) {
          // Its name in use by another table's index (PostgreSQL: unique
          // per schema).
          await testConfigSQL.runSQL(
            'CREATE TABLE ${q}user_index_name_tmp$q (${q}x$q INT)',
          );
          await testConfigSQL.runSQL(
            'CREATE UNIQUE INDEX ${q}user__email_address__unique$q ON '
            '${q}user_index_name_tmp$q (${q}x$q)',
          );
          await expectMissingUnique(conflict: 'on table `user_index_name_tmp`');
          await testConfigSQL.runSQL('DROP TABLE ${q}user_index_name_tmp$q');
        }

        // A non-unique index with its name (the same columns): a conflict.
        await testConfigSQL.runSQL(
          'CREATE INDEX ${q}user__email_address__unique$q ON ${q}user$q '
          '(${q}email$q, ${q}address$q)',
        );
        await expectMissingUnique(
          conflict: 'over (email, address), not unique',
        );
        await testConfigSQL.runSQL(dropIndexSQL('user__email_address__unique'));

        // A unique index (any name) over the same columns: OK.
        await testConfigSQL.runSQL(
          'CREATE UNIQUE INDEX ${q}user_email_address_other_uq$q ON '
          '${q}user$q (${q}email$q, ${q}address$q)',
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        await testConfigSQL.runSQL(dropIndexSQL('user_email_address_other_uq'));

        // The constraint again: OK.
        await testConfigSQL.runSQL(
          'ALTER TABLE ${q}user$q ADD CONSTRAINT '
          '${q}user__email_address__unique$q '
          'UNIQUE (${q}email$q, ${q}address$q)',
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);

        // `email`'s own constraint (`@EntityField.unique()`, also an
        // `@EntityIndex(['email'], unique: true)`) missing: reported once,
        // as the field's (all the SQL adapters: from the unique indexes).
        await testConfigSQL.runSQL(
          isMySQL
              ? 'ALTER TABLE ${q}user$q DROP INDEX ${q}user__email__unique$q'
              : 'ALTER TABLE ${q}user$q DROP CONSTRAINT '
                    '${q}user__email__unique$q',
        );

        sqlAdapter.disposeTableSchemeCache('user');
        var schemeNoEmail = await sqlAdapter.getTableScheme('user');
        expect(schemeNoEmail!.hasIndexOn(['email'], unique: true), isFalse);
        // The composite one: still there.
        expect(
          schemeNoEmail.hasIndexOn(['email', 'address'], unique: true),
          isTrue,
        );

        await expectLater(
          () async => await sqlAdapter.checkDBTables(force: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('missingUniqueConstraints: [email]'),
                isNot(contains('user__email__unique(email) UNIQUE')),
                isNot(contains('missingEntityIndexes')),
              ]),
            ),
          ),
        );

        // A unique index (any name) over `email`: OK.
        await testConfigSQL.runSQL(
          'CREATE UNIQUE INDEX ${q}user_email_other_uq$q ON ${q}user$q '
          '(${q}email$q)',
        );
        expect(await sqlAdapter.checkDBTables(force: true), isTrue);
        await testConfigSQL.runSQL(dropIndexSQL('user_email_other_uq'));

        // Restored by the suggested SQL (the `CREATE TABLE` name):
        await _checkFixedBySuggestedSQLs(
          sqlAdapter,
          testConfigSQL,
          expectedSQLs: [
            'ADD CONSTRAINT ${q}user__email__unique$q UNIQUE (${q}email$q)',
          ],
        );

        sqlAdapter.disposeTableSchemeCache('user');
        var schemeRestored = await sqlAdapter.getTableScheme('user');
        expect(schemeRestored!.indexes!['user__email__unique'], ['email']);
      });

      test('TestEntityRepositoryProvider', () async {
        final sqlAdapter = await entityRepositoryProvider.adapter;
        final storeAPIRepository = entityRepositoryProvider.storeAPIRepository;
        final addressAPIRepository =
            entityRepositoryProvider.addressAPIRepository;
        final roleAPIRepository = entityRepositoryProvider.roleAPIRepository;
        final userInfoAPIRepository =
            entityRepositoryProvider.userInfoAPIRepository;
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;
        final photoAPIRepository = entityRepositoryProvider2.photoAPIRepository;

        expect(sqlAdapter.isInitialized, isTrue);
        expect(await userAPIRepository.length(), equals(0));

        final int userInfoInitID;

        {
          var userInfo = await userInfoAPIRepository.selectByID(1);
          print('userInfo> $userInfo');

          if (populateSource) {
            userInfoInitID = 1;
            expect(userInfo, isNotNull);
            expect(userInfo!.info, equals('abc123xyz'));
          } else {
            userInfoInitID = 0;
            expect(userInfo, isNull);
          }
        }

        {
          var user = await userAPIRepository.selectByID(1);
          expect(user, isNull);

          expect((await userAPIRepository.selectAll()), isEmpty);

          expect((await userAPIRepository.existsID(1)), isFalse);
          expect((await userAPIRepository.existsID(2)), isFalse);
          expect((await userAPIRepository.existsID(3)), isFalse);
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
        int user1Id;

        var store1 = Store('s11', 11);
        var store2 = Store('s12', 12);
        var storeClosed = Store('s9', 9);

        {
          var address = Address(
            'NY',
            'New York',
            'street A',
            101,
            stores: [store1, store2],
            closedStores: [storeClosed],
            latitude: 0.20,
            longitude: 0.30,
          );
          var role = Role(RoleType.admin);

          var photo = Photo.from(png1PixelBase64);

          expect(photo.id, equals(png1PixelSha256));
          expect(
            photo.data,
            equals(Uint8List.fromList(base64.decode(png1PixelBase64))),
          );

          {
            var invalidUser = User(
              'joe at $testDomain',
              '123',
              address,
              [role],
              level: 100,
              creationTime: user1CreationTime,
            );

            expect(invalidUser.reflection.allFieldsValids(), isFalse);

            EntityFieldInvalid? error;
            try {
              await userAPIRepository.store(invalidUser);
            } on EntityFieldInvalid catch (e) {
              error = e;
            }

            expect(error, isNotNull);
            expect(
              error.toString(),
              contains('Invalid entity(User) field(email)> reason: regexp'),
            );

            expect(address.id, isNull);
          }

          {
            var invalidAddress = Address('NYXZ', 'New York', 'street A', 101);
            var role = Role(RoleType.admin);

            var user = User(
              'joe@$testDomain',
              '123',
              invalidAddress,
              [role],
              level: 100,
              creationTime: user1CreationTime,
            );

            expect(user.reflection.allFieldsValids(), isFalse);

            print(user);

            EntityFieldInvalid? error;
            try {
              await userAPIRepository.store(user);
            } on EntityFieldInvalid catch (e) {
              error = e;
            }

            expect(error, isNotNull);
            expect(
              error.toString(),
              contains(
                'Invalid entity(Address) field(state)> reason: maximum(3)',
              ),
            );
          }

          expect((await storeAPIRepository.selectAll()).length, equals(0));
          expect((await addressAPIRepository.selectAll()).length, equals(0));
          expect(
            (await userInfoAPIRepository.selectAll()).length,
            equals(userInfoInitID),
          );
          expect((await userAPIRepository.selectAll()).length, equals(0));

          expect((await photoAPIRepository.count()), equals(0));

          expect(await userAPIRepository.existsID(1), isFalse);
          expect(await userAPIRepository.existIDs([1]), equals([]));

          var user = User(
            'joe@$testDomain',
            '123',
            address,
            [role],
            level: 100,
            userInfo: UserInfo('The user joe'),
            photo: photo,
            creationTime: user1CreationTime,
          );

          expect(user.reflection.allFieldsValids(), isTrue);

          var id = await userAPIRepository.store(user);
          expect(id, equals(1));

          expect(await userAPIRepository.existsID(1), isTrue);
          expect(await userAPIRepository.existIDs([1]), equals([1]));

          expect(
            await userAPIRepository.selectIDsByQuery(
              ' email == ? ',
              parameters: {'email': 'joe@$testDomain'},
            ),
            equals([1]),
          );

          expect(
            await userAPIRepository.selectIDsByQuery(
              ' email == ? ',
              parameters: {'email': 'inexistent.user@$testDomain'},
            ),
            isEmpty,
          );

          user1Id = id;

          expect(user.id, equals(1));
          expect(user.userInfo.id, equals(userInfoInitID + 1));
          expect(address.id, equals(1));
          expect(role.id, equals(1));
          expect(user.userInfo.id, equals(userInfoInitID + 1));
          expect(user.userInfo.entity?.id, equals(userInfoInitID + 1));

          expect(user.address.isEntityReference, isFalse);
          expect(user.userInfo.isEntityReference, isTrue);

          expect(user.address.resolveEntityInstance, isA<Address>());
          expect(user.userInfo.resolveEntityInstance, isA<UserInfo>());
          expect(user.photo.resolveEntityInstance, isA<Photo>());

          expect(
            (await userInfoAPIRepository.selectAll()).length,
            equals(userInfoInitID + 1),
          );
          expect((await userAPIRepository.selectAll()).length, equals(1));
          expect((await addressAPIRepository.selectAll()).length, equals(1));
          expect((await storeAPIRepository.selectAll()).length, equals(3));

          expect((await photoAPIRepository.count()), equals(1));

          expect((await userInfoAPIRepository.existsID(1)), isTrue);
          expect((await userAPIRepository.existsID(1)), isTrue);
          expect((await addressAPIRepository.existsID(1)), isTrue);

          expect((await photoAPIRepository.existsID(png1PixelSha256)), isTrue);

          expect(
            (await photoAPIRepository.selectByID(png1PixelSha256)),
            equals(photo),
          );

          expect(
            (await photoAPIRepository.selectByIDs([png1PixelSha256, "nope"])),
            equals([photo, null]),
          );

          expect(
            (await photoAPIRepository.selectByQuery(
              'id == ?',
              parameters: {'id': photo.id},
            )),
            equals([photo]),
          );

          {
            var address1 = await addressAPIRepository.selectByID(address.id);
            expect(address1, isNotNull);
            expect(address1!.id, equals(address.id));
            expect(address1.state, equals('NY'));
            expect(address1.number, equals(101));
            expect(address1.latitude, equals(Decimal.fromDouble(0.20)));
            expect(address1.longitude, equals(Decimal.fromDouble(0.30)));

            var sel1 = await addressAPIRepository.selectFirstByQuery(
              " state == ? ",
              parameters: ['NY'],
            );
            expect(sel1?.number, equals(101));

            var sel2 = await addressAPIRepository.selectFirstByQuery(
              " state == ? ",
              parameters: ['XX'],
            );
            expect(sel2, isNull);

            var sel3 = await addressAPIRepository.selectFirstByQuery(
              " latitude >= 0.19 && latitude <= 0.21 && longitude >= 0.29 && longitude <= 0.31 ",
            );
            expect(sel3?.number, equals(101));

            var sel4 = await addressAPIRepository.selectFirstByQuery(
              " latitude >= ?:lat1 && latitude <= ?:lat2 && longitude >= ?:long1 && longitude <= ?:long2 ",
              parameters: {
                'lat1': Decimal.fromDouble(0.19),
                'lat2': Decimal.fromDouble(0.21),
                'long1': Decimal.fromDouble(0.29),
                'long2': Decimal.fromDouble(0.31),
              },
            );
            expect(sel4?.number, equals(101));

            var sel5 = await addressAPIRepository.selectFirstByQuery(
              " latitude >= ?:lat1 && latitude <= ?:lat2 && longitude >= ?:long1 && longitude <= ?:long2 ",
              parameters: {
                'lat1': Decimal.fromDouble(0.19),
                'lat2': Decimal.fromDouble(0.21),
                'long1': Decimal.fromDouble(1.29),
                'long2': Decimal.fromDouble(1.31),
              },
            );
            expect(sel5, isNull);

            var sel6 = await addressAPIRepository.selectFirstByQuery(
              " latitude >= ?:lat1 && latitude <= ?:lat2 && longitude >= ?:long1 && longitude <= ?:long2 ",
              parameters: {
                'lat1': Decimal.fromDouble(1.19),
                'lat2': Decimal.fromDouble(1.21),
                'long1': Decimal.fromDouble(0.29),
                'long2': Decimal.fromDouble(0.31),
              },
            );
            expect(sel6, isNull);
          }

          {
            var user = await userAPIRepository.selectByID(1);
            expect(user!.email, equals('joe@$testDomain'));

            expect(user.userInfo.isNull, isFalse);
            expect(user.userInfo.id, equals(userInfoInitID + 1));
            expect(user.userInfo.isEntitySet, isFalse);

            expect(user.photo?.id, equals(png1PixelSha256));
            expect(user.photo?.data, equals(base64.decode(png1PixelBase64)));
          }

          {
            var sel1 = await addressAPIRepository.selectByStore(store1);

            expect(sel1.length, equals(1));
            expect(sel1.first.number, equals(101));

            var sel2 = await addressAPIRepository.selectByStore(storeClosed);
            expect(sel2, isEmpty);
          }

          {
            var sel1 = await addressAPIRepository.selectByClosedStore(
              storeClosed,
            );

            expect(sel1.length, equals(1));
            expect(sel1.first.number, equals(101));

            var sel2 = await addressAPIRepository.selectByClosedStore(store2);
            expect(sel2, isEmpty);
          }

          {
            var user = await userAPIRepository.selectByID(
              1,
              resolutionRules: EntityResolutionRules.fetch(
                eagerEntityTypes: [UserInfo],
              ),
            );
            expect(user!.email, equals('joe@$testDomain'));

            expect(user.userInfo.isNull, isFalse);
            expect(user.userInfo.id, equals(userInfoInitID + 1));
            expect(user.userInfo.isEntitySet, isTrue);
            expect(
              user.userInfo.entityToJson(),
              equals(UserInfo('The user joe', id: userInfoInitID + 1).toJson()),
            );
          }

          expect(
            (await addressAPIRepository.selectByID(1))?.city,
            equals('New York'),
          );

          expect(
            (await addressAPIRepository.selectByID(1))?.stores
                .map((e) => e.name),
            equals(['s11', 's12']),
          );

          expect(
            (await addressAPIRepository.selectByID(1))?.closedStores.entities,
            isNull,
          );

          expect(
            (await addressAPIRepository.selectByID(
              1,
              resolutionRules: EntityResolutionRules.fetchEagerAll(),
            ))?.closedStores.entities?.map((e) => e?.name).toList(),
            equals(['s9']),
          );

          expect(
            (await userAPIRepository.selectByAddress(address)).single.email,
            equals('joe@$testDomain'),
          );
          expect(
            (await userAPIRepository.selectByAddressID(address.id!))
                .single
                .email,
            equals('joe@$testDomain'),
          );

          expect(
            (await userAPIRepository.selectByRole(role)).single.email,
            equals('joe@$testDomain'),
          );

          expect(
            (await userAPIRepository.selectByRoleId(role.id!)).single.email,
            equals('joe@$testDomain'),
          );

          var userDuplicated = User(
            'joe@$testDomain',
            '456',
            address,
            [role],
            level: 100,
            creationTime: user1CreationTime,
          );

          {
            EntityFieldInvalid? error;
            int? result;
            try {
              result = await userAPIRepository.store(userDuplicated);
            } on EntityFieldInvalid catch (e) {
              error = e;
            }

            expect(result, isNull);

            expect(error, isA<EntityFieldInvalid>());
            expect(
              error.toString(),
              matches(
                RegExp(
                  r'Invalid entity\((?:User)?@table:user\) field(?:\(.*?email.*?\))?> reason: unique ; value: <.*?joe@[\w.+]+\.com.*?>.*',
                  dotAll: true,
                ),
              ),
            );
          }

          if (sqlAdapter.capability.transactionAbort) {
            var transaction = Transaction();

            var result = await transaction.execute(() async {
              var id = await userAPIRepository.store(userDuplicated);
              return id as int?;
            });

            print(transaction);

            expect(result, isNull);

            expect(transaction.isAborted, isTrue);
            expect(transaction.isCommitted, isFalse);
            expect(transaction.abortError, isNotNull);
            expect(transaction.abortError?.reason, isNull);

            expect(transaction.abortError?.error, isA<EntityFieldInvalid>());
            expect(
              transaction.abortError?.error.toString(),
              matches(
                RegExp(
                  r'Invalid entity\((?:User)?@table:user\) field(?:\(.*?email.*?\))?> reason: unique ; value: <.*?joe@[\w.+]+\.com.*?>.*',
                  dotAll: true,
                ),
              ),
            );
          }

          if (sqlAdapter.capability.transactionAbort) {
            var transaction = Transaction();

            var result = await transaction.execute(() async {
              var prevUsers = await userAPIRepository.selectFirstByQuery(
                'email == "${userDuplicated.email}"',
              );
              expect(prevUsers, isNotNull);
              expect(prevUsers?.email, equals(userDuplicated.email));
              var id = await userAPIRepository.store(userDuplicated);
              return id as int?;
            });

            print(transaction);

            expect(result, isNull);

            expect(transaction.isOpen, isTrue);
            expect(transaction.isAborted, isTrue);
            expect(transaction.isCommitted, isFalse);
            expect(transaction.length, greaterThanOrEqualTo(1));
            expect(transaction.abortError, isNotNull);
            expect(transaction.abortError?.reason, isNull);

            expect(transaction.abortError?.error, isA<EntityFieldInvalid>());
            expect(
              transaction.abortError?.error.toString(),
              matches(
                RegExp(
                  r'Invalid entity\((?:User)?@table:user\) field(?:\(.*?email.*?\))?> reason: unique ; value: <.*?joe@[\w.+]+\.com.*?>.*',
                  dotAll: true,
                ),
              ),
            );
          }
        }

        var user2CreationTime = DateTime.utc(2021, 9, 21, 22, 11, 12, 0, 0);
        var user2WakeupTime = Time(9, 10, 11);

        int user2Id;

        {
          var address = Address('CA', 'Los Angeles', 'street B', 201);

          var user = User(
            'smith@$testDomain',
            'abc',
            address,
            [Role(RoleType.guest, value: Decimal.parse('123.45'))],
            wakeUpTime: user2WakeupTime,
            creationTime: user2CreationTime,
          );

          final id = await userAPIRepository.store(user);
          expect(id, greaterThanOrEqualTo(2));

          user2Id = id;

          expect((await userAPIRepository.selectAll()).length, equals(2));

          expect(await userAPIRepository.existsID(1), isTrue);
          expect(await userAPIRepository.existsID(id), isTrue);
          expect(await userAPIRepository.existsID(123123123123), isFalse);
          expect(
            await userAPIRepository.existIDs([1, id, 123123123123]),
            equals([1, id]),
          );

          expect(
            await userAPIRepository.selectIDsByQuery(
              ' email == ? ',
              parameters: {'email': 'smith@$testDomain'},
            ),
            equals([id]),
          );

          expect(
            await userAPIRepository.selectIDsByQuery(
              ' email == ? ',
              parameters: {'email': 'inexistent.user@$testDomain'},
            ),
            isEmpty,
          );

          expect(
            await userAPIRepository.selectIDsByQuery(
              ' email =~ ? ',
              parameters: {
                'email': ['joe@$testDomain', 'smith@$testDomain'],
              },
            ),
            unorderedEquals([1, id]),
          );

          var user2 = await userAPIRepository.selectByID(id);

          expect(user2!.userInfo.isNull, isTrue);
          expect(user2.wakeUpTime, equals(user2WakeupTime));

          user2.wakeUpTime = null;
          var id2 = await userAPIRepository.store(user2);
          expect(id2, equals(id));

          user2 = await userAPIRepository.selectByID(id);
          expect(user2!.wakeUpTime, isNull);

          user2.wakeUpTime = user2WakeupTime;
          id2 = await userAPIRepository.store(user2);
          expect(id2, equals(id));

          user2 = await userAPIRepository.selectByID(id);
          expect(user2!.wakeUpTime, equals(user2WakeupTime));

          var user2Role = user2.roles.first;

          expect(
            (await userAPIRepository.selectByRole(user2Role)).first,
            equals(user2),
          );
          expect(
            (await userAPIRepository.selectByRoleId(user2Role.id!)).first,
            equals(user2),
          );
        }

        var user3CreationTime = DateTime.utc(2021, 9, 22);
        var user3WakeupTime = Time(12, 10, 11);

        int user3Id;

        {
          var address = Address('CA', 'Los Angeles', 'street B', 101);

          var user = User(
            'john@$testDomain',
            '456',
            address,
            [],
            wakeUpTime: user3WakeupTime,
            creationTime: user3CreationTime,
          );
          var id = await userAPIRepository.store(user);
          expect(id, greaterThanOrEqualTo(3));

          user3Id = id;
        }

        expect(await addressAPIRepository.length(), equals(3));
        expect(await userAPIRepository.length(), equals(3));

        {
          var sel1 = await addressAPIRepository.selectByStore(store1);

          expect(sel1.length, equals(1));
          expect(sel1.first.number, equals(101));

          var sel2 = await addressAPIRepository.selectByStore(storeClosed);
          expect(sel2, isEmpty);
        }

        {
          var sel1 = await addressAPIRepository.selectByClosedStore(
            storeClosed,
          );

          expect(sel1.length, equals(1));
          expect(sel1.first.number, equals(101));

          var sel2 = await addressAPIRepository.selectByClosedStore(store2);
          expect(sel2, isEmpty);
        }

        {
          var user = await userAPIRepository.selectByID(user1Id);
          expect(user!.email, equals('joe@$testDomain'));
          expect(user.address.state, equals('NY'));
          expect(
            user.roles.map(
              (e) => entityByReflection ? e.toJsonFromFields() : e.toJson(),
            ),
            equals([
              {'enabled': true, 'id': 1, 'type': 'admin', 'value': null},
            ]),
          );
          expect(user.level, equals(100));
          expect(user.wakeUpTime, isNull);
          expect(user.creationTime, equals(user1CreationTime));

          var user2 = await userAPIRepository.selectByEmail('joe@$testDomain');
          expect(user2!.toJsonEncoded(), equals(user.toJsonEncoded()));

          var user3 = (await userAPIRepository.select(
            Condition.parse('email == ?'),
            parameters: ['joe@$testDomain'],
          )).first;
          expect(user3.toJsonEncoded(), equals(user.toJsonEncoded()));

          var user4 = (await userAPIRepository.select(
            Condition.parse('email == ?'),
            parameters: ['joex@$testDomain'],
          )).firstOrNull;
          expect(user4, isNull);
        }

        {
          var user = await userAPIRepository.selectByID(user2Id);
          expect(user!.email, equals('smith@$testDomain'));
          expect(user.address.state, equals('CA'));
          expect(
            user.roles.map(
              (e) => entityByReflection ? e.toJsonFromFields() : e.toJson(),
            ),
            anyOf(
              equals([
                {
                  'id': 2,
                  'type': 'guest',
                  'enabled': true,
                  'value': '123.4500',
                },
              ]),
              equals([
                {'id': 2, 'type': 'guest', 'enabled': true, 'value': '123.45'},
              ]),
            ),
          );
          expect(user.level, isNull);
          expect(user.wakeUpTime, user2WakeupTime);
          expect(user.creationTime, equals(user2CreationTime));
        }

        {
          var user = await userAPIRepository.selectByID(user3Id);
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
          var user = await userAPIRepository.selectByEmail('joe@$testDomain');
          expect(user!.email, equals('joe@$testDomain'));
          expect(user.address.state, equals('NY'));
        }

        {
          var user = await userAPIRepository.selectByEmail('smith@$testDomain');
          expect(user!.email, equals('smith@$testDomain'));
          expect(user.address.state, equals('CA'));
        }

        {
          var sel = await userAPIRepository.selectByAddressState('NY');

          var user = sel.first;
          expect(user.email, equals('joe@$testDomain'));
          expect(user.address.state, equals('NY'));
        }

        {
          var sel = await userAPIRepository.selectByINAddressStates([
            'NY',
            'CA',
          ]);

          expect(sel.length, equals(3));
          expect(
            sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']),
          );
        }

        {
          var user = await userAPIRepository.selectByEmail('joe@$testDomain');
          expect(user!.email, equals('joe@$testDomain'));

          expect(user.id, greaterThanOrEqualTo(1));
          expect(user.roles.length, equals(1));

          user.roles.add(Role(RoleType.unknown));

          expect(await userAPIRepository.store(user), equals(user.id));
          expect(user.roles.length, equals(2));

          var user2 = await userAPIRepository.selectByID(user.id);
          expect(user2!.roles.length, equals(2));
          expect(user2.roles.map((e) => e.id), unorderedEquals([1, 3]));
          expect(
            user2.roles.map((e) => e.type),
            unorderedEquals([RoleType.admin, RoleType.unknown]),
          );

          expect(user2.password, equals('123'));
          user2.password = '321';

          expect(await userAPIRepository.store(user2), equals(user.id));
          expect(user2.roles.length, equals(2));

          var user3 = await userAPIRepository.selectByID(user.id);

          expect(user3!.password, equals('321'));

          expect(user3.roles.length, equals(2));
          expect(user3.roles.map((e) => e.id), unorderedEquals([1, 3]));
          expect(
            user3.roles.map((e) => e.type),
            unorderedEquals([RoleType.admin, RoleType.unknown]),
          );

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [3],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {'roles': []},
            );

            expect(user4, isNull);
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "( roles =~ ?:rs1 || roles =~ ?:rs2 )",
              parameters: {
                'rs1': [3],
                'rs2': [],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              " level == 100 && ( roles =~ ?:rs1 || roles =~ ?:rs2 )",
              parameters: {
                'rs1': [3],
                'rs2': [],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            // A null supplied as a parameter must become `IS NULL`, not `= ?`
            // bound to null — which is never true in SQL, so the query
            // silently returned nothing instead of the rows whose column is
            // null. An inlined null was already handled; passing it as a
            // parameter was not, and that is the form entity queries take.
            var nullLevel = await userAPIRepository.selectByQuery(
              " level == ? ",
              parameters: {'level': null},
            );

            expect(
              nullLevel,
              isNotEmpty,
              reason: 'there are users with no level',
            );
            expect(
              nullLevel.map((e) => e.level),
              everyElement(isNull),
              reason: 'a null parameter must select the rows that are null',
            );

            // Compounded with another term — the shape that made this visible,
            // since a true half cannot rescue a half that never matches.
            var nullLevelCompound = await userAPIRepository.selectByQuery(
              " level == ? && email != ? ",
              parameters: {'level': null, 'email': 'nobody@$testDomain'},
            );

            expect(nullLevelCompound, isNotEmpty);
            expect(nullLevelCompound.map((e) => e.level), everyElement(isNull));

            // And the negation, which has to become `IS NOT NULL`.
            var notNullLevel = await userAPIRepository.selectByQuery(
              " level != ? ",
              parameters: {'level': null},
            );

            expect(notNullLevel, isNotEmpty);
            expect(
              notNullLevel.map((e) => e.level),
              everyElement(isNotNull),
              reason: 'a negated null parameter must select the non-null rows',
            );
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [1],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [1, 3],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [1, 2],
              },
            );

            expect(user4?.id, equals(user3.id));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [2, 5],
              },
            );

            expect(user4?.id, allOf(isNotNull, isNot(equals(user3.id))));
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles =~ ?",
              parameters: {
                'roles': [2001, 20002],
              },
            );

            expect(user4, isNull);
          }

          {
            var user4 = await userAPIRepository.selectFirstByQuery(
              "roles == ?",
              parameters: {
                'roles': [2000],
              },
            );

            expect(user4, isNull);
          }
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info),
              equals([null, null, null]),
            );

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.isAborted, isFalse);
          expect(transaction.length, equals(9));
          expect(transaction.cachedEntitiesLength, equals(12));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ], resolutionRules: EntityResolutionRules.fetchEagerAll());

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info).toList(),
              unorderedEquals(['The user joe', null, null]),
            );

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.isAborted, isFalse);
          expect(transaction.length, equals(11));
          expect(transaction.cachedEntitiesLength, equals(14));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info).toList(),
              equals([null, null, null]),
            );

            var user1 = sel.first;

            user1.level = 123;

            var storeId = await userAPIRepository.store(user1);
            expect(storeId, equals(user1.id));

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.isAborted, isFalse);
          expect(transaction.length, greaterThanOrEqualTo(7));
          expect(transaction.cachedEntitiesLength, equals(12));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ], resolutionRules: EntityResolutionRules.fetchEagerAll());

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info).toList(),
              unorderedEquals(['The user joe', null, null]),
            );

            var user1 = sel.first;

            user1.level = 123;

            var storeId = await userAPIRepository.store(user1);
            expect(storeId, equals(user1.id));

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.isAborted, isFalse);
          expect(transaction.length, greaterThanOrEqualTo(7));
          expect(transaction.cachedEntitiesLength, equals(14));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info).toList(),
              equals([null, null, null]),
            );

            var user1 = sel.firstWhere((e) => e.address.state == 'NY');

            user1.address.city = 'Jersey City';

            var storeId = await userAPIRepository.store(user1);
            expect(storeId, equals(user1.id));

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            var user2 = sel.firstWhere((e) => e.address.state == 'NY');

            expect(user2.address.city, equals('Jersey City'));

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.length, greaterThanOrEqualTo(8));
          expect(transaction.cachedEntitiesLength, equals(12));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var sel = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ], resolutionRules: EntityResolutionRules.fetchEagerAll());

            expect(sel.length, equals(3));
            expect(
              sel.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            expect(
              sel.map((e) => e.userInfo.entity?.info).toList(),
              unorderedEquals(['The user joe', null, null]),
            );

            var user1 = sel.firstWhere((e) => e.address.state == 'NY');

            user1.address.city = 'Jersey City';

            var storeId = await userAPIRepository.store(user1);
            expect(storeId, equals(user1.id));

            var sel2 = await userAPIRepository.selectByINAddressStates([
              'NY',
              'CA',
            ]);

            expect(sel2.length, equals(3));
            expect(
              sel2.map((e) => e.address.state),
              unorderedEquals(['NY', 'CA', 'CA']),
            );

            var user2 = sel.firstWhere((e) => e.address.state == 'NY');

            expect(user2.address.city, equals('Jersey City'));

            return sel2;
          });

          print(transaction);

          expect(result!.length, equals(3));
          expect(transaction.length, greaterThanOrEqualTo(8));
          expect(transaction.cachedEntitiesLength, equals(14));
        }

        {
          var sel = await userAPIRepository.selectByINAddressStates([
            'NY',
            'CA',
            'N/A',
          ]);

          expect(sel.length, equals(3));
          expect(
            sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']),
          );
          expect(
            sel.map((e) => e.address.city),
            unorderedEquals(['Los Angeles', 'Los Angeles', 'Jersey City']),
          );
        }

        {
          var sel = await userAPIRepository.selectByINAddressStates(['NY']);

          expect(sel.length, equals(1));
          expect(sel.map((e) => e.address.state), equals(['NY']));
        }

        {
          var sel = await userAPIRepository.selectByINAddressStatesSingleValue(
            'CA',
          );

          expect(sel.length, equals(2));
          expect(
            sel.map((e) => e.address.state),
            unorderedEquals(['CA', 'CA']),
          );
        }

        {
          var sel = await userAPIRepository.selectByINAddressStates([
            'NY',
            'CA',
            ...List.generate(10, (i) => '$i'),
          ]);

          expect(sel.length, equals(3));
          expect(
            sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']),
          );
        }

        {
          var sel = await userAPIRepository.selectByINAddressStates([
            'NY',
            'CA',
            ...List.generate(100, (i) => '$i'),
          ]);

          expect(sel.length, equals(3));
          expect(
            sel.map((e) => e.address.state),
            unorderedEquals(['NY', 'CA', 'CA']),
          );
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

          expect(sel.length, equals(2));

          expect(
            sel.map((e) => e.email),
            unorderedEquals(['smith@$testDomain', 'john@$testDomain']),
          );

          expect(sel.map((e) => e.address.state), equals(['CA', 'CA']));

          var user = sel.firstWhere((e) => e.email.startsWith('smith'));
          expect(user.email, equals('smith@$testDomain'));
          expect(user.address.state, equals('CA'));

          user.email = 'smith2@$testDomain';

          var ok = await userAPIRepository.store(user);
          expect(ok, equals(user.id));
        }

        {
          var user = await userAPIRepository.selectByEmail(
            'smith2@$testDomain',
          );

          expect(user!.email, equals('smith2@$testDomain'));
          expect(user.address.state, equals('CA'));

          user.email = 'smith3@$testDomain';

          var ok = await userAPIRepository.store(user);
          expect(ok, equals(user.id));

          var user2 = await userAPIRepository.selectByEmail(
            'smith3@$testDomain',
          );

          expect(user2!.id, equals(user.id));
          expect(user2.email, equals('smith3@$testDomain'));
        }

        {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            var executingTransaction = Transaction.executingTransaction;
            expect(executingTransaction, isNotNull);
            expect(executingTransaction!.isEmpty, isTrue);

            var user = await userAPIRepository.selectByEmail(
              'smith3@$testDomain',
            );

            expect(executingTransaction.isNotEmpty, isTrue);

            expect(user!.email, equals('smith3@$testDomain'));
            expect(user.address.state, equals('CA'));

            user.email = 'smith4@$testDomain';
            var ok = await userAPIRepository.store(user);
            expect(ok, equals(user.id));

            var user2 = await userAPIRepository.selectByEmail(
              'smith4@$testDomain',
            );

            expect(user2!.email, equals('smith4@$testDomain'));

            return user2.email;
          });

          print(transaction);

          expect(result, equals('smith4@$testDomain'));

          expect(transaction.isOpen, isTrue);
          expect(transaction.isAborted, isFalse);
          expect(transaction.isCommitted, isTrue);
          expect(transaction.length, greaterThanOrEqualTo(7));
          expect(transaction.abortError, isNull);
        }

        // If `Transaction.abort` is supported:
        if (sqlAdapter.capability.transactionAbort) {
          var transaction = Transaction();

          var result = await transaction.execute(() async {
            try {
              var user = await userAPIRepository.selectByEmail(
                'smith4@$testDomain',
              );

              expect(user!.email, equals('smith4@$testDomain'));

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
          expect(transaction.length, greaterThanOrEqualTo(6));
          expect(transaction.abortError, isNotNull);
          expect(transaction.abortError?.reason, equals('Test'));
        }

        {
          var user = await userAPIRepository.selectByID(user2Id);

          expect(user!.email, equals('smith4@$testDomain'));

          user.roles.add(Role(RoleType.unknown));

          var ok = await userAPIRepository.store(user);
          expect(ok, equals(user.id));

          var rolesJson2a = [
            {'id': 2, 'type': 'guest', 'enabled': true, 'value': '123.4500'},
            {'id': 4, 'type': 'unknown', 'enabled': true, 'value': null},
          ];

          var rolesJson2b = [
            {'id': 2, 'type': 'guest', 'enabled': true, 'value': '123.45'},
            {'id': 4, 'type': 'unknown', 'enabled': true, 'value': null},
          ];

          expect(
            user.roles.map(
              (e) => entityByReflection ? e.toJsonFromFields() : e.toJson(),
            ),
            anyOf(equals(rolesJson2a), equals(rolesJson2b)),
          );

          var user2 = await userAPIRepository.selectByID(user.id);
          expect(user2!.email, equals(user.email));
          expect(
            user2.roles.map(
              (e) => entityByReflection ? e.toJsonFromFields() : e.toJson(),
            ),
            anyOf(equals(rolesJson2a), equals(rolesJson2b)),
          );

          user2.roles.removeWhere((r) => r.type == RoleType.guest);

          var ok2 = await userAPIRepository.store(user2);
          expect(ok2, equals(user.id));

          var user3 = await userAPIRepository.selectByID(user.id);
          expect(user3!.email, equals(user.email));

          var rolesJson3 = [
            {'id': 4, 'type': 'unknown', 'enabled': true, 'value': null},
          ];
          expect(
            user3.roles.map(
              (e) => entityByReflection ? e.toJsonFromFields() : e.toJson(),
            ),
            equals(rolesJson3),
          );

          user3.roles = [];

          var ok4 = await userAPIRepository.store(user3);
          expect(ok4, equals(user.id));

          var user4 = await userAPIRepository.selectByID(user.id);
          expect(user4!.email, equals(user.email));
          expect(user4.roles, isEmpty);
        }

        {
          var del = await userAPIRepository.deleteByQuery(
            ' #ID == ? ',
            parameters: [user2Id],
          );
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
          var user1 = await userAPIRepository.selectFirstByQuery(
            ' email == ? ',
            parameters: {'email': 'joe@$testDomain'},
          );
          expect(user1, isNotNull);
          expect(user1?.email, equals('joe@$testDomain'));
          expect(user1?.roles.map((e) => e.id), unorderedEquals([1, 3]));

          var userId = user1!.id;

          var user2 = await userAPIRepository.selectByID(userId);
          expect(user2, equals(user1));

          expect(user2!.roles.length, equals(2));
          user2.roles.removeWhere((e) => e.id == 3);
          expect(user2.roles.length, equals(1));

          var storedId = await userAPIRepository.store(user2);
          expect(storedId, equals(userId));

          var user3 = await userAPIRepository.selectByID(userId);
          expect(user3, equals(user1));
          expect(user3!.roles.map((e) => e.id), unorderedEquals([1]));
        }

        {
          var del1 = await userAPIRepository.delete(
            Condition.parse(' email == ? '),
            parameters: {'email': 'joex@$testDomain'},
          );
          expect(del1, isEmpty);

          var del2 = await userAPIRepository.delete(
            Condition.parse(' email == ? '),
            parameters: {'email': 'joe@$testDomain'},
          );
          expect(del2.length, equals(1));
          expect(del2.first.email, equals('joe@$testDomain'));
        }

        {
          var address1 = await addressAPIRepository.storeFromJson({
            'state': 'EX',
            'city': 'Extra',
            'street': 'Street x',
            'number': 777,
          });

          expect(address1, isNotNull);
          expect(address1.id, isNotNull);
          expect(address1.number, 777);

          var address2 = await addressAPIRepository.selectByID(address1.id);
          expect(address2!.toJsonEncoded(), equals(address1.toJsonEncoded()));

          var del1 = await addressAPIRepository.deleteByID(address1.id);

          expect(del1, isNotNull);
          expect(del1!.id, address1.id);
          expect(del1.number, address1.number);
        }

        {
          var address1 = await addressAPIRepository.storeFromJson({
            'state': 'EX',
            'city': 'Extra2',
            'street': 'Street z',
            'number': 888,
          });

          expect(address1, isNotNull);
          expect(address1.id, isNotNull);
          expect(address1.number, 888);

          var address2 = await addressAPIRepository.selectByID(address1.id);
          expect(address2!.toJsonEncoded(), equals(address1.toJsonEncoded()));

          var del1 = await addressAPIRepository.deleteEntity(address1);

          expect(del1, isNotNull);
          expect(del1!.id, address1.id);
          expect(del1.number, address1.number);
        }

        {
          var address1 = await addressAPIRepository.storeFromJson({
            'id': 11001,
            'state': 'EX',
            'city': 'Extra',
            'street': 'Street x',
            'number': 999,
          });

          expect(address1, isNotNull);
          expect(address1.id, 11001);
          expect(address1.number, 999);

          var address2 = await addressAPIRepository.selectByID(address1.id);
          expect(address2!.toJsonEncoded(), equals(address1.toJsonEncoded()));
        }

        {
          var address1 = Address('EX', 'Extra', 'Street Double', 201);
          var address2 = Address('EX', 'Extra', 'Street Double', 202);

          var addressesIDs = await addressAPIRepository.storeAll([
            address1,
            address2,
          ]);

          expect(addressesIDs.length, equals(2));

          var address1Id = addressesIDs[0];
          var address2Id = addressesIDs[1];

          expect(address1Id, isNotNull);
          expect(address2Id, isNotNull);

          expect(address1.number, 201);
          expect(address2.number, 202);

          var sel = await addressAPIRepository.selectByIDs([
            address1Id,
            address2Id,
          ]);

          expect(sel.length, equals(2));

          expect(sel[0]?.id, equals(address1.id));
          expect(sel[1]?.id, equals(address2.id));

          expect(sel[0]?.number, equals(201));
          expect(sel[1]?.number, equals(202));
        }

        // Test multiple sub-store of the same sub-entity:
        //
        //   User#2 -> Address#2 -> Store#1 -> User#1
        //                       -> Store#2 -> User#1
        //
        {
          var address1 = Address('EX', 'Extra', 'Street One', 101);
          var user1 = User('user111@mail.com', '111', address1, []);

          var store1 = Store('1x', 1, owner: user1);
          var store2 = Store('2x', 2, owner: user1);
          var address2 = Address(
            'EX',
            'Extra',
            'Street Double',
            202,
            stores: [store1, store2],
          );

          var role2 = Role(RoleType.admin, enabled: true);
          var user2 = User('user222@mail.com', '222', address2, [role2]);

          var id = await userAPIRepository.store(user2);

          expect(id, isNotNull);
          expect(id, equals(user2.id));

          expect(user1.id, isNotNull);
          expect(store1.id, isNotNull);
          expect(store2.id, isNotNull);

          expect(user2.id, isNotNull);
          expect(address2.id, isNotNull);
          expect(role2.id, isNotNull);
        }

        // Recursive Relationship Loop Error:
        //
        //   User#3 -> Address#3 -> Store#3 -> User#3
        //
        {
          var store3 = Store('3x', 3);
          var address3 = Address(
            'EX',
            'Extra',
            'Street Triple',
            301,
            stores: [store3],
          );
          var role3 = Role(RoleType.admin, enabled: true);
          var user3 = User('user3@mail.com', '333', address3, [role3]);
          store3.owner = user3;

          var openTransactions0 = Transaction.openInstances
              .where((t) => !t.isFinished)
              .length;
          var rolesLength0 = await roleAPIRepository.length();

          await expectLater(
            () async => await userAPIRepository.store(user3),
            throwsA(isA<RecursiveRelationshipLoopError>()),
          );

          // Its auto-commit transaction is aborted (not left open, holding
          // its connection), and the role already inserted rolled back:
          await Future.delayed(Duration(milliseconds: 50));
          expect(
            Transaction.openInstances.where((t) => !t.isFinished).length,
            lessThanOrEqualTo(openTransactions0),
          );
          if (sqlAdapter.capability.transactionAbort) {
            expect(await roleAPIRepository.length(), equals(rolesLength0));
          }
        }
      });

      test('Entity tracking: changed fields', () async {
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;
        final addressAPIRepository =
            entityRepositoryProvider.addressAPIRepository;
        final roleAPIRepository = entityRepositoryProvider.roleAPIRepository;
        final userRepository = userAPIRepository.entityRepository;

        var userId = await userAPIRepository.store(
          User(
            'tracking@mail.com',
            '123',
            Address('TR', 'Track City', 'Track Street', 1),
            [Role(RoleType.guest)],
          ),
        );

        Future<User> load() async =>
            (await userAPIRepository.selectByID(userId))!;

        // Untouched:
        {
          var user = await load();
          expect(userRepository.getEntityChangedFields(user), isEmpty);
          expect(userRepository.entityHasChangedFields(user), isFalse);
        }

        // A scalar field:
        {
          var user = await load();
          user.email = 'tracking2@mail.com';
          expect(
            userRepository.getEntityChangedFields(user),
            equals(['email']),
          );
        }

        // A field of the referenced entity is not a change of the user:
        {
          var user = await load();
          user.address.city = 'Other City';
          expect(userRepository.getEntityChangedFields(user), isEmpty);
        }

        // Another referenced entity:
        {
          var otherAddress = Address('TR', 'Track City 2', 'Track Street', 2);
          await addressAPIRepository.store(otherAddress);

          var user = await load();
          user.address = otherAddress;
          expect(
            userRepository.getEntityChangedFields(user),
            equals(['address']),
          );
        }

        // The same referenced entity, as another instance:
        {
          var user = await load();
          user.address = (await addressAPIRepository.selectByID(
            user.address.id,
          ))!;
          expect(userRepository.getEntityChangedFields(user), isEmpty);
        }

        // A list of entities: same IDs, added, removed:
        {
          var user = await load();
          user.roles = user.roles.toList();
          expect(userRepository.getEntityChangedFields(user), isEmpty);

          var admin = Role(RoleType.admin);
          await roleAPIRepository.store(admin);

          user = await load();
          user.roles = [...user.roles, admin];
          expect(
            userRepository.getEntityChangedFields(user),
            equals(['roles']),
          );

          user = await load();
          user.roles = [];
          expect(
            userRepository.getEntityChangedFields(user),
            equals(['roles']),
          );
        }

        // Storing a change updates the tracked state:
        {
          var user = await load();
          user.email = 'tracking3@mail.com';
          await userAPIRepository.store(user);
          expect(userRepository.getEntityChangedFields(user), isEmpty);
          expect((await load()).email, equals('tracking3@mail.com'));
        }
      });

      test('Transaction abort restores relationships', () async {
        final sqlAdapter = await entityRepositoryProvider.adapter;
        if (!sqlAdapter.capability.transactionAbort) return;

        final userAPIRepository = entityRepositoryProvider.userAPIRepository;
        final roleAPIRepository = entityRepositoryProvider.roleAPIRepository;

        var admin = Role(RoleType.admin);
        var guest = Role(RoleType.guest);
        await roleAPIRepository.store(admin);
        await roleAPIRepository.store(guest);

        var userId = await userAPIRepository.store(
          User(
            'rollback@mail.com',
            '123',
            Address('RB', 'Rollback City', 'Rollback Street', 1),
            [admin, guest],
          ),
        );

        Future<List<int?>> roleIdsOfUser() async =>
            (await userAPIRepository.selectByID(userId))!.roles
                .map((r) => r.id)
                .toList()
              ..sort();

        Future<List<int?>> usersWithAdmin() async =>
            (await userAPIRepository.selectByRoleId(admin.id!))
                .map((u) => u.id)
                .toList();

        expect(await roleIdsOfUser(), equals([admin.id, guest.id]..sort()));
        expect(await usersWithAdmin(), contains(userId));

        // Remove the `admin` link, then abort:
        var transaction = Transaction();
        await transaction.execute(() async {
          var user = (await userAPIRepository.selectByID(userId))!;
          user.roles = [guest];
          await userAPIRepository.store(user);
          transaction.abort(reason: 'Test');
        });
        expect(transaction.isAborted, isTrue);

        // Both the user's own roles and a query through the relationship
        // must see the link again:
        expect(await roleIdsOfUser(), equals([admin.id, guest.id]..sort()));
        expect(await usersWithAdmin(), contains(userId));
      });

      test('setRelationship: replaces the relationship', () async {
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;
        final userRepository =
            userAPIRepository.entityRepository
                as DBRelationalEntityRepository<User>;

        var userId = await userAPIRepository.store(
          User(
            'set-relationship@mail.com',
            '123',
            Address('SR', 'Set City', 'Set Street', 1),
            [Role(RoleType.guest), Role(RoleType.admin)],
          ),
        );

        var user = (await userAPIRepository.selectByID(userId))!;
        expect(user.roles, hasLength(2));

        var admin = user.roles.firstWhere((r) => r.type == RoleType.admin);

        // Directly (not through `store`): only the admin role is kept.
        expect(
          await userRepository.setRelationship(user, 'roles', [admin]),
          isTrue,
        );

        var user2 = (await userAPIRepository.selectByID(userId))!;
        expect(user2.roles.map((r) => r.id), equals([admin.id]));
      });

      test('selectRelationships with a repeated entity', () async {
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;
        final userRepository =
            userAPIRepository.entityRepository
                as DBRelationalEntityRepository<User>;

        var userId = await userAPIRepository.store(
          User(
            'repeated@mail.com',
            '123',
            Address('RE', 'Repeated City', 'Repeated Street', 1),
            [Role(RoleType.guest), Role(RoleType.admin)],
          ),
        );

        var user = (await userAPIRepository.selectByID(userId))!;
        var roleIds = user.roles.map((r) => r.id).toList()..sort();
        expect(roleIds, hasLength(2));

        // The same entity twice (`"user" IN (id, id)`): each relationship
        // must still be returned once.
        var relationships = await userRepository.selectRelationships([
          user,
          user,
        ], 'roles');

        expect(relationships.keys, equals([userId]));
        expect(relationships[userId]!.toList()..sort(), equals(roleIds));
      });

      test('readsOutsideTransaction', () async {
        final sqlAdapter = await entityRepositoryProvider.adapter;
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;

        var userId = await userAPIRepository.store(
          User(
            'reads@mail.com',
            '123',
            Address('RO', 'Reads City', 'Reads Street', 1),
            [Role(RoleType.guest)],
          ),
        );

        // Only reads (the user, its roles and its address):
        {
          var transaction = Transaction();
          var user = await transaction.execute(
            () => userAPIRepository.selectByID(userId),
          );

          expect(user!.email, equals('reads@mail.com'));
          expect(user.roles, hasLength(1));
          expect(transaction.length, greaterThan(1));
          expect(transaction.isCommitted, isTrue);
          // With `readsOutsideTransaction` there is no `BEGIN` to send:
          expect(transaction.isOpen, !sqlAdapter.readsOutsideTransaction);
        }

        // A read, then a write: the write opens the transaction.
        {
          var transaction = Transaction();
          await transaction.execute(() async {
            var user = (await userAPIRepository.selectByID(userId))!;
            user.email = 'reads2@mail.com';
            await userAPIRepository.store(user);
          });

          expect(transaction.isCommitted, isTrue);
          expect(transaction.isOpen, isTrue);
          expect(
            (await userAPIRepository.selectByID(userId))!.email,
            equals('reads2@mail.com'),
          );
        }
      });

      test('executedSQLsCount: statements per operation', () async {
        final sqlAdapter = await entityRepositoryProvider.adapter;
        final userAPIRepository = entityRepositoryProvider.userAPIRepository;

        // How many statements (round trips) each operation sends. This pins
        // the current behavior: an optimization that removes statements has
        // to update it, and a regression that adds some fails here.
        Future<(T, int)> counted<T>(FutureOr<T> Function() f) async {
          var before = sqlAdapter.executedSQLsCount;
          var r = await f();
          return (r, sqlAdapter.executedSQLsCount - before);
        }

        var (userId, insertCount) = await counted(
          () => userAPIRepository.store(
            User(
              'count1@$testDomain',
              '123',
              Address('CQ', 'Count City', 'Count Street', 1),
              [Role(RoleType.guest), Role(RoleType.admin)],
            ),
          ),
        );
        // The address, the 2 roles, the user and its 2 role links. Without
        // `generatedIDsHaveNoRelationships`, also a `DELETE` of the other
        // links of each list field: 2 of the address (empty fields) and 1 of
        // the user.
        expect(userId, isNotNull);
        expect(
          insertCount,
          equals(sqlAdapter.generatedIDsHaveNoRelationships ? 6 : 9),
          reason: 'insert',
        );

        await userAPIRepository.store(
          User(
            'count2@$testDomain',
            '123',
            Address('CQ', 'Count City', 'Count Street', 2),
            [Role(RoleType.guest)],
          ),
        );

        // The user, its role links, its roles, its address and the links of
        // the address's 2 list fields:
        var (user, selectByIDCount) = await counted(
          () => userAPIRepository.selectByID(userId),
        );
        expect(user!.roles, hasLength(2));
        expect(selectByIDCount, equals(6), reason: 'selectByID');

        // A JOIN condition, 2 users: the same 6, batched.
        var (users, selectCount) = await counted(
          () => userAPIRepository.selectByQuery(
            ' address.state == ? ',
            parameters: {'state': 'CQ'},
          ),
        );
        expect(users, hasLength(2));
        expect(selectCount, equals(6), reason: 'selectByQuery');

        var (_, countCount) = await counted(() => userAPIRepository.length());
        expect(countCount, equals(1), reason: 'length');

        user.roles.removeWhere((r) => r.type == RoleType.admin);
        var (_, updateCount) = await counted(
          () => userAPIRepository.store(user),
        );
        // The kept role link (`INSERT ... ON CONFLICT DO NOTHING`) and a
        // `DELETE` of the others; the user row itself didn't change.
        expect(updateCount, equals(2), reason: 'update (roles)');

        // The `DELETE ... RETURNING`, then the returned user is resolved:
        // its role links and its address with its 2 list fields' links (the
        // links are removed with the user, so no roles are selected). The
        // memory adapter keeps the role links: the links and the roles.
        var (deleted, deleteCount) = await counted(
          () => userAPIRepository.deleteByID(userId),
        );
        expect(deleted, isNotNull);
        expect(
          deleteCount,
          equals(sqlAdapter is DBSQLMemoryAdapter ? 3 : 5),
          reason: 'deleteByID',
        );
      });

      test('Multi-level Query: Order.items.bonus.campaign == ?', () async {
        //////////

        {
          final campaignRepo = entityRepositoryProvider.campaignAPIRepository;
          final bonusRepo = entityRepositoryProvider.bonusAPIRepository;
          final itemRepo = entityRepositoryProvider.itemAPIRepository;
          final orderRepo = entityRepositoryProvider.orderAPIRepository;

          // Create campaign
          var campaign = Campaign('Summer Promo');
          var campaignId = await campaignRepo.store(campaign);
          expect(campaignId, isNotNull);

          // Create bonus referencing the campaign (by id)
          var bonus = Bonus(campaign: campaignId);
          var bonusId = await bonusRepo.store(bonus);
          expect(bonusId, isNotNull);

          // Create item referencing the bonus (by id)
          var item = Item('Widget', bonus: bonusId);
          var itemId = await itemRepo.store(item);
          expect(itemId, isNotNull);

          // Create order containing the item
          var order = Order('ORD-CHAIN-001', items: [item]);
          var orderId = await orderRepo.store(order);
          expect(orderId, isNotNull);

          // Negative case: order without the referenced campaign
          var otherOrder = Order('ORD-CHAIN-002', items: []);
          await orderRepo.store(otherOrder);

          // Query orders by campaign id using multi-level chain
          var results = (await orderRepo.selectByCampaignId(campaignId))
              .toList();
          var numbers = results.map((o) => o.orderNumber).toList();

          expect(numbers, contains('ORD-CHAIN-001'));
          expect(numbers, isNot(contains('ORD-CHAIN-002')));
        }
      });

      test(
        'Multi-level Query: Order.items.bonus.campaign.config.open == true',
        () async {
          {
            final campaignRepo = entityRepositoryProvider.campaignAPIRepository;
            final campaignConfigRepo =
                entityRepositoryProvider.campaignConfigAPIRepository;
            final bonusRepo = entityRepositoryProvider.bonusAPIRepository;
            final itemRepo = entityRepositoryProvider.itemAPIRepository;
            final orderRepo = entityRepositoryProvider.orderAPIRepository;

            // Create two campaign configs
            var cfgOpen = CampaignConfig(open: true);
            var cfgClosed = CampaignConfig(open: false);
            var cfgOpenId = await campaignConfigRepo.store(cfgOpen);
            var cfgClosedId = await campaignConfigRepo.store(cfgClosed);
            expect(cfgOpenId, isNotNull);
            expect(cfgClosedId, isNotNull);

            // Create campaigns referencing configs
            var campaignOpen = Campaign('Promo Open', config: cfgOpenId);
            var campaignClosed = Campaign('Promo Closed', config: cfgClosedId);
            var campaignOpenId = await campaignRepo.store(campaignOpen);
            var campaignClosedId = await campaignRepo.store(campaignClosed);
            expect(campaignOpenId, isNotNull);
            expect(campaignClosedId, isNotNull);

            // Create bonuses referencing campaigns
            var bonusOpen = Bonus(campaign: campaignOpenId);
            var bonusClosed = Bonus(campaign: campaignClosedId);
            var bonusOpenId = await bonusRepo.store(bonusOpen);
            var bonusClosedId = await bonusRepo.store(bonusClosed);
            expect(bonusOpenId, isNotNull);
            expect(bonusClosedId, isNotNull);

            // Create items referencing bonuses
            var itemOpen = Item('WidgetA', bonus: bonusOpenId);
            var itemClosed = Item('WidgetB', bonus: bonusClosedId);
            var itemOpenId = await itemRepo.store(itemOpen);
            var itemClosedId = await itemRepo.store(itemClosed);
            expect(itemOpenId, isNotNull);
            expect(itemClosedId, isNotNull);

            // Create orders
            var orderOpen = Order('ORD-CONFIG-001', items: [itemOpen]);
            var orderClosed = Order('ORD-CONFIG-002', items: [itemClosed]);
            var orderOpenId = await orderRepo.store(orderOpen);
            var orderClosedId = await orderRepo.store(orderClosed);
            expect(orderOpenId, isNotNull);
            expect(orderClosedId, isNotNull);

            // Query orders where items.bonus.campaign.config.open == true
            var results = (await orderRepo.selectByQuery(
              ' items.bonus.campaign.config.open == ? ',
              parameters: [true],
            )).toList();

            var numbers = results.map((o) => o.orderNumber).toList();
            expect(numbers, contains('ORD-CONFIG-001'));
            expect(numbers, isNot(contains('ORD-CONFIG-002')));
          }
        },
      );

      test('generateSelectSQL: ORDER BY / LIMIT / OFFSET', () async {
        var sqlAdapter = await entityRepositoryProvider.adapter;
        // NOTE: not `cmdQuote` (the DDL quote asserted by
        // `generateFullCreateTableSQLs`): the `generic` dialect of
        // `DBSQLMemoryAdapter` has an empty element quote.
        var q = sqlAdapter.dialect.elementQuote;

        FutureOr<SQL> selectSQL({
          int? limit,
          int? offset,
          bool? orderByID,
          OrderDirection? orderDirection,
        }) => sqlAdapter.generateSelectSQL(
          Transaction(),
          'Campaign',
          'campaign',
          ConditionANY(),
          limit: limit,
          offset: offset,
          orderByID: orderByID,
          orderDirection: orderDirection,
        );

        // The `ORDER BY` column is the table ID, resolved from the
        // `TableScheme` of the DB:
        final orderByIdAsc = ' ORDER BY ${q}ca$q.${q}id$q ASC';
        final orderByIdDesc = ' ORDER BY ${q}ca$q.${q}id$q DESC';

        // Baseline: the pre-existing SQL is unchanged.
        expect((await selectSQL()).sql, isNot(contains('ORDER BY')));
        expect((await selectSQL()).sql, isNot(contains('LIMIT')));
        expect((await selectSQL()).sql, isNot(contains('OFFSET')));

        expect((await selectSQL(limit: 2)).sql, endsWith(' LIMIT 2'));

        // `orderDirection` alone is ignored:
        expect(
          (await selectSQL(orderDirection: OrderDirection.descending)).sql,
          isNot(contains('ORDER BY')),
        );

        expect((await selectSQL(orderByID: true)).sql, endsWith(orderByIdAsc));

        expect(
          (await selectSQL(
            orderByID: true,
            orderDirection: OrderDirection.descending,
          )).sql,
          endsWith(orderByIdDesc),
        );

        // An `offset` implies the ordering, so the pagination is stable:
        expect(
          (await selectSQL(limit: 2, offset: 3)).sql,
          endsWith('$orderByIdAsc LIMIT 2 OFFSET 3'),
        );

        expect(
          (await selectSQL(offset: 3, orderByID: false)).sql,
          isNot(contains('ORDER BY')),
        );

        // An `offset` with no `limit` is the dialect-specific case: MySQL can't
        // parse a standalone `OFFSET`, so it gets the maximum row count as the
        // `LIMIT` instead.
        var offsetOnly = (await selectSQL(offset: 3)).sql;
        if (sqlAdapter.dialect.offsetRequiresLimit) {
          expect(
            offsetOnly,
            endsWith(
              '$orderByIdAsc'
              ' LIMIT ${sqlAdapter.dialect.offsetMaxLimitValue} OFFSET 3',
            ),
          );
        } else {
          expect(offsetOnly, endsWith('$orderByIdAsc OFFSET 3'));
        }
      });

      test('Pagination: orderByID / orderDirection / offset / limit', () async {
        final campaignRepo = entityRepositoryProvider.campaignAPIRepository;

        // Store 5 campaigns and keep their (ascending) IDs. Every query below
        // is scoped with ` id >= ? ` so the campaigns stored by the previous
        // tests of this group can't leak into the assertions.
        var ids = <int>[];
        for (var i = 1; i <= 5; ++i) {
          var id = await campaignRepo.store(Campaign('PAGE-0$i'));
          expect(id, isNotNull);
          ids.add(id as int);
        }

        expect(ids.length, equals(5));
        expect(
          ids,
          orderedEquals([...ids]..sort()),
          reason: "The stored IDs must be ascending: $ids",
        );

        final firstId = ids.first;

        Future<List<Object?>> selectIDs({
          int? limit,
          int? offset,
          int? page,
          bool? orderByID,
          OrderDirection? orderDirection,
        }) async {
          var sel = await campaignRepo.selectByQuery(
            ' id >= ? ',
            parameters: [firstId],
            limit: limit,
            offset: offset,
            page: page,
            orderByID: orderByID,
            orderDirection: orderDirection,
          );
          return sel.map((e) => e.id).toList();
        }

        // Ordering:
        expect(await selectIDs(orderByID: true), equals(ids));

        expect(
          await selectIDs(
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ),
          equals(ids.reversed.toList()),
        );

        expect(
          await selectIDs(orderByID: true, limit: 2),
          equals(ids.take(2).toList()),
        );

        // `offset` implies `orderByID`:
        expect(
          await selectIDs(offset: 2, limit: 2),
          equals(ids.skip(2).take(2).toList()),
        );

        // An `offset` with no `limit`: the MySQL
        // `LIMIT <offsetMaxLimitValue> OFFSET n` path.
        expect(await selectIDs(offset: 3), equals(ids.skip(3).toList()));

        expect(
          await selectIDs(
            offset: 1,
            limit: 2,
            orderDirection: OrderDirection.descending,
          ),
          equals(ids.reversed.skip(1).take(2).toList()),
        );

        expect(await selectIDs(offset: ids.length), isEmpty);

        // Paging through reassembles the full set exactly once:
        var pages = <List<Object?>>[];
        for (var offset = 0; offset < ids.length; offset += 2) {
          pages.add(await selectIDs(limit: 2, offset: offset));
        }
        expect(pages.expand((p) => p).toList(), equals(ids));

        // `orderDirection` alone is ignored (the order stays unspecified):
        expect(
          await selectIDs(orderDirection: OrderDirection.descending),
          unorderedEquals(ids),
        );

        // `selectIDsByQuery`:
        expect(
          (await campaignRepo.selectIDsByQuery<int>(
            ' id >= ? ',
            parameters: [firstId],
            offset: 2,
            limit: 2,
          )).toList(),
          equals(ids.skip(2).take(2).toList()),
        );

        // `selectFirstByQuery`:
        expect(
          (await campaignRepo.selectFirstByQuery(
            ' id >= ? ',
            parameters: [firstId],
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ))?.id,
          equals(ids.last),
        );

        // `selectAll` can't assert exact IDs (the previous tests of this group
        // also stored campaigns), only that the pagination is applied:
        expect(
          (await campaignRepo.selectAll(limit: 2, orderByID: true)).length,
          equals(2),
        );

        // `page` is 1-based and computes the offset from the `limit`:
        expect(
          await selectIDs(limit: 2, page: 1),
          equals(ids.take(2).toList()),
        );
        expect(
          await selectIDs(limit: 2, page: 2),
          equals(ids.skip(2).take(2).toList()),
        );
        expect(
          await selectIDs(limit: 2, page: 3),
          equals(ids.skip(4).take(2).toList()),
        );
        expect(await selectIDs(limit: 2, page: 4), isEmpty);

        expect(
          await selectIDs(
            limit: 2,
            page: 2,
            orderDirection: OrderDirection.descending,
          ),
          equals(ids.reversed.skip(2).take(2).toList()),
        );

        // Paging by `page` reassembles the full set exactly once:
        var byPage = <List<Object?>>[];
        for (var page = 1; page <= 3; ++page) {
          byPage.add(await selectIDs(limit: 2, page: page));
        }
        expect(byPage.expand((p) => p).toList(), equals(ids));

        // `page` is rejected without a positive `limit`, alongside an
        // `offset`, or below 1:
        expect(() => selectIDs(page: 2), throwsArgumentError);
        expect(() => selectIDs(page: 2, limit: 0), throwsArgumentError);
        expect(
          () => selectIDs(page: 2, limit: 2, offset: 2),
          throwsArgumentError,
        );
        expect(() => selectIDs(page: 0, limit: 2), throwsArgumentError);
      });

      test('Pagination: JOIN, eager resolution and stability', () async {
        final campaignRepo = entityRepositoryProvider.campaignAPIRepository;
        final campaignConfigRepo =
            entityRepositoryProvider.campaignConfigAPIRepository;

        var cfgId = await campaignConfigRepo.store(CampaignConfig(open: true));
        expect(cfgId, isNotNull);

        var ids = <int>[];
        for (var i = 1; i <= 5; ++i) {
          var id = await campaignRepo.store(
            Campaign('JOIN-0$i', config: cfgId),
          );
          ids.add(id as int);
        }
        expect(ids, orderedEquals([...ids]..sort()));

        // A condition over a referenced entity generates a `JOIN`. The
        // `ORDER BY` must target the MAIN table's alias (`campaign`), not the
        // joined one, otherwise the paging below would be ordered by the
        // config's ID -- which is the same row for all 5 campaigns.
        Future<List<Object?>> selectJoined({
          int? limit,
          int? offset,
          bool? orderByID,
          OrderDirection? orderDirection,
          EntityResolutionRules? resolutionRules,
        }) async {
          var sel = await campaignRepo.selectByQuery(
            ' config.open == ? && id >= ? ',
            parameters: [true, ids.first],
            limit: limit,
            offset: offset,
            orderByID: orderByID,
            orderDirection: orderDirection,
            resolutionRules: resolutionRules,
          );
          return sel.map((e) => e.id).toList();
        }

        expect(await selectJoined(orderByID: true), equals(ids));

        expect(
          await selectJoined(
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ),
          equals(ids.reversed.toList()),
        );

        expect(
          await selectJoined(limit: 2, offset: 2),
          equals(ids.skip(2).take(2).toList()),
        );

        // Paging a JOIN query must still reassemble the full set:
        var joinPages = <List<Object?>>[];
        for (var offset = 0; offset < ids.length; offset += 2) {
          joinPages.add(await selectJoined(limit: 2, offset: offset));
        }
        expect(joinPages.expand((p) => p).toList(), equals(ids));

        // The ordering must survive the eager entity resolution, which
        // re-reads the referenced entities after the select:
        var eager = await selectJoined(
          limit: 3,
          offset: 1,
          resolutionRules: EntityResolutionRules(allEager: true),
        );
        expect(eager, equals(ids.skip(1).take(3).toList()));

        // Stability: the whole point of `offset` implying `orderByID` is that
        // the same page is the same rows every time.
        for (var i = 0; i < 3; ++i) {
          expect(
            await selectJoined(limit: 2, offset: 2),
            equals(ids.skip(2).take(2).toList()),
            reason: 'Unstable page on repetition #$i',
          );
        }

        // A query matching nothing stays empty under every option:
        Future<List<Object?>> selectNone({int? offset, int? limit}) async {
          var sel = await campaignRepo.selectByQuery(
            ' name == ? ',
            parameters: ['JOIN-NO-SUCH-CAMPAIGN'],
            limit: limit,
            offset: offset,
          );
          return sel.map((e) => e.id).toList();
        }

        expect(await selectNone(), isEmpty);
        expect(await selectNone(offset: 0), isEmpty);
        expect(await selectNone(offset: 5, limit: 2), isEmpty);
      });

      test('EntityPagination: lazy paged access', () async {
        final campaignRepo = entityRepositoryProvider.campaignAPIRepository;

        var ids = <int>[];
        for (var i = 1; i <= 7; ++i) {
          var id = await campaignRepo.store(Campaign('PAGINATION-0$i'));
          ids.add(id as int);
        }
        expect(ids, orderedEquals([...ids]..sort()));

        var p = campaignRepo.paginateByQuery(
          ' id >= ? ',
          parameters: [ids.first],
          limit: 3,
        );

        // Nothing is fetched until asked:
        expect(p.loadedPages, isEmpty);
        expect(p.totalLength, isNull);
        expect(p[0], isNull);

        // Page 1:
        var page1 = await p.loadNextPage();
        expect(page1!.map((e) => e.id).toList(), equals(ids.take(3).toList()));
        expect(p[0]?.id, equals(ids[0]));
        expect(p[2]?.id, equals(ids[2]));
        expect(p.maxLoadedIndex, equals(2));
        expect(p.maxKnownPage, equals(1));
        expect(
          p.isFinalPageResolved,
          isFalse,
          reason: 'A full page does not resolve the end',
        );
        expect(p.totalLength, isNull);

        // Jump to index 6 (page 3), leaving page 2 as a gap:
        expect((await p.getAt(6))?.id, equals(ids[6]));
        expect(p.loadedPages, equals([1, 3]));
        expect(p[3], isNull, reason: 'Page 2 was never loaded');
        expect(p.isIndexLoaded(3), isFalse);
        expect(p.loadedEntitiesLength, equals(4));
        expect(p.maxLoadedIndex, equals(6));

        // Page 3 holds 1 of 3 entries -> it is the final page:
        expect(p.isFinalPageResolved, isTrue);
        expect(p.finalPage, equals(3));
        expect(p.totalLength, equals(7));
        expect(p.isIndexKnownOutOfRange(7), isTrue);
        expect(await p.getAt(7), isNull);

        // `loadAll` fills the gap left by the jump:
        expect(await p.loadAll(), equals(7));
        expect(p.loadedPages, equals([1, 2, 3]));
        expect(p.loadedEntities.map((e) => e.id).toList(), equals(ids));

        // `getRange` across the whole set:
        var range = await p.getRange(2, 5);
        expect(range.map((e) => e.id).toList(), equals(ids.sublist(2, 5)));

        // Descending pagination:
        var desc = campaignRepo.paginateByQuery(
          ' id >= ? ',
          parameters: [ids.first],
          limit: 3,
          orderDirection: OrderDirection.descending,
        );
        expect(await desc.loadAll(), equals(7));
        expect(
          desc.loadedEntities.map((e) => e.id).toList(),
          equals(ids.reversed.toList()),
        );

        // Streaming walks every entry, in order:
        var streamed = await campaignRepo
            .paginateByQuery(' id >= ? ', parameters: [ids.first], limit: 2)
            .stream()
            .toList();
        expect(streamed.map((e) => e.id).toList(), equals(ids));

        // A query matching nothing resolves as empty:
        var none = campaignRepo.paginateByQuery(
          ' name == ? ',
          parameters: ['PAGINATION-NO-SUCH-CAMPAIGN'],
          limit: 3,
        );
        expect(await none.loadAll(), equals(0));
        expect(none.isKnownEmpty, isTrue);
        expect(none.finalPage, equals(1));
        expect(none[0], isNull);
      });

      test('Pagination [objectAdapter]: orderByID / offset / limit', () async {
        final photoRepo = entityRepositoryProvider2.photoAPIRepository;

        // `Photo` has a `String` ID, so this also covers the non-numeric
        // branch of `compareEntityIDs`. Deliberately stored out of order:
        var ids = ['PG-01', 'PG-02', 'PG-03', 'PG-04', 'PG-05'];
        for (var id in [ids[2], ids[0], ids[4], ids[1], ids[3]]) {
          var photo = Photo.fromData(base64.decode(png1PixelBase64), id: id);
          expect(await photoRepo.store(photo), equals(id));
        }

        Future<List<String>> selectAllIDs({
          int? limit,
          int? offset,
          bool? orderByID,
          OrderDirection? orderDirection,
        }) async {
          var sel = await photoRepo.selectAll(
            limit: limit,
            offset: offset,
            orderByID: orderByID,
            orderDirection: orderDirection,
          );
          // The `setUpAll` of this group stores an extra photo (with a sha256
          // ID), so only the ones created here are asserted:
          return sel.map((e) => e.id).where(ids.contains).toList();
        }

        expect(await selectAllIDs(orderByID: true), equals(ids));

        expect(
          await selectAllIDs(
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ),
          equals(ids.reversed.toList()),
        );

        // REGRESSION: `limit` was previously accepted and silently ignored by
        // the object adapters, so this returned every photo.
        var limited = await photoRepo.selectAll(limit: 2, orderByID: true);
        expect(limited.length, equals(2));

        // `offset` implies the ordering:
        expect(
          await selectAllIDs(offset: 1, limit: 2),
          equals(ids.skip(1).take(2).toList()),
        );

        // `selectByIDs` -> `ConditionIdIN`, which is one of the
        // `DBEntityRepository.select` fast paths that used to drop `limit`:
        var byIDs = await photoRepo.entityRepository.select(
          ConditionIdIN(ids),
          offset: 1,
          limit: 2,
        );
        expect(byIDs.map((e) => e.id).toList(), equals(ids.skip(1).take(2)));

        // A single-row select: any positive offset skips the only row.
        expect(
          (await photoRepo.entityRepository.select(ConditionID(ids.first)))
              .map((e) => e.id),
          equals([ids.first]),
        );
        expect(
          await photoRepo.entityRepository.select(
            ConditionID(ids.first),
            offset: 1,
          ),
          isEmpty,
        );
      });

      test('RegExp conditions: =~ /.../ and !~ /.../', () async {
        final userInfoRepo = entityRepositoryProvider.userInfoAPIRepository;
        final addressRepo = entityRepositoryProvider.addressAPIRepository;
        final userRepo = entityRepositoryProvider.userAPIRepository;
        final roleRepo = entityRepositoryProvider.roleAPIRepository;

        var infos = {
          'multiLine': 'rx:alpha\nbeta',
          'upper': 'rx:ALPHA',
          'newLineEnd': 'rx:abc\n',
          'slash': 'rx:a/b',
          'percent': 'rx:100% (x)',
        };

        var idsByName = <String, Object>{};
        for (var e in infos.entries) {
          idsByName[e.key] = (await userInfoRepo.store(UserInfo(e.value)))!;
        }
        var namesByID = idsByName.map((k, v) => MapEntry(v, k));

        // The names of the `UserInfo` created here that match a [query]:
        Future<Set<String>> select(
          String query, {
          Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
        }) async {
          var sel = await userInfoRepo.selectByQuery(
            query,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
          );
          return sel.map((e) => namesByID[e.id]).nonNulls.toSet();
        }

        // Matches anywhere, case-sensitive:
        expect(await select('info =~ /^rx:alpha/'), equals({'multiLine'}));
        expect(await select('info =~ /alpha/'), equals({'multiLine'}));
        expect(await select('info =~ /ALPHA/'), equals({'upper'}));

        // `i`:
        expect(
          await select('info =~ /^RX:ALPHA/i'),
          equals({'multiLine', 'upper'}),
        );

        // `.` matches a line terminator:
        expect(await select('info =~ /alpha.beta/'), equals({'multiLine'}));

        // `^`/`$`: only the start/end of the whole value (not of a line):
        expect(await select('info =~ /^beta/'), isEmpty);
        expect(await select('info =~ /alpha\$/i'), equals({'upper'}));
        expect(await select('info =~ /beta\$/'), equals({'multiLine'}));
        // Not before a final line terminator (as ICU's `$`, in MySQL):
        expect(await select('info =~ /abc\$/'), isEmpty);
        expect(await select('info =~ /abc\\n\$/'), equals({'newLineEnd'}));
        // A `$` in a class is a literal:
        expect(await select('info =~ /[\$]/'), isEmpty);

        // An escaped `/`, and characters special in SQL (`%`, `(`):
        expect(await select(r'info =~ /a\/b$/'), equals({'slash'}));
        expect(await select(r'info =~ /100% \(x\)$/'), equals({'percent'}));
        expect(await select(r"info =~ /'/"), isEmpty);

        // Word boundaries (`\y` in PostgreSQL), and an identity escape:
        expect(await select(r'info =~ /\bbeta\b/'), equals({'multiLine'}));
        expect(
          await select(r'info =~ /\balpha\b/i'),
          equals({'multiLine', 'upper'}),
        );
        expect(await select(r'info =~ /\Blpha/'), equals({'multiLine'}));
        expect(await select(r'info =~ /100\% \(x\)$/'), equals({'percent'}));

        // `!~`:
        expect(
          await select('info !~ /^rx:alpha/i'),
          equals({'newLineEnd', 'slash', 'percent'}),
        );

        // In groups:
        expect(
          await select(r'info =~ /^rx:a\// || info == "rx:ALPHA"'),
          equals({'slash', 'upper'}),
        );
        expect(
          await select(r'info =~ /^rx:a/ && info !~ /\n/'),
          equals({'slash'}),
        );

        // Parameters (a `String` or a `RegExp`):
        expect(
          await select(
            'info =~ /?:p/',
            namedParameters: {'p': RegExp(r'^rx:alpha', caseSensitive: false)},
          ),
          equals({'multiLine', 'upper'}),
        );
        expect(
          await select('info =~ /?:p/i', parameters: {'p': '^rx:alpha\$'}),
          equals({'upper'}),
        );
        expect(
          await select('info !~ /?/', positionalParameters: [r'^rx:a']),
          equals({'upper', 'percent'}),
        );
        expect(
          await select('info =~ /?#0/', parameters: [r'^rx:a/']),
          equals({'slash'}),
        );

        // `selectFirstByQuery` passes the `positionalParameters`:
        var first = await userInfoRepo.selectFirstByQuery(
          'info =~ /?/',
          positionalParameters: [r'^rx:100%'],
        );
        expect(first?.id, equals(idsByName['percent']));

        // A `RegExp` as an `IN` value: not compared as text.
        expect(
          () async =>
              await select('info =~ ?', positionalParameters: [RegExp('x')]),
          throwsA(isA<ArgumentError>()),
        );

        // A non-text column (cast to text):
        var a1 = Address('RX', 'Rx City', 'Rx Street', 901);
        var a2 = Address('RX', 'rx town', 'Rx Street', 1901);
        var addressIDs = [
          (await addressRepo.store(a1))!,
          (await addressRepo.store(a2))!,
        ];

        Future<List<Object?>> selectAddresses(String query) async =>
            (await addressRepo.selectByQuery(query))
                .map((e) => e.id)
                .where(addressIDs.contains)
                .toList();

        expect(
          await selectAddresses(r'number =~ /^90\d$/'),
          equals([addressIDs[0]]),
        );
        expect(
          await selectAddresses('number =~ /01\$/'),
          unorderedEquals(addressIDs),
        );
        expect(
          await selectAddresses('number !~ /^9/'),
          equals([addressIDs[1]]),
        );

        // REGRESSION: 2 positional parameters of the same field shared one
        // placeholder (the 1st value): `number > 900 AND number < 900`.
        Future<List<Object?>> selectAddressesBy(
          String query,
          List parameters,
        ) async => (await addressRepo.selectByQuery(
          query,
          parameters: parameters,
        )).map((e) => e.id).where(addressIDs.contains).toList();

        expect(
          await selectAddressesBy('number > ? && number < ?', [900, 1000]),
          equals([addressIDs[0]]),
        );
        expect(
          await selectAddressesBy('number >= ? && number <= ?', [1901, 1901]),
          equals([addressIDs[1]]),
        );
        expect(
          await selectAddressesBy('number =~ ? && number !~ ?', [
            [901, 1901],
            [901],
          ]),
          equals([addressIDs[1]]),
        );

        // A related entity's field (a join), an enum, and a list
        // relationship:
        var u1 = User('rx1@$testDomain', 'p', a1, [
          Role(RoleType.admin),
        ], creationTime: DateTime.utc(2020));
        var u2 = User('rx2@$testDomain', 'p', a2, [
          Role(RoleType.guest),
          Role(RoleType.unknown),
        ], creationTime: DateTime.utc(2020));
        var userIDs = [
          (await userRepo.store(u1))!,
          (await userRepo.store(u2))!,
        ];

        Future<List<Object?>> selectUsers(String query) async =>
            (await userRepo.selectByQuery(query))
                .map((e) => e.id)
                .where(userIDs.contains)
                .toList();

        expect(
          await selectUsers('address.city =~ /^rx city\$/i'),
          equals([userIDs[0]]),
        );
        expect(
          await selectUsers('address.city !~ /City/'),
          equals([userIDs[1]]),
        );
        expect(await selectUsers('roles.type =~ /^gu/'), equals([userIDs[1]]));
        expect(
          await selectUsers('roles.type =~ /^(admin|unknown)\$/'),
          unorderedEquals(userIDs),
        );
        expect(
          // (Each user once, also with more than one matching role: see
          // 'Operators: the same results on every adapter'.)
          await selectUsers('roles.type !~ /^(admin|guest)\$/'),
          equals([userIDs[1]]),
        );
        expect(
          await selectUsers(
            'email =~ /^rx/ && (address.city =~ /town/ || email =~ /^RX1@/i)',
          ),
          unorderedEquals(userIDs),
        );
        expect(
          await selectUsers('email =~ /^rx/ && roles.type =~ /^adm/'),
          equals([userIDs[0]]),
        );

        // A regexp and another condition, of the same field, by position:
        Future<List<Object?>> selectUsersBy(String query, List params) async =>
            (await userRepo.selectByQuery(
              query,
              parameters: params,
            )).map((e) => e.id).where(userIDs.contains).toList();

        expect(
          await selectUsersBy('email =~ /?/ && email != ?', [
            '^rx',
            'rx1@$testDomain',
          ]),
          equals([userIDs[1]]),
        );
        expect(
          await selectUsersBy('email != ? && email =~ /?/i', [
            'rx2@$testDomain',
            '^RX',
          ]),
          equals([userIDs[0]]),
        );

        var roleIDs = [...u1.roles, ...u2.roles].map((r) => r.id).toList();
        expect(
          (await roleRepo.selectByQuery('type =~ /^(ADMIN|GUEST)\$/i'))
              .map((e) => e.id)
              .where(roleIDs.contains)
              .toList(),
          unorderedEquals([u1.roles[0].id, u2.roles[0].id]),
        );
      });

      test('Negation: !(...), and nulls of the negated operators', () async {
        final userRepo = entityRepositoryProvider.userAPIRepository;
        final storeRepo = entityRepositoryProvider.storeAPIRepository;

        var a1 = Address('NX', 'NX City', 'NX Street', 1);
        var a2 = Address('NX', 'NX Town', 'NX Street', 2);

        var u1 = User(
          'nx1@$testDomain',
          'p',
          a1,
          [Role(RoleType.admin)],
          level: 10,
          creationTime: DateTime.utc(2020),
        );
        var u2 = User('nx2@$testDomain', 'p', a2, [
          Role(RoleType.guest),
          Role(RoleType.unknown),
        ], creationTime: DateTime.utc(2020));
        var u3 = User(
          'nx3@$testDomain',
          'p',
          a1,
          [],
          level: 5,
          creationTime: DateTime.utc(2020),
        );

        var userIDs = <Object>[];
        for (var u in [u1, u2, u3]) {
          userIDs.add((await userRepo.store(u))!);
        }
        var userNames = {userIDs[0]: 'u1', userIDs[1]: 'u2', userIDs[2]: 'u3'};

        Future<Set<String>> users(String query, {Object? parameters}) async =>
            (await userRepo.selectByQuery(
              query,
              parameters: parameters,
            )).map((e) => userNames[e.id]).nonNulls.toSet();

        var s1 = Store('nx-a', 1, owner: u1);
        var s2 = Store('nx-b', null, owner: null);
        var s3 = Store('nx-c', 3, owner: u2);

        var storeIDs = <Object>[];
        for (var s in [s1, s2, s3]) {
          storeIDs.add((await storeRepo.store(s))!);
        }
        var storeNames = {
          storeIDs[0]: 's1',
          storeIDs[1]: 's2',
          storeIDs[2]: 's3',
        };

        Future<Set<String>> stores(String query, {Object? parameters}) async =>
            (await storeRepo.selectByQuery(
              query,
              parameters: parameters,
            )).map((e) => storeNames[e.id]).nonNulls.toSet();

        // A field of the main table (`NOT COALESCE(...)`), with `null`:
        expect(await stores('!(number == 1)'), equals({'s2', 's3'}));
        expect(await stores('!number == 1'), equals({'s2', 's3'}));
        expect(await stores('!(number > 1)'), equals({'s1', 's2'}));
        expect(await stores('!!(number == 1)'), equals({'s1'}));
        expect(await stores('!(number == 1 || number == 3)'), equals({'s2'}));
        expect(
          await stores(
            'name =~ /^nx-/ && !(number == ? || name == ?)',
            parameters: [3, 'nx-a'],
          ),
          equals({'s2'}),
        );

        // The negated operators also match a `null` field (since 1.32.0):
        expect(await stores('number != 1'), equals({'s2', 's3'}));
        expect(await stores('number !~ [1, 2]'), equals({'s2', 's3'}));
        expect(await stores(r'number !~ /^1$/'), equals({'s2', 's3'}));
        // A `null` in the list: as `IS NULL` (SQL `NOT IN (1, NULL)` matches
        // nothing):
        expect(await stores('number !~ [1, null]'), equals({'s3'}));
        expect(await stores('number =~ [1, null]'), equals({'s1', 's2'}));
        expect(
          await stores(
            'number !~ ?',
            parameters: [
              [3, null],
            ],
          ),
          equals({'s1'}),
        );
        // ... but not `!= null` (`IS NOT NULL`):
        expect(await stores('number != null'), equals({'s1', 's3'}));
        expect(await stores('!(number == null)'), equals({'s1', 's3'}));

        // An empty list is not a `null` (1.32.0 wrote it as `IS NULL`):
        // `=~ []` matches nothing, `!~ []` everything (also a `null`).
        var noNumbers = {'number': <int>[]};
        expect(await stores('number =~ ?', parameters: noNumbers), isEmpty);
        expect(
          await stores('number !~ ?', parameters: noNumbers),
          equals({'s1', 's2', 's3'}),
        );
        expect(
          await stores('!(number =~ ?)', parameters: noNumbers),
          equals({'s1', 's2', 's3'}),
        );
        expect(
          await stores('owner =~ ?', parameters: {'owner': <int>[]}),
          isEmpty,
        );
        // Through a relationship: a JOIN (an outer one when negated), and
        // `!( ... )`'s subquery; a missing owner is included when negated.
        var noEmails = {'email': <String>[]};
        expect(
          await stores('owner.email =~ ?:email', parameters: noEmails),
          isEmpty,
        );
        expect(
          await stores('owner.email !~ ?:email', parameters: noEmails),
          equals({'s1', 's2', 's3'}),
        );
        expect(
          await stores('!(owner.email =~ ?:email)', parameters: noEmails),
          equals({'s1', 's2', 's3'}),
        );
        // A to-many relationship:
        var noRoles = {'roles': <int>[]};
        expect(await users('roles =~ ?', parameters: noRoles), isEmpty);
        expect(
          await users('!(roles =~ ?)', parameters: noRoles),
          equals({'u1', 'u2', 'u3'}),
        );
        expect(
          await stores(
            'name == ? || number =~ ?',
            parameters: {'name': 'nx-b', 'number': <int>[]},
          ),
          equals({'s2'}),
        );
        // ... and a `null` parameter is `IS NULL`:
        expect(
          await stores('number =~ ?', parameters: {'number': null}),
          equals({'s2'}),
        );

        // A to-one relationship (a subquery): a missing owner is included.
        expect(
          await stores(r'!(owner.email =~ /^nx1@/)'),
          equals({'s2', 's3'}),
        );
        expect(
          await stores('owner.email != ?', parameters: ['nx1@$testDomain']),
          equals({'s2', 's3'}),
        );
        expect(
          await stores('name =~ /^nx-/ && !(owner.level == 10)'),
          equals({'s2', 's3'}),
        );

        // A to-many relationship: no matching related entity.
        // REGRESSION: in memory, `==` compared the whole list of a to-many
        // relationship with the value (nothing matched).
        expect(await users('roles.type == "admin"'), equals({'u1'}));
        expect(
          await users('roles.id == ?', parameters: [u1.roles.first.id]),
          equals({'u1'}),
        );

        // The negated operators compare each related row (as a SQL join),
        // also without any (a `NULL` row): "some role not admin".
        expect(await users('roles.type != "admin"'), equals({'u2', 'u3'}));
        expect(
          await users('roles.type !~ ["guest"] && email =~ /^nx/'),
          equals({'u1', 'u2', 'u3'}),
        );
        expect(
          await users(r'roles.type !~ /^(admin|guest)$/ && email =~ /^nx/'),
          equals({'u2', 'u3'}),
        );

        // `!(...)`: "no role admin".
        expect(await users('!(roles.type == "admin")'), equals({'u2', 'u3'}));
        expect(
          await users('!(roles.type =~ ["guest", "admin"])'),
          equals({'u3'}),
        );
        expect(
          await users('!(roles.type == "admin" || level == 5)'),
          equals({'u2'}),
        );
        expect(
          await users('email =~ /^nx/ && !(roles.type =~ /^gu/)'),
          equals({'u1', 'u3'}),
        );

        // Nulls (`level`), nested, and in groups:
        expect(await users('!(level == 10)'), equals({'u2', 'u3'}));
        expect(await users('level != 10'), equals({'u2', 'u3'}));
        expect(await users('!(level > 1)'), equals({'u2'}));
        expect(
          await users('!(level == 10) && !(roles.type == "guest")'),
          equals({'u3'}),
        );
        expect(
          await users('level == 10 || !(address.city =~ /city/i)'),
          equals({'u1', 'u2'}),
        );
        expect(
          await users('!(email =~ /^nx/ && !(level == 5))'),
          equals({'u3'}),
        );

        // Parameters, by position and by name:
        expect(
          await users('!(level == ?) && email =~ /?/', parameters: [10, '^nx']),
          equals({'u2', 'u3'}),
        );
        expect(
          await users(
            '!(roles.type == ?:t) && email =~ /?:e/',
            parameters: {'t': 'admin', 'e': '^nx'},
          ),
          equals({'u2', 'u3'}),
        );

        // The complement: `cond` and `!(cond)` split the rows.
        for (var cond in [
          'number == 1',
          'number > 1',
          'number != 3',
          r'owner.email =~ /^nx2@/',
          'owner.level == 10 || number == 3',
        ]) {
          var all = await stores('name =~ /^nx-/');
          var yes = await stores('name =~ /^nx-/ && ($cond)');
          var no = await stores('name =~ /^nx-/ && !($cond)');
          expect(yes.intersection(no), isEmpty, reason: cond);
          expect(yes.union(no), equals(all), reason: cond);
        }
        for (var cond in [
          'roles.type == "admin"',
          'roles.type =~ /^(guest|unknown)\$/',
          'level == 5 || roles.type == "guest"',
        ]) {
          var all = await users('email =~ /^nx/');
          var yes = await users('email =~ /^nx/ && ($cond)');
          var no = await users('email =~ /^nx/ && !($cond)');
          expect(yes.intersection(no), isEmpty, reason: cond);
          expect(yes.union(no), equals(all), reason: cond);
        }

        // A `DELETE` with a subquery of its own table (MySQL: a derived
        // table):
        var d1 = Store('nxd-1', 1);
        var d2 = Store('nxd-2', 2, owner: u1);
        var d1ID = (await storeRepo.store(d1))!;
        var d2ID = (await storeRepo.store(d2))!;

        var deleted = await storeRepo.deleteByQuery(
          r'name =~ /^nxd-/ && !(owner.email =~ /^nx1@/)',
        );
        expect(deleted.map((e) => e.id), equals([d1ID]));
        expect(await storeRepo.selectByID(d1ID), isNull);
        expect((await storeRepo.selectByID(d2ID))?.id, equals(d2ID));
      });

      test('Operators: the same results on every adapter', () async {
        final userRepo = entityRepositoryProvider.userAPIRepository;
        final storeRepo = entityRepositoryProvider.storeAPIRepository;

        // Users: `level` (a nullable int), `creationTime` (a date),
        // `address.city`, and `roles` (a to-many relationship, `uC` without
        // any; an enum, a bool and a nullable decimal).
        var alpha = Address('OX', 'OX Alpha', 'OX Street', 1);
        var beta = Address('OX', 'OX Beta', 'OX Street', 2);

        var uA = User(
          'ox-a@$testDomain',
          'p',
          alpha,
          [Role(RoleType.admin, value: Decimal.parse('1.5'))],
          level: 10,
          creationTime: DateTime.utc(2020),
        );
        var uB = User('ox-b@$testDomain', 'p', beta, [
          Role(RoleType.guest, enabled: false),
          Role(RoleType.unknown, value: Decimal.parse('3')),
        ], creationTime: DateTime.utc(2021));
        var uC = User(
          'ox-c@$testDomain',
          'p',
          alpha,
          [],
          level: 5,
          creationTime: DateTime.utc(2022),
        );

        var userNames = <Object, String>{};
        for (var (u, n) in [(uA, 'a'), (uB, 'b'), (uC, 'c')]) {
          userNames[(await userRepo.store(u))!] = n;
        }
        var allUsers = userNames.values.toSet();
        var (ea, eb, ec) = (uA.email, uB.email, uC.email);

        // Stores: `name` (text), `number` (a nullable int) and `owner` (a
        // nullable to-one relationship, with `owner.address.city` 2 levels
        // away).
        var stores = [
          (Store('ox-apple', 1, owner: uA), 's1'),
          (Store('ox-banana', null), 's2'),
          (Store('ox-cherry', 3, owner: uB), 's3'),
          (Store('OX-Date', 30, owner: uC), 's4'),
          (Store('ox-elder', 1, owner: uB), 's5'),
        ];
        var storeNames = <Object, String>{};
        for (var (s, n) in stores) {
          storeNames[(await storeRepo.store(s))!] = n;
        }
        var allStores = storeNames.values.toSet();

        // The names of the selected entities, sorted: a list, not a set, so
        // an entity selected more than once (a to-many relationship's join)
        // is a failure too.
        Future<List<String>> selectStores(
          String query,
          Object? parameters,
        ) async => (await storeRepo.selectByQuery(
          query,
          parameters: parameters,
        )).map((e) => storeNames[e.id]).nonNulls.toList()..sort();

        Future<List<String>> selectUsers(
          String query,
          Object? parameters,
        ) async => (await userRepo.selectByQuery(
          query,
          parameters: parameters,
        )).map((e) => userNames[e.id]).nonNulls.toList()..sort();

        var failures = <String>[];

        Future<void> check(
          Future<List<String>> Function(String, Object?) select,
          Set<String> all,
          String query,
          Object? parameters,
          Set<String> expected,
        ) async {
          var p = parameters == null ? '' : '  $parameters';
          // The condition, and `!(...)` its complement:
          for (var (q, exp) in [
            (query, expected),
            ('!($query)', all.difference(expected)),
          ]) {
            var expList = exp.toList()..sort();
            try {
              var got = await select(q, parameters);
              if (got.join(',') != expList.join(',')) {
                failures.add('`$q`$p: [${got.join(',')}], expected [$expList]');
              }
            } catch (e) {
              failures.add('`$q`$p: ERROR $e');
            }
          }
        }

        // `x == null` and `x != null` split the entities (none in both, none
        // in neither), as `cond` and `!(cond)`.
        Future<void> nullSplit(
          Future<List<String>> Function(String, Object?) select,
          Set<String> all,
          String key,
          Set<String> isNull,
        ) async {
          await check(select, all, '$key == null', null, isNull);
          await check(
            select,
            all,
            '$key != null',
            null,
            all.difference(isNull),
          );
          await check(select, all, '$key == ?', [null], isNull);
          await check(select, all, '$key =~ [null]', null, isNull);
          await check(
            select,
            all,
            '$key !~ [null]',
            null,
            all.difference(isNull),
          );
        }

        Future<void> s(String q, Set<String> exp, [Object? params]) =>
            check(selectStores, allStores, q, params, exp);

        Future<void> u(String q, Set<String> exp, [Object? params]) =>
            check(selectUsers, allUsers, q, params, exp);

        // A text field, never `null`:
        await s('name == "ox-apple"', {'s1'});
        await s('name != "ox-apple"', {'s2', 's3', 's4', 's5'});
        await s('name =~ ["ox-apple", "ox-cherry"]', {'s1', 's3'});
        await s('name !~ ["ox-apple", "ox-cherry"]', {'s2', 's4', 's5'});
        await s('name =~ /^ox-[ab]/', {'s1', 's2'});
        await s('name !~ /^ox-[ab]/', {'s3', 's4', 's5'});
        await s('name =~ /^ox-d/', {});
        await s('name =~ /^ox-d/i', {'s4'});
        await s('name !~ /^ox-d/i', {'s1', 's2', 's3', 's5'});
        await s('name =~ /e/', {'s1', 's3', 's4', 's5'});
        await s('name == null', {});
        await s('name != null', allStores);
        await s('name =~ null', {});
        await s('name !~ null', allStores);
        await s('name =~ []', {});
        await s('name !~ []', allStores);
        await s('name == ?', {'s3'}, ['ox-cherry']);
        await s('name != ?:n', {'s1', 's2', 's4', 's5'}, {'n': 'ox-cherry'});
        await s(
          'name =~ ?',
          {'s2', 's4'},
          [
            ['ox-banana', 'OX-Date'],
          ],
        );
        await s(
          'name !~ ?',
          {'s1', 's3', 's5'},
          [
            ['ox-banana', 'OX-Date'],
          ],
        );
        await s(
          'name =~ ?:n',
          {'s2', 's4'},
          {
            'n': ['ox-banana', 'OX-Date'],
          },
        );
        await s(
          'name !~ ?:n',
          {'s1', 's3', 's5'},
          {
            'n': ['ox-banana', 'OX-Date'],
          },
        );
        await s('name =~ ?', {}, [<String>[]]);
        await s('name !~ ?:n', allStores, {'n': <String>[]});
        await s('name =~ ?', {}, [null]);
        await s('name !~ ?', allStores, [null]);
        await s('name =~ /?/', {'s3'}, ['^ox-c']);
        await s('name !~ /?:r/i', {'s4', 's5'}, {'r': '^ox-[a-c]'});

        // A nullable number (`s2` is `null`):
        await s('number == 1', {'s1', 's5'});
        await s('number != 1', {'s2', 's3', 's4'});
        await s('number == null', {'s2'});
        await s('number != null', {'s1', 's3', 's4', 's5'});
        await s('number =~ [1, 3]', {'s1', 's3', 's5'});
        await s('number !~ [1, 3]', {'s2', 's4'});
        await s('number =~ null', {'s2'});
        await s('number !~ null', {'s1', 's3', 's4', 's5'});
        await s('number =~ [null]', {'s2'});
        await s('number !~ [null]', {'s1', 's3', 's4', 's5'});
        await s('number =~ [3, null]', {'s2', 's3'});
        await s('number !~ [3, null]', {'s1', 's4', 's5'});
        await s('number =~ []', {});
        await s('number !~ []', allStores);
        await s('number =~ /^3/', {'s3', 's4'});
        await s('number !~ /^3/', {'s1', 's2', 's5'});
        await s(r'number =~ /0$/', {'s4'});
        await s('number > 1', {'s3', 's4'});
        await s('number >= 3', {'s3', 's4'});
        await s('number < 3', {'s1', 's5'});
        await s('number <= 1', {'s1', 's5'});
        await s('number == ?', {'s3'}, [3]);
        await s('number != ?:n', {'s1', 's2', 's4', 's5'}, {'n': 3});
        await s('number == ?', {'s2'}, [null]);
        await s('number != ?', {'s1', 's3', 's4', 's5'}, [null]);
        await s(
          'number =~ ?',
          {'s1', 's4', 's5'},
          [
            [1, 30],
          ],
        );
        await s(
          'number !~ ?:n',
          {'s2', 's3'},
          {
            'n': [1, 30],
          },
        );
        await s('number =~ ?', {'s2'}, [null]);
        await s('number !~ ?', {'s1', 's3', 's4', 's5'}, [null]);
        await s(
          'number =~ ?',
          {'s2', 's3'},
          [
            [3, null],
          ],
        );
        await s(
          'number !~ ?',
          {'s1', 's4', 's5'},
          [
            [3, null],
          ],
        );
        await s('number =~ ?:n', {}, {'n': <int>[]});
        await s('number !~ ?', allStores, [<int>[]]);
        await s('number =~ /?/', {'s1', 's5'}, [r'^1$']);
        await s('number !~ /?:r/', {'s2', 's3', 's4'}, {'r': r'^1$'});
        await s('number > ? && number < ?', {'s3'}, [1, 30]);

        // A to-one relationship, by its ID (`s2` has no owner):
        var (ia, ib, ic) = (uA.id, uB.id, uC.id);
        await s('owner == ?', {'s1'}, [ia]);
        await s('owner != ?', {'s2', 's3', 's4', 's5'}, [ia]);
        await s('owner == null', {'s2'});
        await s('owner != null', {'s1', 's3', 's4', 's5'});
        // A relationship's `=~`/`!~` is with a set of IDs, never `null`:
        // `null` is an empty set (see 'Relationship operators').
        await s('owner =~ null', {});
        await s('owner !~ null', allStores);
        await s(
          'owner =~ ?',
          {'s1', 's4'},
          [
            [ia, ic],
          ],
        );
        await s(
          'owner !~ ?:o',
          {'s2', 's3', 's5'},
          {
            'o': [ia, ic],
          },
        );
        await s('owner =~ ?', {}, [<int>[]]);
        await s('owner !~ ?:o', allStores, {'o': <int>[]});

        // A field of a to-one relationship (a join):
        await s('owner.email == ?', {'s1'}, [ea]);
        await s('owner.email != ?', {'s2', 's3', 's4', 's5'}, [ea]);
        await s(
          'owner.email =~ ?',
          {'s1', 's4'},
          [
            [ea, ec],
          ],
        );
        await s(
          'owner.email !~ ?:e',
          {'s2', 's3', 's5'},
          {
            'e': [ea, ec],
          },
        );
        await s('owner.email =~ /^ox-[ab]@/', {'s1', 's3', 's5'});
        await s('owner.email !~ /^ox-[ab]@/', {'s2', 's4'});
        await s('owner.email =~ /^OX-C@/i', {'s4'});
        await s('owner.email =~ /?:r/', {'s3', 's5'}, {'r': '^ox-b@'});
        await s('owner.email =~ ?', {}, [<String>[]]);
        await s('owner.email !~ ?', allStores, [<String>[]]);
        await s('owner.email !~ ?:e', {'s2', 's3', 's4', 's5'}, {'e': ea});
        await s('owner.email =~ ?', {'s1'}, [ea]);
        // A missing owner (`s2`) is a `null` field: `== null` matches it (as
        // `!=` does):
        await nullSplit(selectStores, allStores, 'owner.email', {'s2'});
        await s('owner.email =~ null', {'s2'});
        await s(
          'owner.email =~ ?',
          {'s1', 's2'},
          [
            [ea, null],
          ],
        );

        // A nullable field of a to-one relationship (`uB` has no level, `s2`
        // no owner):
        await s('owner.level == 10', {'s1'});
        await s('owner.level != 10', {'s2', 's3', 's4', 's5'});
        await s('owner.level =~ [5, 10]', {'s1', 's4'});
        await s('owner.level !~ [10]', {'s2', 's3', 's4', 's5'});
        await s('owner.level > 1', {'s1', 's4'});
        await s('owner.level < 10', {'s4'});
        await s('owner.level =~ ?', {}, [<int>[]]);
        await s('owner.level !~ ?', allStores, [<int>[]]);
        await s('owner.level =~ /^1/', {'s1'});
        await s('owner.level !~ /^1/', {'s2', 's3', 's4', 's5'});
        await s(r'owner.level =~ /?:r/', {'s4'}, {'r': r'^5$'});
        await nullSplit(selectStores, allStores, 'owner.level', {
          's2',
          's3',
          's5',
        });
        await s('owner.level =~ null', {'s2', 's3', 's5'});
        await s('owner.level =~ [5, null]', {'s2', 's3', 's4', 's5'});
        await s('owner.level !~ [5, null]', {'s1'});
        await s('owner.level == ?:l', {'s2', 's3', 's5'}, {'l': null});
        await s('owner.level != ?:l', {'s1', 's4'}, {'l': null});

        // A field 2 relationships away (`owner.address.city`):
        await s('owner.address.city == "OX Alpha"', {'s1', 's4'});
        await s('owner.address.city != "OX Alpha"', {'s2', 's3', 's5'});
        await s('owner.address.city =~ /beta/i', {'s3', 's5'});
        await s('owner.address.city !~ /beta/i', {'s1', 's2', 's4'});
        await s(
          'owner.address.city =~ ?:c',
          {'s3', 's5'},
          {
            'c': ['OX Beta'],
          },
        );
        await s(
          'owner.address.city !~ ?:c',
          {'s1', 's2', 's4'},
          {
            'c': ['OX Beta'],
          },
        );
        await s('owner.address.city =~ ?', {}, [<String>[]]);
        await s('owner.address.city !~ ?', allStores, [<String>[]]);
        await s('owner.address.state == "OX"', {'s1', 's3', 's4', 's5'});
        await s(
          'owner.address.city !~ /?:r/i',
          {'s2', 's3', 's5'},
          {'r': 'alpha'},
        );
        await s('owner.address.city =~ /?/', {'s3', 's5'}, ['Beta\$']);
        await nullSplit(selectStores, allStores, 'owner.address.city', {'s2'});
        await s('owner.address.city =~ null', {'s2'});

        // A to-many relationship through a to-one one (`owner.roles`): `s2`
        // has no owner, `s4`'s owner (`uC`) no roles.
        await s('owner.roles.type == "guest"', {'s3', 's5'});
        await s('owner.roles.type == "admin"', {'s1'});
        await s('owner.roles.type != "admin"', {'s2', 's3', 's4', 's5'});
        await s('owner.roles.type =~ ["admin", "unknown"]', {'s1', 's3', 's5'});
        await s('owner.roles.type =~ /^gu/', {'s3', 's5'});
        await s('owner.roles.type !~ /^(admin|guest)\$/', {
          's2',
          's3',
          's4',
          's5',
        });
        await s('owner.roles.enabled == false', {'s3', 's5'});
        await nullSplit(selectStores, allStores, 'owner.roles.type', {
          's2',
          's4',
        });
        await s('owner.roles.type =~ ?:t', {}, {'t': <String>[]});
        await s('owner.roles.type !~ ?:t', allStores, {'t': <String>[]});

        // Each entity's own `null`s:
        await nullSplit(selectStores, allStores, 'name', {});
        await nullSplit(selectStores, allStores, 'number', {'s2'});
        // (Not `owner`: a relationship's `=~ [null]` is an empty set of IDs,
        // see above.)

        // A single value (not a list) with `=~`/`!~`:
        await s('name =~ "ox-apple"', {'s1'});
        await s('name =~ ?', {'s1'}, ['ox-apple']);
        await s('name !~ ?:n', {'s2', 's3', 's4', 's5'}, {'n': 'ox-apple'});
        await s('number =~ 3', {'s3'});
        await s('number =~ ?', {'s3'}, [3]);
        await s('number !~ 3', {'s1', 's2', 's4', 's5'});

        // `!`, and groups:
        await s('!name == "ox-apple"', {'s2', 's3', 's4', 's5'});
        await s('!!(number == 1)', {'s1', 's5'});
        await s('!(number == 1 || owner.level == 5)', {'s2', 's3'});
        await s('!(number =~ [1, 3] && owner.email =~ /^ox-b@/)', {
          's1',
          's2',
          's4',
        });
        await s('number == 1 && !(owner.email =~ /^ox-a@/)', {'s5'});
        await s('number == null || owner.level == null', {'s2', 's3', 's5'});
        await s('(number == 1 || number == 3) && owner.level != 10', {
          's3',
          's5',
        });
        await s(
          '!(owner =~ ?)',
          {'s1', 's2', 's4'},
          [
            [ib],
          ],
        );
        await s(
          // (`OX-Date` doesn't match the case-sensitive `^ox-`.)
          'name =~ /?/ && !(number =~ ?)',
          {'s1', 's2', 's5'},
          [
            '^ox-',
            [3],
          ],
        );
        await s(
          'name =~ /?:r/i && number !~ ?:n',
          {'s2', 's3', 's4'},
          {
            'r': '^ox-',
            'n': [1],
          },
        );

        // The users: a to-many relationship (`roles`), compared row by row
        // (as a SQL outer join): `==`/`=~` are "some role is", `!=`/`!~`
        // "some role is not", and `!(...)` "no role is". A user without any
        // (`uC`) is one row of `null`s: `roles.type == null` and
        // `roles.type != "admin"` match it, `roles.type != null` doesn't.
        // Each user is selected once (not once per matching role).
        await u('roles.type == "admin"', {'a'});
        await u('roles.type != "admin"', {'b', 'c'});
        await u('roles.type =~ ["guest", "unknown"]', {'b'});
        await u('roles.type !~ ["guest"]', {'a', 'b', 'c'});
        await u('roles.type =~ /^(adm|unk)/', {'a', 'b'});
        await u('roles.type !~ /^(adm|unk)/', {'b', 'c'});
        await u('roles.type =~ ?:t', {}, {'t': <String>[]});
        await u('roles.type !~ ?:t', allUsers, {'t': <String>[]});
        await u(
          'roles.type =~ ?',
          {'a', 'b'},
          [
            ['admin', 'guest'],
          ],
        );
        await u('roles.enabled == false', {'b'});
        await u('roles.enabled == true', {'a', 'b'});
        await u('!(roles.type =~ ["admin", "guest"])', {'c'});
        await u(
          'roles =~ ?',
          {'a'},
          [
            [uA.roles.first.id],
          ],
        );
        await u('roles =~ ?', {}, [<int>[]]);
        await u(
          '!(roles =~ ?)',
          {'a', 'c'},
          [
            [uB.roles.first.id],
          ],
        );
        await nullSplit(selectUsers, allUsers, 'roles.type', {'c'});
        await u('roles.type =~ null', {'c'});
        await u('roles.type =~ ["admin", null]', {'a', 'c'});
        await u('roles.type !~ ["admin", null]', {'b'});
        await u(
          'roles.type !~ ?:t',
          {'b', 'c'},
          {
            't': ['admin'],
          },
        );
        await u('roles.type =~ /?:r/', {'a'}, {'r': '^adm'});
        await u('roles.type !~ /?:r/i', {'b', 'c'}, {'r': '^ADM'});
        // An enum parameter:
        await u('roles.type == ?', {'a'}, [RoleType.admin]);
        await u(
          'roles.type =~ ?',
          {'a', 'b'},
          [
            [RoleType.admin, RoleType.guest],
          ],
        );
        await u('roles.type != ?:t', {'b', 'c'}, {'t': RoleType.admin});
        // A bool:
        await u('roles.enabled =~ [false]', {'b'});
        await u('roles.enabled != true', {'b', 'c'});
        await nullSplit(selectUsers, allUsers, 'roles.enabled', {'c'});
        // A nullable decimal (`uB`'s guest and `uC` are `null`):
        await u('roles.value == 1.5', {'a'});
        await u('roles.value > 1', {'a', 'b'});
        await u('roles.value >= 3', {'b'});
        await u('roles.value < 2', {'a'});
        await u('roles.value != 3', {'a', 'b', 'c'});
        await u('roles.value =~ [1.5, 3]', {'a', 'b'});
        // (Not split by `null`: `uB` has a role with and one without.)
        await u('roles.value == null', {'b', 'c'});
        await u('roles.value != null', {'a', 'b'});
        await u('roles.value =~ [null]', {'b', 'c'});
        await u('roles.value =~ [3, null]', {'b', 'c'});
        await u('roles.value !~ [3, null]', {'a'});
        await u('roles.value == ?', {'b'}, [Decimal.parse('3')]);

        // A decimal as a `String`:
        await u('roles.value == "1.5"', {'a'});
        await u('roles.value =~ ["1.5", "3"]', {'a', 'b'});
        await u('roles.value == ?', {'b'}, ['3']);
        // A list parameter with `==`, through a to-many relationship (`uC`
        // without roles) and of a field:
        await u(
          'roles.type == ?',
          {'c'},
          [
            [null],
          ],
        );
        await u(
          'roles.type == ?',
          {'b'},
          [
            ['guest'],
          ],
        );
        await s(
          'number == ?',
          {'s2'},
          [
            [null],
          ],
        );
        await s(
          'number == ?',
          {'s3'},
          [
            [3],
          ],
        );

        // A date:
        await u('creationTime == ?', {'b'}, [DateTime.utc(2021)]);
        await u('creationTime != ?', {'a', 'c'}, [DateTime.utc(2021)]);
        await u('creationTime > ?', {'b', 'c'}, [DateTime.utc(2020)]);
        await u('creationTime <= ?:t', {'a', 'b'}, {'t': DateTime.utc(2021)});
        await u(
          'creationTime =~ ?',
          {'a', 'c'},
          [
            [DateTime.utc(2020), DateTime.utc(2022)],
          ],
        );

        // The user's own fields:
        await nullSplit(selectUsers, allUsers, 'level', {'b'});
        await u('level == null', {'b'});
        await u('level =~ null', {'b'});
        await u('level !~ null', {'a', 'c'});
        await u('level !~ [10]', {'b', 'c'});
        await u('level =~ [5, null]', {'b', 'c'});
        await u('address.city =~ /alpha/i', {'a', 'c'});
        await u(
          'address.city !~ ?',
          {'a', 'c'},
          [
            ['OX Beta'],
          ],
        );
        await u(
          'email =~ ?:e',
          {'a', 'b'},
          {
            'e': [ea, eb],
          },
        );
        await u('email !~ /^ox-a@/', {'b', 'c'});
        await u('email =~ /^ox-/ && roles.type =~ /^gu/', {'b'});
        await u('level == 10 || !(roles.type == "admin")', {'a', 'b', 'c'});
        await u('level == 5 || roles.type == "guest"', {'b', 'c'});

        // Counted once each, as selected (a to-many relationship's join):
        for (var (q, n) in [
          ('roles.type != "admin"', 2),
          ('roles.type =~ ["guest", "unknown"]', 1),
          ('roles.enabled == true', 2),
        ]) {
          var count = await userRepo.countByQuery('email =~ /^ox-/ && ($q)');
          if (count != n) failures.add('count `$q`: $count, expected $n');
        }

        // Paginated once each (a to-many relationship's join):
        for (var (limit, offset, exp) in [
          (1, null, ['b']),
          (2, null, ['b', 'c']),
          (1, 1, ['c']),
        ]) {
          var page = await userRepo.selectByQuery(
            'email =~ /^ox-/ && roles.type != "admin"',
            limit: limit,
            offset: offset,
            orderByID: true,
          );
          var names = page.map((e) => userNames[e.id]).toList();
          if (names.join(',') != exp.join(',')) {
            failures.add('limit $limit offset $offset: $names, expected $exp');
          }
        }

        // A `DELETE` through a to-one (a `JOIN`) and a to-many relationship:
        var d1 = Store('oxd-1', 1, owner: uA);
        var d2 = Store('oxd-2', 2, owner: uB);
        var d3 = Store('oxd-3', 3);
        var dIDs = [
          for (var d in [d1, d2, d3]) (await storeRepo.store(d))!,
        ];
        for (var (q, params, exp) in [
          ('name =~ /^oxd-/ && owner.email == ?', [eb], [dIDs[1]]),
          ('name =~ /^oxd-/ && owner.roles.type == "admin"', null, [dIDs[0]]),
          ('name =~ /^oxd-/ && owner.level == null', null, [dIDs[2]]),
        ]) {
          try {
            var deleted = await storeRepo.deleteByQuery(q, parameters: params);
            var ids = deleted.map((e) => e.id).toList();
            if (ids.join(',') != exp.join(',')) {
              failures.add('delete `$q`: $ids, expected $exp');
            }
          } catch (e) {
            failures.add('delete `$q`: ERROR $e');
          }
        }
        var left = await storeRepo.selectByQuery('name =~ /^oxd-/');
        if (left.isNotEmpty) {
          failures.add('delete: left ${left.map((e) => e.name).toList()}');
        }

        // A `DELETE` through a to-many relationship, of a table without
        // to-one references (`address.stores`):
        final addressRepo = entityRepositoryProvider.addressAPIRepository;
        var ax1 = Address(
          'PX',
          'PX City',
          'PX Street',
          1,
          stores: [Store('px-1', 1)],
        );
        var ax2 = Address(
          'PX',
          'PX City',
          'PX Street',
          2,
          stores: [Store('px-2', 2), Store('px-3', 3)],
        );
        var ax1ID = (await addressRepo.store(ax1))!;
        var ax2ID = (await addressRepo.store(ax2))!;
        try {
          var deleted = await addressRepo.deleteByQuery(
            'state == "PX" && stores.name == ?',
            parameters: ['px-3'],
          );
          var ids = deleted.map((e) => e.id).toList();
          if (ids.join(',') != '$ax2ID') {
            failures.add('delete address: $ids, expected [$ax2ID]');
          }
        } catch (e) {
          failures.add('delete address: ERROR $e');
        }
        if ((await addressRepo.selectByID(ax1ID))?.id != ax1ID) {
          failures.add('delete address: $ax1ID was deleted');
        }

        expect(failures, isEmpty, reason: failures.join('\n'));
      });

      test('Relationship operators: by ID, on every adapter', () async {
        final userRepo = entityRepositoryProvider.userAPIRepository;
        final storeRepo = entityRepositoryProvider.storeAPIRepository;
        final addressRepo = entityRepositoryProvider.addressAPIRepository;

        var failures = <String>[];

        // The expected results come from a model: each entity's set of
        // related IDs. A relationship is compared by its related IDs, and
        // never has a `null` ID:
        // - `=~ S`: any related ID in `S` (without `null`s: `[]`, `null`,
        //   `[null]` are an empty set, which matches none).
        // - `!~ S`: an empty `S` matches all; otherwise without related
        //   entities, or any related ID not in `S` (as a SQL join of its
        //   rows).
        // - `== null` / `== []`: without related entities; `!=`: with some.
        // - `== v`: any related ID is `v`; `!= v`: without related
        //   entities, or any related ID isn't `v`.
        Future<void> relationship({
          required String field,
          required Map<String, Set<Object>> model,
          required Future<List<String>> Function(String q, Object? params)
          select,
          required Object id1,
          required Object id2,
          required List<Object> entityParams,
        }) async {
          var all = model.keys.toSet();

          Set<String> where(bool Function(Set<Object> ids) f) => {
            for (var e in model.entries)
              if (f(e.value)) e.key,
          };

          Set<String> inSet(Iterable<Object?> s) {
            var ids = s.nonNulls.toSet();
            return where((r) => r.any(ids.contains));
          }

          Set<String> notInSet(Iterable<Object?> s) {
            var ids = s.nonNulls.toSet();
            if (ids.isEmpty) return all;
            return where((r) => r.isEmpty || r.any((v) => !ids.contains(v)));
          }

          var none = where((r) => r.isEmpty);
          var some = where((r) => r.isNotEmpty);

          Future<void> check(String q, Object? params, Set<String> exp) async {
            var p = params == null ? '' : '  $params';
            for (var (query, expected) in [
              (q, exp),
              ('!($q)', all.difference(exp)),
            ]) {
              var expList = expected.toList()..sort();
              try {
                var got = await select(query, params);
                if (got.join(',') != expList.join(',')) {
                  failures.add(
                    '`$query`$p: [${got.join(',')}], expected $expList',
                  );
                }
              } catch (e) {
                failures.add('`$query`$p: ERROR $e');
              }
            }
          }

          // The sets: literals, and parameters (positional and named).
          var sets = <(String, List<Object?>)>[
            ('[]', []),
            ('null', [null]),
            ('[null]', [null]),
            ('$id1', [id1]),
            ('[$id1]', [id1]),
            ('[$id1, $id2]', [id1, id2]),
            ('[$id2, null]', [id2, null]),
          ];
          for (var (literal, s) in sets) {
            await check('$field =~ $literal', null, inSet(s));
            await check('$field !~ $literal', null, notInSet(s));
          }

          var params = <(Object?, List<Object?>)>[
            (<Object>[], []),
            (null, [null]),
            ([null], [null]),
            (id1, [id1]),
            ([id1], [id1]),
            ([id1, id2], [id1, id2]),
            ([id2, null], [id2, null]),
          ];
          for (var (param, s) in params) {
            await check('$field =~ ?', [param], inSet(s));
            await check('$field !~ ?', [param], notInSet(s));
            await check('$field =~ ?:ids', {'ids': param}, inSet(s));
            await check('$field !~ ?:ids', {'ids': param}, notInSet(s));
          }

          // Entities as parameters (compared by their IDs):
          await check('$field =~ ?', [entityParams.first], inSet([id1]));
          await check('$field =~ ?', [entityParams], inSet([id1, id2]));
          await check('$field !~ ?', [entityParams], notInSet([id1, id2]));

          // `==` / `!=`: `null` and `[]` are "without related entities":
          for (var literal in ['null', '[]']) {
            await check('$field == $literal', null, none);
            await check('$field != $literal', null, some);
          }
          for (var param in [null, <Object>[]]) {
            await check('$field == ?', [param], none);
            await check('$field != ?', [param], some);
            await check('$field == ?:v', {'v': param}, none);
            await check('$field != ?:v', {'v': param}, some);
          }
          for (var id in [id1, id2]) {
            await check('$field == $id', null, where((r) => r.contains(id)));
            await check(
              '$field != $id',
              null,
              where((r) => r.isEmpty || r.any((v) => v != id)),
            );
            await check('$field == ?', [id], where((r) => r.contains(id)));
          }
        }

        // A to-many `EntityReferenceList` (`Address.closedStores`) and a
        // to-many `List` (`Address.stores`):
        var sc1 = Store('rk-c1', 1);
        var sc2 = Store('rk-c2', 2);
        var sc3 = Store('rk-c3', 3);
        for (var s in [sc1, sc2, sc3]) {
          await storeRepo.store(s);
        }

        var addresses = {
          'A': Address(
            'RK',
            'RK A',
            'RK Street',
            1,
            stores: [Store('rk-a1', 1)],
            closedStores: [sc1],
          ),
          'B': Address(
            'RK',
            'RK B',
            'RK Street',
            2,
            stores: [Store('rk-b1', 2), Store('rk-b2', 3)],
            closedStores: [sc1, sc2],
          ),
          'C': Address('RK', 'RK C', 'RK Street', 3),
        };
        var addressNames = <Object, String>{};
        for (var e in addresses.entries) {
          addressNames[(await addressRepo.store(e.value))!] = e.key;
        }

        Future<List<String>> selectAddresses(String q, Object? params) async =>
            (await addressRepo.selectByQuery(
              q,
              parameters: params,
            )).map((e) => addressNames[e.id]).nonNulls.toList()..sort();

        Set<Object> ids(Iterable<Store> stores) =>
            stores.map((s) => s.id!).toSet();

        await relationship(
          field: 'closedStores',
          model: {
            'A': {sc1.id!},
            'B': {sc1.id!, sc2.id!},
            'C': {},
          },
          select: selectAddresses,
          id1: sc1.id!,
          id2: sc2.id!,
          entityParams: [sc1, sc2],
        );

        var aStores = addresses['A']!.stores;
        var bStores = addresses['B']!.stores;
        await relationship(
          field: 'stores',
          model: {'A': ids(aStores), 'B': ids(bStores), 'C': {}},
          select: selectAddresses,
          id1: aStores.first.id!,
          id2: bStores.first.id!,
          entityParams: [aStores.first, bStores.first],
        );

        // A to-one entity (`Store.owner`) and a to-one `EntityReference`
        // (`User.userInfo`):
        var alpha = Address('RK', 'RK User', 'RK Street', 9);
        var users = {
          'X': User(
            'rk-x@$testDomain',
            'p',
            alpha,
            [],
            userInfo: UserInfo('rk-x'),
            creationTime: DateTime.utc(2020),
          ),
          'Y': User(
            'rk-y@$testDomain',
            'p',
            alpha,
            [],
            userInfo: UserInfo('rk-y'),
            creationTime: DateTime.utc(2020),
          ),
          'Z': User(
            'rk-z@$testDomain',
            'p',
            alpha,
            [],
            creationTime: DateTime.utc(2020),
          ),
        };
        var userNames = <Object, String>{};
        for (var e in users.entries) {
          userNames[(await userRepo.store(e.value))!] = e.key;
        }

        Future<List<String>> selectUsers(String q, Object? params) async =>
            (await userRepo.selectByQuery(
              q,
              parameters: params,
            )).map((e) => userNames[e.id]).nonNulls.toList()..sort();

        var (ux, uy) = (users['X']!, users['Y']!);
        var infoX = ux.userInfo.id!;
        var infoY = uy.userInfo.id!;
        await relationship(
          field: 'userInfo',
          model: {
            'X': {infoX},
            'Y': {infoY},
            'Z': {},
          },
          select: selectUsers,
          id1: infoX,
          id2: infoY,
          entityParams: [ux.userInfo.entity!, uy.userInfo.entity!],
        );

        var stores = {
          'X': Store('rk-sx', 1, owner: ux),
          'Y': Store('rk-sy', 2, owner: uy),
          'Z': Store('rk-sz', 3),
        };
        var storeNames = <Object, String>{};
        for (var e in stores.entries) {
          storeNames[(await storeRepo.store(e.value))!] = e.key;
        }

        Future<List<String>> selectStores(String q, Object? params) async =>
            (await storeRepo.selectByQuery(
              q,
              parameters: params,
            )).map((e) => storeNames[e.id]).nonNulls.toList()..sort();

        await relationship(
          field: 'owner',
          model: {
            'X': {ux.id!},
            'Y': {uy.id!},
            'Z': {},
          },
          select: selectStores,
          id1: ux.id!,
          id2: uy.id!,
          entityParams: [ux, uy],
        );

        expect(failures, isEmpty, reason: failures.join('\n'));
      });

      test('populate', () async {
        var result = await entityRepositoryProvider.storeAllFromJson({
          'user': [
            {
              'id': 1001,
              'email': 'extra@mail.com',
              'password': 'abc789',
              'roles': [
                {'type': 'guest', 'enabled': true, 'value': 3.33},
              ],
              'wakeUpTime': Time(10, 0),
              'creationTime': DateTime(2022, 10, 1),
              'address': 11001,
            },
            {
              'id': 1002,
              'email': 'extra2@mail.com',
              'password': 'abc7890',
              'roles': [],
              'wakeUpTime': Time(11, 0),
              'creationTime': DateTime(2022, 10, 2),
              'address': {
                'id': 11111,
                'state': 'EX2',
                'city': 'Extra2',
                'street': 'Street x2',
                'number': 2,
              },
            },
          ],
        });

        var sqlAdapter = await entityRepositoryProvider.adapter;

        var information = sqlAdapter.information(extended: true);

        _log.info('${sqlAdapter.runtimeType} INFORMATION:');
        _log.info(
          Json.encode(information, pretty: true).replaceAllMapped(
            RegExp(r'\[\s*(?:\d+,\s*|\d+\s*)+\]'),
            (m) => m[0]!.replaceAll(RegExp(r'\s+'), ' '),
          ),
        );

        expect(result.length, equals(1));

        var usersResult = (result['user'] as List).cast<User>();

        expect(usersResult.length, equals(2));

        var usersResult0 = usersResult[0];
        expect(usersResult0.address.id, equals(11001));
        expect(usersResult0.address.state, equals('EX'));
        expect(usersResult0.roles.length, equals(1));
        expect(usersResult0.roles[0].enabled, isTrue);
        expect(usersResult0.roles[0].type, equals(RoleType.guest));
        expect(usersResult0.roles[0].value, equals(Decimal.from(3.33)));

        var usersResult1 = usersResult[1];
        expect(usersResult1.address.id, equals(11111));
        expect(usersResult1.address.state, equals('EX2'));
        expect(usersResult1.roles, isEmpty);

        var addressAPIRepository =
            entityRepositoryProvider.addressAPIRepository;
        var userAPIRepository = entityRepositoryProvider.userAPIRepository;

        print('DELETE CASCADE [ERROR]:');
        print(
          '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
        );

        expect(Transaction.executingTransaction, isNull);

        await expectLater(
          () async => await addressAPIRepository.deleteEntityCascade(
            usersResult0.address,
          ),
          throwsA(isA<TransactionAbortedError>()),
        );

        print('DELETE CASCADE:');
        print(
          '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
        );

        expect(Transaction.executingTransaction, isNull);

        var deleted = await userAPIRepository.deleteEntityCascade(usersResult0);

        expect(Transaction.executingTransaction, isNull);

        print(deleted);

        expect(deleted, isNotEmpty);

        expect(deleted.length, 3);

        var delUser = deleted.whereType<User>().firstOrNull;
        expect(delUser, isNotNull);
        expect(delUser!.email, 'extra@mail.com');
        expect(delUser.roles, isEmpty);
        expect(delUser.address, isNotNull);

        var delRole = deleted.whereType<Role>().firstOrNull;
        expect(delRole, isNotNull);
        expect(delRole!.enabled, isTrue);
        expect(delRole.type, equals(RoleType.guest));

        var delAddress = deleted.whereType<Address>().firstOrNull;
        expect(delAddress, isNotNull);
        expect(delAddress!.state, equals('EX'));

        print(
          '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>',
        );
      });
    },
    skip: testConfigDB.unsupportedReason,
  );

  return configSupported;
}
