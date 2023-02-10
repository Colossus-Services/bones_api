import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_extension.dart';

/// Rules to resolve entities.
/// Used by [EntityHandler] and [DBEntityRepository].
class EntityResolutionRules {
  /// A `const` instance without any resolution rules to apply.
  static const EntityResolutionRules innocuous =
      _EntityResolutionRulesInnocuous();

  final bool? _innocuous;

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
        _innocuous = (allowEntityFetch != null ||
                allEager != null ||
                allLazy != null ||
                allowReadFile ||
                mergeTolerant)
            ? false
            : (lazyEntityTypes == null && eagerEntityTypes == null)
                ? true
                : null;

  const EntityResolutionRules.fetch(
      {this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager,
      this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        _innocuous = false;

  const EntityResolutionRules.fetchEager(this.eagerEntityTypes,
      {this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = null,
        _innocuous = false;

  const EntityResolutionRules.fetchLazy(this.lazyEntityTypes,
      {this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        allLazy = null,
        allEager = null,
        _innocuous = false;

  const EntityResolutionRules.fetchEagerAll({this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = true,
        _innocuous = false;

  const EntityResolutionRules.fetchLazyAll({this.mergeTolerant = false})
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = true,
        allEager = false,
        _innocuous = false;

  /// Returns `true` if this instance is equivalent to [innocuous] instance (no resolution rules to apply).
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

  bool get isValid => _validateImpl() == null;

  void validate() {
    var error = _validateImpl();
    if (error != null) {
      throw ValidateEntityResolutionRulesError(this, error);
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
          throw MergeEntityResolutionRulesError(
              this, other, 'allowEntityFetch');
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
          throw MergeEntityResolutionRulesError(this, other, 'allLazy');
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
          throw MergeEntityResolutionRulesError(this, other, 'allEager');
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

extension _ListTypeExtension on List<Type>? {
  List<Type>? nullIfEmpty() {
    var self = this;
    return self == null || self.isEmpty ? null : self;
  }

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

class ValidateEntityResolutionRulesError extends Error {
  final EntityResolutionRules resolutionRules;
  final String message;

  ValidateEntityResolutionRulesError(this.resolutionRules, this.message);

  @override
  String toString() =>
      "Error validating `EntityResolutionRules`: $message >> $resolutionRules";
}

/// [EntityResolutionRules.merge] error.
class MergeEntityResolutionRulesError extends Error {
  final EntityResolutionRules a;
  final EntityResolutionRules b;

  final String conflict;

  MergeEntityResolutionRulesError(this.a, this.b, this.conflict);

  @override
  String toString() =>
      "Can't merge `EntityResolutionRules`! Conflict: $conflict >> $a <!> $b";
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
        if (resolutionRules.contextRules == null) {
          return resolutionRules;
        } else {
          resolutionRules = resolutionRules.resolved;
        }
      }

      return _resolveEntityResolutionRulesNoContext(resolutionRules);
    }

    if (context is EntityResolutionRulesResolved) {
      context = context.resolved;
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
