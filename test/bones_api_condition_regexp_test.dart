import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

enum _Color { red, green }

class _Owner {
  @override
  String toString() => 'Owner#12';
}

void main() {
  group('KeyConditionRegExp: parse', () {
    KeyConditionRegExp parseRegExp(String query) {
      var c = Condition.parse(query);
      expect(c, isA<KeyConditionRegExp>());
      return c as KeyConditionRegExp;
    }

    test('=~ and !~ with flags', () {
      var c = parseRegExp('name =~ /^jo/i');
      expect(c.keys.map((k) => k.encode()), equals(['name']));
      expect(c.pattern, equals('^jo'));
      expect(c.patternParameter, isNull);
      expect(c.caseInsensitive, isTrue);
      expect(c.not, isFalse);
      expect(c.encode(), equals('name =~ /^jo/i'));

      var c2 = parseRegExp('name !~ /x/');
      expect(c2.pattern, equals('x'));
      expect(c2.caseInsensitive, isFalse);
      expect(c2.not, isTrue);
      expect(c2.encode(), equals('name !~ /x/'));

      // Spaces around the regexp, and in it:
      expect(parseRegExp(' name=~/a b/ ').pattern, equals('a b'));
    });

    test('escapes', () {
      // `\/` is unescaped:
      var c = parseRegExp(r'url =~ /^https?:\/\//');
      expect(c.pattern, equals('^https?://'));
      expect(c.encode(), equals(r'url =~ /^https?:\/\//'));

      // Any other `\x` is kept, including `\\`:
      expect(parseRegExp(r'a =~ /\d+\.\\/').pattern, equals(r'\d+\.\\'));
      var c2 = parseRegExp(r'a =~ /x\\\/y/');
      expect(c2.pattern, equals(r'x\\/y'));
      expect(c2.encode(), equals(r'a =~ /x\\\/y/'));

      // Characters that are special in JSON or SQL strings:
      expect(parseRegExp(r'''a =~ /"'%_/''').pattern, equals('''"'%_'''));
    });

    test('encode -> parse round trip', () {
      for (var q in [
        'name =~ /^jo/i',
        'name !~ /x/',
        r'url =~ /^https?:\/\//',
        r'a =~ /x\\\/y/',
        r'address.city =~ /^s(ão|ao) paulo$/i',
        r'tags.[0] =~ /urgent/',
        'name =~ /?/',
        'name !~ /?#1/i',
        'name =~ /?:pattern/',
      ]) {
        var c = Condition.parse(q);
        expect(c.encode(), equals(q), reason: q);
        expect(Condition.parse(c.encode()).encode(), equals(q), reason: q);
      }
    });

    test('keys: a path and an index', () {
      var c = parseRegExp('address.city =~ /x/');
      expect(c.keys.map((k) => k.encode()), equals(['address', 'city']));

      var c2 = parseRegExp('tags.[0] =~ /x/');
      expect(c2.keys.last, isA<ConditionKeyIndex>());
    });

    test('parameters', () {
      var c = parseRegExp('name =~ /?/');
      expect(c.pattern, isNull);
      expect(c.patternParameter, isNotNull);
      expect(c.patternParameter!.isPositional, isTrue);
      expect(c.parameters, equals([c.patternParameter]));

      var c2 = parseRegExp('name =~ /?#1/i');
      expect(c2.patternParameter!.index, equals(1));
      expect(c2.caseInsensitive, isTrue);

      var c3 = parseRegExp('name !~ /?:p/');
      expect(c3.patternParameter!.key, equals('p'));
      expect(c3.not, isTrue);

      expect(parseRegExp('name =~ /?#/').patternParameter!.index, equals(-1));
      expect(parseRegExp('name =~ /?:/').patternParameter!.key, isEmpty);

      // Only a whole regexp is a parameter: an optional space then digits.
      var c4 = parseRegExp(r'code =~ / ?\d+/');
      expect(c4.pattern, equals(r' ?\d+'));
      expect(c4.patternParameter, isNull);
      expect(parseRegExp(r'code =~ /a?/').pattern, equals('a?'));
      expect(parseRegExp(r'code =~ /\??/').pattern, equals(r'\??'));
    });

    test('groups', () {
      var c = Condition.parse(
        '(a =~ /x/ || b !~ /y/i) && c == 1 && d =~ ["/z/"]',
      );
      expect(
        c.encode(),
        equals('( ( a =~ /x/ || b !~ /y/i ) && c == 1 && d =~ ["/z/"] )'),
      );
      var and = c as GroupConditionAND;
      var or = and.conditions[0] as GroupConditionOR;
      expect(or.conditions[0], isA<KeyConditionRegExp>());
      expect(or.conditions[1], isA<KeyConditionRegExp>());
      expect(and.conditions[2], isA<KeyConditionIN>());
    });

    test('`=~` without a regexp is still `IN`', () {
      expect(Condition.parse('x =~ ["a", "b"]'), isA<KeyConditionIN>());
      expect(Condition.parse('x =~ "a"'), isA<KeyConditionIN>());
      expect(Condition.parse('x =~ ?'), isA<KeyConditionIN>());
      expect(Condition.parse('x !~ ?:p'), isA<KeyConditionNotIN>());
      expect(Condition.parse('x == "/a/"'), isA<KeyConditionEQ>());
    });

    test('errors', () {
      // Only the `i` flag:
      for (var q in ['x =~ /a/m', 'x =~ /a/s', 'x =~ /a/g', 'x =~ /a/ix']) {
        expect(() => Condition.parse(q), throwsFormatException, reason: q);
      }

      // Only `=~` and `!~`:
      for (var op in ['==', '!=', '>', '>=', '<', '<=']) {
        expect(
          () => Condition.parse('x $op /a/'),
          throwsFormatException,
          reason: op,
        );
      }

      // An invalid pattern:
      for (var q in ['x =~ /(/', 'x =~ /[a/', 'x =~ /a{2,1}/']) {
        expect(() => Condition.parse(q), throwsFormatException, reason: q);
      }

      // A `?` after other characters is a pattern, not a parameter:
      // invalid (nothing to repeat) at the start of a pattern.
      expect(() => Condition.parse(r'x =~ /?\d/'), throwsFormatException);

      // An empty or unterminated regexp:
      for (var q in ['x =~ //', 'x =~ /a', r'x =~ /a\/']) {
        expect(() => Condition.parse(q), throwsFormatException, reason: q);
      }
    });
  });

  group('KeyConditionRegExp', () {
    test('constructor', () {
      var keys = ConditionKey.parse('name');

      var c = KeyConditionRegExp(keys, '^a');
      expect(c.pattern, equals('^a'));
      expect(c.caseInsensitive, isFalse);

      var c2 = KeyConditionRegExp(keys, RegExp('^a', caseSensitive: false));
      expect(c2.pattern, equals('^a'));
      expect(c2.caseInsensitive, isTrue);

      var c3 = KeyConditionRegExp(keys, RegExp('^a'), caseInsensitive: true);
      expect(c3.caseInsensitive, isTrue);

      expect(() => KeyConditionRegExp(keys, 123), throwsArgumentError);
      expect(() => KeyConditionRegExp(keys, '('), throwsFormatException);

      var c4 = c.cast<Map>();
      expect(c4, isA<KeyConditionRegExp<Map>>());
      expect(c4.encode(), equals(c.encode()));
    });

    test('toDartRegExp: semantics and cache', () {
      var r = KeyConditionRegExp.toDartRegExp('^a.b\$');
      expect(r.isDotAll, isTrue);
      expect(r.isMultiLine, isFalse);
      expect(r.isCaseSensitive, isTrue);
      expect(r.isUnicode, isTrue);
      expect(identical(r, KeyConditionRegExp.toDartRegExp('^a.b\$')), isTrue);

      var ri = KeyConditionRegExp.toDartRegExp('x', caseInsensitive: true);
      expect(ri.isCaseSensitive, isFalse);
      expect(identical(ri, KeyConditionRegExp.toDartRegExp('x')), isFalse);

      // The cache is bounded:
      for (var i = 0; i < 300; ++i) {
        KeyConditionRegExp.toDartRegExp('p$i');
      }
      expect(KeyConditionRegExp.toDartRegExp('p299').pattern, equals('p299'));
    });

    test('valueToText', () {
      expect(KeyConditionRegExp.valueToText('a'), equals('a'));
      expect(KeyConditionRegExp.valueToText(12), equals('12'));
      expect(KeyConditionRegExp.valueToText(_Color.green), equals('green'));
    });
  });

  group('KeyConditionRegExp: match', () {
    bool matches(
      String query,
      Map<String, dynamic> o, {
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
    }) {
      var c = Condition.parse(query);
      var m1 = c.matchesEntityMap(
        o,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
      var m2 = c.matchesEntity(
        o,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
      expect(m2, equals(m1), reason: 'matchesEntity != matchesEntityMap');
      return m1;
    }

    test('anywhere, case and `!~`', () {
      var o = {'name': 'Joe Smith'};
      expect(matches('name =~ /Smith/', o), isTrue);
      expect(matches('name =~ /smith/', o), isFalse);
      expect(matches('name =~ /smith/i', o), isTrue);
      expect(matches('name =~ /^Joe Smith\$/', o), isTrue);
      expect(matches('name !~ /smith/', o), isTrue);
      expect(matches('name !~ /smith/i', o), isFalse);
    });

    test('`.` matches a line terminator; `^`/`\$` the whole value', () {
      var o = {'t': 'alpha\nbeta\n'};
      expect(matches('t =~ /alpha.beta/', o), isTrue);
      expect(matches('t =~ /^beta/', o), isFalse);
      expect(matches('t =~ /alpha\$/', o), isFalse);
      expect(matches('t =~ /beta\$/', o), isFalse);
      expect(matches('t =~ /beta\\n\$/', o), isTrue);
      expect(matches('t =~ /^alpha/', o), isTrue);
    });

    test('unicode', () {
      var o = {'t': 'São 😀'};
      expect(matches(r't =~ /^S.o .$/', o), isTrue);
      expect(matches('t =~ /SÃO/i', o), isTrue);
    });

    test('identity escapes (invalid in Dart\'s `unicode` mode)', () {
      // Valid in PostgreSQL and MySQL: accepted (not a `FormatException`).
      expect(matches(r'name =~ /^foo\-bar$/', {'name': 'foo-bar'}), isTrue);
      expect(matches(r'email =~ /\@corp$/', {'email': 'a@corp'}), isTrue);
      expect(
        KeyConditionRegExp.toDartRegExp(r'\-').isUnicode,
        isFalse,
        reason: 'Not valid in the `unicode` mode',
      );
      expect(KeyConditionRegExp.toDartRegExp(r'\.').isUnicode, isTrue);
    });

    test('word boundaries', () {
      var o = {'name': 'John Smith'};
      expect(matches(r'name =~ /\bsmith\b/i', o), isTrue);
      expect(matches(r'name =~ /\Bmith/', o), isTrue);
      expect(matches(r'name =~ /\bmith/', o), isFalse);
    });

    test('an entity reference: by its ID', () {
      var ref = EntityReference<_Owner>.fromID(12);
      expect(matches(r'owner =~ /^12$/', {'owner': ref}), isTrue);
      expect(matches(r'owner !~ /^12$/', {'owner': ref}), isFalse);
      expect(matches(r'owner =~ /^1$/', {'owner': ref}), isFalse);
    });

    test('null, non-text values, lists', () {
      // A `null`: matches `!~` (as `!=` and `!~ [...]`, since 1.32.0).
      expect(matches('x =~ /a/', {'x': null}), isFalse);
      expect(matches('x !~ /a/', {'x': null}), isTrue);
      expect(matches('x =~ /a/', {'y': 'a'}), isFalse);
      expect(matches('x !~ /a/', {'y': 'a'}), isTrue);

      expect(matches(r'n =~ /^9\d$/', {'n': 91}), isTrue);
      expect(matches(r'n =~ /^9\d$/', {'n': 191}), isFalse);
      expect(matches(r'n =~ /^1\.5$/', {'n': 1.5}), isTrue);
      expect(matches('b =~ /^true\$/', {'b': true}), isTrue);
      expect(matches('c =~ /^gr/', {'c': _Color.green}), isTrue);
      expect(matches('c !~ /^gr/', {'c': _Color.red}), isTrue);

      // A list: `=~` if any element matches; `!~` if any doesn't:
      var o = {
        'tags': ['a1', 'b2', null],
      };
      expect(matches(r'tags =~ /^b\d/', o), isTrue);
      expect(matches(r'tags =~ /^c/', o), isFalse);
      expect(matches(r'tags !~ /^a/', o), isTrue);
      // A `null` element isn't a value (nor a SQL row):
      expect(matches(r'tags !~ /\d$/', o), isFalse);
      expect(
        matches(r'tags !~ /a/', {
          'tags': [null],
        }),
        isTrue,
        reason: 'No value: as an empty list',
      );
      expect(
        matches(r'tags !~ /\d$/', {
          'tags': ['a1', 'b2'],
        }),
        isFalse,
      );
      expect(matches('tags =~ /a/', {'tags': []}), isFalse);
      // No element: `!~` matches (as SQL's outer join, a `NULL` row).
      expect(matches('tags !~ /a/', {'tags': []}), isTrue);

      expect(matches('tags.[1] =~ /^b/', o), isTrue);
    });

    test('a nested key', () {
      var o = {
        'address': {'city': 'New York'},
      };
      expect(matches('address.city =~ /york\$/i', o), isTrue);
      expect(matches('address.city !~ /york\$/i', o), isFalse);
    });

    test('parameters', () {
      var o = {'name': 'Joe'};

      expect(matches('name =~ /?/', o, positionalParameters: ['^J']), isTrue);
      expect(matches('name =~ /?/', o, parameters: ['^j']), isFalse);
      expect(matches('name =~ /?/i', o, parameters: ['^j']), isTrue);
      expect(
        matches('name =~ /?#1/', o, positionalParameters: ['x', 'oe\$']),
        isTrue,
      );
      expect(matches('name =~ /?:p/', o, parameters: {'p': '^Jo'}), isTrue);
      expect(
        matches('name !~ /?:p/', o, namedParameters: {'p': '^Jo'}),
        isFalse,
      );

      // A `RegExp`: its case flag is used; `multiLine`/`dotAll` are not.
      expect(
        matches(
          'name =~ /?:p/',
          o,
          parameters: {'p': RegExp('^joe\$', caseSensitive: false)},
        ),
        isTrue,
      );
      expect(
        matches(
          't =~ /?:p/',
          {'t': 'a\nb'},
          parameters: {'p': RegExp(r'^b', multiLine: true)},
        ),
        isFalse,
      );
      expect(
        matches('t =~ /?:p/', {'t': 'a\nb'}, parameters: {'p': RegExp(r'a.b')}),
        isTrue,
      );

      // Not a `String` or `RegExp`:
      expect(
        () => matches('name =~ /?:p/', o, parameters: {'p': 12}),
        throwsArgumentError,
      );
      expect(
        () => matches('name =~ /?:p/', o, parameters: {}),
        throwsArgumentError,
      );
    });

    test('a `RegExp` as a `==`/`IN` parameter: an error', () {
      var o = {'name': 'Joe'};
      for (var q in ['name =~ ?', 'name !~ ?', 'name == ?', 'name != ?']) {
        expect(
          () => matches(q, o, positionalParameters: [RegExp('J')]),
          throwsArgumentError,
          reason: q,
        );
      }
      expect(
        () => matches(
          'name =~ ?',
          o,
          positionalParameters: [
            [RegExp('J')],
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('SQLRegExpSyntax', () {
    test('matchSQL', () {
      String sql(
        SQLRegExpSyntax s, {
        bool ci = false,
        bool not = false,
        bool cast = false,
      }) => s.matchSQL(
        'col',
        '@p',
        caseInsensitive: ci,
        not: not,
        castToText: cast,
      );

      var pg = SQLRegExpSyntax.postgres;
      expect(sql(pg), equals('col ~ @p'));
      expect(sql(pg, ci: true), equals('col ~* @p'));
      expect(sql(pg, not: true), equals('col !~ @p'));
      expect(sql(pg, ci: true, not: true), equals('col !~* @p'));
      expect(sql(pg, cast: true), equals('CAST(col AS TEXT) ~ @p'));

      var my = SQLRegExpSyntax.mysql;
      expect(sql(my), equals("REGEXP_LIKE(col, @p, 'cn')"));
      expect(sql(my, ci: true), equals("REGEXP_LIKE(col, @p, 'in')"));
      expect(
        sql(my, not: true, cast: true),
        equals("NOT REGEXP_LIKE(col, @p, 'cn')"),
      );

      for (var s in [SQLRegExpSyntax.function, SQLRegExpSyntax.dart]) {
        expect(sql(s), equals("regexp(@p, col, '')"));
        expect(sql(s, ci: true, not: true), equals("NOT regexp(@p, col, 'i')"));
      }
    });

    test('adaptPattern / dollarAsEndOfInput', () {
      String d(String p) => SQLRegExpSyntax.dollarAsEndOfInput(p);

      expect(d('abc'), equals('abc'));
      expect(d(r'abc$'), equals(r'abc\z'));
      expect(d(r'^a$|^b$'), equals(r'^a\z|^b\z'));
      expect(d(r'(a$)'), equals(r'(a\z)'));
      expect(d(r'a\$'), equals(r'a\$'));
      expect(d(r'a\\$'), equals(r'a\\\z'));
      expect(d(r'[$]$'), equals(r'[$]\z'));
      expect(d(r'[a\]$]$'), equals(r'[a\]$]\z'));
      expect(d(r'[^$a]b$'), equals(r'[^$a]b\z'));

      // Nested and POSIX classes (ICU), a `]` first in a class, quoting:
      expect(d(r'[[:digit:]$]+$'), equals(r'[[:digit:]$]+\z'));
      expect(d(r'[a[$]]$'), equals(r'[a[$]]\z'));
      expect(d(r'[]$]$'), equals(r'[]$]\z'));
      expect(d(r'[^]$]$'), equals(r'[^]$]\z'));
      expect(d(r'\Q$\E$'), equals(r'\Q$\E\z'));
      expect(d(r'\Q$'), equals(r'\Q$'));
      expect(d(r'a\'), equals(r'a\'));

      expect(SQLRegExpSyntax.mysql.adaptPattern(r'a$'), equals(r'a\z'));
      for (var s in [
        SQLRegExpSyntax.postgres,
        SQLRegExpSyntax.function,
        SQLRegExpSyntax.dart,
      ]) {
        expect(s.adaptPattern(r'a$'), equals(r'a$'), reason: '$s');
      }
    });

    test('adaptPattern / wordBoundaryAsPostgres', () {
      String w(String p) => SQLRegExpSyntax.wordBoundaryAsPostgres(p);

      expect(w('abc'), equals('abc'));
      expect(w(r'\bsmith\b'), equals(r'\ysmith\y'));
      expect(w(r'\Bmith'), equals(r'\Ymith'));
      // An escaped `\`, then `b`:
      expect(w(r'\\b'), equals(r'\\b'));
      // In a class, `\b` is a backspace (also in PostgreSQL):
      expect(w(r'[\b]\b'), equals(r'[\b]\y'));
      expect(w(r'[[:alpha:]\b]+\b'), equals(r'[[:alpha:]\b]+\y'));
      // `[` in a class is a literal (not nested):
      expect(w(r'[[]\b'), equals(r'[[]\y'));

      expect(SQLRegExpSyntax.postgres.adaptPattern(r'\bx$'), equals(r'\yx$'));
      for (var s in [
        SQLRegExpSyntax.mysql,
        SQLRegExpSyntax.function,
        SQLRegExpSyntax.dart,
      ]) {
        expect(s.adaptPattern(r'\bx'), equals(r'\bx'), reason: '$s');
      }
    });

    test('regexpFunction', () {
      var f = SQLRegExpSyntax.regexpFunction;
      expect(f('^a', 'abc'), isTrue);
      expect(f('^A', 'abc'), isFalse);
      expect(f('^A', 'abc', 'i'), isTrue);
      expect(f('^A', 'abc', ''), isFalse);
      expect(f(r'c$', 'abc\n'), isFalse);
      expect(f('a.c', 'a\nc'), isTrue);
      expect(f(r'^\d+$', 123), isTrue);
      expect(f('a', null), isNull);
      expect(f(null, 'a'), isNull);
    });
  });

  group('KeyConditionRegExp: SQL', () {
    ConditionSQLEncoder encoder(SQLRegExpSyntax syntax) => ConditionSQLEncoder(
      _TestSchemeProvider(),
      sqlElementQuote: '"',
      regExpSyntax: syntax,
    );

    Future<EncodingContext> encode(
      SQLRegExpSyntax syntax,
      String query, {
      Object? parameters,
    }) async =>
        await encoder(syntax)
            .encode(Condition.parse(query), 'account', parameters: parameters);

    test('a literal pattern: always a parameter', () async {
      var sql = await encode(SQLRegExpSyntax.postgres, "email =~ /^jo'; --/i");
      expect(sql.outputString, equals('( "ac"."email" ~* @regexp__p )'));
      expect(sql.parametersPlaceholders, equals({'regexp__p': "^jo'; --"}));

      var sql2 = await encode(
        SQLRegExpSyntax.mysql,
        r'email !~ /x$/ && pass =~ /y/',
      );
      expect(
        sql2.outputString,
        equals(
          "( ( NOT REGEXP_LIKE(\"ac\".\"email\", @regexp__p, 'cn') OR "
          "\"ac\".\"email\" IS NULL ) AND "
          "REGEXP_LIKE(\"ac\".\"pass\", @regexp__p_1, 'cn') )",
        ),
      );
      expect(
        sql2.parametersPlaceholders,
        equals({'regexp__p': r'x\z', 'regexp__p_1': 'y'}),
      );

      var sql3 = await encode(SQLRegExpSyntax.function, 'email =~ /a/');
      expect(
        sql3.outputString,
        equals("( regexp(@regexp__p, \"ac\".\"email\", '') )"),
      );
    });

    test('a non-text column: cast to text', () async {
      var sql = await encode(SQLRegExpSyntax.postgres, r'id =~ /^1\d$/');
      expect(
        sql.outputString,
        equals('( CAST("ac"."id" AS TEXT) ~ @regexp__p )'),
      );

      var sql2 = await encode(SQLRegExpSyntax.postgres, 'admin =~ /t/');
      expect(sql2.outputString, contains('CAST("ac"."admin" AS TEXT)'));
    });

    test('a related entity field (join)', () async {
      var sql = await encode(SQLRegExpSyntax.postgres, 'address.city =~ /x/');
      expect(sql.outputString, equals('( "ad"."city" ~ @regexp__p )'));
      expect(sql.fieldsReferencedTables, {
        TableFieldReference('account', 'address', int, 'address', 'id', int),
      });
    });

    test('a pattern parameter', () async {
      var sql = await encode(
        SQLRegExpSyntax.postgres,
        'email =~ /?:p/',
        parameters: {'p': '^jo'},
      );
      expect(sql.outputString, equals('( "ac"."email" ~ @p )'));
      expect(sql.parametersPlaceholders, equals({'p': '^jo'}));

      // A positional parameter: the field's key.
      var sql2 = await encode(
        SQLRegExpSyntax.postgres,
        'email !~ /?/',
        parameters: ['^jo'],
      );
      expect(
        sql2.outputString,
        equals('( ( "ac"."email" !~ @email OR "ac"."email" IS NULL ) )'),
      );
      expect(sql2.parametersPlaceholders, equals({'email': '^jo'}));

      // A `RegExp`: its pattern, and its case flag in the SQL.
      var sql3 = await encode(
        SQLRegExpSyntax.mysql,
        'email =~ /?:p/',
        parameters: {'p': RegExp(r'^jo$', caseSensitive: false)},
      );
      expect(
        sql3.outputString,
        equals("( REGEXP_LIKE(\"ac\".\"email\", @p, 'in') )"),
      );
      expect(sql3.parametersPlaceholders, equals({'p': r'^jo\z'}));

      // In memory (`dart`), the value as is (matched by the condition):
      var regExp = RegExp('^jo', caseSensitive: false);
      var sql4 = await encode(
        SQLRegExpSyntax.dart,
        'email =~ /?:p/',
        parameters: {'p': regExp},
      );
      expect(
        sql4.outputString,
        equals("( regexp(@p, \"ac\".\"email\", 'i') )"),
      );
      expect(sql4.parametersPlaceholders['p'], same(regExp));

      // Not a `String` or a `RegExp`:
      expect(
        () => encode(
          SQLRegExpSyntax.postgres,
          'email =~ /?:p/',
          parameters: {'p': 1},
        ),
        throwsArgumentError,
      );
    });

    test('a parameter key used for another value', () async {
      var sql = await encode(
        SQLRegExpSyntax.postgres,
        'email == ? && email =~ /?#1/',
        parameters: ['joe', '^j'],
      );
      expect(
        sql.outputString,
        equals('( "ac"."email" = @email AND "ac"."email" ~ @email_1 )'),
      );
      expect(
        sql.parametersPlaceholders,
        equals({'email': 'joe', 'email_1': '^j'}),
      );

      // The same value: the same key.
      var sql2 = await encode(
        SQLRegExpSyntax.postgres,
        'pass == ?:p && email =~ /?:p/',
        parameters: {'p': 'x'},
      );
      expect(
        sql2.outputString,
        equals('( "ac"."pass" = @p AND "ac"."email" ~ @p )'),
      );
      expect(sql2.parametersPlaceholders, equals({'p': 'x'}));
    });

    test(
      'positional parameters of the same field: not one placeholder',
      () async {
        // REGRESSION: both were `@id` bound to the 1st value (`id > 1 AND
        // id < 1`).
        var sql = await encode(
          SQLRegExpSyntax.postgres,
          'id > ? && id < ?',
          parameters: [1, 10],
        );
        expect(
          sql.outputString,
          equals('( "ac"."id" > @id AND "ac"."id" < @id_1 )'),
        );
        expect(sql.parametersPlaceholders, equals({'id': 1, 'id_1': 10}));

        // The same value: one placeholder.
        var sql2 = await encode(
          SQLRegExpSyntax.postgres,
          'id >= ? && id <= ?',
          parameters: [3, 3],
        );
        expect(sql2.parametersPlaceholders, equals({'id': 3}));

        // `IN` lists:
        var sql3 = await encode(
          SQLRegExpSyntax.postgres,
          'id =~ ? && id !~ ?',
          parameters: [
            [1, 2],
            [2],
          ],
        );
        expect(
          sql3.outputString,
          equals(
            '( "ac"."id" IN ( @id__0 , @id__1 ) AND '
            '( "ac"."id" NOT IN ( @id_1__0 ) OR "ac"."id" IS NULL ) )',
          ),
        );
        expect(
          sql3.parametersPlaceholders,
          equals({'id__0': 1, 'id__1': 2, 'id_1__0': 2}),
        );

        // Matched in memory with the positional values and the placeholders
        // (as `DBSQLMemoryAdapter` does):
        var c = Condition.parse('id > ? && id < ?');
        for (var (id, expected) in [(5, true), (1, false), (10, false)]) {
          expect(
            c.matchesEntityMap(
              {'id': id},
              positionalParameters: [1, 10],
              namedParameters: sql.parametersPlaceholders.cast(),
            ),
            expected,
            reason: 'id: $id',
          );
        }

        // A regexp first, then `!=` on the same field:
        var sql4 = await encode(
          SQLRegExpSyntax.mysql,
          r'email =~ /?/ && email != ?',
          parameters: [r'@corp\.com$', 'admin@corp.com'],
        );
        expect(
          sql4.outputString,
          equals(
            "( REGEXP_LIKE(\"ac\".\"email\", @email, 'cn') AND "
            '( "ac"."email" != @email_1 OR "ac"."email" IS NULL ) )',
          ),
        );
        expect(
          sql4.parametersPlaceholders,
          equals({'email': r'@corp\.com\z', 'email_1': 'admin@corp.com'}),
        );
      },
    );

    test('a `RegExp` as an `IN` parameter: an error', () async {
      expect(
        () => encode(
          SQLRegExpSyntax.postgres,
          'email =~ ?',
          parameters: [RegExp('x')],
        ),
        throwsArgumentError,
      );
      expect(
        () => encode(
          SQLRegExpSyntax.postgres,
          'email == ?:p',
          parameters: {'p': RegExp('x')},
        ),
        throwsArgumentError,
      );
    });
  });
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
