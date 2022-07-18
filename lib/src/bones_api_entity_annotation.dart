import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta_meta.dart';
import 'package:statistics/statistics.dart';

abstract class EntityAnnotation {
  const EntityAnnotation();
}

/// Configuration of a entity field.
/// - `hidden`: this field won't be stored if is hidden.
/// - `unique`: this filed should be unique in the repository/table.
/// - `minimum`: defines the minimum value or minimum size of the field.
/// - `maximum`: defines the maximum value or maximum size of the field.
/// - `regexp`: defines the [RegExp] pattern of the field.
/// - `validator`: defines a validation [Function] for the field.
@Target({TargetKind.field, TargetKind.getter})
class EntityField extends EntityAnnotation {
  final bool _hidden;
  final bool _unique;
  final num? minimum;
  final num? maximum;
  final String? regexp;
  final bool Function(Object? value)? validator;

  const EntityField(
      {bool hidden = false,
      bool unique = false,
      this.minimum,
      this.maximum,
      this.validator,
      this.regexp})
      : _hidden = hidden,
        _unique = unique;

  const EntityField.visible() : this(hidden: false);

  const EntityField.hidden() : this(hidden: true);

  const EntityField.unique() : this(unique: true);

  const EntityField.minimum(int minimum) : this(minimum: minimum);

  const EntityField.maximum(int maximum) : this(maximum: maximum);

  const EntityField.limits(int minimum, int maximum)
      : this(minimum: minimum, maximum: maximum);

  const EntityField.regexp(String regexp) : this(regexp: regexp);

  const EntityField.validator(bool Function(Object? value) validator)
      : this(validator: validator);

  /// Returns `true` if the annotated field should be hidden from storage.
  bool get isHidden => _hidden;

  /// Returns `true` if the annotated field should be visible to storage.
  bool get isVisible => !_hidden;

  /// Returns `true` if the annotated field should be unique.
  bool get isUnique => _unique;

  /// Returns `true` if [value] is valid for this [EntityField] configuration.
  bool isValidValue(Object? value, {String? fieldName}) =>
      validateValue(value, fieldName: fieldName) == null;

  /// Returns a [EntityFieldInvalid] if [value] is invalid for this [EntityField] configuration.
  EntityFieldInvalid? validateValue(Object? value,
      {String? fieldName, Type? entityType}) {
    var validator = this.validator;
    if (validator != null) {
      if (!validator(value)) {
        return EntityFieldInvalid('validator', value,
            fieldName: fieldName, entityType: entityType);
      }
    }

    var regexp = this.regexp;
    if (regexp != null) {
      var s = value == null ? '' : value.toString();

      var re = RegExp(regexp, dotAll: true);
      var valid = re.hasMatch(s);

      if (!valid) {
        return EntityFieldInvalid('regexp(${re.pattern})', value,
            entityType: entityType, fieldName: fieldName);
      }
    }

    if (value != null) {
      var maximum = this.maximum;

      if (maximum != null) {
        var invalid = false;
        String? valueStr;

        if (value is num) {
          if (value > maximum) invalid = true;
        } else if (value is BigInt) {
          if (value > maximum.toBigInt()) invalid = true;
        } else if (value is DynamicNumber) {
          if (value > maximum.toDynamicNumber()) invalid = true;
        } else if (value is String) {
          if (value.length > maximum) invalid = true;
        } else if (value is Iterable) {
          if (value.length > maximum) {
            invalid = true;
            valueStr = '${value.runtimeType}{length: ${value.length}';
          }
        }

        if (invalid) {
          valueStr ??= '$value';
          return EntityFieldInvalid('maximum($maximum)', value,
              entityType: entityType, fieldName: fieldName);
        }
      }

      var minimum = this.minimum;
      if (minimum != null) {
        var invalid = false;
        String? valueStr;

        if (value is num) {
          if (value < minimum) invalid = true;
        } else if (value is BigInt) {
          if (value < minimum.toBigInt()) invalid = true;
        } else if (value is DynamicNumber) {
          if (value < minimum.toDynamicNumber()) invalid = true;
        } else if (value is String) {
          if (value.length < minimum) invalid = true;
        } else if (value is Iterable) {
          if (value.length < minimum) {
            invalid = true;
            valueStr = '${value.runtimeType}{length: ${value.length}';
          }
        }

        if (invalid) {
          valueStr ??= '$value';
          return EntityFieldInvalid('minimum($minimum)', value,
              entityType: entityType, fieldName: fieldName);
        }
      }
    }

    return null;
  }
}

extension IterableEntityAnnotationExtension on Iterable<EntityAnnotation> {
  Iterable<EntityField> get entityFieldsIterable => whereType<EntityField>();

  List<EntityField> get entityFields => entityFieldsIterable.toList();

  List<num> get maximum => entityFieldsIterable.maximum;

  List<num> get minimum => entityFieldsIterable.minimum;

  List<String> get regexp => entityFieldsIterable.regexp;

  List<EntityField> get unique => entityFieldsIterable.unique;

  List<EntityField> get hidden => entityFieldsIterable.hidden;

  List<EntityField> get visible => entityFieldsIterable.visible;

  bool get hasUnique => entityFieldsIterable.hasUnique;

  bool get hasHidden => entityFieldsIterable.hasHidden;

  bool get hasVisible => entityFieldsIterable.hasVisible;
}

extension IterableEntityFieldExtension on Iterable<EntityField> {
  List<num> get maximum => map((e) => e.maximum).whereNotNull().toList();

  List<num> get minimum => map((e) => e.minimum).whereNotNull().toList();

  List<String> get regexp => map((e) => e.regexp).whereNotNull().toList();

  List<EntityField> get unique => where((e) => e.isUnique).toList();

  List<EntityField> get hidden => where((e) => e.isHidden).toList();

  List<EntityField> get visible => where((e) => e.isVisible).toList();

  bool get hasUnique => any((e) => e.isUnique);

  bool get hasHidden => any((e) => e.isHidden);

  bool get hasVisible => any((e) => e.isVisible);
}

/// An entity field validation error.
class EntityFieldInvalid extends Error {
  /// The reason of the invalid error.
  final String reason;

  /// The invalid value.
  final Object? value;

  /// The entity [Type].
  final Type? entityType;

  /// The table of the [entityType].
  final String? tableName;

  /// The field name of the [value].
  final String? fieldName;

  /// The errors of the sub-entity ([value]) in the [fieldName].
  final Map<String, EntityFieldInvalid>? subEntityErrors;

  /// The parent/original error.
  final Object? parentError;

  EntityFieldInvalid(this.reason, this.value,
      {this.entityType,
      this.tableName,
      this.fieldName,
      this.subEntityErrors,
      this.parentError});

  EntityFieldInvalid copyWith(
          {String? reason,
          Object? value,
          Type? entityType,
          String? tableName,
          String? fieldName,
          Map<String, EntityFieldInvalid>? subEntityErrors,
          Object? parentError}) =>
      EntityFieldInvalid(
        reason ?? this.reason,
        value ?? this.value,
        entityType: entityType ?? this.entityType,
        tableName: tableName ?? this.tableName,
        fieldName: fieldName ?? this.fieldName,
        subEntityErrors: subEntityErrors ?? this.subEntityErrors,
        parentError: parentError ?? this.parentError,
      );

  String get message {
    var msg = 'reason: $reason ; value: <${value?.toString().truncate(100)}>';

    var subEntityErrors = this.subEntityErrors;
    if (subEntityErrors != null && subEntityErrors.isNotEmpty) {
      for (var e in subEntityErrors.values) {
        msg += '\n- $e';
      }
    }

    return msg;
  }

  @override
  String toString() {
    var entityStr = entityType != null ? '$entityType' : '';

    var tableName = this.tableName;
    if (tableName != null && tableName.isNotEmpty) {
      entityStr += '@table:$tableName';
    }

    if (entityStr.isNotEmpty) {
      entityStr = '($entityStr)';
    }

    var fieldStr =
        fieldName != null && fieldName!.isNotEmpty ? '($fieldName)' : '';

    var parentStr =
        parentError != null ? '\n  -- Parent ERROR>> $parentError' : '';

    return 'Invalid entity$entityStr field$fieldStr> $message$parentStr';
  }
}
