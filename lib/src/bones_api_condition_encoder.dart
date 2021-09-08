import 'bones_api_condition.dart';

abstract class ConditionEncoder {
  ConditionEncoder();

  String encode(
      Condition condition, Map<String, dynamic> parametersPlaceholders,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var s = StringBuffer();

    var rootIsGroup = condition is GroupCondition;

    if (!rootIsGroup) {
      s.write(groupOpener);
    }

    encodeCondition(condition, parametersPlaceholders, s, parameters,
        positionalParameters, namedParameters);

    if (!rootIsGroup) {
      s.write(groupCloser);
    }

    return s.toString();
  }

  StringBuffer encodeCondition(
      Condition c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    if (c is KeyCondition) {
      return encodeKeyCondition(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else if (c is GroupCondition) {
      return encodeGroupCondition(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else if (c is IDCondition) {
      return encodeIDCondition(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  StringBuffer encodeIDCondition(
      IDCondition c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters);

  StringBuffer encodeGroupCondition(
      GroupCondition c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    if (c is GroupConditionAND) {
      return encodeGroupConditionAND(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else if (c is GroupConditionOR) {
      return encodeGroupConditionOR(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  String get groupOpener;

  String get groupCloser;

  String get groupOperatorAND;

  String get groupOperatorOR;

  StringBuffer encodeGroupConditionAND(
    GroupConditionAND c,
    Map<String, dynamic> p,
    StringBuffer? s,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    s ??= StringBuffer();

    var conditions = c.conditions;
    var length = conditions.length;

    if (length == 0) {
      return s;
    }

    s.write(groupOpener);
    encodeCondition(conditions.first, p, s, parameters, positionalParameters,
        namedParameters);

    for (var i = 1; i < length; ++i) {
      s.write(groupOperatorAND);

      var c2 = conditions[i];
      encodeCondition(
          c2, p, s, parameters, positionalParameters, namedParameters);
    }

    s.write(groupCloser);

    return s;
  }

  StringBuffer encodeGroupConditionOR(
      GroupConditionOR c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    var conditions = c.conditions;
    var length = conditions.length;

    if (length == 0) {
      return s;
    }

    s.write(groupOpener);

    encodeCondition(conditions.first, p, s, parameters, positionalParameters,
        namedParameters);

    for (var i = 1; i < length; ++i) {
      s.write(groupOperatorOR);

      var c2 = conditions[i];
      encodeCondition(
          c2, p, s, parameters, positionalParameters, namedParameters);
    }

    s.write(groupCloser);

    return s;
  }

  StringBuffer encodeKeyCondition(
      KeyCondition c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    s ??= StringBuffer();

    if (c is KeyConditionEQ) {
      return encodeKeyConditionEQ(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else if (c is KeyConditionNotEQ) {
      return encodeKeyConditionNotEQ(
          c, p, s, parameters, positionalParameters, namedParameters);
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  StringBuffer encodeKeyConditionEQ(
      KeyConditionEQ c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters);

  StringBuffer encodeKeyConditionNotEQ(
      KeyConditionNotEQ c,
      Map<String, dynamic> p,
      StringBuffer? s,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters);

  String resolveParameterSQL(
      String valueKey,
      ConditionParameter value,
      Map<String, dynamic> p,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters) {
    p.putIfAbsent(
        valueKey,
        () => value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters));

    var placeholder = parameterPlaceholder(valueKey);
    return placeholder;
  }

  String parameterPlaceholder(String parameterKey);
}

class ConditionEncodingError extends Error {
  final String message;

  ConditionEncodingError(this.message);

  @override
  String toString() => "Encoding error: $message";
}
