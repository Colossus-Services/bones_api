@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// `checkTables` of `@EntityIndex`es (and `@EntityField.unique()`) against
/// a controlled table scheme: [_SchemeAdapter] (a [DBSQLMemoryAdapter]
/// whose `sales_day` scheme has the given indexes, columns and dialect).

/// An entity with a composite key candidate (`establishment`, `day`), a
/// camelCase field (`creationDate`) and a unique field (`code`).
class _SalesDay extends Entity {
  int? id;
  int? establishment;
  String day;
  DateTime? creationDate;
  String? code;

  _SalesDay({
    this.id,
    this.establishment,
    this.day = '',
    this.creationDate,
    this.code,
  });

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const [
    'id',
    'establishment',
    'day',
    'creationDate',
    'code',
  ];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'establishment' => establishment as V?,
    'day' => day as V?,
    'creationDate' => creationDate as V?,
    'code' => code as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' || 'establishment' => TypeInfo.tInt,
    'day' || 'code' => TypeInfo.tString,
    'creationDate' => TypeInfo.tDateTime,
    _ => null,
  };

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      key == 'code' ? const [EntityField.unique()] : null;

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'establishment':
        establishment = value as int?;
      case 'day':
        day = value as String;
      case 'creationDate':
        creationDate = value as DateTime?;
      case 'code':
        code = value as String?;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'establishment': establishment,
    'day': day,
    'creationDate': creationDate?.toIso8601String(),
    'code': code,
  };
}

const _postgres = SQLDialect(
  'PostgreSQL',
  elementQuote: '"',
  foreignKeyCreatesImplicitIndex: false,
  maxIdentifierLength: 63,
);

const _mysql = SQLDialect(
  'MySQL',
  elementQuote: '`',
  createIndexIfNotExists: false,
  dropIndexOnTable: true,
  maxIdentifierLength: 64,
);

const _sqlite = SQLDialect(
  'SQLite',
  elementQuote: '"',
  foreignKeyCreatesImplicitIndex: false,
  alterTableAddConstraint: false,
);

/// A [DBSQLMemoryAdapter] whose `sales_day` table scheme has the given
/// [indexes] / [uniqueIndexes] (`null`: unknown), [constraints], columns
/// ([renameColumns]: field -> column) and [dialect].
class _SchemeAdapter extends DBSQLMemoryAdapter {
  final SQLDialect? _dialect;

  Map<String, List<String>>? indexes;
  Set<String>? uniqueIndexes;
  Set<TableConstraint>? constraints;
  Map<String, TableEnumConstraint>? checkConstraints;
  Map<String, String> renameColumns;

  /// `findIndexesNamesInUse` (`null`: unknown, the default).
  Map<String, String?>? namesInUse;

  /// With `constraintSupport` (as PostgreSQL).
  final bool constraintSupport;

  _SchemeAdapter({
    SQLDialect? dialect,
    this.indexes,
    this.uniqueIndexes,
    this.constraints,
    this.checkConstraints,
    this.renameColumns = const {},
    this.constraintSupport = false,
    super.parentRepositoryProvider,
  }) : _dialect = dialect;

  @override
  SQLDialect get dialect => _dialect ?? super.dialect;

  @override
  DBSQLAdapterCapability get capability => constraintSupport
      ? DBSQLAdapterCapability(
          dialect: _dialect ?? super.capability.dialect,
          transactions: true,
          transactionAbort: true,
          constraintSupport: true,
          tableSQL: false,
          multiIsolateSupport: false,
          connectivity: DBAdapterCapabilityConnectivity.none,
        )
      : super.capability;

  @override
  TableScheme? getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) {
    var scheme = super.getTableSchemeImpl(
      table,
      relationship,
      contextID: contextID,
    );
    if (scheme == null || table != 'sales_day') return scheme;

    return TableScheme(
      scheme.name,
      idFieldName: scheme.idFieldName,
      fieldsTypes: scheme.fieldsTypes.map(
        (k, v) => MapEntry(renameColumns[k] ?? k, v),
      ),
      fieldsReferencedTables: scheme.fieldsReferencedTables,
      relationshipTables: scheme.relationshipTables,
      constraints: constraints ?? scheme.constraints,
      relationship: scheme.relationship,
      indexes: indexes,
      uniqueIndexes: uniqueIndexes,
      checkConstraints: checkConstraints,
    );
  }

  @override
  FutureOr<Map<String, String?>?> findIndexesNamesInUse(
    String table,
    Iterable<String> indexesNames,
  ) {
    var namesInUse = this.namesInUse;
    if (namesInUse == null) return null;
    return {
      for (var n in indexesNames)
        if (namesInUse.containsKey(n)) n: namesInUse[n],
    };
  }
}

/// A provider with a [_SchemeAdapter] and the `sales_day` repository of
/// [entityIndexes].
class _CheckProvider extends EntityRepositoryProvider {
  late final _SchemeAdapter adapter;

  _CheckProvider(
    List<EntityIndex> entityIndexes, {
    SQLDialect? dialect,
    Map<String, List<String>>? indexes,
    Set<String>? uniqueIndexes,
    Set<TableConstraint>? constraints,
    Map<String, TableEnumConstraint>? checkConstraints,
    Map<String, String> renameColumns = const {},
    bool constraintSupport = false,
  }) {
    adapter = _SchemeAdapter(
      dialect: dialect,
      indexes: indexes,
      uniqueIndexes: uniqueIndexes,
      constraints: constraints,
      checkConstraints: checkConstraints,
      renameColumns: renameColumns,
      constraintSupport: constraintSupport,
      parentRepositoryProvider: this,
    );

    DBSQLEntityRepository<_SalesDay>(
      adapter,
      'sales_day',
      GenericEntityHandler<_SalesDay>(
        instantiatorDefault: _SalesDay.new,
        sampleEntity: _SalesDay(),
        entityIndexes: entityIndexes,
      ),
    );

    addTearDown(() {
      adapter.close();
      close();
    });
  }
}

/// A `checkDBTables(force: true)`: OK, or its error, which has the
/// suggested SQLs ([suggestions]: from its `Suggestion of SQLs`).
typedef _Check = ({bool ok, String error, String suggestions});

Future<_Check> _check(_SchemeAdapter adapter) async {
  try {
    var ok = await adapter.checkDBTables(force: true);
    return (ok: ok, error: '', suggestions: '');
  } on StateError catch (e) {
    var error = e.message;
    var idx = error.indexOf('Suggestion of SQLs');
    return (
      ok: false,
      error: error,
      // Single spaces (`ALTER TABLE "t"  ADD ...`):
      suggestions: idx >= 0
          ? error.substring(idx).replaceAll(RegExp(r' {2,}'), ' ')
          : '',
    );
  }
}

/// The unique indexes of a table: the primary key and `code`'s.
const _baseIndexes = {
  'sales_day_pkey': ['id'],
  'sales_day__code__unique': ['code'],
};

const _baseUnique = {'sales_day_pkey', 'sales_day__code__unique'};

const _unique = EntityIndex(['establishment', 'day'], unique: true);

void main() {
  group('checkTables: @EntityIndex', () {
    test('all present: OK', () async {
      var p = _CheckProvider(
        const [
          _unique,
          EntityIndex(['establishment', 'creationDate']),
        ],
        indexes: {
          ..._baseIndexes,
          'sales_day__establishment_day__unique': ['establishment', 'day'],
          'any_name': ['establishment', 'creation_date'],
        },
        uniqueIndexes: {..._baseUnique, 'sales_day__establishment_day__unique'},
        renameColumns: {'creationDate': 'creation_date'},
      );

      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
      expect(p.adapter.checkedTables, isTrue);
    });

    test('unknown indexes: not checked', () async {
      var p = _CheckProvider(const [_unique]);
      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
    });

    test('unknown unique indexes: the unique ones not checked', () async {
      var p = _CheckProvider(
        const [
          _unique,
          EntityIndex(['day']),
        ],
        indexes: {..._baseIndexes},
        // `uniqueIndexes` unknown:
      );

      var c = await _check(p.adapter);
      expect(c.ok, isFalse);
      // The non-unique one (known missing) reported; the unique one, not
      // (unknown: not reported as missing).
      expect(c.error, contains('sales_day__day__idx(day)'));
      expect(c.error, isNot(contains('sales_day__establishment_day__unique(')));
    });

    test('unique: a non-unique index over its columns isn\'t it', () async {
      var p = _CheckProvider(
        const [_unique],
        dialect: _postgres,
        indexes: {
          ..._baseIndexes,
          'other_name': ['establishment', 'day'],
        },
        uniqueIndexes: _baseUnique,
      );

      var c = await _check(p.adapter);
      expect(c.ok, isFalse);
      expect(p.adapter.checkedTables, isFalse);
      expect(
        c.error,
        contains(
          'sales_day__establishment_day__unique(establishment, day) UNIQUE',
        ),
      );
      // No name conflict: another name.
      expect(c.error, isNot(contains('name in use')));
      // The fix: a constraint (as in the `CREATE TABLE`).
      expect(
        c.suggestions,
        contains(
          'ALTER TABLE "sales_day" ADD CONSTRAINT '
          '"sales_day__establishment_day__unique" '
          'UNIQUE ("establishment", "day")',
        ),
      );
    });

    test('unique: per dialect fix', () async {
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
          _sqlite,
          'CREATE UNIQUE INDEX IF NOT EXISTS '
              '"sales_day__establishment_day__unique" '
              'ON "sales_day" ("establishment", "day")',
        ),
      ]) {
        var p = _CheckProvider(
          const [_unique],
          dialect: dialect,
          indexes: {..._baseIndexes},
          uniqueIndexes: _baseUnique,
        );

        var c = await _check(p.adapter);
        expect(c.ok, isFalse, reason: dialect.name);
        expect(c.suggestions, contains(expected), reason: dialect.name);
      }
    });

    test('unique: satisfied by any unique index, in the same order', () async {
      for (var (columns, ok) in [
        (['establishment', 'day'], true),
        (['ESTABLISHMENT', 'Day'], true),
        // Another order, a superset, a subset: not the same uniqueness.
        (['day', 'establishment'], false),
        (['establishment', 'day', 'code'], false),
        (['establishment'], false),
      ]) {
        var p = _CheckProvider(
          const [_unique],
          indexes: {..._baseIndexes, 'uq': columns},
          uniqueIndexes: {..._baseUnique, 'uq'},
        );

        var c = await _check(p.adapter);
        expect(c.ok, ok, reason: '$columns: ${c.error}');
      }
    });

    test('unique over the primary key: satisfied by it', () async {
      var p = _CheckProvider(
        const [
          EntityIndex(['id'], unique: true),
        ],
        indexes: {..._baseIndexes},
        uniqueIndexes: _baseUnique,
      );

      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
    });

    test('a non-unique one: satisfied by a unique index', () async {
      var p = _CheckProvider(
        const [
          EntityIndex(['establishment', 'day']),
        ],
        indexes: {
          ..._baseIndexes,
          'uq': ['establishment', 'day'],
        },
        uniqueIndexes: {..._baseUnique, 'uq'},
      );

      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
    });

    test('unique: its name in use by a non-unique index', () async {
      var p = _CheckProvider(
        const [_unique],
        dialect: _postgres,
        indexes: {
          ..._baseIndexes,
          'sales_day__establishment_day__unique': ['establishment', 'day'],
        },
        uniqueIndexes: _baseUnique,
      );

      var c = await _check(p.adapter);
      expect(c.ok, isFalse);
      expect(
        c.error,
        contains(
          '<name in use over (establishment, day), not unique: drop it first>',
        ),
      );
      expect(
        c.suggestions,
        contains(
          '-- `sales_day__establishment_day__unique` in use over '
          '(establishment, day), not unique: drop it first:',
        ),
      );
    });

    test('its name in use elsewhere (findIndexesNamesInUse)', () async {
      for (var (inUse, description) in [
        ('other_table', 'on table `other_table`'),
        (null, 'by another relation (not an index)'),
        (
          'sales_day',
          'by an index not usable as it (partial, expression or prefix)',
        ),
      ]) {
        var p = _CheckProvider(
          const [_unique],
          indexes: {..._baseIndexes},
          uniqueIndexes: _baseUnique,
        );
        p.adapter.namesInUse = {
          'sales_day__establishment_day__unique': inUse,
          'unrelated_name': 'x',
        };

        var c = await _check(p.adapter);
        expect(c.ok, isFalse);
        expect(
          c.error,
          contains(
            'sales_day__establishment_day__unique(establishment, day) UNIQUE '
            '<name in use $description: drop it first>',
          ),
          reason: '$inUse',
        );
      }
    });

    test('names in use: not looked up when the index is there', () async {
      var p = _CheckProvider(
        const [_unique],
        indexes: {
          ..._baseIndexes,
          'sales_day__establishment_day__unique': ['establishment', 'day'],
        },
        uniqueIndexes: {..._baseUnique, 'sales_day__establishment_day__unique'},
      );
      p.adapter.namesInUse = {'sales_day__establishment_day__unique': 'x'};

      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
    });

    test('legacy column (`creationDate`): the table\'s column', () async {
      // A legacy table: `creationDate` (not `creation_date`).
      var missing = _CheckProvider(
        const [
          EntityIndex(['establishment', 'creationDate']),
        ],
        dialect: _postgres,
        indexes: {..._baseIndexes},
        uniqueIndexes: _baseUnique,
      );

      var c = await _check(missing.adapter);
      expect(c.ok, isFalse);
      // The name: from the generated columns (as in the `CREATE TABLE`); the
      // columns: the table's.
      expect(
        c.error,
        contains(
          'sales_day__establishment_creation_date__idx'
          '(establishment, creationDate)',
        ),
      );
      expect(
        c.suggestions,
        contains(
          'CREATE INDEX IF NOT EXISTS '
          '"sales_day__establishment_creation_date__idx" ON "sales_day" '
          '("establishment", "creationDate")',
        ),
      );

      // With the index over the legacy column: OK.
      var present = _CheckProvider(
        const [
          EntityIndex(['establishment', 'creationDate']),
        ],
        indexes: {
          ..._baseIndexes,
          'legacy_idx': ['establishment', 'creationDate'],
        },
        uniqueIndexes: _baseUnique,
      );
      var c2 = await _check(present.adapter);
      expect(c2.ok, isTrue, reason: c2.error);
    });

    test('not reported twice', () async {
      var p = _CheckProvider(
        const [
          // Unique and non-unique over the same columns: only the unique.
          EntityIndex(['establishment', 'day']),
          _unique,
          // Twice the same:
          EntityIndex(['day']),
          EntityIndex(['day'], name: 'sales_day_day_2'),
        ],
        indexes: {..._baseIndexes},
        uniqueIndexes: _baseUnique,
      );

      var c = await _check(p.adapter);
      expect(c.ok, isFalse);
      expect(
        c.error,
        contains(
          'sales_day__establishment_day__unique(establishment, day) UNIQUE',
        ),
      );
      expect(c.error, isNot(contains('sales_day__establishment_day__idx(')));
      expect(c.error, contains('sales_day__day__idx(day)'));
      expect(c.error, isNot(contains('sales_day_day_2(')));
    });
  });

  group('checkTables: @EntityField.unique()', () {
    test('missing: reported once, as the field\'s', () async {
      for (var (dialect, expected) in [
        (
          _postgres,
          'ALTER TABLE "sales_day" ADD CONSTRAINT "sales_day__code__unique" '
              'UNIQUE ("code")',
        ),
        (
          _sqlite,
          'CREATE UNIQUE INDEX IF NOT EXISTS "sales_day__code__unique" '
              'ON "sales_day" ("code")',
        ),
      ]) {
        var p = _CheckProvider(
          const [
            // The same as `code`'s `@EntityField.unique()`:
            EntityIndex(['code'], unique: true),
          ],
          dialect: dialect,
          indexes: {
            'sales_day_pkey': ['id'],
          },
          uniqueIndexes: {'sales_day_pkey'},
        );

        var c = await _check(p.adapter);
        expect(c.ok, isFalse, reason: dialect.name);
        expect(c.error, contains('missingUniqueConstraints: [code]'));
        expect(c.error, isNot(contains('sales_day__code__unique(code)')));
        expect(c.suggestions, contains(expected), reason: dialect.name);
      }
    });

    test('a non-unique index over the column: missing', () async {
      var p = _CheckProvider(
        const [],
        indexes: {
          'sales_day_pkey': ['id'],
          'code_idx': ['code'],
        },
        uniqueIndexes: {'sales_day_pkey'},
      );

      var c = await _check(p.adapter);
      expect(c.ok, isFalse);
      expect(c.error, contains('missingUniqueConstraints: [code]'));
    });

    test('unknown unique indexes: from the constraints', () async {
      // Unique indexes unknown, constraints known (`constraintSupport`):
      var ok = _CheckProvider(
        const [],
        indexes: {..._baseIndexes},
        constraints: {TableUniqueConstraint('code')},
        constraintSupport: true,
      );
      var c = await _check(ok.adapter);
      expect(c.ok, isTrue, reason: c.error);

      var missing = _CheckProvider(
        const [],
        indexes: {..._baseIndexes},
        constraints: {},
        constraintSupport: true,
      );
      var c2 = await _check(missing.adapter);
      expect(c2.ok, isFalse);
      expect(c2.error, contains('missingUniqueConstraints: [code]'));
    });

    test(
      'unknown unique indexes, no constraints support: not checked',
      () async {
        var p = _CheckProvider(const [], indexes: {..._baseIndexes});
        var c = await _check(p.adapter);
        expect(c.ok, isTrue, reason: c.error);
      },
    );
  });

  group('DBSQLMemoryAdapter: composite unique values', () {
    Future<EntityFieldInvalid?> store(
      EntityRepository<_SalesDay> repository,
      _SalesDay o,
    ) async {
      try {
        await repository.store(o);
        return null;
      } on EntityFieldInvalid catch (e) {
        return e;
      }
    }

    test('DateTime, null, update', () async {
      var p = _CheckProvider(const [
        EntityIndex(['establishment', 'creationDate'], unique: true),
      ]);
      var repository = p.getEntityRepositoryByType<_SalesDay>(_SalesDay)!;

      var t1 = DateTime.utc(2024, 1, 1, 10);
      var t2 = DateTime.utc(2024, 1, 1, 11);

      expect(
        await store(
          repository,
          _SalesDay(establishment: 1, creationDate: t1, code: 'a'),
        ),
        isNull,
      );
      expect(
        await store(
          repository,
          _SalesDay(establishment: 1, creationDate: t2, code: 'b'),
        ),
        isNull,
      );

      // The same instant (another `DateTime` instance): a violation.
      var dup = await store(
        repository,
        _SalesDay(
          establishment: 1,
          creationDate: DateTime.utc(2024, 1, 1, 10),
          code: 'c',
        ),
      );
      expect(dup?.fieldsNames, ['establishment', 'creationDate']);

      // A `null` value never conflicts (as the SQL databases):
      expect(
        await store(repository, _SalesDay(establishment: 1, code: 'd')),
        isNull,
      );
      expect(
        await store(repository, _SalesDay(establishment: 1, code: 'e')),
        isNull,
      );
      expect(
        await store(repository, _SalesDay(creationDate: t1, code: 'f')),
        isNull,
      );

      expect((await repository.selectAll()).length, 5);
    });

    test('the field unique and the composite one', () async {
      var p = _CheckProvider(const [_unique]);
      var repository = p.getEntityRepositoryByType<_SalesDay>(_SalesDay)!;

      expect(
        await store(
          repository,
          _SalesDay(establishment: 1, day: 'mon', code: 'a'),
        ),
        isNull,
      );

      // `code` (a field's unique): its own error.
      var codeDup = await store(
        repository,
        _SalesDay(establishment: 2, day: 'tue', code: 'a'),
      );
      expect(codeDup?.fieldName, 'code');
      expect(codeDup?.fieldsNames, isNull);

      // The composite one:
      var dup = await store(
        repository,
        _SalesDay(establishment: 1, day: 'mon', code: 'b'),
      );
      expect(dup?.fieldName, 'establishment, day');
      expect(dup?.fieldsNames, ['establishment', 'day']);
    });
  });

  group('checkTables: duplicated indexes and CHECK constraints', () {
    TableScheme scheme({
      String table = 'sales_day',
      Map<String, List<String>>? indexes,
      Set<String>? uniqueIndexes,
      Map<String, TableEnumConstraint>? checkConstraints,
      String? primaryKeyIndex,
      Map<String, String>? indexesKinds,
    }) => TableScheme(
      table,
      idFieldName: 'id',
      fieldsTypes: const {
        'id': int,
        'establishment': int,
        'day': String,
        'type': String,
      },
      indexes: indexes,
      uniqueIndexes: uniqueIndexes,
      checkConstraints: checkConstraints,
      primaryKeyIndex: primaryKeyIndex,
      indexesKinds: indexesKinds,
    );

    _SchemeAdapter adapter(SQLDialect dialect) {
      var a = _SchemeAdapter(dialect: dialect);
      addTearDown(a.close);
      return a;
    }

    test('TableScheme: same columns, in order, any case', () {
      var s = scheme(
        indexes: {
          'b_idx': ['establishment', 'day'],
          'a_idx': ['Establishment', 'DAY'],
          'reversed': ['day', 'establishment'],
          'prefix': ['establishment'],
          'sales_day_pkey': ['id'],
        },
        checkConstraints: {
          'c2': TableEnumConstraint('type', ['admin']),
          'c1': TableEnumConstraint('TYPE', ['admin', 'guest']),
          'other': TableEnumConstraint('day', ['x']),
        },
      );

      expect(s.duplicatedIndexes, [
        ['a_idx', 'b_idx'],
      ]);
      expect(s.duplicatedCheckConstraints, {
        'type': ['c1', 'c2'],
      });
    });

    test('TableScheme: unknown: null; none: empty', () {
      var unknown = scheme();
      expect(unknown.duplicatedIndexes, isNull);
      expect(unknown.duplicatedCheckConstraints, isNull);

      var none = scheme(
        indexes: {
          'sales_day_pkey': ['id'],
        },
        checkConstraints: {
          'c': TableEnumConstraint('type', ['admin']),
        },
      );
      expect(none.duplicatedIndexes, isEmpty);
      expect(none.duplicatedCheckConstraints, isEmpty);
    });

    test('indexes: kept the primary key, a unique one, the default name; '
        'per dialect SQL', () {
      var s = scheme(
        indexes: {
          'sales_day_pkey': ['id'],
          'id_copy': ['id'],
          'sales_day__establishment_day__unique': ['establishment', 'day'],
          'sales_day__establishment_day__idx': ['establishment', 'day'],
          'zz_unique_copy': ['establishment', 'day'],
          'sales_day__day__idx': ['day'],
          'a_day': ['day'],
        },
        uniqueIndexes: {
          'sales_day_pkey',
          'sales_day__establishment_day__unique',
          'zz_unique_copy',
        },
      );

      var pg = adapter(_postgres).findTableDuplicates(s);
      expect(pg.isNotEmpty, isTrue);
      expect(pg.indexes, [
        ['sales_day__day__idx', 'a_day'],
        ['sales_day_pkey', 'id_copy'],
        [
          'sales_day__establishment_day__unique',
          'zz_unique_copy',
          'sales_day__establishment_day__idx',
        ],
      ]);
      expect(pg.checkConstraints, isEmpty);
      expect(
        pg.dropSQLs,
        containsAll([
          'DROP INDEX IF EXISTS "a_day" ;',
          'DROP INDEX IF EXISTS "id_copy" ;',
          // A unique one: a constraint's or an index:
          'ALTER TABLE "sales_day" DROP CONSTRAINT IF EXISTS "zz_unique_copy" ;',
          'DROP INDEX IF EXISTS "zz_unique_copy" ;',
          'DROP INDEX IF EXISTS "sales_day__establishment_day__idx" ;',
        ]),
      );
      // The kept ones aren't dropped:
      for (var kept in [
        'sales_day__day__idx',
        'sales_day_pkey',
        'sales_day__establishment_day__unique',
      ]) {
        expect(pg.dropSQLs.where((s) => s.contains('"$kept" ;')), isEmpty);
      }

      var mysql = adapter(_mysql).findTableDuplicates(s);
      expect(mysql.indexes, pg.indexes);
      expect(
        mysql.dropSQLs,
        containsAll([
          'DROP INDEX `a_day` ON `sales_day` ;',
          'DROP INDEX `zz_unique_copy` ON `sales_day` ;',
        ]),
      );
      expect(mysql.dropSQLs.where((s) => s.contains('CONSTRAINT')), isEmpty);

      var sqlite = adapter(_sqlite).findTableDuplicates(s);
      expect(
        sqlite.dropSQLs,
        contains('DROP INDEX IF EXISTS "zz_unique_copy" ;'),
      );
      expect(sqlite.dropSQLs.where((s) => s.contains('CONSTRAINT')), isEmpty);
    });

    test(
      'MySQL SERIAL: the PRIMARY key and its unique index: not reported',
      () {
        var s = scheme(
          indexes: {
            'PRIMARY': ['id'],
            'id': ['id'],
            'id_copy': ['id'],
            'sales_day__day__idx': ['day'],
          },
          uniqueIndexes: {'PRIMARY', 'id'},
        );

        var d = adapter(_mysql).findTableDuplicates(s);
        // Only `id_copy` (`id`: of `SERIAL`):
        expect(d.indexes, [
          ['PRIMARY', 'id_copy'],
        ]);
        expect(d.dropSQLs, contains('DROP INDEX `id_copy` ON `sales_day` ;'));
        expect(d.dropSQLs.where((s) => s.contains('`id` ON')), isEmpty);

        var onlySerial = scheme(
          indexes: {
            'PRIMARY': ['id'],
            'id': ['id'],
          },
          uniqueIndexes: {'PRIMARY', 'id'},
        );
        expect(adapter(_mysql).findTableDuplicates(onlySerial).isEmpty, isTrue);
      },
    );

    test('the primary key: by primaryKeyIndex, whatever its name', () {
      // A renamed table (`order` -> `orders`) keeps `order_pkey`:
      var s = scheme(
        table: 'orders',
        indexes: {
          'order_pkey': ['id'],
          'a_orders_id_uq': ['id'],
        },
        uniqueIndexes: {'order_pkey', 'a_orders_id_uq'},
        primaryKeyIndex: 'order_pkey',
      );

      var d = adapter(_postgres).findTableDuplicates(s);
      expect(d.indexes, [
        ['order_pkey', 'a_orders_id_uq'],
      ]);
      expect(d.dropSQLs.where((s) => s.contains('"order_pkey"')), isEmpty);
      expect(
        d.dropSQLs,
        contains(
          'ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "a_orders_id_uq" ;',
        ),
      );
    });

    test('index kinds: other kinds over the same columns aren\'t '
        'duplicates', () {
      var s = scheme(
        indexes: {
          'tags_btree': ['day'],
          'tags_gin': ['day'],
          'tags_gin_2': ['day'],
          'day_include': ['day'],
        },
        indexesKinds: {
          'tags_btree': 'btree|3',
          'tags_gin': 'gin|3',
          'tags_gin_2': 'gin|3',
          'day_include': 'btree|3 4',
        },
      );

      // Only the 2 GIN indexes (the same kind):
      expect(s.duplicatedIndexes, [
        ['tags_gin', 'tags_gin_2'],
      ]);
      expect(adapter(_postgres).findTableDuplicates(s).indexes, [
        ['tags_gin', 'tags_gin_2'],
      ]);
    });

    test('unique: the default name (`__unique`) kept', () {
      var s = scheme(
        indexes: {
          'aa_manual_uq': ['establishment', 'day'],
          'sales_day__establishment_day__unique': ['establishment', 'day'],
        },
        uniqueIndexes: {'aa_manual_uq', 'sales_day__establishment_day__unique'},
      );

      var d = adapter(_postgres).findTableDuplicates(s);
      expect(d.indexes, [
        ['sales_day__establishment_day__unique', 'aa_manual_uq'],
      ]);
    });

    test('unique: a foreign key may depend on it: noted', () {
      var s = scheme(
        indexes: {
          'sales_day__establishment_day__unique': ['establishment', 'day'],
          'zz_copy_uq': ['establishment', 'day'],
          'zz_copy_idx': ['establishment', 'day'],
        },
        uniqueIndexes: {'sales_day__establishment_day__unique', 'zz_copy_uq'},
      );

      var dropSQLs = adapter(_postgres).findTableDuplicates(s).dropSQLs;
      var fkNotes = dropSQLs.where((s) => s.contains('foreign key')).toList();
      // Only the unique one (`zz_copy_uq`), before its drop:
      expect(fkNotes, hasLength(1));
      expect(fkNotes.single, contains('`zz_copy_uq`'));
      expect(
        dropSQLs.indexOf(fkNotes.single),
        lessThan(
          dropSQLs.indexOf(
            'ALTER TABLE "sales_day" DROP CONSTRAINT IF EXISTS "zz_copy_uq" ;',
          ),
        ),
      );
    });

    test('CHECKs: all the entity\'s values (and others) kept over the '
        'default name', () {
      RoleType$reflection.staticInstance;

      var s = scheme(
        checkConstraints: {
          'sales_day_type_check': TableEnumConstraint('type', ['admin']),
          'zz_type_check': TableEnumConstraint('type', [
            'admin',
            'guest',
            'unknown',
            'legacy',
          ]),
        },
      );

      var d = adapter(
        _postgres,
      ).findTableDuplicates(s, entityHandler: Role$reflection().entityHandler);
      expect(d.checkConstraints, {
        'type': ['zz_type_check', 'sales_day_type_check'],
      });
      expect(d.dropSQLs.where((s) => s.contains('review')), isEmpty);
    });

    test('CHECKs: the default names (also `__check`) kept over others', () {
      var s = scheme(
        checkConstraints: {
          'aa_type': TableEnumConstraint('type', ['admin']),
          'sales_day_type__check': TableEnumConstraint('type', [
            'admin',
            'guest',
          ]),
        },
      );

      var d = adapter(_postgres).findTableDuplicates(s);
      expect(d.checkConstraints, {
        'type': ['sales_day_type__check', 'aa_type'],
      });
    });

    test('CHECKs: the column mapped to the entity\'s field, any case', () {
      RoleType$reflection.staticInstance;

      var s = TableScheme(
        'role',
        idFieldName: 'id',
        fieldsTypes: const {'id': int, 'Type': String},
        checkConstraints: {
          'role_type_check': TableEnumConstraint('Type', ['admin']),
          'zz_current': TableEnumConstraint('Type', [
            'admin',
            'guest',
            'unknown',
          ]),
        },
      );

      var d = adapter(
        _postgres,
      ).findTableDuplicates(s, entityHandler: Role$reflection().entityHandler);
      // The entity's values (`type`): `zz_current`, not the default name.
      expect(d.checkConstraints.values.single, [
        'zz_current',
        'role_type_check',
      ]);
    });

    test('SQLite: a constraint\'s index (sqlite_autoindex) is kept', () {
      var s = scheme(
        indexes: {
          'sqlite_autoindex_sales_day_1': ['day'],
          'a_day_unique': ['day'],
        },
        uniqueIndexes: {'sqlite_autoindex_sales_day_1', 'a_day_unique'},
      );

      var d = adapter(_sqlite).findTableDuplicates(s);
      expect(d.indexes, [
        ['sqlite_autoindex_sales_day_1', 'a_day_unique'],
      ]);
      expect(d.dropSQLs, contains('DROP INDEX IF EXISTS "a_day_unique" ;'));
    });

    test('CHECKs: kept the one with the entity\'s values', () {
      RoleType$reflection.staticInstance;

      var s = scheme(
        checkConstraints: {
          'sales_day_type_check': TableEnumConstraint('type', [
            'admin',
            'guest',
          ]),
          'sales_day_type_check1': TableEnumConstraint('type', [
            'admin',
            'guest',
            'unknown',
          ]),
          'old_type': TableEnumConstraint('type', ['admin']),
        },
      );

      var d = adapter(
        _postgres,
      ).findTableDuplicates(s, entityHandler: Role$reflection().entityHandler);

      expect(d.indexes, isEmpty);
      expect(d.checkConstraints, {
        'type': ['sales_day_type_check1', 'sales_day_type_check', 'old_type'],
      });
      expect(
        d.dropSQLs,
        containsAll([
          'ALTER TABLE "sales_day" DROP CONSTRAINT IF EXISTS "sales_day_type_check" ;  -- {admin, guest}',
          'ALTER TABLE "sales_day" DROP CONSTRAINT IF EXISTS "old_type" ;  -- {admin}',
        ]),
      );
      expect(d.dropSQLs.where((s) => s.contains('review')), isEmpty);
    });

    test('CHECKs: no entity: the default name; none with the entity\'s '
        'values: review', () {
      RoleType$reflection.staticInstance;

      var s = scheme(
        checkConstraints: {
          'old_type': TableEnumConstraint('type', ['admin']),
          'sales_day_type_check': TableEnumConstraint('type', [
            'admin',
            'guest',
          ]),
        },
      );

      var noEntity = adapter(_postgres).findTableDuplicates(s);
      expect(noEntity.checkConstraints, {
        'type': ['sales_day_type_check', 'old_type'],
      });
      expect(noEntity.dropSQLs.where((s) => s.contains('review')), isEmpty);

      var noMatch = adapter(
        _postgres,
      ).findTableDuplicates(s, entityHandler: Role$reflection().entityHandler);
      expect(noMatch.checkConstraints, noEntity.checkConstraints);
      expect(
        noMatch.dropSQLs.where((s) => s.contains('review before dropping')),
        hasLength(1),
      );
    });

    test('checkTables: warned, not an error; kept in tablesDuplicates', () async {
      var p = _CheckProvider(
        const [],
        dialect: _postgres,
        indexes: {
          ..._baseIndexes,
          'code_copy': ['code'],
        },
        uniqueIndexes: _baseUnique,
        checkConstraints: {
          'sales_day_day_check': TableEnumConstraint('day', ['a']),
          'day_check_2': TableEnumConstraint('day', ['a', 'b']),
        },
      );

      var c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);

      var d = p.adapter.tablesDuplicates['sales_day'];
      expect(d, isNotNull);
      expect(d!.indexes, [
        ['sales_day__code__unique', 'code_copy'],
      ]);
      expect(d.checkConstraints, {
        'day': ['sales_day_day_check', 'day_check_2'],
      });
      expect(d.dropSQLs, contains('DROP INDEX IF EXISTS "code_copy" ;'));
      expect(
        d.dropSQLs,
        contains(
          'ALTER TABLE "sales_day" DROP CONSTRAINT IF EXISTS "day_check_2" ;  -- {a, b}',
        ),
      );

      // Fixed: none on the next check.
      p.adapter
        ..indexes = {..._baseIndexes}
        ..checkConstraints = null;

      c = await _check(p.adapter);
      expect(c.ok, isTrue, reason: c.error);
      expect(p.adapter.tablesDuplicates, isEmpty);
    });
  });
}
