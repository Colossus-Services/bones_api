@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

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
    Map<String, String> renameColumns = const {},
    bool constraintSupport = false,
  }) {
    adapter = _SchemeAdapter(
      dialect: dialect,
      indexes: indexes,
      uniqueIndexes: uniqueIndexes,
      constraints: constraints,
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
}
