import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('Condition', () {
    setUp(() {});

    test('ConditionParameter', () async {
      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter())
              .encode(),
          equals('foo == ?'));

      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter.index(0))
              .encode(),
          equals('foo == ?#0'));

      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter.index(1))
              .encode(),
          equals('foo == ?#1'));

      expect(
          KeyConditionEQ(
                  ConditionKey.parse('foo'), ConditionParameter.key('xy'))
              .encode(),
          equals('foo == ?:xy'));
    });
  });

  test('ConditionParameter', () async {
    var c = ConditionID(123);
    expect(c.idValue, equals(123));

    var g = GroupConditionOR(
        [ConditionID(10), ConditionID(ConditionParameter.key('id'))]);

    var parameters = <ConditionParameter>[];
    g.resolve(parameters: parameters);

    expect(g.conditions.length, equals(2));
    expect((g.conditions[0] as ConditionID).idValue, equals(10));
    expect((g.conditions[1] as ConditionID).idValue,
        equals(ConditionParameter.key('id')));

    expect(parameters, equals([ConditionParameter.key('id')]));
  });

  group('ConditionParser', () {
    setUp(() {});

    test('key op value', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == true ').toString(),
          equals('foo == true'));
      expect(conditionParser.parse(' foo != false ').toString(),
          equals('foo != false'));

      expect(conditionParser.parse(' foo.x == 123 ').toString(),
          equals('foo.x == 123'));

      expect(conditionParser.parse(' foo.x != 123 ').toString(),
          equals('foo.x != 123'));

      expect(conditionParser.parse(' "a:b" == false ').toString(),
          equals('"a:b" == false'));
      expect(conditionParser.parse(" 'a  b' == 'xyz' ").toString(),
          equals('"a  b" == "xyz"'));

      expect(conditionParser.parse(' k_1 == 234 ').toString(),
          equals('k_1 == 234'));

      expect(conditionParser.parse(' ( foo == 123 ) ').toString(),
          equals('foo == 123'));

      expect(conditionParser.parse(' ( foo != 123 ) ').toString(),
          equals('foo != 123'));

      expect(conditionParser.parse(' ( foo == [1 , 2] ) ').toString(),
          equals('foo == [1,2]'));

      expect(conditionParser.parse(' ( foo == {"a": 1 , "b": 2} ) ').toString(),
          equals('foo == {"a":1,"b":2}'));

      expect(conditionParser.parse(' ( foo =~ [1 , 2] ) ').toString(),
          equals('foo =~ [1,2]'));

      expect(conditionParser.parse(' ( foo =~ 123 ) ').toString(),
          equals('foo =~ [123]'));
    });

    test('group AND', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == 123 && bar == false ').toString(),
          equals('( foo == 123 && bar == false )'));

      expect(conditionParser.parse(' (foo == 123 && bar == false) ').toString(),
          equals('( foo == 123 && bar == false )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123) && (bar == 456) ) ')
              .toString(),
          equals('( foo == 123 && bar == 456 )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123 && foo == 321) && (bar == 456) ) ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) && bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 && foo == 321) && (bar == 456) ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) && bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 && foo == 321) || bar == 456 ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) || bar == 456 )'));
    });

    test('group OR', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == 123 || bar == false ').toString(),
          equals('( foo == 123 || bar == false )'));

      expect(
          conditionParser
              .parse(' foo == 123 || ( bar == false || baz == 123 ) ')
              .toString(),
          equals('( foo == 123 || ( bar == false || baz == 123 ) )'));

      expect(conditionParser.parse('( foo == 123 || bar == false )').toString(),
          equals('( foo == 123 || bar == false )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123) || (bar == 456) ) ')
              .toString(),
          equals('( foo == 123 || bar == 456 )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123 || foo == 321) || (bar == 456) ) ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) || bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 || foo == 321) || (bar == 456) ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) || bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 || foo == 321) && bar == 456 ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) && bar == 456 )'));
    });

    test('group AND+OR', () {
      var conditionParser = ConditionParser();

      expect(
          conditionParser
              .parse(" level == ? && ( roles =~ ?:rs1 || roles =~ ?:rs2 ) ")
              .toString(),
          equals('( level == ? && ( roles =~ [?:rs1] || roles =~ [?:rs2] ) )'));

      expect(
          conditionParser
              .parse(" level == 100 && ( roles =~ ?:rs1 || roles =~ ?:rs2 ) ")
              .toString(),
          equals(
              '( level == 100 && ( roles =~ [?:rs1] || roles =~ [?:rs2] ) )'));

      expect(
          conditionParser
              .parse(" ( level == ? ) && ( roles =~ ?:rs1 || roles =~ ?:rs2 ) ")
              .toString(),
          equals('( level == ? && ( roles =~ [?:rs1] || roles =~ [?:rs2] ) )'));

      expect(
          conditionParser
              .parse("( level == ? && ( roles =~ ?:rs1 || roles =~ ?:rs2 ) )")
              .toString(),
          equals('( level == ? && ( roles =~ [?:rs1] || roles =~ [?:rs2] ) )'));
    });

    test('ConditionParameter single', () async {
      var conditionParser = ConditionParser();

      var c1 = conditionParser.parse(' foo == ? ');
      expect(c1.toString(), equals('foo == ?'));
      expect(c1.parameters.toString(), equals('[?]'));
      expect(c1.parameters.map((e) => e.contextPosition), equals([0]));
      expect(c1.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c1.parameters.map((e) => e.index), equals([null]));
      expect(c1.parameters.map((e) => e.key), equals([null]));

      var c2 = conditionParser.parse(' foo == ?#1 ');
      expect(c2.toString(), equals('foo == ?#1'));
      expect(c2.parameters.toString(), equals('[?#1]'));
      expect(c2.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c2.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c2.parameters.map((e) => e.index), equals([1]));
      expect(c2.parameters.map((e) => e.key), equals([null]));

      var c3 = conditionParser.parse(' foo == ?#123 ');
      expect(c3.toString(), equals('foo == ?#123'));
      expect(c3.parameters.toString(), equals('[?#123]'));
      expect(c3.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c3.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c3.parameters.map((e) => e.index), equals([123]));
      expect(c3.parameters.map((e) => e.key), equals([null]));

      var c4 = conditionParser.parse(' foo == ?:xyz ');
      expect(c4.toString(), equals('foo == ?:xyz'));
      expect(c4.parameters.toString(), equals('[?:xyz]'));
      expect(c4.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c4.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c4.parameters.map((e) => e.index), equals([null]));
      expect(c4.parameters.map((e) => e.key), equals(['xyz']));

      var c5 = conditionParser.parse(' foo == ?# ');
      expect(c5.toString(), equals('foo == ?#'));
      expect(c5.parameters.toString(), equals('[?#]'));
      expect(c5.parameters.map((e) => e.contextPosition), equals([0]));
      expect(c5.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c5.parameters.map((e) => e.index), equals([-1]));
      expect(c5.parameters.map((e) => e.key), equals([null]));

      var c6 = conditionParser.parse(' foo == ?: ');
      expect(c6.toString(), equals('foo == ?:'));
      expect(c6.parameters.toString(), equals('[?:]'));
      expect(c6.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c6.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c6.parameters.map((e) => e.index), equals([null]));
      expect(c6.parameters.map((e) => e.key), equals(['']));
    });

    test('ConditionParameter group', () async {
      var conditionParser = ConditionParser();

      var c5 = conditionParser.parse(' foo == ? || bar == ? ');
      expect(c5.toString(), equals('( foo == ? || bar == ? )'));
      expect(c5.parameters.toString(), equals('[?, ?]'));
      expect(c5.parameters.map((e) => e.contextPosition), equals([0, 1]));

      var c6 = conditionParser.parse(' foo == ? || ( bar == ? || baz == ? ) ');
      expect(c6.toString(), equals('( foo == ? || ( bar == ? || baz == ? ) )'));
      expect(c6.parameters.toString(), equals('[?, ?, ?]'));
      expect(c6.parameters.map((e) => e.contextPosition), equals([0, 1, 2]));

      var c7 =
          conditionParser.parse(' foo == ? || ( bar == ?:x || baz == ? ) ');
      expect(
          c7.toString(), equals('( foo == ? || ( bar == ?:x || baz == ? ) )'));
      expect(c7.parameters.toString(), equals('[?, ?:x, ?]'));
      expect(c7.parameters.map((e) => e.contextPosition), equals([0, null, 2]));
      expect(c7.parameters.map((e) => e.contextKey),
          equals(['foo', 'bar', 'baz']));
      expect(c7.parameters.map((e) => e.contextKeyPosition), equals([0, 1, 2]));
      expect(c7.parameters.map((e) => e.index), equals([null, null, null]));
      expect(c7.parameters.map((e) => e.key), equals([null, 'x', null]));

      var c8 =
          conditionParser.parse(' foo == ? || ( bar == ?#0 || baz == ? ) ');
      expect(
          c8.toString(), equals('( foo == ? || ( bar == ?#0 || baz == ? ) )'));
      expect(c8.parameters.toString(), equals('[?, ?#0, ?]'));
      expect(c8.parameters.map((e) => e.contextPosition), equals([0, null, 2]));
      expect(c8.parameters.map((e) => e.contextKey),
          equals(['foo', 'bar', 'baz']));
      expect(c8.parameters.map((e) => e.contextKeyPosition), equals([0, 1, 2]));
      expect(c8.parameters.map((e) => e.index), equals([null, 0, null]));
      expect(c8.parameters.map((e) => e.key), equals([null, null, null]));
    });

    test('group OR', () async {
      var conditionParser = ConditionParser();

      var c1 = conditionParser.parse(' #ID == 123 ') as ConditionID;
      expect(c1.idValue, equals(123));
      expect(c1.matchesEntityMap({'id': 123}, positionalParameters: [123]),
          isTrue);
      expect(c1.matchesEntityMap({'id': 123}, positionalParameters: [456]),
          isTrue);
      expect(c1.matchesEntityMap({'id': 456}, positionalParameters: [456]),
          isFalse);

      var c2 = conditionParser.parse(' #ID == ? ') as ConditionID;
      expect(c2.idValue.toString(), equals('?'));

      expect(c2.matchesEntityMap({'id': 123}, positionalParameters: [123]),
          isTrue);
      expect(c2.matchesEntityMap({'id': 123}, positionalParameters: [456]),
          isFalse);
      expect(c2.matchesEntityMap({'id': 456}, positionalParameters: [456]),
          isTrue);
    });

    test('group complex', () async {
      var conditionParser = ConditionParser();

      var c1 = conditionParser.parse(
              ' address.countryCode == ? && address.state == ? && address.latitude > ?:lat1 && address.latitude < ?:lat2 && address.longitude >= ?:long1 && address.longitude <= ?:long2 ')
          as GroupConditionAND;

      expect(c1.conditions.length, equals(6));
      expect(c1.conditions[0], isA<KeyConditionEQ>());
      expect(c1.conditions[1], isA<KeyConditionEQ>());
      expect(c1.conditions[2], isA<KeyConditionGreaterThan>());
      expect(c1.conditions[3], isA<KeyConditionLessThan>());
      expect(c1.conditions[4], isA<KeyConditionGreaterThanOrEqual>());
      expect(c1.conditions[5], isA<KeyConditionLessThanOrEqual>());

      var m1 = c1.matchesEntityMap({
        'address': {
          'countryCode': 'BR',
          'state': 'SP',
          'latitude': 20.01,
          'longitude': 30.01,
        },
      }, namedParameters: {
        'countryCode': 'BR',
        'state': 'SP',
        'lat1': 20.01 - 1,
        'lat2': 20.01 + 1,
        'long1': 30.01 - 1,
        'long2': 30.01 + 1,
      });

      expect(m1, isTrue);

      var m2 = c1.matchesEntityMap({
        'address': {
          'countryCode': 'BR',
          'state': 'SP',
          'latitude': 20.01,
          'longitude': 30.01,
        },
      }, namedParameters: {
        'countryCode': 'BR',
        'state': 'SP',
        'lat1': 20.01 + 1,
        'lat2': 20.01 + 2,
        'long1': 30.01 - 1,
        'long2': 30.01 + 1,
      });

      expect(m2, isFalse);
    });
  });

  group('ConditionEncoder', () {
    setUp(() {});

    test('SQL Encoder', () async {
      var parser = ConditionParser();

      var sqlEncoder =
          ConditionSQLEncoder(_TestSchemeProvider(), sqlElementQuote: '"');

      {
        var sql = await sqlEncoder.encode(
            parser.parse('email == ? && admin == ?'), 'account',
            parameters: {'email': 'joe@m.com', 'admin': false});

        expect(sql.outputString,
            equals('( "ac"."email" = @email AND "ac"."admin" = @admin )'));
        expect(sql.parametersPlaceholders,
            equals({'email': 'joe@m.com', 'admin': false}));
        expect(sql.tableAliases, equals({'account': 'ac'}));
        expect(sql.fieldsReferencedTables, isEmpty);
      }

      {
        var sql = await sqlEncoder.encode(
            parser.parse('email == ? && address.state == ?'), 'account',
            parameters: {'email': 'joe@m.com', 'state': 'NY'});

        expect(sql.outputString,
            equals('( "ac"."email" = @email AND "ad"."state" = @state )'));
        expect(sql.parametersPlaceholders,
            equals({'email': 'joe@m.com', 'state': 'NY'}));
        expect(sql.tableAliases, equals({'account': 'ac', 'address': 'ad'}));
        expect(sql.fieldsReferencedTables, {
          TableFieldReference('account', 'address', int, 'address', 'id', int)
        });
      }
    });
  });

  group('Condition match', () {
    test('KeyConditionEQ', () {
      expect(
          KeyConditionEQ([ConditionKeyField('foo')], 123)
              .matchesEntity({'foo': 123}),
          isTrue);

      expect(
          KeyConditionEQ([ConditionKeyField('foo')], 123)
              .matchesEntity({'foo': 456}),
          isFalse);
    });

    test('KeyConditionNotEQ', () {
      expect(
          KeyConditionNotEQ([ConditionKeyField('foo')], 123)
              .matchesEntity({'foo': 123}),
          isFalse);

      expect(
          KeyConditionNotEQ([ConditionKeyField('foo')], 123)
              .matchesEntity({'foo': 456}),
          isTrue);
    });

    test('KeyConditionIN', () {
      var conditionIN = KeyConditionIN([ConditionKeyField('foo')], [1, 2, 3]);

      expect(conditionIN.matchesEntity({'foo': 1}), isTrue);
      expect(conditionIN.matchesEntity({'foo': 2}), isTrue);
      expect(conditionIN.matchesEntity({'foo': 3}), isTrue);
      expect(conditionIN.matchesEntity({'foo': 4}), isFalse);
    });

    test('KeyConditionNotIN', () {
      var conditionIN =
          KeyConditionNotIN([ConditionKeyField('foo')], [1, 2, 3]);

      expect(conditionIN.matchesEntity({'foo': 1}), isFalse);
      expect(conditionIN.matchesEntity({'foo': 2}), isFalse);
      expect(conditionIN.matchesEntity({'foo': 3}), isFalse);
      expect(conditionIN.matchesEntity({'foo': 4}), isTrue);
    });

    test('GroupConditionAND', () {
      expect(
          GroupConditionAND([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 123, 'bar': 456}),
          isTrue);

      expect(
          GroupConditionAND([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 123, 'bar': 654}),
          isFalse);

      expect(
          GroupConditionAND([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 321, 'bar': 654}),
          isFalse);
    });

    test('GroupConditionOR', () {
      expect(
          GroupConditionOR([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 123, 'bar': 456}),
          isTrue);

      expect(
          GroupConditionOR([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 123, 'bar': 654}),
          isTrue);

      expect(
          GroupConditionOR([
            KeyConditionEQ([ConditionKeyField('foo')], 123),
            KeyConditionEQ([ConditionKeyField('bar')], 456),
          ]).matchesEntity({'foo': 321, 'bar': 654}),
          isFalse);
    });
  });
}

class _TestSchemeProvider extends SchemeProvider {
  @override
  TableScheme? getTableSchemeImpl(
      String table, TableRelationshipReference? relationship,
      {Object? contextID}) {
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
            'admin': bool
          },
          fieldsReferencedTables: {
            'address': TableFieldReference(
                'account', 'address', int, 'address', 'id', int)
          },
        );
      case 'address':
        return TableScheme(
          'address',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'state': String,
            'city': String,
            'street': String
          },
        );
      default:
        return null;
    }
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) {
    return getTableSchemeImpl(table, null)?.fieldsTypes;
  }

  @override
  String? getTableForType(TypeInfo type) {
    var typeName = type.toString().toLowerCase();

    if (typeName.contains('address')) {
      return 'address';
    } else if (typeName.contains('account')) {
      return 'account';
    }

    return null;
  }

  @override
  FutureOr<TypeInfo?> getFieldType(String field,
      {String? entityName, String? tableName}) {
    var tableScheme =
        tableName != null ? getTableScheme(tableName) as TableScheme? : null;
    tableScheme ??=
        entityName != null ? getTableScheme(entityName) as TableScheme? : null;

    var fieldsType = tableScheme?.fieldsTypes[field];
    if (fieldsType != null) return TypeInfo.from(fieldsType);

    return null;
  }

  @override
  Object? getEntityID(Object entity,
      {String? entityName,
      String? tableName,
      Type? entityType,
      EntityHandler? entityHandler}) {
    if (entity is Entity) {
      return entity.getID();
    } else if (entity is Map) {
      return entity['id'];
    } else if (entityHandler != null) {
      return entityHandler.getID(entity);
    }

    throw StateError("Unknown entity type: $entity");
  }
}
