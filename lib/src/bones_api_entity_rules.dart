import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_extension.dart';

abstract class EntityRules<R extends EntityRules<R>> {
  final bool? _innocuous;

  const EntityRules(this._innocuous);

  /// Returns `true` if this instance is innocuous (no resolution rules to apply).
  bool get isInnocuous;

  /// Return `true` if this instance rules are valid.
  bool get isValid;

  /// Validates this instances rules.
  /// See [isValid].
  void validate();

  /// Merges `this` rules with [other] rules.
  R merge(R? other);

  Map<String, Object?> toJson();
}

/// [EntityRules.validate] error.
class ValidateEntityRulesError<R extends EntityRules<R>> extends Error {
  final R rules;
  final String message;

  ValidateEntityRulesError(this.rules, this.message);

  @override
  String toString() => "Error validating `$R`: $message >> $rules";
}

/// [EntityRules.merge] error.
class MergeEntityRulesError<R extends EntityRules<R>> extends Error {
  final R a;
  final R b;

  final String conflict;

  MergeEntityRulesError(this.a, this.b, this.conflict);

  @override
  String toString() => "Can't merge `$R`! Conflict: $conflict >> $a <!> $b";
}

/// An [EntityAccessRules] type.
enum EntityAccessRuleType { allow, block }

/// An [EntityAccessRules.condition].
typedef EntityAccessRulesCondition = bool Function(
    EntityAccessRulesContext? context);

/// An [EntityAccessRules] context passed to rules with a condition ([EntityAccessRulesCondition]).
class EntityAccessRulesContext {
  final EntityAccessRules accessRules;
  final Object object;
  final Object? context;

  EntityAccessRulesContext(this.accessRules, this.object, {this.context});

  T? objectAs<T>() => object.as<T>();

  List<T> objectAsListOf<T>() => object.asListOf<T>();

  T? contextAs<T>() => context.as<T>();

  List<T> contextAsListOf<T>() => context.asListOf<T>();

  @override
  String toString() =>
      'EntityAccessRulesContext->$accessRules@$object+${context ?? ''}';
}

/// Rules to access entities.
/// Used by [APIServer] responses.
class EntityAccessRules extends EntityRules<EntityAccessRules> {
  /// A `const` instance without any resolution rules to apply.
  static const EntityAccessRules innocuous = _EntityAccessRulesInnocuos();

  final EntityAccessRuleType? ruleType;
  final Type? entityType;
  final List<String>? entityFields;

  final List<EntityAccessRules>? rules;

  final EntityAccessRulesCondition? condition;

  final bool _simplified;

  const EntityAccessRules(
      {this.ruleType,
      this.entityType,
      this.entityFields,
      this.rules,
      this.condition})
      : _simplified = false,
        super(ruleType == null &&
            entityType == null &&
            entityFields == null &&
            rules == null);

  const EntityAccessRules._simplified(this.ruleType, this.entityType,
      this.entityFields, this.rules, this.condition)
      : _simplified = true,
        super(false);

  const EntityAccessRules.group(List<EntityAccessRules> rules)
      :
        // ignore: prefer_initializing_formals
        rules = rules,
        ruleType = null,
        entityType = null,
        entityFields = null,
        condition = null,
        _simplified = false,
        super(false);

  const EntityAccessRules.block(Type entityType,
      {this.entityFields, this.condition})
      :
        // ignore: prefer_initializing_formals
        entityType = entityType,
        ruleType = EntityAccessRuleType.block,
        rules = null,
        _simplified = false,
        super(false);

  const EntityAccessRules.blockFields(
      Type entityType, List<String> entityFields,
      {EntityAccessRulesCondition? condition})
      : this.block(entityType,
            entityFields: entityFields, condition: condition);

  const EntityAccessRules.allow(Type entityType,
      {this.entityFields, this.condition})
      :
        // ignore: prefer_initializing_formals
        entityType = entityType,
        ruleType = EntityAccessRuleType.allow,
        rules = null,
        _simplified = false,
        super(false);

  const EntityAccessRules.allowFields(
      Type entityType, List<String> entityFields,
      {EntityAccessRulesCondition? condition})
      : this.allow(entityType,
            entityFields: entityFields, condition: condition);

  /// Returns `true` if this instance is equivalent to [innocuous] instance (no resolution rules to apply).
  @override
  bool get isInnocuous {
    var innocuous = _innocuous;
    if (innocuous != null) return innocuous;

    return _isInnocuousImpl();
  }

  bool _isInnocuousImpl() {
    if (ruleType != null || entityType != null) return false;

    final entityFields = this.entityFields;
    final hasEntityFields = (entityFields != null && entityFields.isNotEmpty);

    if (hasEntityFields) return false;

    var rules = this.rules;
    if (rules != null && rules.isNotEmpty) {
      return rules.every((r) => r.isInnocuous);
    }

    return true;
  }

  @override
  bool get isValid => true;

  @override
  void validate() {}

  bool hasRuleForEntityType(Type type) {
    if (isInnocuous) return false;

    if (entityType == type) return true;

    final rules = this.rules;
    return rules != null && rules.any((r) => r.hasRuleForEntityType(type));
  }

  bool? isAllowedEntityType(Type type) {
    if (isInnocuous) return null;

    if (entityType == type) {
      if (ruleType == EntityAccessRuleType.allow) {
        // If allows a field also allows a type (not checking `entityFields`):
        return true;
      } else if (ruleType == EntityAccessRuleType.block) {
        final entityFields = this.entityFields;
        var fieldRule = entityFields != null && entityFields.isNotEmpty;

        // If blocks a field it's not fully blocking a type:
        if (fieldRule) {
          return true;
        }
        // If there's NO field rule, the type is being blocked:
        else {
          return false;
        }
      }
    }

    final rules = this.rules;
    if (rules == null || rules.isEmpty) return null;

    for (var r in rules.reversed) {
      var allowed = r.isAllowedEntityType(type);
      if (allowed != null) return allowed;
    }

    return null;
  }

  bool hasRuleForEntityTypeField(Type type) {
    if (isInnocuous) return false;

    if (entityType == type) {
      var entityFields = this.entityFields;
      return entityFields != null && entityFields.isNotEmpty;
    }

    final rules = this.rules;
    return rules != null && rules.any((r) => r.hasRuleForEntityTypeField(type));
  }

  bool? isAllowedEntityTypeField(Type type, String field,
      {EntityAccessRulesContext? context}) {
    if (isInnocuous) return null;

    final entityFields = this.entityFields;

    if (entityType == type) {
      final condition = this.condition;

      if (ruleType == EntityAccessRuleType.allow) {
        if (entityFields.anyIgnoreCase(field)) {
          return (condition == null || condition(context));
        } else {
          return null;
        }
      } else if (ruleType == EntityAccessRuleType.block) {
        if (entityFields.anyIgnoreCase(field)) {
          return !(condition == null || condition(context));
        } else {
          return null;
        }
      }
    }

    final rules = this.rules;
    if (rules == null || rules.isEmpty) return null;

    for (var r in rules.reversed) {
      var allowed = r.isAllowedEntityTypeField(type, field, context: context);
      if (allowed != null) return allowed;
    }

    return null;
  }

  EntityAccessRules copyWith({
    EntityAccessRuleType? ruleType,
    Type? entityType,
    List<String>? entityFields,
    List<EntityAccessRules>? rules,
    EntityAccessRulesCondition? condition,
  }) {
    rules ??= this.rules;

    rules = rules.nullIfEmpty();

    return EntityAccessRules(
      ruleType: ruleType ?? this.ruleType,
      entityType: entityType ?? this.entityType,
      entityFields: entityFields ?? this.entityFields,
      rules: rules,
      condition: condition ?? this.condition,
    );
  }

  EntityAccessRules simplified() {
    if (_simplified) return this;

    if (isInnocuous) return EntityAccessRules.innocuous;

    var s = _simplifiedImpl();

    return s._isInnocuousImpl()
        ? EntityAccessRules.innocuous
        : EntityAccessRules._simplified(
            s.ruleType, s.entityType, s.entityFields, s.rules, s.condition);
  }

  EntityAccessRules _simplifiedImpl() {
    var rules = this.rules;
    if (rules == null || rules.isEmpty) return this;

    final rulesSimple =
        rules.where((r) => !r.isInnocuous).map((r) => r.simplified());

    var rulesSimpleFlat = rulesSimple.expand((r) {
      var rules = r.rules;
      return rules != null && rules.isNotEmpty && r.entityType == null
          ? rules
          : [r];
    }).toList();

    if (entityType != null) {
      var r1 = copyWith(rules: []);

      return rulesSimpleFlat.isEmpty
          ? r1
          : EntityAccessRules.group([r1, ...rulesSimpleFlat]);
    } else {
      if (rulesSimpleFlat.isEmpty) {
        return EntityAccessRules.innocuous;
      } else if (rulesSimpleFlat.length == 1) {
        return rulesSimpleFlat.first;
      } else {
        return EntityAccessRules(rules: rulesSimpleFlat);
      }
    }
  }

  @override
  EntityAccessRules merge(EntityAccessRules? other) {
    if (other == null || other.isInnocuous || identical(this, other)) {
      return isInnocuous ? innocuous : this;
    } else if (isInnocuous) {
      return other;
    }

    var a = simplified();
    var b = other.simplified();

    var rulesA = a.rules;
    var rulesB = b.rules;

    var listA = rulesA != null && rulesA.isNotEmpty && a.entityType == null
        ? rulesA
        : [a];

    var listB = rulesB != null && rulesB.isNotEmpty && b.entityType == null
        ? rulesB
        : [b];

    var allRules = [...listA, ...listB];

    return EntityAccessRules.group(allRules);
  }

  static final _rulesListEquality = ListEquality<EntityAccessRules>();

  @override
  bool operator ==(Object other) =>
      other is EntityAccessRules && simplified()._equals(other.simplified());

  bool _equals(EntityAccessRules other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          ruleType == other.ruleType &&
          entityType == other.entityType &&
          entityFields == other.entityFields &&
          identical(condition, other.condition) &&
          _rulesListEquality.equals(rules, other.rules);

  @override
  int get hashCode => simplified()._hashCode();

  int _hashCode() =>
      ruleType.hashCode ^
      entityType.hashCode ^
      entityFields.hashCode ^
      condition.hashCode ^
      _rulesListEquality.hash(rules);

  @override
  String toString() {
    if (isInnocuous) return 'EntityAccessRules{innocuous}';

    final ruleType = this.ruleType;
    var ruleTypeStr = ruleType != null ? '[${ruleType.name}]' : '';

    var props = [
      if (entityType != null) 'entityType: $entityType',
      if (entityFields != null && entityFields!.isNotEmpty)
        'entityFields: $entityFields',
      if (condition != null) 'condition: #${condition.hashCode}',
    ];

    var propsStr = props.isNotEmpty ? '{${props.join(', ')}}' : '';

    final rules = this.rules;
    var rulesStr = rules != null && rules.isNotEmpty
        ? '<\n  ${rules.join('\n  ')}\n>'
        : '';

    return 'EntityAccessRules$ruleTypeStr$propsStr$rulesStr';
  }

  @override
  Map<String, Object?> toJson() => isInnocuous
      ? <String, Object?>{}
      : <String, Object?>{
          if (ruleType != null) 'ruleType': ruleType?.name,
          if (entityType != null) 'entityType': '$entityType',
          if (entityFields != null && entityFields!.isNotEmpty)
            'entityFields': entityFields,
          if (rules != null && rules!.isNotEmpty)
            'rules': rules!.map((e) => e.toJson()).toList(),
        };
}

/// An [EntityAccessRules] with cache for some calls.
class EntityAccessRulesCached implements EntityAccessRules {
  final EntityAccessRules accessRules;

  EntityAccessRulesCached(this.accessRules);

  @override
  bool? get _innocuous => accessRules._innocuous;

  @override
  bool get isInnocuous => accessRules.isInnocuous;

  @override
  bool _isInnocuousImpl() => accessRules._isInnocuousImpl();

  @override
  bool get isValid => accessRules.isValid;

  @override
  void validate() => accessRules.validate();

  @override
  List<String>? get entityFields => accessRules.entityFields;

  @override
  Type? get entityType => accessRules.entityType;

  @override
  EntityAccessRuleType? get ruleType => accessRules.ruleType;

  @override
  List<EntityAccessRules>? get rules => accessRules.rules;

  @override
  EntityAccessRulesCondition? get condition => accessRules.condition;

  @override
  bool get _simplified => accessRules._simplified;

  final Map<Type, bool> _hasRuleForEntityType = <Type, bool>{};

  @override
  bool hasRuleForEntityType(Type type) => _hasRuleForEntityType.putIfAbsent(
      type, () => accessRules.hasRuleForEntityType(type));

  final Map<Type, bool> _hasRuleForEntityTypeField = <Type, bool>{};

  @override
  bool hasRuleForEntityTypeField(Type type) => _hasRuleForEntityTypeField
      .putIfAbsent(type, () => accessRules.hasRuleForEntityTypeField(type));

  @override
  bool? isAllowedEntityType(Type type) => accessRules.isAllowedEntityType(type);

  @override
  bool? isAllowedEntityTypeField(Type type, String field,
          {EntityAccessRulesContext? context}) =>
      accessRules.isAllowedEntityTypeField(type, field, context: context);

  @override
  EntityAccessRules copyWith({
    EntityAccessRuleType? ruleType,
    Type? entityType,
    List<String>? entityFields,
    List<EntityAccessRules>? rules,
    EntityAccessRulesCondition? condition,
  }) =>
      accessRules.copyWith(
        ruleType: ruleType,
        entityType: entityType,
        entityFields: entityFields,
        rules: rules,
        condition: condition,
      );

  @override
  EntityAccessRules merge(EntityAccessRules? other) => accessRules.merge(other);

  @override
  EntityAccessRules simplified() => accessRules.simplified();

  @override
  EntityAccessRules _simplifiedImpl() => accessRules._simplifiedImpl();

  @override
  bool operator ==(Object other) => accessRules == other;

  @override
  bool _equals(EntityAccessRules other) => accessRules._equals(other);

  @override
  int get hashCode => accessRules.hashCode;

  @override
  int _hashCode() => accessRules._hashCode();

  @override
  String toString() => accessRules.toString();

  @override
  Map<String, Object?> toJson() => accessRules.toJson();
}

class _EntityAccessRulesInnocuos implements EntityAccessRules {
  const _EntityAccessRulesInnocuos();

  @override
  bool? get _innocuous => true;

  @override
  bool get _simplified => true;

  @override
  EntityAccessRules _simplifiedImpl() => this;

  @override
  EntityAccessRules copyWith({
    EntityAccessRuleType? ruleType,
    Type? entityType,
    List<String>? entityFields,
    List<EntityAccessRules>? rules,
    EntityAccessRulesCondition? condition,
  }) =>
      EntityAccessRules(
        ruleType: ruleType,
        entityType: entityType,
        entityFields: entityFields,
        rules: rules,
        condition: condition,
      );

  @override
  bool get isInnocuous => true;

  @override
  bool _isInnocuousImpl() => true;

  @override
  bool get isValid => true;

  @override
  void validate() {}

  @override
  EntityAccessRuleType? get ruleType => null;

  @override
  List<EntityAccessRules>? get rules => null;

  @override
  List<String>? get entityFields => null;

  @override
  Type? get entityType => null;

  @override
  EntityAccessRulesCondition? get condition => null;

  @override
  bool hasRuleForEntityType(Type type) => false;

  @override
  bool hasRuleForEntityTypeField(Type type) => false;

  @override
  bool? isAllowedEntityType(Type type) => null;

  @override
  bool? isAllowedEntityTypeField(Type type, String field,
          {EntityAccessRulesContext? context}) =>
      null;

  @override
  EntityAccessRules simplified() => this;

  @override
  EntityAccessRules merge(EntityAccessRules? other) {
    if (other != null) {
      return other.isInnocuous ? EntityAccessRules.innocuous : other;
    } else {
      return this;
    }
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{};

  @override
  bool _equals(EntityAccessRules other) => this == other;

  @override
  int _hashCode() => hashCode;

  @override
  String toString() => 'EntityAccessRules{innocuous}';
}

/// Rules to resolve entities.
/// Used by [EntityHandler] and [DBEntityRepository].
class EntityResolutionRules extends EntityRules<EntityResolutionRules> {
  /// A `const` instance without any resolution rules to apply.
  static const EntityResolutionRules innocuous =
      _EntityResolutionRulesInnocuous();

  static final EntityResolutionRules instanceAllEager =
      EntityResolutionRules.fetch(allEager: true);

  final bool? _allowEntityFetch;

  /// If `true` it will allow the use of on DB/repository to fetch an entity by an ID reference.
  bool get allowEntityFetch =>
      _allowEntityFetch ??
      allEager ??
      (eagerEntityTypes != null && eagerEntityTypes!.isNotEmpty);

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

  /// If `true` it will be ignored on a conflicting merge.
  final bool mergeTolerant;

  const EntityResolutionRules(
      {bool? allowEntityFetch,
      this.allowReadFile = false,
      this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager,
      this.mergeTolerant = false})
      : _allowEntityFetch = allowEntityFetch,
        super((allowEntityFetch != null ||
                allEager != null ||
                allLazy != null ||
                allowReadFile ||
                mergeTolerant)
            ? false
            : (lazyEntityTypes == null && eagerEntityTypes == null)
                ? true
                : null);

  const EntityResolutionRules.fetch(
      {this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager,
      this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        super(false);

  const EntityResolutionRules.fetchEager(this.eagerEntityTypes,
      {this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = null,
        super(false);

  const EntityResolutionRules.fetchLazy(this.lazyEntityTypes,
      {this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        allLazy = null,
        allEager = null,
        super(false);

  const EntityResolutionRules.fetchEagerAll({this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = true,
        super(false);

  const EntityResolutionRules.fetchLazyAll({this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = true,
        allEager = false,
        super(false);

  /// Returns `true` if this instance is equivalent to [innocuous] instance (no resolution rules to apply).
  @override
  bool get isInnocuous {
    var innocuous = _innocuous;
    if (innocuous != null) return innocuous;

    if (_allowEntityFetch != null ||
        allEager != null ||
        allLazy != null ||
        allowReadFile ||
        mergeTolerant) {
      return false;
    }

    final eagerEntityTypes = this.eagerEntityTypes;
    final lazyEntityTypes = this.lazyEntityTypes;

    return (eagerEntityTypes == null || eagerEntityTypes.isEmpty) &&
        (lazyEntityTypes == null || lazyEntityTypes.isEmpty);
  }

  @override
  bool get isValid => _validateImpl() == null;

  @override
  void validate() {
    var error = _validateImpl();
    if (error != null) {
      throw ValidateEntityRulesError(this, error);
    }
  }

  String? _validateImpl() {
    var conflict = _hasConflictingEntityTypes();
    if (conflict != null) {
      return "Conflicting `eagerEntityTypes` and `lazyEntityTypes`: $conflict";
    }
    return null;
  }

  List<Type>? _hasConflictingEntityTypes() {
    var eagerEntityTypes = this.eagerEntityTypes;
    var lazyEntityTypes = this.lazyEntityTypes;

    if (eagerEntityTypes != null &&
        lazyEntityTypes != null &&
        eagerEntityTypes.isNotEmpty &&
        lazyEntityTypes.isNotEmpty) {
      if (eagerEntityTypes.any((t) => lazyEntityTypes.contains(t))) {
        var conflict =
            eagerEntityTypes.where((t) => lazyEntityTypes.contains(t)).toList();
        return conflict;
      }
    }

    return null;
  }

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

  /// Alias to [isEagerEntityType] with a [TypeInfo] parameter.
  bool isEagerEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) {
    var entityType = entityTypeInfo.entityType;
    return entityType != null ? isEagerEntityType(entityType, def) : false;
  }

  /// Alias to [isLazyEntityType] with a [TypeInfo] parameter.
  bool isLazyEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) {
    var entityType = entityTypeInfo.entityType;
    return entityType != null ? isLazyEntityType(entityType, def) : false;
  }

  /// Copies this instance, allowing fields overwrite.
  /// - [conflictingEntityTypes] informs the [Type]s to remove from [lazyEntityTypes] and [eagerEntityTypes].
  EntityResolutionRules copyWith({
    bool? allowEntityFetch,
    bool? allowReadFile,
    List<Type>? lazyEntityTypes,
    List<Type>? eagerEntityTypes,
    bool? allLazy,
    bool? allEager,
    bool? mergeTolerant,
    List<Type>? conflictingEntityTypes,
  }) {
    lazyEntityTypes ??= this.lazyEntityTypes;
    eagerEntityTypes ??= this.eagerEntityTypes;

    if (conflictingEntityTypes != null && conflictingEntityTypes.isNotEmpty) {
      lazyEntityTypes = lazyEntityTypes.without(conflictingEntityTypes);
      eagerEntityTypes = eagerEntityTypes.without(conflictingEntityTypes);
    }

    lazyEntityTypes = lazyEntityTypes.nullIfEmpty();
    eagerEntityTypes = eagerEntityTypes.nullIfEmpty();

    var resolutionRules = EntityResolutionRules(
      allowEntityFetch: allowEntityFetch ?? _allowEntityFetch,
      allowReadFile: allowReadFile ?? this.allowReadFile,
      lazyEntityTypes: lazyEntityTypes,
      eagerEntityTypes: eagerEntityTypes,
      allLazy: allLazy ?? this.allLazy,
      allEager: allEager ?? this.allEager,
      mergeTolerant: mergeTolerant ?? this.mergeTolerant,
    );

    return resolutionRules.isInnocuous ? innocuous : resolutionRules;
  }

  /// Merges this instances with [other].
  @override
  EntityResolutionRules merge(EntityResolutionRules? other) {
    if (other == null || other.isInnocuous || identical(this, other)) {
      return isInnocuous ? innocuous : this;
    } else if (isInnocuous) {
      return other;
    }

    var bothMergeTolerant = mergeTolerant && other.mergeTolerant;

    var allowEntityFetch = _allowEntityFetch;
    if (other._allowEntityFetch != null) {
      if (allowEntityFetch == null) {
        allowEntityFetch = other._allowEntityFetch;
      } else if (allowEntityFetch != other._allowEntityFetch) {
        if (bothMergeTolerant) {
          allowEntityFetch = null;
        } else if (mergeTolerant) {
          allowEntityFetch = other._allowEntityFetch;
        } else if (!other.mergeTolerant) {
          throw MergeEntityRulesError(this, other, 'allowEntityFetch');
        }
      }
    }

    var allowReadFile = this.allowReadFile || other.allowReadFile;

    var allLazy = this.allLazy;
    if (other.allLazy != null) {
      if (allLazy == null) {
        allLazy = other.allLazy;
      } else if (allLazy != other.allLazy) {
        if (bothMergeTolerant) {
          allLazy = null;
        } else if (mergeTolerant) {
          allLazy = other.allLazy;
        } else if (!other.mergeTolerant) {
          throw MergeEntityRulesError(this, other, 'allLazy');
        }
      }
    }

    var allEager = this.allEager;
    if (other.allEager != null) {
      if (allEager == null) {
        allEager = other.allEager;
      } else if (allEager != other.allEager) {
        if (bothMergeTolerant) {
          allEager = null;
        } else if (mergeTolerant) {
          allEager = other.allEager;
        } else if (!other.mergeTolerant) {
          throw MergeEntityRulesError(this, other, 'allEager');
        }
      }
    }

    var lazyEntityTypes =
        this.lazyEntityTypes.merge(other.lazyEntityTypes).nullIfEmpty();

    var eagerEntityTypes =
        this.eagerEntityTypes.merge(other.eagerEntityTypes).nullIfEmpty();

    var merge = EntityResolutionRules(
      allowEntityFetch: allowEntityFetch,
      allowReadFile: allowReadFile,
      lazyEntityTypes: lazyEntityTypes,
      eagerEntityTypes: eagerEntityTypes,
      allLazy: allLazy,
      allEager: allEager,
      mergeTolerant: bothMergeTolerant,
    );

    if ((mergeTolerant || other.mergeTolerant)) {
      var conflict = merge._hasConflictingEntityTypes();

      if (conflict != null) {
        if (bothMergeTolerant) {
          merge = merge.copyWith(conflictingEntityTypes: conflict);
        } else {
          List<Type>? lazyEntityTypes;
          List<Type>? eagerEntityTypes;

          if (mergeTolerant) {
            lazyEntityTypes = this
                .lazyEntityTypes
                .without(conflict)
                .merge(other.lazyEntityTypes);

            eagerEntityTypes = this
                .eagerEntityTypes
                .without(conflict)
                .merge(other.eagerEntityTypes);
          } else if (other.mergeTolerant) {
            lazyEntityTypes = other.lazyEntityTypes
                .without(conflict)
                .merge(this.lazyEntityTypes);

            eagerEntityTypes = other.eagerEntityTypes
                .without(conflict)
                .merge(this.eagerEntityTypes);
          }

          merge = EntityResolutionRules(
            allowEntityFetch: allowEntityFetch,
            allowReadFile: allowReadFile,
            lazyEntityTypes: lazyEntityTypes.nullIfEmpty(),
            eagerEntityTypes: eagerEntityTypes.nullIfEmpty(),
            allLazy: allLazy,
            allEager: allEager,
          );
        }
      }
    }

    merge.validate();

    return merge;
  }

  @override
  String toString() {
    final lazyEntityTypes = this.lazyEntityTypes;
    final eagerEntityTypes = this.eagerEntityTypes;

    return isInnocuous
        ? 'EntityResolutionRules{innocuous}'
        : 'EntityResolutionRules{${[
            if (allLazy != null) 'allLazy: $allLazy',
            if (allEager != null) 'allEager: $allEager',
            if (allowEntityFetch) 'allowEntityFetch',
            if (allowReadFile) 'allowReadFile',
            if (lazyEntityTypes != null && lazyEntityTypes.isNotEmpty)
              'lazyEntityTypes: $lazyEntityTypes',
            if (eagerEntityTypes != null && eagerEntityTypes.isNotEmpty)
              'eagerEntityTypes: $eagerEntityTypes',
          ].join(', ')}'
            '}';
  }

  @override
  Map<String, Object?> toJson() => isInnocuous
      ? <String, Object?>{}
      : <String, Object?>{
          if (allLazy != null) 'allLazy': allLazy,
          if (allEager != null) 'allEager': allEager,
          if (allowEntityFetch) 'allowEntityFetch': true,
          if (allowReadFile) 'allowReadFile': true,
          if (lazyEntityTypes != null && lazyEntityTypes!.isNotEmpty)
            'lazyEntityTypes':
                lazyEntityTypes!.map((e) => e.toString()).toList(),
          if (eagerEntityTypes != null && eagerEntityTypes!.isNotEmpty)
            'eagerEntityTypes':
                eagerEntityTypes!.map((e) => e.toString()).toList(),
        };
}

class EntityResolutionRulesResolved implements EntityResolutionRules {
  static const _innocuousResolved = EntityResolutionRulesResolved(
      EntityResolutionRules.innocuous,
      contextRules: null,
      rules: EntityResolutionRules.innocuous);

  final EntityResolutionRules resolved;
  final EntityResolutionRules? contextRules;
  final EntityResolutionRules? rules;

  const EntityResolutionRulesResolved(this.resolved,
      {required this.contextRules, required this.rules});

  @override
  bool get isInnocuous => resolved.isInnocuous;

  @override
  bool? get _innocuous => resolved._innocuous;

  @override
  bool get isValid => resolved.isValid;

  @override
  void validate() => resolved.validate();

  @override
  String? _validateImpl() => resolved._validateImpl();

  @override
  bool? get _allowEntityFetch => resolved._allowEntityFetch;

  @override
  bool get allowEntityFetch => resolved.allowEntityFetch;

  @override
  bool get allowReadFile => resolved.allowReadFile;

  @override
  bool get mergeTolerant => resolved.mergeTolerant;

  @override
  bool? get allEager => resolved.allEager;

  @override
  bool? get allLazy => resolved.allLazy;

  @override
  List<Type>? get eagerEntityTypes => resolved.eagerEntityTypes;

  @override
  List<Type>? get lazyEntityTypes => resolved.lazyEntityTypes;

  @override
  List<Type>? _hasConflictingEntityTypes() =>
      resolved._hasConflictingEntityTypes();

  @override
  bool isEagerEntityType(Type entityType, [bool def = false]) =>
      resolved.isEagerEntityType(entityType, def);

  @override
  bool isEagerEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) =>
      resolved.isEagerEntityTypeInfo(entityTypeInfo, def);

  @override
  bool isLazyEntityType(Type entityType, [bool def = false]) =>
      resolved.isLazyEntityType(entityType, def);

  @override
  bool isLazyEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) =>
      resolved.isLazyEntityTypeInfo(entityTypeInfo, def);

  @override
  EntityResolutionRules copyWith(
          {bool? allowEntityFetch,
          bool? allowReadFile,
          List<Type>? lazyEntityTypes,
          List<Type>? eagerEntityTypes,
          bool? allLazy,
          bool? allEager,
          bool? mergeTolerant,
          List<Type>? conflictingEntityTypes}) =>
      resolved.copyWith(
          allowEntityFetch: allowEntityFetch,
          allowReadFile: allowReadFile,
          lazyEntityTypes: lazyEntityTypes,
          eagerEntityTypes: eagerEntityTypes,
          allLazy: allLazy,
          allEager: allEager,
          mergeTolerant: mergeTolerant,
          conflictingEntityTypes: conflictingEntityTypes);

  @override
  EntityResolutionRules merge(EntityResolutionRules? other) =>
      resolved.merge(other);

  @override
  String toString() => '$resolved[resolved]';

  @override
  Map<String, Object?> toJson() => resolved.toJson();
}

class _EntityResolutionRulesInnocuous implements EntityResolutionRules {
  const _EntityResolutionRulesInnocuous();

  @override
  bool get isInnocuous => true;

  @override
  bool? get _innocuous => true;

  @override
  bool get isValid => true;

  @override
  void validate() {}

  @override
  String? _validateImpl() => null;

  @override
  bool? get _allowEntityFetch => null;

  @override
  bool? get allEager => null;

  @override
  bool? get allLazy => null;

  @override
  bool get allowEntityFetch => false;

  @override
  bool get allowReadFile => false;

  @override
  bool get mergeTolerant => false;

  @override
  List<Type>? get eagerEntityTypes => null;

  @override
  List<Type>? get lazyEntityTypes => null;

  @override
  List<Type>? _hasConflictingEntityTypes() => null;

  @override
  bool isEagerEntityType(Type entityType, [bool def = false]) => false;

  @override
  bool isEagerEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) =>
      false;

  @override
  bool isLazyEntityType(Type entityType, [bool def = false]) => false;

  @override
  bool isLazyEntityTypeInfo(TypeInfo entityTypeInfo, [bool def = false]) =>
      false;

  @override
  EntityResolutionRules copyWith(
      {bool? allowEntityFetch,
      bool? allowReadFile,
      List<Type>? lazyEntityTypes,
      List<Type>? eagerEntityTypes,
      bool? allLazy,
      bool? allEager,
      bool? mergeTolerant,
      List<Type>? conflictingEntityTypes}) {
    if (conflictingEntityTypes != null && conflictingEntityTypes.isNotEmpty) {
      lazyEntityTypes = lazyEntityTypes.without(conflictingEntityTypes);
      eagerEntityTypes = eagerEntityTypes.without(conflictingEntityTypes);
    }

    lazyEntityTypes = lazyEntityTypes.nullIfEmpty();
    eagerEntityTypes = eagerEntityTypes.nullIfEmpty();

    return EntityResolutionRules(
      allowEntityFetch: allowEntityFetch,
      allowReadFile: allowReadFile ?? false,
      lazyEntityTypes: lazyEntityTypes,
      eagerEntityTypes: eagerEntityTypes,
      allLazy: allLazy,
      allEager: allEager,
      mergeTolerant: mergeTolerant ?? false,
    );
  }

  @override
  EntityResolutionRules merge(EntityResolutionRules? other) {
    if (other != null) {
      return other.isInnocuous ? EntityResolutionRules.innocuous : other;
    } else {
      return this;
    }
  }

  @override
  String toString() => 'EntityResolutionRules{innocuous}';

  @override
  Map<String, Object?> toJson() => <String, Object?>{};
}

/// An entity rules context provider.
abstract class EntityRulesContextProvider {
  /// Returns the [EntityResolutionRules] for the current context.
  EntityResolutionRules? getContextEntityResolutionRules(
      {Zone? contextZone, Object? contextIdentifier});
}

/// Mixin to resolve the [EntityResolutionRules] to apply.
mixin EntityRulesResolver {
  static final Set<EntityRulesContextProvider> _cotextProviders =
      <EntityRulesContextProvider>{};

  static EntityRulesContextProvider? _singleContextProvider;

  static void _updateSingleContextProvider() => _singleContextProvider =
      _cotextProviders.length == 1 ? _cotextProviders.first : null;

  /// Returns the current [EntityRulesContextProvider]s.
  static List<EntityRulesContextProvider> get cotextProviders =>
      _cotextProviders.toList();

  /// Register an [EntityRulesContextProvider].
  static bool registerContextProvider(
      EntityRulesContextProvider contextProvider) {
    var added = _cotextProviders.add(contextProvider);
    _updateSingleContextProvider();
    return added;
  }

  /// Unregister an [EntityRulesContextProvider].
  static bool unregisterContextProvider(
      EntityRulesContextProvider contextProvider) {
    var removed = _cotextProviders.remove(contextProvider);
    _updateSingleContextProvider();
    return removed;
  }

  /// The current [EntityResolutionRules] of the current context.
  EntityResolutionRules? getContextEntityResolutionRules() {
    var singleContextProvider = _singleContextProvider;

    if (singleContextProvider != null) {
      var resolutionRules = singleContextProvider
          .getContextEntityResolutionRules(contextZone: Zone.current);
      return resolutionRules;
    } else if (_cotextProviders.isEmpty) {
      return null;
    }

    var zone = Zone.current;

    EntityResolutionRules? contextRule;

    for (var c in _cotextProviders) {
      var resolutionRules =
          c.getContextEntityResolutionRules(contextZone: zone);
      if (resolutionRules != null) {
        if (contextRule != null) {
          contextRule = contextRule.merge(resolutionRules);
        } else {
          contextRule = resolutionRules;
        }
      }
    }

    return contextRule;
  }

  /// Resolves the [resolutionRules] to apply. Merges with the current
  /// [EntityResolutionRules] context if needed.
  ///
  /// See [getContextEntityResolutionRules] and [EntityResolutionRules.merge].
  EntityResolutionRulesResolved resolveEntityResolutionRules(
      EntityResolutionRules? resolutionRules) {
    var context = getContextEntityResolutionRules();

    if (context == null || context.isInnocuous) {
      if (resolutionRules is EntityResolutionRulesResolved) {
        return resolutionRules;
      }

      return _resolveEntityResolutionRulesNoContext(resolutionRules);
    }

    if (context is EntityResolutionRulesResolved) {
      if (resolutionRules == null || resolutionRules.isInnocuous) {
        return context;
      } else {
        context = context.resolved;
      }
    }

    if (resolutionRules is EntityResolutionRulesResolved) {
      if (identical(resolutionRules.contextRules, context)) {
        return resolutionRules;
      } else {
        resolutionRules = resolutionRules.resolved;
      }
    }

    return _resolveEntityResolutionRulesWithContext(context, resolutionRules);
  }

  EntityResolutionRulesResolved _resolveEntityResolutionRulesNoContext(
      EntityResolutionRules? rules) {
    if (rules == null || rules.isInnocuous) {
      return EntityResolutionRulesResolved._innocuousResolved;
    } else {
      return EntityResolutionRulesResolved(rules,
          contextRules: null, rules: rules);
    }
  }

  EntityResolutionRulesResolved _resolveEntityResolutionRulesWithContext(
      EntityResolutionRules context, EntityResolutionRules? rules) {
    if (rules == null) {
      return EntityResolutionRulesResolved(context,
          contextRules: context, rules: null);
    } else if (rules.isInnocuous) {
      return EntityResolutionRulesResolved(context,
          contextRules: context, rules: EntityResolutionRules.innocuous);
    } else {
      var merge = rules.merge(context);

      return identical(merge, EntityResolutionRules.innocuous)
          ? EntityResolutionRulesResolved._innocuousResolved
          : EntityResolutionRulesResolved(merge,
              contextRules: context, rules: rules);
    }
  }
}

extension _ListExtension<T> on List<T>? {
  List<T>? nullIfEmpty() {
    var self = this;
    return self == null || self.isEmpty ? null : self;
  }
}

extension _ListStringExtension on List<String>? {
  bool anyIgnoreCase(String s) {
    var self = this;
    return self != null && self.any((e) => equalsIgnoreAsciiCase(s, e));
  }
}

extension _ListTypeExtension on List<Type>? {
  List<Type>? without(List<Type>? conflict) {
    var self = this;
    if (self == null) return null;
    if (conflict == null || conflict.isEmpty) return self;
    return self.where((t) => !conflict.contains(t)).toList();
  }

  List<Type>? merge(List<Type>? other) {
    var self = this;
    if (other != null && other.isNotEmpty) {
      return [...?self, ...other];
    } else {
      return self;
    }
  }
}

extension _ObjectExtension on Object? {
  T? as<T>() {
    final o = this;
    if (o is T) {
      return o;
    } else if (o is Iterable) {
      return o.whereType<T>().firstOrNull;
    } else {
      return null;
    }
  }

  List<T> asListOf<T>() {
    final o = this;

    if (o is Iterable<T>) {
      return o.asList;
    } else if (o is T) {
      return [o];
    } else if (o is Iterable) {
      return o.whereType<T>().toList();
    } else {
      return <T>[];
    }
  }
}
