@TestOn('vm')
library;

import 'dart:convert';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A provider with a [DBSQLMemoryAdapter] (a [SQLGenerator]) and the
/// `Address` repository (with its `@EntityIndex`es).
class _IndexTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  _IndexTestProvider(EntityHandler<Address> addressHandler) {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this);
    DBSQLEntityRepository<Address>(sqlAdapter, 'address', addressHandler);

    // Closed at the test's end: the open providers are all known to each
    // other (global provider), and a lookup of a type none has (e.g. the
    // `Address.stores` `Store`) traverses them, slower with each one.
    addTearDown(() {
      sqlAdapter.close();
      close();
    });
  }
}

/// A provider with a [DBSQLMemoryAdapter] and the `Role` repository (no
/// relationships: storable alone).
class _RoleTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  _RoleTestProvider(EntityHandler<Role> roleHandler) {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this);
    DBSQLEntityRepository<Role>(sqlAdapter, 'role', roleHandler);

    addTearDown(() {
      sqlAdapter.close();
      close();
    });
  }
}

/// An entity with a hidden field (`secret`), for [GenericEntityHandler].
class _SecretEntity extends Entity {
  int? id;
  String name;
  String secret;

  _SecretEntity({this.id, this.name = '', this.secret = ''});

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const ['id', 'name', 'secret'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    'secret' => secret as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' || 'secret' => TypeInfo.tString,
    _ => null,
  };

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      key == 'secret' ? const [EntityField.hidden()] : null;

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'name':
        name = value as String;
      case 'secret':
        secret = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'secret': secret};
}

const _addressIndexes = [
  EntityIndex(['state', 'city']),
  EntityIndex(['city', 'number'], name: 'address_city_number_custom_idx'),
  EntityIndex(['state']),
  EntityIndex(['city']),
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

const _sqlite = SQLDialect(
  'SQLite',
  elementQuote: '"',
  alterTableAddConstraint: false,
);

/// A [DBSQLMemoryAdapter] generating the SQL of another [SQLDialect].
class _DialectMemoryAdapter extends DBSQLMemoryAdapter {
  final SQLDialect _dialect;

  _DialectMemoryAdapter(this._dialect) {
    addTearDown(close);
  }

  @override
  SQLDialect get dialect => _dialect;
}

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

    test('defaultName: maxLength (dialect identifier limit)', () {
      const table = 'establishment_order_closing';
      const columns = ['establishment', 'creation_date', 'payment_method'];
      const full =
          'establishment_order_closing__establishment_creation_date_'
          'payment_method__idx';
      expect(full.length, greaterThan(64));

      // No limit, or within it: unchanged.
      expect(EntityIndex.defaultName(table, columns), full);
      expect(
        EntityIndex.defaultName('t', ['a', 'b'], maxLength: 63),
        't__a_b__idx',
      );
      expect(
        EntityIndex.defaultName(table, columns, maxLength: full.length),
        full,
      );

      for (var maxLength in [63, 64, 30]) {
        var name = EntityIndex.defaultName(
          table,
          columns,
          maxLength: maxLength,
        );
        expect(name.length, maxLength, reason: name);
        // The full name's start (the table, if it fits):
        expect(full, startsWith(name.substring(0, maxLength - 14)));
        if (maxLength > 50) {
          expect(name, startsWith('establishment_order_closing__'));
        }
        expect(name, matches(RegExp(r'_[0-9a-f]{8}__idx$')));

        // Stable:
        expect(
          EntityIndex.defaultName(table, columns, maxLength: maxLength),
          name,
        );
      }

      // The same prefix, other columns: other names (the hash).
      var name1 = EntityIndex.defaultName(table, [
        ...columns,
        'a',
      ], maxLength: 63);
      var name2 = EntityIndex.defaultName(table, [
        ...columns,
        'b',
      ], maxLength: 63);
      expect(name1, isNot(name2));
      expect(
        name1.substring(0, 50),
        name2.substring(0, 50),
        reason: 'only the hash differs',
      );

      // Multi-byte characters: limited in bytes.
      var nameUtf8 = EntityIndex.defaultName('tábua_${'é' * 40}', [
        'a',
      ], maxLength: 63);
      expect(utf8.encode(nameUtf8).length, lessThanOrEqualTo(63));
    });

    test('indexName: maxLength', () {
      const named = EntityIndex(['a'], name: 'my_idx');
      expect(named.indexName('t', ['a'], maxLength: 6), 'my_idx');

      // A too long explicit name: an error (not silently truncated).
      expect(
        () => named.indexName('t', ['a'], maxLength: 5),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('longer than 5 bytes'),
          ),
        ),
      );

      // The default name: shortened.
      const unnamed = EntityIndex(['a']);
      expect(
        unnamed.indexName('t' * 80, ['a'], maxLength: 63).length,
        lessThanOrEqualTo(63),
      );
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
      expect(
        const EntityIndex(['a', 'b']),
        isNot(equals(const EntityIndex(['a', 'b'], unique: true))),
      );
      expect(
        const EntityIndex(['a', 'b'], unique: true),
        equals(EntityIndex(['a', 'b'], unique: true)),
      );
    });

    test('unique: default name, toString', () {
      const index = EntityIndex(['establishment', 'day'], unique: true);
      expect(index.unique, isTrue);
      expect(const EntityIndex(['a']).unique, isFalse);

      // As the single-field unique constraints (`<table>__<column>__unique`):
      expect(
        index.indexName('sales_day', ['establishment', 'day']),
        'sales_day__establishment_day__unique',
      );
      expect(
        EntityIndex.defaultName('t', ['a', 'b'], unique: true),
        't__a_b__unique',
      );

      const named = EntityIndex(['a', 'b'], unique: true, name: 'my_unique');
      expect(named.indexName('t', ['a', 'b']), 'my_unique');

      // Shortened: still `__unique`.
      var long = EntityIndex.defaultName(
        't' * 80,
        ['a', 'b'],
        maxLength: 63,
        unique: true,
      );
      expect(long.length, 63);
      expect(long, matches(RegExp(r'_[0-9a-f]{8}__unique$')));
      expect(
        long,
        isNot(EntityIndex.defaultName('t' * 80, ['a', 'b'], maxLength: 63)),
      );

      expect(index.toString(), 'EntityIndex(establishment, day ; unique)');
      expect(named.toString(), 'EntityIndex(a, b ; unique ; name: my_unique)');
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

    test('unique', () {
      var sql = CreateIndexSQL.columns(
        _postgres,
        'sales_day',
        ['establishment', 'day'],
        'sales_day__establishment_day__unique',
        unique: true,
      );
      expect(sql.unique, isTrue);
      expect(
        sql.buildSQL(),
        'CREATE UNIQUE INDEX IF NOT EXISTS "sales_day__establishment_day__unique" '
        'ON "sales_day" ("establishment", "day") ;',
      );

      var mysql = CreateIndexSQL.columns(
        _mysql,
        'sales_day',
        ['establishment', 'day'],
        'sales_day__establishment_day__unique',
        q: '`',
        unique: true,
      );
      expect(
        mysql.buildSQL(),
        'CREATE UNIQUE INDEX `sales_day__establishment_day__unique` '
        'ON `sales_day` (`establishment`, `day`) ;',
      );

      // Default: not unique.
      expect(CreateIndexSQL(_postgres, 't', 'a', 'i').unique, isFalse);
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

    test('single-field (A, B) and composite (A+B) indexes', () {
      var scheme = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {
          'id': int,
          'state': String,
          'city': String,
          'number': int,
        },
        indexes: {
          'address__state__idx': ['state'],
          'address__city__idx': ['city'],
          'address__state_city__idx': ['state', 'city'],
        },
      );

      // Each one is its own index:
      expect(scheme.hasIndexOn(['state']), isTrue);
      expect(scheme.hasIndexOn(['city']), isTrue);
      expect(scheme.hasIndexOn(['state', 'city']), isTrue);

      // Not covered by the others (order, prefix or a composite of the
      // single ones):
      expect(scheme.hasIndexOn(['city', 'state']), isFalse);
      expect(scheme.hasIndexOn(['number']), isFalse);
      expect(scheme.hasIndexOn(['state', 'city', 'number']), isFalse);

      // Only the composite: the single-field ones (even its prefix) missing.
      var compositeOnly = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'state': String, 'city': String},
        indexes: {
          'address__state_city__idx': ['state', 'city'],
        },
      );
      expect(compositeOnly.hasIndexOn(['state', 'city']), isTrue);
      expect(compositeOnly.hasIndexOn(['state']), isFalse);
      expect(compositeOnly.hasIndexOn(['city']), isFalse);

      // Only the single-field ones: the composite missing.
      var singleOnly = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'state': String, 'city': String},
        indexes: {
          'a': ['state'],
          'b': ['city'],
        },
      );
      expect(singleOnly.hasIndexOn(['state']), isTrue);
      expect(singleOnly.hasIndexOn(['city']), isTrue);
      expect(singleOnly.hasIndexOn(['state', 'city']), isFalse);

      // Unmodifiable:
      expect(() => scheme.indexes!['x'] = ['id'], throwsUnsupportedError);
      expect(
        () => scheme.indexes!['address__state__idx']!.add('x'),
        throwsUnsupportedError,
      );
    });

    test('unique', () {
      var scheme = TableScheme(
        'sales_day',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'establishment': int, 'day': String},
        indexes: {
          'sales_day_pkey': ['id'],
          'sales_day__establishment_day__unique': ['establishment', 'day'],
          'sales_day__day__idx': ['day'],
        },
        uniqueIndexes: [
          'sales_day_pkey',
          'sales_day__establishment_day__unique',
        ],
      );

      expect(scheme.hasIndexOn(['establishment', 'day'], unique: true), isTrue);
      // A unique index is an index too:
      expect(scheme.hasIndexOn(['establishment', 'day']), isTrue);
      expect(scheme.hasIndexOn(['id'], unique: true), isTrue);

      // Not unique, or other columns/order:
      expect(scheme.hasIndexOn(['day']), isTrue);
      expect(scheme.hasIndexOn(['day'], unique: true), isFalse);
      expect(
        scheme.hasIndexOn(['day', 'establishment'], unique: true),
        isFalse,
      );
      expect(scheme.hasIndexOn(['establishment'], unique: true), isFalse);

      // Case insensitive columns (as the non-unique):
      expect(scheme.hasIndexOn(['ESTABLISHMENT', 'Day'], unique: true), isTrue);

      // A unique name without columns (e.g. an ignored index): no index.
      var orphanUnique = TableScheme(
        'sales_day',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'day': String},
        indexes: {
          'x': ['day'],
        },
        uniqueIndexes: ['ignored_expression_idx'],
      );
      expect(orphanUnique.hasIndexOn(['day'], unique: true), isFalse);
      expect(orphanUnique.hasIndexOn(['day']), isTrue);

      // Known, none unique:
      var noneUnique = TableScheme(
        'sales_day',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'day': String},
        indexes: {
          'x': ['day'],
        },
        uniqueIndexes: const [],
      );
      expect(noneUnique.hasIndexOn(['day'], unique: true), isFalse);

      // Unknown unique indexes: `null` (only when asked for a unique one).
      var noUnique = TableScheme(
        'sales_day',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'day': String},
        indexes: {
          'x': ['day'],
        },
      );
      expect(noUnique.uniqueIndexes, isNull);
      expect(noUnique.hasIndexOn(['day']), isTrue);
      expect(noUnique.hasIndexOn(['day'], unique: true), isNull);

      expect(() => scheme.uniqueIndexes!.add('x'), throwsUnsupportedError);
    });

    test('empty indexes (known): no index', () {
      var scheme = TableScheme(
        'address',
        idFieldName: 'id',
        fieldsTypes: {'id': int},
        indexes: {},
      );
      expect(scheme.indexes, isEmpty);
      expect(scheme.hasIndexOn(['id']), isFalse);
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
            'address__state__idx',
            'address__city__idx',
          ]);
          expect(indexes.map((e) => e.columns), [
            ['state', 'city'],
            ['city', 'number'],
            ['state'],
            ['city'],
          ]);

          var createTableSQL = adapter.generateCreateTableSQL(
            entityRepository: repository,
          );
          var sqls = createTableSQL.buildAllSQLs().join('\n');

          // Single-field indexes: `city` (`@EntityIndex`), and `state` only
          // once (also `@EntityField.indexed()`: the same name and column).
          var stateIndex =
              '${q}address__state__idx$q ON ${q}address$q (${q}state$q)';
          expect(stateIndex.allMatches(sqls).length, 1, reason: sqls);
          expect(
            sqls,
            contains('${q}address__city__idx$q ON ${q}address$q (${q}city$q)'),
          );
          expect(
            createTableSQL.indexes!.map((e) => e.indexName).toList(),
            containsAll([
              'address__state__idx',
              'address__city__idx',
              'address__state_city__idx',
              'address_city_number_custom_idx',
            ]),
          );
          expect(
            createTableSQL.indexes!
                .where((e) => e.columns.length == 1 && e.column == 'state')
                .length,
            1,
          );

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

    test('resolveEntityIndexColumns: column names (camelCase, references)', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;
      var userHandler = User$reflection().entityHandler;

      // camelCase -> snake_case; `EntityReference<UserInfo> userInfo` and
      // `Address address`: their reference column.
      expect(
        adapter.resolveEntityIndexColumns(
          userHandler,
          const EntityIndex(['userInfo', 'creationTime']),
        ),
        ['user_info', 'creation_time'],
      );
      expect(
        adapter.resolveEntityIndexColumns(
          userHandler,
          const EntityIndex(['address', 'email']),
        ),
        ['address', 'email'],
      );

      // `List<Role> roles`: a relationship.
      expect(
        () => adapter.resolveEntityIndexColumns(
          userHandler,
          const EntityIndex(['roles']),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Can't index a collection"),
          ),
        ),
      );

      // `User`'s unique `@EntityIndex`es (a reference column):
      var userIndexes = adapter.generateEntityIndexesSQLs(userHandler, 'user');
      expect(userIndexes.map((e) => e.indexName), [
        'user__email_address__unique',
        'user__email__unique',
      ]);
      expect(userIndexes.map((e) => e.columns), [
        ['email', 'address'],
        ['email'],
      ]);
      expect(userIndexes.every((e) => e.unique), isTrue);
    });

    test('resolveEntityIndexColumns: a hidden field', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;

      var handler = GenericEntityHandler<_SecretEntity>(
        instantiatorDefault: _SecretEntity.new,
        sampleEntity: _SecretEntity(),
        entityIndexes: const [
          EntityIndex(['name', 'secret']),
        ],
      );

      expect(
        adapter.resolveEntityIndexColumns(handler, const EntityIndex(['name'])),
        ['name'],
      );

      expect(
        () => adapter.generateEntityIndexesSQLs(handler, 'secret_entity'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("Can't index a hidden field"),
          ),
        ),
      );
    });

    test('generateEntityIndexesSQLs: per dialect', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;
      var handler = Address$reflection().entityHandler;

      var sqls = adapter
          .generateEntityIndexesSQLs(handler, 'address')
          .map((e) => e.buildSQL(ifNotExists: false))
          .toList();

      var q = adapter.dialect.elementQuote;
      var stateCity =
          'CREATE INDEX ${q}address__state_city__idx$q ON ${q}address$q '
          '(${q}state$q, ${q}city$q) ;';
      var cityNumber =
          'CREATE INDEX ${q}address_city_number_custom_idx$q ON ${q}address$q '
          '(${q}city$q, ${q}number$q) ;';
      var state =
          'CREATE INDEX ${q}address__state__idx$q ON ${q}address$q '
          '(${q}state$q) ;';
      var city =
          'CREATE INDEX ${q}address__city__idx$q ON ${q}address$q '
          '(${q}city$q) ;';
      expect(sqls, [stateCity, cityNumber, state, city]);

      // Other tables' indexes have the table in their default name:
      var other = adapter.generateEntityIndexesSQLs(handler, 'address_v2');
      expect(other.map((e) => e.indexName), [
        'address_v2__state_city__idx',
        'address_city_number_custom_idx',
        'address_v2__state__idx',
        'address_v2__city__idx',
      ]);
    });

    test('generateEntityIndexesSQLs: fieldColumn (an existing table)', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;

      var handler = GenericEntityHandler<User>(
        instantiatorDefault: User.empty,
        sampleEntity: User.empty(),
        entityIndexes: const [
          EntityIndex(['email', 'creationTime']),
        ],
      );

      // The generated columns:
      var generated = adapter.generateEntityIndexesSQLs(handler, 'user');
      expect(generated.single.columns, ['email', 'creation_time']);
      expect(generated.single.indexName, 'user__email_creation_time__idx');

      // A legacy column (`creationTime`): the table's column, the same
      // (generated) index name:
      var legacy = adapter.generateEntityIndexesSQLs(
        handler,
        'user',
        fieldColumn: (f) => f == 'creationTime' ? 'creationTime' : null,
      );
      expect(legacy.single.columns, ['email', 'creationTime']);
      expect(legacy.single.indexName, 'user__email_creation_time__idx');
    });

    test('generateCreateTableSQL: an index over the same columns', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // The same columns as `state` (`indexed`), another name:
            EntityIndex(['state'], name: 'address_state_other_idx'),
            // Twice the same columns:
            EntityIndex(['city', 'number']),
            EntityIndex(['city', 'number'], name: 'address_city_number2'),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var repository = provider.getEntityRepositoryByType(Address)!;

      var createTableSQL = adapter.generateCreateTableSQL(
        entityRepository: repository,
      );
      var indexesNames = createTableSQL.indexes!
          .map((e) => e.indexName)
          .toList();

      expect(indexesNames, contains('address__state__idx'));
      expect(indexesNames, contains('address__city_number__idx'));
      expect(indexesNames, isNot(contains('address_state_other_idx')));
      expect(indexesNames, isNot(contains('address_city_number2')));
    });

    test('generateCreateTableSQL: unique (a constraint)', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // Non-unique first: the unique one over the same columns serves
            // it (not created).
            EntityIndex(['state', 'city']),
            EntityIndex(['state', 'city'], unique: true),
            // Unique over `state` (`indexed`: a non-unique index): only the
            // constraint (its index serves as the non-unique one).
            EntityIndex(['state'], unique: true),
            // Named:
            EntityIndex(
              ['street', 'number'],
              unique: true,
              name: 'address_street_number_uq',
            ),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var q = adapter.dialect.elementQuote;
      var repository = provider.getEntityRepositoryByType(Address)!;

      var createTableSQL = adapter.generateCreateTableSQL(
        entityRepository: repository,
      );
      var sqls = createTableSQL.buildAllSQLs().join('\n');

      // In the `CREATE TABLE` (as `EntityField.unique`):
      expect(
        sqls,
        contains(
          'CONSTRAINT ${q}address__state_city__unique$q '
          'UNIQUE (${q}state$q, ${q}city$q)',
        ),
      );
      expect(
        sqls,
        contains(
          'CONSTRAINT ${q}address__state__unique$q UNIQUE (${q}state$q)',
        ),
      );
      expect(
        sqls,
        contains(
          'CONSTRAINT ${q}address_street_number_uq$q '
          'UNIQUE (${q}street$q, ${q}number$q)',
        ),
      );

      var createTable = createTableSQL.buildSQL();
      expect(createTable, contains('address__state_city__unique'));
      expect(createTable, contains('address_street_number_uq'));

      // Not `CREATE INDEX`es:
      var indexesNames = createTableSQL.indexes!
          .map((e) => e.indexName)
          .toList();
      expect(indexesNames, isNot(contains('address__state_city__unique')));
      expect(indexesNames, isNot(contains('address_street_number_uq')));
      expect(sqls, isNot(contains('UNIQUE INDEX')));

      // The non-unique `state, city`: served by the unique constraint.
      expect(indexesNames, isNot(contains('address__state_city__idx')));
      // `state` (`indexed`): its non-unique index dropped (redundant).
      expect(indexesNames, isNot(contains('address__state__idx')));
      expect(sqls, isNot(contains('${q}address__state__idx$q')));
    });

    test('generateCreateTableSQL: unique over an `indexed` field, renamed', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // The name of the dropped (redundant) `state` index: free.
            EntityIndex(['state'], unique: true, name: 'address__state__idx'),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var q = adapter.dialect.elementQuote;
      var repository = provider.getEntityRepositoryByType(Address)!;

      var createTableSQL = adapter.generateCreateTableSQL(
        entityRepository: repository,
      );

      expect(
        createTableSQL.buildSQL(),
        contains('CONSTRAINT ${q}address__state__idx$q UNIQUE (${q}state$q)'),
      );
      expect(
        createTableSQL.indexes!.map((e) => e.indexName),
        isNot(contains('address__state__idx')),
      );
    });

    test('generateAddUniqueConstraintSQL: per dialect', () {
      for (var (dialect, expected) in [
        (
          _postgres,
          'ALTER TABLE "sales_day" ADD CONSTRAINT '
              '"sales_day__establishment_day__unique" '
              'UNIQUE ("establishment", "day")',
        ),
        (
          _mysql,
          'ALTER TABLE `sales_day` ADD CONSTRAINT '
              '`sales_day__establishment_day__unique` '
              'UNIQUE (`establishment`, `day`)',
        ),
        (
          // SQLite can't add a constraint: a unique index.
          _sqlite,
          'CREATE UNIQUE INDEX IF NOT EXISTS '
              '"sales_day__establishment_day__unique" '
              'ON "sales_day" ("establishment", "day")',
        ),
      ]) {
        var adapter = _DialectMemoryAdapter(dialect);
        var sql = adapter.generateAddUniqueConstraintSQL(
          'sales_day',
          'sales_day__establishment_day__unique',
          ['establishment', 'day'],
        );

        var sqlStr = sql
            .buildAllSQLs(multiline: false)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(sqlStr, contains(expected), reason: dialect.name);
      }
    });

    test(
      'generateAddUniqueConstraintAlterTableSQL: the `CREATE TABLE` name',
      () {
        var adapter = _DialectMemoryAdapter(_mysql);
        var sql = adapter
            .generateAddUniqueConstraintAlterTableSQL(
              'user',
              'email',
              TypeInfo.tString,
            )
            .buildSQL(multiline: false);
        expect(sql, contains('`user__email__unique`'));
        expect(sql, contains('ALTER TABLE `user`'));
      },
    );

    test('generateCreateTableSQL: unique, the same as a unique field', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;
      var userHandler = User$reflection().entityHandler;

      // `User.email` is `@EntityField.unique()`, and `@EntityIndex(['email'],
      // unique: true)`: one constraint (the same name and column).
      var indexes = adapter.generateEntityIndexesSQLs(userHandler, 'user');
      var emailUnique = indexes.firstWhere((e) => e.columns.length == 1);
      expect(emailUnique.indexName, 'user__email__unique');
      expect(emailUnique.unique, isTrue);
    });

    test('generateCreateTableSQL: unique, edge cases', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // Twice the same columns (other names): one constraint.
            EntityIndex(['city', 'number'], unique: true),
            EntityIndex(['city', 'number'], unique: true, name: 'addr_cn_2'),
            // The same columns in another order: another constraint.
            EntityIndex(['number', 'city'], unique: true),
            // Unique and non-unique over the same columns, the non-unique
            // first and named: only the unique one.
            EntityIndex(['street'], name: 'address_street_named_idx'),
            EntityIndex(['street'], unique: true),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var q = adapter.dialect.elementQuote;
      var repository = provider.getEntityRepositoryByType(Address)!;

      var createTableSQL = adapter.generateCreateTableSQL(
        entityRepository: repository,
      );
      var createTable = createTableSQL.buildSQL();
      var indexesNames = createTableSQL.indexes!
          .map((e) => e.indexName)
          .toList();

      expect(
        'UNIQUE (${q}city$q, ${q}number$q)'.allMatches(createTable).length,
        1,
        reason: createTable,
      );
      expect(createTable, contains('address__city_number__unique'));
      expect(createTable, isNot(contains('addr_cn_2')));

      expect(
        createTable,
        contains(
          'CONSTRAINT ${q}address__number_city__unique$q '
          'UNIQUE (${q}number$q, ${q}city$q)',
        ),
      );

      expect(
        createTable,
        contains(
          'CONSTRAINT ${q}address__street__unique$q UNIQUE (${q}street$q)',
        ),
      );
      expect(indexesNames, isNot(contains('address_street_named_idx')));
    });

    test('generateEntityIndexesSQLs: unique over a reference column', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;

      var handler = GenericEntityHandler<User>(
        instantiatorDefault: User.empty,
        sampleEntity: User.empty(),
        entityIndexes: const [
          EntityIndex(['address', 'creationTime'], unique: true),
        ],
      );

      var sql = adapter.generateEntityIndexesSQLs(handler, 'user').single;
      expect(sql.unique, isTrue);
      expect(sql.columns, ['address', 'creation_time']);
      expect(sql.indexName, 'user__address_creation_time__unique');

      // An existing table's (legacy) column: the same name.
      var legacy = adapter
          .generateEntityIndexesSQLs(
            handler,
            'user',
            fieldColumn: (f) => f == 'creationTime' ? 'creationTime' : null,
          )
          .single;
      expect(legacy.columns, ['address', 'creationTime']);
      expect(legacy.indexName, 'user__address_creation_time__unique');
      expect(legacy.unique, isTrue);
    });

    test('generateCreateTableSQL: unique, a name in use', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // The name of the `state` index (`indexed`):
            EntityIndex(['city'], unique: true, name: 'address__state__idx'),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var repository = provider.getEntityRepositoryByType(Address)!;

      expect(
        () => adapter.generateCreateTableSQL(entityRepository: repository),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('`address__state__idx` (city)'),
          ),
        ),
      );
    });

    test('generateCreateTableSQL: a name in use (other columns)', () {
      var provider = _IndexTestProvider(
        GenericEntityHandler<Address>(
          instantiatorDefault: Address.empty,
          sampleEntity: Address.empty(),
          entityIndexes: const [
            // The name of the `state` index (`indexed`), over `city`:
            EntityIndex(['city'], name: 'address__state__idx'),
          ],
        ),
      );
      var adapter = provider.sqlAdapter;
      var repository = provider.getEntityRepositoryByType(Address)!;

      expect(
        () => adapter.generateCreateTableSQL(entityRepository: repository),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('`address__state__idx` (city)'),
              contains('already in use'),
              contains('(state)'),
            ),
          ),
        ),
      );
    });
  });

  group('unique violations', () {
    test('DBSQLMemoryAdapter: a composite unique `@EntityIndex`', () async {
      var provider = _RoleTestProvider(
        GenericEntityHandler<Role>(
          instantiatorDefault: Role.empty,
          instantiatorFromMap: Role.fromMap,
          sampleEntity: Role.empty(),
          entityIndexes: const [
            EntityIndex(['type', 'enabled'], unique: true),
          ],
        ),
      );
      var repository = provider.getEntityRepositoryByType<Role>(Role)!;

      var r1 = Role(RoleType.admin, enabled: true);
      expect(await repository.store(r1), isNotNull);

      // Another `enabled`: OK.
      var r2 = Role(RoleType.admin, enabled: false);
      expect(await repository.store(r2), isNotNull);

      // Another `type`, the same `enabled`: OK.
      var r3 = Role(RoleType.guest, enabled: true);
      expect(await repository.store(r3), isNotNull);

      // The same (`type`, `enabled`): a violation of both fields.
      var dup = Role(RoleType.admin, enabled: true, value: Decimal.parse('2'));
      EntityFieldInvalid? error;
      try {
        await repository.store(dup);
      } on EntityFieldInvalid catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(error!.reason, 'unique');
      expect(error.fieldName, 'type, enabled');
      expect(error.fieldsNames, ['type', 'enabled']);
      expect(error.value, isA<List>().having((l) => l.length, 'length', 2));
      expect(error.tableName, 'role');
      expect(
        error.toString(),
        contains('field(type, enabled)> reason: unique'),
      );

      // Updating itself (the same `type`, `enabled`): OK.
      r1.value = Decimal.parse('1.5');
      expect(await repository.store(r1), r1.id);

      // Updating into the other's values: a violation.
      r2.enabled = true;
      EntityFieldInvalid? error2;
      try {
        await repository.store(r2);
      } on EntityFieldInvalid catch (e) {
        error2 = e;
      }
      expect(error2?.fieldsNames, ['type', 'enabled']);

      expect(
        (await repository.selectAll()).map(
          (e) => '${e.type.name}/${e.enabled}',
        ),
        unorderedEquals(['admin/true', 'admin/false', 'guest/true']),
      );
    });

    test('SQLite: the columns of a composite constraint message', () {
      var (table, columns) = DBSQLiteAdapter.parseConstraintTableFields(
        'UNIQUE constraint failed: sales_day.establishment, sales_day.day',
      );
      expect(table, 'sales_day');
      expect(columns, ['establishment', 'day']);

      var (table2, columns2) = DBSQLiteAdapter.parseConstraintTableFields(
        'UNIQUE constraint failed: user.email',
      );
      expect(table2, 'user');
      expect(columns2, ['email']);

      var (table3, columns3) = DBSQLiteAdapter.parseConstraintTableFields(
        'something else',
      );
      expect(table3, isNull);
      expect(columns3, isNull);
    });

    test('PostgreSQL: the columns of a unique violation detail', () {
      expect(
        DBPostgreSQLAdapter.parseUniqueViolationColumns(
          'Key (establishment, day)=(1, 2024-01-01) already exists.',
        ),
        ['establishment', 'day'],
      );
      expect(
        DBPostgreSQLAdapter.parseUniqueViolationColumns(
          'Key (email)=(joe@mail.com) already exists.',
        ),
        ['email'],
      );
      expect(
        DBPostgreSQLAdapter.parseUniqueViolationColumns(
          'Key ("creationDate", day)=(x, y) already exists.',
        ),
        ['creationDate', 'day'],
      );
      expect(DBPostgreSQLAdapter.parseUniqueViolationColumns(null), isNull);
      expect(DBPostgreSQLAdapter.parseUniqueViolationColumns('other'), isNull);
    });

    test('loadedIndexColumns: unknown', () {
      var provider = _IndexTestProvider(Address$reflection().entityHandler);
      var adapter = provider.sqlAdapter;
      expect(adapter.loadedIndexColumns(null, 'x'), isNull);
      expect(adapter.loadedIndexColumns('address', null), isNull);
      // Not loaded / no indexes (memory):
      expect(adapter.loadedIndexColumns('address', 'x'), isNull);
    });

    test('EntityFieldInvalid.fieldsNames', () {
      var error = EntityFieldInvalid(
        'unique',
        [1, 'a'],
        fieldName: 'establishment, day',
        fieldsNames: ['establishment', 'day'],
        tableName: 'sales_day',
      );
      expect(error.fieldsNames, ['establishment', 'day']);
      expect(
        error.toString(),
        startsWith(
          'Invalid entity(@table:sales_day) field(establishment, day)> '
          'reason: unique',
        ),
      );

      var copy = error.copyWith(reason: 'other');
      expect(copy.fieldsNames, ['establishment', 'day']);
      expect(copy.reason, 'other');

      expect(EntityFieldInvalid('unique', 1).fieldsNames, isNull);
    });
  });
}
