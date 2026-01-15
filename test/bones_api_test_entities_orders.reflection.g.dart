//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.7.3
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: no_leading_underscores_for_local_identifiers
// ignore_for_file: camel_case_types
// ignore_for_file: camel_case_extensions
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test_entities_orders.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.7.3');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"bonus":
      return const Symbol(r"bonus");
    case r"campaign":
      return const Symbol(r"campaign");
    case r"config":
      return const Symbol(r"config");
    case r"id":
      return const Symbol(r"id");
    case r"items":
      return const Symbol(r"items");
    case r"open":
      return const Symbol(r"open");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
Bonus Bonus$fromJson(Map<String, Object?> map) =>
    Bonus$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Bonus Bonus$fromJsonEncoded(String jsonEncoded) =>
    Bonus$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Campaign Campaign$fromJson(Map<String, Object?> map) =>
    Campaign$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Campaign Campaign$fromJsonEncoded(String jsonEncoded) =>
    Campaign$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
CampaignConfig CampaignConfig$fromJson(Map<String, Object?> map) =>
    CampaignConfig$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
CampaignConfig CampaignConfig$fromJsonEncoded(String jsonEncoded) =>
    CampaignConfig$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Item Item$fromJson(Map<String, Object?> map) =>
    Item$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Item Item$fromJsonEncoded(String jsonEncoded) =>
    Item$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Order Order$fromJson(Map<String, Object?> map) =>
    Order$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Order Order$fromJsonEncoded(String jsonEncoded) =>
    Order$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class Bonus$reflection extends ClassReflection<Bonus> with __ReflectionMixin {
  static final Expando<Bonus$reflection> _objectReflections = Expando();

  factory Bonus$reflection([Bonus? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Bonus$reflection._(object);
  }

  Bonus$reflection._([Bonus? object]) : super(Bonus, r'Bonus', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.7.0');

  @override
  Bonus$reflection withObject([Bonus? obj]) =>
      Bonus$reflection(obj)..setupInternalsWith(this);

  static Bonus$reflection? _withoutObjectInstance;
  @override
  Bonus$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Bonus$reflection get staticInstance =>
      _withoutObjectInstance ??= Bonus$reflection._();

  @override
  Bonus$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Bonus$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => true;
  @override
  Bonus? createInstanceWithDefaultConstructor() => Bonus();

  @override
  bool get hasEmptyConstructor => true;
  @override
  Bonus? createInstanceWithEmptyConstructor() => Bonus.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Bonus? createInstanceWithNoRequiredArgsConstructor() => Bonus.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Bonus>> _constructors = {};

  @override
  ConstructorReflection<Bonus>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Bonus>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Bonus>(
          this,
          Bonus,
          '',
          () => Bonus.new,
          null,
          null,
          const <String, __PR>{
            'campaign': __PR(__TR.tObject, 'campaign', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
        );
      case 'empty':
        return ConstructorReflection<Bonus>(
          this,
          Bonus,
          'empty',
          () => Bonus.empty,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Entity];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Bonus? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'campaign',
    'fieldsNames',
    'id',
    'idFieldName',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Bonus, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Bonus, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Bonus, T>? field<T>(String fieldName, [Bonus? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Bonus, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Bonus, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Bonus, T>;
  }

  FieldReflection<Bonus, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Bonus, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Bonus, dynamic>? _fieldImpl(String fieldName, Bonus? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Bonus, int?>(
          this,
          Bonus,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'campaign':
        return FieldReflection<Bonus, EntityReference<Campaign>>(
          this,
          Bonus,
          const __TR<EntityReference<Campaign>>(EntityReference, <__TR>[
            __TR<Campaign>(Campaign),
          ]),
          'campaign',
          false,
          (o) => () => o!.campaign,
          (o) => (v) => o!.campaign = v,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<Bonus, String>(
          this,
          Bonus,
          __TR.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName,
          null,
          obj,
          false,
          const [override],
        );
      case 'fieldsnames':
        return FieldReflection<Bonus, List<String>>(
          this,
          Bonus,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Bonus? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'campaign': obj?.campaign,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(
    Bonus? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'campaign': obj?.campaign,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Bonus, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Bonus, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Bonus, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Bonus, R>? method<R>(String methodName, [Bonus? obj]) {
    if (obj == null) {
      if (object != null) {
        return _methodObjectImpl<R>(methodName);
      } else {
        return _methodNoObjectImpl<R>(methodName);
      }
    } else if (identical(obj, object)) {
      return _methodObjectImpl<R>(methodName);
    }
    return _methodNoObjectImpl<R>(methodName)?.withObject(obj);
  }

  MethodReflection<Bonus, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Bonus, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Bonus, R>;
  }

  MethodReflection<Bonus, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Bonus, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Bonus, dynamic>? _methodImpl(String methodName, Bonus? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Bonus, dynamic>(
          this,
          Bonus,
          'getField',
          __TR.tDynamic,
          true,
          (o) => o!.getField,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'getfieldtype':
        return MethodReflection<Bonus, TypeInfo<dynamic>?>(
          this,
          Bonus,
          'getFieldType',
          const __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
          true,
          (o) => o!.getFieldType,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'setfield':
        return MethodReflection<Bonus, void>(
          this,
          Bonus,
          'setField',
          __TR.tVoid,
          false,
          (o) => o!.setField,
          obj,
          const <__PR>[
            __PR(__TR.tString, 'key', false, true),
            __PR(__TR.tDynamic, 'value', true, true),
          ],
          null,
          null,
          const [override],
        );
      case 'tojson':
        return MethodReflection<Bonus, Map<String, dynamic>>(
          this,
          Bonus,
          'toJson',
          __TR.tMapStringDynamic,
          false,
          (o) => o!.toJson,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getid':
        return MethodReflection<Bonus, dynamic>(
          this,
          Entity,
          'getID',
          __TR.tDynamic,
          true,
          (o) => o!.getID,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'setid':
        return MethodReflection<Bonus, void>(
          this,
          Entity,
          'setID',
          __TR.tVoid,
          false,
          (o) => o!.setID,
          obj,
          const <__PR>[__PR(__TR.tDynamic, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'getfieldentityannotations':
        return MethodReflection<Bonus, List<EntityAnnotation>?>(
          this,
          Entity,
          'getFieldEntityAnnotations',
          const __TR<List<EntityAnnotation>>(List, <__TR>[
            __TR<EntityAnnotation>(EntityAnnotation),
          ]),
          true,
          (o) => o!.getFieldEntityAnnotations,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          null,
        );
      case 'tojsonencoded':
        return MethodReflection<Bonus, String>(
          this,
          Entity,
          'toJsonEncoded',
          __TR.tString,
          false,
          (o) => o!.toJsonEncoded,
          obj,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Bonus, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<Bonus, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Bonus, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Bonus, R>;
  }

  StaticMethodReflection<Bonus, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<Bonus, FutureOr<Bonus>>(
          this,
          Bonus,
          'fromMap',
          const __TR<FutureOr<Bonus>>(FutureOr, <__TR>[__TR<Bonus>(Bonus)]),
          false,
          () => Bonus.fromMap,
          const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

class Campaign$reflection extends ClassReflection<Campaign>
    with __ReflectionMixin {
  static final Expando<Campaign$reflection> _objectReflections = Expando();

  factory Campaign$reflection([Campaign? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Campaign$reflection._(object);
  }

  Campaign$reflection._([Campaign? object])
    : super(Campaign, r'Campaign', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.7.0');

  @override
  Campaign$reflection withObject([Campaign? obj]) =>
      Campaign$reflection(obj)..setupInternalsWith(this);

  static Campaign$reflection? _withoutObjectInstance;
  @override
  Campaign$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Campaign$reflection get staticInstance =>
      _withoutObjectInstance ??= Campaign$reflection._();

  @override
  Campaign$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Campaign$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Campaign? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Campaign? createInstanceWithEmptyConstructor() => Campaign.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Campaign? createInstanceWithNoRequiredArgsConstructor() => Campaign.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Campaign>> _constructors = {};

  @override
  ConstructorReflection<Campaign>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Campaign>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Campaign>(
          this,
          Campaign,
          '',
          () => Campaign.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{
            'config': __PR(__TR.tObject, 'config', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
        );
      case 'empty':
        return ConstructorReflection<Campaign>(
          this,
          Campaign,
          'empty',
          () => Campaign.empty,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Entity];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Campaign? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'config',
    'fieldsNames',
    'id',
    'idFieldName',
    'name',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Campaign, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Campaign, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Campaign, T>? field<T>(String fieldName, [Campaign? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Campaign, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Campaign, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Campaign, T>;
  }

  FieldReflection<Campaign, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Campaign, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Campaign, dynamic>? _fieldImpl(
    String fieldName,
    Campaign? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Campaign, int?>(
          this,
          Campaign,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Campaign, String>(
          this,
          Campaign,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name,
          (o) => (v) => o!.name = v,
          obj,
          false,
        );
      case 'config':
        return FieldReflection<Campaign, EntityReference<CampaignConfig>>(
          this,
          Campaign,
          const __TR<EntityReference<CampaignConfig>>(EntityReference, <__TR>[
            __TR<CampaignConfig>(CampaignConfig),
          ]),
          'config',
          false,
          (o) => () => o!.config,
          (o) => (v) => o!.config = v,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<Campaign, String>(
          this,
          Campaign,
          __TR.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName,
          null,
          obj,
          false,
          const [override],
        );
      case 'fieldsnames':
        return FieldReflection<Campaign, List<String>>(
          this,
          Campaign,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Campaign? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'config': obj?.config,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(
    Campaign? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'config': obj?.config,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Campaign, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Campaign, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<Campaign, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Campaign, R>? method<R>(String methodName, [Campaign? obj]) {
    if (obj == null) {
      if (object != null) {
        return _methodObjectImpl<R>(methodName);
      } else {
        return _methodNoObjectImpl<R>(methodName);
      }
    } else if (identical(obj, object)) {
      return _methodObjectImpl<R>(methodName);
    }
    return _methodNoObjectImpl<R>(methodName)?.withObject(obj);
  }

  MethodReflection<Campaign, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Campaign, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Campaign, R>;
  }

  MethodReflection<Campaign, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Campaign, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Campaign, dynamic>? _methodImpl(
    String methodName,
    Campaign? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Campaign, dynamic>(
          this,
          Campaign,
          'getField',
          __TR.tDynamic,
          true,
          (o) => o!.getField,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'getfieldtype':
        return MethodReflection<Campaign, TypeInfo<dynamic>?>(
          this,
          Campaign,
          'getFieldType',
          const __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
          true,
          (o) => o!.getFieldType,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'setfield':
        return MethodReflection<Campaign, void>(
          this,
          Campaign,
          'setField',
          __TR.tVoid,
          false,
          (o) => o!.setField,
          obj,
          const <__PR>[
            __PR(__TR.tString, 'key', false, true),
            __PR(__TR.tDynamic, 'value', true, true),
          ],
          null,
          null,
          const [override],
        );
      case 'tojson':
        return MethodReflection<Campaign, Map<String, dynamic>>(
          this,
          Campaign,
          'toJson',
          __TR.tMapStringDynamic,
          false,
          (o) => o!.toJson,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getid':
        return MethodReflection<Campaign, dynamic>(
          this,
          Entity,
          'getID',
          __TR.tDynamic,
          true,
          (o) => o!.getID,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'setid':
        return MethodReflection<Campaign, void>(
          this,
          Entity,
          'setID',
          __TR.tVoid,
          false,
          (o) => o!.setID,
          obj,
          const <__PR>[__PR(__TR.tDynamic, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'getfieldentityannotations':
        return MethodReflection<Campaign, List<EntityAnnotation>?>(
          this,
          Entity,
          'getFieldEntityAnnotations',
          const __TR<List<EntityAnnotation>>(List, <__TR>[
            __TR<EntityAnnotation>(EntityAnnotation),
          ]),
          true,
          (o) => o!.getFieldEntityAnnotations,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          null,
        );
      case 'tojsonencoded':
        return MethodReflection<Campaign, String>(
          this,
          Entity,
          'toJsonEncoded',
          __TR.tString,
          false,
          (o) => o!.toJsonEncoded,
          obj,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Campaign, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<Campaign, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Campaign, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Campaign, R>;
  }

  StaticMethodReflection<Campaign, dynamic>? _staticMethodImpl(
    String methodName,
  ) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<Campaign, FutureOr<Campaign>>(
          this,
          Campaign,
          'fromMap',
          const __TR<FutureOr<Campaign>>(FutureOr, <__TR>[
            __TR<Campaign>(Campaign),
          ]),
          false,
          () => Campaign.fromMap,
          const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

class CampaignConfig$reflection extends ClassReflection<CampaignConfig>
    with __ReflectionMixin {
  static final Expando<CampaignConfig$reflection> _objectReflections =
      Expando();

  factory CampaignConfig$reflection([CampaignConfig? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= CampaignConfig$reflection._(object);
  }

  CampaignConfig$reflection._([CampaignConfig? object])
    : super(CampaignConfig, r'CampaignConfig', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.7.0');

  @override
  CampaignConfig$reflection withObject([CampaignConfig? obj]) =>
      CampaignConfig$reflection(obj)..setupInternalsWith(this);

  static CampaignConfig$reflection? _withoutObjectInstance;
  @override
  CampaignConfig$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static CampaignConfig$reflection get staticInstance =>
      _withoutObjectInstance ??= CampaignConfig$reflection._();

  @override
  CampaignConfig$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    CampaignConfig$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => true;
  @override
  CampaignConfig? createInstanceWithDefaultConstructor() => CampaignConfig();

  @override
  bool get hasEmptyConstructor => true;
  @override
  CampaignConfig? createInstanceWithEmptyConstructor() =>
      CampaignConfig.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  CampaignConfig? createInstanceWithNoRequiredArgsConstructor() =>
      CampaignConfig.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<CampaignConfig>>
  _constructors = {};

  @override
  ConstructorReflection<CampaignConfig>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<CampaignConfig>? _constructorImpl(
    String constructorName,
  ) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<CampaignConfig>(
          this,
          CampaignConfig,
          '',
          () => CampaignConfig.new,
          null,
          null,
          const <String, __PR>{
            'id': __PR(__TR.tInt, 'id', true, false),
            'open': __PR(__TR.tBool, 'open', false, false, false),
          },
          null,
        );
      case 'empty':
        return ConstructorReflection<CampaignConfig>(
          this,
          CampaignConfig,
          'empty',
          () => CampaignConfig.empty,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Entity];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([CampaignConfig? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'fieldsNames',
    'id',
    'idFieldName',
    'open',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<CampaignConfig, dynamic>>
  _fieldsNoObject = {};

  final Map<String, FieldReflection<CampaignConfig, dynamic>> _fieldsObject =
      {};

  @override
  FieldReflection<CampaignConfig, T>? field<T>(
    String fieldName, [
    CampaignConfig? obj,
  ]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<CampaignConfig, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<CampaignConfig, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<CampaignConfig, T>;
  }

  FieldReflection<CampaignConfig, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<CampaignConfig, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<CampaignConfig, dynamic>? _fieldImpl(
    String fieldName,
    CampaignConfig? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<CampaignConfig, int?>(
          this,
          CampaignConfig,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'open':
        return FieldReflection<CampaignConfig, bool>(
          this,
          CampaignConfig,
          __TR.tBool,
          'open',
          false,
          (o) => () => o!.open,
          (o) => (v) => o!.open = v,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<CampaignConfig, String>(
          this,
          CampaignConfig,
          __TR.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName,
          null,
          obj,
          false,
          const [override],
        );
      case 'fieldsnames':
        return FieldReflection<CampaignConfig, List<String>>(
          this,
          CampaignConfig,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    CampaignConfig? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'open': obj?.open,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(
    CampaignConfig? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'open': obj?.open,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<CampaignConfig, T>? staticField<T>(String fieldName) =>
      null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<CampaignConfig, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<CampaignConfig, dynamic>> _methodsObject =
      {};

  @override
  MethodReflection<CampaignConfig, R>? method<R>(
    String methodName, [
    CampaignConfig? obj,
  ]) {
    if (obj == null) {
      if (object != null) {
        return _methodObjectImpl<R>(methodName);
      } else {
        return _methodNoObjectImpl<R>(methodName);
      }
    } else if (identical(obj, object)) {
      return _methodObjectImpl<R>(methodName);
    }
    return _methodNoObjectImpl<R>(methodName)?.withObject(obj);
  }

  MethodReflection<CampaignConfig, R>? _methodNoObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<CampaignConfig, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<CampaignConfig, R>;
  }

  MethodReflection<CampaignConfig, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<CampaignConfig, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<CampaignConfig, dynamic>? _methodImpl(
    String methodName,
    CampaignConfig? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<CampaignConfig, dynamic>(
          this,
          CampaignConfig,
          'getField',
          __TR.tDynamic,
          true,
          (o) => o!.getField,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'getfieldtype':
        return MethodReflection<CampaignConfig, TypeInfo<dynamic>?>(
          this,
          CampaignConfig,
          'getFieldType',
          const __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
          true,
          (o) => o!.getFieldType,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'setfield':
        return MethodReflection<CampaignConfig, void>(
          this,
          CampaignConfig,
          'setField',
          __TR.tVoid,
          false,
          (o) => o!.setField,
          obj,
          const <__PR>[
            __PR(__TR.tString, 'key', false, true),
            __PR(__TR.tDynamic, 'value', true, true),
          ],
          null,
          null,
          const [override],
        );
      case 'tojson':
        return MethodReflection<CampaignConfig, Map<String, dynamic>>(
          this,
          CampaignConfig,
          'toJson',
          __TR.tMapStringDynamic,
          false,
          (o) => o!.toJson,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getid':
        return MethodReflection<CampaignConfig, dynamic>(
          this,
          Entity,
          'getID',
          __TR.tDynamic,
          true,
          (o) => o!.getID,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'setid':
        return MethodReflection<CampaignConfig, void>(
          this,
          Entity,
          'setID',
          __TR.tVoid,
          false,
          (o) => o!.setID,
          obj,
          const <__PR>[__PR(__TR.tDynamic, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'getfieldentityannotations':
        return MethodReflection<CampaignConfig, List<EntityAnnotation>?>(
          this,
          Entity,
          'getFieldEntityAnnotations',
          const __TR<List<EntityAnnotation>>(List, <__TR>[
            __TR<EntityAnnotation>(EntityAnnotation),
          ]),
          true,
          (o) => o!.getFieldEntityAnnotations,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          null,
        );
      case 'tojsonencoded':
        return MethodReflection<CampaignConfig, String>(
          this,
          Entity,
          'toJsonEncoded',
          __TR.tString,
          false,
          (o) => o!.toJsonEncoded,
          obj,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<CampaignConfig, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<CampaignConfig, R>? staticMethod<R>(
    String methodName,
  ) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<CampaignConfig, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<CampaignConfig, R>;
  }

  StaticMethodReflection<CampaignConfig, dynamic>? _staticMethodImpl(
    String methodName,
  ) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<CampaignConfig, FutureOr<CampaignConfig>>(
          this,
          CampaignConfig,
          'fromMap',
          const __TR<FutureOr<CampaignConfig>>(FutureOr, <__TR>[
            __TR<CampaignConfig>(CampaignConfig),
          ]),
          false,
          () => CampaignConfig.fromMap,
          const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

class Item$reflection extends ClassReflection<Item> with __ReflectionMixin {
  static final Expando<Item$reflection> _objectReflections = Expando();

  factory Item$reflection([Item? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Item$reflection._(object);
  }

  Item$reflection._([Item? object]) : super(Item, r'Item', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.7.0');

  @override
  Item$reflection withObject([Item? obj]) =>
      Item$reflection(obj)..setupInternalsWith(this);

  static Item$reflection? _withoutObjectInstance;
  @override
  Item$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Item$reflection get staticInstance =>
      _withoutObjectInstance ??= Item$reflection._();

  @override
  Item$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Item$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Item? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Item? createInstanceWithEmptyConstructor() => Item.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Item? createInstanceWithNoRequiredArgsConstructor() => Item.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Item>> _constructors = {};

  @override
  ConstructorReflection<Item>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Item>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Item>(
          this,
          Item,
          '',
          () => Item.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{
            'bonus': __PR(__TR.tObject, 'bonus', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
        );
      case 'empty':
        return ConstructorReflection<Item>(
          this,
          Item,
          'empty',
          () => Item.empty,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Entity];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Item? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'bonus',
    'fieldsNames',
    'id',
    'idFieldName',
    'name',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Item, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Item, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Item, T>? field<T>(String fieldName, [Item? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Item, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Item, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Item, T>;
  }

  FieldReflection<Item, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Item, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Item, dynamic>? _fieldImpl(String fieldName, Item? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Item, int?>(
          this,
          Item,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Item, String>(
          this,
          Item,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name,
          (o) => (v) => o!.name = v,
          obj,
          false,
        );
      case 'bonus':
        return FieldReflection<Item, EntityReference<Bonus>>(
          this,
          Item,
          const __TR<EntityReference<Bonus>>(EntityReference, <__TR>[
            __TR<Bonus>(Bonus),
          ]),
          'bonus',
          false,
          (o) => () => o!.bonus,
          (o) => (v) => o!.bonus = v,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<Item, String>(
          this,
          Item,
          __TR.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName,
          null,
          obj,
          false,
          const [override],
        );
      case 'fieldsnames':
        return FieldReflection<Item, List<String>>(
          this,
          Item,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Item? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'bonus': obj?.bonus,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(
    Item? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'bonus': obj?.bonus,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Item, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Item, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Item, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Item, R>? method<R>(String methodName, [Item? obj]) {
    if (obj == null) {
      if (object != null) {
        return _methodObjectImpl<R>(methodName);
      } else {
        return _methodNoObjectImpl<R>(methodName);
      }
    } else if (identical(obj, object)) {
      return _methodObjectImpl<R>(methodName);
    }
    return _methodNoObjectImpl<R>(methodName)?.withObject(obj);
  }

  MethodReflection<Item, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Item, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Item, R>;
  }

  MethodReflection<Item, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Item, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Item, dynamic>? _methodImpl(String methodName, Item? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Item, dynamic>(
          this,
          Item,
          'getField',
          __TR.tDynamic,
          true,
          (o) => o!.getField,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'getfieldtype':
        return MethodReflection<Item, TypeInfo<dynamic>?>(
          this,
          Item,
          'getFieldType',
          const __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
          true,
          (o) => o!.getFieldType,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'setfield':
        return MethodReflection<Item, void>(
          this,
          Item,
          'setField',
          __TR.tVoid,
          false,
          (o) => o!.setField,
          obj,
          const <__PR>[
            __PR(__TR.tString, 'key', false, true),
            __PR(__TR.tDynamic, 'value', true, true),
          ],
          null,
          null,
          const [override],
        );
      case 'tojson':
        return MethodReflection<Item, Map<String, dynamic>>(
          this,
          Item,
          'toJson',
          __TR.tMapStringDynamic,
          false,
          (o) => o!.toJson,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getid':
        return MethodReflection<Item, dynamic>(
          this,
          Entity,
          'getID',
          __TR.tDynamic,
          true,
          (o) => o!.getID,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'setid':
        return MethodReflection<Item, void>(
          this,
          Entity,
          'setID',
          __TR.tVoid,
          false,
          (o) => o!.setID,
          obj,
          const <__PR>[__PR(__TR.tDynamic, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'getfieldentityannotations':
        return MethodReflection<Item, List<EntityAnnotation>?>(
          this,
          Entity,
          'getFieldEntityAnnotations',
          const __TR<List<EntityAnnotation>>(List, <__TR>[
            __TR<EntityAnnotation>(EntityAnnotation),
          ]),
          true,
          (o) => o!.getFieldEntityAnnotations,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          null,
        );
      case 'tojsonencoded':
        return MethodReflection<Item, String>(
          this,
          Entity,
          'toJsonEncoded',
          __TR.tString,
          false,
          (o) => o!.toJsonEncoded,
          obj,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Item, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<Item, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Item, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Item, R>;
  }

  StaticMethodReflection<Item, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<Item, FutureOr<Item>>(
          this,
          Item,
          'fromMap',
          const __TR<FutureOr<Item>>(FutureOr, <__TR>[__TR<Item>(Item)]),
          false,
          () => Item.fromMap,
          const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

class Order$reflection extends ClassReflection<Order> with __ReflectionMixin {
  static final Expando<Order$reflection> _objectReflections = Expando();

  factory Order$reflection([Order? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Order$reflection._(object);
  }

  Order$reflection._([Order? object]) : super(Order, r'Order', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.7.0');

  @override
  Order$reflection withObject([Order? obj]) =>
      Order$reflection(obj)..setupInternalsWith(this);

  static Order$reflection? _withoutObjectInstance;
  @override
  Order$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Order$reflection get staticInstance =>
      _withoutObjectInstance ??= Order$reflection._();

  @override
  Order$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Order$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Order? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Order? createInstanceWithEmptyConstructor() => Order.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Order? createInstanceWithNoRequiredArgsConstructor() => Order.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Order>> _constructors = {};

  @override
  ConstructorReflection<Order>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Order>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Order>(
          this,
          Order,
          '',
          () => Order.new,
          const <__PR>[__PR(__TR.tString, 'orderNumber', false, true)],
          null,
          const <String, __PR>{
            'id': __PR(__TR.tInt, 'id', true, false),
            'items': __PR(
              __TR<List<Item>>(List, <__TR>[__TR<Item>(Item)]),
              'items',
              true,
              false,
            ),
          },
          null,
        );
      case 'empty':
        return ConstructorReflection<Order>(
          this,
          Order,
          'empty',
          () => Order.empty,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Entity];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Order? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'fieldsNames',
    'id',
    'idFieldName',
    'items',
    'orderNumber',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Order, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Order, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Order, T>? field<T>(String fieldName, [Order? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Order, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Order, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Order, T>;
  }

  FieldReflection<Order, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Order, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Order, dynamic>? _fieldImpl(String fieldName, Order? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Order, int?>(
          this,
          Order,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'ordernumber':
        return FieldReflection<Order, String>(
          this,
          Order,
          __TR.tString,
          'orderNumber',
          false,
          (o) => () => o!.orderNumber,
          (o) => (v) => o!.orderNumber = v,
          obj,
          false,
        );
      case 'items':
        return FieldReflection<Order, List<Item>>(
          this,
          Order,
          const __TR<List<Item>>(List, <__TR>[__TR<Item>(Item)]),
          'items',
          false,
          (o) => () => o!.items,
          (o) => (v) => o!.items = v,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<Order, String>(
          this,
          Order,
          __TR.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName,
          null,
          obj,
          false,
          const [override],
        );
      case 'fieldsnames':
        return FieldReflection<Order, List<String>>(
          this,
          Order,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Order? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'orderNumber': obj?.orderNumber,
      'items': obj?.items,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(
    Order? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'orderNumber': obj?.orderNumber,
      'items': obj?.items,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Order, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Order, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Order, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Order, R>? method<R>(String methodName, [Order? obj]) {
    if (obj == null) {
      if (object != null) {
        return _methodObjectImpl<R>(methodName);
      } else {
        return _methodNoObjectImpl<R>(methodName);
      }
    } else if (identical(obj, object)) {
      return _methodObjectImpl<R>(methodName);
    }
    return _methodNoObjectImpl<R>(methodName)?.withObject(obj);
  }

  MethodReflection<Order, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Order, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Order, R>;
  }

  MethodReflection<Order, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Order, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Order, dynamic>? _methodImpl(String methodName, Order? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Order, dynamic>(
          this,
          Order,
          'getField',
          __TR.tDynamic,
          true,
          (o) => o!.getField,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'getfieldtype':
        return MethodReflection<Order, TypeInfo<dynamic>?>(
          this,
          Order,
          'getFieldType',
          const __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
          true,
          (o) => o!.getFieldType,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          const [override],
        );
      case 'setfield':
        return MethodReflection<Order, void>(
          this,
          Order,
          'setField',
          __TR.tVoid,
          false,
          (o) => o!.setField,
          obj,
          const <__PR>[
            __PR(__TR.tString, 'key', false, true),
            __PR(__TR.tDynamic, 'value', true, true),
          ],
          null,
          null,
          const [override],
        );
      case 'tojson':
        return MethodReflection<Order, Map<String, dynamic>>(
          this,
          Order,
          'toJson',
          __TR.tMapStringDynamic,
          false,
          (o) => o!.toJson,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getid':
        return MethodReflection<Order, dynamic>(
          this,
          Entity,
          'getID',
          __TR.tDynamic,
          true,
          (o) => o!.getID,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'setid':
        return MethodReflection<Order, void>(
          this,
          Entity,
          'setID',
          __TR.tVoid,
          false,
          (o) => o!.setID,
          obj,
          const <__PR>[__PR(__TR.tDynamic, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'getfieldentityannotations':
        return MethodReflection<Order, List<EntityAnnotation>?>(
          this,
          Entity,
          'getFieldEntityAnnotations',
          const __TR<List<EntityAnnotation>>(List, <__TR>[
            __TR<EntityAnnotation>(EntityAnnotation),
          ]),
          true,
          (o) => o!.getFieldEntityAnnotations,
          obj,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          null,
          null,
        );
      case 'tojsonencoded':
        return MethodReflection<Order, String>(
          this,
          Entity,
          'toJsonEncoded',
          __TR.tString,
          false,
          (o) => o!.toJsonEncoded,
          obj,
          null,
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Order, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<Order, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Order, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Order, R>;
  }

  StaticMethodReflection<Order, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<Order, FutureOr<Order>>(
          this,
          Order,
          'fromMap',
          const __TR<FutureOr<Order>>(FutureOr, <__TR>[__TR<Order>(Order)]),
          false,
          () => Order.fromMap,
          const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

extension Bonus$reflectionExtension on Bonus {
  /// Returns a [ClassReflection] for type [Bonus]. (Generated by [ReflectionFactory])
  ClassReflection<Bonus> get reflection => Bonus$reflection(this);

  /// Returns a JSON [Map] for type [Bonus]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Bonus] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Campaign$reflectionExtension on Campaign {
  /// Returns a [ClassReflection] for type [Campaign]. (Generated by [ReflectionFactory])
  ClassReflection<Campaign> get reflection => Campaign$reflection(this);

  /// Returns a JSON [Map] for type [Campaign]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Campaign] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension CampaignConfig$reflectionExtension on CampaignConfig {
  /// Returns a [ClassReflection] for type [CampaignConfig]. (Generated by [ReflectionFactory])
  ClassReflection<CampaignConfig> get reflection =>
      CampaignConfig$reflection(this);

  /// Returns a JSON [Map] for type [CampaignConfig]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [CampaignConfig] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Item$reflectionExtension on Item {
  /// Returns a [ClassReflection] for type [Item]. (Generated by [ReflectionFactory])
  ClassReflection<Item> get reflection => Item$reflection(this);

  /// Returns a JSON [Map] for type [Item]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Item] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Order$reflectionExtension on Order {
  /// Returns a [ClassReflection] for type [Order]. (Generated by [ReflectionFactory])
  ClassReflection<Order> get reflection => Order$reflection(this);

  /// Returns a JSON [Map] for type [Order]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Order] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  Bonus$reflection(),
  Campaign$reflection(),
  CampaignConfig$reflection(),
  Item$reflection(),
  Order$reflection(),
];

List<Reflection>? _siblingsReflectionList;
List<Reflection> _siblingsReflection() =>
    _siblingsReflectionList ??= List<Reflection>.unmodifiable(
      _listSiblingsReflection(),
    );

bool _registerSiblingsReflectionCalled = false;
void _registerSiblingsReflection() {
  if (_registerSiblingsReflectionCalled) return;
  _registerSiblingsReflectionCalled = true;
  var length = _listSiblingsReflection().length;
  assert(length > 0);
}
