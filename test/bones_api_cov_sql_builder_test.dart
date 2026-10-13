@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A type without a SQL type nor a repository.
class _Meta {}

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

class _Item extends Entity {
  int? id;
  String? code;
  String title;
  RoleType? kind;
  _Owner? owner;
  _Meta? meta;

  _Item({this.id, this.code, this.title = '', this.kind, this.owner});

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const [
    'id',
    'code',
    'title',
    'kind',
    'owner',
    'meta',
  ];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'code' => code as V?,
    'title' => title as V?,
    'kind' => kind as V?,
    'owner' => owner as V?,
    'meta' => meta as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'code' || 'title' => TypeInfo.tString,
    'kind' => TypeInfo<RoleType>(RoleType),
    'owner' => TypeInfo<_Owner>(_Owner),
    'meta' => TypeInfo<_Meta>(_Meta),
    _ => null,
  };

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      switch (key) {
        'code' => const [EntityField.unique(), EntityField.maximum(20)],
        'title' => const [EntityField.indexed()],
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
        kind = value as RoleType?;
      case 'owner':
        owner = value as _Owner?;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'kind': kind?.name,
    'owner': owner?.id,
  };
}

const _pg = SQLDialect(
  'PostgreSQL',
  elementQuote: '"',
  foreignKeyCreatesImplicitIndex: false,
  maxIdentifierLength: 63,
);

const _varchar = SQLDialect(
  'VarcharDB',
  elementQuote: '"',
  acceptsVarcharWithoutMaximumSize: true,
);

/// A [DBSQLMemoryAdapter] with a [dialect].
class _DialectAdapter extends DBSQLMemoryAdapter {
  final SQLDialect _dialect;

  _DialectAdapter(this._dialect, {super.parentRepositoryProvider});

  @override
  SQLDialect get dialect => _dialect;
}

class _Provider extends EntityRepositoryProvider {
  late final _DialectAdapter adapter;

  _Provider([SQLDialect dialect = _pg]) {
    adapter = _DialectAdapter(dialect, parentRepositoryProvider: this);

    DBSQLEntityRepository<_Owner>(
      adapter,
      'owner',
      GenericEntityHandler<_Owner>(
        instantiatorDefault: _Owner.new,
        sampleEntity: _Owner(),
      ),
    );

    DBSQLEntityRepository<_Item>(
      adapter,
      'item',
      GenericEntityHandler<_Item>(
        instantiatorDefault: _Item.new,
        sampleEntity: _Item(),
      ),
    );

    addTearDown(() {
      adapter.close();
      close();
    });
  }
}

SQLEntry _column(String table, String column, {String? ref}) => SQLEntry(
  'COLUMN',
  ' "$column" INT',
  columns: [SQLColumn(table, column, referenceTable: ref)],
);

SQLEntry _fk(String table, String column, String ref) => SQLEntry(
  'CONSTRAINT',
  ' CONSTRAINT "${table}__${column}__fkey" FOREIGN KEY ("$column") '
      'REFERENCES "$ref"("id")',
  comment: '$column @ $ref.id',
  columns: [
    SQLColumn(table, column, referenceTable: ref, referenceColumn: 'id'),
  ],
);

void main() {
  setUpAll(() {
    User$reflection.boot();
  });

  group('SQL builders', () {
    test('SQLColumn.compareTo', () {
      var cols = [SQLColumn('b', 'x'), SQLColumn('a', 'z'), SQLColumn('a', 'y')]
        ..sort();
      expect(cols.map((c) => '${c.table}.${c.name}').toList(), [
        'a.y',
        'a.z',
        'b.x',
      ]);
    });

    test('SQLEntry', () {
      var e = SQLEntry(
        'COLUMN',
        'x INT',
        comment: '',
        columns: [
          SQLColumn('t', 'x', referenceTable: 'r'),
          SQLColumn('t', 'y'),
        ],
      );
      expect(e.comment, isNull);
      expect(e.tables, equals(['t']));
      expect(e.referenceTables, equals(['r']));
      expect(e.toString(), equals('x INT'));

      var e2 = SQLEntry('COLUMN', 'y INT', comment: 'the y');
      expect(e2.toString(), equals('y INT  -- the y'));
      expect(e2.tables, isNull);
    });

    test('SQLDialect: ==, hashCode, toString', () {
      const d1 = SQLDialect('X', elementQuote: '"');
      const d2 = SQLDialect('X', elementQuote: '`');
      const d3 = SQLDialect('Y');
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
      expect(d1.toString(), startsWith('SQLDialect{name: X,elementQuote: ", '));
      expect(d1.toString(), endsWith('maxIdentifierLength: null}'));
    });

    test('CreateTableSQL: constraints as ALTER TABLE', () {
      var a = CreateTableSQL(_pg, 'a', [
        _column('a', 'id'),
        _column('a', 'b_id', ref: 'b'),
        _fk('a', 'b_id', 'b'),
        _fk('a', 'parent', 'a'),
      ]);
      var rel = CreateTableSQL(_pg, 'a__bs__rel', [
        _column('a__bs__rel', 'a_id', ref: 'a'),
        _fk('a__bs__rel', 'a_id', 'a'),
      ], parentTable: 'a');
      a.relationships = [rel];

      expect(a.constraints, hasLength(2));
      expect(a.referenceTables, equals(['b', 'a']));
      expect(a.relationshipsTables, isEmpty);

      var alters = a.constraintsAsAlterTable();
      // Only the dependent one (to another table):
      expect(alters, hasLength(1));
      expect(
        alters.first.buildSQL(multiline: false),
        equals(
          'ALTER TABLE "a" ADD  CONSTRAINT "a__b_id__fkey" FOREIGN KEY ("b_id") '
          'REFERENCES "b"("id") ;',
        ),
      );
      expect(a.alterTables, equals(alters));
      expect(a.constraints, hasLength(1));
      expect(a.referenceTables, equals(['b', 'a']));

      // Recursive: the relationship's constraint too:
      expect(rel.constraints, isEmpty);
      expect(rel.alterTables, hasLength(1));
      expect(rel.alterTables!.first.toString(), contains('refs: [a]'));
      expect(
        rel.toString(),
        equals('CREATE TABLE a__bs__rel {parent: a, refs: [a]}'),
      );

      // Not only the dependents:
      var c = CreateTableSQL(_pg, 'c', [
        _column('c', 'id'),
        _fk('c', 'parent', 'c'),
      ]);
      var alters2 = c.constraintsAsAlterTable(
        recursive: false,
        onlyDependents: false,
      );
      expect(alters2, hasLength(1));
      expect(c.constraints, isEmpty);
    });

    test('CreateTableSQL / AlterTableSQL: buildSQL and toString', () {
      var t = CreateTableSQL(_pg, 't', [
        SQLEntry('COLUMN', ' "id" INT', comment: 'int id'),
        SQLEntry('COLUMN', ' "name" VARCHAR'),
      ]);
      expect(
        t.buildSQL(ifNotExists: false),
        equals(
          'CREATE TABLE "t" (\n "id" INT,        -- int id\n "name" VARCHAR \n) ;',
        ),
      );

      var alter = AlterTableSQL(_pg, 't', [
        SQLEntry('ADD', ' ADD COLUMN "x" INT', comment: 'int x'),
        SQLEntry('ADD', 'ADD COLUMN "y" INT'),
        SQLEntry(
          'ADD',
          'ADD COLUMN IF NOT EXISTS "z" INT',
          columns: [SQLColumn('t', 'z', referenceTable: 'r')],
        ),
      ], parentTable: 'p');

      expect(
        alter.buildSQL(),
        equals(
          'ALTER TABLE "t" \n'
          'ADD COLUMN IF NOT EXISTS  "x" INT,  -- int x\n'
          'ADD COLUMN IF NOT EXISTS "y" INT,\n'
          'ADD COLUMN IF NOT EXISTS "z" INT\n ;',
        ),
      );
      expect(
        alter.buildSQL(multiline: false, ifNotExists: false),
        equals(
          'ALTER TABLE "t"  ADD COLUMN "x" INT,ADD COLUMN "y" INT,'
          'ADD COLUMN IF NOT EXISTS "z" INT ;',
        ),
      );
      expect(alter.referenceTables, equals(['r']));
      expect(alter.dependentTables, equals(['r']));
      expect(alter.toString(), equals('ALTER TABLE t {parent: p, refs: [r]}'));
      expect(
        AlterTableSQL(_pg, 'u', [SQLEntry('ADD', 'ADD x')]).toString(),
        equals('ALTER TABLE u {}'),
      );
    });

    test('compareTo', () {
      var a = CreateTableSQL(_pg, 'a', [_column('a', 'id')]);
      var b = CreateTableSQL(_pg, 'b', [
        _column('b', 'id'),
        _column('b', 'a_id', ref: 'a'),
      ]);
      var b2 = CreateTableSQL(_pg, 'b2', [_column('b2', 'id')]);
      var alterB = AlterTableSQL(_pg, 'b', [
        SQLEntry(
          'ADD',
          'ADD x',
          columns: [SQLColumn('b', 'x', referenceTable: 'a')],
        ),
      ]);
      var alterC = AlterTableSQL(_pg, 'c', [SQLEntry('ADD', 'ADD x')]);
      var idxA = CreateIndexSQL(_pg, 'a', 'x', 'a__x__idx');
      var idxB = CreateIndexSQL(_pg, 'b', 'x', 'b__x__idx');

      // CREATE TABLE x CREATE TABLE: by references, then by name.
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(b2), lessThan(0));
      // CREATE TABLE before ALTER TABLE:
      expect(a.compareTo(alterB), equals(-1));
      expect(alterB.compareTo(a), equals(1));
      // CREATE TABLE x CREATE INDEX:
      expect(a.compareTo(idxA), equals(-1));
      expect(idxA.compareTo(a), equals(1));
      // An index of another table: by references (the index has 1).
      expect(b2.compareTo(idxA), lessThan(0));
      expect(idxA.compareTo(b2), greaterThan(0));
      expect(idxA.compareTo(idxB), equals(0));

      // ALTER TABLE x ALTER TABLE: by name.
      expect(alterB.compareTo(alterC), lessThan(0));
      // CREATE INDEX x ALTER TABLE: before the ones referencing its table.
      expect(idxA.compareTo(alterB), equals(-1));
      expect(alterB.compareTo(idxA), equals(1));
      expect(idxA.compareTo(alterC), equals(0));
      expect(alterC.compareTo(idxA), equals(0));

      expect(idxA.referenceTables, equals(['a']));
      expect(idxA.dependentTables, equals(['a']));
      expect(idxA.extraSQLBuilders, isNull);
      expect(
        idxA.toString(),
        equals('CREATE INDEX "a__x__idx" ON "a" ("x") ;'),
      );
    });

    test('ordering: bestOrder / toHierarchicalOrder', () {
      CreateTableSQL table(String name, List<String> refs) =>
          CreateTableSQL(_pg, name, [
            _column(name, 'id'),
            for (var r in refs) _column(name, '${r}_id', ref: r),
          ]);

      var c = table('c', ['b']);
      var b = table('b', ['a']);
      var a = table('a', []);
      var d = table('d', ['a', 'c']);
      d.indexes = [CreateIndexSQL(_pg, 'd', 'a_id', 'd__a_id__idx')];

      var sqls = <String, CreateTableSQL>{'d': d, 'c': c, 'b': b, 'a': a};

      expect(sqls.bestOrder().keys.toList(), equals(['a', 'b', 'c', 'd']));
      expect(
        sqls.toHierarchicalOrder().keys.toList(),
        equals(['a', 'b', 'c', 'd']),
      );

      var list = <SQLBuilder>[d, c, b, a, ...d.indexes!];
      list.bestOrder();
      expect(list.isValidOrder, isTrue);
      expect(list.map((e) => e.mainTable).toList(), ['a', 'b', 'c', 'd', 'd']);
      expect(list.getCreateTable('c'), same(c));
      expect(list.getCreateTable('x'), isNull);

      // A reference loop:
      var x = table('x', ['y']);
      var y = table('y', ['x']);
      var loop = <SQLBuilder>[x, y];
      expect(loop.isValidOrder, isFalse);
      loop.bestOrder();
      expect(loop, hasLength(2));
      expect(loop.invalidSQLsOrder(), isNotEmpty);
    });
  });

  group('SQLGenerator', () {
    test('primaryKeyTypeToSQLType', () {
      var p = _Provider();
      expect(
        p.adapter.primaryKeyTypeToSQLType(int),
        equals('SERIAL PRIMARY KEY'),
      );
      expect(
        p.adapter.primaryKeyTypeToSQLType(String),
        equals('VARCHAR(254) PRIMARY KEY'),
      );
      expect(
        p.adapter.primaryKeyTypeToSQLType(
          String,
          entityFieldAnnotations: [EntityField.maximum(40)],
        ),
        equals('VARCHAR(40) PRIMARY KEY'),
      );
      expect(p.adapter.primaryKeyTypeToSQLType(bool), equals('PRIMARY KEY'));

      var p2 = _Provider(_varchar);
      expect(
        p2.adapter.primaryKeyTypeToSQLType(String),
        equals('VARCHAR PRIMARY KEY'),
      );
    });

    test('generateAddColumnAlterTableSQL', () {
      var adapter = _Provider().adapter;

      String build(SQLBuilder s) =>
          s.buildAllSQLs(multiline: false, ifNotExists: true).join('\n');

      expect(
        build(
          adapter.generateAddColumnAlterTableSQL(
            'item',
            'title',
            TypeInfo.tString,
          ),
        ),
        equals(
          'ALTER TABLE "item" ADD COLUMN IF NOT EXISTS  "title" VARCHAR ;',
        ),
      );

      // Unique:
      expect(
        build(
          adapter.generateAddColumnAlterTableSQL(
            'item',
            'code',
            TypeInfo.tString,
            entityFieldAnnotations: [
              EntityField.unique(),
              EntityField.maximum(20),
            ],
          ),
        ),
        equals(
          'ALTER TABLE "item" ADD COLUMN IF NOT EXISTS  "code" VARCHAR(20) ;\n'
          'ALTER TABLE "item"  ADD CONSTRAINT "item__code__unique" UNIQUE ("code") ;',
        ),
      );

      // Indexed:
      expect(
        build(
          adapter.generateAddColumnAlterTableSQL(
            'item',
            'title',
            TypeInfo.tString,
            entityFieldAnnotations: [EntityField.indexed()],
          ),
        ),
        equals(
          'ALTER TABLE "item" ADD COLUMN IF NOT EXISTS  "title" VARCHAR ;\n'
          'CREATE INDEX IF NOT EXISTS "item__title__idx" ON "item" ("title") ;',
        ),
      );

      // An entity reference (FK and its index):
      expect(
        build(
          adapter.generateAddColumnAlterTableSQL(
            'item',
            'owner',
            TypeInfo<_Owner>(_Owner),
          ),
        ),
        equals(
          'ALTER TABLE "item" ADD COLUMN IF NOT EXISTS  "owner" BIGINT ;\n'
          'CREATE INDEX IF NOT EXISTS "item__owner__idx" ON "item" ("owner") ;\n'
          'ALTER TABLE "item"  ADD CONSTRAINT "item__owner__fkey" FOREIGN KEY ("owner") REFERENCES "owner"("id") ;',
        ),
      );

      // An enum:
      expect(
        build(
          adapter.generateAddColumnAlterTableSQL(
            'item',
            'kind',
            TypeInfo<RoleType>(RoleType),
          ),
        ),
        equals(
          'ALTER TABLE "item" ADD COLUMN IF NOT EXISTS  "kind" '
          "ENUM('admin','guest','unknown') ;",
        ),
      );
    });

    test('generateAddEnumConstraintAlterTableSQL', () {
      var adapter = _Provider().adapter;

      expect(
        adapter
            .generateAddEnumConstraintAlterTableSQL(
              'item',
              'kind',
              TypeInfo<RoleType>(RoleType),
            )
            .buildSQL(multiline: false),
        equals(
          'ALTER TABLE "item"  ADD CONSTRAINT "item_kind__check" '
          "ENUM('admin','guest','unknown') ;",
        ),
      );

      expect(
        () => adapter.generateAddEnumConstraintAlterTableSQL(
          'item',
          'title',
          TypeInfo.tString,
        ),
        throwsStateError,
      );
    });

    test('generateAddUniqueConstraintAlterTableSQL', () {
      var adapter = _Provider().adapter;
      expect(
        adapter
            .generateAddUniqueConstraintAlterTableSQL(
              'item',
              'code',
              TypeInfo.tString,
            )
            .buildSQL(multiline: false),
        equals(
          'ALTER TABLE "item"  ADD CONSTRAINT "item__code__unique" UNIQUE ("code") ;',
        ),
      );
    });

    test('isSiblingEntityType', () {
      var p1 = _Provider();
      var p2 = _Provider();

      var itemRepo = p1.adapter.getEntityRepositoryByType(_Item)!;
      var ownerRepo2 = p2.adapter.getEntityRepositoryByType(_Owner)!;

      expect(p1.adapter.isSiblingEntityType(itemRepo, _Owner), isTrue);
      expect(p1.adapter.isSiblingEntityType(itemRepo, _Meta), isFalse);
      expect(
        p1.adapter.isSiblingEntityType(
          itemRepo,
          _Owner,
          columnRepository: ownerRepo2,
        ),
        isFalse,
      );
    });

    test('generateCreateTableSQL', () async {
      var adapter = _Provider().adapter;

      expect(
        () => adapter.generateCreateTableSQL(type: _Meta),
        throwsArgumentError,
      );

      var create = adapter.generateCreateTableSQL(type: _Item);
      // `meta` has no SQL type: not a column.
      expect(
        create.buildSQL(multiline: false),
        equals(
          'CREATE TABLE IF NOT EXISTS "item" ( "id" SERIAL PRIMARY KEY, '
          '"code" VARCHAR(20), '
          "\"kind\" ENUM('admin','guest','unknown'), "
          '"owner" BIGINT, "title" VARCHAR, '
          'CONSTRAINT "item__code__unique" UNIQUE ("code"), '
          'CONSTRAINT "item__owner__fkey" FOREIGN KEY ("owner") '
          'REFERENCES "owner"("id") ) ;',
        ),
      );
      expect(
        create.indexes?.map((e) => e.indexName),
        containsAll(['item__title__idx', 'item__owner__idx']),
      );

      var full = await adapter.generateFullCreateTableSQLs(
        title: 'Line 1\nLine 2',
        withDate: true,
      );
      expect(full, startsWith('-- Line 1\n-- Line 2\n-- SQLAdapter: '));
      expect(full, contains('-- Dialect: PostgreSQL\n'));
      expect(full, contains('-- Date: '));
      expect(full, contains('-- Entity: _Item @ item'));
    });
  });
}
