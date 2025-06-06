//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.5.1
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

part of 'bones_api_test_entities.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.5.1');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"closedStores":
      return const Symbol(r"closedStores");
    case r"creationTime":
      return const Symbol(r"creationTime");
    case r"enabled":
      return const Symbol(r"enabled");
    case r"id":
      return const Symbol(r"id");
    case r"latitude":
      return const Symbol(r"latitude");
    case r"level":
      return const Symbol(r"level");
    case r"longitude":
      return const Symbol(r"longitude");
    case r"owner":
      return const Symbol(r"owner");
    case r"photo":
      return const Symbol(r"photo");
    case r"stores":
      return const Symbol(r"stores");
    case r"userInfo":
      return const Symbol(r"userInfo");
    case r"value":
      return const Symbol(r"value");
    case r"wakeUpTime":
      return const Symbol(r"wakeUpTime");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
Account Account$fromJson(Map<String, Object?> map) =>
    Account$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Account Account$fromJsonEncoded(String jsonEncoded) =>
    Account$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Address Address$fromJson(Map<String, Object?> map) =>
    Address$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Address Address$fromJsonEncoded(String jsonEncoded) =>
    Address$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Photo Photo$fromJson(Map<String, Object?> map) =>
    Photo$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Photo Photo$fromJsonEncoded(String jsonEncoded) =>
    Photo$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Role Role$fromJson(Map<String, Object?> map) =>
    Role$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Role Role$fromJsonEncoded(String jsonEncoded) =>
    Role$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
RoleType? RoleType$from(Object? o) =>
    RoleType$reflection.staticInstance.from(o);
// ignore: non_constant_identifier_names
Store Store$fromJson(Map<String, Object?> map) =>
    Store$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Store Store$fromJsonEncoded(String jsonEncoded) =>
    Store$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
User User$fromJson(Map<String, Object?> map) =>
    User$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
User User$fromJsonEncoded(String jsonEncoded) =>
    User$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
UserInfo UserInfo$fromJson(Map<String, Object?> map) =>
    UserInfo$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
UserInfo UserInfo$fromJsonEncoded(String jsonEncoded) =>
    UserInfo$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class Account$reflection extends ClassReflection<Account>
    with __ReflectionMixin {
  static final Expando<Account$reflection> _objectReflections = Expando();

  factory Account$reflection([Account? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Account$reflection._(object);
  }

  Account$reflection._([Account? object]) : super(Account, r'Account', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  Account$reflection withObject([Account? obj]) =>
      Account$reflection(obj)..setupInternalsWith(this);

  static Account$reflection? _withoutObjectInstance;
  @override
  Account$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Account$reflection get staticInstance =>
      _withoutObjectInstance ??= Account$reflection._();

  @override
  Account$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Account$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Account? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Account? createInstanceWithEmptyConstructor() => Account.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Account? createInstanceWithNoRequiredArgsConstructor() => Account.empty();

  static const List<String> _constructorsNames = const <String>[
    '',
    'empty',
    'entityReference'
  ];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Account>> _constructors = {};

  @override
  ConstructorReflection<Account>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Account>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case 'entityreference':
        return ConstructorReflection<Account>(
            this,
            Account,
            'entityReference',
            () => Account.entityReference,
            const <__PR>[__PR(__TR<User>(User), 'user', false, true)],
            null,
            const <String, __PR>{
              'userInfo': __PR(
                  __TR<EntityReference<UserInfo>>(
                      EntityReference, <__TR>[__TR<UserInfo>(UserInfo)]),
                  'userInfo',
                  false,
                  true)
            },
            null);
      case '':
        return ConstructorReflection<Account>(
            this,
            Account,
            '',
            () => Account.new,
            const <__PR>[__PR(__TR<User>(User), 'user', false, true)],
            null,
            const <String, __PR>{
              'userInfo': __PR(__TR.tObject, 'userInfo', true, false)
            },
            null);
      case 'empty':
        return ConstructorReflection<Account>(this, Account, 'empty',
            () => Account.empty, null, null, null, null);
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
  Object? callMethodToJson([Account? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'user',
    'userInfo'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Account, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Account, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Account, T>? field<T>(String fieldName, [Account? obj]) {
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

  FieldReflection<Account, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Account, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Account, T>;
  }

  FieldReflection<Account, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Account, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Account, dynamic>? _fieldImpl(
      String fieldName, Account? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Account, int?>(
          this,
          Account,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'user':
        return FieldReflection<Account, User>(
          this,
          Account,
          __TR<User>(User),
          'user',
          false,
          (o) => () => o!.user,
          (o) => (v) => o!.user = v,
          obj,
          false,
        );
      case 'userinfo':
        return FieldReflection<Account, EntityReference<UserInfo>>(
          this,
          Account,
          __TR<EntityReference<UserInfo>>(
              EntityReference, <__TR>[__TR<UserInfo>(UserInfo)]),
          'userInfo',
          false,
          (o) => () => o!.userInfo,
          (o) => (v) => o!.userInfo = v,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<Account, int>(
          this,
          Account,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<Account, String>(
          this,
          Account,
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
        return FieldReflection<Account, List<String>>(
          this,
          Account,
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
  Map<String, dynamic> getFieldsValues(Account? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'user': obj?.user,
      'userInfo': obj?.userInfo,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(Account? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'user': obj?.user,
      'userInfo': obj?.userInfo,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Account, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Account, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<Account, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Account, R>? method<R>(String methodName, [Account? obj]) {
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

  MethodReflection<Account, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Account, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Account, R>;
  }

  MethodReflection<Account, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Account, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Account, dynamic>? _methodImpl(
      String methodName, Account? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Account, dynamic>(
            this,
            Account,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<Account, TypeInfo<dynamic>?>(
            this,
            Account,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<Account, void>(
            this,
            Account,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<Account, Map<String, dynamic>>(
            this,
            Account,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<Account, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<Account, void>(
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
            null);
      case 'getfieldentityannotations':
        return MethodReflection<Account, List<EntityAnnotation>?>(
            this,
            Entity,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Account, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Account, R>? staticMethod<R>(String methodName) =>
      null;
}

class Address$reflection extends ClassReflection<Address>
    with __ReflectionMixin {
  static final Expando<Address$reflection> _objectReflections = Expando();

  factory Address$reflection([Address? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Address$reflection._(object);
  }

  Address$reflection._([Address? object]) : super(Address, r'Address', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  Address$reflection withObject([Address? obj]) =>
      Address$reflection(obj)..setupInternalsWith(this);

  static Address$reflection? _withoutObjectInstance;
  @override
  Address$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Address$reflection get staticInstance =>
      _withoutObjectInstance ??= Address$reflection._();

  @override
  Address$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Address$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Address? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Address? createInstanceWithEmptyConstructor() => Address.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Address? createInstanceWithNoRequiredArgsConstructor() => Address.empty();

  static const List<String> _constructorsNames = const <String>[
    '',
    'empty',
    'fromMap'
  ];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Address>> _constructors = {};

  @override
  ConstructorReflection<Address>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Address>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Address>(
            this,
            Address,
            '',
            () => Address.new,
            const <__PR>[
              __PR(__TR.tString, 'state', false, true),
              __PR(__TR.tString, 'city', false, true),
              __PR(__TR.tString, 'street', false, true),
              __PR(__TR.tInt, 'number', false, true)
            ],
            null,
            const <String, __PR>{
              'closedStores': __PR(__TR.tObject, 'closedStores', true, false),
              'id': __PR(__TR.tInt, 'id', true, false),
              'latitude': __PR(__TR.tObject, 'latitude', true, false),
              'longitude': __PR(__TR.tObject, 'longitude', true, false),
              'stores': __PR(
                  __TR<List<Store>>(List, <__TR>[__TR<Store>(Store)]),
                  'stores',
                  true,
                  false)
            },
            null);
      case 'empty':
        return ConstructorReflection<Address>(this, Address, 'empty',
            () => Address.empty, null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Address>(
            this,
            Address,
            'fromMap',
            () => Address.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
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
  Object? callMethodToJson([Address? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'city',
    'closedStores',
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'latitude',
    'longitude',
    'number',
    'state',
    'stores',
    'street'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Address, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Address, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Address, T>? field<T>(String fieldName, [Address? obj]) {
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

  FieldReflection<Address, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Address, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Address, T>;
  }

  FieldReflection<Address, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Address, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Address, dynamic>? _fieldImpl(
      String fieldName, Address? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Address, int?>(
          this,
          Address,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'state':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'state',
          false,
          (o) => () => o!.state,
          (o) => (v) => o!.state = v,
          obj,
          false,
          const [EntityField.indexed(), EntityField.maximum(3)],
        );
      case 'city':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'city',
          false,
          (o) => () => o!.city,
          (o) => (v) => o!.city = v,
          obj,
          false,
          const [EntityField.maximum(100)],
        );
      case 'street':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'street',
          false,
          (o) => () => o!.street,
          (o) => (v) => o!.street = v,
          obj,
          false,
          const [EntityField.maximum(200)],
        );
      case 'number':
        return FieldReflection<Address, int>(
          this,
          Address,
          __TR.tInt,
          'number',
          false,
          (o) => () => o!.number,
          (o) => (v) => o!.number = v,
          obj,
          false,
        );
      case 'latitude':
        return FieldReflection<Address, Decimal>(
          this,
          Address,
          __TR<Decimal>(Decimal),
          'latitude',
          false,
          (o) => () => o!.latitude,
          (o) => (v) => o!.latitude = v,
          obj,
          false,
        );
      case 'longitude':
        return FieldReflection<Address, Decimal>(
          this,
          Address,
          __TR<Decimal>(Decimal),
          'longitude',
          false,
          (o) => () => o!.longitude,
          (o) => (v) => o!.longitude = v,
          obj,
          false,
        );
      case 'stores':
        return FieldReflection<Address, List<Store>>(
          this,
          Address,
          __TR<List<Store>>(List, <__TR>[__TR<Store>(Store)]),
          'stores',
          false,
          (o) => () => o!.stores,
          (o) => (v) => o!.stores = v,
          obj,
          false,
        );
      case 'closedstores':
        return FieldReflection<Address, EntityReferenceList<Store>>(
          this,
          Address,
          __TR<EntityReferenceList<Store>>(
              EntityReferenceList, <__TR>[__TR<Store>(Store)]),
          'closedStores',
          false,
          (o) => () => o!.closedStores,
          (o) => (v) => o!.closedStores = v,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<Address, int>(
          this,
          Address,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<Address, String>(
          this,
          Address,
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
        return FieldReflection<Address, List<String>>(
          this,
          Address,
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
  Map<String, dynamic> getFieldsValues(Address? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'state': obj?.state,
      'city': obj?.city,
      'street': obj?.street,
      'number': obj?.number,
      'latitude': obj?.latitude,
      'longitude': obj?.longitude,
      'stores': obj?.stores,
      'closedStores': obj?.closedStores,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(Address? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'state': obj?.state,
      'city': obj?.city,
      'street': obj?.street,
      'number': obj?.number,
      'latitude': obj?.latitude,
      'longitude': obj?.longitude,
      'stores': obj?.stores,
      'closedStores': obj?.closedStores,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Address, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Address, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<Address, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Address, R>? method<R>(String methodName, [Address? obj]) {
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

  MethodReflection<Address, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Address, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Address, R>;
  }

  MethodReflection<Address, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Address, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Address, dynamic>? _methodImpl(
      String methodName, Address? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Address, dynamic>(
            this,
            Address,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<Address, TypeInfo<dynamic>?>(
            this,
            Address,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldentityannotations':
        return MethodReflection<Address, List<EntityAnnotation>?>(
            this,
            Address,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<Address, void>(
            this,
            Address,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<Address, Map<String, dynamic>>(
            this,
            Address,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<Address, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<Address, void>(
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
            null);
      case 'tojsonencoded':
        return MethodReflection<Address, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Address, R>? staticMethod<R>(String methodName) =>
      null;
}

class Photo$reflection extends ClassReflection<Photo> with __ReflectionMixin {
  static final Expando<Photo$reflection> _objectReflections = Expando();

  factory Photo$reflection([Photo? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Photo$reflection._(object);
  }

  Photo$reflection._([Photo? object]) : super(Photo, r'Photo', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  Photo$reflection withObject([Photo? obj]) =>
      Photo$reflection(obj)..setupInternalsWith(this);

  static Photo$reflection? _withoutObjectInstance;
  @override
  Photo$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Photo$reflection get staticInstance =>
      _withoutObjectInstance ??= Photo$reflection._();

  @override
  Photo$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Photo$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Photo? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Photo? createInstanceWithEmptyConstructor() => Photo.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Photo? createInstanceWithNoRequiredArgsConstructor() => Photo.empty();

  static const List<String> _constructorsNames = const <String>[
    'empty',
    'from',
    'fromData',
    'fromID'
  ];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Photo>> _constructors = {};

  @override
  ConstructorReflection<Photo>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Photo>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case 'fromid':
        return ConstructorReflection<Photo>(
            this,
            Photo,
            'fromID',
            () => Photo.fromID,
            const <__PR>[__PR(__TR.tString, 'id', false, true)],
            null,
            null,
            null);
      case 'fromdata':
        return ConstructorReflection<Photo>(
            this,
            Photo,
            'fromData',
            () => Photo.fromData,
            const <__PR>[__PR(__TR<Uint8List>(Uint8List), 'data', false, true)],
            null,
            const <String, __PR>{'id': __PR(__TR.tString, 'id', true, false)},
            null);
      case 'from':
        return ConstructorReflection<Photo>(
            this,
            Photo,
            'from',
            () => Photo.from,
            const <__PR>[__PR(__TR.tObject, 'o', false, true)],
            null,
            const <String, __PR>{'id': __PR(__TR.tString, 'id', true, false)},
            null);
      case 'empty':
        return ConstructorReflection<Photo>(
            this, Photo, 'empty', () => Photo.empty, null, null, null, null);
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
  Object? callMethodToJson([Photo? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'data',
    'dataUrl',
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Photo, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Photo, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Photo, T>? field<T>(String fieldName, [Photo? obj]) {
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

  FieldReflection<Photo, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Photo, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Photo, T>;
  }

  FieldReflection<Photo, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Photo, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Photo, dynamic>? _fieldImpl(String fieldName, Photo? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Photo, String>(
          this,
          Photo,
          __TR.tString,
          'id',
          false,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'data':
        return FieldReflection<Photo, Uint8List?>(
          this,
          Photo,
          __TR<Uint8List>(Uint8List),
          'data',
          true,
          (o) => () => o!.data,
          (o) => (v) => o!.data = v,
          obj,
          false,
        );
      case 'dataurl':
        return FieldReflection<Photo, String?>(
          this,
          Photo,
          __TR.tString,
          'dataUrl',
          true,
          (o) => () => o!.dataUrl,
          null,
          obj,
          false,
        );
      case 'idfieldname':
        return FieldReflection<Photo, String>(
          this,
          Photo,
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
        return FieldReflection<Photo, List<String>>(
          this,
          Photo,
          __TR.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames,
          null,
          obj,
          false,
          const [JsonField.hidden(), override],
        );
      case 'hashcode':
        return FieldReflection<Photo, int>(
          this,
          Photo,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Photo? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'data': obj?.data,
      'dataUrl': obj?.dataUrl,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(Photo? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'data': obj?.data,
      'dataUrl': obj?.dataUrl,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Photo, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
    'toString'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Photo, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Photo, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Photo, R>? method<R>(String methodName, [Photo? obj]) {
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

  MethodReflection<Photo, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Photo, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Photo, R>;
  }

  MethodReflection<Photo, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Photo, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Photo, dynamic>? _methodImpl(String methodName, Photo? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Photo, dynamic>(
            this,
            Photo,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<Photo, TypeInfo<dynamic>?>(
            this,
            Photo,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<Photo, void>(
            this,
            Photo,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<Photo, Map<String, dynamic>>(
            this,
            Photo,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'tostring':
        return MethodReflection<Photo, String>(
            this,
            Photo,
            'toString',
            __TR.tString,
            false,
            (o) => o!.toString,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<Photo, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<Photo, void>(
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
            null);
      case 'getfieldentityannotations':
        return MethodReflection<Photo, List<EntityAnnotation>?>(
            this,
            Entity,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Photo, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[
    'computeID',
    'fromMap'
  ];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Photo, dynamic>>
      _staticMethods = {};

  @override
  StaticMethodReflection<Photo, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Photo, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Photo, R>;
  }

  StaticMethodReflection<Photo, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'computeid':
        return StaticMethodReflection<Photo, String>(
            this,
            Photo,
            'computeID',
            __TR.tString,
            false,
            () => Photo.computeID,
            const <__PR>[__PR(__TR<Uint8List>(Uint8List), 'data', false, true)],
            null,
            null,
            null);
      case 'frommap':
        return StaticMethodReflection<Photo, Photo>(
            this,
            Photo,
            'fromMap',
            __TR<Photo>(Photo),
            false,
            () => Photo.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

class Role$reflection extends ClassReflection<Role> with __ReflectionMixin {
  static final Expando<Role$reflection> _objectReflections = Expando();

  factory Role$reflection([Role? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Role$reflection._(object);
  }

  Role$reflection._([Role? object]) : super(Role, r'Role', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  Role$reflection withObject([Role? obj]) =>
      Role$reflection(obj)..setupInternalsWith(this);

  static Role$reflection? _withoutObjectInstance;
  @override
  Role$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Role$reflection get staticInstance =>
      _withoutObjectInstance ??= Role$reflection._();

  @override
  Role$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Role$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Role? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Role? createInstanceWithEmptyConstructor() => Role.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Role? createInstanceWithNoRequiredArgsConstructor() => Role.empty();

  static const List<String> _constructorsNames = const <String>[
    '',
    'empty',
    'fromMap'
  ];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Role>> _constructors = {};

  @override
  ConstructorReflection<Role>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Role>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Role>(
            this,
            Role,
            '',
            () => Role.new,
            const <__PR>[__PR(__TR<RoleType>(RoleType), 'type', false, true)],
            null,
            const <String, __PR>{
              'enabled': __PR(__TR.tBool, 'enabled', false, false, true),
              'id': __PR(__TR.tInt, 'id', true, false),
              'value': __PR(__TR<Decimal>(Decimal), 'value', true, false)
            },
            null);
      case 'empty':
        return ConstructorReflection<Role>(
            this, Role, 'empty', () => Role.empty, null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Role>(
            this,
            Role,
            'fromMap',
            () => Role.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
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
  Object? callMethodToJson([Role? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'enabled',
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'type',
    'value'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Role, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Role, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Role, T>? field<T>(String fieldName, [Role? obj]) {
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

  FieldReflection<Role, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Role, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Role, T>;
  }

  FieldReflection<Role, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Role, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Role, dynamic>? _fieldImpl(String fieldName, Role? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Role, int?>(
          this,
          Role,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'type':
        return FieldReflection<Role, RoleType>(
          this,
          Role,
          __TR<RoleType>(RoleType),
          'type',
          false,
          (o) => () => o!.type,
          (o) => (v) => o!.type = v,
          obj,
          false,
        );
      case 'enabled':
        return FieldReflection<Role, bool>(
          this,
          Role,
          __TR.tBool,
          'enabled',
          false,
          (o) => () => o!.enabled,
          (o) => (v) => o!.enabled = v,
          obj,
          false,
        );
      case 'value':
        return FieldReflection<Role, Decimal?>(
          this,
          Role,
          __TR<Decimal>(Decimal),
          'value',
          true,
          (o) => () => o!.value,
          (o) => (v) => o!.value = v,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<Role, int>(
          this,
          Role,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<Role, String>(
          this,
          Role,
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
        return FieldReflection<Role, List<String>>(
          this,
          Role,
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
  Map<String, dynamic> getFieldsValues(Role? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'type': obj?.type,
      'enabled': obj?.enabled,
      'value': obj?.value,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(Role? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'type': obj?.type,
      'enabled': obj?.enabled,
      'value': obj?.value,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Role, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
    'toString'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Role, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Role, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Role, R>? method<R>(String methodName, [Role? obj]) {
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

  MethodReflection<Role, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Role, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Role, R>;
  }

  MethodReflection<Role, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Role, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Role, dynamic>? _methodImpl(String methodName, Role? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Role, dynamic>(
            this,
            Role,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<Role, TypeInfo<dynamic>?>(
            this,
            Role,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<Role, void>(
            this,
            Role,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<Role, Map<String, dynamic>>(
            this,
            Role,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'tostring':
        return MethodReflection<Role, String>(
            this,
            Role,
            'toString',
            __TR.tString,
            false,
            (o) => o!.toString,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<Role, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<Role, void>(
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
            null);
      case 'getfieldentityannotations':
        return MethodReflection<Role, List<EntityAnnotation>?>(
            this,
            Entity,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Role, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Role, R>? staticMethod<R>(String methodName) => null;
}

class RoleType$reflection extends EnumReflection<RoleType>
    with __ReflectionMixin {
  static final Expando<RoleType$reflection> _objectReflections = Expando();

  factory RoleType$reflection([RoleType? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= RoleType$reflection._(object);
  }

  RoleType$reflection._([RoleType? object])
      : super(RoleType, r'RoleType', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  RoleType$reflection withObject([RoleType? obj]) => RoleType$reflection(obj);

  static RoleType$reflection? _withoutObjectInstance;
  @override
  RoleType$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static RoleType$reflection get staticInstance =>
      _withoutObjectInstance ??= RoleType$reflection._();

  @override
  RoleType$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    RoleType$reflection.staticInstance;
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<String> _staticFieldsNames = const <String>[
    'admin',
    'guest',
    'unknown'
  ];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  static const Map<String, RoleType> _valuesByName = const <String, RoleType>{
    'admin': RoleType.admin,
    'guest': RoleType.guest,
    'unknown': RoleType.unknown,
  };

  @override
  Map<String, RoleType> get valuesByName => _valuesByName;
  @override
  List<RoleType> get values => RoleType.values;

  static const List<String> _fieldsNames = const <String>[];

  @override
  List<String> get fieldsNames => _fieldsNames;
}

class Store$reflection extends ClassReflection<Store> with __ReflectionMixin {
  static final Expando<Store$reflection> _objectReflections = Expando();

  factory Store$reflection([Store? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Store$reflection._(object);
  }

  Store$reflection._([Store? object]) : super(Store, r'Store', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  Store$reflection withObject([Store? obj]) =>
      Store$reflection(obj)..setupInternalsWith(this);

  static Store$reflection? _withoutObjectInstance;
  @override
  Store$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Store$reflection get staticInstance =>
      _withoutObjectInstance ??= Store$reflection._();

  @override
  Store$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Store$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Store? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Store? createInstanceWithEmptyConstructor() => Store.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Store? createInstanceWithNoRequiredArgsConstructor() => Store.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Store>> _constructors = {};

  @override
  ConstructorReflection<Store>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Store>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Store>(
            this,
            Store,
            '',
            () => Store.new,
            const <__PR>[
              __PR(__TR.tString, 'name', false, true),
              __PR(__TR.tInt, 'number', true, true)
            ],
            null,
            const <String, __PR>{
              'id': __PR(__TR.tInt, 'id', true, false),
              'owner': __PR(__TR<User>(User), 'owner', true, false)
            },
            null);
      case 'empty':
        return ConstructorReflection<Store>(
            this, Store, 'empty', () => Store.empty, null, null, null, null);
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
  Object? callMethodToJson([Store? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'name',
    'number',
    'owner'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Store, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Store, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Store, T>? field<T>(String fieldName, [Store? obj]) {
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

  FieldReflection<Store, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Store, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Store, T>;
  }

  FieldReflection<Store, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Store, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Store, dynamic>? _fieldImpl(String fieldName, Store? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Store, int?>(
          this,
          Store,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Store, String>(
          this,
          Store,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name,
          (o) => (v) => o!.name = v,
          obj,
          false,
          const [EntityField.maximum(100)],
        );
      case 'number':
        return FieldReflection<Store, int?>(
          this,
          Store,
          __TR.tInt,
          'number',
          true,
          (o) => () => o!.number,
          (o) => (v) => o!.number = v,
          obj,
          false,
        );
      case 'owner':
        return FieldReflection<Store, User?>(
          this,
          Store,
          __TR<User>(User),
          'owner',
          true,
          (o) => () => o!.owner,
          (o) => (v) => o!.owner = v,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<Store, int>(
          this,
          Store,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<Store, String>(
          this,
          Store,
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
        return FieldReflection<Store, List<String>>(
          this,
          Store,
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
  Map<String, dynamic> getFieldsValues(Store? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'number': obj?.number,
      'owner': obj?.owner,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(Store? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'number': obj?.number,
      'owner': obj?.owner,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Store, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<Store, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<Store, dynamic>> _methodsObject = {};

  @override
  MethodReflection<Store, R>? method<R>(String methodName, [Store? obj]) {
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

  MethodReflection<Store, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<Store, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<Store, R>;
  }

  MethodReflection<Store, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<Store, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<Store, dynamic>? _methodImpl(String methodName, Store? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Store, dynamic>(
            this,
            Store,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<Store, TypeInfo<dynamic>?>(
            this,
            Store,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldentityannotations':
        return MethodReflection<Store, List<EntityAnnotation>?>(
            this,
            Store,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<Store, void>(
            this,
            Store,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<Store, Map<String, dynamic>>(
            this,
            Store,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<Store, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<Store, void>(
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
            null);
      case 'tojsonencoded':
        return MethodReflection<Store, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<Store, dynamic>>
      _staticMethods = {};

  @override
  StaticMethodReflection<Store, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<Store, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<Store, R>;
  }

  StaticMethodReflection<Store, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<Store, FutureOr<Store>>(
            this,
            Store,
            'fromMap',
            __TR<FutureOr<Store>>(FutureOr, <__TR>[__TR<Store>(Store)]),
            false,
            () => Store.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

class User$reflection extends ClassReflection<User> with __ReflectionMixin {
  static final Expando<User$reflection> _objectReflections = Expando();

  factory User$reflection([User? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= User$reflection._(object);
  }

  User$reflection._([User? object]) : super(User, r'User', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  User$reflection withObject([User? obj]) =>
      User$reflection(obj)..setupInternalsWith(this);

  static User$reflection? _withoutObjectInstance;
  @override
  User$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static User$reflection get staticInstance =>
      _withoutObjectInstance ??= User$reflection._();

  @override
  User$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    User$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  User? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  User? createInstanceWithEmptyConstructor() => User.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  User? createInstanceWithNoRequiredArgsConstructor() => User.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<User>> _constructors = {};

  @override
  ConstructorReflection<User>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<User>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<User>(
            this,
            User,
            '',
            () => User.new,
            const <__PR>[
              __PR(__TR.tString, 'email', false, true),
              __PR(__TR.tString, 'password', false, true),
              __PR(__TR<Address>(Address), 'address', false, true),
              __PR(__TR<List<Role>>(List, <__TR>[__TR<Role>(Role)]), 'roles',
                  false, true)
            ],
            null,
            const <String, __PR>{
              'creationTime':
                  __PR(__TR<DateTime>(DateTime), 'creationTime', true, false),
              'id': __PR(__TR.tInt, 'id', true, false),
              'level': __PR(__TR.tInt, 'level', true, false),
              'photo': __PR(__TR.tObject, 'photo', true, false),
              'userInfo': __PR(__TR.tObject, 'userInfo', true, false),
              'wakeUpTime': __PR(__TR<Time>(Time), 'wakeUpTime', true, false)
            },
            null);
      case 'empty':
        return ConstructorReflection<User>(
            this, User, 'empty', () => User.empty, null, null, null, null);
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
  Object? callMethodToJson([User? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'address',
    'creationTime',
    'email',
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'level',
    'password',
    'photo',
    'roles',
    'userInfo',
    'wakeUpTime'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<User, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<User, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<User, T>? field<T>(String fieldName, [User? obj]) {
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

  FieldReflection<User, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<User, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<User, T>;
  }

  FieldReflection<User, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<User, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<User, dynamic>? _fieldImpl(String fieldName, User? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<User, int?>(
          this,
          User,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'email':
        return FieldReflection<User, String>(
          this,
          User,
          __TR.tString,
          'email',
          false,
          (o) => () => o!.email,
          (o) => (v) => o!.email = v,
          obj,
          false,
          const [
            EntityField.unique(),
            EntityField.maximum(100),
            EntityField.regexp(r'[\w-.]+@\w+(?:\.\w+)*')
          ],
        );
      case 'password':
        return FieldReflection<User, String>(
          this,
          User,
          __TR.tString,
          'password',
          false,
          (o) => () => o!.password,
          (o) => (v) => o!.password = v,
          obj,
          false,
        );
      case 'address':
        return FieldReflection<User, Address>(
          this,
          User,
          __TR<Address>(Address),
          'address',
          false,
          (o) => () => o!.address,
          (o) => (v) => o!.address = v,
          obj,
          false,
        );
      case 'roles':
        return FieldReflection<User, List<Role>>(
          this,
          User,
          __TR<List<Role>>(List, <__TR>[__TR<Role>(Role)]),
          'roles',
          false,
          (o) => () => o!.roles,
          (o) => (v) => o!.roles = v,
          obj,
          false,
        );
      case 'level':
        return FieldReflection<User, int?>(
          this,
          User,
          __TR.tInt,
          'level',
          true,
          (o) => () => o!.level,
          (o) => (v) => o!.level = v,
          obj,
          false,
        );
      case 'wakeuptime':
        return FieldReflection<User, Time?>(
          this,
          User,
          __TR<Time>(Time),
          'wakeUpTime',
          true,
          (o) => () => o!.wakeUpTime,
          (o) => (v) => o!.wakeUpTime = v,
          obj,
          false,
        );
      case 'userinfo':
        return FieldReflection<User, EntityReference<UserInfo>>(
          this,
          User,
          __TR<EntityReference<UserInfo>>(
              EntityReference, <__TR>[__TR<UserInfo>(UserInfo)]),
          'userInfo',
          false,
          (o) => () => o!.userInfo,
          (o) => (v) => o!.userInfo = v,
          obj,
          false,
        );
      case 'photo':
        return FieldReflection<User, Photo?>(
          this,
          User,
          __TR<Photo>(Photo),
          'photo',
          true,
          (o) => () => o!.photo,
          (o) => (v) => o!.photo = v,
          obj,
          false,
        );
      case 'creationtime':
        return FieldReflection<User, DateTime>(
          this,
          User,
          __TR<DateTime>(DateTime),
          'creationTime',
          false,
          (o) => () => o!.creationTime,
          (o) => (v) => o!.creationTime = v,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<User, int>(
          this,
          User,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<User, String>(
          this,
          User,
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
        return FieldReflection<User, List<String>>(
          this,
          User,
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
  Map<String, dynamic> getFieldsValues(User? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'email': obj?.email,
      'password': obj?.password,
      'address': obj?.address,
      'roles': obj?.roles,
      'level': obj?.level,
      'wakeUpTime': obj?.wakeUpTime,
      'userInfo': obj?.userInfo,
      'photo': obj?.photo,
      'creationTime': obj?.creationTime,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(User? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'email': obj?.email,
      'password': obj?.password,
      'address': obj?.address,
      'roles': obj?.roles,
      'level': obj?.level,
      'wakeUpTime': obj?.wakeUpTime,
      'userInfo': obj?.userInfo,
      'photo': obj?.photo,
      'creationTime': obj?.creationTime,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<User, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
    'toString'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<User, dynamic>> _methodsNoObject =
      {};

  final Map<String, MethodReflection<User, dynamic>> _methodsObject = {};

  @override
  MethodReflection<User, R>? method<R>(String methodName, [User? obj]) {
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

  MethodReflection<User, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<User, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<User, R>;
  }

  MethodReflection<User, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<User, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<User, dynamic>? _methodImpl(String methodName, User? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<User, dynamic>(
            this,
            User,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<User, TypeInfo<dynamic>?>(
            this,
            User,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldentityannotations':
        return MethodReflection<User, List<EntityAnnotation>?>(
            this,
            User,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<User, void>(
            this,
            User,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<User, Map<String, dynamic>>(
            this,
            User,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'tostring':
        return MethodReflection<User, String>(
            this,
            User,
            'toString',
            __TR.tString,
            false,
            (o) => o!.toString,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<User, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<User, void>(
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
            null);
      case 'tojsonencoded':
        return MethodReflection<User, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<User, dynamic>>
      _staticMethods = {};

  @override
  StaticMethodReflection<User, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<User, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<User, R>;
  }

  StaticMethodReflection<User, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<User, FutureOr<User>>(
            this,
            User,
            'fromMap',
            __TR<FutureOr<User>>(FutureOr, <__TR>[__TR<User>(User)]),
            false,
            () => User.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

class UserInfo$reflection extends ClassReflection<UserInfo>
    with __ReflectionMixin {
  static final Expando<UserInfo$reflection> _objectReflections = Expando();

  factory UserInfo$reflection([UserInfo? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= UserInfo$reflection._(object);
  }

  UserInfo$reflection._([UserInfo? object])
      : super(UserInfo, r'UserInfo', object);

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
  Version get languageVersion => Version.parse('3.6.0');

  @override
  UserInfo$reflection withObject([UserInfo? obj]) =>
      UserInfo$reflection(obj)..setupInternalsWith(this);

  static UserInfo$reflection? _withoutObjectInstance;
  @override
  UserInfo$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static UserInfo$reflection get staticInstance =>
      _withoutObjectInstance ??= UserInfo$reflection._();

  @override
  UserInfo$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    UserInfo$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  UserInfo? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  UserInfo? createInstanceWithEmptyConstructor() => UserInfo.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  UserInfo? createInstanceWithNoRequiredArgsConstructor() => UserInfo.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<UserInfo>> _constructors = {};

  @override
  ConstructorReflection<UserInfo>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<UserInfo>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<UserInfo>(
            this,
            UserInfo,
            '',
            () => UserInfo.new,
            const <__PR>[__PR(__TR.tString, 'info', false, true)],
            null,
            const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
            null);
      case 'empty':
        return ConstructorReflection<UserInfo>(this, UserInfo, 'empty',
            () => UserInfo.empty, null, null, null, null);
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
  Object? callMethodToJson([UserInfo? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  static const List<String> _fieldsNames = const <String>[
    'fieldsNames',
    'hashCode',
    'id',
    'idFieldName',
    'info'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<UserInfo, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<UserInfo, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<UserInfo, T>? field<T>(String fieldName, [UserInfo? obj]) {
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

  FieldReflection<UserInfo, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<UserInfo, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<UserInfo, T>;
  }

  FieldReflection<UserInfo, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<UserInfo, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<UserInfo, dynamic>? _fieldImpl(
      String fieldName, UserInfo? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<UserInfo, int?>(
          this,
          UserInfo,
          __TR.tInt,
          'id',
          true,
          (o) => () => o!.id,
          (o) => (v) => o!.id = v,
          obj,
          false,
        );
      case 'info':
        return FieldReflection<UserInfo, String>(
          this,
          UserInfo,
          __TR.tString,
          'info',
          false,
          (o) => () => o!.info,
          (o) => (v) => o!.info = v,
          obj,
          false,
          const [EntityField.maximum(1000)],
        );
      case 'hashcode':
        return FieldReflection<UserInfo, int>(
          this,
          UserInfo,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'idfieldname':
        return FieldReflection<UserInfo, String>(
          this,
          UserInfo,
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
        return FieldReflection<UserInfo, List<String>>(
          this,
          UserInfo,
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
  Map<String, dynamic> getFieldsValues(UserInfo? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'info': obj?.info,
      'idFieldName': obj?.idFieldName,
      'fieldsNames': obj?.fieldsNames,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  @override
  Map<String, dynamic> getJsonFieldsVisibleValues(UserInfo? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'info': obj?.info,
      'idFieldName': obj?.idFieldName,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<UserInfo, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[
    'getField',
    'getFieldEntityAnnotations',
    'getFieldType',
    'getID',
    'setField',
    'setID',
    'toJson',
    'toJsonEncoded',
    'toString'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<UserInfo, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<UserInfo, dynamic>> _methodsObject = {};

  @override
  MethodReflection<UserInfo, R>? method<R>(String methodName, [UserInfo? obj]) {
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

  MethodReflection<UserInfo, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<UserInfo, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<UserInfo, R>;
  }

  MethodReflection<UserInfo, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<UserInfo, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<UserInfo, dynamic>? _methodImpl(
      String methodName, UserInfo? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'tostring':
        return MethodReflection<UserInfo, String>(
            this,
            UserInfo,
            'toString',
            __TR.tString,
            false,
            (o) => o!.toString,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getfield':
        return MethodReflection<UserInfo, dynamic>(
            this,
            UserInfo,
            'getField',
            __TR.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldtype':
        return MethodReflection<UserInfo, TypeInfo<dynamic>?>(
            this,
            UserInfo,
            'getFieldType',
            __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getFieldType,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'getfieldentityannotations':
        return MethodReflection<UserInfo, List<EntityAnnotation>?>(
            this,
            UserInfo,
            'getFieldEntityAnnotations',
            __TR<List<EntityAnnotation>>(
                List, <__TR>[__TR<EntityAnnotation>(EntityAnnotation)]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            const <__PR>[__PR(__TR.tString, 'key', false, true)],
            null,
            null,
            const [override]);
      case 'setfield':
        return MethodReflection<UserInfo, void>(
            this,
            UserInfo,
            'setField',
            __TR.tVoid,
            false,
            (o) => o!.setField,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'key', false, true),
              __PR(__TR.tDynamic, 'value', true, true)
            ],
            null,
            null,
            const [override]);
      case 'tojson':
        return MethodReflection<UserInfo, Map<String, dynamic>>(
            this,
            UserInfo,
            'toJson',
            __TR.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getid':
        return MethodReflection<UserInfo, dynamic>(this, Entity, 'getID',
            __TR.tDynamic, true, (o) => o!.getID, obj, null, null, null, null);
      case 'setid':
        return MethodReflection<UserInfo, void>(
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
            null);
      case 'tojsonencoded':
        return MethodReflection<UserInfo, String>(
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
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>['fromMap'];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<UserInfo, dynamic>>
      _staticMethods = {};

  @override
  StaticMethodReflection<UserInfo, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<UserInfo, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<UserInfo, R>;
  }

  StaticMethodReflection<UserInfo, dynamic>? _staticMethodImpl(
      String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return StaticMethodReflection<UserInfo, FutureOr<UserInfo>>(
            this,
            UserInfo,
            'fromMap',
            __TR<FutureOr<UserInfo>>(
                FutureOr, <__TR>[__TR<UserInfo>(UserInfo)]),
            false,
            () => UserInfo.fromMap,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

extension Account$reflectionExtension on Account {
  /// Returns a [ClassReflection] for type [Account]. (Generated by [ReflectionFactory])
  ClassReflection<Account> get reflection => Account$reflection(this);

  /// Returns a JSON [Map] for type [Account]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Account] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Address$reflectionExtension on Address {
  /// Returns a [ClassReflection] for type [Address]. (Generated by [ReflectionFactory])
  ClassReflection<Address> get reflection => Address$reflection(this);

  /// Returns a JSON [Map] for type [Address]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Address] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Photo$reflectionExtension on Photo {
  /// Returns a [ClassReflection] for type [Photo]. (Generated by [ReflectionFactory])
  ClassReflection<Photo> get reflection => Photo$reflection(this);

  /// Returns a JSON [Map] for type [Photo]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Photo] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Role$reflectionExtension on Role {
  /// Returns a [ClassReflection] for type [Role]. (Generated by [ReflectionFactory])
  ClassReflection<Role> get reflection => Role$reflection(this);

  /// Returns a JSON [Map] for type [Role]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Role] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension RoleType$reflectionExtension on RoleType {
  /// Returns a [EnumReflection] for type [RoleType]. (Generated by [ReflectionFactory])
  EnumReflection<RoleType> get reflection => RoleType$reflection(this);

  /// Returns the name of the [RoleType] instance. (Generated by [ReflectionFactory])
  String get enumName => RoleType$reflection(this).name()!;

  /// Returns a JSON for type [RoleType]. (Generated by [ReflectionFactory])
  String? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [RoleType]. (Generated by [ReflectionFactory])
  Map<String, Object>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [RoleType]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);
}

extension Store$reflectionExtension on Store {
  /// Returns a [ClassReflection] for type [Store]. (Generated by [ReflectionFactory])
  ClassReflection<Store> get reflection => Store$reflection(this);

  /// Returns a JSON [Map] for type [Store]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [Store] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension User$reflectionExtension on User {
  /// Returns a [ClassReflection] for type [User]. (Generated by [ReflectionFactory])
  ClassReflection<User> get reflection => User$reflection(this);

  /// Returns a JSON [Map] for type [User]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [User] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension UserInfo$reflectionExtension on UserInfo {
  /// Returns a [ClassReflection] for type [UserInfo]. (Generated by [ReflectionFactory])
  ClassReflection<UserInfo> get reflection => UserInfo$reflection(this);

  /// Returns a JSON [Map] for type [UserInfo]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [UserInfo] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
      Account$reflection(),
      Address$reflection(),
      Photo$reflection(),
      Role$reflection(),
      RoleType$reflection(),
      Store$reflection(),
      User$reflection(),
      UserInfo$reflection(),
    ];

List<Reflection>? _siblingsReflectionList;
List<Reflection> _siblingsReflection() => _siblingsReflectionList ??=
    List<Reflection>.unmodifiable(_listSiblingsReflection());

bool _registerSiblingsReflectionCalled = false;
void _registerSiblingsReflection() {
  if (_registerSiblingsReflectionCalled) return;
  _registerSiblingsReflectionCalled = true;
  var length = _listSiblingsReflection().length;
  assert(length > 0);
}
