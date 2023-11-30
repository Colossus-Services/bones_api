import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition_parser.dart';
import 'bones_api_entity.dart';
import 'bones_api_extension.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_collections.dart';
import 'bones_api_utils_json.dart';

abstract class ConditionElement {
  bool _resolved = false;

  bool get resolved => _resolved;

  void _markResolved([bool resolved = true, Condition? parent]) {
    _resolved = resolved;

    if (parent != null) {
      _parent = parent;
    }
  }

  Condition? _parent;

  Condition? get parent => _parent;

  /// Returns `true` if this conditions performs an "inner join" of related tables/repositories.
  /// Returns `false` if an `outer join` is needed to not influence other conditions
  /// in the query (usually when a condition is inside an `OR` group).
  ///
  /// - Uses [parent.isInner] to resolve it.
  bool get isInner => parent?.isInner ?? true;

  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters});

  late List<ConditionParameter> _parameters;

  List<ConditionParameter> get parameters => _parameters;

  static final List<ConditionParameter> _emptyParameters =
      List<ConditionParameter>.unmodifiable([]);

  void _setParameters(Iterable<ConditionParameter> parameters) {
    _parameters = parameters.isEmpty
        ? _emptyParameters
        : List<ConditionParameter>.unmodifiable(parameters);
  }
}

class ConditionParameter extends ConditionElement {
  final int? index;
  final String? key;

  int? contextPosition;
  String? contextKey;

  ConditionParameter()
      : index = null,
        key = null;

  ConditionParameter.index(this.index) : key = null;

  ConditionParameter.key(this.key) : index = null;

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    if (isPositional) {
      var positionalParametersSize =
          parameters.where((p) => p.isPositional).length;
      contextPosition = positionalParametersSize;
    }

    if (parent is KeyCondition) {
      contextKey = parent.keys.whereType<ConditionKeyField>().last.name;
    }

    parameters.add(this);

    parameters = [this];

    _markResolved();
  }

  bool get isPositional {
    if (hasKey) return false;
    var index = this.index;
    return index == null || index < 0;
  }

  bool get hasIndex => index != null;

  bool get hasKey => key != null;

  Object? getValue(
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Map<String, Object?>? encodingParameters}) {
    if (parameters != null) {
      if (parameters is! Map && parameters is! Iterable) {
        var obj = parameters as dynamic;
        try {
          var json = Json.toJson(obj);
          parameters = json;
        } catch (_) {}
      }

      if (parameters is Map) {
        namedParameters ??= parameters is Map<String, Object?>
            ? parameters
            : parameters.map<String, Object?>(
                (key, value) => MapEntry<String, Object?>('$key', value));
      } else if (parameters is Iterable) {
        positionalParameters ??= parameters is List
            ? parameters
            : parameters.toList(growable: false);
      }
    }

    var index = this.index;
    if (index == null || index < 0) {
      index = contextPosition;
    }

    if (index != null) {
      if (positionalParameters != null) {
        return index < positionalParameters.length
            ? positionalParameters[index]
            : null;
      }

      if (namedParameters != null && index < namedParameters.length) {
        var key = namedParameters.keys.elementAt(index);
        return namedParameters[key];
      }

      return null;
    }

    var key = this.key;
    if (key == null || key.isEmpty) {
      key = contextKey;
    }

    if (key != null) {
      return namedParameters?[key] ?? encodingParameters?[key];
    }

    return null;
  }

  bool matches(Object? value,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        : value;

    if (myValue is Iterable) {
      if (otherValue is Iterable) {
        var equals = isEqualsIterableDeep(myValue, otherValue,
            valueEquality: (a, b) => EntityHandler.equalsValuesBasic(a, b,
                entityHandler: entityHandler));
        return equals;
      } else {
        var contains = myValue
            .where((v) => EntityHandler.equalsValuesBasic(v, otherValue,
                entityHandler: entityHandler))
            .isNotEmpty;
        return contains;
      }
    } else if (otherValue is Iterable) {
      var contains = otherValue
          .where((v) => EntityHandler.equalsValuesBasic(v, myValue,
              entityHandler: entityHandler))
          .isNotEmpty;
      return contains;
    }

    return EntityHandler.equalsValuesBasic(myValue, otherValue,
        entityHandler: entityHandler);
  }

  bool greaterThan(Object? value,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        : value;

    return EntityHandler.graterThanValue(myValue, otherValue,
        entityHandler: entityHandler);
  }

  bool greaterThanOrEqual(Object? value,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        : value;

    return EntityHandler.graterThanOrEqualValue(myValue, otherValue,
        entityHandler: entityHandler);
  }

  bool lessThan(Object? value,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        : value;

    return EntityHandler.lessThanValue(myValue, otherValue,
        entityHandler: entityHandler);
  }

  bool lessThanOrEqual(Object? value,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        : value;

    return EntityHandler.lessThanOrEqualValue(myValue, otherValue,
        entityHandler: entityHandler);
  }

  bool matchesIn(List values,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    var myValue = getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    if (myValue is List) {
      for (var v1 in myValue) {
        for (var v2 in values) {
          var otherValue = v2 is ConditionParameter
              ? v2.getValue(
                  parameters: parameters,
                  positionalParameters: positionalParameters,
                  namedParameters: namedParameters)
              : v2;

          var match = EntityHandler.equalsValuesBasic(v1, otherValue,
              entityHandler: entityHandler);
          if (match) return true;
        }
      }

      return false;
    } else {
      for (var v2 in values) {
        var otherValue = v2 is ConditionParameter
            ? v2.getValue(
                parameters: parameters,
                positionalParameters: positionalParameters,
                namedParameters: namedParameters)
            : v2;

        var match = EntityHandler.equalsValuesBasic(myValue, otherValue,
            entityHandler: entityHandler);
        if (match) return true;
      }

      return false;
    }
  }

  @override
  String toString() {
    if (hasKey) {
      return key!.isNotEmpty ? '?:$key' : '?:';
    } else if (hasIndex) {
      return index! >= 0 ? '?#$index' : '?#';
    } else {
      return '?';
    }
  }

  Map<String, dynamic> toJson() {
    if (hasKey) {
      return {'ConditionParameter': ':$key'};
    } else if (hasIndex) {
      return {'ConditionParameter': '#$index'};
    } else {
      return {'ConditionParameter': '?'};
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConditionParameter &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          key == other.key &&
          contextPosition == other.contextPosition;

  @override
  int get hashCode =>
      (index?.hashCode ?? 0) ^
      (key?.hashCode ?? 0) ^
      (contextPosition?.hashCode ?? 0);
}

abstract class EntityMatcher<O> {
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});

  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});
}

abstract class Condition<O> extends ConditionElement
    with EntityFieldAccessor<O>
    implements EntityMatcher<O> {
  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});

  Condition._();

  static final ConditionParser _conditionParser = ConditionParser();

  factory Condition.parse(String condition) {
    if (condition.isEmpty) throw FormatException('Empty condition');

    return _conditionParser.parse(condition).cast<O>();
  }

  static final RegExp _conditionParameterRegExp = RegExp(
      r'\{\s*"ConditionParameter":\s*"(?:(#(?:-?\d+)?)|(:\w*)|\?)"\s*\}');

  static String encodeConditionValue(dynamic o) {
    var s = Json.encode(o, toEncodable: toJsonEncodable);

    s = s.replaceAllMapped(_conditionParameterRegExp, (m) {
      var groupIdx = m.group(1);
      if (groupIdx != null) {
        var idxStr = groupIdx.substring(1);
        var idx = idxStr.isNotEmpty ? int.parse(idxStr) : -1;
        return idx >= 0 ? '?#$idx' : '?#';
      }

      var groupKey = m.group(2);
      if (groupKey != null) {
        var key = groupKey.substring(1);
        return groupKey.isNotEmpty ? '?:$key' : '?:';
      }

      return '?';
    });

    return s;
  }

  static Object? toJsonEncodable(dynamic o) {
    if (o == null) {
      return o;
    }

    if (o is ConditionParameter) {
      return o.toJson();
    } else {
      return o;
    }
  }

  bool greaterThanConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      TypeInfo? keyType,
      EntityHandler? keyEntityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.greaterThan(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else if (value2 is ConditionParameter) {
      return value2.lessThan(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else {
      var match = EntityHandler.graterThanValue(value1, value2,
          entityHandler: keyEntityHandler);
      return match;
    }
  }

  bool greaterThanOrEqualConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      TypeInfo? keyType,
      EntityHandler? keyEntityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.greaterThanOrEqual(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else if (value2 is ConditionParameter) {
      return value2.lessThanOrEqual(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else {
      var match = EntityHandler.graterThanOrEqualValue(value1, value2,
          entityHandler: keyEntityHandler);
      return match;
    }
  }

  bool lessThanConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      TypeInfo? keyType,
      EntityHandler? keyEntityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.lessThan(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else if (value2 is ConditionParameter) {
      return value2.greaterThan(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else {
      var match = EntityHandler.lessThanValue(value1, value2,
          entityHandler: keyEntityHandler);
      return match;
    }
  }

  bool lessThanOrEqualConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      TypeInfo? keyType,
      EntityHandler? keyEntityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.lessThanOrEqual(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else if (value2 is ConditionParameter) {
      return value2.greaterThanOrEqual(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else {
      var match = EntityHandler.lessThanOrEqualValue(value1, value2,
          entityHandler: keyEntityHandler);
      return match;
    }
  }

  bool equalsConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      TypeInfo? keyType,
      EntityHandler? keyEntityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.matches(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else if (value2 is ConditionParameter) {
      return value2.matches(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: keyEntityHandler);
    } else {
      var match = EntityHandler.equalsValuesBasic(value1, value2,
          entityHandler: keyEntityHandler);
      return match;
    }
  }

  bool inConditionValues(Object? value1, List value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      EntityHandler? entityHandler}) {
    if (value1 is ConditionParameter) {
      return value1.matchesIn(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          entityHandler: entityHandler);
    } else if (value1 is List) {
      for (var v2 in value2) {
        if (v2 is ConditionParameter) {
          var match = v2.matchesIn(value1,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
              entityHandler: entityHandler);
          if (match) return true;
        } else {
          for (var v1 in value1) {
            var match = EntityHandler.equalsValuesBasic(v1, v2,
                entityHandler: entityHandler);
            if (match) return true;
          }
        }
      }

      return false;
    } else {
      for (var v2 in value2) {
        if (v2 is ConditionParameter) {
          var match = v2.matches(value1,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
              entityHandler: entityHandler);
          if (match) return true;
        } else {
          var match = EntityHandler.equalsValuesBasic(value1, v2,
              entityHandler: entityHandler);
          if (match) return true;
        }
      }

      return false;
    }
  }

  Condition<T> cast<T>();

  String encode();

  @override
  String toString() => encode();
}

abstract class GroupCondition<O> extends Condition<O> {
  final List<Condition> conditions;

  GroupCondition(Iterable<Condition> conditions)
      : conditions =
            conditions is List<Condition> ? conditions : conditions.toList(),
        super._() {
    for (var c in conditions) {
      c._parent = this;
    }
  }

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    var parametersSize0 = parameters.length;

    for (var c in conditions) {
      c.resolve(parent: this, parameters: parameters);
    }

    _setParameters(parameters.sublist(parametersSize0));

    _markResolved();
  }
}

class GroupConditionAND<O> extends GroupCondition<O> {
  GroupConditionAND(super.conditions);

  @override
  GroupConditionAND<T> cast<T>() {
    if (this is GroupConditionAND<T>) {
      return this as GroupConditionAND<T>;
    }
    return GroupConditionAND<T>(conditions.map((e) => e.cast<T>()).toList())
      .._markResolved(resolved, _parent);
  }

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntity(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      if (!matches) return false;
    }

    return true;
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntityMap(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      if (!matches) return false;
    }

    return true;
  }

  @override
  String encode() => '( ${conditions.join(' && ')} )';
}

class GroupConditionOR<O> extends GroupCondition<O> {
  GroupConditionOR(super.conditions);

  @override
  bool get isInner => false;

  @override
  GroupConditionOR<T> cast<T>() {
    if (this is GroupConditionOR<T>) {
      return this as GroupConditionOR<T>;
    }
    return GroupConditionOR<T>(conditions.map((e) => e.cast<T>()).toList())
      .._markResolved(resolved, _parent);
  }

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntity(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      if (matches) return true;
    }

    return false;
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntityMap(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      if (matches) return true;
    }

    return false;
  }

  @override
  String encode() => '( ${conditions.join(' || ')} )';
}

class ConditionANY<O> extends Condition<O> {
  ConditionANY() : super._();

  @override
  ConditionANY<T> cast<T>() =>
      this is ConditionANY<T> ? this as ConditionANY<T> : ConditionANY<T>()
        .._markResolved(resolved, _parent);

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    _markResolved();
  }

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return true;
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return true;
  }

  @override
  String encode() => 'true';
}

class ConditionID<O> extends Condition<O> {
  dynamic idValue;

  ConditionID([this.idValue]) : super._();

  @override
  ConditionID<T> cast<T>() =>
      this is ConditionID<T> ? this as ConditionID<T> : ConditionID<T>(idValue)
        .._markResolved(resolved, _parent);

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    var idValue = this.idValue;
    if (idValue is ConditionParameter) {
      idValue.resolve(parent: this, parameters: parameters);
      _setParameters([idValue]);
    } else {
      _setParameters([]);
    }

    _markResolved();
  }

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var id = getID(o, entityHandler: entityHandler);

    var idValue = this.idValue;

    if (idValue is ConditionParameter) {
      return idValue.matches(id,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
    } else {
      return id == idValue;
    }
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var idField = entityHandler?.idFieldName() ?? 'id';
    var id = o[idField];

    var idValue = this.idValue;

    if (idValue is ConditionParameter) {
      return idValue.matches(id,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
    } else {
      return EntityHandler.equalsValuesBasic(id, idValue,
          entityHandler: entityHandler);
    }
  }

  String get encodeIdValue => Condition.encodeConditionValue(idValue);

  @override
  String encode() => idValue != null ? '#ID == $encodeIdValue' : '#ID == ?';
}

class ConditionIdIN<O> extends Condition<O> {
  List<dynamic> idsValues;

  ConditionIdIN([dynamic ids])
      : idsValues = KeyConditionINBase.valuesAsList(ids),
        super._();

  @override
  ConditionIdIN<T> cast<T>() => this is ConditionIdIN<T>
      ? this as ConditionIdIN<T>
      : ConditionIdIN<T>(idsValues)
    .._markResolved(resolved, _parent);

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    var idsValues = this.idsValues;

    var params =
        idsValues.map((e) => e is ConditionParameter ? e : null).whereNotNull();
    _setParameters(params);

    _markResolved();
  }

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var id = getID(o, entityHandler: entityHandler);
    return _matchesID(
        idsValues, id, parameters, positionalParameters, namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var idField = entityHandler?.idFieldName() ?? 'id';
    var id = o[idField];
    return _matchesID(
        idsValues, id, parameters, positionalParameters, namedParameters);
  }

  bool _matchesID(
      List<dynamic> idsValues,
      id,
      Object? parameters,
      List<dynamic>? positionalParameters,
      Map<String, Object?>? namedParameters) {
    return idsValues.any((p) {
      return p is ConditionParameter
          ? p.matches(id,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters)
          : id == p;
    });
  }

  String get encodeIdsValues => Condition.encodeConditionValue(idsValues);

  @override
  String encode() => '#ID =~ $encodeIdsValues';
}

abstract class ConditionKey {
  static final RegExp _keyRegExp =
      RegExp(r'''(?:"([^"]*?)"|'([^.]*?)'|(\w+)|\[\s*(\d+)\s*\])''');

  static List<ConditionKey> parse(String keys) {
    keys = keys.trim();
    if (keys.isEmpty) {
      throw ArgumentError('Empty key');
    }

    var list = _keyRegExp.allMatches(keys).map((m) {
      var s1 = m.group(1);
      if (s1 != null) {
        return ConditionKeyField(s1);
      }

      var s2 = m.group(2);
      if (s2 != null) {
        return ConditionKeyField(s2);
      }

      var field = m.group(3);
      if (field != null) {
        return ConditionKeyField(field);
      }

      var index = m.group(4);
      if (index != null) {
        var idx = int.parse(index);
        return ConditionKeyIndex(idx);
      }

      throw StateError('Invalid match: $m');
    }).toList();

    return list;
  }

  bool get isWordKey;

  String encode();

  @override
  String toString() => encode();
}

class ConditionKeyField extends ConditionKey {
  final String name;

  ConditionKeyField(this.name);

  static final RegExp _wordRegExp = RegExp(r'^\w+$');

  @override
  bool get isWordKey => _wordRegExp.hasMatch(name);

  @override
  String encode() => isWordKey ? name : Condition.encodeConditionValue(name);
}

class ConditionKeyIndex extends ConditionKey {
  final int index;

  ConditionKeyIndex(this.index);

  @override
  bool get isWordKey => false;

  @override
  String encode() => '[$index]';
}

abstract class KeyCondition<O, V> extends Condition<O> {
  List<ConditionKey> keys;
  V value;

  KeyCondition(this.keys, this.value) : super._() {
    if (keys.isEmpty) {
      throw ArgumentError('Empty keys');
    }

    if (keys.first is ConditionKeyIndex) {
      throw ArgumentError("First key can't be an index: $keys");
    }
  }

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    _parent = parent;

    var value = this.value;
    if (value is ConditionParameter) {
      value.resolve(parent: this, parameters: parameters);
      _setParameters([value]);
    } else if (value is List) {
      for (var v in value) {
        if (v is ConditionParameter) {
          v.resolve(parent: this, parameters: parameters);
        }
      }
      _setParameters(value.whereType<ConditionParameter>());
    } else {
      _setParameters([]);
    }

    _markResolved();
  }

  bool get isWordKey => keys.length == 1 && keys.first.isWordKey;

  String get encodeKey =>
      isWordKey ? keys.first.encode() : keys.map((e) => e.encode()).join('.');

  static final EntityFieldAccessorGeneric _accessorGeneric =
      EntityFieldAccessorGeneric();

  Object? getEntityKeyValue(O o, [EntityHandler<O>? entityHandler]) {
    if (o == null) return null;

    dynamic obj = o;
    EntityFieldAccessor fieldAccessor = this;

    for (var key in keys) {
      Object? value;

      if (key is ConditionKeyField) {
        var objEntityHandler = entityHandler?.getEntityHandler(obj: obj);
        value = fieldAccessor.getField(obj, key.name,
            entityHandler: objEntityHandler);
      } else if (key is ConditionKeyIndex) {
        var index = key.index;

        if (obj is Iterable) {
          value = obj.elementAt(index);
        } else {
          throw StateError(
              "Can't access index[$index] of type: ${(obj as Object?).runtimeTypeNameUnsafe}");
        }
      }

      if (value == null) {
        return null;
      } else {
        obj = value;
        fieldAccessor = _accessorGeneric;
      }
    }

    return obj;
  }

  KeyConditionValue? getEntityMapKeyValue(Map<String, dynamic>? entityMap,
      [EntityHandler<O>? entityHandler]) {
    if (entityMap == null || entityMap.isEmpty) return null;

    dynamic value = entityMap;
    TypeInfo? valueType =
        TypeInfo.from(entityHandler?.type ?? entityMap.runtimeType);
    EntityHandler? valueEntityHandler = entityHandler;

    for (var key in keys) {
      Object? keyValue;
      TypeInfo? keyType;
      EntityHandler? keyEntityHandler;

      if (key is ConditionKeyField) {
        var keyName = key.name;

        if (value is Map) {
          keyValue = value[keyName];
        } else if (value is Iterable) {
          keyValue = value.map((e) {
            if (e is Map) {
              return e[keyName];
            } else {
              var handler = entityHandler?.getEntityHandler(obj: e);
              if (handler != null) {
                var v = handler.getField(e, keyName);
                return v;
              } else {
                return e;
              }
            }
          }).toList();
        } else {
          throw StateError(
              "Can't access key[$keyName] for type: ${(value as Object?).runtimeTypeNameUnsafe}");
        }

        keyType =
            _resolveValueType(keyName, valueType, valueEntityHandler, keyValue);
        keyEntityHandler =
            _resolveValueEntityHandler(keyType, valueEntityHandler);
      } else if (key is ConditionKeyIndex) {
        var index = key.index;

        if (value is Iterable) {
          keyValue = value.elementAt(index);
          keyType =
              _resolveValueType(null, valueType, valueEntityHandler, keyValue);
          keyEntityHandler =
              _resolveValueEntityHandler(keyType, valueEntityHandler);
        } else {
          throw StateError(
              "Can't access index[$index] for type: ${(value as Object?).runtimeTypeNameUnsafe}");
        }
      }

      if (keyValue == null) {
        return null;
      } else {
        value = keyValue;
        valueType = keyType;
        valueEntityHandler = keyEntityHandler;
      }
    }

    if (valueEntityHandler != null) {
      var idFieldName = valueEntityHandler.idFieldName();

      if (value is Map) {
        value = value[idFieldName];
      } else if (value is Iterable) {
        value = value.map((v) => v is Map ? v[idFieldName] : v).toList();
      }
    }

    return KeyConditionValue(value, valueType, valueEntityHandler);
  }

  EntityHandler? _resolveValueEntityHandler(
      TypeInfo? objType, EntityHandler? objEntityHandler) {
    if (objType == null) return null;

    if (objType.isListEntityOrReference) {
      objType = objType.arguments0!;
    }

    if (objEntityHandler != null) {
      return objEntityHandler.getEntityHandler(type: objType.type);
    }

    var classReflection =
        ReflectionFactory().getRegisterClassReflection(objType.type);

    return classReflection?.entityHandler ??
        EntityHandlerProvider.globalProvider
            .getEntityHandler(type: objType.type);
  }

  TypeInfo? _resolveValueType(String? keyName, TypeInfo? objType,
      EntityHandler? objEntityHandler, Object? value) {
    if (keyName != null) {
      var type = objEntityHandler?.getFieldType(null, keyName);
      if (type != null) return type;
    }

    if (value == null) {
      return null;
    } else if (value is List) {
      if (value.isNotEmpty) {
        return _resolveValueType(
            keyName, objType, objEntityHandler, value.first);
      } else {
        return TypeInfo.from(value);
      }
    } else if (value is Map) {
      return objType ?? TypeInfo.from(value);
    }

    var t = objEntityHandler?.getEntityHandler(obj: value)?.type;
    return t != null ? TypeInfo.fromType(t) : null;
  }
}

class KeyConditionValue {
  final Object value;

  final TypeInfo? type;
  final EntityHandler? entityHandler;

  KeyConditionValue(this.value, this.type, this.entityHandler);
}

class KeyConditionEQ<O> extends KeyCondition<O, Object?> {
  KeyConditionEQ(super.keys, dynamic super.value);

  @override
  KeyConditionEQ<T> cast<T>() => this is KeyConditionEQ<T>
      ? this as KeyConditionEQ<T>
      : KeyConditionEQ<T>(keys, value)
    .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return equalsConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return equalsConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey == $encodeValue';
}

class KeyConditionNotEQ<O> extends KeyCondition<O, Object?> {
  KeyConditionNotEQ(super.keys, dynamic super.value);

  @override
  KeyConditionNotEQ<T> cast<T>() => this is KeyConditionNotEQ<T>
      ? this as KeyConditionNotEQ<T>
      : KeyConditionNotEQ<T>(keys, value)
    .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return !equalsConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return !equalsConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey != $encodeValue';
}

class KeyConditionGreaterThan<O> extends KeyCondition<O, Object?> {
  KeyConditionGreaterThan(super.keys, dynamic super.value);

  @override
  KeyConditionGreaterThan<T> cast<T>() => this is KeyConditionGreaterThan<T>
      ? this as KeyConditionGreaterThan<T>
      : KeyConditionGreaterThan<T>(keys, value)
    .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return greaterThanConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return greaterThanConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey > $encodeValue';
}

class KeyConditionGreaterThanOrEqual<O> extends KeyCondition<O, Object?> {
  KeyConditionGreaterThanOrEqual(super.keys, dynamic super.value);

  @override
  KeyConditionGreaterThanOrEqual<T> cast<T>() =>
      this is KeyConditionGreaterThanOrEqual<T>
          ? this as KeyConditionGreaterThanOrEqual<T>
          : KeyConditionGreaterThanOrEqual<T>(keys, value)
        .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return greaterThanOrEqualConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return greaterThanOrEqualConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey >= $encodeValue';
}

class KeyConditionLessThan<O> extends KeyCondition<O, Object?> {
  KeyConditionLessThan(super.keys, dynamic super.value);

  @override
  KeyConditionLessThan<T> cast<T>() => this is KeyConditionLessThan<T>
      ? this as KeyConditionLessThan<T>
      : KeyConditionLessThan<T>(keys, value)
    .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return lessThanConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return lessThanConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey < $encodeValue';
}

class KeyConditionLessThanOrEqual<O> extends KeyCondition<O, Object?> {
  KeyConditionLessThanOrEqual(super.keys, dynamic super.value);

  @override
  KeyConditionLessThanOrEqual<T> cast<T>() =>
      this is KeyConditionLessThanOrEqual<T>
          ? this as KeyConditionLessThanOrEqual<T>
          : KeyConditionLessThanOrEqual<T>(keys, value)
        .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return lessThanOrEqualConditionValue(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return lessThanOrEqualConditionValue(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        keyType: keyValue?.type,
        keyEntityHandler: keyValue?.entityHandler);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey <= $encodeValue';
}

abstract class KeyConditionINBase<O> extends KeyCondition<O, List<Object?>> {
  static List<Object?> valuesAsList(dynamic value) {
    if (value == null) return [null];

    if (value is List) return value;

    if (value is Iterable) return value.toList();

    if (value is Map) return value.values.toList();

    return [value];
  }

  final bool not;

  KeyConditionINBase(List<ConditionKey> keys, dynamic values,
      {this.not = false})
      : super(keys, valuesAsList(values));

  @override
  KeyConditionINBase<T> cast<T>();

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    var inValues = inConditionValues(keyValue, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return inValues != not;
  }

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    var inValues = inConditionValues(keyValue?.value, value,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        entityHandler: entityHandler);

    return inValues != not;
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey ${not ? '!' : '='}~ $encodeValue';
}

class KeyConditionIN<O> extends KeyConditionINBase<O> {
  KeyConditionIN(super.keys, super.values);

  @override
  KeyConditionIN<T> cast<T>() => this is KeyConditionIN<T>
      ? this as KeyConditionIN<T>
      : KeyConditionIN<T>(keys, value)
    .._markResolved(resolved, _parent);
}

class KeyConditionNotIN<O> extends KeyConditionINBase<O> {
  KeyConditionNotIN(super.keys, List super.values) : super(not: true);

  @override
  KeyConditionNotIN<T> cast<T>() => this is KeyConditionNotIN<T>
      ? this as KeyConditionNotIN<T>
      : KeyConditionNotIN<T>(keys, value)
    .._markResolved(resolved, _parent);
}

class ConditionParseCache<O> {
  static final Map<Type, ConditionParseCache> _typesCache =
      <Type, ConditionParseCache>{};

  static ConditionParseCache<O> get<O>() {
    var cached = _typesCache[O];
    if (cached != null) {
      return cached as ConditionParseCache<O>;
    }

    var instance = ConditionParseCache<O>._();
    _typesCache[O] = instance;
    return instance;
  }

  factory ConditionParseCache() => get<O>();

  ConditionParseCache._();

  static final ConditionParser _conditionParser = ConditionParser();

  final Map<String, Condition<O>> _parsedConditions = <String, Condition<O>>{};

  Condition<O> parseQuery(String query) {
    var cached = _parsedConditions[query];
    if (cached != null) {
      return cached;
    }

    if (_parsedConditions.length > 500) {
      for (var k in _parsedConditions.keys.take(100).toList(growable: false)) {
        _parsedConditions.remove(k);
      }
    }

    var condition = _conditionParser.parse<O>(query);
    _parsedConditions[query] = condition;
    return condition;
  }
}

class ConditionQuery<O> implements EntityMatcher<O> {
  final String query;

  const ConditionQuery(this.query);

  static Condition<O> parse<O>(String query) {
    var cache = ConditionParseCache.get<O>();
    return cache.parseQuery(query);
  }

  Condition<O> get condition => parse<O>(query);

  @override
  bool matchesEntity(O o,
          {EntityHandler<O>? entityHandler,
          Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      condition.matchesEntity(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  @override
  bool matchesEntityMap(Map<String, dynamic> o,
          {EntityHandler<O>? entityHandler,
          Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      condition.matchesEntityMap(o,
          entityHandler: entityHandler,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
}
