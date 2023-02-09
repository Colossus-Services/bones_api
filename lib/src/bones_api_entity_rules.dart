import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_extension.dart';

/// Rules to resolve entities.
/// Used by [EntityHandler] and [DBEntityRepository].
class EntityResolutionRules {
  /// A `const` instance without any resolution rules to apply.
  static const EntityResolutionRules innocuous =
      _EntityResolutionRulesInnocuous();

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

  const EntityResolutionRules(
      {bool? allowEntityFetch,
      this.allowReadFile = false,
      this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager})
      : _allowEntityFetch = allowEntityFetch;

  const EntityResolutionRules.fetch(
      {this.lazyEntityTypes,
      this.eagerEntityTypes,
      this.allLazy,
      this.allEager})
      : _allowEntityFetch = true,
        allowReadFile = false;

  const EntityResolutionRules.fetchEager(this.eagerEntityTypes)
      : _allowEntityFetch = true,
        allowReadFile = false,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = null;

  const EntityResolutionRules.fetchLazy(this.lazyEntityTypes)
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        allLazy = null,
        allEager = null;

  const EntityResolutionRules.fetchEagerAll()
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = null,
        allEager = true;

  const EntityResolutionRules.fetchLazyAll()
      : _allowEntityFetch = true,
        allowReadFile = false,
        eagerEntityTypes = null,
        lazyEntityTypes = null,
        allLazy = true,
        allEager = false;

  /// Returns `true` if this instance is equivalent to [innocuous] instance (no resolution rules to apply).
  bool get isInnocuous =>
      _allowEntityFetch == null &&
      !allowReadFile &&
      (eagerEntityTypes == null || eagerEntityTypes!.isEmpty) &&
      (lazyEntityTypes == null || lazyEntityTypes!.isEmpty) &&
      allLazy == null &&
      allEager == null;

  bool get isValid => _validateImpl() == null;

  void validate() {
    var error = _validateImpl();
    if (error != null) {
      throw ValidateEntityResolutionRulesError(this, error);
    }
  }

  String? _validateImpl() {
    var eagerEntityTypes = this.eagerEntityTypes;
    var lazyEntityTypes = this.lazyEntityTypes;

    if (eagerEntityTypes != null &&
        lazyEntityTypes != null &&
        eagerEntityTypes.isNotEmpty &&
        lazyEntityTypes.isNotEmpty) {
      if (eagerEntityTypes.any((t) => lazyEntityTypes.contains(t))) {
        var conflict =
            eagerEntityTypes.where((t) => lazyEntityTypes.contains(t)).toList();

        return "Conflicting `eagerEntityTypes` and `lazyEntityTypes`: $conflict";
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
  EntityResolutionRules copyWith(
      {bool? allowEntityFetch,
      bool? allowReadFile,
      List<Type>? lazyEntityTypes,
      List<Type>? eagerEntityTypes,
      bool? allLazy,
      bool? allEager}) {
    var resolutionRules = EntityResolutionRules(
      allowEntityFetch: allowEntityFetch ?? _allowEntityFetch,
      allowReadFile: allowReadFile ?? this.allowReadFile,
      lazyEntityTypes: lazyEntityTypes ?? this.lazyEntityTypes,
      eagerEntityTypes: eagerEntityTypes ?? this.eagerEntityTypes,
      allLazy: allLazy ?? this.allLazy,
      allEager: allEager ?? this.allEager,
    );
    return resolutionRules.isInnocuous ? innocuous : resolutionRules;
  }

  /// Merges this instances with [other].
  EntityResolutionRules merge(EntityResolutionRules? other) {
    if (other == null || other.isInnocuous) {
      return isInnocuous ? innocuous : this;
    } else if (isInnocuous) {
      return other;
    }

    var allowEntityFetch = _allowEntityFetch;
    if (other._allowEntityFetch != null) {
      if (allowEntityFetch == null) {
        allowEntityFetch = other._allowEntityFetch;
      } else if (allowEntityFetch != other._allowEntityFetch) {
        throw MergeEntityResolutionRulesError(this, other, 'allowEntityFetch');
      }
    }

    var allowReadFile = this.allowReadFile || other.allowReadFile;

    var allLazy = this.allLazy;
    if (other.allLazy != null) {
      if (allLazy == null) {
        allLazy = other.allLazy;
      } else if (allLazy != other.allLazy) {
        throw MergeEntityResolutionRulesError(this, other, 'allLazy');
      }
    }

    var allEager = this.allEager;
    if (other.allEager != null) {
      if (allEager == null) {
        allEager = other.allEager;
      } else if (allEager != other.allEager) {
        throw MergeEntityResolutionRulesError(this, other, 'allEager');
      }
    }

    var lazyEntityTypes = this.lazyEntityTypes;

    var otherLazyEntityTypes = other.lazyEntityTypes;
    if (otherLazyEntityTypes != null && otherLazyEntityTypes.isNotEmpty) {
      lazyEntityTypes = [...?lazyEntityTypes, ...otherLazyEntityTypes];
    }

    var eagerEntityTypes = this.eagerEntityTypes;

    var otherEagerEntityTypes = other.eagerEntityTypes;
    if (otherEagerEntityTypes != null && otherEagerEntityTypes.isNotEmpty) {
      eagerEntityTypes = [...?eagerEntityTypes, ...otherEagerEntityTypes];
    }

    var merge = EntityResolutionRules(
      allowEntityFetch: allowEntityFetch,
      allowReadFile: allowReadFile,
      lazyEntityTypes: lazyEntityTypes,
      eagerEntityTypes: eagerEntityTypes,
      allLazy: allLazy,
      allEager: allEager,
    );

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

class _EntityResolutionRulesInnocuous implements EntityResolutionRules {
  const _EntityResolutionRulesInnocuous();

  @override
  bool get isInnocuous => true;

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
  List<Type>? get eagerEntityTypes => null;

  @override
  List<Type>? get lazyEntityTypes => null;

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
          bool? allEager}) =>
      EntityResolutionRules(
        allowEntityFetch: allowEntityFetch,
        allowReadFile: allowReadFile ?? false,
        lazyEntityTypes: lazyEntityTypes,
        eagerEntityTypes: eagerEntityTypes,
        allLazy: allLazy,
        allEager: allEager,
      );

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
}

/// Mixin to resolve the [EntityResolutionRules] to apply.
mixin EntityRulesResolver {
  /// The current [EntityResolutionRules] of the current context.
  EntityResolutionRules? getContextEntityResolutionRules() {
    return null;
  }

  /// Resolves the [resolutionRules] to apply. Merges with the current
  /// [EntityResolutionRules] context if needed.
  ///
  /// See [getContextEntityResolutionRules] and [EntityResolutionRules.merge].
  EntityResolutionRules resolveEntityResolutionRules(
      EntityResolutionRules? resolutionRules) {
    var context = getContextEntityResolutionRules();

    if (resolutionRules == null || resolutionRules.isInnocuous) {
      return context ?? EntityResolutionRules.innocuous;
    } else {
      var merge = resolutionRules.merge(context);
      return merge;
    }
  }
}
