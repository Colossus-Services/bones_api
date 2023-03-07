import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_initializable.dart';
import 'bones_api_module.dart';
import 'bones_api_utils.dart';

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
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    var entityHandler = getRegisterEntityHandler<O>(classType);
    return entityHandler?.createFromMap(map,
        entityProvider: entityProvider,
        entityCache: entityCache,
        resolutionRules: resolutionRules);
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

  List<O> toList([O? obj]) => [object ?? obj!];

  EntityReference<O> toEntityReference([O? obj]) =>
      EntityReference<O>.fromEntity(object ?? obj);

  EntityReferenceList<O> toEntityReferenceList(List<O> entities) =>
      EntityReferenceList<O>.fromEntities(entities);

  bool isValidFieldValue<V>(String key,
          {O? obj, V? value, bool nullValue = false}) =>
      entityHandler.isValidFieldValue(obj ?? object!, key,
          value: value, nullValue: nullValue);

  EntityFieldInvalid? validateFieldValue<V>(String key,
          {O? obj, V? value, bool nullValue = false}) =>
      entityHandler.validateFieldValue(obj ?? object!, key,
          value: value, nullValue: nullValue);

  void checkFieldValue<V>(String key,
          {O? obj, V? value, bool nullValue = false}) =>
      entityHandler.checkFieldValue(obj ?? object!, key,
          value: value, nullValue: nullValue);

  bool allFieldsValids<V>({O? obj}) =>
      entityHandler.allFieldsValids(obj ?? object!);

  Map<String, EntityFieldInvalid>? validateAllFields<V>({O? obj}) =>
      entityHandler.validateAllFields(obj ?? object!);

  void checkAllFieldsValues<V>({O? obj}) =>
      entityHandler.checkAllFieldsValues(obj ?? object!);

  /// Creates an instance [O] from [map].
  FutureOr<O> createFromMap(Map<String, dynamic> map,
          {EntityProvider? entityProvider,
          EntityCache? entityCache,
          EntityResolutionRules? resolutionRules}) =>
      entityHandler.createFromMap(map,
          entityProvider: entityProvider,
          entityCache: entityCache,
          resolutionRules: resolutionRules);

  O createFromMapSync(Map<String, dynamic> map,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    // ignore: discarded_futures
    var o = createFromMap(map,
        entityProvider: entityProvider,
        entityCache: entityCache,
        resolutionRules: resolutionRules);
    if (o is Future) {
      throw StateError(
          "createFromMapSync> sub-call to `createFromMap` returned a `Future` for: $map");
    }
    return o;
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
      (declaringType != APIModule && declaringType != Initializable) &&
      (returnsAPIResponse || receivesAPIRequest);

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

    if (typeInfo.isFuture || typeInfo.isFutureOr) {
      var arg = typeInfo.arguments0;
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
    return getParsed(key, parser == null ? null : (o) => parser(o),
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
    } else if (value is T?) {
      return value ?? defaultValue;
    } else {
      throw ArgumentError("Can't parse key('$key') value as `$T`: $value");
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

/// Extension over [TypeReflection] for entity functionalities.
extension TypeReflectionEntityExtension<T> on TypeReflection<T> {
  /// The argument at index `0` (in [arguments]).
  TypeReflection? get arguments0 {
    final arguments = this.arguments;
    return arguments.isNotEmpty ? arguments[0] : null;
  }

  /// Returns `true` if [isListEntity] OR [isEntityReferenceListType].
  bool get isListEntityOrReference => isListEntity || isEntityReferenceListType;

  /// Returns the entity [TypeInfo] if [isListEntityOrReference].
  TypeReflection? get listEntityOrReferenceType =>
      isListEntityOrReference ? arguments0 : null;

  /// Returns `true` if [isListEntity] AND [EntityHandler.isValidEntityType] for the entity type ([argumentType] `0`).
  bool get isValidListEntityType =>
      isListEntity ? EntityHandler.isValidEntityType(arguments0!.type) : false;

  /// Returns `true` if [isListEntityOrReference] AND [EntityHandler.isValidEntityType] for the entity type ([argumentType] `0`).
  bool get isValidListEntityOrReferenceType => isListEntityOrReference
      ? EntityHandler.isValidEntityType(arguments0!.type)
      : false;

  /// Returns `true` if [type] is equals to [EntityReference].
  bool get isEntityReferenceType => type == EntityReference;

  /// Returns `true` if [type] is equals to [EntityReferenceList].
  bool get isEntityReferenceListType => type == EntityReferenceList;

  /// Returns a valid entity [Type].
  /// If this [TypeInfo] is an [EntityReference] it will return the [EntityReference.type].
  /// See [EntityHandler.isValidEntityType].
  Type? get entityType {
    var type = this.type;

    Type? entityType;
    if (type.isEntityReferenceBaseType) {
      var arguments = this.arguments;
      entityType = arguments.isNotEmpty ? arguments0!.type : null;
    } else {
      entityType = type;
    }

    return EntityHandler.isValidEntityType(entityType) ? entityType : null;
  }
}

/// Extension over [TypeInfo] for entity functionalities.
extension TypeInfoEntityExtension<T> on TypeInfo<T> {
  /// The argument at index `0` (in [arguments]).
  TypeInfo? get arguments0 => argumentType(0);

  /// The argument at index `1` (in [arguments]).
  TypeInfo? get arguments1 => argumentType(1);

  /// Returns `true` if [isListEntity] OR [isEntityReferenceListType].
  bool get isListEntityOrReference => isListEntity || isEntityReferenceListType;

  /// Returns the entity [TypeInfo] if [isListEntityOrReference].
  TypeInfo? get listEntityOrReferenceType =>
      isListEntityOrReference ? arguments0 : null;

  /// Returns `true` if [isListEntity] AND [EntityHandler.isValidEntityType] for the entity type ([argumentType] `0`).
  bool get isValidListEntityType =>
      isListEntity ? EntityHandler.isValidEntityType(arguments0!.type) : false;

  /// Returns `true` if [isListEntityOrReference] AND [EntityHandler.isValidEntityType] for the entity type ([argumentType] `0`).
  bool get isValidListEntityOrReferenceType => isListEntityOrReference
      ? EntityHandler.isValidEntityType(arguments0!.type)
      : false;

  /// Returns `true` if [type] is equals to [EntityReference].
  bool get isEntityReferenceType => type == EntityReference;

  /// Returns `true` if [type] is equals to [EntityReferenceList].
  bool get isEntityReferenceListType => type == EntityReferenceList;

  /// Returns `true` if [isEntityReferenceType] and [arguments0] is a valid entity type.
  bool get isValidEntityReferenceType =>
      isEntityReferenceType &&
      EntityHandler.isValidEntityType(arguments0?.type);

  /// Returns `true` if [isEntityReferenceListType] and [arguments0] is a valid entity type.
  bool get isValidEntityReferenceListType =>
      isEntityReferenceListType &&
      EntityHandler.isValidEntityType(arguments0?.type);

  /// Returns `true` if [type] is equals to [EntityReference] OR [EntityReferenceList].
  bool get isEntityReferenceBaseType =>
      type == EntityReference || type == EntityReferenceList;

  /// Returns a valid entity [Type].
  /// If this [TypeInfo] is an [EntityReference] it will return the [EntityReference.type].
  /// See [EntityHandler.isValidEntityType].
  Type? get entityType {
    var type = this.type;

    Type? entityType;
    if (type.isEntityReferenceBaseType) {
      entityType = arguments0?.type;
    } else {
      entityType = type;
    }

    return EntityHandler.isValidEntityType(entityType) ? entityType : null;
  }

  bool equalsEntityType(TypeInfo? other) {
    if (other == null) return false;

    var entityType1 = entityType;
    if (entityType1 == null) return false;

    var entityType2 = other.entityType;

    var eq = entityType1 == entityType2;
    return eq;
  }

  bool equalsTypeOrEntityType(TypeInfo? other) {
    if (other == null) return false;
    return equalsType(other) || equalsEntityType(other);
  }

  E? parseEntity<E>(Object? value) {
    if (isEntityReferenceType) {
      var entityType = arguments0;
      if (entityType != null) {
        return entityType.parse<E>(value);
      }
    } else if (isEntityReferenceListType) {
      var entityType = arguments0;
      if (entityType != null) {
        return entityType.parse<E>(value);
      }
    }

    return parse<E>(value);
  }

  V? resolveValue<V>(Object? value,
      {EntityHandler<T>? entityHandler,
      EntityProvider? entityProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityFetcher<T>? entityFetcher,
      EntityCache? entityCache}) {
    Object? resolvedValue = value;

    var forceToEntityReference = false;
    var forceToEntityReferenceList = false;

    if (value is EntityReference) {
      if (isEntityReferenceType) {
        if (genericType != value.genericType &&
            genericType != Object &&
            genericType != dynamic) {
          forceToEntityReference = true;
        }
      } else {
        if (value.isNull) {
          resolvedValue = null;
        } else if (value.isEntitySet && value.entity is V) {
          resolvedValue = value.entity;
        } else if (value.isIdSet && value.id is V) {
          resolvedValue = value.id;
        }
      }
    } else if (value is EntityReferenceList) {
      if (isEntityReferenceListType || isEntityReferenceType) {
        if (genericType != value.genericType &&
            genericType != Object &&
            genericType != dynamic) {
          forceToEntityReferenceList = true;
        }
      } else {
        if (value.isNull) {
          resolvedValue = null;
        } else if (value.isEntitiesSet && value.entities is V) {
          resolvedValue = value.entities;
        } else if (value.isIDsSet && value.ids is V) {
          resolvedValue = value.ids;
        }
      }
    } else if (isEntityReferenceListType) {
      forceToEntityReferenceList = true;
    } else if (isEntityReferenceType) {
      forceToEntityReference = true;
    }

    if (forceToEntityReferenceList) {
      var t = isEntityReferenceListType ? arguments0! : this;

      resolvedValue = t.toEntityReferenceList(value,
          entityHandler: entityHandler,
          entityProvider: entityProvider,
          entityHandlerProvider: entityHandlerProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    } else if (forceToEntityReference) {
      var t = isEntityReferenceType ? arguments0! : this;

      resolvedValue = t.toEntityReference(value,
          entityHandler: entityHandler,
          entityProvider: entityProvider,
          entityHandlerProvider: entityHandlerProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    }

    return resolvedValue as V?;
  }

  EntityReference<T> toEntityReference(Object? o,
      {Type? type,
      String? typeName,
      EntityHandler<T>? entityHandler,
      EntityProvider? entityProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityFetcher<T>? entityFetcher,
      EntityCache? entityCache}) {
    if (isEntityReferenceType) {
      var entityType = arguments0;

      throw StateError(
          "This `TypeInfo` is an `EntityReference` type! `toEntityReference` should be called in the type argument#0 of this `TypeInfo`: $entityType");
    }

    EntityReference<E> castCall<E>() {
      EntityHandler<E>? oEntityHandler;
      if (entityHandler != null) {
        oEntityHandler = entityHandler is EntityHandler<E>
            ? (entityHandler as EntityHandler<E>)
            : entityHandler.getEntityHandler<E>(type: type);
      }

      return _toEntityReferenceImpl<E>(
          o,
          type,
          typeName,
          oEntityHandler,
          entityProvider,
          entityHandlerProvider,
          entityFetcher as EntityFetcher<E>?,
          entityCache);
    }

    return callCasted<EntityReference>(castCall) as EntityReference<T>;
  }

  EntityReference<E> _toEntityReferenceImpl<E>(
      Object? o,
      Type? type,
      String? typeName,
      EntityHandler<E>? entityHandler,
      EntityProvider? entityProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityFetcher<E>? entityFetcher,
      EntityCache? entityCache) {
    type ??= this.type;

    if (o == null) {
      return EntityReference<E>.asNull(
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    } else if (o is EntityReference) {
      return o as EntityReference<E>;
    } else if (o.isEntityIDType) {
      return EntityReference<E>.fromID(o,
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    } else if (o is Map<String, dynamic>) {
      return EntityReference<E>.fromJson(o,
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    } else {
      return EntityReference<E>.from(o,
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityFetcher: entityFetcher,
          entityCache: entityCache);
    }
  }

  EntityReferenceList<T> toEntityReferenceList(Object? o,
      {Type? type,
      String? typeName,
      EntityHandler<T>? entityHandler,
      EntityProvider? entityProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntitiesFetcher<T>? entitiesFetcher,
      EntityFetcher<T>? entityFetcher,
      EntityCache? entityCache}) {
    if (isEntityReferenceListType) {
      var entityType = arguments0;

      throw StateError(
          "This `TypeInfo` is an `EntityReferenceList` type! `toEntityReferenceList` should be called in the type argument#0 of this `TypeInfo`: $entityType");
    }

    if (entityFetcher != null && entitiesFetcher == null) {
      entitiesFetcher = (ids, type) => ids
          // ignore: discarded_futures
          .map((id) => id == null ? null : entityFetcher(id, type))
          .toList()
          // ignore: discarded_futures
          .resolveAll();
    }

    EntityReferenceList<E> castCall<E>() {
      EntityHandler<E>? oEntityHandler;
      if (entityHandler != null) {
        oEntityHandler = entityHandler is EntityHandler<E>
            ? (entityHandler as EntityHandler<E>)
            : entityHandler.getEntityHandler<E>(type: type);
      }

      return _toEntityReferenceListImpl<E>(
          o,
          type,
          typeName,
          oEntityHandler,
          entityProvider,
          entityHandlerProvider,
          entitiesFetcher as EntitiesFetcher<E>?,
          entityCache);
    }

    return callCasted<EntityReferenceList>(castCall) as EntityReferenceList<T>;
  }

  EntityReferenceList<E> _toEntityReferenceListImpl<E>(
      Object? o,
      Type? type,
      String? typeName,
      EntityHandler<E>? entityHandler,
      EntityProvider? entityProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntitiesFetcher<E>? entitiesFetcher,
      EntityCache? entityCache) {
    type ??= this.type;

    if (o == null) {
      return EntityReferenceList<E>.asNull(
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entitiesFetcher: entitiesFetcher,
          entityCache: entityCache);
    } else if (o is EntityReferenceList) {
      return o as EntityReferenceList<E>;
    } else if (o.isEntityIDType) {
      return EntityReferenceList<E>.fromIDs([o],
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entitiesFetcher: entitiesFetcher,
          entityCache: entityCache);
    } else if (o is List) {
      if (o is List<E> || o is List<E?>) {
        return EntityReferenceList<E>.fromEntities(o as dynamic,
            type: type,
            typeName: typeName,
            entityHandler: entityHandler,
            entityHandlerProvider: entityHandlerProvider,
            entityProvider: entityProvider,
            entitiesFetcher: entitiesFetcher,
            entityCache: entityCache);
      } else if (o is List<Map<String, dynamic>?> ||
          o.every((Object? e) => e == null || e is Map<String, Object?>)) {
        var entitiesMaps = o is List<Map<String, dynamic>?>
            ? o
            : o.cast<Map<String, dynamic>?>();
        return EntityReferenceList<E>.fromEntitiesMaps(entitiesMaps,
            type: type,
            typeName: typeName,
            entityHandler: entityHandler,
            entityHandlerProvider: entityHandlerProvider,
            entityProvider: entityProvider,
            entitiesFetcher: entitiesFetcher,
            entityCache: entityCache);
      } else if (o.every((Object? e) => e == null || e.isEntityIDType)) {
        return EntityReferenceList<E>.fromIDs(o,
            type: type,
            typeName: typeName,
            entityHandler: entityHandler,
            entityHandlerProvider: entityHandlerProvider,
            entityProvider: entityProvider,
            entitiesFetcher: entitiesFetcher,
            entityCache: entityCache);
      } else {
        throw StateError(
            "Can't resolve `EntityReferenceList` values: (${o.runtimeTypeNameUnsafe} -> ${o.map((e) => (e as Object?).runtimeTypeNameUnsafe)}) $o");
      }
    } else if (o is Map<String, dynamic>) {
      return EntityReferenceList<E>.fromJson(o,
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entitiesFetcher: entitiesFetcher,
          entityCache: entityCache);
    } else {
      return EntityReferenceList<E>.from(o,
          type: type,
          typeName: typeName,
          entityHandler: entityHandler,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entitiesFetcher: entitiesFetcher,
          entityCache: entityCache);
    }
  }
}

/// Extension for entity [Type]s.
extension APIEntityTypeExtension on Type {
  /// Returns `true` if `this` [Type] is an [int] or [String].
  bool get isEntityIDPrimitiveType {
    var self = this;
    return self == int || self == String;
  }

  /// Returns `true` if `this` [Type] is an [int], [BigInt] or [String].
  bool get isEntityIDType {
    var self = this;
    return isEntityIDPrimitiveType || self == BigInt;
  }

  /// Returns `true` if `this` [Type] is an [EntityReference] or [EntityReferenceList].
  bool get isEntityReferenceBaseType {
    var self = this;
    return self == EntityReference || self == EntityReferenceList;
  }

  /// Returns this [type] as a [TypeInfo].
  TypeInfo get typeInfo => TypeInfo.fromType(this);

  /// Parses [value] using [TypeInfo.parse].
  V? tryParse<V>(Object? value, [V? def]) => typeInfo.parse(value);
}

/// Extension for entity [Object]s.
extension APIEntityObjectExtension on Object? {
  /// Returns `true` if `this` object is an [int] or [String].
  bool get isEntityIDPrimitiveType {
    var self = this;
    return self is int || self is String;
  }

  /// Returns `true` if `this` object is an [int], [BigInt] or [String].
  bool get isEntityIDType {
    var self = this;
    return isEntityIDPrimitiveType || self is BigInt;
  }

  /// Returns `true` if `this` object is an [EntityReference].
  bool get isEntityReference {
    var self = this;
    return self is EntityReference;
  }

  /// Returns `true` if `this` object is an [EntityReferenceList].
  bool get isEntityReferenceList {
    var self = this;
    return self is EntityReferenceList;
  }

  /// Returns `true` if `this` object is an [EntityReference] OR [EntityReferenceList].
  bool get isEntityReferenceBase {
    var self = this;
    return self is EntityReference || self is EntityReferenceList;
  }

  /// Returns an entity instance.
  /// - If it's an [EntityReference] returns [EntityReference.entity].
  /// - If ![isEntityIDType] returns `this` object.
  /// - Otherwise returns `null`.
  Object? get resolveEntityInstance {
    var self = this;
    if (self is EntityReference) {
      return self.entity;
    } else if (self is EntityReferenceList) {
      return self.entities;
    } else {
      return (!isEntityIDType ? self : null);
    }
  }
}

/// Extension for [List] of [String]s.
extension ListOfStringExtension on List<String> {
  bool containsIgnoreCase(String s) {
    for (var e in this) {
      if (equalsIgnoreAsciiCase(e, s)) return true;
    }
    return false;
  }
}
