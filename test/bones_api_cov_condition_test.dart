@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicInt;
import 'package:test/test.dart';

/// A non-`Map`, non-`Iterable` parameters object (converted with `toJson`).
class _Point {
  final int x;
  final int y;

  _Point(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// Only a type for the [_Schemes] field types and tables.
class _RoleRef {}

class _OtherRef {}

class _NoTableRef {}

enum _Color { red, green, blue }

/// A [GroupCondition] unknown to the encoders.
class _XorGroup extends GroupCondition<Object?> {
  _XorGroup(super.conditions);

  @override
  Condition<T> cast<T>() => throw UnimplementedError();

  @override
  bool matchesEntity(
    Object? o, {
    EntityHandler<Object?>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => false;

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<Object?>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => false;

  @override
  String encode() => 'xor(${conditions.join(', ')})';
}

/// A [KeyCondition] unknown to the encoders.
class _LikeKey extends KeyCondition<Object?, Object?> {
  _LikeKey(super.keys, super.value);

  @override
  Condition<T> cast<T>() => throw UnimplementedError();

  @override
  bool matchesEntity(
    Object? o, {
    EntityHandler<Object?>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => false;

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<Object?>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => false;

  @override
  String encode() => '$encodeKey ~~ $value';
}

/// A [SchemeProvider] over fixed schemes: field types by `table.field`
/// ([fieldTypes]) and tables by type ([typeTables]).
class _Schemes extends SchemeProvider {
  final Map<String, TableScheme> schemes;
  final Map<String, TypeInfo> fieldTypes;
  final Map<Type, String> typeTables;

  _Schemes(
    this.schemes, {
    this.fieldTypes = const {},
    this.typeTables = const {},
  });

  @override
  TableScheme? getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) => schemes[table];

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) =>
      schemes[table]?.fieldsTypes;

  @override
  String? getTableForType(TypeInfo type) => typeTables[type.type];

  @override
  FutureOr<TypeInfo?> getFieldType(
    String field, {
    String? entityName,
    String? tableName,
  }) => fieldTypes['${tableName ?? entityName}.$field'];

  @override
  Object? getEntityID(
    Object entity, {
    String? entityName,
    String? tableName,
    Type? entityType,
    EntityHandler? entityHandler,
  }) => entity is Map ? entity['id'] : null;
}

final _userRoles = TableRelationshipReference(
  'user__roles__rel',
  'user',
  'id',
  int,
  'user_id',
  'role',
  'id',
  int,
  'role_id',
);

_Schemes _schemes() => _Schemes(
  {
    'user': TableScheme(
      'user',
      idFieldName: 'id',
      fieldsTypes: {'id': int, 'name': String, 'address': int, 'ghost': int},
      fieldsReferencedTables: {
        'address': TableFieldReference(
          'user',
          'address',
          int,
          'address',
          'id',
          int,
        ),
        'ghost': TableFieldReference('user', 'ghost', int, 'ghost', 'id', int),
      },
      relationshipTables: [_userRoles],
    ),
    'address': TableScheme(
      'address',
      idFieldName: 'id',
      fieldsTypes: {'id': int, 'city': String, 'value': Decimal},
    ),
    'role': TableScheme(
      'role',
      idFieldName: 'id',
      fieldsTypes: {'id': int, 'name': String},
    ),
    'item': TableScheme(
      'item',
      idFieldName: 'code',
      fieldsTypes: {'code': String, 'title': String},
    ),
  },
  fieldTypes: {
    'user.roles': TypeInfo<_RoleRef>(_RoleRef),
    'user.others': TypeInfo<_OtherRef>(_OtherRef),
    'user.notable': TypeInfo<_NoTableRef>(_NoTableRef),
  },
  typeTables: {_RoleRef: 'role', _OtherRef: 'other'},
);

ConditionSQLEncoder _encoder([_Schemes? schemes]) =>
    ConditionSQLEncoder(schemes ?? _schemes(), sqlElementQuote: '"');

Future<EncodingContext> _encode(
  String condition,
  String entityName, {
  Map<String, Object?>? namedParameters,
}) async => _encoder().encode(
  Condition.parse(condition),
  entityName,
  namedParameters: namedParameters,
);

void main() {
  group('ConditionParameter', () {
    test('getValue: parameters object (toJson)', () {
      expect(
        ConditionParameter.key('y').getValue(parameters: _Point(1, 2)),
        equals(2),
      );
    });

    test('getValue: a Map with non-String keys', () {
      expect(
        ConditionParameter.key('1').getValue(parameters: {1: 'one', 2: 'two'}),
        equals('one'),
      );
    });

    test('getValue: an Iterable that is not a List', () {
      expect(
        ConditionParameter.index(1).getValue(parameters: {10, 20, 30}),
        equals(20),
      );
      expect(
        ConditionParameter.index(5).getValue(parameters: {10, 20, 30}),
        isNull,
      );
    });

    test('getValue: by position over named parameters', () {
      expect(
        ConditionParameter.index(1).getValue(namedParameters: {'a': 1, 'b': 2}),
        equals(2),
      );
      expect(
        ConditionParameter.index(3).getValue(namedParameters: {'a': 1}),
        isNull,
      );
    });

    test('getValue: context key', () {
      var p = ConditionParameter()..contextKey = 'k';
      expect(p.getValue(namedParameters: {'k': 5}), equals(5));
      expect(p.getValue(encodingParameters: {'k': 6}), equals(6));
      expect(p.getValue(namedParameters: {'k': null}), isNull);

      // Unresolved and without a context key:
      expect(ConditionParameter().getValue(namedParameters: {'a': 1}), isNull);
    });

    test('matches: iterables', () {
      var p = ConditionParameter.key('a');
      expect(
        p.matches(
          [1, 2],
          namedParameters: {
            'a': [1, 2],
          },
        ),
        isTrue,
      );
      expect(
        p.matches(
          [2, 1],
          namedParameters: {
            'a': [1, 2],
          },
        ),
        isFalse,
      );
      expect(
        p.matches(
          2,
          namedParameters: {
            'a': [1, 2],
          },
        ),
        isTrue,
      );
      expect(
        p.matches(
          3,
          namedParameters: {
            'a': [1, 2],
          },
        ),
        isFalse,
      );
      expect(p.matches([3, 2], namedParameters: {'a': 2}), isTrue);
      expect(p.matches([3, 4], namedParameters: {'a': 2}), isFalse);
      expect(
        p.matches(
          ConditionParameter.key('b'),
          namedParameters: {'a': 1, 'b': 1},
        ),
        isTrue,
      );
    });

    test('comparisons against another parameter', () {
      var a = ConditionParameter.key('a');
      var b = ConditionParameter.key('b');
      var params = {'a': 5, 'b': 3};

      expect(a.greaterThan(b, namedParameters: params), isTrue);
      expect(a.greaterThanOrEqual(b, namedParameters: params), isTrue);
      expect(a.lessThan(b, namedParameters: params), isFalse);
      expect(a.lessThanOrEqual(b, namedParameters: params), isFalse);
      expect(b.lessThan(a, namedParameters: params), isTrue);
      expect(b.lessThanOrEqual(a, namedParameters: params), isTrue);
    });

    test('matchesIn', () {
      var a = ConditionParameter.key('a');
      var b = ConditionParameter.key('b');

      expect(
        a.matchesIn(
          [b, 9],
          namedParameters: {
            'a': [1, 2],
            'b': 2,
          },
        ),
        isTrue,
      );
      expect(
        a.matchesIn(
          [b, 9],
          namedParameters: {
            'a': [1, 2],
            'b': 3,
          },
        ),
        isFalse,
      );
      expect(a.matchesIn([b], namedParameters: {'a': 3, 'b': 3}), isTrue);
      expect(a.matchesIn([b, 4], namedParameters: {'a': 3, 'b': 5}), isFalse);
    });

    test('toString, toJson, ==, hashCode', () {
      expect(ConditionParameter.key('').toString(), equals('?:'));
      expect(ConditionParameter.key('k').toString(), equals('?:k'));
      expect(ConditionParameter.index(-1).toString(), equals('?#'));
      expect(ConditionParameter.index(2).toString(), equals('?#2'));
      expect(ConditionParameter().toString(), equals('?'));

      expect(
        ConditionParameter.key('k').toJson(),
        equals({'ConditionParameter': ':k'}),
      );
      expect(
        ConditionParameter.index(2).toJson(),
        equals({'ConditionParameter': '#2'}),
      );
      expect(
        ConditionParameter().toJson(),
        equals({'ConditionParameter': '?'}),
      );

      expect(ConditionParameter.key('k'), equals(ConditionParameter.key('k')));
      expect(
        ConditionParameter.key('k').hashCode,
        equals(ConditionParameter.key('k').hashCode),
      );
      expect(
        ConditionParameter.index(1),
        isNot(equals(ConditionParameter.index(2))),
      );
    });

    test('Condition.encodeConditionValue with parameters', () {
      expect(
        Condition.encodeConditionValue([
          ConditionParameter.index(-1),
          ConditionParameter.index(3),
          ConditionParameter.key(''),
          ConditionParameter.key('x'),
          ConditionParameter(),
        ]),
        equals('[?#,?#3,?:,?:x,?]'),
      );
    });
  });

  group('Condition values', () {
    final c = KeyConditionEQ<Map>(ConditionKey.parse('a'), 1);
    final p = ConditionParameter.key('p');

    test('greaterThan', () {
      expect(
        c.greaterThanConditionValue(p, 1, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(
        c.greaterThanConditionValue(3, p, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(c.greaterThanConditionValue(3, 2), isTrue);
      expect(c.greaterThanConditionValue(2, 3), isFalse);
    });

    test('greaterThanOrEqual', () {
      expect(
        c.greaterThanOrEqualConditionValue(p, 2, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(
        c.greaterThanOrEqualConditionValue(2, p, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(c.greaterThanOrEqualConditionValue(2, 2), isTrue);
      expect(c.greaterThanOrEqualConditionValue(1, 2), isFalse);
    });

    test('lessThan', () {
      expect(c.lessThanConditionValue(p, 3, namedParameters: {'p': 2}), isTrue);
      expect(c.lessThanConditionValue(1, p, namedParameters: {'p': 2}), isTrue);
      expect(c.lessThanConditionValue(1, 2), isTrue);
      expect(c.lessThanConditionValue(2, 1), isFalse);
    });

    test('lessThanOrEqual', () {
      expect(
        c.lessThanOrEqualConditionValue(p, 2, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(
        c.lessThanOrEqualConditionValue(2, p, namedParameters: {'p': 2}),
        isTrue,
      );
      expect(c.lessThanOrEqualConditionValue(2, 2), isTrue);
      expect(c.lessThanOrEqualConditionValue(3, 2), isFalse);
    });

    test('equals', () {
      expect(c.equalsConditionValue(p, 2, namedParameters: {'p': 2}), isTrue);
      expect(c.equalsConditionValue(2, p, namedParameters: {'p': 2}), isTrue);
      expect(c.equalsConditionValue(2, p, namedParameters: {'p': 3}), isFalse);
      expect(c.equalsConditionValue('x', 'x'), isTrue);
    });

    test('in', () {
      expect(c.inConditionValues(p, [1, 2], namedParameters: {'p': 2}), isTrue);
      expect(
        c.inConditionValues([1, 2], [p], namedParameters: {'p': 2}),
        isTrue,
      );
      expect(
        c.inConditionValues([1, 2], [p], namedParameters: {'p': 5}),
        isFalse,
      );
      expect(c.inConditionValues([1, 2], [5, 2]), isTrue);
      expect(c.inConditionValues([1, 2], [5]), isFalse);
      expect(c.inConditionValues(3, [p], namedParameters: {'p': 3}), isTrue);
      expect(c.inConditionValues(3, [1, 3]), isTrue);
      expect(c.inConditionValues(3, [1]), isFalse);
    });
  });

  group('Conditions', () {
    test('GroupCondition from a non-List Iterable', () {
      var g = GroupConditionAND(<Condition>{
        KeyConditionEQ(ConditionKey.parse('a'), 1),
        KeyConditionEQ(ConditionKey.parse('b'), 2),
      });
      expect(g.conditions, hasLength(2));
      expect(g.encode(), equals('( a == 1 && b == 2 )'));
      expect(g.conditions.first.parent, same(g));
    });

    test('ConditionANY', () {
      var c = ConditionANY<Map>();
      var c2 = c.cast<int>();
      expect(c2, isA<ConditionANY<int>>());
      expect(c2, isNot(same(c)));
      expect(identical(c.cast<Map>(), c), isTrue);

      var parameters = <ConditionParameter>[];
      c.resolve(parameters: parameters);
      expect(c.resolved, isTrue);
      expect(parameters, isEmpty);

      expect(c.matchesEntity({'x': 1}), isTrue);
      expect(c.matchesEntityMap({'x': 1}), isTrue);
      expect(c.encode(), equals('true'));
    });

    test('ConditionID', () {
      expect(
        ConditionID<Map>().resolveIDValue(parameters: {'id': 5}),
        equals(5),
      );
      expect(
        ConditionID<Map>(
          ConditionParameter.key('id'),
        ).resolveIDValue(parameters: {'id': 7}),
        equals(7),
      );
      expect(ConditionID<Map>(9).resolveIDValue(), equals(9));

      expect(ConditionID<Map>(5).matchesEntity({'id': 5}), isTrue);
      expect(ConditionID<Map>(5).matchesEntity({'id': 6}), isFalse);
      expect(ConditionID<Map>(5).matchesEntityMap({'id': 5}), isTrue);
      expect(
        ConditionID<Map>(
          ConditionParameter.key('x'),
        ).matchesEntityMap({'id': 5}, namedParameters: {'x': 5}),
        isTrue,
      );

      expect(ConditionID(5).encode(), equals('#ID == 5'));
      expect(ConditionID().encode(), equals('#ID == ?'));
      expect(ConditionID(5).isIDCondition, isTrue);
    });

    test('ConditionIdIN', () {
      var c = ConditionIdIN<Map>([1, ConditionParameter.key('x')]);
      expect(c.isIDCondition, isTrue);
      expect(c.encode(), equals('#ID =~ [1,?:x]'));

      var c2 = c.cast<int>();
      expect(c2, isA<ConditionIdIN<int>>());
      expect(c2, isNot(same(c)));
      expect(c2.idsValues, equals(c.idsValues));
      expect(identical(c.cast<Map>(), c), isTrue);

      var parameters = <ConditionParameter>[];
      c.resolve(parameters: parameters);
      expect(c.resolved, isTrue);
      expect(c.parameters, equals([ConditionParameter.key('x')]));

      expect(c.matchesEntity({'id': 1}), isTrue);
      expect(c.matchesEntity({'id': 9}, namedParameters: {'x': 9}), isTrue);
      expect(c.matchesEntity({'id': 3}, namedParameters: {'x': 9}), isFalse);
      expect(c.matchesEntityMap({'id': 1}), isTrue);
      expect(c.matchesEntityMap({'id': 4}, namedParameters: {'x': 9}), isFalse);
    });

    test('ConditionKey.parse', () {
      expect(() => ConditionKey.parse('  '), throwsArgumentError);

      var keys = ConditionKey.parse('"a b".\'c\'.d[2]');
      expect(keys, hasLength(4));
      expect((keys[0] as ConditionKeyField).name, equals('a b'));
      expect((keys[1] as ConditionKeyField).name, equals('c'));
      expect((keys[2] as ConditionKeyField).name, equals('d'));
      expect((keys[3] as ConditionKeyIndex).index, equals(2));

      expect(keys[0].isWordKey, isFalse);
      expect(keys[0].toString(), equals('"a b"'));
      expect(keys[2].isWordKey, isTrue);
      expect(keys[3].isWordKey, isFalse);
      expect(keys[3].toString(), equals('[2]'));
    });

    test('KeyCondition: invalid keys', () {
      expect(() => KeyConditionEQ([], 1), throwsArgumentError);
      expect(
        () => KeyConditionEQ([ConditionKeyIndex(0)], 1),
        throwsArgumentError,
      );
    });

    test('KeyCondition: an index key (entity)', () {
      var c = KeyConditionEQ<Map>(ConditionKey.parse('list[1]'), 'b');
      expect(
        c.matchesEntity({
          'list': ['a', 'b'],
        }),
        isTrue,
      );
      expect(
        c.matchesEntity({
          'list': ['b', 'a'],
        }),
        isFalse,
      );
      expect(c.matchesEntity({'other': 1}), isFalse);

      expect(
        () => KeyConditionEQ<Map>(
          ConditionKey.parse('a[0]'),
          1,
        ).matchesEntity({'a': 5}),
        throwsStateError,
      );
    });

    test('KeyCondition: entity map paths', () {
      // An iterable of maps:
      expect(
        KeyConditionIN<Map>(ConditionKey.parse('items.n'), [
          2,
        ]).matchesEntityMap({
          'items': [
            {'n': 1},
            {'n': 2},
          ],
        }),
        isTrue,
      );

      // An iterable of values (no entity handler): the values themselves.
      expect(
        KeyConditionIN<Map>(ConditionKey.parse('list.x'), [2]).matchesEntityMap(
          {
            'list': [1, 2],
          },
        ),
        isTrue,
      );
      expect(
        KeyConditionIN<Map>(ConditionKey.parse('list.x'), [5]).matchesEntityMap(
          {
            'list': [1, 2],
          },
        ),
        isFalse,
      );

      // A nested map:
      expect(
        KeyConditionEQ<Map>(ConditionKey.parse('a.b'), 1).matchesEntityMap({
          'a': {'b': 1},
        }),
        isTrue,
      );

      // An index:
      expect(
        KeyConditionEQ<Map>(ConditionKey.parse('list[1]'), 20).matchesEntityMap(
          {
            'list': [10, 20],
          },
        ),
        isTrue,
      );

      // An empty list value:
      expect(
        KeyConditionEQ<Map>(
          ConditionKey.parse('a'),
          1,
        ).matchesEntityMap({'a': []}),
        isFalse,
      );

      // A missing key and an empty map:
      expect(
        KeyConditionEQ<Map>(
          ConditionKey.parse('a.b'),
          1,
        ).matchesEntityMap({'x': 1}),
        isFalse,
      );
      expect(
        KeyConditionEQ<Map>(ConditionKey.parse('a'), null).matchesEntityMap({}),
        isTrue,
      );

      // A field of a primitive, and an index of a non-iterable:
      expect(
        () => KeyConditionEQ<Map>(
          ConditionKey.parse('a.b'),
          1,
        ).matchesEntityMap({'a': 5}),
        throwsStateError,
      );
      expect(
        () => KeyConditionEQ<Map>(
          ConditionKey.parse('a[0]'),
          1,
        ).matchesEntityMap({'a': 5}),
        throwsStateError,
      );
    });

    test('KeyCondition comparisons: cast, matchesEntity, encode', () {
      var gt = KeyConditionGreaterThan<Map>(ConditionKey.parse('n'), 3);
      var gte = KeyConditionGreaterThanOrEqual<Map>(ConditionKey.parse('n'), 3);
      var lt = KeyConditionLessThan<Map>(ConditionKey.parse('n'), 3);
      var lte = KeyConditionLessThanOrEqual<Map>(ConditionKey.parse('n'), 3);
      var notIn = KeyConditionNotIN<Map>(ConditionKey.parse('n'), [1, 3]);

      expect(gt.encode(), equals('n > 3'));
      expect(gte.encode(), equals('n >= 3'));
      expect(lt.encode(), equals('n < 3'));
      expect(lte.encode(), equals('n <= 3'));
      expect(notIn.encode(), equals('n !~ [1,3]'));

      for (var (c, n, expected) in [
        (gt, 4, true),
        (gt, 3, false),
        (gte, 3, true),
        (gte, 2, false),
        (lt, 2, true),
        (lt, 3, false),
        (lte, 3, true),
        (lte, 4, false),
        (notIn, 2, true),
        (notIn, 3, false),
      ]) {
        expect(c.matchesEntity({'n': n}), expected, reason: '$c ; n: $n');
        expect(c.matchesEntityMap({'n': n}), expected, reason: '$c ; n: $n');

        var casted = c.cast<int>();
        expect(casted, isNot(same(c)));
        expect(casted.encode(), equals(c.encode()));
        expect(identical(c.cast<Map>(), c), isTrue);
      }

      expect(gt.cast<int>(), isA<KeyConditionGreaterThan<int>>());
      expect(gte.cast<int>(), isA<KeyConditionGreaterThanOrEqual<int>>());
      expect(lt.cast<int>(), isA<KeyConditionLessThan<int>>());
      expect(lte.cast<int>(), isA<KeyConditionLessThanOrEqual<int>>());
      expect(notIn.cast<int>(), isA<KeyConditionNotIN<int>>());
    });

    test('KeyConditionINBase.valuesAsList', () {
      expect(KeyConditionINBase.valuesAsList(null), equals([null]));
      expect(KeyConditionINBase.valuesAsList([1, 2]), equals([1, 2]));
      expect(KeyConditionINBase.valuesAsList({1, 2}), equals([1, 2]));
      expect(KeyConditionINBase.valuesAsList({'a': 1, 'b': 2}), equals([1, 2]));
      expect(KeyConditionINBase.valuesAsList(3), equals([3]));
    });

    test('ConditionParseCache', () {
      var cache = ConditionParseCache<_Point>();
      expect(identical(cache, ConditionParseCache.get<_Point>()), isTrue);

      var first = cache.parseQuery('n == 0');
      expect(identical(cache.parseQuery('n == 0'), first), isTrue);

      // More than 500 cached: the oldest 100 are evicted.
      for (var i = 1; i <= 501; ++i) {
        cache.parseQuery('n == $i');
      }

      var again = cache.parseQuery('n == 0');
      expect(identical(again, first), isFalse);
      expect(again.encode(), equals('n == 0'));
    });

    test('ConditionQuery', () {
      const q = ConditionQuery<Map>('n > 2');
      expect(q.query, equals('n > 2'));
      expect(q.condition.encode(), equals('n > 2'));
      expect(
        identical(q.condition, ConditionQuery.parse<Map>('n > 2')),
        isTrue,
      );
      expect(q.matchesEntity({'n': 3}), isTrue);
      expect(q.matchesEntity({'n': 2}), isFalse);
      expect(q.matchesEntityMap({'n': 1}), isFalse);
      expect(q.matchesEntityMap({'n': 5}), isTrue);
    });
  });

  group('TableScheme / references', () {
    test('TableRelationshipReference: ==, hashCode, typed copy', () {
      var r1 = TableRelationshipReference(
        'a__bs__rel',
        'a',
        'id',
        int,
        'a_id',
        'b',
        'id',
        int,
        'b_id',
        sourceRelationshipFieldIndex: 'idx_a',
        targetRelationshipFieldIndex: '',
      );
      var r2 = TableRelationshipReference(
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

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1.sourceRelationshipFieldIndex, equals('idx_a'));
      expect(r1.targetRelationshipFieldIndex, isNull);
      expect(
        r1.toString(),
        equals(
          'TableRelationshipReference[a__bs__rel]{"a"."id"(int) -> "b"."id"(int)}id@idx_a',
        ),
      );

      var typed = r1.copyWithEntityTypes(TypeInfo.tString, TypeInfo.tInt);
      expect(typed.sourceFieldEntityType, equals(TypeInfo.tString));
      expect(typed.targetFieldEntityType, equals(TypeInfo.tInt));
      expect(typed, equals(r1));
      expect(
        typed.toString(),
        equals(
          'TableRelationshipReferenceEntityTyped[a__bs__rel]{"a"."id"(int @ <T:String> String) -> "b"."id"(int @ <T:int> int)}id@idx_a',
        ),
      );
    });

    test('TableFieldReference', () {
      var r = TableFieldReference(
        'a',
        'b',
        int,
        'b',
        'id',
        int,
        indexName: 'i',
      );
      expect(r.indexName, equals('i'));
      expect(r.toString(), endsWith('@i'));
      expect(
        TableFieldReference(
          'a',
          'b',
          int,
          'b',
          'id',
          int,
          indexName: '',
        ).indexName,
        isNull,
      );
    });

    TableScheme schemeWithRels(List<String> relTables) => TableScheme(
      'user',
      idFieldName: 'id',
      fieldsTypes: {'id': int},
      relationshipTables: [
        for (var t in relTables)
          TableRelationshipReference(
            t,
            'user',
            'id',
            int,
            'user_id',
            'role',
            'id',
            int,
            'role_id',
          ),
      ],
    );

    test('getTableRelationshipReference', () {
      var s = schemeWithRels(['user__roles__rel']);
      expect(s.tableRelationshipReferenceLength, equals(1));
      expect(s.hasTableReferences, isTrue);

      expect(
        () => s.getTableRelationshipReference(sourceField: 'x'),
        throwsArgumentError,
      );

      // By target:
      expect(
        s.getTableRelationshipReference(targetTable: 'role')?.relationshipTable,
        equals('user__roles__rel'),
      );
      // Not by target, but by source:
      expect(
        s
            .getTableRelationshipReference(
              sourceTable: 'role',
              targetTable: 'x',
            )
            ?.relationshipTable,
        equals('user__roles__rel'),
      );
      // None:
      expect(
        s.getTableRelationshipReference(sourceTable: 'x', targetTable: 'y'),
        isNull,
      );
    });

    test('getTableRelationshipReference: ambiguous', () {
      var s = schemeWithRels(['user__roles__rel', 'user__admin_roles__rel']);

      // A different case of the source table, and no field: ambiguous.
      expect(
        () => s.getTableRelationshipReference(
          sourceTable: 'User',
          targetTable: 'role',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Ambiguous relationship tables for User.? -> role'),
          ),
        ),
      );

      // The field in the relationship table name:
      expect(
        s
            .getTableRelationshipReference(
              sourceTable: 'user',
              sourceField: 'adminRoles',
              targetTable: 'role',
            )
            ?.relationshipTable,
        equals('user__admin_roles__rel'),
      );
    });

    test('getTableRelationshipReference: field in many names', () {
      var s = schemeWithRels(['user__roles__rel', 'user__roles__rel2']);

      var rel = s.getTableRelationshipReference(
        sourceTable: 'user',
        sourceField: 'roles',
        targetTable: 'role',
      );
      expect(rel?.relationshipTable, equals('user__roles__rel'));
    });

    test('constraints', () {
      var e1 = TableEnumConstraint('type', ['a', 'b']);
      var e2 = TableEnumConstraint('type', ['b', 'a']);
      var e3 = TableEnumConstraint('type', ['a']);

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
      expect(e1.toString(), equals('TableEnumConstraint(type){a, b}'));

      expect(
        TablePrimaryKeyConstraint('id').toString(),
        equals('TablePrimaryKeyConstraint(id)'),
      );
      expect(
        TableUniqueConstraint('email').toString(),
        equals('TableUniqueConstraint(email)'),
      );
      expect(TableUniqueConstraint('a'), equals(TableUniqueConstraint('a')));
      expect(
        TableUniqueConstraint('a').hashCode,
        equals(TableUniqueConstraint('a').hashCode),
      );

      var sorted = [
        e1,
        TableUniqueConstraint('b'),
        TablePrimaryKeyConstraint('id'),
        TableUniqueConstraint('a'),
      ]..sort();
      expect(sorted.map((e) => '${e.runtimeType}:${e.field}').toList(), [
        'TablePrimaryKeyConstraint:id',
        'TableUniqueConstraint:a',
        'TableUniqueConstraint:b',
        'TableEnumConstraint:type',
      ]);

      var s = TableScheme(
        't',
        idFieldName: 'id',
        fieldsTypes: {'id': int, 'type': String},
        constraints: [TablePrimaryKeyConstraint('id'), e1],
      );
      expect(s.toString(), contains('\n-- TableEnumConstraint(type){a, b}'));
      expect(
        [TableUniqueConstraint('a'), e1].toFields(fieldMap: {'a': 'fieldA'}),
        equals(['fieldA', 'type']),
      );
    });
  });

  group('SchemeProvider', () {
    test('selectIDFieldName', () {
      var p = _schemes();
      expect(p.selectIDFieldName('t', []), equals('id'));
      expect(p.selectIDFieldName('t', ['pk']), equals('pk'));
      expect(p.selectIDFieldName('t', ['a', 'ID']), equals('ID'));
      expect(p.selectIDFieldName('t', ['x', 'user_id']), equals('user_id'));
      expect(p.selectIDFieldName('t', ['x', 'CODE']), equals('CODE'));
      expect(p.selectIDFieldName('t', ['x', 'serial']), equals('serial'));
      expect(p.selectIDFieldName('t', ['x', 'y']), equals('x'));
    });

    test('getTableSchemeForType / fields types / dispose', () async {
      var p = _schemes();

      var s = await p.getTableSchemeForType(TypeInfo<_RoleRef>(_RoleRef));
      expect(s?.name, equals('role'));
      expect(
        await p.getTableSchemeForType(TypeInfo<_NoTableRef>(_NoTableRef)),
        isNull,
      );

      expect(p.getTableSchemeIfLoaded('role'), same(s));
      expect(
        await p.getTableFieldsTypes('role'),
        equals({'id': int, 'name': String}),
      );
      expect(await p.getTableFieldsTypes('item'), containsPair('code', String));
      expect(await p.getTableFieldsTypes('nope'), isNull);

      expect(p.disposeTableSchemeCache('role', fieldsTypes: true), same(s));
      expect(p.getTableSchemeIfLoaded('role'), isNull);

      await p.getTableScheme('user');
      p.disposeTablesSchemesCaches(fieldsTypes: true);
      expect(p.getTableSchemeIfLoaded('user'), isNull);
    });
  });

  group('EncodingContext', () {
    test('resolveEntityAlias: taken prefixes', () {
      var context = EncodingContext('ab');
      context.tableAliases['e0'] = 'ab';
      expect(context.resolveEntityAlias('ab'), equals('a1'));
      expect(context.resolveEntityAlias('ab'), equals('a1'));

      var context2 = EncodingContext('ab');
      context2.tableAliases['e0'] = 'ab';
      for (var i = 1; i <= 9; ++i) {
        context2.tableAliases['ea$i'] = 'a$i';
      }
      expect(context2.resolveEntityAlias('ab'), equals('t1'));

      var context3 = EncodingContext('tb');
      context3.tableAliases['e0'] = 'tb';
      for (var i = 1; i <= 9; ++i) {
        context3.tableAliases['et$i'] = 't$i';
      }
      expect(context3.resolveEntityAlias('tb'), equals('alias1'));

      expect(EncodingContext('x').resolveEntityAlias(''), equals('alias1'));

      // A reserved word isn't an alias:
      expect(EncodingContext('x').resolveEntityAlias('asset'), equals('ass'));
      expect(context.isValidAlias('as'), isFalse);
      expect(context.isValidAlias('ab'), isTrue);
    });

    test('addEncodingParameter', () {
      var context = EncodingContext(
        'user',
        namedParameters: {'id': 1, 'param_id': 2},
      );

      expect(context.addEncodingParameter('name', 'x'), equals('name'));
      expect(context.addEncodingParameter('id', 10), equals('param_id1'));
      expect(
        context.encodingParameters,
        equals({'name': 'x', 'param_id1': 10}),
      );

      var context2 = EncodingContext('user', namedParameters: {'id': 1});
      expect(context2.addEncodingParameter('id', 10), equals('param_id'));
      expect(
        context2.addEncodingParameter('id', 11, parameterPrefix: 'p_'),
        equals('p_id'),
      );
    });

    test('pruneUnusedParametersPlaceholders', () {
      var encoder = _encoder();

      EncodingContext context(String output) {
        var c = EncodingContext('t');
        c.parametersPlaceholders['level'] = null;
        c.parametersPlaceholders['other'] = 1;
        c.markPlaceholderInlinedAsNull('level');
        c.markPlaceholderInlinedAsNull('missing');
        c.write(output);
        return c;
      }

      // Only a longer placeholder (`@level_0`): unused.
      var c1 = context('x IN ( @level_0 ) AND y IS NULL');
      encoder.pruneUnusedParametersPlaceholders(c1);
      expect(c1.parametersPlaceholders, equals({'other': 1}));

      // Also used as itself:
      var c2 = context('x = @level_0 AND z = @level AND y IS NULL');
      encoder.pruneUnusedParametersPlaceholders(c2);
      expect(c2.parametersPlaceholders.keys, containsAll(['level', 'other']));

      // At the end of the output:
      var c3 = context('z = @level');
      encoder.pruneUnusedParametersPlaceholders(c3);
      expect(c3.parametersPlaceholders.keys, contains('level'));

      expect(c3.nullInlinedPlaceholders, containsAll(['level', 'missing']));
    });
  });

  group('ConditionEncoder', () {
    test('unknown conditions', () async {
      var encoder = _encoder();

      expect(
        () async => await encoder.encode(
          _XorGroup([KeyConditionEQ(ConditionKey.parse('name'), 'a')]),
          'user',
        ),
        throwsA(isA<ConditionEncodingError>()),
      );

      expect(
        () async => await encoder.encode(
          _LikeKey(ConditionKey.parse('name'), 'a'),
          'user',
        ),
        throwsA(
          isA<ConditionEncodingError>().having(
            (e) => e.toString(),
            'toString',
            equals('Encoding error: name ~~ a'),
          ),
        ),
      );
    });

    test('resolveValueToType: enums, lists', () async {
      var encoder = _encoder();

      expect(await encoder.resolveValueToType(_Color.green, String), 'green');
      expect(await encoder.resolveValueToType(_Color.green, int), 1);
      expect(await encoder.resolveValueToType(_Color.red, int), 0);
      expect(await encoder.resolveValueToType(_Color.blue, num), 2);
      expect(await encoder.resolveValueToType(_Color.blue, double), 2.0);
      expect(await encoder.resolveValueToType(_Color.blue, BigInt), BigInt.two);

      expect(
        await encoder.resolveValueToType(null, int, valueAsList: true),
        isEmpty,
      );
      expect(
        await encoder.resolveValueToType(['1', '2'], int, valueAsList: true),
        equals([1, 2]),
      );
      expect(
        await encoder.resolveValueToType('3', int, valueAsList: true),
        equals([3]),
      );

      // An entity to its ID (by the scheme provider):
      expect(
        await encoder.resolveValueToType({'id': 12}, _RoleRef),
        equals(12),
      );
    });

    test('encoding values', () {
      var encoder = _encoder();

      var nul = EncodingValueNull<String>(
        'k',
        int,
        encoder.encodeEncodingValueNull,
      );
      expect(nul.encode, equals('null'));
      expect(nul.resolvedValue, isNull);
      expect(nul.toString(), equals('null'));
      expect(nul.asList, equals([nul]));

      var text = EncodingValueText<String>(
        'k',
        String,
        "it's",
        encoder.encodeEncodingValueText,
      );
      expect(text.encode, equals("'it\\'s'"));

      var p1 = EncodingPlaceholderIndex<String>(
        'k',
        int,
        '@k__0',
        0,
        encoder.encodeEncodingPlaceholderIndex,
      );
      var p2 = EncodingPlaceholderIndex<String>(
        'k',
        int,
        '@k__1',
        1,
        encoder.encodeEncodingPlaceholderIndex,
      );
      var inner = EncodingValueList<String>('k', int, [
        p1,
        p2,
      ], encoder.encodeEncodingValueList);
      var list = EncodingValueList<String>('k', int, [
        inner,
        nul,
      ], encoder.encodeEncodingValueList);
      expect(list.asList, equals([p1, p2, nul]));
      expect(list.encode, equals('( ( @k__0 , @k__1 ) , null )'));

      var empty = EncodingValueList<String>(
        'k',
        int,
        [],
        encoder.encodeEncodingValueList,
      );
      expect(empty.encode, equals('( null )'));
    });
  });

  group('ConditionSQLEncoder', () {
    test('operators', () async {
      var sql = await _encode(
        'name != "a" && id > 1 && id >= 2 && id < 3 && id <= 4 && id !~ [5, 6]',
        'user',
      );
      expect(
        sql.outputString,
        equals(
          '( "us"."name" != \'a\' AND "us"."id" > 1 AND "us"."id" >= 2 AND '
          '"us"."id" < 3 AND "us"."id" <= 4 AND "us"."id" NOT IN ( 5 , 6 ) )',
        ),
      );
    });

    test('null comparisons', () async {
      var sql = await _encode('name != null', 'user');
      expect(sql.outputString, equals('( "us"."name" IS NOT NULL )'));

      var sql2 = await _encode(
        'name != ? && id == ?',
        'user',
        namedParameters: {'name': null, 'id': 3},
      );
      expect(
        sql2.outputString,
        equals('( "us"."name" IS NOT NULL AND "us"."id" = @id )'),
      );
      expect(sql2.parametersPlaceholders, equals({'id': 3}));

      // An empty `IN` list: compared to null.
      var sql3 = await _encoder().encode(
        KeyConditionIN(ConditionKey.parse('id'), []),
        'user',
      );
      expect(sql3.outputString, equals('( "us"."id" IS NULL )'));
    });

    test('a group with a single condition', () async {
      var sql = await _encoder().encode(
        GroupConditionAND([
          GroupConditionOR([KeyConditionEQ(ConditionKey.parse('id'), 1)]),
        ]),
        'user',
      );
      expect(sql.outputString, equals(' "us"."id" = 1 '));
    });

    test('ID conditions', () async {
      var sql = await _encoder().encode(ConditionID(10), 'item');
      expect(sql.outputString, equals('( "it"."code" = \'10\' )'));

      var sql2 = await _encoder().encode(ConditionIdIN(['a', 'b']), 'item');
      expect(sql2.outputString, equals('( "it"."code" IN ( \'a\' , \'b\' ) )'));

      expect(
        () async => await _encoder().encode(ConditionID(1), 'nope'),
        throwsStateError,
      );
      expect(
        () async => await _encoder().encode(ConditionIdIN([1]), 'nope'),
        throwsStateError,
      );
    });

    test('values: Set, Decimal, DynamicInt, DateTime', () async {
      var sql = await _encoder().encode(
        KeyConditionIN(ConditionKey.parse('id'), {7, 8}),
        'user',
      );
      expect(sql.outputString, equals('( "us"."id" IN ( 7 , 8 ) )'));

      var sql2 = await _encode(
        'address.value == ?',
        'user',
        namedParameters: {'value': Decimal.parse('1.5')},
      );
      expect(sql2.outputString, equals('( "ad"."value" = @value )'));
      expect(sql2.parametersPlaceholders, equals({'value': 1.5}));

      var encoder = _encoder();
      expect(
        await encoder.resolveValueToCompatibleType(Decimal.parse('2.5')),
        equals(2.5),
      );
      expect(
        await encoder.resolveValueToCompatibleType(DynamicInt.fromInt(3)),
        equals(BigInt.from(3)),
      );
      var d = DateTime.utc(2020, 1, 2);
      expect(
        await encoder.resolveValueToCompatibleType(d.toLocal()),
        equals(d),
      );
      expect(await encoder.resolveValueToCompatibleType('x'), equals('x'));
    });

    test('valueToSQL / plain values', () async {
      var encoder = _encoder();
      var context = EncodingContext('user');

      expect(await encoder.valueToSQL(context, 'x'), equals("'x'"));
      expect(await encoder.valueToSQL(context, 3, fieldType: int), equals('3'));
      expect(
        await encoder.valueToSQL(context, [1, 2, 3], valueAsList: true),
        equals('( 1 , 2 , 3 )'),
      );
      expect(
        await encoder.valueToSQL(
          context,
          ['1', '2'],
          fieldType: int,
          valueAsList: true,
        ),
        equals('( 1 , 2 )'),
      );
      expect(await encoder.valueToSQL(context, null), equals('null'));

      expect(encoder.valueToSQLPlain(null, null).encode, equals('null'));
      expect(
        encoder.valueToSQLPlain(Decimal.parse('1.5'), null).encode,
        equals('1.5'),
      );
      expect(
        encoder.valueToSQLPlain(DynamicInt.fromInt(3), null).encode,
        equals('3'),
      );
      expect(encoder.valueToSQLPlain(true, null).encode, equals('true'));
      expect(encoder.valueToParameterValueList(5, int).encode, equals('( 5 )'));

      expect(
        () => encoder.conditionParameterToParameterValue(
          ConditionParameter(),
          context,
          null,
          int,
        ),
        throwsA(isA<ConditionEncodingError>()),
      );
    });

    test('resolveFieldName', () async {
      var encoder = _encoder();
      expect(await encoder.resolveFieldName('user', 'NAME'), equals('name'));
      expect(await encoder.resolveFieldName('user', 'xyz'), equals('xyz'));
      expect(await encoder.resolveFieldName('nope', 'Name'), equals('Name'));
    });

    test('invalid keys', () async {
      var c = KeyConditionEQ(ConditionKey.parse('name'), 1);
      c.keys = [];
      expect(
        () async => await _encoder().encode(c, 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );

      var c2 = KeyConditionEQ(ConditionKey.parse('name'), 1);
      c2.keys = [ConditionKeyIndex(0)];
      expect(
        () async => await _encoder().encode(c2, 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );

      // A key path with an index:
      var c3 = KeyConditionEQ([
        ConditionKeyField('address'),
        ConditionKeyIndex(0),
        ConditionKeyField('city'),
      ], 1);
      expect(
        () async => await _encoder().encode(c3, 'user'),
        throwsA(
          isA<ConditionEncodingError>().having(
            (e) => e.message,
            'message',
            contains('key[1] is not a `ConditionKeyField`'),
          ),
        ),
      );
    });

    test('a relationship field', () async {
      var sql = await _encode('roles == 3', 'user');
      expect(sql.outputString, equals('( "u_r_r"."role_id" = 3 )'));
      expect(sql.relationshipTables, equals({'role': _userRoles}));
    });

    test('key field errors', () async {
      // No scheme:
      expect(() async => await _encode('name == 1', 'nope'), throwsStateError);
      // No field type:
      expect(
        () async => await _encode('xyz == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
      // No table for the field type:
      expect(
        () async => await _encode('notable == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
      // No relationship table to the field's table:
      expect(
        () async => await _encode('others == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
    });

    test('key path errors', () async {
      // No scheme of the root table:
      expect(() async => await _encode('a.b == 1', 'nope'), throwsStateError);
      // No field in the referenced table:
      expect(
        () async => await _encode('address.zip == 1', 'user'),
        throwsStateError,
      );
      // No scheme of the referenced table:
      expect(
        () async => await _encode('ghost.x == 1', 'user'),
        throwsStateError,
      );
      // No field type:
      expect(
        () async => await _encode('missing.x == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
      // No table for the field type:
      expect(
        () async => await _encode('notable.x == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
      // No relationship table:
      expect(
        () async => await _encode('others.x == 1', 'user'),
        throwsA(isA<ConditionEncodingError>()),
      );
    });

    test('a relationship path', () async {
      var sql = await _encode('roles.name == "admin"', 'user');
      expect(sql.outputString, equals('( "ro"."name" = \'admin\' )'));
      expect(sql.relationshipTables.keys, equals(['role']));
    });
  });
}
