import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_reference.dart';
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

    JsonDecoder.registerTypeDecoder(Decimal, (o, d) => Decimal.from(o));

    JsonDecoder.registerTypeDecoder(DynamicInt, (o, d) => DynamicInt.from(o));

    JsonDecoder.registerTypeDecoder(
        DynamicNumber, (o, d) => DynamicNumber.from(o));

    JsonDecoder.registerTypeDecoder(EntityReference, (o, jsonDecoder) {
      var entityCache = jsonDecoder?.entityCache;
      var entityProvider = entityCache?.asEntityProvider;
      return EntityReference.from(o, entityProvider: entityProvider);
    });

    JsonDecoder.registerTypeDecoder(EntityReferenceList, (o, jsonDecoder) {
      var entityCache = jsonDecoder?.entityCache;
      var entityProvider = entityCache?.asEntityProvider;
      return EntityReferenceList.from(o, entityProvider: entityProvider);
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
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonCodec = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider, entityCache);

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
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonEncoder = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider, entityCache);

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
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonEncoder = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider, entityCache);

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
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache) {
    if (entityHandlerProvider == null &&
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
        toEncodableProvider: (o) =>
            _jsonEncodableProvider(o, entityHandlerProvider),
        entityCache: entityCache,
        forceDuplicatedEntitiesAsID: true);
  }

  static ToEncodableJson? _jsonEncodableProvider(
      Object object, EntityHandlerProvider? entityHandlerProvider) {
    if (object is Time) {
      return (o, j) => object.toString();
    } else if (object is DynamicNumber) {
      return (o, j) => object.toStringStandard();
    }

    var oType = object.runtimeType;

    if (entityHandlerProvider != null) {
      var entityHandler = entityHandlerProvider.getEntityHandler(type: oType);

      if (entityHandler != null) {
        return (o, j) => entityHandler.getFields(o);
      }
    }

    var entityHandler =
        EntityHandlerProvider.globalProvider.getEntityHandler(type: oType);

    if (entityHandler != null) {
      return (o, j) => entityHandler.getFields(o);
    }

    return null;
  }

  /// Converts [o] to [type].
  static T? fromJson<T>(Object? o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJson<T>(o,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T?> fromJsonAsync<T>(Object? o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonAsync<T>(o,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to as [List] of [type].
  static List<T?> fromJsonList<T>(Iterable o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonList<T>(o,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [o] to as [List] of [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<List<T?>> fromJsonListAsync<T>(FutureOr<Iterable> o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonListAsync<T>(o,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [map] to [type].
  static T fromJsonMap<T>(Map<String, Object?> map,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonMap<T>(map,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Converts [map] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T> fromJsonMapAsync<T>(FutureOr<Map<String, Object?>> map,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.fromJsonMapAsync<T>(map,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Decodes [encodedJson] to a JSON collection/data.
  static T decode<T>(String encodedJson,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decode(encodedJson,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Sames as [decode] but from a [Uint8List].
  static T decodeFromBytes<T>(Uint8List encodedJsonBytes,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeFromBytes(encodedJsonBytes,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Decodes [encodedJson] to a JSON collection/data accepting async values.
  static FutureOr<T> decodeAsync<T>(FutureOr<String> encodedJson,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeAsync(encodedJson,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  /// Sames as [decodeAsync] but from a [Uint8List].
  static FutureOr<T> decodeFromBytesAsync<T>(
      FutureOr<Uint8List> encodedJsonBytes,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider,
      EntityCache? entityCache,
      bool? autoResetEntityCache}) {
    var jsonDecoder =
        _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider, entityCache);

    return jsonDecoder.decodeFromBytesAsync(encodedJsonBytes,
        type: type, autoResetEntityCache: autoResetEntityCache);
  }

  static final JsonDecoder defaultDecoder = JsonDecoder(
      jsonValueDecoderProvider: _jsonValueDecoderProvider,
      jsomMapDecoderAsyncProvider: (type, map) =>
          _jsomMapDecoderAsyncProvider(type, null, null),
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
        jsonValueDecoderProvider: (t, v) =>
            _jsonValueDecoderProvider(t, v, entityHandlerProvider, entityCache),
        jsomMapDecoder: jsomMapDecoder,
        jsomMapDecoderAsyncProvider: (type, map) =>
            _jsomMapDecoderAsyncProvider(
                type, entityHandlerProvider, entityCache),
        iterableCaster: (v, t) => _iterableCaster(v, t, entityHandlerProvider),
        entityCache: entityCache,
        forceDuplicatedEntitiesAsID: true);
  }

  static JsonValueDecoder<O>? _jsonValueDecoderProvider<O>(
      Type type, Object? value,
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
      var entity = entityHandler?.createFromMap(value);
      if (entity != null) return entity as O;
    }

    return null;
  }

  static JsomMapDecoderAsync? _jsomMapDecoderAsyncProvider(Type type,
      EntityHandlerProvider? entityHandlerProvider, EntityCache? entityCache) {
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

  static String defaultFieldNameResolver(
      String field, Map<String, Object?> map) {
    if (map.containsKey(field)) {
      return field;
    }

    var fieldLC = field.toLowerCase();
    if (map.containsKey(fieldLC)) {
      return fieldLC;
    }

    var fieldSimple = StringUtils.toLowerCaseSimple(field);
    if (map.containsKey(fieldSimple)) {
      return fieldSimple;
    }

    for (var k in map.keys) {
      if (equalsIgnoreAsciiCase(fieldLC, k)) {
        return k;
      }

      if (equalsIgnoreAsciiCase(fieldSimple, k)) {
        return k;
      }
    }

    return field;
  }

  static Object? defaultFieldValueResolver(
      String field,
      Object? value,
      TypeReflection type,
      JsonDecoder jsonDecoder,
      EntityHandlerProvider? entityHandlerProvider) {
    if (type.isListEntity && value is Iterable) {
      return _iterableCaster(value, type, entityHandlerProvider);
    } else {
      return jsonDecoder.fromJson(value, type: type.type);
    }
  }

  static Object? _iterableCaster(Iterable value, TypeReflection type,
      EntityHandlerProvider? entityHandlerProvider) {
    if (entityHandlerProvider != null) {
      var entityType = type.isListEntityOrReference ? type.arguments0! : type;
      var entityHandler =
          entityHandlerProvider.getEntityHandler(type: entityType.type);

      if (entityHandler != null) {
        return entityHandler.castIterable(value, entityType.type);
      }
    }

    return null;
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
