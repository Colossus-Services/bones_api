@Tags(['entities'])
// ignore_for_file: discarded_futures
import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A dedicated (non-singleton) provider with a single `role` table, so the
/// ordering/pagination assertions below can't be disturbed by the entities
/// stored by the other test files.
class _SelectTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  late final DBSQLEntityRepository<Role> roleRepository;

  _SelectTestProvider() {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this)
      ..addTableSchemes([
        TableScheme(
          'role',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'type': String,
            'enabled': bool,
            'value': Decimal,
          },
        ),
      ]);

    roleRepository = DBSQLEntityRepository<Role>(
      sqlAdapter,
      'role',
      roleEntityHandler,
    )..ensureInitialized();
  }
}

void main() {
  group('generateSelectSQL[memory]', () {
    late final _SelectTestProvider provider;
    late final DBSQLMemoryAdapter sqlAdapter;

    setUpAll(() async {
      roleEntityHandler.ensureRegistered();
      provider = _SelectTestProvider();
      await provider.ensureInitialized();
      sqlAdapter = provider.sqlAdapter;
    });

    tearDownAll(() => provider.close());

    FutureOr<SQL> selectSQL({
      int? limit,
      int? offset,
      bool? orderByID,
      OrderDirection? orderDirection,
    }) => sqlAdapter.generateSelectSQL(
      Transaction(),
      'Role',
      'role',
      ConditionANY(),
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    );

    // The `generic` dialect of `DBSQLMemoryAdapter` has an empty element quote:
    const from = 'SELECT ro.* FROM role as ro';

    test('baseline: no ordering and no pagination (unchanged SQL)', () async {
      var sql = await selectSQL();
      expect(sql.sql, equals(from));
      expect(sql.offset, isNull);
      expect(sql.orderByID, isNull);
      expect(sql.orderDirection, isNull);
    });

    test('limit only (unchanged SQL)', () async {
      expect((await selectSQL(limit: 2)).sql, equals('$from LIMIT 2'));
    });

    test('limit of 0 emits no clause', () async {
      expect((await selectSQL(limit: 0)).sql, equals(from));
    });

    test('orderByID resolves the table ID column', () async {
      expect(
        (await selectSQL(orderByID: true)).sql,
        equals('$from ORDER BY ro.id ASC'),
      );
    });

    test('orderDirection', () async {
      expect(
        (await selectSQL(
          orderByID: true,
          orderDirection: OrderDirection.ascending,
        )).sql,
        equals('$from ORDER BY ro.id ASC'),
      );

      expect(
        (await selectSQL(
          orderByID: true,
          orderDirection: OrderDirection.descending,
        )).sql,
        equals('$from ORDER BY ro.id DESC'),
      );
    });

    test('orderDirection alone is ignored', () async {
      expect(
        (await selectSQL(orderDirection: OrderDirection.descending)).sql,
        equals(from),
      );
    });

    test('offset implies the ordering', () async {
      expect(
        (await selectSQL(offset: 3)).sql,
        equals('$from ORDER BY ro.id ASC OFFSET 3'),
      );

      expect(
        (await selectSQL(limit: 2, offset: 3)).sql,
        equals('$from ORDER BY ro.id ASC LIMIT 2 OFFSET 3'),
      );

      expect(
        (await selectSQL(
          limit: 2,
          offset: 3,
          orderDirection: OrderDirection.descending,
        )).sql,
        equals('$from ORDER BY ro.id DESC LIMIT 2 OFFSET 3'),
      );
    });

    test('orderByID: false opts out of the implied ordering', () async {
      expect(
        (await selectSQL(offset: 3, orderByID: false)).sql,
        equals('$from OFFSET 3'),
      );
    });

    test('the clauses are carried by the SQL and survive copy()', () async {
      var sql = await selectSQL(
        limit: 2,
        offset: 3,
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );

      expect(sql.limit, equals(2));
      expect(sql.offset, equals(3));
      expect(sql.orderByID, isTrue);
      expect(sql.orderDirection, equals(OrderDirection.descending));

      var copy = sql.copy();
      expect(copy.sql, equals(sql.sql));
      expect(copy.limit, equals(2));
      expect(copy.offset, equals(3));
      expect(copy.orderByID, isTrue);
      expect(copy.orderDirection, equals(OrderDirection.descending));
    });

    test('with a WHERE condition', () async {
      var sql = await sqlAdapter.generateSelectSQL(
        Transaction(),
        'Role',
        'role',
        ConditionParser().parse(' enabled == ? '),
        parameters: {'enabled': true},
        limit: 2,
        offset: 1,
      );

      expect(
        sql.sql,
        equals(
          'SELECT ro.* FROM role as ro WHERE ( ro.enabled = @enabled )'
          ' ORDER BY ro.id ASC LIMIT 2 OFFSET 1',
        ),
      );
    });

    test('generateSelectIDsSQL', () async {
      var sql = await sqlAdapter.generateSelectIDsSQL(
        Transaction(),
        'Role',
        'role',
        ConditionANY(),
        limit: 2,
        offset: 1,
        orderDirection: OrderDirection.descending,
      );

      expect(
        sql.sql,
        equals(
          'SELECT ro.id as id FROM role as ro'
          ' ORDER BY ro.id DESC LIMIT 2 OFFSET 1',
        ),
      );
    });
  });

  group('generateSelectSQL[dialects]', () {
    // `_generateSelectTailSQL` delegates the dialect-specific syntax to
    // `SQLDialect`, so the per-dialect shape is asserted through it. The
    // PostgreSQL and MySQL adapters can't be instantiated without a server.
    const postgres = SQLDialect('PostgreSQL', elementQuote: '"');
    const mysql = SQLDialect(
      'MySQL',
      elementQuote: '`',
      offsetRequiresLimit: true,
    );

    test('PostgreSQL', () {
      expect(
        postgres.orderBySQL('ro', 'id') +
            postgres.limitOffsetSQL(limit: 2, offset: 3),
        equals(' ORDER BY "ro"."id" ASC LIMIT 2 OFFSET 3'),
      );

      // PostgreSQL accepts a standalone `OFFSET`:
      expect(postgres.limitOffsetSQL(offset: 3), equals(' OFFSET 3'));
    });

    test('MySQL: an OFFSET requires a LIMIT', () {
      expect(
        mysql.orderBySQL('ro', 'id', direction: OrderDirection.descending) +
            mysql.limitOffsetSQL(limit: 2, offset: 3),
        equals(' ORDER BY `ro`.`id` DESC LIMIT 2 OFFSET 3'),
      );

      // MySQL can't parse a standalone `OFFSET`, so the maximum row count is
      // used as the `LIMIT`:
      expect(
        mysql.limitOffsetSQL(offset: 3),
        equals(' LIMIT 18446744073709551615 OFFSET 3'),
      );
    });
  });

  group('DBSQLEntityRepository[memory] ordering/pagination', () {
    late final _SelectTestProvider provider;
    late final DBSQLEntityRepository<Role> roleRepository;

    // The IDs of the 5 stored roles, in ascending order:
    late final List<int> ids;

    setUpAll(() async {
      roleEntityHandler.ensureRegistered();
      provider = _SelectTestProvider();
      await provider.ensureInitialized();
      roleRepository = provider.roleRepository;

      var stored = <int>[];
      for (var i = 1; i <= 5; ++i) {
        var role = Role(
          i.isEven ? RoleType.admin : RoleType.guest,
          enabled: i != 5,
          value: Decimal.parse('$i.00'),
        );
        stored.add((await roleRepository.store(role)) as int);
      }

      ids = stored;
      expect(ids.length, equals(5));
      // The assertions below rely on the IDs being ascending:
      expect(ids, orderedEquals([...ids]..sort()));
    });

    tearDownAll(() => provider.close());

    Future<List<Object?>> selectIDs({
      String? query,
      Object? parameters,
      int? limit,
      int? offset,
      bool? orderByID,
      OrderDirection? orderDirection,
    }) async {
      var sel = await roleRepository.selectByQuery(
        query ?? ' id >= ? ',
        parameters: parameters ?? [ids.first],
        limit: limit,
        offset: offset,
        orderByID: orderByID,
        orderDirection: orderDirection,
      );
      return sel.map((e) => e.id).toList();
    }

    test('baseline: all 5 roles', () async {
      expect(await selectIDs(), unorderedEquals(ids));
    });

    test('orderByID ascending/descending', () async {
      expect(await selectIDs(orderByID: true), equals(ids));

      expect(
        await selectIDs(
          orderByID: true,
          orderDirection: OrderDirection.descending,
        ),
        equals(ids.reversed.toList()),
      );
    });

    test('limit with the ordering', () async {
      expect(await selectIDs(orderByID: true, limit: 2), equals(ids.take(2)));

      expect(
        await selectIDs(
          orderByID: true,
          limit: 2,
          orderDirection: OrderDirection.descending,
        ),
        equals(ids.reversed.take(2)),
      );
    });

    test('offset implies the ordering', () async {
      expect(await selectIDs(offset: 2), equals(ids.skip(2)));
      expect(await selectIDs(offset: 2, limit: 2), equals(ids.skip(2).take(2)));
    });

    test('paging through reassembles the full set exactly once', () async {
      var pages = <List<Object?>>[];
      for (var offset = 0; offset < ids.length; offset += 2) {
        pages.add(await selectIDs(limit: 2, offset: offset));
      }

      expect(pages.map((p) => p.length), equals([2, 2, 1]));
      expect(pages.expand((p) => p).toList(), equals(ids));
    });

    test('descending pagination', () async {
      expect(
        await selectIDs(
          limit: 2,
          offset: 1,
          orderDirection: OrderDirection.descending,
        ),
        equals(ids.reversed.skip(1).take(2)),
      );
    });

    test('offset past the end returns empty', () async {
      expect(await selectIDs(offset: ids.length), isEmpty);
      expect(await selectIDs(offset: 100), isEmpty);
    });

    test('orderDirection alone does not order', () async {
      expect(
        await selectIDs(orderDirection: OrderDirection.descending),
        unorderedEquals(ids),
      );
    });

    test('ordering and pagination with a WHERE condition', () async {
      // Roles 1..4 are enabled; role 5 is not:
      var enabled = await selectIDs(
        query: ' enabled == ? ',
        parameters: [true],
        orderByID: true,
      );
      expect(enabled, equals(ids.take(4)));

      expect(
        await selectIDs(
          query: ' enabled == ? ',
          parameters: [true],
          limit: 2,
          offset: 1,
        ),
        equals(ids.take(4).skip(1).take(2)),
      );
    });

    test('selectIDsByQuery', () async {
      var sel = await roleRepository.selectIDsByQuery<int>(
        ' id >= ? ',
        parameters: [ids.first],
        limit: 2,
        offset: 2,
      );
      expect(sel.toList(), equals(ids.skip(2).take(2)));
    });

    test('selectFirstByQuery', () async {
      var first = await roleRepository.selectFirstByQuery(
        ' id >= ? ',
        parameters: [ids.first],
        orderByID: true,
      );
      expect(first?.id, equals(ids.first));

      var last = await roleRepository.selectFirstByQuery(
        ' id >= ? ',
        parameters: [ids.first],
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );
      expect(last?.id, equals(ids.last));

      // `offset` implies the ordering, so this is the 2nd role:
      var second = await roleRepository.selectFirstByQuery(
        ' id >= ? ',
        parameters: [ids.first],
        offset: 1,
      );
      expect(second?.id, equals(ids[1]));
    });

    test('selectAll', () async {
      var all = await roleRepository.selectAll(orderByID: true);
      expect(all.map((e) => e.id).toList(), equals(ids));

      var page = await roleRepository.selectAll(limit: 2, offset: 2);
      expect(page.map((e) => e.id).toList(), equals(ids.skip(2).take(2)));

      var desc = await roleRepository.selectAll(
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );
      expect(desc.map((e) => e.id).toList(), equals(ids.reversed.toList()));
    });

    test('select with an EntityMatcher', () async {
      var sel = await roleRepository.select(
        ConditionANY(),
        limit: 2,
        offset: 1,
      );
      expect(sel.map((e) => e.id).toList(), equals(ids.skip(1).take(2)));
    });

    test('count is not affected by the ordering', () async {
      expect(await roleRepository.length(), equals(ids.length));
      expect(
        await roleRepository.countByQuery(' enabled == ? ', parameters: [true]),
        equals(4),
      );
    });
  });
}
