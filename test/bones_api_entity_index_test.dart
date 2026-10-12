@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A provider with a [DBSQLMemoryAdapter] (a [SQLGenerator]) and the
/// `Address` repository (with its `@EntityIndex`es).
class _IndexTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  _IndexTestProvider(EntityHandler<Address> addressHandler) {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this);
    DBSQLEntityRepository<Address>(sqlAdapter, 'address', addressHandler);
  }
}

const _addressIndexes = [
  EntityIndex(['state', 'city']),
  EntityIndex(['city', 'number'], name: 'address_city_number_custom_idx'),
];

const _postgres = SQLDialect(
  'PostgreSQL',
  elementQuote: '"',
  acceptsReturningSyntax: true,
  acceptsInsertDefaultValues: true,
  acceptsInsertOnConflict: true,
  acceptsVarcharWithoutMaximumSize: true,
);

const _mysql = SQLDialect(
  'MySQL',
  elementQuote: '`',
  createIndexIfNotExists: false,
);

void main() {
  group('EntityIndex', () {
    test('defaultName / indexName', () {
      expect(
        EntityIndex.defaultName('order_closing', [
          'establishment',
          'creation_date',
        ]),
        'order_closing__establishment_creation_date__idx',
      );

      const index = EntityIndex(['a', 'b']);
      expect(index.indexName('t', ['a', 'b']), 't__a_b__idx');

      const named = EntityIndex(['a', 'b'], name: 'my_idx');
      expect(named.indexName('t', ['a', 'b']), 'my_idx');
    });

    test('equality', () {
      expect(const EntityIndex(['a', 'b']), equals(EntityIndex(['a', 'b'])));
      expect(
        const EntityIndex(['a', 'b']),
        isNot(equals(const EntityIndex(['b', 'a']))),
      );
      expect(
        const EntityIndex(['a']),
        isNot(equals(const EntityIndex(['a'], name: 'x'))),
      );
      expect(
        const EntityIndex(['a', 'b']).hashCode,
        EntityIndex(['a', 'b']).hashCode,
      );
    });
  });

  group('CreateIndexSQL', () {
    test('single column (unchanged)', () {
      var sql = CreateIndexSQL(
        _postgres,
        'address',
        'city',
        'address__city__idx',
      );
      expect(sql.columns, ['city']);
      expect(sql.isComposite, isFalse);
      expect(
        sql.buildSQL(),
        'CREATE INDEX IF NOT EXISTS "address__city__idx" ON "address" ("city") ;',
      );
    });

    test('columns: composite', () {
      var sql = CreateIndexSQL.columns(_postgres, 'order_closing', [
        'establishment',
        'creation_date',
      ], 'order_closing__establishment_creation_date__idx');
      expect(sql.column, 'establishment');
      expect(sql.isComposite, isTrue);
      expect(
        sql.buildSQL(),
        'CREATE INDEX IF NOT EXISTS "order_closing__establishment_creation_date__idx" '
        'ON "order_closing" ("establishment", "creation_date") ;',
      );

      var mysql = CreateIndexSQL.columns(
        _mysql,
        'address',
        ['state', 'city'],
        'address__state_city__idx',
        q: '`',
      );
      // MySQL: no `IF NOT EXISTS` for indexes.
      expect(
        mysql.buildSQL(),
        'CREATE INDEX `address__state_city__idx` ON `address` (`state`, `city`) ;',
      );
    });

    test('columns: empty', () {
      expect(
        () => CreateIndexSQL.columns(_postgres, 't', [], 'i'),
        throwsArgumentError,
      );
    });
  });

  group('TableScheme.hasIndexOn', () {
    test('by columns, in order, any name', () {
      var scheme = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'state': String, 'city': String},
        indexes: {
          'address_pkey': ['id'],
          'some_name': ['state', 'city'],
        },
      );
      expect(scheme.hasIndexOn(['state', 'city']), isTrue);
      expect(scheme.hasIndexOn(['STATE', 'City']), isTrue);
      expect(scheme.hasIndexOn(['city', 'state']), isFalse);
      expect(scheme.hasIndexOn(['state']), isFalse);
    });

    test('unknown indexes: null', () {
      var scheme = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {'id': int},
      );
      expect(scheme.indexes, isNull);
      expect(scheme.hasIndexOn(['id']), isNull);
    });
  });

  group('EntityHandler.getEntityIndexes', () {
    test('reflection: the class annotations', () {
      var handler = Address$reflection().entityHandler;
      expect(handler.getEntityIndexes(), _addressIndexes);
    });

    test('generic: the constructor parameter', () {
      expect(addressEntityHandler.getEntityIndexes(), _addressIndexes);
      expect(storeEntityHandler.getEntityIndexes(), isEmpty);
    });
  });

  group('SQLGenerator', () {
    for (var byReflection in [true, false]) {
      test(
        'generateCreateTableSQL: the indexes (reflection: $byReflection)',
        () async {
          var handler = byReflection
              ? Address$reflection().entityHandler
              : (addressEntityHandler..inspectObject(Address.empty()));

          var provider = _IndexTestProvider(handler);
          var adapter = provider.sqlAdapter;
          var q = adapter.dialect.elementQuote;

          var repository = provider.getEntityRepositoryByType(Address)!;

          var indexes = adapter.generateEntityIndexesSQLs(
            repository.entityHandler,
            'address',
          );
          expect(indexes.map((e) => e.indexName), [
            'address__state_city__idx',
            'address_city_number_custom_idx',
          ]);
          expect(indexes.map((e) => e.columns), [
            ['state', 'city'],
            ['city', 'number'],
          ]);

          var createTableSQL = adapter.generateCreateTableSQL(
            entityRepository: repository,
          );
          var sqls = createTableSQL.buildAllSQLs().join('\n');

          expect(
            sqls,
            contains(
              '${q}address__state_city__idx$q ON ${q}address$q '
              '(${q}state$q, ${q}city$q)',
            ),
          );
          expect(
            sqls,
            contains(
              '${q}address_city_number_custom_idx$q ON ${q}address$q '
              '(${q}city$q, ${q}number$q)',
            ),
          );
        },
      );
    }

    test('resolveEntityIndexColumns: invalid fields', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;
      var handler = Address$reflection().entityHandler;

      expect(
        adapter.resolveEntityIndexColumns(
          handler,
          const EntityIndex(['latitude', 'longitude']),
        ),
        ['latitude', 'longitude'],
      );

      // Unknown field:
      expect(
        () => adapter.resolveEntityIndexColumns(
          handler,
          const EntityIndex(['state', 'nope']),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown `EntityIndex` field `nope`'),
          ),
        ),
      );

      // A collection (relationship) field:
      expect(
        () => adapter.resolveEntityIndexColumns(
          handler,
          const EntityIndex(['stores']),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Can't index a collection"),
          ),
        ),
      );

      // Empty:
      expect(
        () => adapter.resolveEntityIndexColumns(handler, const EntityIndex([])),
        throwsArgumentError,
      );
    });
  });
}
