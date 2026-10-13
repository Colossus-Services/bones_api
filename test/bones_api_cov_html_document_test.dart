@TestOn('vm')
import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class _NoReflectionEnum {}

void main() {
  setUpAll(() {
    User$reflection.staticInstance;
    UserInfo$reflection.staticInstance;
    Store$reflection.staticInstance;
    Role$reflection.staticInstance;
    RoleType$reflection.staticInstance;
  });

  group('HTMLDocument', () {
    test('body styles', () {
      var doc = HTMLDocument(
        title: ' T ',
        bodyStyles: ' margin: 0 ; ',
        bodyColor: ' red ',
        bodyBackgroundColor: 'blue',
        bodyFontFamily: 'Arial',
        bodyPadding: '2px',
      );

      expect(doc.title, equals('T'));
      expect(doc.bodyColor, equals('red'));
      expect(
        doc.bodyStyles,
        equals(
          'margin: 0 ; color: red ; background-color: blue ; '
          'font-family: Arial ; padding: 2px;',
        ),
      );

      var html = doc.build();
      expect(html, contains('<title>T</title>'));
      expect(html, isNot(contains('<style>')));
      expect(html, contains('<body style="margin: 0 ; color: red ;'));
      expect(html, endsWith('</body>\n</html>\n'));

      var empty = HTMLDocument(bodyColor: '', bodyPadding: ' ');
      expect(empty.bodyStyles, equals(''));
      var emptyHtml = empty.build();
      expect(emptyHtml, contains('<body>\n'));
      expect(emptyHtml, isNot(contains('<title>')));
    });

    test('darkTheme', () {
      var doc = HTMLDocument.darkTheme(
        title: 'Dark',
        top: 'TOP',
        content: 'CONTENT',
        footer: 'FOOTER',
      );

      expect(doc.bodyColor, equals('#a9b7c5'));
      expect(doc.bodyBackgroundColor, equals('#1e1f22'));
      expect(doc.styles, contains('button:hover'));

      var html = doc.build();
      expect(html, contains('<title>Dark</title>'));
      expect(html, contains('background-color: #1e1f22'));
      expect(html, contains('TOP\nCONTENT\nFOOTER\n'));

      var doc2 = HTMLDocument.darkTheme(styles: '.x {}');
      expect(doc2.styles, equals('.x {}'));
    });

    test('resolve', () {
      expect(HTMLDocument.resolve(null), equals(''));
      expect(HTMLDocument.resolve(() => 'fn'), equals('fn'));
      expect(HTMLDocument.resolve(StringBuffer('sb')), equals('sb'));
      expect(HTMLDocument.resolve(123), equals('123'));
      expect(HTMLDocument.resolve(['a', 1, null]), equals('a1'));
      expect(
        HTMLDocument.resolve({'a': 1}),
        equals('<pre>{\n  "a": 1\n}</pre>'),
      );
      expect(HTMLDocument.resolve(MapEntry('k', 'v')), equals('k: v'));

      expect(
        HTMLDocument.resolve(MapEntry<String, Type>('age', int)),
        equals('<input id="field_age" name="age" type="number" step="1">'),
      );
      expect(
        HTMLDocument.resolve(
          MapEntry<String, TypeInfo>('name', TypeInfo.tString),
        ),
        contains('<textarea id="field_name" name="name"'),
      );

      expect(
        HTMLDocument.resolve(HTMLInput('x', TypeInfo.tBool, value: true)),
        contains('checked'),
      );

      expect(
        HTMLDocument.resolve(EntityReference<User>.fromID(10)),
        equals('10'),
      );
      expect(
        HTMLDocument.resolve(EntityReferenceList<Store>.fromIDs([1, 2])),
        equals('12'),
      );
    });
  });

  group('HTMLInput', () {
    test('equality / toString / from', () {
      var a = HTMLInput('a', TypeInfo.tInt, value: 1);
      var b = HTMLInput('a', TypeInfo.tInt, value: 1);
      var c = HTMLInput('a', TypeInfo.tInt, value: 2);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(
        a.toString(),
        equals('HTMLInput{name: a, type: <T:int> int, value: 1}'),
      );

      var fromTypeInfo = HTMLInput.from(MapEntry('t', TypeInfo.tDouble));
      expect(fromTypeInfo.type, equals(TypeInfo.tDouble));

      var fromType = HTMLInput.from(MapEntry('t', String));
      expect(fromType.type.isString, isTrue);

      var fromObj = HTMLInput.from(MapEntry('t', 'some value'));
      expect(fromObj.name, equals('t'));
    });

    test('build: primitive types', () {
      expect(
        HTMLInput('s', TypeInfo.tString, value: 'abc').build(),
        equals(
          '<textarea id="field_s" name="s" rows="1" cols="30">abc</textarea>',
        ),
      );
      expect(
        HTMLInput('i', TypeInfo.tInt, value: 10).build(),
        equals(
          '<input id="field_i" name="i" type="number" step="1" value="10">',
        ),
      );
      expect(
        HTMLInput('bi', TypeInfo.tBigInt).build(),
        contains('type="number" step="1"'),
      );
      expect(
        HTMLInput('di', TypeInfo.fromType(DynamicInt)).build(),
        contains('type="number" step="1"'),
      );
      expect(
        HTMLInput('d', TypeInfo.tDouble, value: 1.5).build(),
        equals(
          '<input id="field_d" name="d" type="number" step="any" value="1.5">',
        ),
      );
      expect(
        HTMLInput('dec', TypeInfo.fromType(Decimal)).build(),
        contains('step="any"'),
      );
      expect(
        HTMLInput('b', TypeInfo.tBool, value: 'false').build(),
        equals('<input id="field_b" name="b" type="checkbox">'),
      );
      expect(
        HTMLInput('b', TypeInfo.tBool, value: 'true').build(),
        equals('<input id="field_b" name="b" type="checkbox" checked>'),
      );
    });

    test('build: DateTime / Time', () {
      expect(
        HTMLInput(
          'dt',
          TypeInfo.tDateTime,
          value: DateTime.utc(2021, 2, 3, 4, 5, 6),
        ).build(),
        equals(
          '<input id="field_dt" name="dt" type="datetime-local" '
          'value="2021-02-03T04:05">',
        ),
      );

      var local = DateTime(2021, 2, 3, 4, 5, 6);
      var localUtc = local.toUtc().toIso8601String();
      expect(
        HTMLInput('dt', TypeInfo.tDateTime, value: local).build(),
        contains('value="${localUtc.substring(0, localUtc.lastIndexOf(':'))}"'),
      );

      expect(
        HTMLInput('dt', TypeInfo.tDateTime).build(),
        equals('<input id="field_dt" name="dt" type="datetime-local">'),
      );

      expect(
        HTMLInput(
          't',
          TypeInfo.fromType(Time),
          value: Time(10, 20, 30),
        ).build(),
        equals(
          '<input id="field_t" name="t" type="time" step="1" value="10:20:30">',
        ),
      );
      expect(
        HTMLInput('t', TypeInfo.fromType(Time)).build(),
        equals('<input id="field_t" name="t" type="time" step="1">'),
      );
    });

    test('build: EntityReference', () {
      var refUserType = TypeInfo<EntityReference<User>>.fromType(
        EntityReference,
        [TypeInfo.fromType(User)],
      );

      expect(
        HTMLInput('user', refUserType, value: 11).build(),
        equals(
          '<input id="field_user" name="user" type="number" step="1" value="11">',
        ),
      );

      expect(
        HTMLInput(
          'user',
          refUserType,
          value: EntityReference<User>.fromID(12),
        ).build(),
        contains('value="12"'),
      );

      var refUnknownType = TypeInfo.fromType(EntityReference, [
        TypeInfo.fromType(_NoReflectionEnum),
      ]);
      expect(
        HTMLInput('x', refUnknownType, value: 'abc').build(),
        equals('<input id="field_x" name="x" type="text" size="34">'),
      );

      var refNoArgType = TypeInfo.fromType(EntityReference);
      expect(
        HTMLInput('x', refNoArgType).build(),
        equals('<input id="field_x" name="x" type="text" size="34">'),
      );
    });

    test('build: EntityReferenceList / List<Entity>', () {
      var refListType = TypeInfo<EntityReferenceList<Store>>.fromType(
        EntityReferenceList,
        [TypeInfo.fromType(Store)],
      );

      expect(
        HTMLInput(
          'stores',
          refListType,
          value: EntityReferenceList<Store>.fromIDs([1, 2, 3]),
        ).build(),
        equals(
          '<textarea id="field_stores" name="stores" rows="4" cols="25">'
          '1, 2, 3</textarea>',
        ),
      );

      expect(
        HTMLInput('stores', refListType, value: [4, '5', null]).build(),
        contains('>4, 5</textarea>'),
      );

      expect(
        HTMLInput('stores', refListType).build(),
        contains('cols="25"></textarea>'),
      );

      var listType = TypeInfo.fromType(List, [TypeInfo.fromType(Store)]);

      expect(
        HTMLInput(
          'stores',
          listType,
          value: [Store('s1', 1, id: 7), Store('s2', 2, id: 8)],
        ).build(),
        equals(
          '<textarea id="field_stores" name="stores" rows="4" cols="25">'
          '7, 8</textarea>',
        ),
      );

      expect(
        HTMLInput('stores', listType, value: 9).build(),
        contains('>9</textarea>'),
      );

      expect(
        HTMLInput('stores', listType).build(),
        contains('cols="25"></textarea>'),
      );
    });

    test('build: enum / entity / other', () {
      var roleTypeType = TypeInfo.fromType(RoleType);

      var select = HTMLInput(
        'role',
        roleTypeType,
        value: RoleType.guest,
      ).build();
      expect(select, startsWith('<select id="field_role" name="role">\n'));
      expect(select, contains('<option value=""></option>'));
      expect(select, contains('<option value="admin">admin</option>'));
      expect(select, contains('<option value="guest" selected>guest</option>'));
      expect(select, endsWith('</select>'));

      var select2 = HTMLInput('role', roleTypeType).build();
      expect(select2, isNot(contains('selected')));

      var userType = TypeInfo.fromType(User);
      expect(
        HTMLInput('owner', userType, value: 21).build(),
        equals(
          '<textarea id="field_owner" name="owner" rows="4" cols="8">'
          '21</textarea>',
        ),
      );
      expect(
        HTMLInput('owner', userType).build(),
        contains('cols="8"></textarea>'),
      );

      expect(
        HTMLInput(
          'other',
          TypeInfo.fromType(_NoReflectionEnum),
          value: 'x',
        ).build(),
        equals(
          '<textarea id="field_other" name="other" rows="3" cols="40">'
          'x</textarea>',
        ),
      );
    });
  });

  group('decodeQueryStringParameters', () {
    test('basic', () {
      expect(decodeQueryStringParameters(null), isEmpty);
      expect(decodeQueryStringParameters(''), isEmpty);

      expect(
        decodeQueryStringParameters('a=1&b=2&b=3&b=4&c&&d=x+y%21'),
        equals({
          'a': '1',
          'b': ['2', '3', '4'],
          'c': '',
          'd': 'x y!',
        }),
      );
    });

    test('charsets', () {
      // `%E9` is an invalid UTF-8 sequence: falls back to latin1.
      expect(decodeQueryStringParameters('n=caf%E9'), equals({'n': 'café'}));

      expect(
        decodeQueryStringParameters('n=caf%C3%A9', charset: 'utf-8'),
        equals({'n': 'café'}),
      );

      expect(
        decodeQueryStringParameters('n=caf%E9', charset: 'utf-8'),
        equals({'n': 'café'}),
      );

      expect(
        decodeQueryStringParameters('n=caf%E9', charset: 'latin1'),
        equals({'n': 'café'}),
      );

      // Malformed escape: the raw value is preserved.
      expect(
        decodeQueryStringParameters('n=%ZZ', charset: 'latin1'),
        equals({'n': '%ZZ'}),
      );
      expect(
        decodeQueryStringParameters('n=%ZZ', charset: 'utf-8'),
        equals({'n': '%ZZ'}),
      );
      expect(decodeQueryStringParameters('n=%ZZ'), equals({'n': '%ZZ'}));
    });
  });
}
