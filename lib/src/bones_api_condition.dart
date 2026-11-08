import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicNumber;

import 'bones_api_condition_parser.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_reference.dart';
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

  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  });

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
  int? contextKeyPosition;

  ConditionParameter() : index = null, key = null;

  ConditionParameter.index(this.index) : key = null;

  ConditionParameter.key(this.key) : index = null;

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
    _parent = parent;

    if (isPositional) {
      contextPosition = parameters.length;
    }

    if (parent is KeyCondition) {
      contextKey = parent.keys.whereType<ConditionKeyField>().last.name;
      contextKeyPosition = parameters.length;
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

  Object? getValue({
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Map<String, Object?>? encodingParameters,
  }) {
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
                (key, value) => MapEntry<String, Object?>('$key', value),
              );
      } else if (parameters is Iterable) {
        positionalParameters ??= parameters is List
            ? parameters
            : parameters.toList(growable: false);
      }
    }

    var key = this.key;

    if (key != null && key.isNotEmpty) {
      var value = namedParameters?[key] ?? encodingParameters?[key];
      if (value != null) {
        return value;
      }
    }

    var index = this.index;

    // A positional `?` is keyed by its field only without positional values:
    // with them, its position (e.g. `id > ? && id < ?`: both keyed by `id`).
    if (index == null && positionalParameters == null) {
      var key = contextKey;
      if (key != null && key.isNotEmpty) {
        var value = namedParameters?[key] ?? encodingParameters?[key];
        if (value != null) {
          return value;
        }
      }
    }

    if (index == null || index < 0) {
      index = contextPosition ?? contextKeyPosition;
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

    if (key == null || key.isEmpty) {
      key = contextKey;

      if (key != null && key.isNotEmpty) {
        return namedParameters?[key] ?? encodingParameters?[key];
      }
    }

    return null;
  }

  /// Throws an [ArgumentError] if [value] is a [RegExp] (or, with [deep], an
  /// [Iterable] with one): as an `==`/`=~` (`IN`) value it would be
  /// compared, not matched. A regexp parameter is written `/?/`:
  /// `field =~ /?/`.
  ///
  /// When matching each entity, only `deep: false` (`O(1)`): the elements
  /// of a list are checked as they are compared.
  static void checkNotRegExpValue(Object? value, {bool deep = false}) {
    if (value is RegExp ||
        (deep && value is Iterable && value.any((e) => e is RegExp))) {
      throw ArgumentError(
        'A `RegExp` parameter value is only matched as a regexp pattern: '
        'write the parameter between `/`, e.g. `field =~ /?/` '
        '(not `field =~ ?`).',
      );
    }
  }

  bool matches(
    Object? value, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) {
    var myValue = getValue(
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    );

    checkNotRegExpValue(myValue);

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
          )
        : value;

    if (myValue is Iterable) {
      if (otherValue is Iterable) {
        var equals = isEqualsIterableDeep(
          myValue,
          otherValue,
          valueEquality: (a, b) => EntityHandler.equalsValuesBasic(
            a,
            b,
            entityHandler: entityHandler,
          ),
        );
        return equals;
      } else {
        var contains = myValue.where((v) {
          checkNotRegExpValue(v);
          return EntityHandler.equalsValuesBasic(
            v,
            otherValue,
            entityHandler: entityHandler,
          );
        }).isNotEmpty;
        return contains;
      }
    } else if (otherValue is Iterable) {
      var contains = otherValue
          .where(
            (v) => EntityHandler.equalsValuesBasic(
              v,
              myValue,
              entityHandler: entityHandler,
            ),
          )
          .isNotEmpty;
      return contains;
    }

    return EntityHandler.equalsValuesBasic(
      myValue,
      otherValue,
      entityHandler: entityHandler,
    );
  }

  bool greaterThan(
    Object? value, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) => _compareOrdering(
    _Ordering.gt,
    value,
    parameters,
    positionalParameters,
    namedParameters,
    entityHandler,
  );

  bool greaterThanOrEqual(
    Object? value, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) => _compareOrdering(
    _Ordering.gte,
    value,
    parameters,
    positionalParameters,
    namedParameters,
    entityHandler,
  );

  bool lessThan(
    Object? value, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) => _compareOrdering(
    _Ordering.lt,
    value,
    parameters,
    positionalParameters,
    namedParameters,
    entityHandler,
  );

  bool lessThanOrEqual(
    Object? value, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) => _compareOrdering(
    _Ordering.lte,
    value,
    parameters,
    positionalParameters,
    namedParameters,
    entityHandler,
  );

  /// Compares this parameter's value (the left side) with [value] (the right
  /// side, itself resolved if it's a [ConditionParameter]) by [ordering].
  ///
  /// The shared body of [greaterThan], [greaterThanOrEqual], [lessThan] and
  /// [lessThanOrEqual], which only differ by the [ordering].
  bool _compareOrdering(
    _Ordering ordering,
    Object? value,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  ) {
    var myValue = getValue(
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    );

    var otherValue = value is ConditionParameter
        ? value.getValue(
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
          )
        : value;

    return ordering.test(myValue, otherValue, entityHandler);
  }

  bool matchesIn(
    List values, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) {
    var myValue = getValue(
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    );

    checkNotRegExpValue(myValue);

    // Resolve the parameters among [values] once, not once per element of
    // `myValue` (`getValue` is pure, but it may convert the `parameters`
    // object with `Json.toJson` on every call):
    var otherValues = values
        .map(
          (v2) => v2 is ConditionParameter
              ? v2.getValue(
                  parameters: parameters,
                  positionalParameters: positionalParameters,
                  namedParameters: namedParameters,
                )
              : v2,
        )
        .toList();

    if (myValue is List) {
      for (var v1 in myValue) {
        checkNotRegExpValue(v1);
        for (var otherValue in otherValues) {
          var match = EntityHandler.equalsValuesBasic(
            v1,
            otherValue,
            entityHandler: entityHandler,
          );
          if (match) return true;
        }
      }

      return false;
    } else {
      for (var otherValue in otherValues) {
        var match = EntityHandler.equalsValuesBasic(
          myValue,
          otherValue,
          entityHandler: entityHandler,
        );
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

/// The four ordering comparisons of a condition (`>`, `>=`, `<`, `<=`).
///
/// Written once here, instead of once per operator in [ConditionParameter],
/// [Condition] and the `KeyCondition` subclasses: used by
/// [ConditionParameter._compareOrdering], [Condition._orderingConditionValue]
/// and [_KeyConditionOrdering].
enum _Ordering {
  gt('>'),
  gte('>='),
  lt('<'),
  lte('<=');

  /// The operator symbol, as encoded in a condition (see [Condition.encode]).
  final String symbol;

  const _Ordering(this.symbol);

  /// The same comparison with its sides swapped: `a > b` is `b < a`. Used
  /// when the [ConditionParameter] to resolve is the right side.
  _Ordering get mirrored => switch (this) {
    gt => lt,
    gte => lte,
    lt => gt,
    lte => gte,
  };

  /// Compares [a] with [b] by the matching [EntityHandler] function.
  bool test(Object? a, Object? b, EntityHandler? entityHandler) =>
      switch (this) {
        gt => EntityHandler.graterThanValue(a, b, entityHandler: entityHandler),
        gte => EntityHandler.graterThanOrEqualValue(
          a,
          b,
          entityHandler: entityHandler,
        ),
        lt => EntityHandler.lessThanValue(a, b, entityHandler: entityHandler),
        lte => EntityHandler.lessThanOrEqualValue(
          a,
          b,
          entityHandler: entityHandler,
        ),
      };
}

abstract class EntityMatcher<O> {
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  });

  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  });
}

abstract class Condition<O> extends ConditionElement
    with EntityFieldAccessor<O>
    implements EntityMatcher<O> {
  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  });

  Condition._();

  static final ConditionParser _conditionParser = ConditionParser();

  factory Condition.parse(String condition) {
    if (condition.isEmpty) throw FormatException('Empty condition');

    return _conditionParser.parse(condition).cast<O>();
  }

  static final RegExp _conditionParameterRegExp = RegExp(
    r'\{\s*"ConditionParameter":\s*"(?:(#(?:-?\d+)?)|(:\w*)|\?)"\s*\}',
  );

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

  bool get isIDCondition => false;

  /// If [value1] (an entity's) is the values of a to-many relationship,
  /// compared one by one (as a SQL join of its rows) with a single [value2].
  static bool _isToManyValues(Object? value1, Object? value2) =>
      value1 is Iterable && value2 is! Iterable;

  /// If [value1] `>` [value2] (see [_orderingConditionValue]).
  ///
  /// [keyType] is unused: kept for the API (and symmetry with
  /// [equalsConditionValue]).
  bool greaterThanConditionValue(
    Object? value1,
    Object? value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  }) => _orderingConditionValue(
    _Ordering.gt,
    value1,
    value2,
    parameters,
    positionalParameters,
    namedParameters,
    keyEntityHandler,
  );

  /// If [value1] `>=` [value2] (see [_orderingConditionValue]).
  ///
  /// [keyType] is unused: kept for the API (and symmetry with
  /// [equalsConditionValue]).
  bool greaterThanOrEqualConditionValue(
    Object? value1,
    Object? value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  }) => _orderingConditionValue(
    _Ordering.gte,
    value1,
    value2,
    parameters,
    positionalParameters,
    namedParameters,
    keyEntityHandler,
  );

  /// If [value1] `<` [value2] (see [_orderingConditionValue]).
  ///
  /// [keyType] is unused: kept for the API (and symmetry with
  /// [equalsConditionValue]).
  bool lessThanConditionValue(
    Object? value1,
    Object? value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  }) => _orderingConditionValue(
    _Ordering.lt,
    value1,
    value2,
    parameters,
    positionalParameters,
    namedParameters,
    keyEntityHandler,
  );

  /// If [value1] `<=` [value2] (see [_orderingConditionValue]).
  ///
  /// [keyType] is unused: kept for the API (and symmetry with
  /// [equalsConditionValue]).
  bool lessThanOrEqualConditionValue(
    Object? value1,
    Object? value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  }) => _orderingConditionValue(
    _Ordering.lte,
    value1,
    value2,
    parameters,
    positionalParameters,
    namedParameters,
    keyEntityHandler,
  );

  /// Compares [value1] (an entity's value) with [value2] by [ordering]: the
  /// shared body of [greaterThanConditionValue],
  /// [greaterThanOrEqualConditionValue], [lessThanConditionValue] and
  /// [lessThanOrEqualConditionValue].
  ///
  /// - The values of a to-many relationship: any of them (as a SQL join of
  ///   its rows).
  /// - A [ConditionParameter] on the left is resolved and compared by
  ///   [ordering]; on the right, it's the left side of the [_Ordering.mirrored]
  ///   comparison (`a > ?` is `? < a`).
  bool _orderingConditionValue(
    _Ordering ordering,
    Object? value1,
    Object? value2,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? keyEntityHandler,
  ) {
    if (_isToManyValues(value1, value2)) {
      return (value1 as Iterable).any(
        (v) => _orderingConditionValue(
          ordering,
          v,
          value2,
          parameters,
          positionalParameters,
          namedParameters,
          keyEntityHandler,
        ),
      );
    }

    if (value1 is ConditionParameter) {
      return value1._compareOrdering(
        ordering,
        value2,
        parameters,
        positionalParameters,
        namedParameters,
        keyEntityHandler,
      );
    } else if (value2 is ConditionParameter) {
      return value2._compareOrdering(
        ordering.mirrored,
        value1,
        parameters,
        positionalParameters,
        namedParameters,
        keyEntityHandler,
      );
    } else {
      return ordering.test(value1, value2, keyEntityHandler);
    }
  }

  bool equalsConditionValue(
    Object? value1,
    Object? value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  }) {
    if (value1 is ConditionParameter) {
      return value1.matches(
        value2,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        entityHandler: keyEntityHandler,
      );
    } else if (value2 is ConditionParameter) {
      return value2.matches(
        value1,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        entityHandler: keyEntityHandler,
      );
    } else if (value1 is Iterable && value2 is! Iterable) {
      // The values of a to-many relationship: any of them (as a SQL join of
      // its rows, and as a parameter's value: [ConditionParameter.matches]).
      return value1.any(
        (v) => EntityHandler.equalsValuesBasic(
          v,
          value2,
          entityHandler: keyEntityHandler,
        ),
      );
    } else {
      var match = EntityHandler.equalsValuesBasic(
        value1,
        value2,
        entityHandler: keyEntityHandler,
      );
      return match;
    }
  }

  bool inConditionValues(
    Object? value1,
    List value2, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  }) {
    if (value1 is ConditionParameter) {
      return value1.matchesIn(
        value2,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        entityHandler: entityHandler,
      );
    } else if (value1 is List) {
      for (var v2 in value2) {
        if (v2 is ConditionParameter) {
          var match = v2.matchesIn(
            value1,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
            entityHandler: entityHandler,
          );
          if (match) return true;
        } else {
          for (var v1 in value1) {
            var match = EntityHandler.equalsValuesBasic(
              v1,
              v2,
              entityHandler: entityHandler,
            );
            if (match) return true;
          }
        }
      }

      return false;
    } else {
      for (var v2 in value2) {
        if (v2 is ConditionParameter) {
          var match = v2.matches(
            value1,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
            entityHandler: entityHandler,
          );
          if (match) return true;
        } else {
          var match = EntityHandler.equalsValuesBasic(
            value1,
            v2,
            entityHandler: entityHandler,
          );
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
    : conditions = conditions is List<Condition>
          ? conditions
          : conditions.toList(),
      super._() {
    for (var c in conditions) {
      c._parent = this;
    }
  }

  @override
  bool get isIDCondition => conditions.every((e) => e.isIDCondition);

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
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
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

      if (!matches) return false;
    }

    return true;
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntityMap(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

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
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

      if (matches) return true;
    }

    return false;
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    if (conditions.isEmpty) {
      return false;
    }

    for (var c in conditions) {
      var matches = c.matchesEntityMap(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

      if (matches) return true;
    }

    return false;
  }

  @override
  String encode() => '( ${conditions.join(' || ')} )';
}

/// The negation of a [condition]: `!(condition)` or `!key op value`.
///
/// The complement of the [condition]: matches exactly the entities that the
/// [condition] doesn't, including those with a `null` field (or without a
/// related entity) where the [condition] is unknown. Through a to-many
/// relationship it matches the entities without any matching related one:
/// `!(roles.type == "admin")` matches the users without an admin role.
class ConditionNOT<O> extends Condition<O> {
  /// The negated condition.
  final Condition condition;

  ConditionNOT(this.condition) : super._() {
    condition._parent = this;
  }

  @override
  bool get isIDCondition => condition.isIDCondition;

  /// A `NOT` is encoded apart from its parent (a subquery or its own group),
  /// so its [condition] starts again with inner joins.
  @override
  bool get isInner => true;

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
    _parent = parent;

    var parametersSize0 = parameters.length;
    condition.resolve(parent: this, parameters: parameters);
    _setParameters(parameters.sublist(parametersSize0));

    _markResolved();
  }

  @override
  ConditionNOT<T> cast<T>() {
    if (this is ConditionNOT<T>) {
      return this as ConditionNOT<T>;
    }
    return ConditionNOT<T>(condition.cast<T>())
      .._markResolved(resolved, _parent);
  }

  /// If the [condition] has nothing to match (an empty group): as SQL encodes
  /// it, every entity (and its negation, none).
  bool get _isEmptyCondition {
    var c = _unwrappedCondition;
    return c is GroupCondition && c.conditions.isEmpty;
  }

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) =>
      !_isEmptyCondition &&
      !condition.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) =>
      !_isEmptyCondition &&
      !condition.matchesEntityMap(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

  /// The [condition], without the groups of a single condition (parsed as
  /// the condition itself).
  Condition get _unwrappedCondition {
    var c = condition;
    while (c is GroupCondition && c.conditions.length == 1) {
      c = c.conditions.first;
    }
    return c;
  }

  @override
  String encode() {
    var c = _unwrappedCondition;
    // A group is already in parentheses:
    return c is GroupCondition && c.conditions.length > 1
        ? '!${c.encode()}'
        : '!( ${c.encode()} )';
  }
}

class ConditionANY<O> extends Condition<O> {
  ConditionANY() : super._();

  @override
  ConditionANY<T> cast<T>() =>
      this is ConditionANY<T> ? this as ConditionANY<T> : ConditionANY<T>()
        .._markResolved(resolved, _parent);

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
    _parent = parent;

    _markResolved();
  }

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    return true;
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    return true;
  }

  @override
  String encode() => 'true';
}

class ConditionID<O> extends Condition<O> {
  dynamic idValue;

  ConditionID([this.idValue]) : super._();

  dynamic resolveIDValue({Object? parameters}) {
    var id = idValue;

    if (id == null && parameters is O) {
      id = getID(parameters);
    }

    if (id is ConditionParameter) {
      id = id.getValue(parameters: parameters);
    }

    return id;
  }

  @override
  bool get isIDCondition => true;

  @override
  ConditionID<T> cast<T>() =>
      this is ConditionID<T> ? this as ConditionID<T> : ConditionID<T>(idValue)
        .._markResolved(resolved, _parent);

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
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
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var id = getID(o, entityHandler: entityHandler);

    var idValue = this.idValue;

    if (idValue is ConditionParameter) {
      return idValue.matches(
        id,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    } else {
      return id == idValue;
    }
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var idField = entityHandler?.idFieldName() ?? 'id';
    var id = o[idField];

    var idValue = this.idValue;

    if (idValue is ConditionParameter) {
      return idValue.matches(
        id,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    } else {
      return EntityHandler.equalsValuesBasic(
        id,
        idValue,
        entityHandler: entityHandler,
      );
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
  bool get isIDCondition => true;

  @override
  ConditionIdIN<T> cast<T>() =>
      this is ConditionIdIN<T>
            ? this as ConditionIdIN<T>
            : ConditionIdIN<T>(idsValues)
        .._markResolved(resolved, _parent);

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
    _parent = parent;

    var idsValues = this.idsValues;

    var params = idsValues
        .map((e) => e is ConditionParameter ? e : null)
        .nonNulls;
    _setParameters(params);

    _markResolved();
  }

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var id = getID(o, entityHandler: entityHandler);
    return _matchesID(
      idsValues,
      id,
      parameters,
      positionalParameters,
      namedParameters,
    );
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var idField = entityHandler?.idFieldName() ?? 'id';
    var id = o[idField];
    return _matchesID(
      idsValues,
      id,
      parameters,
      positionalParameters,
      namedParameters,
    );
  }

  bool _matchesID(
    List<dynamic> idsValues,
    id,
    Object? parameters,
    List<dynamic>? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    return idsValues.any((p) {
      return p is ConditionParameter
          ? p.matches(
              id,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
            )
          : id == p;
    });
  }

  String get encodeIdsValues => Condition.encodeConditionValue(idsValues);

  @override
  String encode() => '#ID =~ $encodeIdsValues';
}

abstract class ConditionKey {
  static final RegExp _keyRegExp = RegExp(
    r'''(?:"([^"]*?)"|'([^.]*?)'|(\w+)|\[\s*(\d+)\s*\])''',
  );

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

  /// The [value] encoded as in a condition string (see [encode]).
  String get encodeValue => Condition.encodeConditionValue(value);

  /// If `true` this is a negated operator (`!=`, `!~`), that also matches a
  /// `null` field.
  bool get isNegated => false;

  /// A negated operator needs an outer join: a missing related entity is a
  /// `null` field, which it matches.
  @override
  bool get isInner => !isNegated && super.isInner;

  /// If [keyValue] is an empty list reached through a to-many relationship
  /// (see [hasToManyInKeyPath]): an entity without related entities.
  bool _isEmptyToMany(Object? keyValue, EntityHandler? entityHandler) =>
      keyValue is Iterable &&
      keyValue.isEmpty &&
      hasToManyInKeyPath(entityHandler);

  /// A cache of [hasToManyInKeyPath]: the [EntityHandler] whose result is cached in
  /// [_hasToManyInKeyPathCacheResult].
  ///
  /// Why: [hasToManyInKeyPath] is called for every entity matched (an in-memory
  /// select checks each row), and resolving it walks the [keys] through the
  /// entity handlers' field types. The result depends only on the [keys]
  /// (fixed) and the [EntityHandler] (the same for every row of a query), so
  /// it's computed once per handler. A different handler (the same parsed
  /// [Condition] used for another entity type, or none) recomputes it.
  EntityHandler? _hasToManyInKeyPathCacheHandler;

  /// The cached [hasToManyInKeyPath] of [_hasToManyInKeyPathCacheHandler] (`null`: not
  /// computed yet).
  bool? _hasToManyInKeyPathCacheResult;

  /// If any key of the [keys] path, not only the last one, is a to-many
  /// relationship (a field declared as a list of entities or references):
  /// `roles` (the last key), `roles.type` and `owner.roles.type` (a key
  /// before the last). Then the key's value is a list, one value per
  /// related entity.
  ///
  /// Resolved by the declared field types of [entityHandler]'s entity (not
  /// by the values: a to-many without related entities is an empty list, as
  /// an empty list field).
  ///
  /// A list field that is not a relationship (`List<String> tags`, a
  /// `Uint8List`) is not a to-many: its value is compared as a whole.
  ///
  /// Cached per [entityHandler] (see [_hasToManyInKeyPathCacheHandler]).
  bool hasToManyInKeyPath(EntityHandler? entityHandler) {
    if (identical(entityHandler, _hasToManyInKeyPathCacheHandler)) {
      return _hasToManyInKeyPathCacheResult ?? false;
    }

    var toMany = false;
    var handler = entityHandler;
    for (var key in keys) {
      if (handler == null || key is! ConditionKeyField) break;

      var type = handler.getFieldType(null, key.name, resolveFiledName: true);
      if (type == null) break;

      if (isToManyType(type, handler)) {
        toMany = true;
        break;
      }

      handler = _resolveValueEntityHandler(type, handler);
    }

    _hasToManyInKeyPathCacheHandler = entityHandler;
    _hasToManyInKeyPathCacheResult = toMany;
    return toMany;
  }

  /// A cache of [isRelationshipKey]: the [EntityHandler] whose result is
  /// cached in [_isRelationshipKeyCacheResult].
  ///
  /// Why: as [hasToManyInKeyPath] (see [_hasToManyInKeyPathCacheHandler]),
  /// it's called for every entity matched, and resolved by the entity
  /// handler's field types: computed once per handler.
  EntityHandler? _isRelationshipKeyCacheHandler;

  /// The cached [isRelationshipKey] of [_isRelationshipKeyCacheHandler]
  /// (`null`: not computed yet).
  bool? _isRelationshipKeyCacheResult;

  /// If the [keys] are a single relationship field of [entityHandler]'s
  /// entity: a to-one (an entity, `User? owner`, or an [EntityReference]) or
  /// a to-many (a `List` of entities or an [EntityReferenceList]). Not a
  /// path through one (`owner.email`), nor a field of another type.
  ///
  /// A relationship is compared by the IDs of its related entities, and it
  /// never has a `null` ID: so a `null` element of a `=~`/`!~` list
  /// (`=~ [1, null]`, `=~ [null]`) is ignored (for another field, it matches
  /// a `null`, as `IS NULL`). As any field, `=~ null` (or a `null`
  /// parameter) is an empty set (`=~` matches none, `!~` all, as with `[]`),
  /// and `==`/`!=` with `[]` are with `null` ("without related entities" /
  /// "with some").
  ///
  /// Cached per [entityHandler] (see [_isRelationshipKeyCacheHandler]).
  bool isRelationshipKey(EntityHandler? entityHandler) {
    if (identical(entityHandler, _isRelationshipKeyCacheHandler)) {
      return _isRelationshipKeyCacheResult ?? false;
    }

    var relationship = false;
    var key = keys.length == 1 ? keys.first : null;
    if (entityHandler != null && key is ConditionKeyField) {
      var type = entityHandler.getFieldType(
        null,
        key.name,
        resolveFiledName: true,
      );
      if (type != null) {
        relationship = isRelationshipType(type, entityHandler);
      }
    }

    _isRelationshipKeyCacheHandler = entityHandler;
    _isRelationshipKeyCacheResult = relationship;
    return relationship;
  }

  /// The right side of a `=~`/`!~` ([value], a list) with its parameters
  /// resolved (a parameter's list flattened), without `null`s: the IDs (or
  /// entities) of a relationship (see [isRelationshipKey]) to match. Empty
  /// for `[]`, `null`, `[null]` or a `null` parameter.
  List<Object> _relationshipRightIDs(
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    var ids = <Object>[];

    void add(Object? v) {
      if (v == null) return;
      if (v is Iterable) {
        for (var e in v) {
          add(e);
        }
      } else if (v is EntityReference) {
        // A reference as a parameter: its ID (`null` if empty).
        add(v.id);
      } else if (v is EntityReferenceList) {
        add(v.ids);
      } else {
        ids.add(v);
      }
    }

    var values = value;
    for (var v in values is Iterable ? values : [values]) {
      add(
        v is ConditionParameter
            ? v.getValue(
                parameters: parameters,
                positionalParameters: positionalParameters,
                namedParameters: namedParameters,
              )
            : v,
      );
    }

    return ids;
  }

  /// If the right side of a `=~`/`!~` ([value], a list) is a single
  /// parameter whose value is `null` (`x =~ ?` with `null`): an empty set,
  /// as `x =~ null` and `x =~ []` (`=~` matches none, `!~` all, any field).
  bool _isNullParameterSet(
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    var values = value;
    if (values is! List || values.length != 1) return false;
    var p = values.first;
    return p is ConditionParameter &&
        p.getValue(
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
            ) ==
            null;
  }

  /// The right side of a `==`/`!=` ([value]) as SQL compares it:
  /// - `[]` (also a parameter's) is `null`: `== []` is `== null`
  ///   (`IS NULL`), any field.
  /// - A list as a single value, `[x]` is `x` (`== [7]` is `== 7`), unless
  ///   the left side ([keyValue], the entity's) is itself a list field (a
  ///   `List<String>`, a `Uint8List`; not a to-many relationship's values,
  ///   see [hasToManyInKeyPath]): then the lists are compared as a whole.
  /// - An [EntityReference] (also a parameter's, or a list's element) is
  ///   its ID.
  ///
  /// Otherwise returns [value] unchanged (a [ConditionParameter] is then
  /// resolved while compared, as before).
  Object? _equalsRightValue(
    Object? keyValue,
    EntityHandler? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    Object? v = value;
    if (v is ConditionParameter) {
      var paramValue = v.getValue(
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
      if (paramValue is! Iterable && paramValue is! EntityReference) {
        return value;
      }
      v = paramValue;
    }

    if (v is EntityReference) return v.id;

    if (v is Iterable) {
      var list = v.toList();
      if (list.isEmpty) return null;

      // A list field (not a to-many's values): compared as a whole, by
      // [value] (a parameter is compared with [ConditionParameter.matches]).
      var listField =
          keyValue is Iterable && !hasToManyInKeyPath(entityHandler);
      if (listField) return value;

      if (list.length == 1) {
        var e = list.first;
        return e is EntityReference ? e.id : e;
      }
    }

    return v;
  }

  /// Matches the left side of a comparison with [compare], one value at a
  /// time through a to-many relationship (as a SQL join of its rows).
  ///
  /// In `roles.type == "admin"`:
  /// - [keyValue] is the left side: the value of the [keys] (`roles.type`)
  ///   in the entity being matched. Through a to-many relationship (see
  ///   [hasToManyInKeyPath]) it's a list, one value per related entity
  ///   (`[admin, guest]`).
  /// - [compare] compares one left-side value with the right side: this
  ///   condition's [value] (`"admin"`), or its [ConditionParameter]'s value
  ///   (`?`, `?:name`).
  ///
  /// Through a to-many relationship, matches if [compare] matches any of its
  /// values; without related entities (an empty list), [compare] gets a
  /// single `null`. Otherwise (a field, also a list field), [keyValue] is
  /// compared as a whole.
  ///
  /// Why: on SQL, a to-many relationship is an outer join, one row per
  /// related entity, and an entity without related entities joins one row of
  /// `NULL`s. So `roles.type == null` matches a user without roles (`IS
  /// NULL`), and `roles.type == ?` with `['guest']` compares each role's
  /// type with the parameter (as a field's `number == ?` does).
  ///
  /// Used by [KeyConditionEQ] (`==`). [KeyConditionNotEQ] (`!=`) and
  /// [KeyConditionINBase] (`=~`/`!~`) handle a to-many the same way,
  /// directly (see `_notEquals` and `_matchesIn`).
  bool _matchesToManyOrValue(
    Object? keyValue,
    EntityHandler? entityHandler,
    bool Function(Object? leftValue) compare,
  ) {
    if (keyValue is Iterable && hasToManyInKeyPath(entityHandler)) {
      return keyValue.isEmpty ? compare(null) : keyValue.any(compare);
    }
    return compare(keyValue);
  }

  /// If a left side's value ([v], one compared by [_matchesToManyOrValue]) is
  /// `null`, for `== null` / `!= null` (`IS NULL` / `IS NOT NULL`).
  ///
  /// A list (a list field's value: a to-many's values are compared one at a
  /// time) is a value, never `null`, also with a `null` element
  /// (`['a', null]`): [equalsConditionValue] would compare its elements
  /// ("any is `null`").
  bool _isNullLeftValue(
    Object? v,
    TypeInfo? keyType,
    EntityHandler? keyEntityHandler,
  ) {
    if (v is Iterable) return false;
    return equalsConditionValue(
      v,
      null,
      keyType: keyType,
      keyEntityHandler: keyEntityHandler,
    );
  }

  @override
  void resolve({
    Condition? parent,
    required List<ConditionParameter> parameters,
  }) {
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
        value = fieldAccessor.getField(
          obj,
          key.name,
          entityHandler: objEntityHandler,
        );
      } else if (key is ConditionKeyIndex) {
        var index = key.index;

        if (obj is Iterable) {
          value = obj.elementAt(index);
        } else {
          throw StateError(
            "Can't access index[$index] of type: ${(obj as Object?).runtimeTypeNameUnsafe}",
          );
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

  KeyConditionValue? getEntityMapKeyValue(
    Map<String, dynamic>? entityMap, [
    EntityHandler<O>? entityHandler,
  ]) {
    if (entityMap == null || entityMap.isEmpty) return null;

    dynamic value = entityMap;
    TypeInfo? valueType = TypeInfo.from(
      entityHandler?.type ?? entityMap.runtimeType,
    );
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
        } else if (valueEntityHandler != null &&
            (value as Object).isPrimitiveValue) {
          // A related entity not resolved (only its ID: one stored by another
          // adapter, or a missing row): its ID field is the ID; any other
          // field is unknown, a `null` (as a SQL outer join's `NULL` row).
          keyValue = keyName == valueEntityHandler.idFieldName() ? value : null;
        } else {
          throw StateError(
            "Can't access key[$keyName] for type: ${(value as Object?).runtimeTypeNameUnsafe}",
          );
        }

        keyType = _resolveValueType(
          keyName,
          valueType,
          valueEntityHandler,
          keyValue,
        );
        keyEntityHandler = _resolveValueEntityHandler(
          keyType,
          valueEntityHandler,
        );
      } else if (key is ConditionKeyIndex) {
        var index = key.index;

        if (value is Iterable) {
          keyValue = value.elementAt(index);
          keyType = _resolveValueType(
            null,
            valueType,
            valueEntityHandler,
            keyValue,
          );
          keyEntityHandler = _resolveValueEntityHandler(
            keyType,
            valueEntityHandler,
          );
        } else {
          throw StateError(
            "Can't access index[$index] for type: ${(value as Object?).runtimeTypeNameUnsafe}",
          );
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

    return KeyConditionValue(
      _parseDecimalValue(value, valueType),
      valueType,
      valueEntityHandler,
    );
  }

  /// A [Decimal] field is kept as a `String` in an entity's `Map` (as in
  /// memory): parsed (also each of a to-many relationship's), so it's
  /// compared as a number (as SQL compares a `DECIMAL` column).
  static Object _parseDecimalValue(Object value, TypeInfo? valueType) {
    var type = valueType?.type;
    if (type != Decimal && type != DynamicNumber) return value;

    Object? parse(Object? v) => v is String ? (Decimal.from(v.trim()) ?? v) : v;

    if (value is List) return value.map(parse).toList();
    return parse(value)!;
  }

  /// If [type] is a to-many relationship's: an [EntityReferenceList], or a
  /// `List` of an entity type (one with an [EntityHandler], resolved from
  /// [entityHandler]). Not a `List` of enums or of other classes.
  static bool isToManyType(TypeInfo type, EntityHandler? entityHandler) {
    if (type.isEntityReferenceListType) return true;
    if (!type.isListEntity) return false;
    var elementType = type.arguments0;
    return elementType != null &&
        _resolveValueEntityHandler(elementType, entityHandler) != null;
  }

  /// If [type] is a relationship field's (see [isRelationshipKey]): a
  /// to-one, an [EntityReference] or an entity type (one with an
  /// [EntityHandler], resolved from [entityHandler]), or a to-many (see
  /// [isToManyType]).
  static bool isRelationshipType(TypeInfo type, EntityHandler? entityHandler) {
    if (type.isEntityReferenceBaseType) return true;
    if (type.isListEntity) return isToManyType(type, entityHandler);
    if (type.isPrimitiveType || type.isIterable || type.isMap) return false;
    return _resolveValueEntityHandler(type, entityHandler) != null;
  }

  static EntityHandler? _resolveValueEntityHandler(
    TypeInfo? objType,
    EntityHandler? objEntityHandler,
  ) {
    if (objType == null) return null;

    if (objType.isListEntityOrReference) {
      objType = objType.arguments0!;
    }

    if (objEntityHandler != null) {
      return objEntityHandler.getEntityHandler(type: objType.type);
    }

    var classReflection = ReflectionFactory().getRegisterClassReflection(
      objType.type,
    );

    return classReflection?.entityHandler ??
        EntityHandlerProvider.globalProvider.getEntityHandler(
          type: objType.type,
        );
  }

  TypeInfo? _resolveValueType(
    String? keyName,
    TypeInfo? objType,
    EntityHandler? objEntityHandler,
    Object? value,
  ) {
    if (keyName != null) {
      var type = objEntityHandler?.getFieldType(
        null,
        keyName,
        resolveFiledName: true,
      );
      if (type != null) return type;
    }

    if (value == null) {
      return null;
    } else if (value is List) {
      if (value.isNotEmpty) {
        return _resolveValueType(
          keyName,
          objType,
          objEntityHandler,
          value.first,
        );
      } else {
        return TypeInfo.from(value);
      }
    } else if (value is Map) {
      return objType ?? TypeInfo.from(value);
    }

    var t = objEntityHandler?.getEntityHandler(obj: value)?.typeInfo;
    return t;
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
  KeyConditionEQ<T> cast<T>() =>
      this is KeyConditionEQ<T>
            ? this as KeyConditionEQ<T>
            : KeyConditionEQ<T>(keys, value)
        .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    // `== []` is `== null`, `== [x]` is `== x` (see [_equalsRightValue]):
    var right = _equalsRightValue(
      keyValue,
      entityHandler,
      parameters,
      positionalParameters,
      namedParameters,
    );

    // Through a to-many relationship, each related entity's value (or a
    // `null` without any):
    return _matchesToManyOrValue(
      keyValue,
      entityHandler,
      (v) => right == null
          ? _isNullLeftValue(v, null, null)
          : equalsConditionValue(
              v,
              right,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
            ),
    );
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    // `== []` is `== null`, `== [x]` is `== x` (see [_equalsRightValue]):
    var right = _equalsRightValue(
      keyValue?.value,
      entityHandler,
      parameters,
      positionalParameters,
      namedParameters,
    );

    // Through a to-many relationship, each related entity's value (or a
    // `null` without any):
    return _matchesToManyOrValue(
      keyValue?.value,
      entityHandler,
      (v) => right == null
          ? _isNullLeftValue(v, keyValue?.type, keyValue?.entityHandler)
          : equalsConditionValue(
              v,
              right,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters,
              keyType: keyValue?.type,
              keyEntityHandler: keyValue?.entityHandler,
            ),
    );
  }

  @override
  String encode() => '$encodeKey == $encodeValue';
}

class KeyConditionNotEQ<O> extends KeyCondition<O, Object?> {
  KeyConditionNotEQ(super.keys, dynamic super.value);

  /// `true`, unless comparing with `null` (`IS NOT NULL`).
  @override
  bool get isNegated => value != null;

  @override
  KeyConditionNotEQ<T> cast<T>() =>
      this is KeyConditionNotEQ<T>
            ? this as KeyConditionNotEQ<T>
            : KeyConditionNotEQ<T>(keys, value)
        .._markResolved(resolved, _parent);

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return _notEquals(
      keyValue,
      null,
      entityHandler,
      parameters,
      positionalParameters,
      namedParameters,
    );
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return _notEquals(
      keyValue?.value,
      keyValue,
      entityHandler,
      parameters,
      positionalParameters,
      namedParameters,
    );
  }

  /// The values of a to-many relationship are compared one by one (as a SQL
  /// join of its rows): any of them not equal; without any (see
  /// [_isEmptyToMany]), as a `NULL` row (not equal to a value, but not
  /// `!= null`).
  bool _notEquals(
    Object? keyValue,
    KeyConditionValue? keyConditionValue,
    EntityHandler? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    // `!= []` is `!= null`, `!= [x]` is `!= x` (see [_equalsRightValue]):
    var right = _equalsRightValue(
      keyValue,
      entityHandler,
      parameters,
      positionalParameters,
      namedParameters,
    );

    // `!= null` (`IS NOT NULL`): with a value; a relationship, with some
    // related entity.
    if (right == null) {
      return _matchesToManyOrValue(
        keyValue,
        entityHandler,
        (v) => !_isNullLeftValue(
          v,
          keyConditionValue?.type,
          keyConditionValue?.entityHandler,
        ),
      );
    }

    bool notEquals(Object? v) => !equalsConditionValue(
      v,
      right,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      keyType: keyConditionValue?.type,
      keyEntityHandler: keyConditionValue?.entityHandler,
    );

    if (keyValue is Iterable && right is! Iterable) {
      if (_isEmptyToMany(keyValue, entityHandler)) return notEquals(null);
      return keyValue.isEmpty || keyValue.any(notEquals);
    }

    return notEquals(keyValue);
  }

  @override
  String encode() => '$encodeKey != $encodeValue';
}

/// The base of the ordering key conditions ([KeyConditionGreaterThan],
/// [KeyConditionGreaterThanOrEqual], [KeyConditionLessThan] and
/// [KeyConditionLessThanOrEqual]), which only differ by their [_ordering]:
/// matching and encoding are written once here. Each public subclass keeps
/// its own constructor and [cast].
abstract class _KeyConditionOrdering<O> extends KeyCondition<O, Object?> {
  _KeyConditionOrdering(super.keys, super.value);

  /// The comparison of this condition.
  _Ordering get _ordering;

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return _orderingConditionValue(
      _ordering,
      keyValue,
      value,
      parameters,
      positionalParameters,
      namedParameters,
      null,
    );
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return _orderingConditionValue(
      _ordering,
      keyValue?.value,
      value,
      parameters,
      positionalParameters,
      namedParameters,
      keyValue?.entityHandler,
    );
  }

  @override
  String encode() => '$encodeKey ${_ordering.symbol} $encodeValue';
}

class KeyConditionGreaterThan<O> extends _KeyConditionOrdering<O> {
  KeyConditionGreaterThan(super.keys, dynamic super.value);

  @override
  _Ordering get _ordering => _Ordering.gt;

  @override
  KeyConditionGreaterThan<T> cast<T>() =>
      this is KeyConditionGreaterThan<T>
            ? this as KeyConditionGreaterThan<T>
            : KeyConditionGreaterThan<T>(keys, value)
        .._markResolved(resolved, _parent);
}

class KeyConditionGreaterThanOrEqual<O> extends _KeyConditionOrdering<O> {
  KeyConditionGreaterThanOrEqual(super.keys, dynamic super.value);

  @override
  _Ordering get _ordering => _Ordering.gte;

  @override
  KeyConditionGreaterThanOrEqual<T> cast<T>() =>
      this is KeyConditionGreaterThanOrEqual<T>
            ? this as KeyConditionGreaterThanOrEqual<T>
            : KeyConditionGreaterThanOrEqual<T>(keys, value)
        .._markResolved(resolved, _parent);
}

class KeyConditionLessThan<O> extends _KeyConditionOrdering<O> {
  KeyConditionLessThan(super.keys, dynamic super.value);

  @override
  _Ordering get _ordering => _Ordering.lt;

  @override
  KeyConditionLessThan<T> cast<T>() =>
      this is KeyConditionLessThan<T>
            ? this as KeyConditionLessThan<T>
            : KeyConditionLessThan<T>(keys, value)
        .._markResolved(resolved, _parent);
}

class KeyConditionLessThanOrEqual<O> extends _KeyConditionOrdering<O> {
  KeyConditionLessThanOrEqual(super.keys, dynamic super.value);

  @override
  _Ordering get _ordering => _Ordering.lte;

  @override
  KeyConditionLessThanOrEqual<T> cast<T>() =>
      this is KeyConditionLessThanOrEqual<T>
            ? this as KeyConditionLessThanOrEqual<T>
            : KeyConditionLessThanOrEqual<T>(keys, value)
        .._markResolved(resolved, _parent);
}

abstract class KeyConditionINBase<O> extends KeyCondition<O, List<Object?>> {
  /// The values of an `IN` list.
  ///
  /// `x =~ null` is an empty set of values, as `x =~ []`: `=~` matches none
  /// and `!~` all (any field). An explicit `null` element (`x =~ [null]`,
  /// `x =~ [3, null]`) is kept: for a field (not a relationship, see
  /// [KeyCondition.isRelationshipKey]), it also matches a `null` (as
  /// `IS NULL`).
  static List<Object?> valuesAsList(dynamic value) {
    if (value == null) return [];

    if (value is List) return value;

    if (value is Iterable) return value.toList();

    if (value is Map) return value.values.toList();

    return [value];
  }

  final bool not;

  KeyConditionINBase(
    List<ConditionKey> keys,
    dynamic values, {
    this.not = false,
  }) : super(keys, valuesAsList(values));

  @override
  bool get isNegated => not;

  @override
  KeyConditionINBase<T> cast<T>();

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityKeyValue(o, entityHandler);

    return _matchesIn(
      keyValue,
      _isEmptyToMany(keyValue, entityHandler),
      isRelationshipKey(entityHandler),
      parameters,
      positionalParameters,
      namedParameters,
      null,
    );
  }

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var keyValue = getEntityMapKeyValue(o, entityHandler);

    return _matchesIn(
      keyValue?.value,
      _isEmptyToMany(keyValue?.value, entityHandler),
      isRelationshipKey(entityHandler),
      parameters,
      positionalParameters,
      namedParameters,
      entityHandler,
    );
  }

  /// The values of a to-many relationship are compared one by one (as a SQL
  /// join of its rows), with [not] (`NOT IN`): any of them not in. Without
  /// any ([emptyToMany], see [_isEmptyToMany]), as a `NULL` row (in a list
  /// with a `null`; also `NOT IN` a list without one).
  ///
  /// With a [relationshipKey] (see [isRelationshipKey]), the related
  /// entities' IDs are matched with a set of IDs, without `null`s (see
  /// [_matchesRelationshipIn]).
  bool _matchesIn(
    Object? keyValue,
    bool emptyToMany,
    bool relationshipKey,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  ) {
    if (relationshipKey) {
      return _matchesRelationshipIn(
        keyValue,
        emptyToMany,
        parameters,
        positionalParameters,
        namedParameters,
        entityHandler,
      );
    }

    // `x =~ ?` with `null`: an empty set, as `x =~ null` and `x =~ []`
    // (`=~` matches none, `!~` all).
    if (_isNullParameterSet(
      parameters,
      positionalParameters,
      namedParameters,
    )) {
      return not;
    }

    // References on the right side (a path ending in a reference,
    // `owner.userInfo =~ ?`): compared by their IDs, as SQL.
    var rightValues =
        _rightValuesWithReferencesAsIDs(
          parameters,
          positionalParameters,
          namedParameters,
        ) ??
        value;

    bool inValues(Object? v) => inConditionValues(
      v,
      rightValues,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      entityHandler: entityHandler,
    );

    if (emptyToMany) return inValues(null) != not;

    if (not && keyValue is Iterable) {
      return keyValue.isEmpty || keyValue.any((v) => !inValues(v));
    }

    return inValues(keyValue) != not;
  }

  /// The right side of a `=~`/`!~` ([value]) with its parameters resolved,
  /// and its [EntityReference]s (also an [EntityReferenceList]'s) as their
  /// IDs (an empty reference: a `null` element). Returns `null` if there's
  /// no reference: [value] is compared as before (its parameters resolved
  /// while compared).
  List<Object?>? _rightValuesWithReferencesAsIDs(
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    var hasReference = false;
    var resolved = <Object?>[];

    void add(Object? v) {
      if (v is EntityReference) {
        hasReference = true;
        resolved.add(v.id);
      } else if (v is EntityReferenceList) {
        hasReference = true;
        resolved.addAll(v.ids ?? const []);
      } else if (v is Iterable) {
        for (var e in v) {
          add(e);
        }
      } else {
        resolved.add(v);
      }
    }

    for (var v in value) {
      add(
        v is ConditionParameter
            ? v.getValue(
                parameters: parameters,
                positionalParameters: positionalParameters,
                namedParameters: namedParameters,
              )
            : v,
      );
    }

    return hasReference ? resolved : null;
  }

  /// A relationship's `=~`/`!~` (see [isRelationshipKey]): the left side
  /// ([keyValue]) is the related entities' IDs (a to-one's, or a to-many's
  /// list); the right side is the set of IDs (or entities) to match
  /// ([_relationshipRightIDs]: [value] with its parameters resolved, and
  /// without `null`s).
  ///
  /// - An empty set (`[]`, `null`, `[null]`, a `null` parameter): `=~`
  ///   matches none and `!~` all (a relationship never has a `null` ID).
  /// - Without related entities (a `null` to-one, an empty to-many): in no
  ///   set (`=~` doesn't match, `!~` does).
  /// - A to-many: `=~` if any related ID is in the set, `!~` if any isn't
  ///   (as a SQL join of its rows).
  bool _matchesRelationshipIn(
    Object? keyValue,
    bool emptyToMany,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    EntityHandler? entityHandler,
  ) {
    var ids = _relationshipRightIDs(
      parameters,
      positionalParameters,
      namedParameters,
    );
    if (ids.isEmpty) return not;

    if (keyValue == null ||
        emptyToMany ||
        (keyValue is Iterable && keyValue.isEmpty)) {
      return not;
    }

    bool inIDs(Object? v) =>
        inConditionValues(v, ids, entityHandler: entityHandler);

    if (keyValue is Iterable) {
      return not ? keyValue.any((v) => !inIDs(v)) : keyValue.any(inIDs);
    }

    return inIDs(keyValue) != not;
  }

  @override
  String encode() => '$encodeKey ${not ? '!' : '='}~ $encodeValue';
}

class KeyConditionIN<O> extends KeyConditionINBase<O> {
  KeyConditionIN(super.keys, super.values);

  @override
  KeyConditionIN<T> cast<T>() =>
      this is KeyConditionIN<T>
            ? this as KeyConditionIN<T>
            : KeyConditionIN<T>(keys, value)
        .._markResolved(resolved, _parent);
}

class KeyConditionNotIN<O> extends KeyConditionINBase<O> {
  KeyConditionNotIN(super.keys, super.values) : super(not: true);

  @override
  KeyConditionNotIN<T> cast<T>() =>
      this is KeyConditionNotIN<T>
            ? this as KeyConditionNotIN<T>
            : KeyConditionNotIN<T>(keys, value)
        .._markResolved(resolved, _parent);
}

/// A regular expression condition: `key =~ /pattern/flags` (matches) or
/// `key !~ /pattern/flags` (does not match).
///
/// The pattern is a [String] or a [ConditionParameter] (`/?/`, `/?#1/`,
/// `/?:name/`), whose value is a [String] or a [RegExp] (only its
/// [RegExp.pattern] and [RegExp.isCaseSensitive] are used).
///
/// The only flag is `i` ([caseInsensitive]). The matching is the same in every
/// adapter (PostgreSQL's semantics):
/// - The pattern matches anywhere in the value (use `^...$` for all of it).
/// - `.` also matches a line terminator.
/// - `^` and `$` match only at the start and end of the whole value.
///
/// A value that is not a [String] is matched by its text (an [Enum] by its
/// name). A `null` value matches `!~` and not `=~` (as `!=` and `!~ [...]`).
/// A list value (e.g. of a relationship) matches `=~` if any element matches,
/// and `!~` if any element does not match (as a SQL join of its rows).
class KeyConditionRegExp<O> extends KeyCondition<O, Object> {
  /// If `true`, the condition is `!~` (does not match).
  final bool not;

  @override
  bool get isNegated => not;

  /// The `i` flag.
  final bool caseInsensitive;

  /// Creates a regular expression condition. [pattern] can be a [String], a
  /// [RegExp] (a case-insensitive one sets [caseInsensitive]) or a
  /// [ConditionParameter].
  ///
  /// Throws a [FormatException] for an invalid pattern.
  KeyConditionRegExp(
    List<ConditionKey> keys,
    Object pattern, {
    bool caseInsensitive = false,
    this.not = false,
  }) : caseInsensitive =
           caseInsensitive || (pattern is RegExp && !pattern.isCaseSensitive),
       super(keys, _normalizePattern(pattern));

  static Object _normalizePattern(Object pattern) {
    if (pattern is ConditionParameter) return pattern;

    var s = pattern is RegExp ? pattern.pattern : pattern;
    if (s is! String) {
      throw ArgumentError.value(
        pattern,
        'pattern',
        'Not a `String`, `RegExp` or `ConditionParameter`',
      );
    }

    // Validates it (throws a `FormatException`):
    toDartRegExp(s);
    return s;
  }

  /// The pattern, if not a [ConditionParameter].
  String? get pattern {
    var value = this.value;
    return value is String ? value : null;
  }

  /// The pattern's [ConditionParameter], if any.
  ConditionParameter? get patternParameter {
    var value = this.value;
    return value is ConditionParameter ? value : null;
  }

  static final Map<(String, bool), RegExp> _regExpCache = {};

  /// The Dart [RegExp] with the semantics of a [KeyConditionRegExp]: `.`
  /// matches a line terminator (`dotAll`) and `^`/`$` only the start/end of
  /// the whole input (not `multiLine`). It's `unicode` (by code point) if the
  /// [pattern] is valid in that stricter mode (e.g. not with `\-`). Cached.
  ///
  /// Throws a [FormatException] for an invalid [pattern].
  static RegExp toDartRegExp(String pattern, {bool caseInsensitive = false}) {
    var key = (pattern, caseInsensitive);
    var regExp = _regExpCache[key];
    if (regExp != null) return regExp;

    RegExp compile(bool unicode) => RegExp(
      pattern,
      caseSensitive: !caseInsensitive,
      dotAll: true,
      multiLine: false,
      unicode: unicode,
    );

    try {
      // By code point (as the databases), when the pattern is valid in the
      // stricter `unicode` mode:
      regExp = compile(true);
    } on FormatException {
      // E.g. an identity escape (`\-`, `\@`), valid in the databases:
      regExp = compile(false);
    }

    if (_regExpCache.length >= 256) {
      _regExpCache.remove(_regExpCache.keys.first);
    }
    _regExpCache[key] = regExp;

    return regExp;
  }

  /// The text of a [value] to match: an [Enum] by its name, otherwise by its
  /// [Object.toString].
  static String valueToText(Object value) =>
      value is Enum ? value.name : value.toString();

  /// Resolves the pattern of this condition and its `i` flag, with the
  /// value of its [ConditionParameter], if any.
  ///
  /// Throws an [ArgumentError] if the parameter's value is not a [String] or
  /// a [RegExp].
  (String pattern, bool caseInsensitive) resolvePattern({
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Map<String, Object?>? encodingParameters,
  }) {
    var value = this.value;

    if (value is String) return (value, caseInsensitive);

    var parameter = value as ConditionParameter;
    var paramValue = parameter.getValue(
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      encodingParameters: encodingParameters,
    );

    return resolvePatternValue(paramValue, caseInsensitive: caseInsensitive);
  }

  /// Resolves a pattern parameter's [value] ([String] or [RegExp]) and its
  /// `i` flag (from [caseInsensitive] or a case-insensitive [RegExp]).
  static (String pattern, bool caseInsensitive) resolvePatternValue(
    Object? value, {
    bool caseInsensitive = false,
  }) {
    if (value is String) {
      return (value, caseInsensitive);
    } else if (value is RegExp) {
      return (value.pattern, caseInsensitive || !value.isCaseSensitive);
    } else {
      throw ArgumentError(
        'A regexp pattern parameter must be a `String` or a `RegExp`, '
        'not: ${value?.runtimeTypeNameUnsafe ?? 'null'}',
      );
    }
  }

  /// A cache of the [RegExp] of a literal [pattern] (without a parameter),
  /// filled by [_resolveRegExp].
  ///
  /// Why: a literal pattern never changes, and a condition is matched once
  /// per entity (an in-memory select): compiled once, not once per entity.
  RegExp? _literalRegExpCache;

  /// The [RegExp] of this condition, with its parameter's value, if any.
  ///
  /// A parameter's value is resolved on each call (not cached by the
  /// parameters instances: their content can change), but its [RegExp] is
  /// cached by [toDartRegExp].
  RegExp _resolveRegExp(
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    var pattern = this.pattern;
    if (pattern != null) {
      return _literalRegExpCache ??= toDartRegExp(
        pattern,
        caseInsensitive: caseInsensitive,
      );
    }

    var (paramPattern, paramCaseInsensitive) = resolvePattern(
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    );

    return toDartRegExp(paramPattern, caseInsensitive: paramCaseInsensitive);
  }

  /// Matches a [keyValue] with [regExp] (see the class documentation). An
  /// entity (or reference) is matched by its ID.
  bool matchesValue(
    Object? keyValue,
    RegExp regExp, {
    EntityHandler? entityHandler,
  }) {
    // A `null` matches only `!~` (as `!=` and `!~ [...]`):
    bool matchesText(Object? v) =>
        v == null ? not : regExp.hasMatch(valueToText(v)) != not;

    if (keyValue == null) return not;

    // The values of a to-many relationship: any of them (as a SQL join of its
    // rows: a `null`, e.g. an unsaved reference, isn't a row); without any,
    // `!~` matches (a `NULL` row).
    Iterable<Object>? values;
    if (keyValue is EntityReferenceList) {
      values = (keyValue.ids ?? const []).nonNulls;
    } else if (keyValue is Iterable) {
      values = keyValue.map((v) => _entityID(v, entityHandler)).nonNulls;
    }

    if (values != null) {
      return (not && values.isEmpty) || values.any(matchesText);
    }

    return matchesText(_entityID(keyValue, entityHandler));
  }

  /// The ID of [value], if it's an entity or a reference, otherwise [value].
  static Object? _entityID(Object? value, EntityHandler? entityHandler) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is Enum ||
        value is DateTime) {
      return value;
    }

    if (value is EntityReference) return value.id;

    var handler = entityHandler?.getEntityHandler(obj: value);
    if (handler != null && handler.type == value.runtimeType) {
      return handler.getID(value);
    }

    return value;
  }

  bool _matches(
    Object? keyValue,
    EntityHandler? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  ) {
    if (keyValue == null) return not;

    var regExp = _resolveRegExp(
      parameters,
      positionalParameters,
      namedParameters,
    );

    return matchesValue(keyValue, regExp, entityHandler: entityHandler);
  }

  @override
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => _matches(
    getEntityKeyValue(o, entityHandler),
    entityHandler,
    parameters,
    positionalParameters,
    namedParameters,
  );

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => _matches(
    getEntityMapKeyValue(o, entityHandler)?.value,
    entityHandler,
    parameters,
    positionalParameters,
    namedParameters,
  );

  @override
  KeyConditionRegExp<T> cast<T>() =>
      this is KeyConditionRegExp<T>
            ? this as KeyConditionRegExp<T>
            : KeyConditionRegExp<T>(
                keys,
                value,
                caseInsensitive: caseInsensitive,
                not: not,
              )
        .._markResolved(resolved, _parent);

  /// Encodes [pattern] as a regexp literal's body: `/` escaped as `\/`.
  static String encodePatternLiteral(String pattern) {
    var s = StringBuffer();

    for (var i = 0; i < pattern.length; ++i) {
      var c = pattern[i];
      if (c == r'\' && i + 1 < pattern.length) {
        s.write(c);
        s.write(pattern[++i]);
      } else if (c == '/') {
        s.write(r'\/');
      } else {
        s.write(c);
      }
    }

    return s.toString();
  }

  /// A regexp is encoded as `/pattern/flags`, not as a JSON value.
  @override
  String get encodeValue {
    var value = this.value;
    var body = value is String ? encodePatternLiteral(value) : value.toString();
    return '/$body/${caseInsensitive ? 'i' : ''}';
  }

  @override
  String encode() => '$encodeKey ${not ? '!' : '='}~ $encodeValue';
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
  bool matchesEntity(
    O o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => condition.matchesEntity(
    o,
    entityHandler: entityHandler,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
  );

  @override
  bool matchesEntityMap(
    Map<String, dynamic> o, {
    EntityHandler<O>? entityHandler,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => condition.matchesEntityMap(
    o,
    entityHandler: entityHandler,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
  );
}
