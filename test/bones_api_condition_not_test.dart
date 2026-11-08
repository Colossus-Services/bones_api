import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('ConditionNOT: parse', () {
    test('a parenthesized condition, or a single comparison', () {
      for (var q in ['!(a == 1)', '!a == 1', ' ! ( a == 1 ) ', '!  a==1']) {
        var c = Condition.parse(q);
        expect(c, isA<ConditionNOT>(), reason: q);
        var inner = (c as ConditionNOT).condition;
        expect(inner, isA<KeyConditionEQ>(), reason: q);
        expect(inner.parent, same(c));
      }

      var c2 = Condition.parse('!(a == 1 || b == 2)') as ConditionNOT;
      expect(c2.condition, isA<GroupConditionOR>());

      var c3 = Condition.parse('!(a == 1 && b == 2)') as ConditionNOT;
      expect(c3.condition, isA<GroupConditionAND>());

      expect(
        (Condition.parse('!(#ID == 3)') as ConditionNOT).condition,
        isA<ConditionID>(),
      );
      expect(
        (Condition.parse('!name =~ /^x/i') as ConditionNOT).condition,
        isA<KeyConditionRegExp>(),
      );
      expect(
        (Condition.parse('!address.city == "x"') as ConditionNOT).condition,
        isA<KeyConditionEQ>(),
      );
    });

    test('precedence: `!` binds to the next comparison', () {
      var c = Condition.parse('!a == 1 && b == 2') as GroupConditionAND;
      expect(c.conditions[0], isA<ConditionNOT>());
      expect(c.conditions[1], isA<KeyConditionEQ>());

      var c2 = Condition.parse('a == 1 || !b == 2') as GroupConditionOR;
      expect(c2.conditions[0], isA<KeyConditionEQ>());
      expect(c2.conditions[1], isA<ConditionNOT>());
    });

    test('nested', () {
      var c = Condition.parse('!!(a == 1)') as ConditionNOT;
      expect(c.condition, isA<ConditionNOT>());
      expect((c.condition as ConditionNOT).condition, isA<KeyConditionEQ>());

      var c2 = Condition.parse('!(a == 1 && !(b == 2 || !c =~ /x/))');
      expect(
        c2.encode(),
        equals('!( a == 1 && !( b == 2 || !( c =~ /x/ ) ) )'),
      );

      var c3 = Condition.parse('(!(a == 1)) && (!b == 2)') as GroupConditionAND;
      expect(c3.conditions.every((e) => e is ConditionNOT), isTrue);
    });

    test('`!` with the negated operators', () {
      var c = Condition.parse('!a != 1') as ConditionNOT;
      expect(c.condition, isA<KeyConditionNotEQ>());

      var c2 = Condition.parse('!a !~ [1, 2]') as ConditionNOT;
      expect(c2.condition, isA<KeyConditionNotIN>());

      var c3 = Condition.parse('!a !~ /x/') as ConditionNOT;
      expect((c3.condition as KeyConditionRegExp).not, isTrue);

      // Not a negation:
      expect(Condition.parse('a != 1'), isA<KeyConditionNotEQ>());
      expect(Condition.parse('a !~ [1]'), isA<KeyConditionNotIN>());
    });

    test('encode -> parse round trip', () {
      for (var (q, encoded) in [
        ('!(a == 1)', '!( a == 1 )'),
        ('!a == 1', '!( a == 1 )'),
        ('!(a == 1 || b == 2)', '!( a == 1 || b == 2 )'),
        ('!(a == 1 && b == 2)', '!( a == 1 && b == 2 )'),
        ('!!(a == 1)', '!( !( a == 1 ) )'),
        ('!a == 1 && b == 2', '( !( a == 1 ) && b == 2 )'),
        ('!(a == ?) && b == ?:p', '( !( a == ? ) && b == ?:p )'),
        (r'!name =~ /^x\//i', r'!( name =~ /^x\//i )'),
        ('!(#ID == 3)', '!( #ID == 3 )'),
      ]) {
        var c = Condition.parse(q);
        expect(c.encode(), equals(encoded), reason: q);
        expect(Condition.parse(encoded).encode(), equals(encoded), reason: q);
      }
    });

    test('errors', () {
      for (var q in [
        '!',
        '!(',
        '!()',
        '!(a == 1',
        'a == !1',
        '!!',
        'a !',
        '! &&',
      ]) {
        expect(() => Condition.parse(q), throwsFormatException, reason: q);
      }
    });

    test('parameters', () {
      var c = Condition.parse('!(a == ? || b == ?:p) && c == ?');
      var not = (c as GroupConditionAND).conditions[0] as ConditionNOT;

      expect(not.parameters.map((p) => p.toString()), equals(['?', '?:p']));
      expect(c.parameters.map((p) => p.toString()), equals(['?', '?:p', '?']));

      // The positional parameters, in order:
      var a = (not.condition as GroupConditionOR).conditions[0] as KeyCondition;
      expect((a.value as ConditionParameter).contextPosition, equals(0));
      var cEq = c.conditions[1] as KeyCondition;
      expect((cEq.value as ConditionParameter).contextPosition, equals(2));
    });

    test('cast', () {
      var c = Condition.parse('!(a == 1)') as ConditionNOT;
      var c2 = c.cast<Map>();
      expect(c2, isA<ConditionNOT<Map>>());
      expect(c2.encode(), equals(c.encode()));
      expect(identical(c.cast<dynamic>(), c), isTrue);
    });
  });

  group('ConditionNOT: match', () {
    bool matches(String query, Map<String, dynamic> o, {Object? parameters}) {
      var c = Condition.parse(query);
      var m1 = c.matchesEntityMap(o, parameters: parameters);
      var m2 = c.matchesEntity(o, parameters: parameters);
      expect(m2, equals(m1), reason: 'matchesEntity != matchesEntityMap');
      return m1;
    }

    test('the complement', () {
      for (var (cond, o) in [
        ('a == 1', {'a': 1}),
        ('a == 1', {'a': 2}),
        ('a == 1', {'a': null}),
        ('a == 1', <String, dynamic>{}),
        ('a > 1', {'a': null}),
        ('a > 1', {'a': 2}),
        ('a =~ [1, 2]', {'a': 2}),
        ('a !~ [1, 2]', {'a': null}),
        ('a != 1', {'a': null}),
        (r'a =~ /^x/', {'a': 'xy'}),
        (r'a !~ /^x/', {'a': null}),
        ('a == 1 || b == 2', {'a': 0, 'b': 2}),
        ('a == 1 && b == 2', {'a': 1, 'b': 0}),
        ('x.y == 1', {'x': null}),
        (
          'x.y == 1',
          {
            'x': {'y': 1},
          },
        ),
      ]) {
        var positive = matches(cond, o);
        expect(matches('!($cond)', o), equals(!positive), reason: '$cond $o');
        expect(matches('!!($cond)', o), equals(positive), reason: '$cond $o');
      }
    });

    test('a `null` field', () {
      expect(matches('!(level == 10)', {'level': null}), isTrue);
      expect(matches('!(level > 1)', {'level': null}), isTrue);
      expect(matches('!(level == null)', {'level': null}), isFalse);
      expect(matches('!(level == null)', {'level': 1}), isTrue);
    });

    test('a list (to-many relationship): none matches', () {
      var o = {
        'roles': ['admin', 'guest'],
      };
      expect(matches('roles == "admin"', o), isTrue);
      expect(matches('!(roles == "admin")', o), isFalse);
      expect(matches('!(roles == "other")', o), isTrue);
      expect(matches('!(roles =~ ["x", "guest"])', o), isFalse);
      expect(matches(r'!(roles =~ /^gu/)', o), isFalse);
      expect(matches('!(roles == "admin")', {'roles': []}), isTrue);
    });

    test('parameters', () {
      var o = {'a': 1, 'b': 2};
      expect(matches('!(a == ?) && b == ?', o, parameters: [1, 2]), isFalse);
      expect(matches('!(a == ?) && b == ?', o, parameters: [5, 2]), isTrue);
      expect(
        matches('!(a == ?:x || b == ?:y)', o, parameters: {'x': 0, 'y': 0}),
        isTrue,
      );
      expect(
        matches('!(a == ?:x || b == ?:y)', o, parameters: {'x': 0, 'y': 2}),
        isFalse,
      );
    });
  });

  group('Negated operators: a to-many list, by element', () {
    bool matches(String query, Map<String, dynamic> o) =>
        Condition.parse(query).matchesEntityMap(o);

    test('`==` any; `!=`, `!~` any not, or none', () {
      var o = {
        'roles': ['admin', 'guest'],
      };
      expect(matches('roles == "guest"', o), isTrue);
      expect(matches('roles == "x"', o), isFalse);

      expect(matches('roles != "admin"', o), isTrue);
      expect(
        matches('roles != "admin"', {
          'roles': ['admin'],
        }),
        isFalse,
      );
      expect(matches('roles != "admin"', {'roles': []}), isTrue);

      expect(matches('roles !~ ["admin"]', o), isTrue);
      expect(matches('roles !~ ["admin", "guest"]', o), isFalse);
      expect(matches('roles !~ ["admin"]', {'roles': []}), isTrue);

      expect(matches(r'roles !~ /^a/', o), isTrue);
      expect(matches(r'roles !~ /^(a|g)/', o), isFalse);
      expect(matches(r'roles !~ /^a/', {'roles': []}), isTrue);
    });

    test('a `null` in a comparison: no match (not an error)', () {
      expect(matches('a > 1', {'a': null}), isFalse);
      expect(matches('a >= 1', {'a': null}), isFalse);
      expect(matches('a < 1', {'a': null}), isFalse);
      expect(matches('a <= 1', {'a': null}), isFalse);
    });
  });

  group('ConditionNOT: SQL', () {
    ConditionSQLEncoder encoder({
      bool subquery = true,
      bool derivedTable = false,
    }) => ConditionSQLEncoder(
      _TestSchemeProvider(),
      sqlElementQuote: '"',
      subqueryFromSQL: subquery
          ? (table, sub) {
              var alias = sub.resolveEntityAlias(table);
              var joins = sub.fieldsReferencedTables
                  .map((r) => 'JOIN "${r.targetTable}"')
                  .join(' ');
              return 'FROM "$table" as "$alias" $joins';
            }
          : null,
      subqueryAsDerivedTable: derivedTable,
    );

    Future<EncodingContext> encode(
      String query, {
      Object? parameters,
      ConditionSQLEncoder? sqlEncoder,
    }) async => await (sqlEncoder ?? encoder()).encode(
      Condition.parse(query),
      'account',
      parameters: parameters,
      tableName: 'account',
    );

    test('the main table fields: `NOT COALESCE`', () async {
      var sql = await encode('!(email == "a")');
      expect(
        sql.outputString,
        equals('( NOT COALESCE(( "ac"."email" = \'a\' ), FALSE) )'),
      );
      expect(sql.fieldsReferencedTables, isEmpty);
      expect(sql.tableAliases, equals({'account': 'ac'}));

      var sql2 = await encode(
        '!(email == ? || pass == ?) && admin == ?',
        parameters: ['a', 'b', true],
      );
      expect(
        sql2.outputString,
        equals(
          '( NOT COALESCE(( ( "ac"."email" = @email OR "ac"."pass" = @pass ) ), '
          'FALSE) AND "ac"."admin" = @admin )',
        ),
      );
      expect(
        sql2.parametersPlaceholders,
        equals({'email': 'a', 'pass': 'b', 'admin': true}),
      );

      var sql3 = await encode('!!(email == "a")');
      expect(
        sql3.outputString,
        equals(
          '( NOT COALESCE(( NOT COALESCE(( "ac"."email" = \'a\' ), FALSE) ), '
          'FALSE) )',
        ),
      );
    });

    test('a `null` comparison in a `NOT` (placeholders pruned)', () async {
      var sql = await encode('!(email == ?)', parameters: [null]);
      expect(
        sql.outputString,
        equals('( NOT COALESCE(( "ac"."email" IS NULL ), FALSE) )'),
      );
      expect(sql.parametersPlaceholders, isEmpty);
    });

    test('other tables: `NOT IN` a subquery', () async {
      var sql = await encode(
        '!(address.city == ?) && email == ?',
        parameters: ['x', 'a'],
      );
      expect(
        sql.outputString,
        equals(
          '( "ac"."id" NOT IN ( SELECT "ac"."id" FROM "account" as "ac" '
          'JOIN "address" WHERE "ad"."city" = @city ) AND '
          '"ac"."email" = @email )',
        ),
      );
      expect(sql.parametersPlaceholders, equals({'city': 'x', 'email': 'a'}));
      // The joins are in the subquery:
      expect(sql.fieldsReferencedTables, isEmpty);

      var sql2 = await encode(
        '!(address.city == "x")',
        sqlEncoder: encoder(derivedTable: true),
      );
      expect(
        sql2.outputString,
        equals(
          '( "ac"."id" NOT IN ( SELECT "not_ids"."id" FROM ( SELECT "ac"."id" '
          'FROM "account" as "ac" JOIN "address" WHERE "ad"."city" = \'x\' ) '
          'as "not_ids" ) )',
        ),
      );

      expect(
        () => encode(
          '!(address.city == "x")',
          sqlEncoder: encoder(subquery: false),
        ),
        throwsA(isA<ConditionEncodingError>()),
      );
    });

    test('`!ANY`', () async {
      var sql = await encoder().encode(
        ConditionNOT(ConditionANY()),
        'account',
        tableName: 'account',
      );
      expect(sql.outputString, equals('( FALSE )'));
    });

    test('a negated operator: `OR ... IS NULL`, and an outer join', () async {
      var sql = await encode('address.city != "x"');
      expect(
        sql.outputString,
        equals('( ( "ad"."city" != \'x\' OR "ad"."city" IS NULL ) )'),
      );
      var ref = sql.fieldsReferencedTables.single;
      expect(sql.isInnerFieldReference(ref), isFalse);

      var sql2 = await encode('address.city == "x"');
      expect(
        sql2.isInnerFieldReference(sql2.fieldsReferencedTables.single),
        isTrue,
      );

      // A `!= null`: `IS NOT NULL` (an inner join suffices).
      var sql3 = await encode('address.city != null');
      expect(sql3.outputString, equals('( "ad"."city" IS NOT NULL )'));
      expect(
        sql3.isInnerFieldReference(sql3.fieldsReferencedTables.single),
        isTrue,
      );
    });
  });

  group('Review fixes', () {
    ConditionSQLEncoder encoder({SchemeProvider? schemeProvider}) =>
        ConditionSQLEncoder(
          schemeProvider ?? _TestSchemeProvider(),
          sqlElementQuote: '"',
          subqueryFromSQL: (table, sub) =>
              'FROM "$table" as "${sub.resolveEntityAlias(table)}" JOIN',
        );

    Future<EncodingContext> encode(
      String query, {
      Object? parameters,
      String? tableFieldID,
      SchemeProvider? schemeProvider,
    }) async => await encoder(schemeProvider: schemeProvider).encode(
      Condition.parse(query),
      'account',
      parameters: parameters,
      tableName: 'account',
      tableFieldID: tableFieldID,
    );

    bool matches(String query, Map<String, dynamic> o, {Object? parameters}) =>
        Condition.parse(query).matchesEntityMap(o, parameters: parameters);

    test('comparisons over a to-many list: any element', () {
      var o = {
        'roles': [1, 5],
      };
      expect(matches('roles > 3', o), isTrue);
      expect(matches('roles >= 5', o), isTrue);
      expect(matches('roles < 1', o), isFalse);
      expect(matches('roles <= 1', o), isTrue);
      expect(matches('!(roles > 3)', o), isFalse);
      expect(
        matches('!(roles > 3)', {
          'roles': [1, 2],
        }),
        isTrue,
      );
      expect(matches('roles > ?', o, parameters: [4]), isTrue);
      expect(matches('roles > 1', {'roles': []}), isFalse);
    });

    test('a `null` in an `IN` list (SQL as memory)', () async {
      // Memory:
      expect(matches('a !~ [10, null]', {'a': null}), isFalse);
      expect(matches('a !~ [10, null]', {'a': 5}), isTrue);
      expect(matches('a !~ [10, null]', {'a': 10}), isFalse);
      expect(matches('a =~ [10, null]', {'a': null}), isTrue);
      expect(matches('a =~ [10, null]', {'a': 5}), isFalse);

      // SQL:
      var sql = await encode('pass !~ ["x", null]');
      expect(
        sql.outputString,
        equals(
          '( ( "ac"."pass" NOT IN ( \'x\' ) AND "ac"."pass" IS NOT NULL ) )',
        ),
      );

      var sql2 = await encode('pass =~ ["x", null]');
      expect(
        sql2.outputString,
        equals('( ( "ac"."pass" IN ( \'x\' ) OR "ac"."pass" IS NULL ) )'),
      );

      var sql3 = await encode('pass =~ [null]');
      expect(sql3.outputString, equals('( "ac"."pass" IS NULL )'));

      // A parameter's list: its `null` placeholder is dropped.
      var sql4 = await encode(
        'pass !~ ?',
        parameters: [
          ['x', null],
        ],
      );
      expect(
        sql4.outputString,
        equals(
          '( ( "ac"."pass" NOT IN ( @pass__0 ) AND "ac"."pass" IS NOT NULL ) )',
        ),
      );
      expect(sql4.parametersPlaceholders, equals({'pass__0': 'x'}));
    });

    test('an empty `IN` list is not a `null` (SQL as memory)', () async {
      // Memory: `=~ []` matches nothing, `!~ []` everything (also a `null`);
      // `=~ null` is "is null".
      for (var a in [null, 5]) {
        var empty = {'a': <int>[]};
        expect(matches('a =~ ?', {'a': a}, parameters: empty), isFalse);
        expect(matches('a !~ ?', {'a': a}, parameters: empty), isTrue);
        expect(matches('!(a =~ ?)', {'a': a}, parameters: empty), isTrue);
      }
      var aNull = {'a': null};
      expect(matches('a =~ ?', {'a': null}, parameters: aNull), isTrue);
      expect(matches('a =~ ?', {'a': 5}, parameters: aNull), isFalse);

      // SQL (1.32.0 wrote `[]` as `IS NULL`/`IS NOT NULL`):
      Future<String> sql(String q, Object? p) async =>
          (await encode(q, parameters: p)).outputString;

      expect(await sql('pass =~ ?', {'pass': <String>[]}), '( FALSE )');
      expect(await sql('pass !~ ?', {'pass': <String>[]}), '( TRUE )');
      expect(await sql('pass =~ ?', [<String>[]]), '( FALSE )');
      expect(await sql('id =~ ?', {'id': <int>[]}), '( FALSE )');
      expect(await sql('id !~ ?', {'id': <int>[]}), '( TRUE )');
      expect(await sql('pass =~ []', null), '( FALSE )');
      expect(await sql('pass !~ []', null), '( TRUE )');
      expect(
        await sql('!(pass =~ ?)', {'pass': <String>[]}),
        '( NOT COALESCE(( FALSE ), FALSE) )',
      );
      expect(
        await sql('email == ? || pass =~ ?', {
          'email': 'a',
          'pass': <String>[],
        }),
        '( "ac"."email" = @email OR FALSE )',
      );

      // Not an `IN`: `==`/`!=` with an empty list are still compared to
      // `null` (unchanged; in memory they match none/all).
      expect(await sql('pass == []', null), '( "ac"."pass" IS NULL )');
      expect(await sql('pass != []', null), '( "ac"."pass" IS NOT NULL )');

      // A `null` (as a list) is still `IS NULL`:
      expect(await sql('pass =~ ?', {'pass': null}), '( "ac"."pass" IS NULL )');
      expect(
        await sql('pass !~ ?', {'pass': null}),
        '( "ac"."pass" IS NOT NULL )',
      );
      expect(
        await sql('pass =~ ?', {
          'pass': [null],
        }),
        '( "ac"."pass" IS NULL )',
      );
    });

    test('encode: a group of a single condition', () {
      var c = ConditionNOT(
        GroupConditionAND([
          GroupConditionOR([KeyConditionEQ(ConditionKey.parse('a'), 1)]),
        ]),
      );
      expect(c.encode(), equals('!( a == 1 )'));
      expect(Condition.parse(c.encode()).encode(), equals('!( a == 1 )'));
    });

    test('an empty group: every entity (and its negation, none)', () async {
      var c = ConditionNOT(GroupConditionAND([]));
      expect(c.matchesEntityMap({'a': 1}), isFalse);
      expect(c.matchesEntity({'a': 1}), isFalse);

      var sql = await encoder().encode(c, 'account', tableName: 'account');
      expect(sql.outputString, equals('( FALSE )'));
    });

    test('the main table ID: never `NULL`', () async {
      var sql = await encode('id != 1 && id !~ [2]', tableFieldID: 'id');
      expect(
        sql.outputString,
        equals('( "ac"."id" != 1 AND "ac"."id" NOT IN ( 2 ) )'),
      );

      var sql2 = await encode('!(#ID == 3)', tableFieldID: 'id');
      expect(sql2.outputString, startsWith('( NOT ( '));
    });

    test(
      'a group: in order, also with an asynchronous `TableScheme`',
      () async {
        var sql = await encode(
          '!(address.city == "x") && email == "a" && !(pass == "b") && admin == true',
          schemeProvider: _AsyncTestSchemeProvider(),
        );
        expect(
          sql.outputString,
          equals(
            '( "ac"."id" NOT IN ( SELECT "ac"."id" FROM "account" as "ac" JOIN '
            'WHERE "ad"."city" = \'x\' ) AND "ac"."email" = \'a\' AND '
            'NOT COALESCE(( "ac"."pass" = \'b\' ), FALSE) AND '
            '"ac"."admin" = true )',
          ),
        );
      },
    );
  });

  group('EncodingContext.sub', () {
    test('shares the parameters, not the output', () {
      var parent = EncodingContext(
        'account',
        parameters: [1],
        tableName: 'account',
        tableFieldID: 'id',
      );
      parent.resolveEntityAlias('account');
      parent.parametersPlaceholders['a'] = 1;

      var sub = EncodingContext.sub(parent);
      expect(sub.parent, same(parent));
      expect(sub.root, same(parent));
      expect(EncodingContext.sub(sub).root, same(parent));

      expect(sub.parameters, equals([1]));
      expect(sub.tableName, equals('account'));
      expect(sub.tableFieldID, equals('id'));
      expect(sub.tableAliases, equals({'account': 'ac'}));
      expect(sub.parametersPlaceholders, same(parent.parametersPlaceholders));
      expect(sub.encodingParameters, same(parent.encodingParameters));

      sub.write('x');
      expect(parent.outputString, isEmpty);

      sub.resolveEntityAlias('address');
      expect(parent.tableAliases.containsKey('address'), isFalse);

      sub.markPlaceholderInlinedAsNull('k');
      expect(parent.nullInlinedPlaceholders, equals(['k']));
      expect(sub.nullInlinedPlaceholders, equals(['k']));
    });
  });
}

/// Resolves each [TableScheme] asynchronously (as when not cached yet).
class _AsyncTestSchemeProvider extends _TestSchemeProvider {
  @override
  FutureOr<TableScheme?> getTableScheme(
    String table, {
    TableRelationshipReference? relationship,
    Object? contextID,
  }) => Future.delayed(
    Duration(milliseconds: 1),
    () => getTableSchemeImpl(table, relationship, contextID: contextID),
  );
}

class _TestSchemeProvider extends SchemeProvider {
  @override
  TableScheme? getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) {
    switch (table) {
      case 'account':
        return TableScheme(
          'account',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'email': String,
            'pass': String,
            'address': int,
            'admin': bool,
          },
          fieldsReferencedTables: {
            'address': TableFieldReference(
              'account',
              'address',
              int,
              'address',
              'id',
              int,
            ),
          },
        );
      case 'address':
        return TableScheme(
          'address',
          idFieldName: 'id',
          fieldsTypes: {'id': int, 'city': String},
        );
      default:
        return null;
    }
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) =>
      getTableSchemeImpl(table, null)?.fieldsTypes;

  @override
  String? getTableForType(TypeInfo type) {
    var typeName = type.toString().toLowerCase();
    return typeName.contains('address') ? 'address' : null;
  }

  @override
  FutureOr<TypeInfo?> getFieldType(
    String field, {
    String? entityName,
    String? tableName,
  }) {
    var table = tableName ?? entityName;
    var fieldType = table != null
        ? getTableSchemeImpl(table, null)?.fieldsTypes[field]
        : null;
    return fieldType != null ? TypeInfo.from(fieldType) : null;
  }

  @override
  Object? getEntityID(
    Object entity, {
    String? entityName,
    String? tableName,
    Type? entityType,
    EntityHandler? entityHandler,
  }) => entity is Map ? entity['id'] : throw UnimplementedError();
}
