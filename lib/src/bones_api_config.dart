import 'dart:async';
import 'dart:convert' as dart_convert;

import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

import 'bones_api_config_generic.dart'
    if (dart.library.io) 'bones_api_config_io.dart';
import 'bones_api_utils.dart';

typedef APIConfigProvider = FutureOr<APIConfig?> Function();

/// The API Configuration.
class APIConfig {
  final Map<String, dynamic> _properties = <String, dynamic>{};

  String? _source;

  APIConfig([Map<String, dynamic> properties = const <String, dynamic>{}]) {
    _properties.addAll(properties);
  }

  /// The source of this configuration.
  String? get source => _source;

  /// Returns `true` if the configuration [properties] is empty.
  bool get isEmpty => _properties.isEmpty;

  /// same as: ![isNotEmpty].
  bool get isNotEmpty => _properties.isNotEmpty;

  /// The number of the [properties] entries.
  int get length => _properties.length;

  /// Returns a unmodifiable [Map] of the configuration properties.
  Map<String, dynamic> get properties =>
      Map<String, dynamic>.unmodifiable(_properties);

  /// The [properties] keys.
  Iterable<String> get keys => _properties.keys;

  /// The [properties] entries.
  Iterable<MapEntry<String, dynamic>> get entries => _properties.entries;

  /// The [properties] values.
  Iterable<dynamic> get values => _properties.values;

  /// [properties] key getter.
  dynamic operator [](String key) => _properties[key];

  /// [properties] key setter.
  operator []=(String key, dynamic value) => _properties[key] = value;

  /// [properties] case insensitive key getter.
  dynamic getCaseInsensitive(String key) {
    if (_properties.containsKey(key)) {
      return _properties[key];
    }

    var keyLC = key.toLowerCase();

    for (var k in _properties.keys) {
      if (k.toLowerCase() == keyLC) {
        return _properties[k];
      }
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
  static APIConfig? fromSync(dynamic o, [dynamic def]) =>
      _fromImpl(o, allowAsync: false, def: def) as APIConfig?;

  /// Constructs an [APIConfig] instance from [o], returning [def] if [o] is invalid.
  /// (Async mode, allows async calls like URL resolution).
  static FutureOr<APIConfig?> fromAsync(dynamic o, [dynamic def]) =>
      _fromImpl(o, allowAsync: true, def: def);

  static FutureOr<APIConfig?> _fromImpl(dynamic o,
      {required bool allowAsync, Object? def}) {
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
  factory APIConfig.fromPropertiesEncoded(String properties) {
    var map = parsePropertiesEncoded(properties);
    return APIConfig(map);
  }

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
      return o.expand((e) => _toMapEntry(e)).toList();
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
  String toYAMLEncoded() => YAMLWriter().write(_properties);

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
