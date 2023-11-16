import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';
import 'bones_api_utils_json.dart';
import 'bones_api_types.dart';

/// Helper class to generate HTML documents.
///
/// This can be useful for creating API routes
/// using old-school techniques (HTML+Forms).
class HTMLDocument {
  /// The title of the HTML.
  final String title;

  /// The style of the HTML.
  final String styles;

  final String? _bodyStyles;

  /// The optional body style `color`.
  final String? bodyColor;

  /// The optional body style `background-color`.
  final String? bodyBackgroundColor;

  /// The optional body style `font-family`.
  final String? bodyFontFamily;

  /// The optional body style `padding`.
  final String? bodyPadding;

  /// The optional HTML top content.
  /// See [resolve]
  Object? top;

  /// The HTML content.
  /// See [resolve]
  Object? content;

  /// The optional HTML footer content.
  /// See [resolve]
  Object? footer;

  HTMLDocument(
      {String title = '',
      String styles = '',
      String bodyStyles = '',
      String? bodyColor,
      String? bodyBackgroundColor,
      String? bodyFontFamily,
      String? bodyPadding,
      this.top,
      this.content,
      this.footer})
      : title = title.trim(),
        styles = styles.trim(),
        _bodyStyles = bodyStyles.trim(),
        bodyColor = bodyColor?.trim(),
        bodyBackgroundColor = bodyBackgroundColor?.trim(),
        bodyFontFamily = bodyFontFamily?.trim(),
        bodyPadding = bodyPadding?.trim();

  factory HTMLDocument.darkTheme(
      {String title = '',
      String? styles,
      Object? top,
      Object? content,
      Object? footer}) {
    return HTMLDocument(
      title: title,
      styles: styles ?? _stylesDarkTheme(),
      top: top,
      content: content,
      footer: footer,
      bodyColor: '#a9b7c5',
      bodyBackgroundColor: '#1e1f22',
      bodyFontFamily: 'Arial, Helvetica, sans-serif',
      bodyPadding: '10px',
    );
  }

  static String _stylesDarkTheme() {
    return '''
    input, textarea, select {
      border-radius: 8px;
      background-color: #a9b7c5;
      color: #333333;
    }
    hr {
      border: 1px dotted #aab7c5;
    }
    h1, h2, h3 {
      text-align: center;
      margin: 2px;
    }
    a {
      color: #b4d5fa;
      text-decoration: none;
    }
    button {
      background-color: #5b5e67;
      color: #d5ddf4;
      border-radius: 8px;
      padding: 8px 12px;
      border: none;
      font-size: 120%;
      box-shadow: 0 8px 16px 0 rgba(0,0,0,0.2), 0 6px 20px 0 rgba(0,0,0,0.19);
    }
    button:hover {
      background-color: #6e717e;
      color: #ffffff;
    }
    pre {
      text-align: left;
    }
    table {
      border-spacing: 6px;
      background-color: rgba(255, 255, 255, 0.04);
    }
    th, td {
      background-color: rgba(0,0,0, 0.30);
      padding: 4px;
    }
    thead tr {
      background-color: rgba(0,0,0, 0.60);
    }
    .center {
      margin-left: auto;
      margin-right: auto;
    }
    .note {
      font-size: 90%;
      font-style: italic;
      opacity: 60%;
    }
    ''';
  }

  String get bodyStyles {
    var styles = (_bodyStyles != null && _bodyStyles.trim().isNotEmpty
            ? _bodyStyles
            : '')
        .split(RegExp(r'\s*;\s*'));

    final bodyColor = this.bodyColor;
    if (bodyColor != null && bodyColor.isNotEmpty) {
      styles.add('color: $bodyColor');
    }

    final bodyBackgroundColor = this.bodyBackgroundColor;
    if (bodyBackgroundColor != null && bodyBackgroundColor.isNotEmpty) {
      styles.add('background-color: $bodyBackgroundColor');
    }

    final bodyFontFamily = this.bodyFontFamily;
    if (bodyFontFamily != null && bodyFontFamily.isNotEmpty) {
      styles.add('font-family: $bodyFontFamily');
    }

    final bodyPadding = this.bodyPadding;
    if (bodyPadding != null && bodyPadding.isNotEmpty) {
      styles.add('padding: $bodyPadding');
    }

    var s = styles.where((e) => e.trim().isNotEmpty).join(' ; ').trim();
    return s.isNotEmpty ? '$s;' : '';
  }

  /// Builds the HTML string.
  String build() {
    final html = StringBuffer();

    html.write('<html>\n');
    html.write('<head>\n');

    if (title.isNotEmpty) {
      html.write('<title>$title</title>\n');
    }

    if (styles.isNotEmpty) {
      html.write('<style>\n$styles\n</style>\n');
    }

    html.write('</head>\n');

    var bodyStyles = this.bodyStyles;

    html.write('<body'
        '${bodyStyles.isNotEmpty ? ' style="$bodyStyles"' : ''}'
        '>\n');

    _writeObject(html, top);
    _writeObject(html, content);
    _writeObject(html, footer);

    html.write('</body>\n');
    html.write('</html>\n');

    return html.toString();
  }

  /// Resolves [o] to an HTML string.
  /// Accepts:
  /// - [String].
  /// - [StringBuffer].
  /// - [Function].
  /// - [MapEntry]:
  ///   - If is a `MapEntry<String, TypeInfo>` or `MapEntry<String, Type>` will be converted to an input.
  /// - [Iterable]: maps elements calling [resolve].
  /// - [Map]: encodes to JSON calling [Json.encode].
  static String resolve(Object? o) {
    if (o == null) return '';

    if (o is Function()) {
      o = o();
    }

    if (o is MapEntry) {
      if (o is MapEntry<String, TypeInfo>) {
        o = HTMLInput.from(o);
      } else if (o is MapEntry<String, Type>) {
        o = HTMLInput.from(o);
      } else {
        var k = resolve(o.key);
        var v = resolve(o.value);
        return '$k: $v';
      }
    }

    if (o is HTMLInput) {
      return o.build();
    }

    if (o is EntityReference) {
      return resolve(o.entityOrID);
    } else if (o is EntityReferenceList) {
      return resolve(o.entitiesOrIDs);
    }

    if (o is Iterable) {
      return o.map(resolve).join();
    }

    if (o is Map) {
      var jsonEnc = Json.encode(o, pretty: true);
      return '<pre>$jsonEnc</pre>';
    }

    if (o is StringBuffer) return o.toString();

    if (o is String) return o;

    var s = o.toString();
    return s;
  }

  void _writeObject(StringBuffer html, Object? o) {
    if (o != null) {
      var s = resolve(o);
      html.write('$s\n');
    }
  }
}

/// An HTML input used by [HTMLDocument].
class HTMLInput {
  /// The name of the input.
  final String name;

  /// The type of the input.
  final TypeInfo type;

  /// The optional value of the input.
  final Object? value;

  HTMLInput(this.name, this.type, {this.value});

  factory HTMLInput.from(MapEntry<String, Object> entry) {
    var name = entry.key;
    var type = entry.value;

    if (type is TypeInfo) {
      return HTMLInput(name, type);
    } else if (type is Type) {
      return HTMLInput(name, TypeInfo.fromType(type));
    } else {
      return HTMLInput(name, TypeInfo.from(type));
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HTMLInput &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => name.hashCode ^ type.hashCode ^ value.hashCode;

  @override
  String toString() {
    return 'HTMLInput{name: $name, type: $type, value: $value}';
  }

  String build() => _resolveInput(name, type, value);

  static String _resolveInput(String name, TypeInfo<dynamic> type,
      [Object? value]) {
    var valStr = value != null ? '$value' : '';
    var valAttr = valStr.isNotEmpty ? ' value="$valStr"' : '';

    if (type.isString) {
      return '<textarea id="field_$name" name="$name" rows="1" cols="30">$valStr</textarea>';
    } else if (type.isInt || type.isBigInt || type.type == DynamicInt) {
      return '<input id="field_$name" name="$name" type="number" step="1"$valAttr>';
    } else if (type.isDouble || type.type == Decimal) {
      return '<input id="field_$name" name="$name" type="number" step="any"$valAttr>';
    } else if (type.isBool) {
      var checked = parseBool(value) ?? false;
      return '<input id="field_$name" name="$name" type="checkbox"${checked ? ' checked' : ''}>';
    } else if (type.isDateTime) {
      var d = TypeParser.parseDateTime(value);
      String? dStr;
      if (d != null) {
        dStr = d.toIso8601String();
        var idx = dStr.lastIndexOf(':');
        assert(idx > 4);
        dStr = dStr.substring(0, idx);
      }
      valAttr = d != null ? ' value="$dStr"' : '';
      return '<input id="field_$name" name="$name" type="datetime-local"$valAttr>';
    } else if (type.type == Time) {
      var d = Time.from(value);
      valAttr = d != null ? ' value="${d.toString()}"' : '';
      return '<input id="field_$name" name="$name" type="time" step="1"$valAttr>';
    } else if (type.isEntityReferenceType) {
      var idAsInt = false;
      Object? id;

      var t = type.argumentType(0);
      if (t != null) {
        var entityHandler =
            ReflectionFactory().getRegisterEntityHandler(t.type);

        if (entityHandler != null) {
          var idType = entityHandler.idType();
          idAsInt = idType == int || idType == BigInt;
          id = entityHandler.resolveID(value);
        }
      }

      if (value is EntityReference) {
        id = value.id;
      }

      valAttr = id != null ? ' value="$id"' : '';

      if (idAsInt) {
        return '<input id="field_$name" name="$name" type="number" step="1"$valAttr>';
      } else {
        return '<input id="field_$name" name="$name" type="text" size="34"$valAttr>';
      }
    } else if (type.isEntityReferenceListType) {
      var ids = _resolveListIDs(value, type.arguments0);

      valStr = ids != null && ids.isNotEmpty ? ids.join(', ') : '';

      return '<textarea id="field_$name" name="$name" rows="4" cols="25">$valStr</textarea>';
    } else if (type.isListEntity) {
      var ids = _resolveListIDs(value, type.arguments0);

      valStr = ids != null && ids.isNotEmpty ? ids.join(', ') : '';

      return '<textarea id="field_$name" name="$name" rows="4" cols="25">$valStr</textarea>';
    } else {
      final reflectionFactory = ReflectionFactory();

      var enumReflection =
          reflectionFactory.getRegisterEnumReflection(type.type);

      if (enumReflection != null) {
        var html = StringBuffer();
        html.write('<select id="field_$name" name="$name">\n');

        valStr = value != null
            ? (enumReflection.name(value) ?? value.toString().split('.').last)
            : '';

        for (var e in enumReflection.values) {
          var enumName = enumReflection.name(e) ?? '';

          var selected =
              equalsIgnoreAsciiCase(enumName, valStr) ? ' selected' : '';

          html.write('<option value="$enumName"$selected>$enumName</option>\n');
        }

        html.write('</select>');
        return html.toString();
      }

      var entityHandler = reflectionFactory.getRegisterEntityHandler(type.type);

      if (entityHandler != null) {
        var id = entityHandler.resolveID(value);
        valStr = id != null ? '$id' : '';

        return '<textarea id="field_$name" name="$name" rows="4" cols="8">$valStr</textarea>';
      }

      return '<textarea id="field_$name" name="$name" rows="3" cols="40">$valStr</textarea>';
    }
  }

  static List? _resolveListIDs(Object? value, TypeInfo? type) {
    if (value == null) {
      return null;
    } else if (value is EntityReferenceList) {
      return value.ids;
    } else if (value is Iterable) {
      return value
          .expand((e) => _resolveListIDs(e, type) ?? [])
          .whereNotNull()
          .toList();
    } else {
      if (type != null) {
        var entityHandler =
            ReflectionFactory().getRegisterEntityHandler(type.type);

        var ids = entityHandler?.resolveIDs(value);
        if (ids != null) return ids;
      }

      return ['$value'];
    }
  }
}
