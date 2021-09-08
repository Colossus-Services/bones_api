import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';

class ConditionSQLEncoder extends ConditionEncoder {
  ConditionSQLEncoder();

  @override
  String get groupOpener => '(';

  @override
  String get groupCloser => ')';

  @override
  String get groupOperatorAND => 'AND';

  @override
  String get groupOperatorOR => 'OR';

  @override
  String parameterPlaceholder(String parameterKey) => '@$parameterKey';

  @override
  StringBuffer encodeIDCondition(
      IDCondition c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    s.write(' id = ');

    var valueSQL = valueToSQL(
        c.idValue, p, parameters, positionalParameters, namedParameters);

    s.write(valueSQL);
    s.write(' ');

    return s;
  }

  @override
  StringBuffer encodeKeyConditionEQ(
      KeyConditionEQ c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    var keySQL = keyToSQL(c);

    s.write(' ');
    s.write(keySQL);

    s.write(" = ");

    var valueSQL = valueToSQL(
        c.value, p, parameters, positionalParameters, namedParameters);

    s.write(valueSQL);
    s.write(' ');

    return s;
  }

  @override
  StringBuffer encodeKeyConditionNotEQ(
      KeyConditionNotEQ c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    var keySQL = keyToSQL(c);

    s.write(' ');
    s.write(keySQL);

    s.write(" != ");

    var valueSQL = valueToSQL(
        c.value, p, parameters, positionalParameters, namedParameters);

    s.write(valueSQL);
    s.write(' ');

    return s;
  }

  String keyToSQL(KeyCondition<dynamic> c) {
    if (c.keys.length == 1) {
      var key = c.keys[0];

      if (key is ConditionKeyField) {
        return '"${key.name}"';
      }
    }

    throw ConditionEncodingError("Key: $c");
  }

  String valueToSQL(dynamic value, Map<String, dynamic> p, Object? parameters,
      List? positionalParameters, Map<String, Object?>? namedParameters) {
    if (value is ConditionParameter) {
      return conditionParameterToSQL(
          value, p, parameters, positionalParameters, namedParameters);
    } else if (value is num || value is bool) {
      return value.toString();
    } else {
      var valueStr = '$value';
      valueStr = valueStr.replaceAll("'", r"\'");
      return "'$valueStr'";
    }
  }

  String conditionParameterToSQL(
      ConditionParameter parameter,
      Map<String, dynamic> p,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    if (parameter.hasKey) {
      return resolveParameterSQL(parameter.key!, parameter, p, parameters,
          positionalParameters, namedParameters);
    } else {
      var contextKey = parameter.contextKey;

      if (contextKey != null) {
        return resolveParameterSQL(contextKey, parameter, p, parameters,
            positionalParameters, namedParameters);
      }

      throw ConditionEncodingError('$parameter');
    }
  }
}
