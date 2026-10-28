@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicInt;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class _Owner extends Entity {
  int? id;
  String name;

  _Owner({this.id, this.name = ''});

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const ['id', 'name'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' => TypeInfo.tString,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'name':
        name = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class _Tag extends Entity {
  int? id;
  String label;

  _Tag({this.id, this.label = ''});

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const ['id', 'label'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'label' => label as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'label' => TypeInfo.tString,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'label':
        label = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

class _Item extends Entity {
  int? id;
  String? code;
  String title;
  RoleType? kind;
  _Owner? owner;
  List<_Tag> tags;
  String? secret;

  _Item({
    this.id,
    this.code,
    this.title = '',
    this.kind,
    this.owner,
    List<_Tag>? tags,
  }) : tags = tags ?? [];

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const [
    'id',
    'code',
    'title',
    'kind',
    'owner',
    'tags',
    'secret',
  ];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'code' => code as V?,
    'title' => title as V?,
    'kind' => kind as V?,
    'owner' => owner as V?,
    'tags' => tags as V?,
    'secret' => secret as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'code' || 'title' || 'secret' => TypeInfo.tString,
    'kind' => TypeInfo<RoleType>(RoleType),
    'owner' => TypeInfo<_Owner>(_Owner),
    'tags' => TypeInfo<List<_Tag>>(List, [TypeInfo<_Tag>(_Tag)]),
    _ => null,
  };

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      switch (key) {
        'code' => const [EntityField.unique(), EntityField.maximum(20)],
        'secret' => const [EntityField.hidden()],
        _ => null,
      };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'code':
        code = value as String?;
      case 'title':
        title = value as String;
      case 'kind':
        kind = value is RoleType ? value : RoleType$from(value);
      case 'owner':
        owner = value as _Owner?;
      case 'tags':
        tags = value == null ? [] : List<_Tag>.from(value as Iterable);
      case 'secret':
        secret = value as String?;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'kind': kind?.name,
    'owner': owner?.id,
    'tags': tags.map((e) => e.id).toList(),
  };
}

class _Provider extends EntityRepositoryProvider {
  late final DBSQLiteAdapter adapter;
  late final DBSQLEntityRepository<_Owner> ownerRepository;
  late final DBSQLEntityRepository<_Tag> tagRepository;
  late final DBSQLEntityRepository<_Item> itemRepository;

  _Provider({
    bool generateTables = true,
    bool checkTables = true,
    bool logSQL = false,
  }) {
    adapter = DBSQLiteAdapter(
      sqliteMemoryPath,
      parentRepositoryProvider: this,
      generateTables: generateTables,
      checkTables: checkTables,
      logSQL: logSQL,
    );

    ownerRepository = DBSQLEntityRepository<_Owner>(
      adapter,
      'owner',
      GenericEntityHandler<_Owner>(
        instantiatorDefault: _Owner.new,
        sampleEntity: _Owner(),
      ),
    );

    tagRepository = DBSQLEntityRepository<_Tag>(
      adapter,
      'tag',
      GenericEntityHandler<_Tag>(
        instantiatorDefault: _Tag.new,
        sampleEntity: _Tag(),
      ),
    );

    itemRepository = DBSQLEntityRepository<_Item>(
      adapter,
      'item',
      GenericEntityHandler<_Item>(
        instantiatorDefault: _Item.new,
        sampleEntity: _Item(),
      ),
    );
  }

  void dispose() {
    adapter.close();
    close();
  }
}

/// A `checkDBTables(force: true)` error message (`null` if OK).
Future<String?> _checkError(DBSQLAdapter adapter) async {
  try {
    await adapter.checkDBTables(force: true);
    return null;
  } on StateError catch (e) {
    return e.message;
  }
}

TransactionOperationSelect _op(String repositoryName, Object executor) =>
    TransactionOperationSelect(repositoryName, false, executor, ConditionANY());

void main() {
  setUpAll(() {
    User$reflection.boot();
  });

  group('DBSQLiteAdapter config', () {
    test('fromConfig', () {
      var a1 = DBSQLiteAdapter.fromConfig({'memory': true});
      expect(a1.inMemory, isTrue);
      expect(a1.databasePath, equals(sqliteMemoryPath));
      expect(a1.busyTimeout, equals(5000));
      expect(a1.logSQL, isFalse);
      a1.close();

      var a2 = DBSQLiteAdapter.fromConfig(null);
      expect(a2.inMemory, isTrue);
      a2.close();

      var a3 = DBSQLiteAdapter.fromConfig({
        'db': 'memory',
        'busy-timeout': 123,
        'log': {'sql': true},
        'populate': {
          'tables': 'CREATE TABLE t (id INT)',
          'source': {'t': []},
          'variables': {'x': 1},
          'generateTables': true,
          'checkTables': false,
        },
      });
      expect(a3.inMemory, isTrue);
      expect(a3.busyTimeout, equals(123));
      a3.close();

      var a4 = DBSQLiteAdapter.fromConfig({
        'inMemory': true,
        'busyTimeout': 7,
        'log.sql': true,
      });
      expect(a4.busyTimeout, equals(7));
      expect(a4.logSQL, isTrue);
      expect(a4.toString(), startsWith('DBSQLiteAdapter#'));
      expect(a4.toString(), endsWith('{memory}'));
      a4.close();
      expect(a4.toString(), endsWith('{memory, closed}'));

      var a5 = DBSQLiteAdapter.fromConfig({
        'busy_timeout': 9,
        'log': true,
      }, defaultDatabasePath: '');
      expect(a5.inMemory, isTrue);
      expect(a5.busyTimeout, equals(9));
      expect(a5.logSQL, isTrue);
      a5.close();

      expect(
        () => DBSQLiteAdapter.fromConfig({'memory': false}),
        throwsArgumentError,
      );
    });

    test('DBSQLAdapter registry', () async {
      DBSQLiteAdapter.boot();

      expect(DBSQLAdapter.registeredAdaptersNames, contains('sqlite'));
      expect(DBSQLAdapter.registeredAdaptersTypes, contains(DBSQLiteAdapter));

      var instantiator = DBSQLAdapter.getAdapterInstantiator(name: 'sqlite');
      expect(instantiator, isNotNull);

      // An invalid config: `null` (logged).
      expect(await instantiator!({'memory': false}), isNull);

      var adapter = await DBSQLAdapter.fromConfig({
        'sqlite': {'memory': true},
      });
      expect(adapter, isA<DBSQLiteAdapter>());
      expect(adapter.capability.info, contains('tableSQL: true'));
      adapter.close();

      expect(
        () => DBSQLAdapter.fromConfig({'nope': {}}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains("Can't find `DBSQLAdapter<Object>` instantiator"),
          ),
        ),
      );
    });

    test('parseConfigLogSQL', () {
      expect(DBSQLAdapter.parseConfigLogSQL(null), isNull);
      expect(DBSQLAdapter.parseConfigLogSQL({}), isNull);
      expect(DBSQLAdapter.parseConfigLogSQL({'log.sql': true}), isTrue);
      expect(DBSQLAdapter.parseConfigLogSQL({'log.sql': 'false'}), isFalse);
      expect(DBSQLAdapter.parseConfigLogSQL({'log': true}), isTrue);
      expect(DBSQLAdapter.parseConfigLogSQL({'log': 'no'}), isFalse);
    });

    test('parseConfigLogSQL: `log: {sql: ...}`', () {
      expect(
        DBSQLAdapter.parseConfigLogSQL({
          'log': {'sql': true},
        }),
        isTrue,
      );
      expect(
        DBSQLAdapter.parseConfigLogSQL({
          'log': {'sql': false},
        }),
        isFalse,
      );
    });

    test('parseConfigDBGenerateTablesAndCheckTables', () {
      expect(
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables(null),
        equals((generateTables: false, checkTables: true)),
      );
      expect(
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables({
          'generate-tables': true,
          'check_tables': false,
        }),
        equals((generateTables: true, checkTables: false)),
      );
      expect(
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables({
          'populate': {'generate_tables': true, 'checkTables': false},
        }),
        equals((generateTables: true, checkTables: false)),
      );
      expect(
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables({
          'checkTables': true,
          'populate': {'generateTables': true, 'checkTables': false},
        }),
        equals((generateTables: true, checkTables: true)),
      );
    });
  });

  group('SQL', () {
    test('MultipleSQL', () {
      var s1 = SQL('SELECT 1', null, null, {}, mainTable: 't');
      var s2 = SQL('SELECT 2', null, null, {}, mainTable: 't');
      var m = MultipleSQL([s1, s2]);
      expect(m.sqlsLength, equals(2));
      expect(m.mainSQL, same(s1));
      expect(m.allSQLs, equals([s1, s2]));

      expect(s1.sqlsLength, equals(1));
      expect(s1.mainSQL, same(s1));
      expect(s1.allSQLs, equals([s1]));
    });

    test('dummy, copy, positional', () {
      expect(SQL.dummy.isSharedDummy, isTrue);
      expect(SQL.dummy.isDummy, isTrue);
      expect(SQL.dummy.isFullyDummy, isTrue);

      var copy = SQL.dummy.ensureNotSharedDummy();
      expect(copy.isSharedDummy, isFalse);
      expect(copy.isDummy, isTrue);
      copy.preSQL = [SQL('SELECT 1', null, null, {}, mainTable: 't')];
      expect(copy.hasPreSQL, isTrue);
      expect(copy.isFullyDummy, isFalse);

      var sql = SQL(
        'SELECT * FROM t WHERE a = @a AND b = @b AND a2 = @a',
        null,
        {'a': 1, 'b': 2},
        {'a': 1, 'b': 2},
        mainTable: 't',
      );
      expect(identical(sql.ensureNotSharedDummy(), sql), isTrue);
      expect(
        sql.sqlPositional,
        equals('SELECT * FROM t WHERE a = ? AND b = ? AND a2 = ?'),
      );
      expect(sql.parametersKeysByPosition, equals(['a', 'b', 'a']));
      expect(sql.parametersValuesByPosition, equals([1, 2, 1]));

      var noParams = SQL('SELECT 1', null, null, {}, mainTable: 't');
      expect(noParams.parametersValuesByPosition, isEmpty);
      expect(noParams.parametersKeysByPosition, isEmpty);
      expect(noParams.sqlPositional, equals('SELECT 1'));
    });

    test('toString', () {
      var rel = TableRelationshipReference(
        'a__bs__rel',
        'a',
        'id',
        int,
        'a_id',
        'b',
        'id',
        int,
        'b_id',
      );
      var sql = SQL(
        'SELECT * FROM a',
        null,
        null,
        {'p': 1, 'o': Object()},
        condition: ConditionID(1),
        entityName: 'A',
        mainTable: 'a',
        relationship: rel,
        returnColumns: {'id'},
        returnColumnsAliases: {'id': 'a_id'},
      );
      sql.preSQL = [SQL('SELECT 1', null, null, {}, mainTable: 'a')];
      sql.posSQL = [SQL('SELECT 2', null, null, {}, mainTable: 'a')];

      var s = sql.toString();
      expect(s, startsWith('SQL<< SELECT * FROM a >>( {"p":1,"o":'));
      expect(s, contains(' ; Condition<< #ID == 1 >>'));
      expect(s, contains(' ; entityName: A'));
      expect(
        s,
        contains(' ; mainTable: a (TableRelationshipReference[a__bs__rel]'),
      );
      expect(s, contains(' ; returnColumns: {id}'));
      expect(s, contains(' ; returnColumnsAliases: {id: a_id}'));
      expect(s, contains('\n - preSQL: [SQL<< SELECT 1 >>'));
      expect(s, contains('\n - posSQL: [SQL<< SELECT 2 >>'));
    });
  });

  group('DBSQLiteAdapter', () {
    late DBSQLiteAdapter adapter;

    setUp(() {
      adapter = DBSQLiteAdapter(sqliteMemoryPath);
    });

    tearDown(() => adapter.close());

    test('column types', () async {
      adapter.executeRawSQL(
        'CREATE TABLE types ('
        'id INTEGER PRIMARY KEY, a BOOLEAN, b BOOL, c TINYINT, d INT8, '
        'e BIGINT UNSIGNED, f DECIMAL(10,2), g NUMERIC, h FLOAT, '
        'i DOUBLE PRECISION, j REAL, k BLOB, l TIME, m DATE, n DATETIME, '
        'o TEXT, p CHAR(5), q VARCHAR(20), r CLOB, s ENUM, '
        't UNSIGNED BIG INT, u NATIVE CHARACTER(70), v LONGBLOB, '
        'w FLOATING, x DOUBLEX, y JSONB, z)',
      );

      var types = await adapter.getTableFieldsTypes('types');
      expect(
        types,
        equals({
          'id': int,
          'a': bool,
          'b': bool,
          'c': int,
          'd': int,
          'e': int,
          'f': Decimal,
          'g': Decimal,
          'h': double,
          'i': double,
          'j': double,
          'k': Uint8List,
          'l': Time,
          'm': DateTime,
          'n': DateTime,
          'o': String,
          'p': String,
          'q': String,
          'r': String,
          's': String,
          't': int,
          'u': String,
          'v': Uint8List,
          'w': double,
          'x': double,
          'y': String,
          'z': String,
        }),
      );

      expect(await adapter.getTableFieldsTypes('nope'), isNull);
      expect(adapter.listTablesNames(), equals(['types']));
    });

    test('parameters normalization', () {
      var rows = adapter.executeRawSQL(
        'SELECT ? AS a, ? AS b, ? AS c, ? AS d, ? AS e, ? AS f, ? AS g, '
        '? AS h, ? AS i, ? AS j, ? AS k',
        [
          true,
          DateTime.utc(2020, 1, 2, 3, 4, 5),
          Time(10, 20, 30),
          RoleType.guest,
          BigInt.from(42),
          BigInt.parse('123456789012345678901234567890'),
          DynamicInt.fromInt(7),
          Decimal.parse('1.5'),
          <int>[1, 2, 3],
          Uri.parse('http://x/'),
          Uint8List.fromList([4, 5]),
        ],
      );

      var row = rows.first;
      expect(row['a'], equals(1));
      expect(row['b'], equals('2020-01-02T03:04:05.000Z'));
      expect(row['c'], equals('10:20:30'));
      expect(row['d'], equals('guest'));
      expect(row['e'], equals(42));
      expect(row['f'], equals('123456789012345678901234567890'));
      expect(row['g'], equals(7));
      expect(row['h'], equals(1.5));
      expect(row['i'], equals([1, 2, 3]));
      expect(row['j'], equals('http://x/'));
      expect(row['k'], equals([4, 5]));
    });

    test('executeTableSQL, findIndexesNamesInUse, connections', () async {
      expect(await adapter.executeTableSQL('CREATE TABLE ok (id INT)'), isTrue);
      expect(await adapter.executeTableSQL('CREATE TABLE bad ('), isFalse);

      adapter.executeRawSQL('CREATE INDEX ok_idx ON ok (id)');

      expect(await adapter.findIndexesNamesInUse('ok', []), isEmpty);
      expect(
        await adapter.findIndexesNamesInUse('x', ['ok_idx', 'ok', 'free']),
        equals({'ok_idx': 'ok', 'ok': null}),
      );

      var conn = adapter.createConnection();
      expect(conn.connectionURL, equals('sqlite://:memory:'));
      expect(conn.info, contains('db: :memory:'));
      expect(adapter.getConnectionURL(conn), equals('sqlite://:memory:'));
      expect(adapter.isConnectionValid(conn, checkUsage: false), isTrue);
      expect(await adapter.isPoolElementInvalid(conn), isFalse);
      expect(adapter.isPoolElementValid(conn), isTrue);
      expect(adapter.recyclePoolElement(conn), same(conn));

      conn.close();
      expect(await adapter.isPoolElementInvalid(conn), isTrue);
      expect(adapter.isConnectionValid(conn), isFalse);

      expect(
        adapter.primaryKeyTypeToSQLType(String),
        equals('VARCHAR PRIMARY KEY'),
      );
      expect(
        adapter.primaryKeyTypeToSQLType(int),
        equals('INTEGER PRIMARY KEY AUTOINCREMENT'),
      );
    });

    test('populateTables', () async {
      expect(await adapter.populateTables(null), isEmpty);
      expect(await adapter.populateTables('no tables here'), isEmpty);

      var dir = Directory.systemTemp.createTempSync('bones_api_cov_sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      var file = File('${dir.path}/tables.sql');
      file.writeAsStringSync(
        '-- A comment\n'
        'CREATE TABLE IF NOT EXISTS "f1" (id INT) ;\n'
        'CREATE TABLE f2 (id INT) ; -- trailing\n'
        'CREATE INDEX f2_idx ON f2 (id) ;\n',
      );

      expect(await adapter.populateTables(file.path), equals(['f1', 'f2']));
      expect(adapter.listTablesNames(), containsAll(['f1', 'f2']));

      expect(
        () => adapter.populateTables('CREATE TABLE broken ( ;'),
        throwsStateError,
      );
    });

    test('extractCreateIndexInSQL', () {
      var createIndex = DBSQLAdapter.extractCreateIndexInSQL(
        'CREATE INDEX IF NOT EXISTS "t__a__idx" ON "t" ("a") ;',
      )!;
      expect(createIndex.table, equals('t'));
      expect(createIndex.columns, equals(['a']));

      createIndex = DBSQLAdapter.extractCreateIndexInSQL(
        'CREATE UNIQUE INDEX `t__a_b__unique` ON `t` (`a`, b DESC)',
      )!;
      expect(createIndex.table, equals('t'));
      expect(createIndex.columns, equals(['a', 'b']));
      // An expression: unknown columns.
      expect(
        DBSQLAdapter.extractCreateIndexInSQL(
          'CREATE INDEX t__a__idx ON t (lower(a))',
        ),
        isNull,
      );
      expect(
        DBSQLAdapter.extractCreateIndexInSQL('CREATE TABLE t (a INT)'),
        isNull,
      );
    });

    test(
      'populateTables: CREATE INDEX on a column missing in a table',
      () async {
        // A table created before the column `x` was added to the entity:
        adapter.executeRawSQL('CREATE TABLE m (id INT)');

        var sqls =
            'CREATE TABLE IF NOT EXISTS "m" (id INT, x INT) ;\n'
            'CREATE INDEX IF NOT EXISTS "m__x__idx" ON "m" ("x") ;\n'
            'CREATE INDEX IF NOT EXISTS "m__id__idx" ON "m" ("id") ;\n';

        // Skipped: left to `checkTables` (pending), and the next SQLs run.
        expect(await adapter.populateTables(sqls), equals(['m']));
        expect(
          await adapter.findIndexesNamesInUse('m', ['m__x__idx', 'm__id__idx']),
          equals({'m__id__idx': 'm'}),
        );

        // Not a missing column (no table `n2`): still an error.
        expect(
          () => adapter.populateTables(
            'CREATE TABLE IF NOT EXISTS "n" (x INT) ;\n'
            'CREATE INDEX IF NOT EXISTS "n__x__idx" ON "n2" ("x") ;',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              startsWith('Error creating table SQL'),
            ),
          ),
        );

        // Without `checkTables`: an error naming the missing columns.
        var adapter2 = DBSQLiteAdapter(sqliteMemoryPath, checkTables: false);
        addTearDown(adapter2.close);

        adapter2.executeRawSQL('CREATE TABLE m (id INT)');

        expect(
          () => adapter2.populateTables(sqls),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('`m` exists without the columns [x]'),
                isNot(contains('[id]')),
              ),
            ),
          ),
        );
      },
    );

    test('removeSQLsComments: block comments', () {
      expect(
        DBSQLAdapter.removeSQLsComments('CREATE TABLE a (id INT) ; /* x */'),
        equals('CREATE TABLE a (id INT) ;  '),
      );
      // Replaced by a space: tokens around it aren't joined.
      expect(
        DBSQLAdapter.removeSQLsComments('SELECT/* a\n b */1'),
        equals('SELECT 1'),
      );
    });
  });

  group('DBSQLiteAdapter entities', () {
    late _Provider provider;
    late DBSQLiteAdapter adapter;

    final logs = <String>[];

    setUpAll(() async {
      LoggerHandler.root.logDbTo(
        messageLogger: (level, message) => logs.add(message),
      );

      provider = _Provider(logSQL: true);
      await provider.ensureInitialized();
      adapter = provider.adapter;
      await adapter.ensureInitialized();
      expect(adapter.generatedTables, isTrue);
      expect(await adapter.checkDBTables(force: true), isTrue);
    });

    tearDownAll(() {
      LoggerHandler.root.logDbTo(messageLogger: null);
      provider.dispose();
    });

    test('store, select, count, delete', () async {
      var t1 = _Tag(label: 'red');
      var t2 = _Tag(label: 'blue');
      // An owner not stored yet: stored with the item.
      var item = _Item(
        code: 'A1',
        title: 'first',
        kind: RoleType.admin,
        owner: _Owner(name: 'joe'),
        tags: [t1, t2],
      );

      var id = await provider.itemRepository.store(item);
      expect(id, isNotNull);
      expect(item.owner?.id, isNotNull);

      var item2 = _Item(code: 'B2', title: 'second', kind: RoleType.guest);
      await provider.itemRepository.store(item2);

      var byId = await provider.itemRepository.select(ConditionID(id));
      expect(byId.map((e) => e.code), equals(['A1']));
      expect(byId.first.owner?.name, equals('joe'));
      expect(
        byId.first.tags.map((e) => e.label),
        unorderedEquals(['red', 'blue']),
      );

      var byIds = await provider.itemRepository.select(
        ConditionIdIN([id, item2.id]),
      );
      expect(byIds.map((e) => e.code), unorderedEquals(['A1', 'B2']));

      var all = await provider.itemRepository.select(ConditionANY());
      expect(all, hasLength(2));

      expect(await provider.itemRepository.count(), equals(2));

      var byOwner = await provider.itemRepository.selectByQuery(
        'owner.name == ? || title == ?',
        parameters: ['joe', 'second'],
      );
      expect(byOwner.map((e) => e.code), unorderedEquals(['A1', 'B2']));

      var byTag = await provider.itemRepository.selectByQuery(
        'tags.label == ?',
        parameters: ['blue'],
      );
      expect(byTag.map((e) => e.code), equals(['A1']));

      var deleted = await provider.itemRepository.deleteByQuery(
        'code == ?',
        parameters: ['A1'],
      );
      expect(deleted.map((e) => e.code), equals(['A1']));
      expect(await provider.itemRepository.count(), equals(1));

      expect(logs.join('\n'), contains('[tID: '));
    });

    test('constraint errors', () async {
      await provider.itemRepository.store(_Item(code: 'U1', title: 'u'));

      // UNIQUE:
      expect(
        () async =>
            await provider.itemRepository.store(_Item(code: 'U1', title: 'v')),
        throwsA(
          isA<EntityFieldInvalid>()
              .having((e) => e.reason, 'reason', 'unique')
              .having((e) => e.fieldName, 'fieldName', 'code')
              .having((e) => e.tableName, 'tableName', 'item')
              .having((e) => e.value, 'value', 'U1'),
        ),
      );

      var ra = provider.itemRepository.repositoryAdapter;

      // CHECK (the enum):
      var fields = <String, dynamic>{
        'code': 'C1',
        'title': 'c',
        'kind': 'bogus',
      };
      var sql = await ra.generateInsertSQL(Transaction(), _Item(), fields);
      expect(
        () async => await ra.insertSQL(_op('item', ra), sql, fields),
        throwsA(
          isA<EntityFieldInvalid>().having((e) => e.reason, 'reason', 'check'),
        ),
      );

      // NOT NULL (a table with a `NOT NULL` column):
      adapter.executeRawSQL(
        'CREATE TABLE strict (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name VARCHAR NOT NULL, other VARCHAR)',
      );
      var fields2 = <String, dynamic>{'other': 'x'};
      var sql2 = await adapter.generateInsertSQL(
        Transaction(),
        'strict',
        'strict',
        fields2,
      );
      expect(
        () async => await adapter.insertSQL(
          _op('strict', adapter),
          'strict',
          'strict',
          sql2,
          fields2,
        ),
        throwsA(
          isA<EntityFieldInvalid>()
              .having((e) => e.reason, 'reason', 'null')
              .having((e) => e.tableName, 'tableName', 'strict')
              .having((e) => e.fieldName, 'fieldName', 'name'),
        ),
      );
    });

    test('DBSQLRepositoryAdapter', () async {
      var ra = provider.itemRepository.repositoryAdapter;
      expect(ra.dialect.name, equals('SQLite'));
      expect(
        ra.toString(),
        equals(
          'SQLRepositoryAdapter{name: item, tableName: item, type: _Item}',
        ),
      );

      // Insert:
      var fields = <String, dynamic>{'code': 'R1', 'title': 'r'};
      var insert = await ra.generateInsertSQL(Transaction(), _Item(), fields);
      var id = await ra.insertSQL(_op('item', ra), insert, fields);
      expect(id, isA<int>());

      // Count:
      var countSQL = await ra.generateCountSQL(
        Transaction(),
        matcher: Condition.parse('code == ?'),
        parameters: {'code': 'R1'},
      );
      expect(await ra.countSQL(_op('item', ra), countSQL), equals(1));

      var countAllSQL = await ra.generateCountSQL(Transaction());
      expect(await ra.countSQL(_op('item', ra), countAllSQL), greaterThan(0));

      // Select:
      var select = await ra.generateSelectSQL(
        Transaction(),
        ConditionID(id),
        limit: 10,
      );
      var rows = await ra.selectSQL(_op('item', ra), select);
      expect(rows.map((e) => e['code']), equals(['R1']));

      // Update:
      var updateFields = <String, dynamic>{'title': 'r2'};
      var update = await ra.generateUpdateSQL(
        Transaction(),
        _Item(),
        id,
        updateFields,
      );
      expect(
        await ra.updateSQL(_op('item', ra), update, id, updateFields),
        equals(id),
      );

      // Update of a not stored entity:
      var update2 = await ra.generateUpdateSQL(
        Transaction(),
        _Item(),
        9999,
        updateFields,
      );
      expect(
        () async =>
            await ra.updateSQL(_op('item', ra), update2, 9999, updateFields),
        throwsA(
          isA<DBSQLiteAdapterException>().having(
            (e) => e.message,
            'message',
            contains("Can't update not stored entity into table `item`"),
          ),
        ),
      );

      // Relationships:
      var tag1 = await provider.tagRepository.store(_Tag(label: 't1'));
      var tag2 = await provider.tagRepository.store(_Tag(label: 't2'));

      var relSQLs = await ra.generateInsertRelationshipSQLs(
        Transaction(),
        'tags',
        id,
        'tag',
        [tag1, tag2],
      );
      expect(relSQLs, hasLength(2));
      // The last one also deletes the entity's other relationship rows:
      expect(relSQLs.first.posSQL, isNull);
      expect(relSQLs.last.posSQL!.single.sql, startsWith('DELETE FROM'));

      // A just inserted entity (`newEntity`, on the adapters with
      // `generatedIDsHaveNoRelationships`): it has none, so no `DELETE`.
      var relSQLsNew = await adapter.generateInsertRelationshipSQLs(
        Transaction(),
        'item',
        'item',
        'tags',
        id,
        'tag',
        [tag1, tag2],
        newEntity: true,
      );
      expect(relSQLsNew.map((e) => e.sql), equals(relSQLs.map((e) => e.sql)));
      expect(relSQLsNew.map((e) => e.posSQL), everyElement(isNull));

      expect(
        await ra.insertRelationshipSQLs(_op('item', ra), relSQLs, id, 'tag', [
          tag1,
          tag2,
        ]),
        isTrue,
      );

      var relSelect = await ra.generateSelectRelationshipSQL(
        Transaction(),
        'tags',
        id,
        'tag',
      );
      var relRows = await ra.selectRelationshipSQL(
        _op('item', ra),
        relSelect,
        id,
        'tag',
      );
      expect(relRows, hasLength(2));

      var relsSelect = await ra.generateSelectRelationshipsSQL(
        Transaction(),
        'tags',
        [id],
        'tag',
      );
      var relsRows = await ra.selectRelationshipsSQL(
        _op('item', ra),
        relsSelect,
        [id],
        'tag',
      );
      expect(relsRows, hasLength(2));

      // Delete:
      var delete = await ra.generateDeleteSQL(
        Transaction(),
        Condition.parse('code == ?'),
        parameters: {'code': 'R1'},
      );
      var deleted = await ra.deleteSQL(_op('item', ra), delete);
      expect(deleted.map((e) => e['code']), equals(['R1']));
    });

    test('generate SQLs: errors', () async {
      var t = Transaction();

      expect(
        () async => await adapter.generateInsertSQL(t, 'x', 'nope', {'a': 1}),
        throwsStateError,
      );
      expect(
        () async =>
            await adapter.generateUpdateSQL(t, 'x', 'nope', 1, {'a': 1}),
        throwsStateError,
      );
      expect(
        await adapter.generateUpdateSQL(t, 'x', 'nope', 1, {}),
        same(SQL.dummy),
      );
      expect(
        () async => await adapter.generateInsertRelationshipSQLs(
          t,
          'x',
          'nope',
          'tags',
          1,
          'tag',
          [1],
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateInsertRelationshipSQLs(
          t,
          'item',
          'item',
          'tags',
          1,
          'owner',
          [1],
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateSelectRelationshipSQL(
          t,
          'x',
          'nope',
          'tags',
          1,
          'tag',
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateSelectRelationshipSQL(
          t,
          'item',
          'item',
          'tags',
          1,
          'owner',
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateSelectRelationshipsSQL(
          t,
          'x',
          'nope',
          'tags',
          [1],
          'tag',
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateSelectRelationshipsSQL(
          t,
          'item',
          'item',
          'tags',
          [1],
          'owner',
        ),
        throwsStateError,
      );
      expect(
        () async => await adapter.generateSelectSQL(
          t,
          'item',
          'item',
          const ConditionQuery('id == 1'),
        ),
        throwsStateError,
      );
    });

    test('valueToSQL', () {
      expect(adapter.valueToSQL(null), isNull);
      expect(adapter.valueToSQL(Time(1, 2, 3)), equals('01:02:03'));
      expect(
        adapter.valueToSQL(DateTime.utc(2020).toLocal()),
        equals(DateTime.utc(2020)),
      );
      expect(adapter.valueToSQL(Decimal.parse('1.5')), equals('1.5'));
      expect(adapter.valueToSQL(DynamicInt.fromInt(3)), equals('3'));
      expect(adapter.valueToSQL(RoleType.guest), equals('guest'));
      expect(adapter.valueToSQL('x'), equals('x'));
    });

    test('fieldValueToSQL', () async {
      var scheme = (await adapter.getTableScheme('item'))!;
      var context = EncodingContext('item');
      var ownerHandler = provider.ownerRepository.entityHandler;

      Future<Object?> value(Object? v) async {
        var values = <String, Object?>{};
        var placeholder = await adapter.fieldValueToSQL(
          context,
          scheme,
          'owner',
          v,
          values,
        );
        expect(placeholder, equals('@owner'));
        return values['owner'];
      }

      expect(await value(null), isNull);
      expect(
        await value(
          EntityReference<_Owner>.asNull(entityHandler: ownerHandler),
        ),
        isNull,
      );
      expect(
        await value(
          EntityReference<_Owner>.fromID(123, entityHandler: ownerHandler),
        ),
        equals(123),
      );
      expect(
        await value(
          EntityReference<_Owner>.fromEntity(
            _Owner(id: 77, name: 'x'),
            entityHandler: ownerHandler,
          ),
        ),
        equals(77),
      );

      // Not stored yet: stored.
      var owner = _Owner(name: 'new owner');
      var id = await value(owner);
      expect(id, isA<int>());
      expect(owner.id, equals(id));

      // An entity without a repository here: its ID.
      expect(await value(Role(RoleType.guest, id: 5)), equals(5));
      // Not an entity: as a SQL value.
      expect(await value(RoleType.admin), equals('admin'));
    });

    test('getRepositoryAdapter*', () {
      expect(adapter.getRepositoryAdapterByName('item'), isNotNull);
      expect(adapter.getRepositoryAdapterByType(_Item), isNotNull);
      expect(adapter.getRepositoryAdapterByTableName('item'), isNotNull);
      expect(adapter.getRepositoryAdapterByName('nope'), isNull);
    });
  });

  group('checkTables', () {
    test('missing columns', () async {
      var provider = _Provider(generateTables: false, checkTables: false);
      addTearDown(provider.dispose);
      await provider.ensureInitialized();

      var adapter = provider.adapter;
      adapter.executeRawSQL(
        'CREATE TABLE owner (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)',
      );
      adapter.executeRawSQL(
        'CREATE TABLE tag (id INTEGER PRIMARY KEY AUTOINCREMENT, label VARCHAR)',
      );
      adapter.executeRawSQL(
        'CREATE TABLE item (id INTEGER PRIMARY KEY AUTOINCREMENT, title VARCHAR)',
      );

      var error = (await _checkError(adapter))!;
      expect(adapter.checkedTables, isFalse);

      expect(
        error,
        contains(
          "Can't find all `_Item` fields in table `item` scheme:\n"
          '  -- repository: DBSQLEntityRepository<_Item>[item]',
        ),
      );
      expect(
        error,
        contains('  -- missingColumns: [String code , RoleType kind]'),
      );
      expect(error, contains('  -- missingReferenceColumns: [_Owner owner]'));
      // Only the collection (`List`) reference fields:
      expect(
        error,
        contains('  -- missingCollectionReferenceColumns: [List<_Tag> tags]'),
      );
      // `code` (unique) is a missing column: its unique constraint comes with
      // its `ADD COLUMN` (not also a missing unique constraint).
      expect(error, isNot(contains('missingUniqueConstraints')));

      // SQLite (no `ALTER TABLE ... ADD CONSTRAINT`, nor `ADD COLUMN IF NOT
      // EXISTS`): the foreign key in the column (`REFERENCES`), a unique
      // index for `UNIQUE` (once: with the `ADD COLUMN`).
      const suggestionTitle =
          'Suggestion of SQLs (`SQLite`) to fix missing columns in tables:\n\n';
      expect(
        error,
        contains(
          '$suggestionTitle'
          '  ALTER TABLE "item"  ADD COLUMN "code" VARCHAR(20) ;\n'
          '  CREATE UNIQUE INDEX IF NOT EXISTS "item__code__unique" '
          'ON "item" ("code") ;\n'
          '  ALTER TABLE "item"  ADD COLUMN "kind" VARCHAR '
          "CHECK( \"kind\" IN ('admin','guest','unknown') ) ;\n"
          '  \n'
          '  ALTER TABLE "item"  ADD COLUMN "owner" BIGINT '
          'REFERENCES "owner"("id") ;\n'
          '  CREATE INDEX IF NOT EXISTS "item__owner__idx" ON "item" ("owner") ;\n'
          '  \n',
        ),
      );
      expect(error, isNot(contains('ADD CONSTRAINT')));
      expect(error, isNot(contains('ADD COLUMN IF NOT EXISTS')));
      expect(
        'CREATE UNIQUE INDEX IF NOT EXISTS "item__code__unique"'
            .allMatches(error)
            .length,
        equals(1),
      );

      // Fixing the item table with the suggested SQLs (valid in SQLite), and
      // creating the relationship table: OK.
      var suggestedSQLs = error
          .substring(error.indexOf(suggestionTitle) + suggestionTitle.length)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(suggestedSQLs, hasLength(5));

      for (var sql in suggestedSQLs) {
        adapter.executeRawSQL(sql);
      }

      adapter.executeRawSQL(
        'CREATE TABLE item__tags__rel ('
        'item_id BIGINT NOT NULL REFERENCES item(id), '
        'tag_id BIGINT NOT NULL REFERENCES tag(id), '
        'PRIMARY KEY (item_id, tag_id))',
      );

      expect(await _checkError(adapter), isNull);
      expect(adapter.checkedTables, isTrue);
    });

    test('generateTables: existing table missing indexed columns', () async {
      var provider = _Provider(generateTables: true, checkTables: true);
      addTearDown(provider.dispose);

      // A table created before the columns were added to the entity: its
      // generated `CREATE INDEX`es (`owner`, `code`) can't be created.
      provider.adapter.executeRawSQL(
        'CREATE TABLE item (id INTEGER PRIMARY KEY AUTOINCREMENT, title VARCHAR)',
      );

      // Not a failed `CREATE INDEX` of `generateTables`: reported by
      // `checkTables`, with the SQLs to fix it.
      await provider.ensureInitialized();
      await provider.adapter.ensureInitialized();

      expect(provider.adapter.generatedTables, isTrue);
      expect(provider.adapter.checkedTables, isFalse);

      var message = (await _checkError(provider.adapter))!;
      expect(
        message,
        contains('  -- missingColumns: [String code , RoleType kind]'),
      );
      expect(
        message,
        contains(
          'CREATE INDEX IF NOT EXISTS "item__owner__idx" ON "item" ("owner") ;',
        ),
      );
    });

    test('no table', () async {
      var provider = _Provider(generateTables: false, checkTables: false);
      addTearDown(provider.dispose);
      await provider.ensureInitialized();

      // A missing table: reported by the check (not a `TypeError`).
      var error = await _checkError(provider.adapter);
      expect(error, contains('No scheme for repository `item` (`_Item`)'));
      expect(provider.adapter.checkedTables, isFalse);
    });

    test('invalid column type', () async {
      var provider = _Provider(generateTables: false, checkTables: false);
      addTearDown(provider.dispose);
      await provider.ensureInitialized();

      var adapter = provider.adapter;
      adapter.executeRawSQL(
        'CREATE TABLE owner (id INTEGER PRIMARY KEY AUTOINCREMENT, name INTEGER)',
      );
      adapter.executeRawSQL(
        'CREATE TABLE tag (id INTEGER PRIMARY KEY AUTOINCREMENT, label VARCHAR)',
      );
      adapter.executeRawSQL(
        'CREATE TABLE item (id INTEGER PRIMARY KEY AUTOINCREMENT, title VARCHAR)',
      );

      expect(
        () async => await adapter.checkDBTables(force: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid scheme field(`name`) type'),
          ),
        ),
      );
    });
  });
}
