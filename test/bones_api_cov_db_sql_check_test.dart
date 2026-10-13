@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// `checkTables` with `constraintSupport` (as PostgreSQL): references
/// (`FOREIGN KEY`s and their indexes), relationship tables' indexes and enum
/// `CHECK` constraints, against controlled table schemes ([_SchemesAdapter]).

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
  ];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'code' => code as V?,
    'title' => title as V?,
    'kind' => kind as V?,
    'owner' => owner as V?,
    'tags' => tags as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'code' || 'title' => TypeInfo.tString,
    'kind' => TypeInfo<RoleType>(RoleType),
    'owner' => TypeInfo<_Owner>(_Owner),
    'tags' => TypeInfo<List<_Tag>>(List, [TypeInfo<_Tag>(_Tag)]),
    _ => null,
  };

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      switch (key) {
        'code' => const [EntityField.unique()],
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
      case 'tags':
        tags = value == null ? [] : List<_Tag>.from(value as Iterable);
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

/// A [DBSQLMemoryAdapter] with `constraintSupport` and the table [schemes].
class _SchemesAdapter extends DBSQLMemoryAdapter {
  final Map<String, TableScheme> schemes;

  _SchemesAdapter(this.schemes, {super.parentRepositoryProvider});

  @override
  SQLDialect get dialect => _pg;

  @override
  DBSQLAdapterCapability get capability => DBSQLAdapterCapability(
    dialect: _pg,
    transactions: true,
    transactionAbort: true,
    constraintSupport: true,
    tableSQL: false,
    multiIsolateSupport: false,
    connectivity: DBAdapterCapabilityConnectivity.none,
  );

  @override
  TableScheme? getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) => schemes[table];
}

class _Provider extends EntityRepositoryProvider {
  late final _SchemesAdapter adapter;

  _Provider(Map<String, TableScheme> schemes) {
    adapter = _SchemesAdapter(schemes, parentRepositoryProvider: this);

    DBSQLEntityRepository<_Owner>(
      adapter,
      'owner',
      GenericEntityHandler<_Owner>(
        instantiatorDefault: _Owner.new,
        sampleEntity: _Owner(),
      ),
    );

    DBSQLEntityRepository<_Tag>(
      adapter,
      'tag',
      GenericEntityHandler<_Tag>(
        instantiatorDefault: _Tag.new,
        sampleEntity: _Tag(),
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

final _baseSchemes = {
  'owner': TableScheme(
    'owner',
    idFieldName: 'id',
    fieldsTypes: {'id': int, 'name': String},
  ),
  'tag': TableScheme(
    'tag',
    idFieldName: 'id',
    fieldsTypes: {'id': int, 'label': String},
  ),
};

TableRelationshipReference _itemTags({
  String? sourceIndex,
  String? targetIndex,
}) => TableRelationshipReference(
  'item__tags__rel',
  'item',
  'id',
  int,
  'item_id',
  'tag',
  'id',
  int,
  'tag_id',
  sourceRelationshipFieldIndex: sourceIndex,
  targetRelationshipFieldIndex: targetIndex,
);

Future<String?> _checkError(DBSQLAdapter adapter) async {
  try {
    await adapter.checkDBTables(force: true);
    return null;
  } on StateError catch (e) {
    return e.message;
  }
}

void main() {
  setUpAll(() {
    User$reflection.boot();
  });

  test('missing FOREIGN KEY, relationship indexes and enum CHECK', () async {
    var p = _Provider({
      ..._baseSchemes,
      'item': TableScheme(
        'item',
        idFieldName: 'id',
        fieldsTypes: {
          'id': int,
          'code': String,
          'title': String,
          'kind': String,
          'owner': int,
        },
        relationshipTables: [_itemTags()],
        constraints: [TableUniqueConstraint('code')],
      ),
    });

    var error = await _checkError(p.adapter);
    expect(p.adapter.checkedTables, isFalse);

    expect(error, contains('  -- missingReferenceConstraints: [_Owner owner]'));
    expect(
      error,
      contains(
        '  -- missingRelationshipReferenceIndexes: '
        '[_Item item_id , _Tag tag_id]',
      ),
    );
    // The reference column exists:
    expect(error, isNot(contains('missingReferenceColumns')));

    expect(
      error,
      contains(
        'Suggestion of SQLs (`PostgreSQL`) to fix missing columns in tables:\n'
        '\n'
        '  ALTER TABLE "item"  ADD CONSTRAINT "item__owner__fkey" '
        'FOREIGN KEY ("owner") REFERENCES "owner"("id") ;\n'
        '  \n'
        '  CREATE INDEX IF NOT EXISTS "item__tags__rel__item_id__idx" '
        'ON "item__tags__rel" ("item_id") ;\n'
        '  CREATE INDEX IF NOT EXISTS "item__tags__rel__tag_id__idx" '
        'ON "item__tags__rel" ("tag_id") ;\n'
        '  \n'
        '  ALTER TABLE "item"  ADD CONSTRAINT "item_kind__check" '
        "ENUM('admin','guest','unknown') ;\n",
      ),
    );
  });

  test('missing FOREIGN KEY index and enum values', () async {
    var p = _Provider({
      ..._baseSchemes,
      'item': TableScheme(
        'item',
        idFieldName: 'id',
        fieldsTypes: {
          'id': int,
          'code': String,
          'title': String,
          'kind': String,
          'owner': int,
        },
        fieldsReferencedTables: {
          'owner': TableFieldReference(
            'item',
            'owner',
            int,
            'owner',
            'id',
            int,
          ),
        },
        relationshipTables: [_itemTags(sourceIndex: 'i1', targetIndex: 'i2')],
        constraints: [
          TableUniqueConstraint('code'),
          TableEnumConstraint('kind', ['admin']),
        ],
      ),
    });

    var error = await _checkError(p.adapter);

    expect(error, contains('  -- missingReferenceIndexes: [_Owner owner]'));
    expect(error, isNot(contains('missingReferenceConstraints')));
    expect(error, isNot(contains('missingRelationshipReferenceIndexes')));

    // The enum values missing in the `CHECK` (only `admin`): a new one.
    expect(
      error,
      contains(
        'Suggestion of SQLs (`PostgreSQL`) to fix missing columns in tables:\n'
        '\n'
        '  CREATE INDEX IF NOT EXISTS "item__owner__idx" ON "item" ("owner") ;\n'
        '  \n'
        '  ALTER TABLE "item"  ADD CONSTRAINT "item_kind__check" '
        "ENUM('admin','guest','unknown') ;\n",
      ),
    );
  });

  test('all present: OK', () async {
    var p = _Provider({
      ..._baseSchemes,
      'item': TableScheme(
        'item',
        idFieldName: 'id',
        fieldsTypes: {
          'id': int,
          'code': String,
          'title': String,
          'kind': String,
          'owner': int,
        },
        fieldsReferencedTables: {
          'owner': TableFieldReference(
            'item',
            'owner',
            int,
            'owner',
            'id',
            int,
            indexName: 'item__owner__idx',
          ),
        },
        relationshipTables: [_itemTags(sourceIndex: 'i1', targetIndex: 'i2')],
        constraints: [
          TableUniqueConstraint('code'),
          TableEnumConstraint('kind', ['admin', 'guest', 'unknown']),
        ],
      ),
    });

    expect(await _checkError(p.adapter), isNull);
    expect(p.adapter.checkedTables, isTrue);
  });

  for (var enumConstraint in [
    null,
    TableEnumConstraint('kind', ['admin']),
  ]) {
    var missing = enumConstraint == null ? 'enum CHECK' : 'enum values';

    test('only the $missing missing: described in the error', () async {
      var p = _Provider({
        ..._baseSchemes,
        'item': TableScheme(
          'item',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'code': String,
            'title': String,
            'kind': String,
            'owner': int,
          },
          fieldsReferencedTables: {
            'owner': TableFieldReference(
              'item',
              'owner',
              int,
              'owner',
              'id',
              int,
              indexName: 'item__owner__idx',
            ),
          },
          relationshipTables: [_itemTags(sourceIndex: 'i1', targetIndex: 'i2')],
          constraints: [TableUniqueConstraint('code'), ?enumConstraint],
        ),
      });

      var error = await _checkError(p.adapter);
      expect(p.adapter.checkedTables, isFalse);

      expect(
        error,
        contains(
          enumConstraint == null
              ? '  -- missingEnumConstraints: [RoleType kind]'
              : '  -- missingEnumValues: [kind: guest, unknown]',
        ),
      );
    });
  }
}
