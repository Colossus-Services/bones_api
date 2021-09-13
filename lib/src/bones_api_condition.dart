import 'dart:convert';

import 'package:bones_api/src/bones_api_condition_parser.dart';

import 'bones_api_entity.dart';

abstract class ConditionElement {
  bool _resolved = false;

  bool get resolved => _resolved;

  void _markResolved() {
    _resolved = true;
  }

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
          var json = obj.toJson();
          parameters = json;
        } catch (_) {}
      }

      if (parameters is Map) {
        namedParameters ??= parameters is Map<String, Object?>
            ? parameters
            : parameters.map<String, Object?>(
                (key, value) => MapEntry<String, Object?>('$key', value));
      } else if (parameters is Iterable) {
        positionalParameters ??=
            parameters is List ? parameters : parameters.toList();
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
      Map<String, Object?>? namedParameters}) {
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

    return myValue == otherValue;
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
    var s = json.encode(o, toEncodable: toJsonEncodable);

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

  bool equalsConditionValue(Object? value1, Object? value2,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (value1 is ConditionParameter) {
      return value1.matches(value2,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
    } else if (value2 is ConditionParameter) {
      return value2.matches(value1,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
    } else {
      return value1 == value2;
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
        super._();

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
    var parametersSize0 = parameters.length;

    for (var c in conditions) {
      c.resolve(parent: this, parameters: parameters);
    }

    _setParameters(parameters.sublist(parametersSize0));

    _markResolved();
  }
}

class GroupConditionAND<O> extends GroupCondition<O> {
  GroupConditionAND(Iterable<Condition> conditions) : super(conditions);

  @override
  GroupConditionAND<T> cast<T>() {
    if (this is GroupConditionAND<T>) {
      return this as GroupConditionAND<T>;
    }
    return GroupConditionAND<T>(conditions.map((e) => e.cast<T>()).toList());
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
  GroupConditionOR(Iterable<Condition> conditions) : super(conditions);

  @override
  GroupConditionOR<T> cast<T>() {
    if (this is GroupConditionOR<T>) {
      return this as GroupConditionOR<T>;
    }
    return GroupConditionOR<T>(conditions.map((e) => cast<T>()).toList());
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

class ConditionID<O> extends Condition<O> {
  dynamic idValue;

  ConditionID([this.idValue]) : super._();

  @override
  ConditionID<T> cast<T>() =>
      this is ConditionID<T> ? this as ConditionID<T> : ConditionID<T>(idValue);

  @override
  void resolve(
      {Condition? parent, required List<ConditionParameter> parameters}) {
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
    var idField = entityHandler?.idFieldsName() ?? 'id';
    var id = o[idField];

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

  String get encodeIdValue => Condition.encodeConditionValue(idValue);

  @override
  String encode() => idValue != null ? '#ID == $encodeIdValue' : '#ID == ?';
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

abstract class KeyCondition<O> extends Condition<O> {
  List<ConditionKey> keys;
  dynamic value;

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
    var value = this.value;
    if (value is ConditionParameter) {
      value.resolve(parent: this, parameters: parameters);
      _setParameters([value]);
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
              "Can't access index[$index] of type: ${obj.runtimeType}");
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

  Object? getEntityMapKeyValue(Map<String, dynamic>? o,
      [EntityHandler<O>? entityHandler]) {
    if (o == null || o.isEmpty) return null;

    dynamic obj = o;

    for (var key in keys) {
      Object? value;

      if (key is ConditionKeyField) {
        if (obj is Map) {
          value = obj[key.name];
        } else {
          throw StateError(
              "Can't access key[${key.name}] for type: ${obj.runtimeType}");
        }
      } else if (key is ConditionKeyIndex) {
        var index = key.index;

        if (obj is Iterable) {
          value = obj.elementAt(index);
        } else {
          throw StateError(
              "Can't access index[$index] for type: ${obj.runtimeType}");
        }
      }

      if (value == null) {
        return null;
      } else {
        obj = value;
      }
    }

    return obj;
  }
}

class KeyConditionEQ<O> extends KeyCondition<O> {
  KeyConditionEQ(List<ConditionKey> keys, dynamic value) : super(keys, value);

  @override
  KeyConditionEQ<T> cast<T>() => this is KeyConditionEQ<T>
      ? this as KeyConditionEQ<T>
      : KeyConditionEQ<T>(keys, value);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return equalsConditionValue(value, keyValue,
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

    return equalsConditionValue(value, keyValue,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey == $encodeValue';
}

class KeyConditionNotEQ<O> extends KeyCondition<O> {
  KeyConditionNotEQ(List<ConditionKey> keys, dynamic value)
      : super(keys, value);

  @override
  KeyConditionNotEQ<T> cast<T>() => this is KeyConditionNotEQ<T>
      ? this as KeyConditionNotEQ<T>
      : KeyConditionNotEQ<T>(keys, value);

  @override
  bool matchesEntity(O o,
      {EntityHandler<O>? entityHandler,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return !equalsConditionValue(value, keyValue,
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

    return !equalsConditionValue(value, keyValue,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  String get encodeValue => Condition.encodeConditionValue(value);

  @override
  String encode() => '$encodeKey != $encodeValue';
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
      for (var k in _parsedConditions.keys.take(100).toList()) {
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
