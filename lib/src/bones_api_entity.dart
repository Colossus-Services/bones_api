import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:data_serializer/data_serializer.dart' show hex;
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart'
    show
        Decimal,
        DynamicInt,
        DynamicNumber,
        IterableMapEntryExtension,
        NumericTypeExtension,
        IterableExtension;
import 'package:swiss_knife/swiss_knife.dart' show EventStream, DataURLBase64;

import 'bones_api_condition.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_error_zone.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_mixin.dart';
import 'bones_api_platform.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_collections.dart';
import 'bones_api_utils_instance_tracker.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('Entity');

final _logTransaction = logging.Logger('Transaction');

typedef JsonToEncodable = Object? Function(dynamic object);

typedef JsonReviver = Object? Function(Object? key, Object? value);

abstract class Entity {
  V? getID<V>() => getField('id');

  void setID<V>(V id) => setField('id', id);

  String get idFieldName;

  List<String> get fieldsNames;

  V? getField<V>(String key);

  TypeInfo? getFieldType(String key);

  List<EntityAnnotation>? getFieldEntityAnnotations(String key) => null;

  void setField<V>(String key, V? value);

  Map<String, dynamic> toJson();

  String toJsonEncoded() => dart_convert.json.encode(toJson());
}

class EntityHandlerProvider {
  static final EntityHandlerProvider _globalProvider = EntityHandlerProvider();

  static EntityHandlerProvider get globalProvider => _globalProvider;

  final Map<Type, EntityHandler> _entityHandlers = <Type, EntityHandler>{};

  void _register<O>(EntityHandler<O> entityHandler) {
    _entityHandlers[entityHandler.type] = entityHandler;
  }

  EntityHandler<O>? getEntityHandler<O>(
          {O? obj, Type? type, String? typeName}) =>
      _getEntityHandlerImpl<O>(obj: obj, type: type) ??
      _globalProvider._getEntityHandlerImpl<O>(obj: obj, type: type);

  EntityHandler<O>? _getEntityHandlerImpl<O>({O? obj, Type? type}) {
    var entityHandler = _entityHandlers[O];

    if (entityHandler == null && obj != null) {
      entityHandler = _entityHandlers[obj.runtimeType];
    }

    if (entityHandler == null && type != null) {
      entityHandler = _entityHandlers[type];
    }

    return entityHandler as EntityHandler<O>?;
  }

  EntityHandler<O>? getEntityHandlerByType<O>(Type type) =>
      _getEntityHandlerByTypeImpl<O>(type) ??
      _globalProvider._getEntityHandlerByTypeImpl<O>(type);

  EntityHandler<O>? _getEntityHandlerByTypeImpl<O>(Type type) {
    var entityHandler = _entityHandlers[type];
    return entityHandler as EntityHandler<O>?;
  }

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj,
      Type? type,
      String? name,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    var entityHandler = getEntityHandler<O>(obj: obj, type: type);

    if (entityHandler != null) {
      var entityRepository = entityHandler.getEntityRepository<O>(
          obj: obj,
          type: type,
          name: name,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: this);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    for (var entityHandler in _entityHandlers.values) {
      var entityRepository = entityHandler.getEntityRepository<O>(
          obj: obj,
          type: type,
          name: name,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: this);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    return null;
  }
}

/// Entity provider interface.
abstract class EntityProvider {
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type, bool sync = false});
}

typedef EntityCache = JsonEntityCache;

/// Rules to resolve entities.
/// Used by [EntityHandler] and [DBEntityRepository].
class EntityResolutionRules {
  /// If `true` it will allow the use of on DB/repository to fetch an entity by an ID reference.
  final bool allowEntityFetch;

  /// If `true` it will allow calls to [APIPlatform.readFileAsString]
  /// and [APIPlatform.readFileAsBytes].
  final bool allowReadFile;

  /// Entities [Type] with lazy load.
  final List<Type>? lazyEntityTypes;

  /// Entities [Type] with eager load.
  final List<Type>? eagerEntityTypes;

  /// If `true` all types will be eager loaded.
  final bool? allEager;

  /// If `true` all types will be lazy loaded.
  final bool? allLazy;

  const EntityResolutionRules(
      {this.allowEntityFetch = false,
      this.allowReadFile = false,
      this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager});

  const EntityResolutionRules.fetch(
      {this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager})
      : allowEntityFetch = true,
        allowReadFile = false;

  const EntityResolutionRules.fetchEager(this.eagerEntityTypes)
      : allowEntityFetch = true,
        allowReadFile = false,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = null;

  const EntityResolutionRules.fetchLazy(this.lazyEntityTypes)
      : allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        allLazy = null,
        allEager = null;

  const EntityResolutionRules.fetchEagerAll()
      : allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = true;

  const EntityResolutionRules.fetchLazyAll()
      : allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = true,
        allEager = false;

  /// Returns `true` if [entityType] load is eager.
  /// - [def] is returned in case there's not rule for [entityType].
  bool isEagerEntityType(Type entityType, [bool def = false]) {
    var allEager = this.allEager;
    if (allEager != null && allEager && !isLazyEntityType(entityType)) {
      return true;
    }

    var eagerEntityTypes = this.eagerEntityTypes;
    if (eagerEntityTypes != null && eagerEntityTypes.contains(entityType)) {
      return true;
    }

    var lazyEntityTypes = this.lazyEntityTypes;
    if (lazyEntityTypes != null && lazyEntityTypes.contains(entityType)) {
      return false;
    }

    return def;
  }

  /// Returns `true` if [entityType] load is lazy.
  /// - [def] is returned in case there's not rule for [entityType].
  bool isLazyEntityType(Type entityType, [bool def = false]) {
    var allLazy = this.allLazy;
    if (allLazy != null && allLazy && !isEagerEntityType(entityType)) {
      return true;
    }

    var lazyEntityTypes = this.lazyEntityTypes;
    if (lazyEntityTypes != null && lazyEntityTypes.contains(entityType)) {
      return true;
    }

    var eagerEntityTypes = this.eagerEntityTypes;
    if (eagerEntityTypes != null && eagerEntityTypes.contains(entityType)) {
      return false;
    }

    return def;
  }

  @override
  String toString() {
    return 'EntityResolutionRules{allowEntityFetch: $allowEntityFetch, allowReadFile: $allowReadFile, lazyEntityTypes: $lazyEntityTypes, eagerEntityTypes: $eagerEntityTypes}';
  }
}

/// Base class to implement entities handlers.
abstract class EntityHandler<O> with FieldsFromMap {
  /// The provider of [EntityHandler] instances for different [Type]s.
  final EntityHandlerProvider provider;

  /// The entity [Type] handled by this instance.
  final Type type;

  EntityHandler(EntityHandlerProvider? provider, {Type? type})
      : provider = provider ?? EntityHandlerProvider.globalProvider,
        type = type ?? O {
    if (!isValidEntityType(this.type)) {
      throw StateError('Invalid EntityHandler type: $type (O: $O)');
    }

    if (O != type) {
      throw StateError(
          'EntityHandler generic type `O` should be the same of parameter `type`: O:$O != type:$type');
    }

    Json.boot();

    _jsonReviver = _defaultJsonReviver;

    ensureRegistered();
  }

  void ensureRegistered() => provider._register(this);

  static Type? resolveEntityType<O>({O? obj, Type? type}) {
    if (type != null && isValidEntityType(type)) return type;

    if (obj != null) {
      type = obj.runtimeType;
      if (isValidEntityType(type)) return type;
    }

    type = O;
    if (isValidEntityType(type)) return type;

    return null;
  }

  static bool isValidEntityType<T>([Type? type]) {
    type ??= T;
    return type != Object &&
        type != dynamic &&
        !isBasicType(type) &&
        !_isReflectedEnumTypeImpl(type);
  }

  static bool isBasicType<T>([Type? type]) {
    type ??= T;

    if (isPrimitiveType<T>(type) || TypeParser.isCollectionType<T>(type)) {
      return true;
    }

    if (type == DateTime ||
        type == Time ||
        type == BigInt ||
        type == Decimal ||
        type == DynamicInt ||
        type == DynamicNumber ||
        type == Uint8List) return true;

    return false;
  }

  static bool isReflectedEnumType<T>([Type? type]) {
    type ??= T;

    if (isBasicType<T>(type)) return false;

    return _isReflectedEnumTypeImpl(type);
  }

  static final Map<Type, bool> _reflectedEnumTypes = <Type, bool>{};

  static bool _isReflectedEnumTypeImpl(Type type) {
    var val = _reflectedEnumTypes[type];

    if (val == null) {
      var reflectionFactory = ReflectionFactory();

      var enumReflection = reflectionFactory.getRegisterEnumReflection(type);
      if (enumReflection != null) {
        _reflectedEnumTypes[type] = true;
        return true;
      }

      var classReflection = reflectionFactory.getRegisterClassReflection(type);
      if (classReflection != null) {
        _reflectedEnumTypes[type] = false;
      }

      return false;
    } else {
      return val;
    }
  }

  static bool isPrimitiveType<T>([Type? type]) =>
      TypeParser.isPrimitiveType<T>(type);

  TypeInfo? _typeInfo;

  /// Returns [type] as a [TypeInfo].
  TypeInfo get typeInfo => _typeInfo ??= TypeInfo<O>.fromType(type);

  /// Returns `true` if [o] is an entity instance [O].
  bool isEntityInstance(Object? o) {
    if (o == null) return false;
    return o is O;
  }

  EntityHandler<T>? getEntityHandler<T>(
      {T? obj,
      Type? type,
      String? typeName,
      EntityHandler? knownEntityHandler}) {
    if (T == O && isValidEntityType<T>()) {
      return this as EntityHandler<T>;
    }

    if (obj != null) {
      if (obj is EntityReference) {
        if (obj.type == O && isValidEntityType<O>()) {
          return this as EntityHandler<T>;
        } else {
          var entityHandler = obj.entityHandler;
          if (entityHandler is EntityHandler<T>) {
            return entityHandler;
          }
        }
      } else if (obj.runtimeType == O && isValidEntityType<O>()) {
        return this as EntityHandler<T>;
      }
    }

    if (type != null && type == O && isValidEntityType<O>()) {
      return this as EntityHandler<T>;
    }

    if (typeName != null && this.type.toString() == typeName) {
      return this as EntityHandler<T>;
    }

    return knownEntityHandler?.getEntityHandler<T>(
            obj: obj, type: type, typeName: typeName) ??
        provider.getEntityHandler<T>(obj: obj, type: type);
  }

  EntityHandler<T>? getEntityHandlerByType<T>(Type type,
      {EntityHandler? knownEntityHandler}) {
    if (type == O && isValidEntityType<O>()) {
      return this as EntityHandler<T>;
    } else {
      return knownEntityHandler?.getEntityHandlerByType<T>(type) ??
          provider.getEntityHandlerByType<T>(type);
    }
  }

  V? resolveID<V>(Object? value) {
    if (value == null) return null;

    if (value is O) {
      return getID(value as O);
    } else if (value is Map) {
      return resolveIDFromMap(value);
    } else {
      var idType = this.idType();

      if (value.runtimeType == idType) {
        return value as V;
      }

      var idTypeInfo = TypeInfo.fromType(idType);
      return idTypeInfo.parse(value) as V?;
    }
  }

  V? resolveIDFromMap<V>(Map map) {
    var idField = idFieldName();

    var id = map[idField];
    if (id != null) return id;

    var idFieldSimple = StringUtils.toLowerCaseSimple(idField);

    for (var k in map.keys) {
      if (k == idFieldSimple) {
        return map[k];
      }

      var kSimple = StringUtils.toLowerCaseSimple(k);

      if (kSimple == idFieldSimple) {
        return map[k];
      }
    }

    return null;
  }

  V? getID<V>(O o) => getField<V?>(o, idFieldName(o));

  void setID<V>(O o, V id) => setField<V>(o, idFieldName(o), id);

  Map<dynamic, O> toEntitiesByIdMap(Iterable<O> entities) =>
      Map<dynamic, O>.fromEntries(entities.map((o) => MapEntry(getID(o), o)));

  Type? _idType;

  Type idType([O? o]) => _idType ??= getFieldType(o, idFieldName(o))!.type;

  String idFieldName([O? o]);

  List<String> fieldsNames([O? o]);

  Map<String, TypeInfo> fieldsTypes([O? o]);

  Map<String, TypeInfo>? _fieldsWithTypeList;

  Map<String, TypeInfo> fieldsWithTypeList([O? o]) => _fieldsWithTypeList ??=
      fieldsWithType((_, fieldType) => fieldType.isList, o);

  Map<String, TypeInfo>? _fieldsWithTypeEntity;

  Map<String, TypeInfo> fieldsWithTypeEntity([O? o]) =>
      _fieldsWithTypeEntity ??= fieldsWithType(
          (_, fieldType) =>
              !fieldType.isBasicType &&
              !fieldType.isEntityReferenceListType &&
              !fieldType.isEntityReferenceType &&
              isValidEntityType(fieldType.type),
          o);

  Map<String, TypeInfo>? _fieldsWithTypeEntityOrReference;

  Map<String, TypeInfo> fieldsWithTypeEntityOrReference([O? o]) =>
      _fieldsWithTypeEntityOrReference ??= fieldsWithType(
          (_, fieldType) =>
              (!fieldType.isBasicType &&
                  !fieldType.isEntityReferenceListType &&
                  isValidEntityType(fieldType.type)) ||
              (fieldType.isEntityReferenceType &&
                  isValidEntityType(fieldType.arguments0!.type)),
          o);

  Map<String, TypeInfo>? _fieldsWithTypeListEntity;

  Map<String, TypeInfo> fieldsWithTypeListEntity([O? o]) =>
      _fieldsWithTypeListEntity ??=
          fieldsWithType((_, fieldType) => fieldType.isValidListEntityType, o);

  Map<String, TypeInfo>? _fieldsWithTypeListEntityReference;

  Map<String, TypeInfo> fieldsWithTypeListEntityOrReference([O? o]) =>
      _fieldsWithTypeListEntityReference ??= fieldsWithType(
          (_, fieldType) => fieldType.isValidListEntityOrReferenceType, o);

  Map<String, TypeInfo> fieldsWithType(
      bool Function(String fieldName, TypeInfo fieldType) typeFilter,
      [O? o]) {
    return Map<String, TypeInfo>.unmodifiable(
        Map<String, TypeInfo>.fromEntries(fieldsTypes(o).entries.where((e) {
      return typeFilter(e.key, e.value);
    })));
  }

  void inspectObject(O? o);

  FutureOr<Map<String, Object?>> resolveFieldsValues(
      Map<String, Object?> fields,
      {O? o,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityResolutionRules? resolutionRules}) {
    entityCache ??= JsonEntityCacheSimple();

    var fieldsTypes = this.fieldsTypes(o);

    var resolved = fields.map((f, v) {
      var t = fieldsTypes[f];
      var v2 = resolveFieldValue(f, t, v,
          entityProvider: entityProvider,
          entityCache: entityCache,
          entityHandlerProvider: entityHandlerProvider,
          entityRepositoryProvider: entityRepositoryProvider,
          resolutionRules: resolutionRules);

      if (t != null) {
        if (t.isEntityReferenceType) {
          var entityType = t.arguments0 ?? TypeInfo.tObject;

          v2 = v2.resolveMapped((val) => entityType.toEntityReference(val,
              type: entityType.type,
              entityProvider: entityProvider,
              entityHandlerProvider: entityHandlerProvider));
        } else if (t.isEntityReferenceListType) {
          var entityType = t.arguments0 ?? TypeInfo.tObject;

          v2 = v2.resolveMapped((val) => entityType.toEntityReferenceList(val,
              type: entityType.type,
              entityProvider: entityProvider,
              entityHandlerProvider: entityHandlerProvider));
        }
      }

      return MapEntry(f, v2);
    });

    return resolved.resolveAllValuesNullable();
  }

  FutureOr<Object?> resolveFieldValue(
          String fieldName, TypeInfo? fieldType, Object? value,
          {EntityProvider? entityProvider,
          EntityCache? entityCache,
          EntityHandlerProvider? entityHandlerProvider,
          EntityRepositoryProvider? entityRepositoryProvider,
          EntityResolutionRules? resolutionRules}) =>
      resolveValueByType(fieldType, value,
          entityProvider: entityProvider,
          entityCache: entityCache,
          entityHandlerProvider: entityHandlerProvider,
          entityRepositoryProvider: entityRepositoryProvider,
          resolutionRules: resolutionRules);

  FutureOr<Map<String, Object?>> resolveFieldsNamesAndValues(
      Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      List<String>? returnFieldsUsedKeys,
      EntityResolutionRules? resolutionRules}) {
    var fieldsNames = this.fieldsNames();

    var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
        fieldsNamesIndexes: fieldsNamesIndexes(),
        fieldsNamesLC: fieldsNamesLC(),
        fieldsNamesSimple: fieldsNamesSimple(),
        returnMapUsedKeys: returnFieldsUsedKeys);

    return resolveFieldsValues(fieldsValues,
        entityProvider: entityProvider,
        entityCache: entityCache,
        entityHandlerProvider: entityHandlerProvider,
        entityRepositoryProvider: entityRepositoryProvider,
        resolutionRules: resolutionRules);
  }

  FutureOr<dynamic> resolveEntityFieldValue(O o, String key, dynamic value,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    entityCache ??= JsonEntityCacheSimple();
    var fieldType = getFieldType(o, key);
    return resolveValueByType(fieldType, value,
        entityProvider: entityProvider,
        entityCache: entityCache,
        resolutionRules: resolutionRules);
  }

  static final TypeInfo _typeInfoTime = TypeInfo(Time);
  static final TypeInfo _typeInfoDecimal = TypeInfo(Decimal);
  static final TypeInfo _typeInfoDynamicInt = TypeInfo(DynamicInt);
  static final TypeInfo _typeInfoUint8List = TypeInfo(Uint8List);

  FutureOr<T?> resolveValueByType<T>(TypeInfo? type, Object? value,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityResolutionRules? resolutionRules}) {
    if (type == null) {
      return value as T?;
    }

    var tType = TypeInfo.from(T);
    var valueType = value != null ? TypeInfo.from(value) : null;

    if (type.equalsTypeOrEntityType(valueType) &&
        value is T &&
        (!tType.isAnyType && type.equalsType(tType) && !type.hasArguments)) {
      return value;
    }

    if (type.equalsType(_typeInfoTime)) {
      return Time.from(value) as T?;
    } else if (type.equalsType(_typeInfoDecimal)) {
      return Decimal.from(value) as T?;
    } else if (type.equalsType(_typeInfoDynamicInt)) {
      return DynamicInt.from(value) as T?;
    } else if (type.equalsType(_typeInfoUint8List)) {
      return _resolveValueAsUInt8List(value, resolutionRules) as T?;
    }

    entityCache ??= JsonEntityCacheSimple();

    if (value is Map<String, Object?>) {
      if (type.isMap) {
        return type.parse<T>(value);
      } else {
        var valEntityHandler = _resolveEntityHandler(
            type, entityHandlerProvider, entityRepositoryProvider);

        Object? resolved;

        if (type.isEntityReferenceType) {
          resolved = type.arguments0!.toEntityReference(value,
              entityHandler: valEntityHandler,
              entityHandlerProvider: entityHandlerProvider);
        } else if (type.isEntityReferenceListType) {
          resolved = type.arguments0!.toEntityReferenceList(value,
              entityHandler: valEntityHandler,
              entityHandlerProvider: entityHandlerProvider);
        } else {
          resolved = valEntityHandler != null
              ? valEntityHandler.createFromMap(value,
                  entityProvider: entityProvider,
                  entityCache: entityCache,
                  resolutionRules: resolutionRules)
              : value;
        }

        return resolved as T?;
      }
    } else if (value is List<Object?>) {
      if (type.isList && type.hasArguments) {
        var elementType = type.arguments.first;
        var valEntityHandler = _resolveEntityHandler(
            elementType, entityHandlerProvider, entityRepositoryProvider);

        return _resolveListValueByType<T>(valEntityHandler, value, elementType,
            entityProvider, entityCache, resolutionRules);
      } else if (type.isEntityReferenceListType) {
        var elementType = type.arguments.first;

        var valEntityHandler = _resolveEntityHandler(
            elementType, entityHandlerProvider, entityRepositoryProvider);

        var eagerEntityType =
            resolutionRules?.isEagerEntityType(elementType.type) ?? false;
        if (!eagerEntityType) {
          return elementType.toEntityReferenceList(value,
              entityProvider: entityProvider,
              entityHandler: valEntityHandler) as T;
        }

        return _resolveListValueByType<T>(valEntityHandler, value, elementType,
            entityProvider, entityCache, resolutionRules);
      } else {
        return type.parseEntity<T>(value);
      }
    } else if (value != null && !type.isBasicType) {
      if (value.isEntityIDType) {
        var entity =
            entityCache.getCachedEntityByID(value, type: type.entityType);
        if (entity != null) return entity as T;
      }

      var parsed = type.parseEntity<T>(value);
      if (parsed != null) return parsed;

      if (entityProvider != null) {
        var entityAsync =
            entityProvider.getEntityByID(value, type: type.entityType);

        if (entityAsync != null) {
          return entityAsync.resolveMapped<T?>((entity) {
            if (entity != null) {
              entityCache!.cacheEntity(entity);
              return entity as T?;
            }
            return _resolveValueByEntityHandler<T>(
                value,
                type,
                entityProvider,
                entityCache!,
                entityHandlerProvider,
                entityRepositoryProvider,
                resolutionRules);
          });
        }
      }

      return _resolveValueByEntityHandler<T>(
          value,
          type,
          entityProvider,
          entityCache,
          entityHandlerProvider,
          entityRepositoryProvider,
          resolutionRules);
    } else {
      return type.parseEntity<T>(value);
    }
  }

  FutureOr<T?> _resolveListValueByType<T>(
      EntityHandler? valEntityHandler,
      List<Object?> value,
      TypeInfo elementType,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules) {
    if (!elementType.isBasicType) {
      var totalEntitiesToResolve = 0;
      var totalResolvedEntities = 0;

      value = value.map((e) {
        if (e.isEntityIDType) {
          totalEntitiesToResolve++;
          var entity =
              entityCache!.getCachedEntityByID(e, type: elementType.type);

          if (entity != null) {
            totalResolvedEntities++;
            return entity;
          } else {
            return e;
          }
        } else {
          return e;
        }
      }).toList();

      if (totalResolvedEntities == totalEntitiesToResolve &&
          value.length == totalResolvedEntities) {
        if (valEntityHandler != null) {
          return valEntityHandler.castList(value, elementType.type)! as T;
        } else {
          return value as T;
        }
      }
    }

    if (valEntityHandler != null) {
      var listFutures = TypeParser.parseList(value,
          elementParser: (e) => valEntityHandler.resolveValueByType(
              elementType, e,
              entityProvider: entityProvider,
              entityCache: entityCache,
              resolutionRules: resolutionRules));

      if (listFutures == null) return null;

      return listFutures.resolveAll().resolveMapped((l) {
        return valEntityHandler.castList(l, elementType.type)! as T;
      });
    } else {
      var listFutures = TypeParser.parseList(value,
          elementParser: (e) => resolveValueByType(elementType, e,
              entityProvider: entityProvider,
              entityCache: entityCache,
              resolutionRules: resolutionRules));

      if (listFutures == null) return null;
      return listFutures.resolveAll().resolveMapped((l) => l as T);
    }
  }

  FutureOr<Uint8List?> _resolveValueAsUInt8List(
      Object? value, EntityResolutionRules? resolutionRules) {
    if (value == null) return null;
    var bytes = TypeParser.parseUInt8List(value);
    if (bytes != null) return bytes;

    if (value is String) {
      value = value.trim();

      if (value.isEmpty) {
        return null;
      } else if (value.startsWith("data:")) {
        var dataURL = DataURLBase64.parse(value);
        return dataURL?.payloadArrayBuffer;
      } else if (value.startsWith("url(") && value.endsWith(")")) {
        var allowReadFile = resolutionRules?.allowReadFile ?? false;
        if (!allowReadFile) return null;

        var path = value.substring(4, value.length - 1);
        if ((path.startsWith('"') && path.endsWith('"')) ||
            (path.startsWith("'") && path.endsWith("'"))) {
          path = path.substring(1, path.length - 1);
        }

        var apiPlatform = APIPlatform.get();
        var filePath = apiPlatform.resolveFilePath(path);

        if (filePath != null) {
          var bytes = apiPlatform.readFileAsBytes(filePath);
          return bytes;
        }
      }

      try {
        var data = dart_convert.base64.decode(value);
        return data;
      } catch (_) {
        // not a Base64 data:

        try {
          var data = hex.decode(value);
          return data;
        } catch (_) {
          // not a HEX data:
          return null;
        }
      }
    }

    return null;
  }

  FutureOr<T?> _resolveValueByEntityHandler<T>(
      Object value,
      TypeInfo type,
      EntityProvider? entityProvider,
      EntityCache entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityResolutionRules? resolutionRules) {
    var valEntityHandler = _resolveEntityHandler(
        type, entityHandlerProvider, entityRepositoryProvider);

    if (entityRepositoryProvider == null) {
      if (this is EntityRepositoryProvider) {
        entityRepositoryProvider = this as EntityRepositoryProvider;
      } else if (entityProvider is EntityRepositoryProvider) {
        entityRepositoryProvider = entityProvider;
      }
    }

    var allowEntityFetch = (resolutionRules?.allowEntityFetch ?? false) ||
        entityCache.allowEntityFetch;

    if (allowEntityFetch && type.isEntityReferenceBaseType) {
      var entityType = type.entityType;
      var eager = entityType != null &&
          resolutionRules != null &&
          resolutionRules.isEagerEntityType(entityType);
      allowEntityFetch = eager;
    }

    if (allowEntityFetch) {
      var entityRepository = valEntityHandler?.getEntityRepositoryByTypeInfo(
          type,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: entityHandlerProvider ?? provider);

      if (entityRepository != null) {
        var transaction = entityProvider is Transaction ? entityProvider : null;
        var retEntity =
            entityRepository.selectByID(value, transaction: transaction);
        return retEntity.resolveMapped((val) {
          return val as T?;
        });
      }
    }

    try {
      Type jsonType;
      if (type.isEntityReferenceType) {
        var entityType = type.arguments0 ?? TypeInfo.tObject;

        var entityReference = entityType.toEntityReference(value,
            entityHandler: valEntityHandler,
            entityHandlerProvider: entityHandlerProvider ?? provider);

        return entityReference as T;
      } else if (type.isEntityReferenceListType) {
        var entityType = type.arguments0 ?? TypeInfo.tObject;

        var entityReferenceList = entityType.toEntityReferenceList(value,
            entityHandler: valEntityHandler,
            entityHandlerProvider: entityHandlerProvider ?? provider);

        return entityReferenceList as T;
      } else {
        jsonType = type.type;
      }

      var value2 = Json.fromJson(value,
          type: jsonType,
          entityHandlerProvider: entityHandlerProvider ?? provider,
          entityCache: entityCache,
          autoResetEntityCache: false);

      if (value2 != null) {
        return value2 as T?;
      } else {
        return value as T?;
      }
    } catch (e) {
      return value as T?;
    }
  }

  List? castList(List list, Type type) {
    if (type == this.type) {
      if (list.any((e) => e == null)) {
        throw ArgumentError(
            "Can't cast to List<$type> due to null elements in it.");
      }
      return List<O>.from(list);
    }
    return null;
  }

  List? castListNullable(List list, Type type) {
    if (type == this.type) {
      return List<O?>.from(list);
    }
    return null;
  }

  Iterable? castIterable(Iterable itr, Type type) {
    if (type == this.type) {
      return itr.cast<O>();
    }
    return null;
  }

  Iterable? castIterableNullable(Iterable itr, Type type) {
    if (type == this.type) {
      return itr.cast<O?>();
    }
    return null;
  }

  EntityHandler? _resolveEntityHandler(
      TypeInfo fieldType,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider) {
    var entityType = fieldType.entityType;
    if (entityType == null) return null;

    EntityHandler? valEntityHandler = type == entityType ? this : null;
    if (valEntityHandler != null) return valEntityHandler;

    if (valEntityHandler == null && entityRepositoryProvider != null) {
      var entityRepository =
          entityRepositoryProvider.getEntityRepositoryByType(entityType);
      valEntityHandler = entityRepository?.entityHandler;
      if (valEntityHandler != null) return valEntityHandler;
    }

    if (valEntityHandler == null && entityHandlerProvider != null) {
      valEntityHandler =
          entityHandlerProvider.getEntityHandler(type: entityType);
    }

    valEntityHandler ??= getEntityHandler(type: entityType) ??
        getEntityRepositoryByType(entityType, entityHandlerProvider: provider)
            ?.entityHandler;

    return valEntityHandler;
  }

  Map<String, int>? _fieldsNamesIndexes;

  Map<String, int> fieldsNamesIndexes([O? o]) {
    if (_fieldsNamesIndexes == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesIndexes = buildFieldsNamesIndexes(fieldsNames);
    }
    return _fieldsNamesIndexes!;
  }

  List<String>? _fieldsNamesLC;

  List<String> fieldsNamesLC([O? o]) {
    if (_fieldsNamesLC == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesLC = buildFieldsNamesLC(fieldsNames);
    }
    return _fieldsNamesLC!;
  }

  List<String>? _fieldsNamesSimple;

  List<String> fieldsNamesSimple([O? o]) {
    if (_fieldsNamesSimple == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesSimple = buildFieldsNamesSimple(fieldsNames);
    }
    return _fieldsNamesSimple!;
  }

  TypeInfo? getFieldType(O? o, String key);

  Map<String, TypeInfo> getFieldsTypes(O o) {
    return Map<String, TypeInfo>.fromEntries(fieldsNames(o)
        .map((key) => MapEntry<String, TypeInfo>(key, getFieldType(o, key)!)));
  }

  List<EntityAnnotation>? getFieldEntityAnnotations(O? o, String key);

  Map<String, List<EntityAnnotation>>? getAllFieldsEntityAnnotations(O? o) {
    var fieldsNames = this.fieldsNames(o);

    var entries = fieldsNames.map((f) {
      var annotations = getFieldEntityAnnotations(o, f);
      return annotations == null ? null : MapEntry(f, annotations);
    }).whereNotNull();

    var map = Map<String, List<EntityAnnotation>>.fromEntries(entries);

    return map.isEmpty ? null : map;
  }

  EntityFieldInvalid? validateFieldValue<V>(O o, String key,
      {V? value, bool nullValue = false}) {
    if (value == null) {
      if (nullValue) {
        value = null;
      } else {
        value = getField<V>(o, key);
      }
    }

    Object? resolvedValue = value;

    if (value is EntityReference) {
      if (value.isNull) {
        resolvedValue = null;
      } else {
        resolvedValue = value.entity;
      }
    } else if (value is EntityReferenceList) {
      if (value.isNull) {
        resolvedValue = null;
      } else {
        resolvedValue = value.entities;
      }
    }

    var annotations = getFieldEntityAnnotations(o, key);
    if (annotations != null && annotations.isNotEmpty) {
      for (var a in annotations) {
        if (a is EntityField) {
          var invalid =
              a.validateValue(resolvedValue, entityType: type, fieldName: key);
          if (invalid != null) return invalid;
        }
      }
    }

    if (resolvedValue != null) {
      var fieldType = getFieldType(o, key);

      if (fieldType != null) {
        EntityHandler<Object>? fieldEntityHandler;

        if (fieldType.isListEntityOrReference) {
          fieldEntityHandler = getEntityHandler(
              obj: resolvedValue, type: fieldType.arguments0!.type);
        } else if (!fieldType.isBasicType) {
          fieldEntityHandler =
              getEntityHandler(obj: resolvedValue, type: fieldType.entityType);
        }

        if (fieldEntityHandler != null) {
          var values = resolvedValue is List ? resolvedValue : [resolvedValue];

          for (var i = 0; i < values.length; ++i) {
            var v = values[i];
            if (!fieldEntityHandler.isEntityInstance(v)) continue;

            var invalids = fieldEntityHandler.validateAllFields(v as dynamic);

            if (invalids != null && invalids.isNotEmpty) {
              return EntityFieldInvalid(
                'entity($fieldType) field${invalids.length > 1 ? 's' : ''}(${invalids.keys.join(',')})',
                resolvedValue,
                entityType: type,
                fieldName: key,
                subEntityErrors: invalids,
              );
            }
          }
        }
      }
    }

    return null;
  }

  bool isValidFieldValue<V>(O o, String key,
          {V? value, bool nullValue = false}) =>
      validateFieldValue(o, key, value: value, nullValue: nullValue) == null;

  void checkFieldValue<V>(O o, String key, {V? value, bool nullValue = false}) {
    var invalid =
        validateFieldValue(o, key, value: value, nullValue: nullValue);
    if (invalid == null) return;

    throw invalid;
  }

  bool allFieldsValids<V>(O o) {
    var fieldsNames = this.fieldsNames(o);
    for (var f in fieldsNames) {
      if (!isValidFieldValue(o, f)) return false;
    }
    return true;
  }

  Map<String, EntityFieldInvalid>? validateAllFields<V>(O o) {
    var fieldsNames = this.fieldsNames(o);

    Map<String, EntityFieldInvalid>? errors;

    for (var f in fieldsNames) {
      var invalid = validateFieldValue(o, f);
      if (invalid != null) {
        errors ??= <String, EntityFieldInvalid>{};
        errors[f] = invalid;
      }
    }

    return errors;
  }

  void checkAllFieldsValues<V>(O o) {
    var fieldsNames = this.fieldsNames(o);

    for (var f in fieldsNames) {
      checkFieldValue(o, f);
    }
  }

  V? getField<V>(O o, String key);

  Map<String, dynamic> getFields(O o) {
    return Map<String, dynamic>.fromEntries(fieldsNames(o)
        .map((key) => MapEntry<String, dynamic>(key, getField(o, key))));
  }

  void setField<V>(O o, String key, V? value, {bool log = true});

  bool trySetField<V>(O o, String key, V? value) {
    try {
      setField<V>(o, key, value, log: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates a copy of [obj].
  ///
  /// - The default implementation uses JSON to copy the internal data.
  FutureOr<O?> copy(O obj) {
    var json = toJson(obj);

    if (json is Map<String, dynamic>) {
      return createFromMap(json);
    }

    return null;
  }

  late JsonReviver _jsonReviver;

  JsonReviver get jsonReviver => _jsonReviver;

  set jsonReviver(JsonReviver? value) {
    _jsonReviver = value ?? _defaultJsonReviver;
  }

  Object? _defaultJsonReviver(Object? key, Object? value) {
    if (key != null) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      return createFromMap(value,
          entityProvider: EntityRepositoryProvider.globalProvider);
    }

    return value;
  }

  O decodeObjectJson(String json) => decodeJson<O>(json)!;

  List<O> decodeObjectListJson(String json) {
    var itr = decodeObjectJson(json) as Iterable<O>;
    return itr is List<O> ? itr : itr.toList();
  }

  T? decodeJson<T>(String json) {
    return dart_convert.json.decode(json, reviver: jsonReviver) as T?;
  }

  JsonToEncodable? jsonToEncodable;

  String encodeObjectJson(O o) =>
      Json.encode(o, toEncodable: jsonToEncodable, removeNullFields: true);

  String encodeObjectListJson(Iterable<O> list) => Json.encode(list.toList(),
      toEncodable: jsonToEncodable, removeNullFields: true);

  String encodeJson(dynamic o) =>
      Json.encode(o, toEncodable: jsonToEncodable, removeNullFields: true);

  dynamic toJson(dynamic o) =>
      Json.toJson(o, toEncodable: jsonToEncodable, removeNullFields: true);

  bool equalsFieldValues(String field, Object? value1, Object? value2, [O? o]) {
    if (field == idFieldName(o)) {
      return isEqualsDeep(value1, value2);
    }

    return equalsValues(value1, value2);
  }

  bool equalsValues(Object? value1, Object? value2) {
    if (value1 == null) return value2 == null;
    if (value2 == null) return false;
    if (identical(value1, value2)) return true;

    var equals = equalsEntityReferenceBase(value1, value2);
    if (equals != null) return equals;

    if (value1 == value2) return true;

    equals = equalsValuesDateTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesPrimitive(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesEnum(value1, value2);
    if (equals != null) return equals;

    var collection1 = TypeParser.isCollectionValue(value1) ||
        value1.isEntityReferenceList ||
        value1 is Uint8List ||
        value1 is Int8List;
    var collection2 = TypeParser.isCollectionValue(value2) ||
        value2.isEntityReferenceList ||
        value2 is Uint8List ||
        value2 is Int8List;

    if (collection1 && collection2) {
      return isEqualsDeep(value1, value2, valueEquality: equalsValues);
    }

    value1 = value1.resolveEntityInstance ?? value1;
    value2 = value2.resolveEntityInstance ?? value2;

    var maybeEntity1 = !collection1 && !TypeParser.isPrimitiveValue(value1);
    var maybeEntity2 = !collection2 && !TypeParser.isPrimitiveValue(value2);

    var entityHandler1 = maybeEntity1 ? getEntityHandler(obj: value1) : null;
    var entityHandler2 = maybeEntity2 ? getEntityHandler(obj: value2) : null;

    if (entityHandler1 != null || entityHandler2 != null) {
      Object? id1;
      Object? id2;
      if (entityHandler1 == entityHandler2) {
        id1 = entityHandler1!.getID(value1);
        id2 = entityHandler1.getID(value2);
      } else if (entityHandler1 == null) {
        id1 = value1;
        id2 = entityHandler2!.getID(value2);
      } else if (entityHandler2 == null) {
        id1 = entityHandler1.getID(value1);
        id2 = value2;
      }

      if (id1 == null && id2 == null) {
        return isEqualsDeep(value1, value2);
      } else {
        return isEqualsDeep(id1, id2);
      }
    }

    return false;
  }

  static bool equalsValuesBasic(Object? value1, Object? value2,
      {EntityHandler? entityHandler}) {
    if (value1 == null) return value2 == null;
    if (value2 == null) return false;
    if (identical(value1, value2) || value1 == value2) return true;

    var equals = equalsValuesDateTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesTime(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesPrimitive(value1, value2);
    if (equals != null) return equals;

    equals = equalsValuesEnum(value1, value2);
    if (equals != null) return equals;

    equals =
        equalsValuesCollection(value1, value2, entityHandler: entityHandler);
    if (equals != null) return equals;

    equals = equalsValuesEntity(value1, value2, entityHandler: entityHandler);
    if (equals != null) return equals;

    return false;
  }

  static bool? equalsValuesEntity(Object value1, Object value2,
      {EntityHandler? entityHandler}) {
    if (value1 is EntityReference) {
      return value1.equalsEntityID(value2);
    } else if (value2 is EntityReference) {
      return value2.equalsEntityID(value1);
    }

    var reflectionFactory = ReflectionFactory();

    EntityHandler? entityHandler1 = value1.isPrimitiveValue
        ? null
        : reflectionFactory
                .getRegisterClassReflection(value1.runtimeType)
                ?.entityHandler ??
            EntityHandlerProvider.globalProvider.getEntityHandler(obj: value1);

    EntityHandler? entityHandler2 = value2.isPrimitiveValue
        ? null
        : reflectionFactory
                .getRegisterClassReflection(value2.runtimeType)
                ?.entityHandler ??
            EntityHandlerProvider.globalProvider.getEntityHandler(obj: value2);

    if (entityHandler1 != null) {
      var id1 = entityHandler1.getID(value1);

      if (entityHandler2 != null) {
        if (entityHandler1 != entityHandler2) return false;
        var id2 = entityHandler2.getID(value2);
        return id1 == id2;
      } else {
        var id2 = entityHandler1.resolveID(value2);
        return id1 == id2;
      }
    } else if (entityHandler2 != null) {
      var id1 = entityHandler2.resolveID(value1);
      var id2 = entityHandler2.getID(value2);
      return id1 == id2;
    } else if (entityHandler != null) {
      var id1 = entityHandler.resolveID(value1);
      var id2 = entityHandler.resolveID(value2);
      return id1 == id2;
    }

    return false;
  }

  static bool? equalsEntityReferenceBase(Object value1, Object value2) {
    if (value1 is EntityReference && value2 is EntityReference) {
      return value1 == value2;
    }

    if (value1 is EntityReferenceList && value2 is EntityReferenceList) {
      return value1 == value2;
    }

    return null;
  }

  static bool? equalsValuesDateTime(Object value1, Object value2) {
    if (value1 is DateTime || value2 is DateTime) {
      var t1 = TypeParser.parseInt(value1);
      var t2 = TypeParser.parseInt(value2);
      return t1 == t2;
    }

    return null;
  }

  static bool? equalsValuesTime(Object value1, Object value2) {
    if (value1 is Time || value2 is Time) {
      var t1 = value1 is Time
          ? value1.totalMilliseconds
          : TypeParser.parseInt(value1);
      var t2 = value2 is Time
          ? value2.totalMilliseconds
          : TypeParser.parseInt(value2);
      return t1 == t2;
    }

    return null;
  }

  static bool? equalsValuesPrimitive(Object value1, Object value2) {
    var primitive1 = TypeParser.isPrimitiveValue(value1);
    var primitive2 = TypeParser.isPrimitiveValue(value2);

    if (primitive1 && primitive2) {
      return value1 == value2;
    }

    return null;
  }

  static bool? equalsValuesEnum(Object value1, Object value2) {
    var enum1 = value1 is Enum;
    var enum2 = value2 is Enum;

    if (enum1 && enum2) {
      return value1 == value2;
    } else if (enum1 || enum2) {
      var enumName1 = value1 is Enum ? enumToName(value1) : value1.toString();
      var enumName2 = value2 is Enum ? enumToName(value2) : value2.toString();

      return equalsIgnoreAsciiCase(enumName1, enumName2);
    }

    return null;
  }

  static bool? equalsValuesCollection(Object value1, Object value2,
      {EntityHandler? entityHandler}) {
    var collection1 = TypeParser.isCollectionValue(value1);
    var collection2 = TypeParser.isCollectionValue(value2);

    if (collection1 && collection2) {
      return isEqualsDeep(value1, value2,
          valueEquality: (a, b) =>
              equalsValuesBasic(a, b, entityHandler: entityHandler));
    }

    return null;
  }

  FutureOr<O?> createDefault();

  FutureOr<O> createFromMap(Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityResolutionRules? resolutionRules}) {
    entityCache ??= JsonEntityCacheSimple();

    var returnFieldsUsedKeys = <String>[];

    return resolveFieldsNamesAndValues(fields,
            entityProvider: entityProvider,
            entityCache: entityCache,
            entityHandlerProvider: entityHandlerProvider,
            entityRepositoryProvider: entityRepositoryProvider,
            returnFieldsUsedKeys: returnFieldsUsedKeys,
            resolutionRules: resolutionRules)
        .resolveMapped((resolvedFields) {
      try {
        var fieldsUnusedKeys = fields.keys
            .whereNot((f) => returnFieldsUsedKeys.contains(f))
            .toList();

        // Add unresolved fields, to allow non field parameters,
        // constructors with parameters different from class field name.
        resolvedFields.addEntries(fieldsUnusedKeys
            .map((f) => MapEntry<String, Object?>(f, fields[f])));

        return instantiateFromMapImpl(resolvedFields).resolveMapped((o) {
          if (o != null) {
            entityCache!.cacheEntity(o, getID);
            return o;
          } else {
            return _createFromMapDefaultImpl(
                resolvedFields, entityProvider, entityCache, resolutionRules);
          }
        });
      } catch (e, s) {
        _log.warning(
            "Error creating from `Map` using `instantiatorFromMap`. Trying instantiation with default constructor...",
            e,
            s);
        return _createFromMapDefaultImpl(
            fields, entityProvider, entityCache, resolutionRules);
      }
    });
  }

  FutureOr<O> _createFromMapDefaultImpl(
      Map<String, dynamic> fields,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules) {
    return createDefault().resolveMapped((o) {
      if (o == null) {
        throw StateError(
            "Can't instantiate entity `$type` by default constructor!");
      }

      return setFieldsFromMap(o, fields,
              entityProvider: entityProvider,
              entityCache: entityCache,
              resolutionRules: resolutionRules)
          .resolveMapped((o) {
        entityCache!.cacheEntity(o, getID);
        return o;
      });
    });
  }

  FutureOr<O?> instantiateFromMapImpl(Map<String, dynamic> fields);

  FutureOr<O> setFieldsFromMap(O o, Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    entityCache ??= JsonEntityCacheSimple();

    var fieldsNames = this.fieldsNames(o);

    var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
        fieldsNamesIndexes: fieldsNamesIndexes(o),
        fieldsNamesLC: fieldsNamesLC(o),
        fieldsNamesSimple: fieldsNamesSimple(o));

    var setFutures = fieldsValues.entries.map((e) {
      return setFieldValueDynamic(o, e.key, e.value,
              entityProvider: entityProvider,
              entityCache: entityCache,
              resolutionRules: resolutionRules)
          .resolveWithValue(true);
    });

    return setFutures.resolveAllWithValue(o);
  }

  FutureOr<dynamic> setFieldValueDynamic(O o, String key, dynamic value,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    var retValue2 = resolveEntityFieldValue(o, key, value,
        entityProvider: entityProvider,
        entityCache: entityCache,
        resolutionRules: resolutionRules);
    return retValue2.resolveMapped((value2) {
      setField<dynamic>(o, key, value2);
      return value2;
    });
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    if (!identical(provider, EntityHandlerProvider.globalProvider)) {
      _knownEntityRepositoryProviders.add(provider);
    }
  }

  EntityRepository<T>? getEntityRepository<T extends Object>(
          {T? obj,
          Type? type,
          String? name,
          EntityHandlerProvider? entityHandlerProvider,
          EntityRepositoryProvider? entityRepositoryProvider}) =>
      _knownEntityRepositoryProviders.getEntityRepository<T>(
          obj: obj,
          type: type,
          name: name,
          entityHandlerProvider: entityHandlerProvider ?? provider,
          entityRepositoryProvider: entityRepositoryProvider);

  EntityRepository<T>? getEntityRepositoryByType<T extends Object>(Type type,
          {EntityHandlerProvider? entityHandlerProvider,
          EntityRepositoryProvider? entityRepositoryProvider}) =>
      _knownEntityRepositoryProviders.getEntityRepositoryByType<T>(type,
          entityHandlerProvider: entityHandlerProvider ?? provider,
          entityRepositoryProvider: entityRepositoryProvider);

  EntityRepository<T>? getEntityRepositoryByTypeInfo<T extends Object>(
      TypeInfo typeInfo,
      {EntityHandlerProvider? entityHandlerProvider,
      EntityRepositoryProvider? entityRepositoryProvider}) {
    var entityType = typeInfo.entityType;
    if (entityType == null) return null;

    return getEntityRepositoryByType<T>(entityType,
        entityHandlerProvider: entityHandlerProvider,
        entityRepositoryProvider: entityRepositoryProvider);
  }
}

typedef InstantiatorDefault<O> = FutureOr<O> Function();

typedef InstantiatorFromMap<O> = FutureOr<O> Function(Map<String, dynamic>);

class GenericEntityHandler<O extends Entity> extends EntityHandler<O> {
  final InstantiatorDefault<O>? instantiatorDefault;

  final InstantiatorFromMap<O>? instantiatorFromMap;

  GenericEntityHandler(
      {this.instantiatorDefault,
      this.instantiatorFromMap,
      Type? type,
      O? sampleEntity,
      EntityHandlerProvider? provider})
      : super(provider, type: type ?? O) {
    if (instantiatorDefault == null && instantiatorFromMap == null) {
      throw ArgumentError(
          "Null instantiators: `instantiatorDefault`, `instantiatorFromMap`");
    }

    if (sampleEntity != null) {
      inspectObject(sampleEntity);
    }
  }

  String? _idFieldsName;

  @override
  String idFieldName([O? o]) {
    var idFieldsName = _idFieldsName;

    if (idFieldsName == null) {
      inspectObject(o);
      idFieldsName = _idFieldsName;

      if (idFieldsName == null) {
        throw StateError("`idFieldsName` Not populated yet for type `$type`! "
            "No Entity instance presented to this EntityHandler yet.");
      }
    }

    return idFieldsName;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) {
    var fieldsNames = _fieldsNames;

    if (fieldsNames == null) {
      inspectObject(o);
      fieldsNames = _fieldsNames;
    }

    if (fieldsNames == null) {
      throw StateError(
          "`fieldsNames` Not populated yet! No Entity instance presented to this EntityHandler yet. Type: $type");
    }

    return fieldsNames;
  }

  Map<String, TypeInfo>? _fieldsTypes;

  @override
  Map<String, TypeInfo> fieldsTypes([O? o]) {
    var fieldsTypes = _fieldsTypes;

    if (fieldsTypes == null) {
      inspectObject(o);
      fieldsTypes = _fieldsTypes;
    }

    if (fieldsTypes == null) {
      throw StateError(
          "`fieldsTypes` Not populated yet! No Entity instance presented to this EntityHandler yet. Type: $type");
    }

    return fieldsTypes;
  }

  Map<String, List<EntityAnnotation>?>? _fieldsEntityAnnotations;

  @override
  void inspectObject(O? o) {
    if (o == null) {
      var obj = createDefault();
      if (obj is O) {
        o = obj;
      }
    }

    if (o != null && _idFieldsName == null) {
      _idFieldsName = o.idFieldName;

      _fieldsNames ??= List<String>.unmodifiable(o.fieldsNames);

      _fieldsTypes ??= Map<String, TypeInfo>.unmodifiable(
          Map<String, TypeInfo>.fromEntries(
              _fieldsNames!.map((f) => MapEntry(f, o!.getFieldType(f)!))));

      _fieldsEntityAnnotations ??=
          Map<String, List<EntityAnnotation>?>.unmodifiable(
              Map<String, List<EntityAnnotation>?>.fromEntries(
                  _fieldsNames!.map((f) {
        var list = o!.getFieldEntityAnnotations(f);
        return MapEntry(f, list == null ? null : UnmodifiableListView(list));
      })));
    }
  }

  @override
  String encodeObjectJson(O o) {
    inspectObject(o);
    return super.encodeObjectJson(o);
  }

  @override
  String encodeJson(o) {
    inspectObject(o);
    return super.encodeJson(o);
  }

  @override
  String encodeObjectListJson(Iterable<O> list) {
    if (list.isNotEmpty) {
      inspectObject(list.first);
    }
    return super.encodeObjectListJson(list);
  }

  @override
  V? getID<V>(O o) {
    inspectObject(o);
    return o.getID();
  }

  @override
  void setID<V>(O o, V id) {
    inspectObject(o);
    o.setID(id);
  }

  @override
  V? getField<V>(O o, String key) {
    inspectObject(o);
    return o.getField<V>(key);
  }

  @override
  TypeInfo? getFieldType(O? o, String key) {
    inspectObject(o);
    if (o != null) {
      return o.getFieldType(key);
    } else {
      return _fieldsTypes?[key];
    }
  }

  @override
  void setField<V>(O o, String key, V? value, {bool log = true}) {
    inspectObject(o);
    try {
      return o.setField<V>(key, value);
    } catch (e, s) {
      var message = "Error setting `$type` field: $key = $value";
      if (log) {
        _log.severe(message, e, s);
      }
      throw StateError(message);
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(O? o, String key) {
    inspectObject(o);
    if (o != null) {
      return o.getFieldEntityAnnotations(key);
    } else {
      return _fieldsEntityAnnotations?[key];
    }
  }

  @override
  FutureOr<O?> createDefault() {
    var instantiatorDefault = this.instantiatorDefault;
    if (instantiatorDefault == null) return null;
    return instantiatorDefault();
  }

  @override
  FutureOr<O?> instantiateFromMapImpl(Map<String, dynamic> fields) {
    var instantiatorFromMap = this.instantiatorFromMap;
    if (instantiatorFromMap == null) return null;
    return instantiatorFromMap(fields);
  }

  @override
  String toString() {
    return 'GenericEntityHandler{$type}';
  }
}

class ClassReflectionEntityHandler<O> extends EntityHandler<O> {
  Type classType;

  ClassReflection<O>? _reflection;

  ClassReflectionEntityHandler(this.classType,
      {EntityHandlerProvider? provider, ClassReflection<O>? reflection})
      : _reflection = reflection,
        super(provider, type: classType);

  ClassReflection<O> get reflection => _reflection ??=
      ReflectionFactory().getRegisterClassReflection<O>(classType)!;

  ClassReflection<O> reflectionWithObject([O? o]) =>
      o == null ? reflection : reflection.withObject(o);

  List<ClassReflectionEntityHandler>? _siblingsEntityHandlers;

  List<ClassReflectionEntityHandler> siblingsEntityHandlers() =>
      _siblingsEntityHandlers ??=
          List<ClassReflectionEntityHandler>.unmodifiable(
              reflection.siblingsClassReflection().map((c) => c.entityHandler));

  @override
  EntityHandler<T>? getEntityHandler<T>(
      {T? obj,
      Type? type,
      String? typeName,
      EntityHandler? knownEntityHandler}) {
    var entityHandler = super.getEntityHandler<T>(
        obj: obj,
        type: type,
        typeName: typeName,
        knownEntityHandler: knownEntityHandler);
    if (entityHandler != null) {
      return entityHandler;
    }

    var objType = obj?.runtimeType;

    if (obj is EntityReference) {
      objType = obj.type;
      obj = obj.entity;
    }

    var classReflectionForType =
        reflection.siblingClassReflectionFor<T>(obj: obj, type: type);

    if (classReflectionForType != null) {
      return classReflectionForType.entityHandler;
    }

    entityHandler =
        ReflectionFactory().getRegisterEntityHandler<T>(type ?? objType);
    return entityHandler;
  }

  @override
  void inspectObject(O? o) {}

  @override
  V? getField<V>(O o, String key) => reflection.getField<V?>(key, o);

  @override
  TypeInfo? getFieldType(O? o, String key) {
    var field = reflection.field(key, o);
    return field != null ? TypeInfo.from(field) : null;
  }

  List<Object>? getFieldAnnotations(O? o, String key) {
    var field = reflection.field(key, o);
    if (field == null) return null;

    return field.annotations;
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(O? o, String key) =>
      getFieldAnnotations(o, key)?.whereType<EntityAnnotation>().toList();

  @override
  void setField<V>(O o, String key, V? value, {bool log = true}) {
    try {
      var field = reflection.field<V>(key, o);
      if (field == null) return;

      var fieldType = field.type;

      var resolvedValue =
          fieldType.typeInfo.resolveValue<V>(value, entityHandler: this);

      field.set(resolvedValue);
    } catch (e, s) {
      var message =
          "Error setting `$type` field using reflection[$reflection]: $key = $value";
      if (log) {
        _log.severe(message, e, s);
      }
      throw StateError(message);
    }
  }

  @override
  bool trySetField<V>(O o, String key, V? value) {
    var field = reflection.field<V>(key, o);
    if (field == null) return false;

    var fieldType = field.type;

    var resolvedValue =
        fieldType.typeInfo.resolveValue<V>(value, entityHandler: this);

    if (resolvedValue == null) {
      if (field.nullable) {
        field.set(null);
        return true;
      } else {
        return false;
      }
    }

    if (fieldType.type == resolvedValue.runtimeType) {
      field.set(resolvedValue);
      return true;
    } else {
      return false;
    }
  }

  @override
  FutureOr<O?> copy(O obj) {
    var reflection = this.reflection;
    var json = reflection.toJson(obj);
    return reflection.fromJson(json);
  }

  String? _idFieldsName;

  @override
  String idFieldName([O? o]) {
    if (_idFieldsName == null) {
      // Just to populate:
      if (_fieldsNames == null) {
        fieldsNames(o);
      }

      var fieldName = findIdFieldName(o);
      _idFieldsName = fieldName ?? 'id';
    }
    return _idFieldsName!;
  }

  String? findIdFieldName([O? o]) {
    var reflection = reflectionWithObject(o);

    var possibleFields = reflection.fieldsWhere((f) {
      return f.type.isPrimitiveType;
    }).toList(growable: false);

    if (possibleFields.isEmpty) {
      throw StateError(
          "Class without candidate for ID field: ${fieldsNames()}");
    }

    if (possibleFields.length == 1) {
      return possibleFields.first.name;
    }

    possibleFields.sort((a, b) {
      var n1 = a.nullable;
      var n2 = b.nullable;
      return n1 == n2 ? 0 : (n1 ? -1 : 1);
    });

    var idField = possibleFields.firstWhereOrNull((f) {
      var name = f.name.toLowerCase();
      return name == 'id' || name == 'key' || name == 'primary';
    });

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.type.isNumericType);
    idField ??=
        possibleFields.firstWhereOrNull((f) => f.type.type.isDynamicNumberType);

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.nullable);

    if (idField != null) {
      return idField.name;
    }

    return null;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) =>
      _fieldsNames ??= fieldsTypes(o).keys.toList();

  Map<String, TypeInfo>? _fieldsTypes;

  @override
  Map<String, TypeInfo> fieldsTypes([O? o]) {
    if (_fieldsTypes == null) {
      var reflection = reflectionWithObject(o);

      var types = reflection.fieldsNames.map((f) {
        var field = reflection.field(f, o);
        if (field == null || !field.hasSetter) return null;
        var type = TypeInfo.from(field);
        return MapEntry(f, type);
      });

      _fieldsTypes = Map<String, TypeInfo>.unmodifiable(
          Map<String, TypeInfo>.fromEntries(types.whereNotNull()));
    }
    return _fieldsTypes!;
  }

  @override
  FutureOr<O?> createDefault() => reflection.createInstance();

  @override
  FutureOr<O?> instantiateFromMapImpl(Map<String, dynamic> fields) =>
      reflection.createInstanceFromMap(fields,
          fieldNameResolver: (f, m) => m.containsKey(f) ? f : null);

  @override
  T? decodeJson<T>(String json) {
    try {
      return Json.decode<T>(json, type: type);
    } catch (_) {
      return dart_convert.json.decode(json, reviver: jsonReviver) as T?;
    }
  }

  @override
  String toString() {
    return 'ClassReflectionEntityHandler{$classType}';
  }
}

mixin EntityFieldAccessor<O> {
  dynamic getID(O o, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getID();
    } else if (entityHandler != null) {
      return entityHandler.getID(o);
    } else if (o is Map) {
      return o['id'];
    } else {
      throw StateError('getID: No EntityHandler provided for: $o');
    }
  }

  void setID(O o, Object id, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.setID(id);
    } else if (entityHandler != null) {
      return entityHandler.setID(o, id);
    } else if (o is Map) {
      o['id'] = id;
    } else {
      throw StateError('setID: No EntityHandler provided for: $o');
    }
  }

  dynamic getField(O o, String key, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getField(key);
    } else if (entityHandler != null) {
      return entityHandler.getField(o, key);
    } else if (o is Map) {
      return o[key];
    } else {
      throw StateError('getField($key): No EntityHandler provided for: $o');
    }
  }

  void setField(O o, String key, Object? value,
      {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      o.setField(key, value);
    } else if (entityHandler != null) {
      entityHandler.setField(o, key, value);
    } else if (o is Map) {
      o[key] = value;
    } else {
      throw StateError('setField($key): No EntityHandler provided for: $o');
    }
  }
}

class EntityFieldAccessorGeneric<O> with EntityFieldAccessor<O> {}

abstract class EntityAccessor<O extends Object> {
  static String simplifiedName(String name) {
    name = name.trim().toLowerCase().replaceAll(RegExp(r'[\W_]+'), '').trim();
    return name;
  }

  final String name;

  EntityAccessor(this.name);

  String? _nameSimplified;

  String get nameSimplified => _nameSimplified ??= simplifiedName(name);

  Object? getEntityID(O o);
}

abstract class EntitySource<O extends Object> extends EntityAccessor<O> {
  EntitySource(String name) : super(name);

  FutureOr<bool> existsID(dynamic id, {Transaction? transaction});

  FutureOr<O?> selectByID(dynamic id, {Transaction? transaction}) {
    return select(ConditionID(id)).resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    });
  }

  FutureOr<List<O?>> selectByIDs(List<dynamic> ids,
      {Transaction? transaction}) {
    var ret = ids.map((id) => selectByID(id, transaction: transaction));
    return ret.resolveAll();
  }

  FutureOr<int> length({Transaction? transaction}) =>
      count(transaction: transaction);

  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction});

  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  FutureOr<O?> selectFirstByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          Transaction? transaction}) =>
      selectByQuery(query,
              parameters: parameters,
              namedParameters: namedParameters,
              transaction: transaction,
              limit: 1)
          .resolveMapped((result) => result.firstOrNull);

  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        limit: limit);
  }

  FutureOr<Iterable<O>> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules});

  FutureOr<Iterable<O>> selectAll(
      {Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules});

  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction});

  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
      List<O>? os, String field,
      {List<dynamic>? oIds, TypeInfo? fieldType, Transaction? transaction});
}

abstract class EntityStorage<O extends Object> extends EntityAccessor<O> {
  EntityStorage(String name) : super(name);

  bool isStored(O o, {Transaction? transaction});

  void checkEntityFields(O o);

  FutureOr<dynamic> store(O o, {Transaction? transaction});

  FutureOr<Iterable> storeAll(Iterable<O> o, {Transaction? transaction});

  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction});

  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  FutureOr<O?> deleteEntity(O o, {Transaction? transaction}) =>
      deleteByID(getEntityID(o), transaction: transaction);

  FutureOr<O?> tryDeleteEntity(O o, {Transaction? transaction}) =>
      tryCall<O>(() => deleteEntity(o, transaction: transaction));

  FutureOr<O?> deleteByID(dynamic id, {Transaction? transaction}) {
    if (id == null) return null;
    return delete(ConditionID(id), transaction: transaction)
        .resolveMapped((del) => del.firstOrNull);
  }

  FutureOr<O?> tryDeleteByID(dynamic id, {Transaction? transaction}) =>
      tryCall<O>(() => deleteByID(id, transaction: transaction));

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction});

  FutureOr<Iterable> deleteEntityCascade(O o, {Transaction? transaction}) =>
      deleteCascadeGeneric(o,
          transaction: transaction,
          entityHandler: EntityHandlerProvider.globalProvider
              .getEntityHandler(obj: o, type: O),
          entityRepository: EntityRepositoryProvider.globalProvider
              .getEntityRepository(obj: o, type: O),
          repositoryProvider: EntityRepositoryProvider.globalProvider);

  static EntityRepository<O>? _resolveRepositoryProvider<O extends Object>(
          EntityHandler? entityHandler,
          EntityRepository<O>? entityRepository,
          EntityRepositoryProvider? repositoryProvider,
          {O? obj,
          Type? type}) =>
      entityRepository?.provider.getEntityRepository<O>(obj: obj, type: type) ??
      repositoryProvider?.getEntityRepository<O>(obj: obj, type: type) ??
      entityHandler?.getEntityRepository<O>(obj: obj, type: type);

  static Future<Iterable> deleteCascadeGeneric<O extends Object>(O o,
      {Transaction? transaction,
      EntityHandler<O>? entityHandler,
      EntityRepository<O>? entityRepository,
      EntityRepositoryProvider? repositoryProvider}) async {
    entityRepository ??= _resolveRepositoryProvider<O>(
        entityHandler, entityRepository, repositoryProvider,
        obj: o);
    entityHandler ??= _resolveEntityHandler<O>(
        entityHandler, entityRepository, repositoryProvider,
        obj: o);

    if (entityHandler == null) {
      throw ArgumentError(
          "EntityHandler not provided for type: ${o.runtimeType}");
    }

    var deleted = <Object>[];

    return Transaction.executeBlock(
        (transaction) => _deleteCascadeGenericImpl(o, transaction,
                entityHandler, entityRepository, repositoryProvider, deleted)
            .resolveWithValue(deleted),
        transaction: transaction);
  }

  static EntityHandler<O>? _resolveEntityHandler<O extends Object>(
      EntityHandler? entityHandler,
      EntityRepository<O>? entityRepository,
      EntityRepositoryProvider? repositoryProvider,
      {O? obj,
      Type? type}) {
    var t = EntityHandler.resolveEntityType<O>(obj: obj, type: type);

    var eh = (t != null && entityRepository?.entityHandler.type == t
            ? entityRepository?.entityHandler
            : null) ??
        entityHandler?.getEntityHandler<O>(obj: obj, type: type);
    if (eh != null && eh.type == obj.genericType) return eh;

    var er = _resolveRepositoryProvider<O>(
        entityHandler, entityRepository, repositoryProvider,
        obj: obj, type: type);
    return er?.entityHandler;
  }

  static Future<bool> _deleteCascadeGenericImpl<O extends Object>(
      O o,
      Transaction transaction,
      EntityHandler<O>? entityHandler,
      EntityRepository<O>? entityRepository,
      EntityRepositoryProvider? repositoryProvider,
      List<Object> deleted) async {
    if (entityHandler == null) {
      throw ArgumentError(
          "EntityHandler not provided for type: ${o.runtimeType}");
    }

    if (entityRepository == null) {
      throw ArgumentError(
          "EntityRepository not provided for type: ${o.runtimeType}");
    }

    var id = entityRepository.getEntityID(o);
    if (id == null) return false;

    var fieldsTypes = entityHandler
        .getFieldsTypes(o)
        .entries
        .where((e) => !e.value.isPrimitiveType);

    var preDeleteCalls = <Future<bool> Function()>[];
    var posDeleteCalls = <Future<bool> Function()>[];
    var changed = false;

    for (var e in fieldsTypes) {
      var t = e.value;

      if (t.isEntityReferenceType) {
        var fieldValue = entityHandler.getField(o, e.key);
        if (fieldValue == null) continue;

        if (fieldValue is EntityReference) {
          if (fieldValue.isNull) continue;

          if (fieldValue.isEntitySet) {
            var fieldType = fieldValue.type;
            var del = _deleteSubEntityImpl(
                entityHandler,
                entityRepository,
                repositoryProvider,
                o,
                e.key,
                fieldType,
                fieldValue,
                transaction,
                deleted,
                preDeleteCalls,
                posDeleteCalls);

            changed |= del;
            continue;
          }
        }
      } else if (t.isEntityReferenceListType) {
        var fieldValue = entityHandler.getField(o, e.key);
        if (fieldValue == null) continue;

        if (fieldValue is EntityReferenceList) {
          if (fieldValue.isNull) continue;

          if (fieldValue.isEntitiesSet) {
            var fieldType = fieldValue.type;
            var del = _deleteSubEntityImpl(
                entityHandler,
                entityRepository,
                repositoryProvider,
                o,
                e.key,
                fieldType,
                fieldValue,
                transaction,
                deleted,
                preDeleteCalls,
                posDeleteCalls);

            changed |= del;
            continue;
          }
        }
      } else if (t.isIterable) {
        var tTypeInfo = t.arguments.firstOrNull;
        if (tTypeInfo == null || tTypeInfo.isPrimitiveType) continue;

        var tType = tTypeInfo.type;
        if (!EntityHandler.isValidEntityType(tType)) continue;

        var fieldValues = entityHandler.getField(o, e.key);
        if (fieldValues == null ||
            fieldValues is! Iterable ||
            fieldValues.whereNotNull().isEmpty) continue;

        EntityRepository<Object>? tEntityRepository;
        EntityHandler<Object>? tEntityHandler;

        for (var e in fieldValues.whereNotNull()) {
          tEntityRepository ??= _resolveRepositoryProvider(
              entityHandler, entityRepository, repositoryProvider,
              obj: e, type: tType);

          tEntityHandler ??= _resolveEntityHandler(
              entityHandler, tEntityRepository, repositoryProvider,
              obj: e, type: tType);

          preDeleteCalls.add(() => _deleteCascadeGenericImpl<Object>(
              e,
              transaction,
              tEntityHandler,
              tEntityRepository,
              repositoryProvider,
              deleted));
        }

        var fieldValuesEmpty = fieldValues.toList()..clear();
        entityHandler.setField<dynamic>(o, e.key, fieldValuesEmpty);
        changed = true;
      } else if (t.isCollection || EntityHandler.isReflectedEnumType(t.type)) {
        continue;
      } else {
        var tType = t.type;
        if (!EntityHandler.isValidEntityType(tType)) continue;

        var fieldValue = entityHandler.getField(o, e.key);
        if (fieldValue == null) continue;

        var del = _deleteSubEntityImpl(
            entityHandler,
            entityRepository,
            repositoryProvider,
            o,
            e.key,
            tType,
            fieldValue,
            transaction,
            deleted,
            preDeleteCalls,
            posDeleteCalls);

        changed |= del;
      }
    }

    if (changed) {
      await entityRepository.store(o, transaction: transaction);
    }

    for (var d in preDeleteCalls) {
      await d();
    }

    var del = await entityRepository.deleteByID(id, transaction: transaction);

    for (var d in posDeleteCalls) {
      await d();
    }

    var delOk = del != null;

    if (delOk) {
      deleted.add(o);
    }

    return delOk;
  }

  static bool _deleteSubEntityImpl<O extends Object>(
      EntityHandler<O> entityHandler,
      EntityRepository<O> entityRepository,
      EntityRepositoryProvider? repositoryProvider,
      O parentEntity,
      String parentEntityFieldName,
      Type entityType,
      Object entity,
      Transaction transaction,
      List<Object> deleted,
      List<Function> preDeleteCalls,
      List<Function> posDeleteCalls) {
    var tEntityRepository = _resolveRepositoryProvider(
        entityHandler, entityRepository, repositoryProvider,
        obj: entity, type: entityType);

    if (tEntityRepository == null) {
      throw StateError(
          "Can't resolve `EntityRepository` for type `$entityType`.");
    }

    var tEntityHandler = _resolveEntityHandler(
        entityHandler, tEntityRepository, repositoryProvider,
        obj: entity, type: entityType);

    if (tEntityHandler == null) {
      throw StateError("Can't resolve `EntityHandler` for type `$entityType`.");
    }

    // ignore: prefer_function_declarations_over_variables
    var call = () => _deleteCascadeGenericImpl<Object>(entity, transaction,
        tEntityHandler, tEntityRepository, repositoryProvider, deleted);

    var changed = false;

    if (entityHandler.trySetField<dynamic>(
        parentEntity, parentEntityFieldName, null)) {
      preDeleteCalls.add(call);
      changed = true;
    } else {
      posDeleteCalls.add(call);
    }

    return changed;
  }
}

class EntityRepositoryProvider
    with Closable, Initializable
    implements EntityProvider {
  static final EntityRepositoryProvider _globalProvider =
      EntityRepositoryProvider._global()..doInitialization();

  static EntityRepositoryProvider get globalProvider => _globalProvider;

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  static int _instanceIDCount = 0;

  final int instanceID = ++_instanceIDCount;

  EntityRepositoryProvider() {
    _globalProvider.notifyKnownEntityRepositoryProvider(this);
  }

  EntityRepositoryProvider._global();

  @override
  FutureOr<InitializationResult> initialize() => InitializationResult.ok(this);

  @override
  bool close() => super.close() as bool;

  void registerEntityRepository<O extends Object>(
      EntityRepository<O> entityRepository) {
    checkNotClosed();

    _entityRepositories[entityRepository.type] = entityRepository;
  }

  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  Map<EntityRepository, Object> get registeredEntityRepositoriesInformation =>
      _entityRepositories.values
          .map((e) => MapEntry(e, e.information(extended: true)))
          .toMapFromEntries();

  bool _callingGetEntityRepository = false;

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name}) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    checkInitialized();

    try {
      var entityRepository =
          _getEntityRepositoryImpl<O>(obj: obj, type: type, name: name);
      if (entityRepository != null) {
        return entityRepository;
      }

      if (!identical(this, _globalProvider)) {
        return _globalProvider._getEntityRepositoryImpl<O>(
            obj: obj, type: type, name: name);
      }

      return null;
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O extends Object>(
      {O? obj, Type? type, String? name}) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[O];
      if (entityRepository != null && !entityRepository.isClosed) {
        return entityRepository as EntityRepository<O>;
      }

      if (obj != null) {
        entityRepository = _entityRepositories[obj.runtimeType];
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }

      if (type != null) {
        entityRepository = _entityRepositories[type];
        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }

      if (name != null) {
        var nameSimplified = EntityAccessor.simplifiedName(name);

        entityRepository = _entityRepositories.values
            .where((e) => e.name == name || e.nameSimplified == nameSimplified)
            .firstOrNull;

        if (entityRepository != null && !entityRepository.isClosed) {
          return entityRepository as EntityRepository<O>;
        }
      }
    }

    return _knownEntityRepositoryProviders.getEntityRepository<O>(
        obj: obj, type: type, name: name, entityRepositoryProvider: this);
  }

  EntityRepository<O>? getEntityRepositoryByTypeInfo<O extends Object>(
      TypeInfo typeInfo) {
    var entityType = typeInfo.entityType;
    if (entityType == null) return null;

    return getEntityRepositoryByType<O>(entityType);
  }

  EntityRepository<O>? getEntityRepositoryByType<O extends Object>(Type type) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    checkInitialized();

    try {
      var entityRepository = _getEntityRepositoryByTypeImpl<O>(type);
      if (entityRepository != null) {
        return entityRepository;
      }

      if (!identical(this, _globalProvider)) {
        return _globalProvider._getEntityRepositoryByTypeImpl<O>(type);
      }

      return null;
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryByTypeImpl<O extends Object>(
      Type type) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[type];
      if (entityRepository != null && !entityRepository.isClosed) {
        return entityRepository as EntityRepository<O>;
      }
    }

    return _knownEntityRepositoryProviders.getEntityRepositoryByType<O>(type,
        entityRepositoryProvider: this);
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    if (!identical(provider, globalProvider)) {
      _knownEntityRepositoryProviders.add(provider);
    }
  }

  @override
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type, bool sync = false}) {
    if (id == null || type == null) return null;
    var entityRepository = getEntityRepositoryByType(type);
    if (entityRepository != null) {
      if (sync) return null;
      return entityRepository.selectByID(id).resolveMapped((o) => o as O?);
    }

    var enumReflection = ReflectionFactory().getRegisterEnumReflection(type);
    if (enumReflection != null) {
      return null;
    }

    _log.warning(
        "Can't get entity by ID($id). Can't find `EntityRepository` for type: $type");

    return null;
  }

  Map<Type, EntityRepository> allRepositories(
      {Map<Type, EntityRepository>? allRepositories,
      Set<EntityRepositoryProvider>? traversedProviders}) {
    allRepositories ??= <Type, EntityRepository>{};
    traversedProviders ??= <EntityRepositoryProvider>{};

    if (traversedProviders.contains(this)) {
      return allRepositories;
    }

    traversedProviders.add(this);

    for (var e in _entityRepositories.entries) {
      allRepositories.putIfAbsent(e.key, () => e.value);
    }

    for (var e in _knownEntityRepositoryProviders) {
      e.allRepositories(allRepositories: allRepositories);
    }

    return allRepositories;
  }

  @override
  String toString() {
    return '$runtimeType${_entityRepositories.keys.toList()}';
  }
}

extension IterableEntityRepositoryProviderExtension
    on Iterable<EntityRepositoryProvider> {
  EntityRepository<T>? getEntityRepository<T extends Object>(
      {T? obj,
      Type? type,
      String? name,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider}) {
    var length = this.length;
    if (length == 0) {
      return null;
    } else if (length == 1) {
      return first.getEntityRepository<T>(obj: obj, type: type, name: name);
    }

    var entityRepositories =
        map((e) => e.getEntityRepository<T>(obj: obj, type: type, name: name))
            .whereNotNull()
            .toList();

    return _resolveEntityRepository<T>(entityRepositories, type,
        entityRepositoryProvider, entityHandlerProvider);
  }

  EntityRepository<T>? getEntityRepositoryByTypeInfo<T extends Object>(
      TypeInfo typeInfo,
      {EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider}) {
    var entityType = typeInfo.entityType;
    if (entityType == null) return null;

    return getEntityRepositoryByType(entityType,
        entityRepositoryProvider: entityRepositoryProvider,
        entityHandlerProvider: entityHandlerProvider);
  }

  EntityRepository<T>? getEntityRepositoryByType<T extends Object>(Type type,
      {EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider}) {
    var length = this.length;
    if (length == 0) {
      return null;
    } else if (length == 1) {
      return first.getEntityRepositoryByType<T>(type);
    }

    var entityRepositories = map((e) => e.getEntityRepositoryByType<T>(type))
        .whereNotNull()
        .toList();

    return _resolveEntityRepository<T>(entityRepositories, type,
        entityRepositoryProvider, entityHandlerProvider);
  }

  EntityRepository<T>? _resolveEntityRepository<T extends Object>(
      List<EntityRepository<T>> entityRepositories,
      Type? type,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider) {
    var entityRepositoriesLength = entityRepositories.length;
    if (entityRepositoriesLength == 0) return null;

    if (entityRepositoriesLength > 1) {
      entityRepositories = entityRepositories.toSet().toList();
      entityRepositoriesLength = entityRepositories.length;
    }

    if (entityRepositoriesLength == 1) {
      return entityRepositories.first;
    } else if (entityRepositoriesLength > 1) {
      EntityHandler? entityHandler;
      if (entityHandlerProvider != null) {
        entityHandler = entityHandlerProvider.getEntityHandler(type: type);
      }

      if (entityRepositoryProvider != null) {
        var sameProvider = entityRepositories
            .where((r) =>
                r.provider == entityRepositoryProvider &&
                (entityHandler == null || r.entityHandler == entityHandler))
            .toList();
        if (sameProvider.length == 1) {
          return sameProvider.first;
        }
      } else if (entityHandler != null) {
        var sameProvider = entityRepositories
            .where((r) => r.entityHandler == entityHandler)
            .toList();
        if (sameProvider.length == 1) {
          return sameProvider.first;
        }
      }

      throw StateError(
          "Multiple `EntityRepository` candidates: $entityRepositories");
    } else {
      return null;
    }
  }
}

extension EntityRepositoryProviderExtension on EntityRepositoryProvider {
  FutureOr<Map<String, List<Object>>> storeAllFromJsonEncoded(
      String jsonEncoded,
      {Transaction? transaction,
      EntityResolutionRules? resolutionRules}) {
    var json = Json.decode(jsonEncoded);
    if (json == null) return <String, List<Object>>{};

    var map = (json as Map).map((key, value) {
      return MapEntry(
          key.toString(),
          (value as Iterable)
              .map((e) => (e as Map).map((key, value) =>
                  MapEntry<String, dynamic>(key.toString(), value as dynamic)))
              .toList());
    });

    return storeAllFromJson(map,
        transaction: transaction, resolutionRules: resolutionRules);
  }

  FutureOr<Map<String, List<Object>>> storeAllFromJson(
      Map<String, Iterable<Map<String, dynamic>>> entries,
      {Transaction? transaction,
      EntityResolutionRules? resolutionRules}) async {
    var results = <String, List<Object>>{};

    for (var e in entries.entries) {
      var typeName = e.key;
      var typeEntries = e.value;
      if (typeEntries.isEmpty) {
        results[typeName] = [];
        continue;
      }

      _log.info(
          'Populating `$typeName`: ${typeEntries.length} JSON entries...$_logSectionOpen');

      var entityRepository = getEntityRepository(name: typeName);
      if (entityRepository == null) {
        throw StateError(
            "Can't find `EntityRepository` for type name: $typeName");
      }

      var os = await entityRepository.storeAllFromJson(typeEntries,
          resolutionRules: resolutionRules);
      results[typeName] = os;

      _log.info('Populated `$typeName` entries: ${os.length}$_logSectionClose');
    }

    return results;
  }

  static const _logSectionOpen =
      '\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<';
  static const _logSectionClose =
      '\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>';

  FutureOr<Map<String, List<Object>>> populateFromSource(Object? source,
      {String? workingPath, EntityResolutionRules? resolutionRules}) {
    if (source == null) {
      return <String, List<Object>>{};
    } else if (source is Map<String, Iterable<Map<String, dynamic>>>) {
      _log.info(
          'Populating adapter ($this) [Map entries: ${source.length}]...$_logSectionOpen');

      return storeAllFromJson(source, resolutionRules: resolutionRules)
          .resolveMapped((res) {
        _log.info('Populate source finished. $_logSectionClose');
        return res;
      });
    } else if (source is String) {
      if (RegExp(r'^\S+\.json$').hasMatch(source)) {
        var apiPlatform = APIPlatform.get();

        var filePath =
            apiPlatform.resolveFilePath(source, parentPath: workingPath);

        if (filePath == null) {
          throw StateError("Can't resolve source file path: $source");
        }

        _log.info('Reading $this populate source file: $filePath');

        var fileData = apiPlatform.readFileAsString(filePath);

        if (fileData != null) {
          return fileData.resolveMapped((data) {
            if (data != null) {
              _log.info(
                  'Populating $this source [encoded JSON length: ${data.length}]...$_logSectionOpen');

              return storeAllFromJsonEncoded(data,
                      resolutionRules: resolutionRules)
                  .resolveMapped((res) {
                _log.info('Populate source finished. $_logSectionClose');
                return res;
              });
            } else {
              return <String, List<Object>>{};
            }
          });
        }
      } else {
        _log.info(
            'Populating $this source [encoded JSON length: ${source.length}]...$_logSectionOpen');

        return storeAllFromJsonEncoded(source, resolutionRules: resolutionRules)
            .resolveMapped((res) {
          _log.info('Populate source finished. $_logSectionClose');
          return res;
        });
      }
    }

    return <String, List<Object>>{};
  }
}

abstract class EntityRepository<O extends Object> extends EntityAccessor<O>
    with Initializable, Closable
    implements EntitySource<O>, EntityStorage<O> {
  static FutureOr<Map<String, dynamic>> resolveSubEntitiesFields(
      Map<String, dynamic> fields, Map<String, Type> subEntitiesFields,
      {Object? Function(String field, Map<String, dynamic> map)? fromMap,
      Object? Function(String field)? empty,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    if (subEntitiesFields.isEmpty) return fields;

    entityCache ??= JsonEntityCacheSimple();

    var entries = subEntitiesFields.entries.toList(growable: false);

    var futures = entries.map((e) {
      var f = e.key;
      var t = e.value;

      var fromMapField = fromMap != null ? (m) => fromMap(f, m) : null;
      var emptyField = empty != null ? () => empty(f) : null;

      return resolveEntityFromMap(
          parentMap: fields,
          entityField: f,
          fromMap: fromMapField,
          empty: emptyField,
          entityType: t,
          entityRepositoryProvider: entityRepositoryProvider,
          entityHandlerProvider: entityHandlerProvider,
          entityProvider: entityProvider,
          entityCache: entityCache,
          resolutionRules: resolutionRules);
    });

    return futures.resolveAllJoined((resolvedEntities) {
      var map2 = Map<String, dynamic>.from(fields);

      for (var i = 0; i < entries.length; ++i) {
        var f = entries[i].key;
        var o = resolvedEntities[i];
        map2[f] = o;
      }

      return map2;
    });
  }

  static FutureOr<E?> resolveEntityFromMap<E extends Object>(
      {Object? entityMap,
      Map<String, dynamic>? parentMap,
      String? entityField,
      E? Function(Map<String, dynamic> map)? fromMap,
      E? Function()? empty,
      Type? entityType,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider,
      EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    entityCache ??= JsonEntityCacheSimple();

    if (entityMap == null) {
      if (parentMap == null || entityField == null) {
        throw ArgumentError(
            'If `entityValue` is null, `parentMap` and `entityField` should be provided');
      }

      entityMap = parentMap[entityField];
    }

    FutureOr<E?> entity;

    if (entityMap is Map<String, dynamic>) {
      if (fromMap != null) {
        entity = fromMap(entityMap);
      }

      if (entity == null) {
        var entityRepository = _resolveEntityRepository<E>(entityField,
            entityType, entityRepositoryProvider, entityHandlerProvider);
        entity = entityRepository?.fromMap(entityMap,
            entityProvider: entityProvider,
            entityCache: entityCache,
            resolutionRules: resolutionRules);
      }

      if (entity == null) {
        entityHandlerProvider ??= EntityHandlerProvider.globalProvider;
        var entityHandler =
            entityHandlerProvider.getEntityHandler<E>(type: entityType);
        entity = entityHandler?.createFromMap(entityMap,
            entityProvider: entityProvider,
            entityCache: entityCache,
            resolutionRules: resolutionRules);
      }
    } else if (entityMap is num || entityMap is String) {
      var entityRepository = _resolveEntityRepository<E>(entityField,
          entityType, entityRepositoryProvider, entityHandlerProvider);
      entity = entityRepository?.selectByID(entityMap);
    }

    if (entity == null && empty != null) {
      return empty();
    } else {
      return entity;
    }
  }

  static EntityRepository<E>? _resolveEntityRepository<E extends Object>(
      String? entityField,
      Type? entityType,
      EntityRepositoryProvider? entityRepositoryProvider,
      EntityHandlerProvider? entityHandlerProvider) {
    if (entityRepositoryProvider == null && entityHandlerProvider != null) {
      var entityRepository = entityHandlerProvider.getEntityRepository<E>(
          type: entityType, name: entityField);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    entityRepositoryProvider ??= EntityRepositoryProvider.globalProvider;

    var entityRepository = entityRepositoryProvider.getEntityRepository<E>(
        type: entityType, name: entityField);
    return entityRepository;
  }

  final EntityRepositoryProvider provider;

  final EntityHandler<O> entityHandler;
  final Type type;

  late final InstanceTracker<O, Map<String, Object?>> _entitiesTracker;

  EntityRepository(
      EntityRepositoryProvider? provider, String name, this.entityHandler,
      {Type? type})
      : provider = provider ?? EntityRepositoryProvider.globalProvider,
        type = type ?? O,
        super(name) {
    if (!EntityHandler.isValidEntityType(this.type)) {
      throw StateError('Invalid EntityRepository type: $type ?? $O');
    }

    _entitiesTracker = InstanceTracker<O, Map<String, Object?>>(
        name, _getTrackingEntityFields);

    this.provider.registerEntityRepository(this);

    entityHandler.notifyKnownEntityRepositoryProvider(this.provider);
  }

  Map<String, Object?> _getTrackingEntityFields(O o) {
    var fields = getEntityFields(o);

    var fieldsCp =
        fields.map((key, value) => MapEntry(key, _trackingValueCopy(value)));
    return fieldsCp;
  }

  Object? _trackingValueCopy(Object? o) {
    if (o == null) return null;
    if (o is num ||
        o is String ||
        o is bool ||
        o is DynamicNumber ||
        o is DateTime ||
        o is Time ||
        o is Enum) return o;

    if (o is EntityReferenceBase) {
      return o.copy();
    }

    var v2 = deepCopy(o);
    return v2;
  }

  @override
  bool close() => super.close() as bool;

  bool isOfEntityType(Object? o) {
    if (o == null) return false;
    return o is O || o.runtimeType == type;
  }

  FutureOr<List<O>> storeAllFromJson(
          Iterable<Map<String, dynamic>> entitiesJson,
          {Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      executeInitialized(
          () =>
              _storeAllFromJsonImpl(entitiesJson, transaction, resolutionRules),
          parent: provider);

  FutureOr<List<O>> _storeAllFromJsonImpl(
          Iterable<Map<String, dynamic>> entitiesJson,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules) =>
      Transaction.executeBlock((transaction) {
        var osAsync = entitiesJson
            .map((e) => createFromMap(e,
                entityCache: transaction,
                entityProvider: provider,
                resolutionRules: resolutionRules))
            .resolveAll();

        return osAsync.resolveMapped((os) {
          return storeAll(os, transaction: transaction).resolveWithValue(os);
        });
      }, transaction: transaction);

  FutureOr<O> storeFromJson(Map<String, dynamic> json,
          {Transaction? transaction, EntityResolutionRules? resolutionRules}) =>
      executeInitialized(
          () => _storeFromJsonImpl(json, transaction, resolutionRules),
          parent: provider);

  FutureOr<O> _storeFromJsonImpl(Map<String, dynamic> json,
          Transaction? transaction, EntityResolutionRules? resolutionRules) =>
      Transaction.executeBlock((transaction) {
        var oAsync = createFromMap(json,
            entityCache: transaction, resolutionRules: resolutionRules);

        return oAsync.resolveMapped((o) {
          return store(o, transaction: transaction).resolveWithValue(o);
        });
      }, transaction: transaction);

  FutureOr<O> createFromMap(Map<String, dynamic> fields,
      {EntityProvider? entityProvider,
      EntityCache? entityCache,
      EntityResolutionRules? resolutionRules}) {
    try {
      var ret = entityHandler.createFromMap(fields,
          entityProvider: entityProvider,
          entityCache: entityCache,
          resolutionRules: resolutionRules);

      return ret.then((o) => o, onError: (e, s) {
        _log.severe(
            "Error creating `${entityHandler.type}` from fields Map: $fields",
            e,
            s);

        throw e;
      });
    } catch (e, s) {
      _log.severe(
          "Error creating `${entityHandler.type}` from fields Map: $fields",
          e,
          s);
      rethrow;
    }
  }

  @override
  Object? getEntityID(O o) => entityHandler.getID(o);

  Map<String, Object?> getEntityFields(O o) => entityHandler.getFields(o);

  FutureOr<O> fromMap(Map<String, dynamic> fields,
          {EntityProvider? entityProvider,
          EntityCache? entityCache,
          EntityResolutionRules? resolutionRules}) =>
      entityHandler.createFromMap(fields,
          entityProvider: entityProvider,
          entityCache: entityCache,
          resolutionRules: resolutionRules);

  bool isTrackingEntity(O o) => _entitiesTracker.isTrackedInstance(o);

  O trackEntity(O o, {bool stored = false}) {
    var entity = _entitiesTracker.trackInstance(o);

    if (stored) {
      notifyStoredEntities([entity]);
    }

    return entity;
  }

  void untrackEntity(O? o, {bool deleted = false}) {
    _entitiesTracker.untrackInstance(o);

    if (deleted && o != null) {
      notifyDeletedEntities([o]);
    }
  }

  O? trackEntityNullable(O? o) {
    if (o == null) return null;
    return trackEntity(o);
  }

  List<O> trackEntities(Iterable<O> os, {bool stored = false}) {
    var entities = _entitiesTracker.trackInstances(os);

    if (stored) {
      notifyStoredEntities(entities);
    }

    return entities;
  }

  List<O?> trackEntitiesNullable(Iterable<O?> os, {bool stored = false}) {
    var entities = _entitiesTracker.trackInstancesNullable(os);

    if (stored) {
      notifyStoredEntities(entities.whereNotNull());
    }

    return entities;
  }

  void untrackEntities(Iterable<O?> os, {bool deleted = false}) {
    _entitiesTracker.untrackInstances(os);

    if (deleted) {
      notifyDeletedEntities(os.whereNotNull());
    }
  }

  final EventStream<O> onStore = EventStream<O>();

  void notifyStoredEntities(Iterable<O> entities) {
    if (onStore.isUsed) {
      for (var e in entities) {
        onStore.add(e);
      }
    }
  }

  final EventStream<O> onDelete = EventStream<O>();

  void notifyDeletedEntities(Iterable<O> entities) {
    if (onDelete.isUsed) {
      for (var e in entities) {
        onDelete.add(e);
      }
    }
  }

  List<String>? getEntityChangedFields(O o) {
    var prevFields = _entitiesTracker.getTrackedInstanceInfo(o);
    if (prevFields == null) {
      return null;
    }

    var fields = getEntityFields(o);

    var changed = fields.entries.where((e) {
      var key = e.key;
      var val = e.value;
      var prevVal = prevFields[key];
      var eq = entityHandler.equalsFieldValues(key, val, prevVal);
      return !eq;
    });

    var changedFields = changed.map((e) => e.key).toList();
    return changedFields;
  }

  bool entityHasChangedFields(O o) {
    var prevFields = _entitiesTracker.getTrackedInstanceInfo(o);
    if (prevFields == null) {
      return false;
    }

    var fields = getEntityFields(o);

    var changed = fields.entries.any((e) {
      var key = e.key;
      var val = e.value;
      var prevVal = prevFields[key];
      var eq = entityHandler.equalsFieldValues(key, val, prevVal);
      return !eq;
    });

    return changed;
  }

  @override
  FutureOr<O?> selectByID(dynamic id,
      {Transaction? transaction, EntityResolutionRules? resolutionRules}) {
    if (id == null) return null;

    checkNotClosed();

    var cachedEntity = transaction?.getCachedEntityByID(id, type: type);
    if (cachedEntity != null) {
      return cachedEntity;
    }

    return select(ConditionID(id),
            transaction: transaction, resolutionRules: resolutionRules)
        .resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    }).resolveMapped(trackEntityNullable);
  }

  @override
  FutureOr<List<O?>> selectByIDs(List<dynamic> ids,
      {Transaction? transaction, EntityResolutionRules? resolutionRules}) {
    if (ids.isEmpty) return <O?>[];

    checkNotClosed();

    var idsUnique = ids.length == 1 ? ids : ids.toSet().toList();

    if (idsUnique.length == 1) {
      var id = idsUnique.first;

      var cachedEntity = transaction?.getCachedEntityByID(id, type: type);
      if (cachedEntity != null) {
        return <O>[cachedEntity];
      }

      var ret = selectByID(id, transaction: transaction);
      return ret.resolveMapped((o) => _idsToUniqueEntityList(ids, o));
    }

    var cachedEntities = transaction?.getCachedEntitiesByIDs<O>(idsUnique,
        type: type, removeCachedIDs: true);

    if (idsUnique.isEmpty) {
      var entities = _idsToEntitiesList(ids, null, cachedEntities);
      trackEntitiesNullable(entities);
      return entities;
    }

    var ret = select(ConditionIdIN(idsUnique),
        transaction: transaction, resolutionRules: resolutionRules);

    return ret
        .resolveMapped((results) => _idsToEntitiesList(
            ids, entityHandler.toEntitiesByIdMap(results), cachedEntities))
        .resolveMapped(trackEntitiesNullable);
  }

  List<O?> _idsToEntitiesList(List<dynamic> ids, Map<dynamic, O>? entitiesByID,
          [Map<dynamic, Object>? cachedEntities]) =>
      ids.map((id) => entitiesByID?[id] ?? cachedEntities?[id] as O?).toList();

  List<O?> _idsToUniqueEntityList(List<dynamic> ids, O? o) {
    if (o == null) return List<O?>.filled(ids.length, null);
    var oID = getEntityID(o);
    if (ids.length == 1) return <O?>[o];
    return ids.map((id) => id == oID ? o : null).toList();
  }

  FutureOr<dynamic> ensureStored(O o, {Transaction? transaction});

  FutureOr<bool> ensureReferencesStored(O o, {Transaction? transaction});

  @override
  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  @override
  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  @override
  FutureOr<O?> selectFirstByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      selectByQuery(query,
              parameters: parameters,
              namedParameters: namedParameters,
              transaction: transaction,
              limit: 1,
              resolutionRules: resolutionRules)
          .resolveMapped((result) => result.firstOrNull);

  @override
  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        limit: limit,
        resolutionRules: resolutionRules);
  }

  @override
  FutureOr<O?> deleteEntity(O o, {Transaction? transaction}) =>
      deleteByID(getEntityID(o), transaction: transaction);

  @override
  FutureOr<O?> tryDeleteEntity(O o, {Transaction? transaction}) =>
      tryCall<O>(() => deleteEntity(o, transaction: transaction));

  @override
  FutureOr<O?> deleteByID(dynamic id, {Transaction? transaction}) {
    if (id == null) return null;
    return delete(ConditionID(id), transaction: transaction)
        .resolveMapped((del) => del.firstOrNull);
  }

  @override
  FutureOr<O?> tryDeleteByID(dynamic id, {Transaction? transaction}) =>
      tryCall<O>(() => deleteByID(id, transaction: transaction));

  @override
  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction);
  }

  @override
  FutureOr<Iterable> deleteEntityCascade(O o, {Transaction? transaction}) {
    checkNotClosed();

    return Transaction.executeBlock(
        (transaction) => EntityStorage.deleteCascadeGeneric(o,
            transaction: transaction,
            entityHandler: entityHandler,
            entityRepository: this,
            repositoryProvider: provider),
        transaction: transaction);
  }

  Map<String, dynamic> information({bool extended = false});

  @override
  String toString() {
    var info = information();
    return '$runtimeType[$type:$name]@${provider.runtimeType}$info';
  }
}

/// A [Transaction] abortion error.
class TransactionAbortedError extends Error {
  String? reason;
  Object? payload;

  Object? abortError;
  StackTrace? abortStackTrace;

  TransactionAbortedError(
      {this.reason, this.payload, this.abortError, this.abortStackTrace});

  TransactionAbortedError withAbortStackTrace(StackTrace? abortStackTrace) {
    if (abortStackTrace == null ||
        identical(this.abortStackTrace, abortStackTrace)) {
      return this;
    }

    return TransactionAbortedError(
        reason: reason,
        payload: payload,
        abortError: abortError,
        abortStackTrace: abortStackTrace);
  }

  @override
  String toString() {
    var l = [
      if (reason != null) 'reason: $reason',
      if (abortError != null) 'abortError: $abortError',
    ];

    return 'TransactionAbortedError> ${l.join(' ; ')}';
  }
}

typedef ErrorFilter = bool Function(Object, StackTrace);

typedef TransactionExecution<R, C> = FutureOr<R> Function(C context);

/// An [EntityRepository] transaction.
class Transaction extends JsonEntityCacheSimple implements EntityProvider {
  static final ZoneField<Transaction> _executingTransaction =
      ZoneField<Transaction>(_errorZone);

  /// The current executing transaction.
  /// See [execute] and [executeBlock].
  static Transaction? get executingTransaction => _executingTransaction.get();

  final List<TransactionOperation> _operations = <TransactionOperation>[];

  List<TransactionOperation> get operations =>
      UnmodifiableListView(_operations);

  Object? get executor => _operations.firstOrNull?.executor;

  final List<TransactionOperation> _executedOperations =
      <TransactionOperation>[];

  List<TransactionOperation> get executedOperations =>
      UnmodifiableListView(_executedOperations);

  final bool autoCommit;

  late final Completer _transactionCompleter;

  Future get transactionFuture => _transactionCompleter.future;

  late final Completer _resultCompleter;

  Future get resultFuture => _resultCompleter.future;

  late final Completer<bool> _openCompleter;

  @override
  bool get allowEntityFetch => true;

  bool _external;

  final Transaction? parentTransaction;

  Transaction({bool autoCommit = false}) : this._(autoCommit, true);

  Transaction._(this.autoCommit,
      [this._external = false, this.parentTransaction])
      : super() {
    _transactionCompleter = _errorZone.createCompleter();
    _resultCompleter = _errorZone.createCompleter();
    _openCompleter = _errorZone.createCompleter<bool>();
  }

  Transaction.autoCommit() : this._(true, true);

  factory Transaction.executingOrNew({required bool autoCommit}) {
    return executingTransaction ?? Transaction._(autoCommit, true);
  }

  /// Executes [block] inside a [Transaction] and [commit]s it.
  /// - If the parameter [transaction] is provided it will be used as the [Transaction] instance.
  /// - If [allowExecutingTransaction] is `true` (default) and [transaction] is not provided
  ///   [executingTransaction] will be used.
  /// - If [transaction] is null and [allowExecutingTransaction] is false, or
  ///   no [executingTransaction] can be found, a new [Transaction] instance
  ///   will be created.
  /// - See [execute].
  static FutureOr<R> executeBlock<R>(
      FutureOr<R> Function(Transaction transaction) block,
      {Transaction? transaction,
      bool allowExecutingTransaction = true}) {
    if (transaction == null && allowExecutingTransaction) {
      transaction = executingTransaction;
    }

    if (transaction != null) {
      return block(transaction);
    }

    transaction = Transaction();

    return transaction
        ._executeImpl(() => block(transaction!))
        .resolveMapped((r) {
      if (r == null) {
        try {
          return r as R;
        } catch (e, s) {
          var abortError =
              transaction!.abortedError ?? transaction._resolveAbortError(e, s);
          var abortStackTrace = abortError.abortStackTrace;
          if (abortStackTrace != null) {
            Error.throwWithStackTrace(abortError, abortStackTrace);
          } else {
            throw abortError;
          }
        }
      }

      return r;
    });
  }

  static Zone? _errorZoneInstance;

  static Zone get _errorZone {
    return _errorZoneInstance ??= createErrorZone(
        uncaughtErrorTitle: '', onUncaughtError: _onErrorZoneUncaughtError);
  }

  static void _onErrorZoneUncaughtError(Object error, StackTrace stackTrace) {
    if (error is TransactionAbortedError ||
        isFilteredError(error, stackTrace)) {
      return;
    }

    printZoneError(error, stackTrace, title: '[Transaction ERROR]');
  }

  static final Set<ErrorFilter> _errorFilters = <ErrorFilter>{};

  static void registerErrorFilter(ErrorFilter errorFilter) {
    _errorFilters.add(errorFilter);
  }

  static bool isFilteredError(Object error, StackTrace stackTrace) {
    if (_errorFilters.isEmpty) return false;

    for (var f in _errorFilters) {
      if (f(error, stackTrace)) {
        return true;
      }
    }

    return false;
  }

  bool get isExecuting => identical(Transaction.executingTransaction, this);

  bool _committed = false;

  bool get isCommitted => _committed;

  bool get isCommitting => _commitCalled && (!_committed && !_aborted);

  int get length => _operations.length;

  bool get isEmpty => _operations.isEmpty;

  bool get isNotEmpty => _operations.isNotEmpty;

  int get notExecutedOperationsSize =>
      _operations.length - _executedOperations.length;

  bool isLastExecutingOperation(TransactionOperation op) {
    if (isEmpty) return false;

    var notExecuted = notExecutedOperationsSize;
    if (notExecuted > 1) {
      return false;
    }

    if (!_operations.contains(op)) {
      throw StateError("Operation not in transaction: $op");
    }

    if (notExecuted == 1) {
      return !_executedOperations.contains(op);
    } else {
      return _executedOperations.last == op;
    }
  }

  bool _opening = false;

  bool get isOpening => _opening;

  FutureOr<void> Function()? _transactionCloser;

  void open(
      FutureOr<Object> Function() opener, FutureOr<void> Function()? closer) {
    if (_opening) {
      throw StateError("Transaction already opening.");
    } else if (_open) {
      throw StateError("Transaction already open.");
    }

    _opening = true;
    _transactionCloser = closer;

    asyncTry(opener, then: (c) {
      _setContext(c!);
      return c;
    }, onError: (e, s) {
      _logTransaction.severe("Error opening transaction: $this", e, s);
    });
  }

  bool _open = false;

  bool get isOpen => _open;

  Object? _context;

  Object? get context => _context;

  void _setContext(Object context) {
    _context = context;
    _open = true;
    _opening = false;
    _openCompleter.complete(true);
  }

  FutureOr<R> onOpen<R>(FutureOr<R> Function() f) {
    if (_open) {
      return f();
    } else {
      return _openCompleter.future.then((_) {
        return f();
      });
    }
  }

  FutureOr? transactionResult;

  Object? _result;

  Object? get result => _result;

  void addOperation(TransactionOperation op) {
    if (_operations.contains(op)) {
      throw StateError("Operation already in transaction: $op");
    }

    if (_committed) {
      throw StateError("Transaction already committed:\n$this");
    }

    if (_aborted) {
      throw StateError("Transaction already aborted:\n$this");
    }

    if (_commitCalled) {
      throw StateError("Transaction is committing:\n$this");
    }

    _operations.add(op);
    op.id = _operations.length;
  }

  FutureOr<R> finishOperation<R>(TransactionOperation op, R result,
      {bool allowAutoCommit = true}) {
    _markOperationExecuted(op, result, allowAutoCommit);

    if (op.transactionRoot && !op.externalTransaction && length > 1) {
      return resultFuture.then((_) => result);
    } else if (_commitCalled) {
      return resultFuture.then((_) => result);
    } else {
      return result;
    }
  }

  void finishOperationVoid<R>(TransactionOperation op, R result,
      {bool allowAutoCommit = true}) {
    _markOperationExecuted(op, result, allowAutoCommit);
  }

  Completer<bool>? _waitingExecutedOperation;

  Object? _lastResult;

  void _markOperationExecuted(
      TransactionOperation op, Object? result, bool allowAutoCommit) {
    if (_executedOperations.contains(op)) {
      throw StateError("Operation already executed in transaction: $op");
    }

    if (_committed) {
      throw StateError("Transaction already committed:\n$this");
    }

    _executedOperations.add(op);

    if (!_aborted) {
      _lastResult = result;
    }

    var waitingExecutedOperation = _waitingExecutedOperation;
    if (waitingExecutedOperation != null &&
        !waitingExecutedOperation.isCompleted) {
      waitingExecutedOperation.complete(true);
      _waitingExecutedOperation = null;
    }

    if (allowAutoCommit) {
      _doAutoCommit();
    }
  }

  FutureOr<bool> waitAllExecuted() {
    if (_executedOperations.length == _operations.length) {
      return true;
    }
    return _waitAllExecutedImpl();
  }

  Future<bool> _waitAllExecutedImpl() async {
    while (_executedOperations.length < _operations.length) {
      var completer = _waitingExecutedOperation ??= Completer<bool>();
      await completer.future;
    }
    return true;
  }

  void _doAutoCommit() {
    if (autoCommit && _executedOperations.length == _operations.length) {
      commit();
    }
  }

  bool get isFinished => _committed || _aborted;

  bool _commitCalled = false;

  FutureOr<R?> commit<R>() {
    if (_aborted) {
      if (_commitCalled) {
        return null;
      }

      _commitCalled = true;

      return _abortImpl().resolveMapped((_) => null);
    }

    if (_commitCalled) {
      FutureOr<dynamic> retFuture;
      if (transactionResult != null) {
        retFuture = transactionResult;
      } else {
        retFuture = _transactionCompleter.future;
      }
      return retFuture.resolveMapped((r) => r as R?);
    }

    _commitCalled = true;

    return waitAllExecuted().resolveMapped((_) => _commitImpl<R>());
  }

  FutureOr<R?> _commitImpl<R>() {
    var result = _lastResult;
    _result = result;

    FutureOr<void>? closerResult;

    var closer = _transactionCloser;
    if (closer != null) {
      closerResult = closer();

      if (closerResult != null) {
        return closerResult.resolveWith(() => _commitComplete<R>(result));
      }
    }

    return _commitComplete<R>(result);
  }

  FutureOr<R?> _commitComplete<R>(Object? result) {
    if (_executedOperations.length < _operations.length) {
      throw StateError(
          "Not all operations in Transaction finished yet:\n$this");
    }

    var transactionResult = this.transactionResult;
    if (transactionResult != null) {
      if (transactionResult is Future) {
        var parentStackTrace = StackTrace.current;

        var ret = transactionResult
            .then((r) => _commitCompleteFinish<R>(r, parentStackTrace));

        _transactionCompleter.complete(result);
        return ret;
      } else {
        _transactionCompleter.complete(result);
        return _commitCompleteFinish<R>(result);
      }
    } else {
      var parentStackTrace = StackTrace.current;

      var ret = _transactionCompleter.future
          .then((r) => _commitCompleteFinish<R>(r, parentStackTrace));

      _transactionCompleter.complete(result);
      return ret;
    }
  }

  R? _commitCompleteFinish<R>(Object? result, [StackTrace? parentStackTrace]) {
    if (_executedOperations.length < _operations.length) {
      var error =
          StateError("Not all operations in Transaction finished yet:\n$this");

      if (parentStackTrace != null) {
        Error.throwWithStackTrace(error, parentStackTrace);
      } else {
        throw error;
      }
    }

    _committed = true;

    _logTransaction.info(
        '[transaction:$id] Committed> ops: ${_operations.length} ; root: ${_operations.firstOrNull} > result: $result');

    _resultCompleter.complete(result);
    return result as R?;
  }

  bool _aborted = false;

  /// Returns `true` if this transaction as aborted. See [abort].
  bool get isAborted => _aborted;

  TransactionAbortedError? _abortedError;

  /// Returns the abort error ([TransactionAbortedError]).
  TransactionAbortedError? get abortedError => _abortedError;

  /// Abort this transaction.
  FutureOr<TransactionAbortedError?> abort(
      {String? reason,
      Object? payload,
      Object? error,
      StackTrace? stackTrace}) {
    if (_commitCalled) {
      return null;
    }

    if (_aborted) {
      return _abortedError;
    }

    payload ??= _lastResult;

    var abortError = _resolveAbortError(error, stackTrace, reason, payload);

    _abortedError = abortError;
    _aborted = true;

    for (var op in _operations.whereNotIn(_executedOperations)) {
      finishOperationVoid(op, null, allowAutoCommit: false);
    }

    return abortError;
  }

  TransactionAbortedError _resolveAbortError(
      Object? error, StackTrace? stackTrace,
      [String? reason, Object? payload]) {
    if (error is TransactionAbortedError) {
      stackTrace ??=
          error.abortStackTrace ?? error.stackTrace ?? StackTrace.current;

      var abortError = error.withAbortStackTrace(stackTrace);
      return abortError;
    } else {
      if (error is Error) {
        stackTrace ??= error.stackTrace ?? StackTrace.current;
      } else {
        stackTrace ??= StackTrace.current;
      }

      return TransactionAbortedError(
          reason: reason,
          payload: payload,
          abortError: error,
          abortStackTrace: stackTrace);
    }
  }

  FutureOr<TransactionAbortedError> _abortImpl() {
    var abortError = _abortedError!;

    _transactionCompleter.completeError(
        abortError.abortError ?? abortError, abortError.abortStackTrace);

    if (transactionResult != null) {
      if (transactionResult is Future) {
        return (transactionResult as Future).then((r) {
          _resultCompleter.complete(null);
          return abortError;
        }, onError: (e) {
          return abortError;
        });
      } else {
        return transactionResult!.resolveMapped((r) {
          _resultCompleter.complete(null);
          return abortError;
        });
      }
    } else {
      return _transactionCompleter.future.then((r) {
        _resultCompleter.complete(null);
        return abortError;
      }, onError: (e) {
        _resultCompleter.complete(null);
        return abortError;
      });
    }
  }

  /// Executes the transaction operations dispatches inside [block] then [commit]s.
  FutureOr<R?> execute<R>(FutureOr<R> Function() block) => _executeImpl(block);

  /// Executes the transaction operations dispatches inside [block] then [commit]s.
  /// If any error occurs it returns the value returned by [onError].
  FutureOr<R> executeOrError<R>(FutureOr<R> Function() block,
          {required R Function(
                  Transaction transaction, Object error, StackTrace stackTrace)
              onError}) =>
      _executeImpl(block, onError: onError).resolveMapped((r) => r as R);

  FutureOr<R?> _executeImpl<R>(FutureOr<R> Function() block,
      {R Function(Transaction transaction, Object error, StackTrace stackTrace)?
          onError}) {
    if (isFinished) {
      throw StateError('Transaction already finished: $this');
    }

    if (executingTransaction != null) {
      throw StateError(
          'Already executing a Transaction: _executingTransaction');
    }

    var zone = _executingTransaction.createContextZone();
    _executingTransaction.set(this, contextZone: zone);

    if (onError != null) {
      return zone.asyncTry<R>(
        block,
        onError: (e, s) => _executeCommit(zone, e, s)
            .resolveMapped((val) => onError(this, e, s)),
        onFinally: () => _executeCommit(zone),
      );
    } else {
      return zone.asyncTry<R>(
        block,
        onError: (e, s) => _executeCommit(zone, e, s),
        onFinally: () => _executeCommit(zone),
      );
    }
  }

  FutureOr<void> _executeCommit(Zone zone,
      [Object? error, StackTrace? stackTrace]) {
    if (_commitCalled) return null;

    if (error != null) {
      stackTrace ??= StackTrace.current;
      _onExecutionError(error, stackTrace, null, null, rethrowError: false);
    }

    return asyncTry(commit, onFinally: () {
      if (identical(_executingTransaction.get(zone), this)) {
        _executingTransaction.disposeContextZone(zone);
      }
    });
  }

  final List<FutureOr> _executionsFutures = <FutureOr>[];

  FutureOr<R> addExecution<R, C>(TransactionExecution<R, C> exec,
      {Object? Function(Object error, StackTrace stackTrace)? errorResolver,
      String? Function()? debugInfo}) {
    if (_executionsFutures.isEmpty) {
      var ret = _executeSafe(exec, errorResolver, debugInfo);
      _executionsFutures.add(ret);
      return ret;
    } else {
      var last = _executionsFutures.last;

      var ret = last.resolveWith(() {
        return _executeSafe(exec, errorResolver, debugInfo);
      });

      _executionsFutures.add(ret);
      return ret;
    }
  }

  FutureOr<R> _executeSafe<R, C>(
      TransactionExecution<R, C> exec,
      Object? Function(Object error, StackTrace stackTrace)? errorResolver,
      String? Function()? debugInfo) {
    try {
      var ret = exec(context! as C);
      if (ret is Future<R>) {
        var future = ret;
        return future.catchError(
            (e, s) => _onExecutionError<R>(e, s, errorResolver, debugInfo));
      } else {
        return ret;
      }
    } catch (e, s) {
      return _onExecutionError<R>(e, s, errorResolver, debugInfo);
    }
  }

  FutureOr<R> notifyExecutionError<R>(Object error, StackTrace stackTrace,
      {Object? Function(Object error, StackTrace stackTrace)? errorResolver,
      String? Function()? debugInfo}) {
    return _onExecutionError<R>(error, stackTrace, errorResolver, debugInfo);
  }

  FutureOr<R> _onExecutionError<R>(
      Object error,
      StackTrace stackTrace,
      Object? Function(Object error, StackTrace stackTrace)? errorResolver,
      String? Function()? debugInfo,
      {bool rethrowError = true}) {
    var info = debugInfo != null ? debugInfo() : null;

    if (errorResolver != null) {
      error = errorResolver(error, stackTrace) ?? error;
    }

    if (info != null && info.isNotEmpty) {
      _log.severe(
          "Error executing transaction operation: $info", error, stackTrace);
    } else {
      _log.severe("Error executing transaction operation!", error, stackTrace);
    }

    if (!_aborted) {
      abort(error: error, stackTrace: stackTrace);
    }

    if (rethrowError) {
      Error.throwWithStackTrace(error, stackTrace);
    } else {
      return error as R;
    }
  }

  @override
  FutureOr<O?> getEntityByID<O>(id, {Type? type, bool sync = false}) =>
      getCachedEntityByID(id, type: type);

  @override
  void cacheEntity<O>(O entity, [Function(O o)? idGetter]) {
    super.cacheEntity(entity, idGetter);

    var parentTransaction = this.parentTransaction;
    if (parentTransaction != null) {
      parentTransaction.cacheEntity(entity, idGetter);
    }
  }

  @override
  void cacheEntities<O>(List<O> entities, [Function(O o)? idGetter]) {
    super.cacheEntities(entities, idGetter);

    var parentTransaction = this.parentTransaction;
    if (parentTransaction != null) {
      parentTransaction.cacheEntities(entities, idGetter);
    }
  }

  @override
  String toString({bool compact = false}) {
    return [
      'Transaction[#$id]{\n',
      '  open: $isOpen\n',
      '  executing: $isExecuting\n',
      '  committed: ${isCommitted ? 'true' : (isCommitting ? 'committing...' : 'false')}\n',
      '  aborted: $isAborted\n',
      '  abortedError: $abortedError\n',
      '  cachedEntities: $cachedEntitiesLength\n',
      '  external: $_external\n',
      if (compact) '  operations: ${operations.length}\n',
      if (!compact) '  operations: [\n',
      if (!compact && _operations.isNotEmpty)
        '    ${_operations.join(',\n    ')}',
      if (!compact) '\n  ],\n',
      if (compact) '  executedOperations: ${executedOperations.length}\n',
      if (!compact) '  executedOperations: [\n',
      if (!compact && _executedOperations.isNotEmpty)
        '    ${_executedOperations.join(',\n    ')}',
      if (!compact) '\n  ]\n',
      if (_commitCalled) '  result: $_result\n',
      '}'
    ].join();
  }
}

abstract class TransactionOperation {
  final TransactionOperationType type;
  final String repositoryName;
  Object? command;

  int? id;

  final Object executor;

  late final Transaction transaction;
  bool _transactionResolved = false;

  late final bool externalTransaction;
  late final bool transactionRoot;

  TransactionOperation(
      this.type, this.repositoryName, this.executor, Transaction? transaction) {
    var resolvedTransaction =
        resolveTransaction(transaction: transaction, operation: this);
    this.transaction = resolvedTransaction;
    _transactionResolved = true;

    externalTransaction = identical(resolvedTransaction, transaction);

    transactionRoot =
        resolvedTransaction.isEmpty && !resolvedTransaction.isExecuting;

    resolvedTransaction.addOperation(this);
  }

  static Transaction resolveTransaction(
      {Transaction? transaction, TransactionOperation? operation}) {
    if (transaction == null &&
        operation != null &&
        operation._transactionResolved) {
      return operation.transaction;
    }

    transaction ??= Transaction.executingTransaction;

    if (transaction == null) {
      return Transaction._(true);
    }

    var transactionExecutor = transaction.executor;

    if (transactionExecutor != null &&
        operation != null &&
        operation.executor != transactionExecutor &&
        operation is! TransactionOperationSubTransaction) {
      var subTransaction = Transaction._(true, false, transaction);

      var opSubTransaction = TransactionOperationSubTransaction(
          operation.repositoryName,
          operation.executor,
          transaction,
          subTransaction);

      subTransaction.transactionFuture.then((result) {
        opSubTransaction.finish(result);
      });

      return subTransaction;
    }

    return transaction;
  }

  int get transactionId => transaction.id;

  TransactionExecution? execution;

  String get _commandToString => command == null ? '' : ', command: $command';

  FutureOr<R> finish<R>(R result) => transaction.finishOperation(this, result);
}

class TransactionOperationSubTransaction<O> extends TransactionOperation {
  final Transaction subTransaction;

  TransactionOperationSubTransaction(
    String repositoryName,
    Object executor,
    Transaction parentTransaction,
    this.subTransaction,
  ) : super(TransactionOperationType.subTransaction, repositoryName, executor,
            parentTransaction);

  @override
  String toString() {
    return 'TransactionOperationSubTransaction[#$id@#${transaction.id}:subTransaction@$repositoryName]->${subTransaction.toString(compact: true)}';
  }
}

class TransactionOperationSelect<O> extends TransactionOperation {
  final EntityMatcher matcher;

  TransactionOperationSelect(
      String repositoryName, Object executor, this.matcher,
      [Transaction? transaction])
      : super(TransactionOperationType.select, repositoryName, executor,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:select@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

class TransactionOperationCount<O> extends TransactionOperation {
  final EntityMatcher? matcher;

  TransactionOperationCount(String repositoryName, Object executor,
      [this.matcher, Transaction? transaction])
      : super(TransactionOperationType.count, repositoryName, executor,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:count@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

class TransactionOperationStore<O> extends TransactionOperation {
  final O entity;

  TransactionOperationStore(String repositoryName, Object executor, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.store, repositoryName, executor,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:store@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationUpdate<O> extends TransactionOperation {
  final O entity;

  TransactionOperationUpdate(
      String repositoryName, Object executor, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.update, repositoryName, executor,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:update@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationStoreRelationship<O, E> extends TransactionOperation {
  final O entity;
  final List<E> others;

  TransactionOperationStoreRelationship(
      String repositoryName, Object executor, this.entity, this.others,
      [Transaction? transaction])
      : super(TransactionOperationType.storeRelationship, repositoryName,
            executor, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:storeRelationship@$repositoryName]{entity: $entity, other: $others$_commandToString}';
  }
}

class TransactionOperationConstrainRelationship<O, E>
    extends TransactionOperation {
  final O entity;
  final List<E> others;

  TransactionOperationConstrainRelationship(
      String repositoryName, Object executor, this.entity, this.others,
      [Transaction? transaction])
      : super(TransactionOperationType.constrainRelationship, repositoryName,
            executor, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:constrainRelationship@$repositoryName]{entity: $entity, other: $others$_commandToString}';
  }
}

class TransactionOperationSelectRelationship<O> extends TransactionOperation {
  final O entity;

  TransactionOperationSelectRelationship(
      String repositoryName, Object executor, this.entity,
      [Transaction? transaction])
      : super(TransactionOperationType.selectRelationship, repositoryName,
            executor, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:selectRelationship@$repositoryName]{entity: $entity$_commandToString}';
  }
}

class TransactionOperationSelectRelationships<O> extends TransactionOperation {
  final List<O> entities;

  TransactionOperationSelectRelationships(
      String repositoryName, Object executor, this.entities,
      [Transaction? transaction])
      : super(TransactionOperationType.selectRelationships, repositoryName,
            executor, transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:selectRelationships@$repositoryName]{entities: $entities$_commandToString}';
  }
}

class TransactionOperationDelete<O> extends TransactionOperation {
  final EntityMatcher matcher;

  TransactionOperationDelete(
      String repositoryName, Object executor, this.matcher,
      [Transaction? transaction])
      : super(TransactionOperationType.delete, repositoryName, executor,
            transaction);

  @override
  String toString() {
    return 'TransactionOperation[#$id@#${transaction.id}:delete@$repositoryName]{matcher: $matcher$_commandToString}';
  }
}

enum TransactionOperationType {
  subTransaction,
  select,
  count,
  store,
  storeRelationship,
  constrainRelationship,
  selectRelationship,
  selectRelationships,
  update,
  delete
}

extension TransactionOperationTypeExtension on TransactionOperationType {
  String get name {
    switch (this) {
      case TransactionOperationType.subTransaction:
        return 'subTransaction';
      case TransactionOperationType.select:
        return 'select';
      case TransactionOperationType.count:
        return 'count';
      case TransactionOperationType.store:
        return 'store';
      case TransactionOperationType.storeRelationship:
        return 'storeRelationship';
      case TransactionOperationType.constrainRelationship:
        return 'constrainRelationship';
      case TransactionOperationType.selectRelationship:
        return 'selectRelationship';
      case TransactionOperationType.update:
        return 'update';
      case TransactionOperationType.delete:
        return 'delete';
      default:
        throw ArgumentError("Unknown: $this");
    }
  }
}

abstract class IterableEntityRepository<O extends Object>
    extends EntityRepository<O> with EntityFieldAccessor<O> {
  IterableEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(provider, name, entityHandler);

  Iterable<O> iterable();

  dynamic nextID();

  void put(O o);

  void remove(O o);

  @override
  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    if (matcher == null) {
      return iterable().length;
    }

    return iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    }).length;
  }

  @override
  Object? getEntityID(O o) => getID(o, entityHandler: entityHandler);

  @override
  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) {
    checkNotClosed();

    var o = iterable().firstWhereOrNull((o) {
      var oId = getID(o, entityHandler: entityHandler);
      return oId == id;
    });

    return o != null;
  }

  @override
  Iterable<O> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules}) {
    checkNotClosed();

    var os = matches(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        limit: limit);

    return trackEntities(os);
  }

  @override
  FutureOr<Iterable<O>> selectAll(
      {Transaction? transaction,
      int? limit,
      EntityResolutionRules? resolutionRules}) {
    checkNotClosed();

    var os = all(limit: limit);

    return trackEntities(os);
  }

  @override
  O? selectByID(id,
      {Transaction? transaction, EntityResolutionRules? resolutionRules}) {
    checkNotClosed();

    var o = iterable().firstWhereOrNull((o) {
      var oId = getID(o, entityHandler: entityHandler);
      return oId == id;
    });

    return trackEntityNullable(o);
  }

  @override
  bool isStored(O o, {Transaction? transaction}) {
    var id = entityHandler.getID(o);
    return id != null;
  }

  @override
  dynamic store(O o, {Transaction? transaction}) {
    checkNotClosed();

    checkEntityFields(o);

    var op = TransactionOperationStore(name, this, o, transaction);

    return ensureReferencesStored(o, transaction: op.transaction)
        .resolveWith(() {
      var oId = getID(o, entityHandler: entityHandler);

      if (oId == null) {
        oId = nextID();
        setID(o, oId, entityHandler: entityHandler);
        put(o);
      }

      op.finish(oId);

      trackEntity(o, stored: true);

      return oId;
    });
  }

  @override
  void checkEntityFields(O o) {
    entityHandler.checkAllFieldsValues(o);

    var fieldsEntityAnnotations =
        entityHandler.getAllFieldsEntityAnnotations(o);

    var uniques = fieldsEntityAnnotations?.entries
        .where((e) => e.value.hasUnique)
        .toList();
    if (uniques == null || uniques.isEmpty) return;

    for (var e in uniques) {
      var field = e.key;
      var value = getField(o, field);
      if (value == null) continue;

      if (_containsEntryWithFieldValue(field, value)) {
        throw EntityFieldInvalid("unique", value,
            fieldName: field, entityType: type, tableName: name);
      }
    }
  }

  bool _containsEntryWithFieldValue(String field, value) =>
      iterable().any((elem) {
        var elemValue = getField(elem, field);
        return elemValue == value;
      });

  @override
  FutureOr<Iterable<dynamic>> storeAll(Iterable<O> os,
      {Transaction? transaction}) {
    checkNotClosed();

    return Transaction.executeBlock((transaction) {
      var result = os.map((o) => store(o, transaction: transaction)).toList();

      return result;
    }, transaction: transaction);
  }

  @override
  FutureOr<bool> setRelationship<E extends Object>(
      O o, String field, List<E> values,
      {TypeInfo? fieldType, Transaction? transaction}) {
    checkNotClosed();

    fieldType ??= entityHandler.getFieldType(o, field)!;

    if (!fieldType.isListEntityOrReference) {
      throw StateError("Field `$field` not a `List` entity type: $fieldType");
    }

    var op = TransactionOperationStoreRelationship(
        name, this, o, values, transaction);

    var valuesType = fieldType.arguments0!.type;
    var valuesRepository = provider.getEntityRepository<E>(type: valuesType)!;
    var valuesEntityHandler = valuesRepository.entityHandler;

    var oId = getID(o, entityHandler: entityHandler);
    var valuesIds = values.map((e) => valuesEntityHandler.getID(e));

    var valuesIdsNotNull = IterableNullableExtension(valuesIds).whereNotNull();

    return putRelationship(oId, valuesType, valuesIdsNotNull)
        .resolveMapped((ok) {
      op.finish(ok);
      return ok;
    });
  }

  FutureOr<bool> putRelationship(
      Object oId, Type valuesType, Iterable<Object> valuesIds);

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(O? o, String field,
      {Object? oId, TypeInfo? fieldType, Transaction? transaction}) {
    checkNotClosed();

    fieldType ??= entityHandler.getFieldType(o, field)!;

    if (!fieldType.isListEntityOrReference) {
      throw StateError("Field `$field` not a `List` entity type: $fieldType");
    }

    oId ??= getID(o!, entityHandler: entityHandler)!;

    var valuesType = fieldType.arguments0!.type;

    var op = TransactionOperationSelectRelationship(
        name, this, o ?? oId, transaction);

    var valuesIds = getRelationship(oId!, valuesType);
    op.finish(valuesIds);

    return valuesIds;
  }

  @override
  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
      List<O>? os, String field,
      {List<dynamic>? oIds, TypeInfo? fieldType, Transaction? transaction}) {
    oIds ??= os!
        .map((o) => getID(o, entityHandler: entityHandler)! as Object)
        .toList();

    if (oIds.isEmpty) {
      return <dynamic, Iterable<dynamic>>{};
    }

    var entries = oIds.map((oId) {
      var objs = selectRelationship(null, field,
          oId: oId, fieldType: fieldType, transaction: transaction);
      return MapEntry(oId, objs);
    }).toList();

    var results =
        Map<dynamic, FutureOr<Iterable<dynamic>>>.fromEntries(entries);
    return results.resolveAllValues();
  }

  List<Object> getRelationship(Object oId, Type valuesType);

  @override
  FutureOr<dynamic> ensureStored(O o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew(autoCommit: true);

    var id = getID(o, entityHandler: entityHandler);

    if (id == null || entityHasChangedFields(o)) {
      return store(o, transaction: transaction);
    } else {
      return ensureReferencesStored(o, transaction: transaction)
          .resolveWithValue(id);
    }
  }

  @override
  FutureOr<bool> ensureReferencesStored(O o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew(autoCommit: true);

    var fieldsNames = entityHandler.fieldsNames(o);

    var futures = fieldsNames.map((fieldName) {
      var value = entityHandler.getField(o, fieldName);
      if (value == null) return null;

      var fieldType = entityHandler.getFieldType(o, fieldName)!;

      if (!EntityHandler.isValidEntityType(fieldType.type)) {
        return null;
      }

      if (value is List && fieldType.isList && fieldType.hasArguments) {
        var elementType = fieldType.arguments.first;

        var elementRepository =
            provider.getEntityRepositoryByTypeInfo(elementType);
        if (elementRepository == null) return null;

        var futures = value.map((e) {
          return elementRepository.ensureStored(e, transaction: transaction);
        }).toList();

        return futures.resolveAll();
      } else {
        var repository =
            provider.getEntityRepository(type: fieldType.type, obj: value);
        if (repository == null) return null;

        return repository.ensureStored(value, transaction: transaction);
      }
    });

    return futures.resolveAllWithValue(true);
  }

  @override
  FutureOr<O?> deleteByID(dynamic id, {Transaction? transaction}) {
    if (id == null) return null;

    checkNotClosed();

    var o = selectByID(id, transaction: transaction);
    if (o == null) return null;

    remove(o);
    return o;
  }

  @override
  FutureOr<O?> tryDeleteByID(dynamic id, {Transaction? transaction}) =>
      tryCall<O>(() => deleteByID(id, transaction: transaction));

  @override
  FutureOr<O?> deleteEntity(O o, {Transaction? transaction}) =>
      deleteByID(getEntityID(o));

  @override
  FutureOr<O?> tryDeleteEntity(O o, {Transaction? transaction}) =>
      tryCall<O>(() => deleteEntity(o, transaction: transaction));

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var del = matches(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    for (var o in del) {
      remove(o);
    }

    untrackEntities(del, deleted: true);

    return del;
  }

  List<O> matches(EntityMatcher<dynamic> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit}) {
    var itr = iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    });

    if (limit != null && limit > 0) {
      itr = itr.take(limit);
    }

    return itr.toList();
  }

  List<O> all({int? limit}) {
    var itr = iterable();

    if (limit != null && limit > 0) {
      itr = itr.take(limit);
    }

    return itr.toList();
  }

  @override
  Map<String, dynamic> information({bool extended = false}) => {
        'name': name,
        'length': length(),
        'nextID': nextID(),
      };
}

class SetEntityRepository<O extends Object>
    extends IterableEntityRepository<O> {
  SetEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(name, entityHandler, provider: provider);

  final Set<O> _entries = <O>{};

  @override
  Iterable<O> iterable() => _entries;

  @override
  int nextID() => _entries.length + 1;

  @override
  int length({Transaction? transaction}) => _entries.length;

  @override
  void put(O o) {
    _entries.add(o);
  }

  @override
  void remove(O o) {
    _entries.remove(o);
  }

  final Map<Type, Map<Object, Set<Object>>> _relationships =
      <Type, Map<Object, Set<Object>>>{};

  @override
  FutureOr<bool> putRelationship(
      Object oId, Type valuesType, Iterable<Object> valuesIds) {
    var typeRelationships =
        _relationships.putIfAbsent(valuesType, () => <Object, Set<Object>>{});

    typeRelationships[oId] = valuesIds.toSet();

    return true;
  }

  @override
  List<Object> getRelationship(Object oId, Type valuesType) {
    var typeRelationships = _relationships[valuesType];

    var idReferences = typeRelationships?[oId];

    return idReferences?.toList() ?? <Object>[];
  }
}
