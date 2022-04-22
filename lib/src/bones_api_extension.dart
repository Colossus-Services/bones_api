import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';
import 'bones_api_module.dart';

/// [ReflectionFactory] extension.
extension ReflectionFactoryExtension on ReflectionFactory {
  /// Returns the registered [ClassReflectionEntityHandler] for [classType].
  ClassReflectionEntityHandler<O>? getRegisterEntityHandler<O>(
      [Type? classType]) {
    var classReflection = getRegisterClassReflection<O>(classType);
    return classReflection?.entityHandler;
  }

  /// Creates an instance [O] from [map] for [classType] (or [O]).
  ///
  /// - Requires a registered [ClassReflection] for [O] or [classType].
  /// - Uses a [ClassReflectionEntityHandler] for [O] or [classType].
  FutureOr<O?> createFromMap<O>(Map<String, dynamic> map,
      {Type? classType,
      EntityProvider? entityProvider,
      EntityCache? entityCache}) {
    var entityHandler = getRegisterEntityHandler<O>(classType);
    return entityHandler?.createFromMap(map,
        entityProvider: entityProvider, entityCache: entityCache);
  }
}

/// [ClassReflection] extension.
extension ClassReflectionExtension<O> on ClassReflection<O> {
  static final Expando<ClassReflectionEntityHandler> _expandoEntityHandlers =
      Expando<ClassReflectionEntityHandler>();

  /// Returns a [ClassReflectionEntityHandler] for instances of this reflected class ([classType]).
  ClassReflectionEntityHandler<O> get entityHandler {
    var classReflection = withoutObjectInstance();

    var entityHandler = _expandoEntityHandlers[classReflection]
        as ClassReflectionEntityHandler<O>?;

    if (entityHandler == null) {
      entityHandler = _createEntityHandler();
      _expandoEntityHandlers[classReflection] = entityHandler;
    }

    return entityHandler;
  }

  ClassReflectionEntityHandler<O> _createEntityHandler() {
    return callCasted<ClassReflectionEntityHandler<O>>(<T>(classReflection) {
      var classType = classReflection.classType;
      var reflection = classReflection.withoutObjectInstance();
      return ClassReflectionEntityHandler<T>(classType, reflection: reflection)
          as ClassReflectionEntityHandler<O>;
    });
  }

  /// Creates an instance [O] from [map].
  FutureOr<O> createFromMap(Map<String, dynamic> map,
      {EntityProvider? entityProvider, EntityCache? entityCache}) {
    return entityHandler.createFromMap(map,
        entityProvider: entityProvider, entityCache: entityCache);
  }

  /// Lists the API methods of this reflected class.
  /// See [MethodReflectionExtension.isAPIMethod].
  List<MethodReflection<O, dynamic>> apiMethods() =>
      allMethods().where((m) => m.isAPIMethod).toList();
}

/// [MethodReflection] extension.
extension MethodReflectionExtension<O, R> on MethodReflection<O, R> {
  /// Returns `true` if this reflected method is an API method ([returnsAPIResponse] OR [receivesAPIRequest]).
  bool get isAPIMethod =>
      declaringType != APIModule && (returnsAPIResponse || receivesAPIRequest);

  /// Returns `true` if this reflected method is [returnsAPIResponse] AND [receivesAPIRequest].
  bool get isFullAPIMethod => returnsAPIResponse && receivesAPIRequest;

  /// Returns `true` if this reflected method receives an [APIRequest] as parameter.
  bool get receivesAPIRequest =>
      equalsNormalParametersTypes([APIRequest], equivalency: true);

  /// Returns `true` if this reflected method returns an [APIResponse].
  bool get returnsAPIResponse {
    var returnType = this.returnType;
    if (returnType == null) return false;

    var typeInfo = returnType.typeInfo;

    if (typeInfo.isOf(APIResponse) || typeInfo.isDynamic) return true;

    if (typeInfo.isFuture) {
      var arg = typeInfo.argumentType(0);
      if (arg == null) return false;

      if (arg.isOf(APIResponse) || arg.isDynamic) return true;
    }

    return false;
  }
}

/// Extension for [Map] to get key values.
extension MapGetterExtension<K, V> on Map<K, V> {
  /// Gets a [key] value.
  V? get(K key, {V? defaultValue, bool ignoreCase = false}) {
    var value = ignoreCase ? getIgnoreCase(key) : this[key];
    return value ?? defaultValue;
  }

  /// Gets a [key] value parsing to [T] type.
  ///
  /// See [TypeParser.parserFor].
  T? getAs<T>(K key, {T? defaultValue, bool ignoreCase = false}) {
    var parser = TypeParser.parserFor<T>();
    return getParsed(key, parser == null ? null : (o) => parser(o) as T?,
        defaultValue: defaultValue, ignoreCase: ignoreCase);
  }

  /// Gets a [key] value ignoring case.
  V? getIgnoreCase(K key, {V? defaultValue}) {
    var value = this[key];
    if (value != null) return value;

    if (key == null) {
      return defaultValue;
    }

    var keyStr = key.toString();

    for (var k in keys) {
      if (equalsIgnoreAsciiCase(keyStr, k.toString())) {
        var value = this[k];
        return value ?? defaultValue;
      }
    }

    return defaultValue;
  }

  /// Returns the existing key that matches [key] as case-insensitive.
  K? matchKeyIgnoreCase(K key) {
    if (containsKey(key)) return key;

    var keyStr = key.toString();

    for (var k in keys) {
      if (equalsIgnoreAsciiCase(keyStr, k.toString())) {}
    }

    return null;
  }

  /// Returns the existing key that matches [key].
  K? matchKey(K key) {
    if (containsKey(key)) return key;
    return null;
  }

  /// Gets a [key] value parsing as [bool].
  ///
  /// - [def] is the default value if the value is invalid.
  bool? getAsBool(K key, {bool? defaultValue, bool ignoreCase = false}) =>
      getParsed(key, TypeParser.parseBool,
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [int].
  ///
  /// - [def] is the default value if the value is invalid.
  int? getAsInt(K key, {int? defaultValue, bool ignoreCase = false}) =>
      getParsed(key, TypeParser.parseInt,
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [double].
  ///
  /// - [def] is the default value if the value is invalid.
  double? getAsDouble(K key, {double? defaultValue, bool ignoreCase = false}) =>
      getParsed(key, TypeParser.parseDouble,
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing to [num] type.
  ///
  /// - [def] is the default value if the value is invalid.
  num? getAsNum(K key, {num? defaultValue, bool ignoreCase = false}) =>
      getParsed(key, TypeParser.parseNum,
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [String].
  ///
  /// - [def] is the default value if the value is invalid.
  String? getAsString(K key, {String? defaultValue, bool ignoreCase = false}) =>
      getParsed(key, TypeParser.parseString,
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [List].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [elementParser] is the parser to use for each element in the [List].
  List<E>? getAsList<E>(K key,
          {List<E>? def,
          TypeElementParser<E>? elementParser,
          List<E>? defaultValue,
          bool ignoreCase = false}) =>
      getParsed(
          key,
          (l) => TypeParser.parseList<E>(l,
              def: def, elementParser: elementParser),
          defaultValue: defaultValue,
          ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [Map].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [keyParser] is the parser to use for each key in the [Map].
  /// - [valueParser] is the parser to use for each value in the [Map].
  Map<K, V>? getAsMap(K key,
          {Map<K, V>? def,
          TypeElementParser<K>? keyParser,
          TypeElementParser<V>? valueParser,
          Map<K, V>? defaultValue,
          bool ignoreCase = false}) =>
      getParsed(
          key,
          (m) => TypeParser.parseMap<K, V>(m,
              def: def, keyParser: keyParser, valueParser: valueParser),
          defaultValue: defaultValue,
          ignoreCase: ignoreCase);

  /// Gets a [key] value parsing as [Set].
  ///
  /// - [def] is the default value if the value is invalid.
  /// - [elementParser] is the parser to use for each element in the [Set].
  Set<E>? getAsSet<E>(K key,
          {Set<E>? def,
          TypeElementParser<E>? elementParser,
          Set<E>? defaultValue,
          bool ignoreCase = false}) =>
      getParsed(key,
          (s) => TypeParser.parseSet(s, def: def, elementParser: elementParser),
          defaultValue: defaultValue, ignoreCase: ignoreCase);

  /// Gets a [key] value parsing with [parser].
  ///
  /// - [defaultValue] is the default value if the value is invalid.
  T? getParsed<T>(K key, TypeElementParser<T>? parser,
      {T? defaultValue, bool ignoreCase = false}) {
    var value = ignoreCase ? getIgnoreCase(key) : this[key];
    if (parser != null) {
      var val2 = parser(value);
      return val2 ?? defaultValue;
    } else {
      return (value as T?) ?? defaultValue;
    }
  }
}

/// Extension for a multi-value [Map]: keys as [String] and values as `String` or `List<String>`.
extension MapMultiValueExtension<K> on Map<K, Object> {
  /// Sets the value for [key]. If the value already exists, ensures that is a `List<String>`.
  void setMultiValue(K key, String value, {bool ignoreCase = false}) {
    var keyMatch =
        (ignoreCase ? matchKeyIgnoreCase(key) : matchKey(key)) ?? key;

    var prev = this[keyMatch];

    if (prev == null) {
      this[keyMatch] = value;
    } else if (prev is String) {
      this[keyMatch] = [prev, value];
    } else if (prev is List<String>) {
      this[keyMatch] = [...prev, value];
    } else if (prev is List) {
      this[keyMatch] = <String>[
        ...prev.where((e) => e != null).map((e) => e!.toString()),
        value
      ];
    }
  }

  /// Returns the first values for [key].
  List<String>? getMultiValue(K key, {bool ignoreCase = false}) {
    var prev = ignoreCase ? getIgnoreCase(key) : get(key);

    if (prev == null) return null;
    if (prev is String) return [prev];

    if (prev is List<String>) return prev;

    if (prev is List) {
      return prev.where((e) => e != null).map((e) => e.toString()).toList();
    }

    return null;
  }

  /// Returns the first value for [key], if present.
  String? getFirstValue(K key, {bool ignoreCase = false}) {
    var prev = ignoreCase ? getIgnoreCase(key) : get(key);

    if (prev == null) return null;
    if (prev is String) return prev;

    if (prev is List<String>) return prev.isEmpty ? null : prev.first;

    if (prev is List) return prev.isEmpty ? null : prev.first.toString();

    return null;
  }
}
