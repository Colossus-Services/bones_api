import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';

typedef ToEncodable = Object? Function(Object? object);

/// JSON utility class.
class Json {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    Time.boot();

    JsonDecoder.registerTypeDecoder(Decimal, (o, d, t) => Decimal.from(o));

    JsonDecoder.registerTypeDecoder(
        DynamicInt, (o, d, t) => DynamicInt.from(o));

    JsonDecoder.registerTypeDecoder(
        DynamicNumber, (o, d, t) => DynamicNumber.from(o));

    JsonDecoder.registerTypeDecoder(EntityReference, (o, jsonDecoder, t) {
      var entityCache = jsonDecoder?.entityCache;
      var entityProvider = entityCache?.asEntityProvider;
      if (t.isValidEntityReferenceType) {
        return t.arguments0!.toEntityReference(o,
            entityProvider: entityProvider, entityCache: entityCache);
      } else {
        return EntityReference.from(o,
            entityProvider: entityProvider, entityCache: entityCache);
      }
    });

    JsonDecoder.registerTypeDecoder(EntityReferenceList, (o, jsonDecoder, t) {
      var entityCache = jsonDecoder?.entityCache;
      var entityProvider = entityCache?.asEntityProvider;
      if (t.isValidEntityReferenceListType) {
        return t.arguments0!.toEntityReferenceList(o,
            entityProvider: entityProvider, entityCache: entityCache);
      } else {
        return EntityReferenceList.from(o,
            entityProvider: entityProvider, entityCache: entityCache);
      }
    });
  }

  /// A standard implementation of mask filed.
  ///
  /// - [extraKeys] is the extra keys to mask.
  static bool standardJsonMaskField(String key, {Iterable<String>? extraKeys}) {
    key = key.trim().toLowerCase();
    return key == 'password' ||
        key == 'pass' ||
        key == 'passwordhash' ||
        key == 'passhash' ||
        key == 'passphrase' ||
        key == 'ping' ||
        key == 'secret' ||
        key == 'privatekey' ||
        key == 'pkey' ||
        (extraKeys != null && extraKeys.contains(key));
  }

  /// Converts [o] to a JSON collection/data.
  /// - [maskField] when preset indicates if a field value should be masked with [maskText].
  static T? toJson<T>(Object? o,
      {JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodableJsonProvider? toEncodableProvider,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonCodec = _buildJsonEncoder(
        maskField,
        maskText,
        removeField,
        removeNullFields,
        toEncodableProvider,
        toEncodable,
        entityHandlerProvider,
        entityCache);

    return jsonCodec.toJson(o, autoResetEntityCache: autoResetEntityCache);
  }

  /// Transforms [o] to an encoded JSON.
  /// - If [pretty] is `true` generates a pretty JSON, with indentation and line break.
  /// - [maskField] is the mask function. See [toJson].
  /// - [toEncodable] converts a not encodable [Object] to a encodable JSON collection/data. See [dart_convert.JsonEncoder].
  static String encode(Object? o,
      {bool pretty = false,
      JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodableJsonProvider? toEncodableProvider,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonEncoder = _buildJsonEncoder(
        maskField,
        maskText,
        removeField,
        removeNullFields,
        toEncodableProvider,
        toEncodable,
        entityHandlerProvider,
        entityCache);

    return jsonEncoder.encode(o,
        pretty: pretty, autoResetEntityCache: autoResetEntityCache);
  }

  /// Sames as [encode] but returns a [Uint8List].
  static Uint8List encodeToBytes(Object? o,
      {bool pretty = false,
      JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodableJsonProvider? toEncodableProvider,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonEncoder = _buildJsonEncoder(
        maskField,
        maskText,
        removeField,
        removeNullFields,
        toEncodableProvider,
        toEncodable,
        entityHandlerProvider,
        entityCache);

    return jsonEncoder.encodeToBytes(o,
        pretty: pretty, autoResetEntityCache: autoResetEntityCache);
  }

  static final JsonEncoder defaultEncoder = JsonEncoder(
      toEncodableProvider: (o) => _jsonEncodableProvider(o, null),
      entityCache: JsonEntityCacheSimple(),
      forceDuplicatedEntitiesAsID: true);

  static JsonEncoder _buildJsonEncoder(
      JsonFieldMatcher? maskField,
      String maskText,
      JsonFieldMatcher? removeField,
      bool removeNullFields,
      ToEncodableJsonProvider? toEncodableProvider,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache) {
    if (entityHandlerProvider == null &&
        toEncodableProvider == null &&
        toEncodable == null &&
        !removeNullFields &&
        removeField == null &&
        maskField == null &&
        entityCache == null) {
      return defaultEncoder;
    }

    return JsonEncoder(
        maskField: maskField,
        maskText: maskText,
        removeField: removeField,
        removeNullFields: removeNullFields,
        toEncodable: toEncodable == null ? null : (o, j) => toEncodable(o),
        toEncodableProvider: toEncodableProvider != null
            ? (o) =>
                toEncodableProvider(o) ??
                _jsonEncodableProvider(o, entityHandlerProvider)
            : (o) => _jsonEncodableProvider(o, entityHandlerProvider),
        entityCache: entityCache,
        forceDuplicatedEntitiesAsID: true);
  }

  static ToEncodableJsonProvider defaultToEncodableJsonProvider(
          [EntityHandlerProvider? entityHandlerProvider]) =>
      (o) => _jsonEncodableProvider(o, entityHandlerProvider);

  static ToEncodableJson? _jsonEncodableProvider(
      Object object, EntityHandlerProvider? entityHandlerProvider) {
    if (object is DateTime) {
      return (o, j) => (o as DateTime).toUtc().toString();
    } else if (object is Time) {
      return (o, j) => o.toString();
    } else if (object is DynamicNumber) {
      return (o, j) => (o as DynamicNumber).toStringStandard();
    } else if (object is EntityReferenceBase) {
      return (o, j) => (o as EntityReferenceBase).toJson(j);
    }

    var oType = object.runtimeType;

    if (object is! num &&
        object is! String &&
        object is! bool &&
        object is! List &&
        object is! Map &&
        object is! Set) {
      final reflectionFactory = ReflectionFactory();

      var classReflection = reflectionFactory.getRegisterClassReflection(oType);

      // Do not use `EntityHandler` if there's a registered `ClassReflection`:
      if (classReflection != null) {
        return null;
      }
    }

    EntityHandler? entityHandler;

    if (entityHandlerProvider != null) {
      entityHandler = entityHandlerProvider.getEntityHandler(type: oType);
    }

    entityHandler ??=
        EntityHandlerProvider.globalProvider.getEntityHandler(type: oType);

    if (entityHandler != null) {
      return (o, j) => entityHandler!.getFields(o);
    }

    return null;
  }

  /// Converts [o] to [type].
  static JsonDecoder decoder(
      {JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);
    return jsonDecoder;
  }

  /// Converts [o] to [type].
  static T? fromJson<T>(Object? o,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJson<T>(o,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T?> fromJsonAsync<T>(Object? o,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonAsync<T>(o,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to as [List] of [type].
  static List<T?> fromJsonList<T>(Iterable o,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonList<T>(o,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to as [List] of [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<List<T?>> fromJsonListAsync<T>(FutureOr<Iterable> o,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonListAsync<T>(o,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [map] to [type].
  static T fromJsonMap<T>(Map<String, Object?> map,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonMap<T>(map,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [map] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T> fromJsonMapAsync<T>(FutureOr<Map<String, Object?>> map,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonMapAsync<T>(map,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Decodes [encodedJson] to a JSON collection/data.
  static T decode<T>(String encodedJson,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decode(encodedJson,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Sames as [decode] but from a [Uint8List].
  static T decodeFromBytes<T>(Uint8List encodedJsonBytes,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeFromBytes(encodedJsonBytes,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Decodes [encodedJson] to a JSON collection/data accepting async values.
  static FutureOr<T> decodeAsync<T>(FutureOr<String> encodedJson,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeAsync(encodedJson,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  /// Sames as [decodeAsync] but from a [Uint8List].
  static FutureOr<T> decodeFromBytesAsync<T>(
      FutureOr<Uint8List> encodedJsonBytes,
      {Type? type,
      TypeInfo? typeInfo,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeFromBytesAsync(encodedJsonBytes,
        type: type,
        typeInfo: typeInfo,
        autoResetEntityCache: autoResetEntityCache);
  }

  static final JsonDecoder defaultDecoder = JsonDecoder(
      jsonValueDecoderProvider: _jsonValueDecoderProvider,
      jsomMapDecoderAsyncProvider: (t, m, j) =>
          _jsomMapDecoderAsyncProvider(t, j, null, null),
      jsomMapDecoderProvider: (t, m, j) => _jsomMapDecoderProvider(t, j, null),
      entityCache: JsonEntityCacheSimple(),
      forceDuplicatedEntitiesAsID: true);

  static JsonDecoder _buildJsonDecoder(JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider, EntityCache? entityCache) {
    if (jsomMapDecoder == null &&
        entityHandlerProvider == null &&
        entityCache == null) {
      return defaultDecoder;
    }

    return JsonDecoder(
        jsonValueDecoderProvider: (t, v, j) => _jsonValueDecoderProvider(
            t, v, j, entityHandlerProvider, entityCache),
        jsomMapDecoder: jsomMapDecoder,
        jsomMapDecoderAsyncProvider: (t, m, j) => _jsomMapDecoderAsyncProvider(
            t, j, entityHandlerProvider, entityCache),
        jsomMapDecoderProvider: (t, m, j) =>
            _jsomMapDecoderProvider(t, j, entityHandlerProvider),
        iterableCaster: (v, t, j) =>
            _iterableCaster(v, t, j, entityHandlerProvider),
        entityCache: entityCache,
        forceDuplicatedEntitiesAsID: true);
  }

  static JsonValueDecoder<O>? _jsonValueDecoderProvider<O>(
      Type type, Object? value, JsonDecoder jsonDecoder,
      [EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache]) {
    if (type == Time) {
      return (o, t, j) {
        var time = Time.from(o);
        return time as O?;
      };
    } else if (type == Decimal) {
      return (o, t, j) {
        var d = Decimal.from(o);
        return d as O?;
      };
    } else if (type == DynamicInt) {
      return (o, t, j) {
        var d = DynamicInt.from(o);
        return d as O?;
      };
    }

    if (entityHandlerProvider != null || entityCache != null) {
      return (o, t, j) {
        return _jsonEntityDecoder<O>(t, o, entityHandlerProvider, entityCache);
      };
    }

    return null;
  }

  static O? _jsonEntityDecoder<O>(Type type, Object? value,
      EntityHandlerProvider? entityHandlerProvider, EntityCache? entityCache) {
    if (entityCache != null) {
      var entity = entityCache.getCachedEntityByID<O>(value, type: type);
      if (entity != null) return entity;
    }

    if (entityHandlerProvider != null && value is Map<String, Object?>) {
      var entityHandler = entityHandlerProvider.getEntityHandler(type: type);
      var entity = entityHandler?.createFromMapSync(value);
      if (entity != null) return entity as O;
    }

    return null;
  }

  static JsomMapDecoderAsync? _jsomMapDecoderAsyncProvider(
      Type type,
      JsonDecoder jsonDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache) {
    if (entityHandlerProvider != null) {
      var entityHandler = entityHandlerProvider.getEntityHandler(type: type);

      if (entityHandler != null) {
        return (m, j) => entityHandler.createFromMap(m,
            entityProvider: EntityRepositoryProvider.globalProvider,
            entityCache: entityCache);
      }
    }

    var classReflection = ReflectionFactory().getRegisterClassReflection(type);

    if (classReflection != null) {
      return (m, j) => classReflection.createInstanceFromMap(m,
          fieldNameResolver: defaultFieldNameResolver,
          fieldValueResolver: (f, v, t) =>
              defaultFieldValueResolver(f, v, t, j, entityHandlerProvider));
    }

    var entityHandler =
        EntityHandlerProvider.globalProvider.getEntityHandler(type: type);

    if (entityHandler != null) {
      return (m, j) => entityHandler.createFromMap(m,
          entityProvider: EntityRepositoryProvider.globalProvider,
          entityCache: entityCache);
    }

    return null;
  }

  static JsomMapDecoder? _jsomMapDecoderProvider(Type type,
      JsonDecoder jsonDecoder, EntityHandlerProvider? entityHandlerProvider) {
    var classReflection = ReflectionFactory().getRegisterClassReflection(type);

    if (classReflection != null) {
      return (m, j) => classReflection.createInstanceFromMap(m,
          fieldNameResolver: defaultFieldNameResolver,
          fieldValueResolver: (f, v, t) =>
              defaultFieldValueResolver(f, v, t, j, entityHandlerProvider));
    }

    return null;
  }

  static String? defaultFieldNameResolver(
      String field, Map<String, Object?> map) {
    if (map.containsKey(field)) {
      return field;
    }

    var fieldSimple = StringUtils.toLowerCaseSimpleCached(field);

    if (field.length == fieldSimple.length) {
      for (var k in map.keys) {
        if (equalsIgnoreAsciiCase(fieldSimple, k)) {
          return k;
        }
      }
    } else {
      for (var k in map.keys) {
        if (equalsIgnoreAsciiCase(fieldSimple, k)) {
          return k;
        }

        if (equalsIgnoreAsciiCase(field, k)) {
          return k;
        }
      }
    }

    // Non matching fields should return `null` (not present):
    return null;
  }

  static Object? defaultFieldValueResolver(
      String field,
      Object? value,
      TypeReflection type,
      JsonDecoder jsonDecoder,
      EntityHandlerProvider? entityHandlerProvider) {
    if (type.isListEntity && value is Iterable) {
      return _iterableCaster(value, type, jsonDecoder, entityHandlerProvider);
    } else {
      if (value == null) {
        return null;
      } else if (type.type == value.runtimeType) {
        return value;
      } else if (type.isStringType) {
        return TypeParser.parseString(value);
      } else if (type.isIntType) {
        return TypeParser.parseInt(value);
      } else if (type.isDoubleType) {
        return TypeParser.parseDouble(value);
      } else if (type.isNumType) {
        return TypeParser.parseNum(value);
      } else if (type.isBoolType) {
        return TypeParser.parseBool(value);
      } else if (type.isEntityReferenceType && value is EntityReference) {
        if (type.arguments0?.type == value.type) {
          return value;
        }
      } else if (type.isEntityReferenceListType &&
          value is EntityReferenceList) {
        if (type.arguments0?.type == value.type) {
          return value;
        }
      }

      return jsonDecoder.fromJson(value,
          typeInfo: type.typeInfo, autoResetEntityCache: false);
    }
  }

  static Object? _iterableCaster(Iterable value, TypeReflection type,
      JsonDecoder jsonDecoder, EntityHandlerProvider? entityHandlerProvider) {
    final entityTypeReflection =
        type.isListEntityOrReference ? type.arguments0! : type;
    final entityType = entityTypeReflection.type;

    EntityHandler? entityHandler;
    if (entityHandlerProvider != null) {
      entityHandler = entityHandlerProvider.getEntityHandler(type: entityType);
    }

    if (entityHandler == null) {
      var classReflection =
          ReflectionFactory().getRegisterClassReflection(entityType);

      entityHandler = classReflection?.entityHandler;
    }

    if (entityHandler == null) return null;

    final entityCache = jsonDecoder.entityCache;
    var classification = entityHandler.classifyIterableElements(value);

    Iterable list = value;

    if (classification.isAllObj) {
      list = value;
    } else if (classification.isAllMap) {
      list = value
          .map((m) => m is Map<String, dynamic>
              ? entityHandler!.createFromMapSync(m, entityCache: entityCache)
              : null)
          .toList();
    } else if (classification.isAllID) {
      list = value.map((id) {
        if (id == null) return null;
        var o = entityCache.getCachedEntityByID(id, type: entityType);
        return o;
      }).toList();
    } else if (classification.isAllNullOrEmpty) {
      list = value;
    } else {
      list = value.map((e) {
        if (e == null) {
          return null;
        } else if (e is Map<String, dynamic>) {
          return entityHandler!.createFromMapSync(e, entityCache: entityCache);
        } else if ((e as Object).isEntityIDPrimitiveType) {
          return entityCache.getCachedEntityByID(e, type: entityType);
        } else {
          return e;
        }
      }).toList();
    }

    return classification.hasNull
        ? entityHandler.castIterableNullable(list, entityType)
        : entityHandler.castIterable(list, entityType);
  }

  /// A debugging tool that generates a `String` representation of [o],
  /// showing the [runtimeType] of each value in the tree.
  static String dumpRuntimeTypes(Object? o, [String indent = '']) {
    if (o == null) return '$indent<null>';
    if (o is String) return '$indent<String>:"$o"';
    if (o is bool) return '$indent<bool>:$o';
    if (o is int) return '$indent<int>:$o';
    if (o is double) return '$indent<double>:$o';
    if (o is num) return '$indent<num>:$o';
    if (o is Iterable) {
      return '$indent<${o.runtimeType}>:[\n$indent${o.map((e) => dumpRuntimeTypes(e, '  $indent')).join(',\n$indent')}\n$indent]';
    }
    if (o is Map) {
      return '$indent<${o.runtimeType}>:{\n$indent${o.entries.map((e) => "${dumpRuntimeTypes(e.key, '  $indent')}=${dumpRuntimeTypes(e.value, '')}").join(',\n$indent')}\n$indent}';
    }
    return '@<${o.runtimeType}>:$o';
  }
}

extension JsonEntityCacheExtension on JsonEntityCache {
  EntityProvider get asEntityProvider => _EntityProviderFromEntityCache(this);
}

class _EntityProviderFromEntityCache implements EntityProvider {
  final JsonEntityCache entityCache;

  _EntityProviderFromEntityCache(this.entityCache);

  @override
  FutureOr<O?> getEntityByID<O>(id,
          {Type? type,
          bool sync = false,
          EntityResolutionRules? resolutionRules}) =>
      entityCache.getCachedEntityByID(id, type: type);

  @override
  String toString() => 'EntityProvider@$entityCache';
}
