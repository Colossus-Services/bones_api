import 'dart:convert' as dart_convert;

import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

import 'bones_api_base.dart';
import 'bones_api_config_generic.dart'
    if (dart.library.io) 'bones_api_config_io.dart';
import 'bones_api_platform.dart';
import 'bones_api_utils_json.dart';

typedef APIConfigProvider = FutureOr<APIConfig?> Function();

/// The API Configuration.
class APIConfig {
  final Map<String, dynamic> _properties = <String, dynamic>{};

  String? _source;

  /// If `true` indicates development environment.
  late final bool development;

  /// If `true` indicates test environment.
  late final bool test;

  APIConfig([Map<String, dynamic> properties = const <String, dynamic>{}]) {
    BonesAPI.boot();
    _properties.addAll(properties);

    var dev = _properties['development'];
    development = TypeParser.parseBool(dev, false)!;

    var test = _properties['test'];
    this.test = TypeParser.parseBool(test, false)!;
  }

  /// The source of this configuration.
  String? get source => _source;

  /// The source parent path of this configuration.
  String? get sourceParentPath {
    var source = _source;
    if (source == null || source.isEmpty) return null;

    var idx = source.lastIndexOf(RegExp(r'[/\\]'));
    if (idx >= 0) {
      var parent = source.substring(0, idx);

      if (parent.startsWith(RegExp(r'^file:/'))) {
        var uri = Uri.tryParse(parent);
        if (uri != null) {
          parent = uri.toFilePath();
        }
      }

      return parent;
    }

    return null;
  }

  /// Returns `true` if the configuration [properties] is empty.
  bool get isEmpty => _properties.isEmpty;

  /// same as: ![isNotEmpty].
  bool get isNotEmpty => _properties.isNotEmpty;

  /// The number of the [properties] entries.
  int get length => _properties.length;

  /// Returns a unmodifiable [Map] of the configuration properties.
  Map<String, dynamic> get properties =>
      Map<String, dynamic>.unmodifiable(Map.fromEntries(entries));

  /// The [properties] keys.
  Iterable<String> get keys => _properties.keys;

  /// The [properties] entries.
  Iterable<MapEntry<String, dynamic>> get entries => _properties.entries
      .map((e) => MapEntry(e.key, _resolveValue(e.key, e.value, null)));

  /// The [properties] values.
  Iterable<dynamic> get values => entries.map((e) => e.value);

  /// [properties] key getter.
  dynamic operator [](String key) => _getImpl(key, null);

  /// [properties] key setter.
  operator []=(String key, dynamic value) => _properties[key] = value;

  /// [properties] key getter.
  dynamic get(String key, {Object? defaultValue, bool caseSensitive = false}) {
    return caseSensitive
        ? _getImpl(key, defaultValue)
        : getIgnoreCase(key, defaultValue: defaultValue);
  }

  dynamic _getImpl(String key, Object? defaultValue) =>
      _resolveValue(key, _properties[key], defaultValue);

  static final RegExp _regexpValueVariable = RegExp(r'%(\w+)%');

  dynamic _resolveValue(String key, Object? value, Object? defaultValue) {
    if (value == null) return defaultValue;

    if (value is String) {
      if (!value.contains('%')) {
        return value;
      }

      var valueResolved = value.replaceAllMapped(_regexpValueVariable, (m) {
        var k = m[1];
        var v =
            k != null ? _getVariable(k, !equalsIgnoreAsciiCase(k, key)) : m[0];
        return v ?? '';
      });

      return valueResolved;
    }

    return value;
  }

  String? _getVariable(String key, bool allowProperties) {
    if (allowProperties) {
      var val = _properties[key];
      if (val != null) {
        return _resolveValue(key, val, null);
      }
    }

    var val = APIPlatform.get().getProperty(key);
    if (val != null) {
      return _resolveValue(key, val, null);
    }

    return null;
  }

  /// [properties] case insensitive key getter.
  dynamic getIgnoreCase(String key, {Object? defaultValue}) {
    if (_properties.containsKey(key)) {
      return _getImpl(key, defaultValue);
    }

    var keyLC = key.toLowerCase();

    for (var k in _properties.keys) {
      if (k.toLowerCase() == keyLC) {
        return _getImpl(k, defaultValue);
      }
    }

    return null;
  }

  /// Returns the final value from a path of keys as [E].
  /// If not null, it attempts to parse the value into [E] or throws a [StateError].
  E? getPath<E>(String k0, [Object? k1, Object? k2, Object? k3, Object? k4]) {
    Object key = k0;
    Object? val = get(k0);
    if (val == null) return null;

    if (k1 != null) {
      key = k1;
      val = val is Map ? val[k1] : (k1 is int && val is List ? val[k1] : null);
      if (val == null) return null;
    }

    if (k2 != null) {
      key = k2;
      val = val is Map ? val[k2] : (k2 is int && val is List ? val[k2] : null);
      if (val == null) return null;
    }

    if (k3 != null) {
      key = k3;
      val = val is Map ? val[k3] : (k3 is int && val is List ? val[k3] : null);
      if (val == null) return null;
    }

    if (k4 != null) {
      key = k4;
      val = val is Map ? val[k4] : (k4 is int && val is List ? val[k4] : null);
      if (val == null) return null;
    }

    val = _resolveValue(key.toString(), val, null);

    if (val is! E) {
      var val2 = _parseValue<E>(val);
      if (val2 != null) return val2;

      var keyPath = [k0, k1, k2, k3, k4].nonNulls.join('/');
      throw StateError("Can't return key `$keyPath` as `$E`: $val");
    }

    return val;
  }

  /// Alias to [get] returning a [Map].
  Map<String, V>? getAsMap<V>(String key,
      {Map<String, V>? defaultValue, bool caseSensitive = false}) {
    var m = get(key, defaultValue: defaultValue, caseSensitive: caseSensitive);
    if (m == null) return null;
    if (m is! Map) {
      throw StateError("Can't return key `$key` as `Map`: $m");
    }
    return m.cast<String, V>();
  }

  /// Alias to [get] returning a [List].
  List<E>? getAsList<E>(String key,
      {List<E>? defaultValue, bool caseSensitive = false}) {
    var l = get(key, defaultValue: defaultValue, caseSensitive: caseSensitive);
    if (l == null) return null;
    if (l is! List) {
      throw StateError("Can't return key `$key` as `List`: $l");
    }
    return l is List<E> ? l : l.cast<E>();
  }

  /// Alias to [get] returning as [T].
  /// If not null, it attempts to parse the value into [T] or throws a [StateError].
  T? getAs<T>(String key, {T? defaultValue, bool caseSensitive = false}) {
    var val =
        get(key, defaultValue: defaultValue, caseSensitive: caseSensitive);
    if (val == null) return null;
    if (val is! T) {
      var val2 = _parseValue<T>(val);
      if (val2 != null) return val2;

      throw StateError("Can't return key `$key` as `$T`: $val");
    }
    return val;
  }

  T? _parseValue<T>(Object? val) {
    if (val == null) return null;

    if (T != Object && T != dynamic) {
      var parser = TypeParser.parserFor<T>();
      if (parser != null) {
        return parser(val);
      }
    }

    return null;
  }

  /// Apply the values in the `properties` entry to the [APIPlatform] properties.
  Map<String, String>? applyProperties() {
    var properties = get('properties');
    if (properties is Map) {
      var apiPlatform = APIPlatform.get();

      var props = <String, String>{};

      for (var e in properties.entries) {
        var k = e.key?.toString();
        var v = e.value;

        if (k == null || (v is! String && v is! num && v is! bool)) continue;

        var vStr = v.toString();
        apiPlatform.setProperty(k, vStr);

        props[k] = vStr;
      }

      return props;
    }

    return null;
  }

  /// Constructs an [APIConfig] instance from [o], returning [def] if [o] is invalid.
  /// Calls [fromSync].
  static APIConfig? from(dynamic o, [dynamic def]) {
    return fromSync(o, def);
  }

  /// Constructs an [APIConfig] instance from [o], returning [def] if [o] is invalid.
  /// (Sync mode).
  static APIConfig? fromSync(dynamic o, [dynamic def]) {
    // ignore: discarded_futures
    var ret = _fromImpl(o, allowAsync: false, def: def);
    if (ret is Future) return null;
    return ret;
  }

  /// Constructs an [APIConfig] instance from [o], returning [def] if [o] is invalid.
  /// (Async mode, allows async calls like URL resolution).
  static FutureOr<APIConfig?> fromAsync(dynamic o, [dynamic def]) =>
      _fromImpl(o, allowAsync: true, def: def);

  static FutureOr<APIConfig?> _fromImpl(dynamic o,
      {required bool allowAsync, Object? def}) {
    BonesAPI.boot();

    if (o == null) {
      return def == null ? null : _fromImpl(def, allowAsync: allowAsync);
    }

    if (o is APIConfig) {
      return o;
    }

    if (o is APIConfigProvider) {
      var ret = o();
      if (ret is Future) {
        if (!allowAsync) {
          throw StateError(
              "Async not allowed. APIConfigProvider returned a Future: $ret");
        }
        return ret;
      } else {
        return ret;
      }
    }

    if (o is Map || o is Iterable) {
      return APIConfig.fromCollection(o, def);
    }

    if (o is String) {
      var uri = resolveStringUri(o);

      if (uri != null) {
        return APIConfig.fromUri(uri, allowAsync: allowAsync) ??
            _fromImpl(def, allowAsync: allowAsync);
      } else {
        return APIConfig.fromContent(o) ??
            _fromImpl(def, allowAsync: allowAsync);
      }
    }

    return def == null ? null : _fromImpl(def, allowAsync: allowAsync);
  }

  /// Constructs an [APIConfig] instance from a collection [o], or return [def].
  static APIConfig? fromCollection(Object? o, [dynamic def]) {
    if (o == null) {
      return APIConfig.fromSync(def);
    }

    if (o is Map<String, dynamic>) {
      return APIConfig(o);
    }

    if (o is Map) {
      return APIConfig(o.map((key, value) => MapEntry('$key', value)));
    } else if (o is Iterable) {
      var map = Map<String, dynamic>.fromEntries(o.expand(_toMapEntry));
      return APIConfig(map);
    }

    return APIConfig.fromSync(def);
  }

  /// Constructs an [APIConfig] instance from an [uri
  /// If [allowAsync] ir `true` allows async resolution, like URL download.
  static FutureOr<APIConfig?> fromUri(Uri uri, {bool allowAsync = true}) =>
      loadAPIConfigFromUri(uri, allowAsync: allowAsync);

  static final RegExp _regExpSpaces = RegExp(r'\s');
  static final RegExp _regexpStartWithWord = RegExp(r'^\w');

  /// Tries to resolves a [String] [s] to an [Uri].
  static Uri? resolveStringUri(String s) {
    if (!_regExpSpaces.hasMatch(s)) {
      if (s.startsWith('http://') ||
          s.startsWith('https://') ||
          s.startsWith('file:/')) {
        try {
          return Uri.parse(s);
        } catch (_) {}
      }

      var u = Uri.base;

      String? path;

      if (s.startsWith('/')) {
        path = s;
      } else if (s.startsWith('./')) {
        var basePath = u.path;
        if (!basePath.endsWith('/')) {
          basePath += '/';
        }
        path = basePath + s.substring(2);
      } else if (_regexpStartWithWord.hasMatch(s)) {
        var basePath = u.path;
        if (!basePath.endsWith('/')) {
          basePath += '/';
        }
        path = u.path + s;
      }

      if (path != null) {
        return Uri(
            scheme: u.scheme,
            userInfo: u.userInfo,
            host: u.host,
            port: u.port,
            path: path,
            query: u.query);
      }
    }

    return null;
  }

  /// Tries to resolve a file extension from [path].
  static String? resolveFileExtension(String path) {
    path = path.trim();
    if (path.isEmpty) {
      return null;
    }

    var idx = path.lastIndexOf('.');
    if (idx < 0) {
      return null;
    }

    var ext = path.substring(idx + 1);
    return ext.isEmpty ? null : ext;
  }

  /// Tries to construct an [APIConfig] from [content].
  /// - If [type] is defined (`JSON`, `YAML`or `properties`), forces decoding
  /// of the specified type format.
  /// - If [autoIdentify] is `true` it tries to detect the format to decode.
  static APIConfig? fromContent(String content,
      {String? type, bool autoIdentify = true, String? source}) {
    type ??= '';
    type = type.toLowerCase().trim();

    if (type == '*') {
      autoIdentify = true;
    }

    if (type == 'json' || type == 'js') {
      try {
        return APIConfig.fromJsonEncoded(content).._source = source;
      } catch (_) {
        throw FormatException('Error parsing JSON!');
      }
    }

    if (type == 'yaml' || type == 'yml') {
      try {
        return APIConfig.fromYAML(content).._source = source;
      } catch (_) {
        throw FormatException('Error parsing YAML!');
      }
    }

    if (type == 'properties' || type == 'prop') {
      try {
        return APIConfig.fromPropertiesEncoded(content).._source = source;
      } catch (_) {
        throw FormatException('Error parsing properties!');
      }
    }

    if (autoIdentify) {
      try {
        return APIConfig.fromJsonEncoded(content).._source = source;
      } catch (_) {}

      try {
        return APIConfig.fromYAML(content).._source = source;
      } catch (_) {}

      try {
        return APIConfig.fromPropertiesEncoded(content).._source = source;
      } catch (_) {}
    }

    return null;
  }

  /// Constructs an [APIConfig] from a [yamlEncoded].
  factory APIConfig.fromYAML(String yamlEncoded) {
    var yaml = loadYaml(yamlEncoded);

    Object? o = yaml;
    if (yaml is Map) {
      o = Map<String, dynamic>.fromEntries(
          yaml.entries.expand(_toMapEntry).toList());
    }

    return APIConfig.fromCollection(o)!;
  }

  /// Constructs an [APIConfig] from [json].
  APIConfig.fromJson(Map<String, dynamic> json) : this(json);

  /// Constructs an [APIConfig] from [jsonEncoded].
  APIConfig.fromJsonEncoded(String jsonEncoded)
      : this(dart_convert.json.decode(jsonEncoded));

  /// Constructs an [APIConfig] from [properties].
  APIConfig.fromPropertiesEncoded(String properties)
      : this(parsePropertiesEncoded(properties));

  static Map<String, dynamic> parsePropertiesEncoded(String properties) {
    var entries = parsePropertiesEncodedEntries(properties);
    var map = Map<String, dynamic>.fromEntries(entries);
    return map;
  }

  static final RegExp _regexpLineBreak = RegExp(r'[\r\n]+');
  static final RegExp _regexpKeyLine = RegExp(r'^\s*\w+\s*[:=]');
  static final RegExp _regexpKeyDelimiter = RegExp(r'[:=]');

  static List<MapEntry<String, dynamic>> parsePropertiesEncodedEntries(
      String properties) {
    var lines = properties.split(_regexpLineBreak);

    var l = lines.expand((l) {
      if (_regexpKeyLine.hasMatch(l)) {
        var idx = l.indexOf(_regexpKeyDelimiter);
        var k = l.substring(0, idx).trim();
        var v = l.substring(idx + 1);
        var val = _parseJsonValue(v);
        return <MapEntry<String, dynamic>>[MapEntry(k, val)];
      } else {
        return <MapEntry<String, dynamic>>[];
      }
    }).toList();

    return l;
  }

  static dynamic _parseJsonValue(String v) {
    try {
      return dart_convert.json.decode(v);
    } catch (e) {
      return v.trim();
    }
  }

  static List<MapEntry<String, dynamic>> _toMapEntry(dynamic o) {
    if (o == null) {
      return <MapEntry<String, dynamic>>[];
    } else if (o is MapEntry) {
      return [MapEntry<String, dynamic>('${o.key}', _toMapValue(o.value))];
    } else if (o is Map) {
      return o.entries
          .map((e) =>
              MapEntry<String, dynamic>('${e.key}', _toMapValue(e.value)))
          .toList();
    } else if (o is Iterable) {
      return o.expand(_toMapEntry).toList();
    } else if (o is String) {
      return APIConfig.parsePropertiesEncodedEntries(o);
    } else {
      throw StateError("Invalid: $o");
    }
  }

  static dynamic _toMapValue(dynamic o) {
    if (o == null) {
      return null;
    }

    if (o is String || o is num || o is bool) {
      return o;
    }

    if (o is Map) {
      return Map<String, dynamic>.fromEntries(o.entries.expand(_toMapEntry));
    } else if (o is Iterable) {
      return o.map(_toMapValue).toList();
    }

    return o;
  }

  /// Converts this configuration [properties] to a JSON [Map].
  Map<String, dynamic> toJson({bool Function(String key)? maskField}) =>
      Json.toJson(_properties, maskField: maskField);

  /// Converts this configuration [properties] to an encoded JSON.
  String toJsonEncoded(
          {bool Function(String key)? maskField, bool pretty = true}) =>
      Json.encode(_properties, pretty: pretty, maskField: maskField);

  /// Converts this configuration [properties] to an encoded YAML.
  String toYAMLEncoded() => YamlWriter().write(_properties);

  /// Converts this configuration [properties] to a Java properties format.
  String toPropertiesEncoded() {
    var s = StringBuffer();

    for (var e in _properties.entries) {
      s.write(e.key);
      s.write('=');
      s.write(dart_convert.json.encode(e.value));
      s.write('\n');
    }

    return s.toString();
  }

  @override
  String toString() {
    var json = toJsonEncoded(maskField: _maskField);

    var src = '';
    if (_source?.isNotEmpty ?? false) {
      src = '[$_source]';
    }

    return 'APIConfig$src$json';
  }

  bool _maskField(String key) =>
      Json.standardJsonMaskField(key, extraKeys: const <String>{'token'});
}
