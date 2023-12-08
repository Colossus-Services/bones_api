import 'package:petitparser/petitparser.dart';

import 'bones_api_condition.dart';

const Map<String, String> jsonEscapeChars = {
  '\\': '\\',
  '/': '/',
  '"': '"',
  'b': '\b',
  'f': '\f',
  'n': '\n',
  'r': '\r',
  't': '\t'
};

const Map<String, String> jsonEscapeChars2 = {
  ...jsonEscapeChars,
  "'": "'",
};

final jsonEscapeCharsString = jsonEscapeChars.keys.join();
final jsonEscapeCharsString2 = jsonEscapeChars2.keys.join();

/// JSON grammar lexer.
abstract class JsonGrammarLexer extends GrammarDefinition {
  Parser<String> token(Object source, [String? name]) {
    if (source is String) {
      return source.toParser(message: 'Expected ${name ?? source}').trim();
    } else if (source is Parser) {
      ArgumentError.checkNotNull(name, 'name');
      return source.flatten('Expected $name').trim();
    } else {
      throw ArgumentError('Unknown token type: $source.');
    }
  }

  Parser jsonValue();

  Parser jsonValue2();

  Parser<List> array() =>
      char('[').trim() & ref0(elements).optional() & char(']').trim();

  Parser<List> array2() =>
      char('[').trim() & ref0(elements2).optional() & char(']').trim();

  Parser<List> elements() =>
      ref0(jsonValue).plusSeparated(char(',')).map((l) => l.elements);

  Parser<List> elements2() =>
      ref0(jsonValue2).plusSeparated(char(',')).map((l) => l.elements);

  Parser<List> object() =>
      char('{').trim() & ref0(members).optional() & char('}').trim();

  Parser<List> object2() =>
      char('{').trim() & ref0(members2).optional() & char('}').trim();

  Parser<List> members() =>
      ref0(pair).plusSeparated(char(',')).map((l) => l.elements);

  Parser<List> members2() =>
      ref0(pair2).plusSeparated(char(',')).map((l) => l.elements);

  Parser<List> pair() => keyToken() & char(':').trim() & ref0(jsonValue);

  Parser<List> pair2() => keyToken2() & char(':').trim() & ref0(jsonValue2);

  Parser<String> keyToken() => stringPrimitive().map((l) {
        return (l[1] as List).join();
      }).trim();

  Parser<String> keyToken2() =>
      (wordPrimitive().flatten() | stringPrimitive2()).map((l) {
        if (l is List) {
          return (l[1] as List).join();
        } else {
          return l as String;
        }
      }).trim();

  Parser<String> trueToken() => token('true');

  Parser<String> falseToken() => token('false');

  Parser<String> nullToken() => token('null');

  Parser<String> numberToken() => token(numberPrimitive(), 'number');

  Parser<dynamic> characterPrimitive() =>
      characterNormal() | characterEscapeValue() | characterUnicodeValue();

  Parser<dynamic> characterPrimitive2() =>
      characterNormal2() | characterEscapeValue2() | characterUnicodeValue();

  Parser<String> characterNormal() => pattern('^"\\');

  Parser<String> characterNormal2() => pattern("^'\\");

  Parser<List> characterEscape() => char('\\') & pattern(jsonEscapeCharsString);

  Parser<String> characterEscapeValue() =>
      characterEscape().map((each) => jsonEscapeChars[each[1]]!);

  Parser<String> characterEscapeValue2() =>
      characterEscape().map((each) => jsonEscapeChars2[each[1]]!);

  Parser<List> characterUnicode() =>
      string('\\u') & pattern('0-9A-Fa-f').times(4);

  Parser<String> characterUnicodeValue() => characterUnicode().map((each) {
        Object each_1 = each[1] ?? '';
        var s = each_1 is List ? each_1.join() : each_1.toString();
        final charCode = int.parse(s, radix: 16);
        return String.fromCharCode(charCode);
      });

  Parser<List> numberPrimitive() =>
      char('-').optional() &
      char('0').or(digit().plus()) &
      char('.').seq(digit().plus()).optional() &
      pattern('eE')
          .seq(pattern('-+').optional())
          .seq(digit().plus())
          .optional();

  Parser<String> wordPrimitive() =>
      ((letter() | char('_')) & word().star()).flatten();

  Parser<List> stringPrimitive() =>
      char('"') & ref0(characterPrimitive).star() & char('"');

  Parser<List> stringPrimitiveExtra() =>
      char("'") & ref0(characterPrimitive2).star() & char("'");

  Parser<List> stringPrimitive2() => <Parser<List>>[
        stringPrimitive(),
        stringPrimitiveExtra()
      ].toChoiceParser();
}

/// JSON grammar definition.
class JsonGrammarDefinition extends JsonGrammarLexer {
  final bool extendedGrammar;

  JsonGrammarDefinition(this.extendedGrammar);

  @override
  Parser start() => ref0(extendedGrammar ? jsonValue2 : jsonValue).end();

  @override
  Parser jsonValue() => [
        stringValue(),
        numberValue(),
        ref0(objectValue),
        ref0(arrayValue),
        trueValue(),
        falseValue(),
        nullValue(),
      ].toChoiceParser(failureJoiner: selectFarthestJoined);

  @override
  Parser jsonValue2() => [
        stringValue2(),
        numberValue(),
        ref0(objectValue2),
        ref0(arrayValue2),
        trueValue(),
        falseValue(),
        nullValue(),
      ].toChoiceParser(failureJoiner: selectFarthestJoined);

  Parser<List<dynamic>> arrayValue() => _mapArrayValue(array());

  Parser<List<dynamic>> arrayValue2() => _mapArrayValue(array2());

  Parser<List<dynamic>> _mapArrayValue(Parser<dynamic> ar) {
    return ar.map((each) {
      if (each is! List) return [];
      return each[1] ?? [];
    });
  }

  Parser<Map<String, dynamic>> objectValue() => _mapObjectValue(object());

  Parser<Map<String, dynamic>> objectValue2() => _mapObjectValue(object2());

  Parser<Map<String, dynamic>> _mapObjectValue(Parser<dynamic> obj) {
    return obj.map((each) {
      final result = <String, dynamic>{};
      if (each is List) {
        var l_1 = each[1];
        if (l_1 is Iterable) {
          for (final elem in l_1.whereType<List>()) {
            var key = elem[0];
            var value = elem[2];
            result[key] = value;
          }
        }
      }
      return result;
    });
  }

  Parser<bool> trueValue() => trueToken().map((each) => true);

  Parser<bool> falseValue() => falseToken().map((each) => false);

  // ignore: prefer_void_to_null
  Parser<Null> nullValue() => nullToken().map((each) => null);

  Parser<String> stringValue() => stringPrimitive().map<String>((l) {
        var l_1 = l[1];
        if (l_1 is! List) return l_1?.toString() ?? '';
        return l_1.join();
      }).trim();

  Parser<String> stringValue2() => stringPrimitive2().map<String>((l) {
        var l_1 = l[1];
        if (l_1 is! List) return l_1?.toString() ?? '';
        return l_1.join();
      }).trim();

  Parser<num> numberValue() => numberToken().map((each) => num.parse(each));
}

/// Condition grammar definition.
class ConditionGrammarDefinition extends JsonGrammarDefinition {
  ConditionGrammarDefinition() : super(true);

  @override
  Parser start() => ref0(condition).end();

  Parser<Condition> condition() =>
      (conditionGroup() | conditionParenthesis() | conditionMatch())
          .map((v) => v as Condition);

  Parser<Condition> conditionParenthesisOrValue() =>
      (conditionParenthesis() | conditionMatch()).map((v) {
        return v as Condition;
      });

  Parser<Condition> conditionParenthesis() => (char('(').trim() &
              (conditionGroup() | conditionMatch()) &
              char(')').trim())
          .map((l) {
        return l[1] as Condition;
      });

  Parser<Condition> conditionGroup() =>
      (conditionGroupAND() | conditionGroupOR()).map((v) => v as Condition);

  Parser<GroupConditionAND> conditionGroupAND() =>
      (ref0(conditionParenthesisOrValue) &
              (string('&&').trim() & ref0(conditionParenthesisOrValue)).plus())
          .map((l) {
        var v1 = l[0];
        var v2 = (l[1] as List)
            .expand((e) => e is List ? e : [e])
            .whereType<Condition>();
        return GroupConditionAND([v1, ...v2]);
      });

  Parser<GroupConditionOR> conditionGroupOR() =>
      (ref0(conditionParenthesisOrValue) &
              (string('||').trim() & ref0(conditionParenthesisOrValue)).plus())
          .map((l) {
        var v1 = l[0];
        var v2 = (l[1] as List)
            .expand((e) => e is List ? e : [e])
            .whereType<Condition>();
        return GroupConditionOR([v1, ...v2]);
      });

  Parser<Condition> conditionMatch() =>
      (conditionID() | conditionKeyValue()).cast<Condition>();

  Parser<Condition> conditionKeyValue() =>
      (conditionKeys() & conditionOperator() & conditionValue()).map((l) {
        var keys = l[0] as List<ConditionKey>;
        var op = l[1] as String;
        var value = l[2];

        switch (op) {
          case '=':
          case '==':
            return KeyConditionEQ(keys, value);
          case '!=':
            return KeyConditionNotEQ(keys, value);
          case '=~':
            return KeyConditionIN(keys, value);
          case '!~':
            return KeyConditionNotIN(keys, value);
          case '>':
            return KeyConditionGreaterThan(keys, value);
          case '>=':
            return KeyConditionGreaterThanOrEqual(keys, value);
          case '<':
            return KeyConditionLessThan(keys, value);
          case '<=':
            return KeyConditionLessThanOrEqual(keys, value);
          default:
            throw FormatException('Unknown operator: $keys $op $value');
        }
      });

  Parser<List<ConditionKey>> conditionKeys() =>
      (conditionKey() & (char('.') & conditionKey()).map((l) => l[1]).star())
          .map((l) {
        var head = l[0] as ConditionKey;
        var tail = (l[1] as List).cast<ConditionKey>();
        return [head, ...tail];
      });

  Parser<ConditionKey> conditionKey() =>
      (conditionKeyIndex() | conditionKeyField()).cast<ConditionKey>();

  Parser<ConditionKeyIndex> conditionKeyIndex() => (char('[').trim() &
              (char('-').optional() & digit().plus()).flatten() &
              char(']').trim())
          .map((l) {
        var idx = int.parse(l[1]);
        return ConditionKeyIndex(idx);
      });

  Parser<ConditionKeyField> conditionKeyField() =>
      (wordPrimitive().flatten() | stringPrimitive2()).trim().map((l) {
        String s;
        if (l is List) {
          s = (l[1] as List).join();
        } else {
          s = l as String;
        }
        return ConditionKeyField(s);
      });

  Parser<ConditionID> conditionID() =>
      (string('#ID').trim() & string('==').trim() & conditionValue()).map((l) {
        var value = l[2];

        return ConditionID(value);
      });

  Parser<String> conditionOperator() => (string('==') |
          string('!=') |
          string('=~') |
          string('!~') |
          string('>=') |
          string('<=') |
          string('>') |
          string('<'))
      .flatten()
      .trim();

  Parser conditionValue() => (jsonValue2() | conditionParameter());

  Parser conditionParameter() => (conditionParameterIndex() |
      conditionParameterKey() |
      conditionParameterPositional());

  Parser<ConditionParameter> conditionParameterIndex() =>
      (char('?') & (char('#') & digit().star().flatten())).trim().map((l) {
        var idxPart = l[1] as List;
        var idxStr = idxPart[1] as String;
        var idx = idxStr.isNotEmpty ? int.parse(idxStr) : -1;
        return ConditionParameter.index(idx);
      });

  Parser<ConditionParameter> conditionParameterKey() =>
      (char('?') & (char(':') & word().star().flatten())).trim().map((l) {
        var keyPart = l[1] as List;
        var key = keyPart[1] as String;
        return ConditionParameter.key(key);
      });

  Parser<ConditionParameter> conditionParameterPositional() =>
      char('?').trim().map((l) => ConditionParameter());
}

class JsonParser {
  final JsonGrammarDefinition _grammar;

  JsonParser({bool extendedGrammar = false})
      : _grammar = JsonGrammarDefinition(extendedGrammar);

  Parser<dynamic>? _grammarParserInstance;

  Parser<dynamic> get _grammarParser {
    _grammarParserInstance ??= _grammar.build();
    return _grammarParserInstance!;
  }

  dynamic parse(String code) {
    var result = _grammarParser.parse(code);

    if ((result is Failure) || (result is! Success)) {
      throw FormatException(result.message);
    }

    return result.value;
  }
}

class ConditionParser {
  final ConditionGrammarDefinition _grammar;

  ConditionParser() : _grammar = ConditionGrammarDefinition();

  Parser<dynamic>? _grammarParserInstance;

  Parser<dynamic> get _grammarParser {
    _grammarParserInstance ??= _grammar.build();
    return _grammarParserInstance!;
  }

  Condition<O> parse<O>(String code) {
    var result = _grammarParser.parse(code);

    if ((result is Failure) || (result is! Success)) {
      throw FormatException(result.message);
    }

    var condition = result.value as Condition;

    var parameters = <ConditionParameter>[];
    condition.resolve(parameters: parameters);

    return condition.cast<O>();
  }
}
