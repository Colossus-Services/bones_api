import 'dart:async';

import 'package:bones_api/bones_api.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';

/// [ClassReflection] extension.
extension ClassReflectionExtension<O> on ClassReflection<O> {
  /// Returns a [ClassReflectionEntityHandler] for instances of this reflected class ([classType]).
  ClassReflectionEntityHandler<O> get entityHandler =>
      ClassReflectionEntityHandler<O>(O);

  /// Lists the API methods of this reflected class.
  /// See [MethodReflectionExtension.isAPIMethod].
  List<MethodReflection<O, dynamic>> apiMethods() =>
      allMethods().where((m) => m.isAPIMethod).toList();
}

/// [MethodReflection] extension.
extension MethodReflectionExtension<O, R> on MethodReflection<O, R> {
  /// Returns `true` if this reflected method is an API method ([returnsAPIResponse] OR [receivesAPIRequest]).
  bool get isAPIMethod => returnsAPIResponse || receivesAPIRequest;

  /// Returns `true` if this reflected method is [returnsAPIResponse] AND [receivesAPIRequest].
  bool get isFullAPIMethod => returnsAPIResponse && receivesAPIRequest;

  /// Returns `true` if this reflected method receives an [APIRequest] as parameter.
  bool get receivesAPIRequest => equalsNormalParametersTypes([APIRequest]);

  /// Returns `true` if this reflected method returns an [APIResponse].
  bool get returnsAPIResponse {
    var returnType = this.returnType;
    if (returnType == null) return false;

    var type = returnType.type;

    return type == APIResponse ||
        ((type == Future || type == FutureOr) &&
            (returnType.equalsArgumentsTypes([APIResponse])));
  }
}

/// Extension for a [Map] of [String] keys.
extension EntityMapExtension on Map<String, Object?> {
  /// Gets a [key] value parsing to [V] type.
  ///
  /// See [TypeParser.parserFor].
  V? get<V>(String key, [V? def]) {
    var parser = TypeParser.parserFor<V>();
    return getParsed(key, parser == null ? null : (o) => parser(o) as V?, def);
  }

  /// Gets a [key] value parsing as [bool].
  ///
  /// - [def] is the default value if the value is invalid.
  bool? getAsBool(String key, [bool? def]) =>
      getParsed(key, TypeParser.parseBool, def);

  /// Gets a [key] value parsing as [int].
  ///
  /// - [def] is the default value if the value is invalid.
  int? getAsInt(String key, [int? def]) =>
      getParsed(key, TypeParser.parseInt, def);

  /// Gets a [key] value parsing as [double].
  ///
  /// - [def] is the default value if the value is invalid.
  double? getAsDouble(String key, [double? def]) =>
      getParsed(key, TypeParser.parseDouble, def);

  /// Gets a [key] value parsing to [num] type.
  ///
  /// - [def] is the default value if the value is invalid.
  num? getAsNum(String key, [num? def]) =>
      getParsed(key, TypeParser.parseNum, def);

  /// Gets a [key] value parsing as [String].
  ///
  /// - [def] is the default value if the value is invalid.
  String? getAsString(String key, [String? def]) =>
      getParsed(key, TypeParser.parseString, def);

  /// Gets a [key] value parsing as [List].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [elementParser] is the parser to use for each element in the [List].
  List<E>? getAsList<E>(String key,
          {List<E>? def, TypeElementParser<E>? elementParser}) =>
      getParsed(
          key,
          (l) => TypeParser.parseList<E>(l,
              def: def, elementParser: elementParser),
          def);

  /// Gets a [key] value parsing as [Map].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [keyParser] is the parser to use for each key in the [Map].
  /// - [valueParser] is the parser to use for each value in the [Map].
  Map<K, V>? getAsMap<K, V>(String key,
          {Map<K, V>? def,
          TypeElementParser<K>? keyParser,
          TypeElementParser<V>? valueParser}) =>
      getParsed(
          key,
          (m) => TypeParser.parseMap<K, V>(m,
              def: def, keyParser: keyParser, valueParser: valueParser),
          def);

  /// Gets a [key] value parsing as [Set].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [elementParser] is the parser to use for each element in the [Set].
  Set<E>? getAsSet<E>(String key,
          {Set<E>? def, TypeElementParser<E>? elementParser}) =>
      getParsed(
          key,
          (s) => TypeParser.parseSet(s, def: def, elementParser: elementParser),
          def);

  /// Gets a [key] value parsing with [parser].
  ///
  /// - [def] is the default value if the value is invalid.
  V? getParsed<V>(String key, TypeElementParser<V>? parser, [V? def]) {
    var value = this[key];
    if (parser != null) {
      var val2 = parser(value);
      return val2 ?? def;
    } else {
      return (value as V?) ?? def;
    }
  }
}
