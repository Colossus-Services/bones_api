//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.2.1
// BUILD COMMAND: dart run build_runner build
//

// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test_entities.dart';

// ignore: non_constant_identifier_names
Address Address$fromJson(Map<String, Object?> map) =>
    Address$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Address Address$fromJsonEncoded(String jsonEncoded) =>
    Address$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
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

class Address$reflection extends ClassReflection<Address> {
  Address$reflection([Address? object]) : super(Address, object);

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
  Version get languageVersion => Version.parse('2.15.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.2.1');

  @override
  Address$reflection withObject([Address? obj]) => Address$reflection(obj);

  static Address$reflection? _withoutObjectInstance;
  @override
  Address$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as Address$reflection;

  static Address$reflection get staticInstance =>
      _withoutObjectInstance ??= Address$reflection();

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

  @override
  List<String> get constructorsNames => const <String>['', 'empty', 'fromMap'];

  @override
  ConstructorReflection<Address>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Address>(
            this,
            Address,
            '',
            () => (String state, String city, String street, int number,
                    {int? id,
                    List<Store>? stores,
                    List<Store>? closedStores}) =>
                Address(state, city, street, number,
                    id: id, stores: stores, closedStores: closedStores),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'state', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'city', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'street', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tInt, 'number', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'closedStores': ParameterReflection(TypeReflection(List, [Store]),
                  'closedStores', true, false, null, null),
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null),
              'stores': ParameterReflection(TypeReflection(List, [Store]),
                  'stores', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<Address>(this, Address, 'empty',
            () => () => Address.empty(), null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Address>(
            this,
            Address,
            'fromMap',
            () => (Map<String, dynamic> map) => Address.fromMap(map),
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<ClassReflection> siblingsClassReflection() =>
      _siblingsReflection().whereType<ClassReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<Type> get supperTypes => const <Type>[Entity];

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Address? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  @override
  List<String> get fieldsNames => const <String>[
        'city',
        'closedStores',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'number',
        'state',
        'stores',
        'street'
      ];

  @override
  FieldReflection<Address, T>? field<T>(String fieldName, [Address? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'state':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tString,
          'state',
          false,
          (o) => () => o!.state as T,
          (o) => (T? v) => o!.state = v as String,
          obj,
          false,
          false,
          [EntityField.maximum(3)],
        );
      case 'city':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tString,
          'city',
          false,
          (o) => () => o!.city as T,
          (o) => (T? v) => o!.city = v as String,
          obj,
          false,
          false,
          [EntityField.maximum(100)],
        );
      case 'street':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tString,
          'street',
          false,
          (o) => () => o!.street as T,
          (o) => (T? v) => o!.street = v as String,
          obj,
          false,
          false,
          [EntityField.maximum(200)],
        );
      case 'number':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tInt,
          'number',
          false,
          (o) => () => o!.number as T,
          (o) => (T? v) => o!.number = v as int,
          obj,
          false,
          false,
          null,
        );
      case 'stores':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection(List, [Store]),
          'stores',
          false,
          (o) => () => o!.stores as T,
          (o) => (T? v) => o!.stores = v as List<Store>,
          obj,
          false,
          false,
          null,
        );
      case 'closedstores':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection(List, [Store]),
          'closedStores',
          false,
          (o) => () => o!.closedStores as T,
          (o) => (T? v) => o!.closedStores = v as List<Store>,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'idfieldname':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'fieldsnames':
        return FieldReflection<Address, T>(
          this,
          Address,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<Address, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
  MethodReflection<Address, R>? method<R>(String methodName, [Address? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Address, R>(
            this,
            Address,
            'getField',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<Address, R>(
            this,
            Address,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldentityannotations':
        return MethodReflection<Address, R>(
            this,
            Address,
            'getFieldEntityAnnotations',
            TypeReflection(List, [EntityAnnotation]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<Address, R>(
            this,
            Address,
            'setField',
            TypeReflection.tVoid,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tDynamic, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<Address, R>(
            this,
            Address,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getid':
        return MethodReflection<Address, R>(
            this,
            Entity,
            'getID',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getID,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'setid':
        return MethodReflection<Address, R>(
            this,
            Entity,
            'setID',
            TypeReflection.tVoid,
            false,
            (o) => o!.setID,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tDynamic, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Address, R>(
            this,
            Entity,
            'toJsonEncoded',
            TypeReflection.tString,
            false,
            (o) => o!.toJsonEncoded,
            obj,
            false,
            null,
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<Address, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

class Role$reflection extends ClassReflection<Role> {
  Role$reflection([Role? object]) : super(Role, object);

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
  Version get languageVersion => Version.parse('2.15.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.2.1');

  @override
  Role$reflection withObject([Role? obj]) => Role$reflection(obj);

  static Role$reflection? _withoutObjectInstance;
  @override
  Role$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as Role$reflection;

  static Role$reflection get staticInstance =>
      _withoutObjectInstance ??= Role$reflection();

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

  @override
  List<String> get constructorsNames => const <String>['', 'empty', 'fromMap'];

  @override
  ConstructorReflection<Role>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Role>(
            this,
            Role,
            '',
            () => (RoleType type,
                    {int? id, bool enabled = true, Decimal? value}) =>
                Role(type, id: id, enabled: enabled, value: value),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection(RoleType), 'type', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'enabled': ParameterReflection(
                  TypeReflection.tBool, 'enabled', false, false, true, null),
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null),
              'value': ParameterReflection(
                  TypeReflection(Decimal), 'value', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<Role>(this, Role, 'empty',
            () => () => Role.empty(), null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Role>(
            this,
            Role,
            'fromMap',
            () => (Map<String, dynamic> map) => Role.fromMap(map),
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<ClassReflection> siblingsClassReflection() =>
      _siblingsReflection().whereType<ClassReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<Type> get supperTypes => const <Type>[Entity];

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Role? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  @override
  List<String> get fieldsNames => const <String>[
        'enabled',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'type',
        'value'
      ];

  @override
  FieldReflection<Role, T>? field<T>(String fieldName, [Role? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'type':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection(RoleType),
          'type',
          false,
          (o) => () => o!.type as T,
          (o) => (T? v) => o!.type = v as RoleType,
          obj,
          false,
          false,
          null,
        );
      case 'enabled':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection.tBool,
          'enabled',
          false,
          (o) => () => o!.enabled as T,
          (o) => (T? v) => o!.enabled = v as bool,
          obj,
          false,
          false,
          null,
        );
      case 'value':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection(Decimal),
          'value',
          true,
          (o) => () => o!.value as T,
          (o) => (T? v) => o!.value = v as Decimal?,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'idfieldname':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'fieldsnames':
        return FieldReflection<Role, T>(
          this,
          Role,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<Role, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
  MethodReflection<Role, R>? method<R>(String methodName, [Role? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Role, R>(
            this,
            Role,
            'getField',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<Role, R>(
            this,
            Role,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<Role, R>(
            this,
            Role,
            'setField',
            TypeReflection.tVoid,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tDynamic, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<Role, R>(
            this,
            Role,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getid':
        return MethodReflection<Role, R>(
            this,
            Entity,
            'getID',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getID,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'setid':
        return MethodReflection<Role, R>(
            this,
            Entity,
            'setID',
            TypeReflection.tVoid,
            false,
            (o) => o!.setID,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tDynamic, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'getfieldentityannotations':
        return MethodReflection<Role, R>(
            this,
            Entity,
            'getFieldEntityAnnotations',
            TypeReflection(List, [EntityAnnotation]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Role, R>(
            this,
            Entity,
            'toJsonEncoded',
            TypeReflection.tString,
            false,
            (o) => o!.toJsonEncoded,
            obj,
            false,
            null,
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<Role, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

class RoleType$reflection extends EnumReflection<RoleType> {
  RoleType$reflection([RoleType? object]) : super(RoleType, object);

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
  Version get languageVersion => Version.parse('2.15.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.2.1');

  @override
  RoleType$reflection withObject([RoleType? obj]) => RoleType$reflection(obj);

  static RoleType$reflection? _withoutObjectInstance;
  @override
  RoleType$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as RoleType$reflection;

  static RoleType$reflection get staticInstance =>
      _withoutObjectInstance ??= RoleType$reflection();

  @override
  RoleType$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    RoleType$reflection.staticInstance;
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<EnumReflection> siblingsEnumReflection() =>
      _siblingsReflection().whereType<EnumReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<String> get fieldsNames => const <String>['admin', 'guest', 'unknown'];

  @override
  Map<String, RoleType> get valuesByName => const <String, RoleType>{
        'admin': RoleType.admin,
        'guest': RoleType.guest,
        'unknown': RoleType.unknown,
      };

  @override
  List<RoleType> get values => RoleType.values;
}

class Store$reflection extends ClassReflection<Store> {
  Store$reflection([Store? object]) : super(Store, object);

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
  Version get languageVersion => Version.parse('2.15.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.2.1');

  @override
  Store$reflection withObject([Store? obj]) => Store$reflection(obj);

  static Store$reflection? _withoutObjectInstance;
  @override
  Store$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as Store$reflection;

  static Store$reflection get staticInstance =>
      _withoutObjectInstance ??= Store$reflection();

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

  @override
  List<String> get constructorsNames => const <String>['', 'empty'];

  @override
  ConstructorReflection<Store>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Store>(
            this,
            Store,
            '',
            () => (String name, int? number, {int? id}) =>
                Store(name, number, id: id),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'name', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tInt, 'number', true, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<Store>(this, Store, 'empty',
            () => () => Store.empty(), null, null, null, null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<ClassReflection> siblingsClassReflection() =>
      _siblingsReflection().whereType<ClassReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<Type> get supperTypes => const <Type>[Entity];

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([Store? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  @override
  List<String> get fieldsNames => const <String>[
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'name',
        'number'
      ];

  @override
  FieldReflection<Store, T>? field<T>(String fieldName, [Store? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'name':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tString,
          'name',
          false,
          (o) => () => o!.name as T,
          (o) => (T? v) => o!.name = v as String,
          obj,
          false,
          false,
          [EntityField.maximum(100)],
        );
      case 'number':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tInt,
          'number',
          true,
          (o) => () => o!.number as T,
          (o) => (T? v) => o!.number = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'idfieldname':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'fieldsnames':
        return FieldReflection<Store, T>(
          this,
          Store,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<Store, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
  MethodReflection<Store, R>? method<R>(String methodName, [Store? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Store, R>(
            this,
            Store,
            'getField',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<Store, R>(
            this,
            Store,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldentityannotations':
        return MethodReflection<Store, R>(
            this,
            Store,
            'getFieldEntityAnnotations',
            TypeReflection(List, [EntityAnnotation]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<Store, R>(
            this,
            Store,
            'setField',
            TypeReflection.tVoid,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tDynamic, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<Store, R>(
            this,
            Store,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getid':
        return MethodReflection<Store, R>(
            this,
            Entity,
            'getID',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getID,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'setid':
        return MethodReflection<Store, R>(
            this,
            Entity,
            'setID',
            TypeReflection.tVoid,
            false,
            (o) => o!.setID,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tDynamic, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<Store, R>(
            this,
            Entity,
            'toJsonEncoded',
            TypeReflection.tString,
            false,
            (o) => o!.toJsonEncoded,
            obj,
            false,
            null,
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>['fromMap'];

  @override
  MethodReflection<Store, R>? staticMethod<R>(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return MethodReflection<Store, R>(
            this,
            Store,
            'fromMap',
            TypeReflection(FutureOr, [Store]),
            false,
            (o) => Store.fromMap,
            null,
            true,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

class User$reflection extends ClassReflection<User> {
  User$reflection([User? object]) : super(User, object);

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
  Version get languageVersion => Version.parse('2.15.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.2.1');

  @override
  User$reflection withObject([User? obj]) => User$reflection(obj);

  static User$reflection? _withoutObjectInstance;
  @override
  User$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as User$reflection;

  static User$reflection get staticInstance =>
      _withoutObjectInstance ??= User$reflection();

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

  @override
  List<String> get constructorsNames => const <String>['', 'empty'];

  @override
  ConstructorReflection<User>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<User>(
            this,
            User,
            '',
            () => (String email, String password, Address address,
                    List<Role> roles,
                    {int? id,
                    int? level,
                    Time? wakeUpTime,
                    DateTime? creationTime}) =>
                User(email, password, address, roles,
                    id: id,
                    level: level,
                    wakeUpTime: wakeUpTime,
                    creationTime: creationTime),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'email', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'password', false, true, null, null),
              ParameterReflection(
                  TypeReflection(Address), 'address', false, true, null, null),
              ParameterReflection(TypeReflection(List, [Role]), 'roles', false,
                  true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'creationTime': ParameterReflection(TypeReflection(DateTime),
                  'creationTime', true, false, null, null),
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null),
              'level': ParameterReflection(
                  TypeReflection.tInt, 'level', true, false, null, null),
              'wakeUpTime': ParameterReflection(
                  TypeReflection(Time), 'wakeUpTime', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<User>(this, User, 'empty',
            () => () => User.empty(), null, null, null, null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<ClassReflection> siblingsClassReflection() =>
      _siblingsReflection().whereType<ClassReflection>().toList();

  @override
  List<Reflection> siblingsReflection() => _siblingsReflection();

  @override
  List<Type> get supperTypes => const <Type>[Entity];

  @override
  bool get hasMethodToJson => true;

  @override
  Object? callMethodToJson([User? obj]) {
    obj ??= object;
    return obj?.toJson();
  }

  @override
  List<String> get fieldsNames => const <String>[
        'address',
        'creationTime',
        'email',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'level',
        'password',
        'roles',
        'wakeUpTime'
      ];

  @override
  FieldReflection<User, T>? field<T>(String fieldName, [User? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'email':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tString,
          'email',
          false,
          (o) => () => o!.email as T,
          (o) => (T? v) => o!.email = v as String,
          obj,
          false,
          false,
          [
            EntityField.unique(),
            EntityField.maximum(100),
            EntityField.regexp(r'[\w-.]+@\w+(?:\.\w+)*')
          ],
        );
      case 'password':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tString,
          'password',
          false,
          (o) => () => o!.password as T,
          (o) => (T? v) => o!.password = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'address':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection(Address),
          'address',
          false,
          (o) => () => o!.address as T,
          (o) => (T? v) => o!.address = v as Address,
          obj,
          false,
          false,
          null,
        );
      case 'roles':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection(List, [Role]),
          'roles',
          false,
          (o) => () => o!.roles as T,
          (o) => (T? v) => o!.roles = v as List<Role>,
          obj,
          false,
          false,
          null,
        );
      case 'level':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tInt,
          'level',
          true,
          (o) => () => o!.level as T,
          (o) => (T? v) => o!.level = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'wakeuptime':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection(Time),
          'wakeUpTime',
          true,
          (o) => () => o!.wakeUpTime as T,
          (o) => (T? v) => o!.wakeUpTime = v as Time?,
          obj,
          false,
          false,
          null,
        );
      case 'creationtime':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection(DateTime),
          'creationTime',
          false,
          (o) => () => o!.creationTime as T,
          (o) => (T? v) => o!.creationTime = v as DateTime,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'idfieldname':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'fieldsnames':
        return FieldReflection<User, T>(
          this,
          User,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          [JsonField.hidden(), override],
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<User, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
  MethodReflection<User, R>? method<R>(String methodName, [User? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<User, R>(
            this,
            User,
            'getField',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<User, R>(
            this,
            User,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldentityannotations':
        return MethodReflection<User, R>(
            this,
            User,
            'getFieldEntityAnnotations',
            TypeReflection(List, [EntityAnnotation]),
            true,
            (o) => o!.getFieldEntityAnnotations,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<User, R>(
            this,
            User,
            'setField',
            TypeReflection.tVoid,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tDynamic, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<User, R>(
            this,
            User,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getid':
        return MethodReflection<User, R>(
            this,
            Entity,
            'getID',
            TypeReflection.tDynamic,
            true,
            (o) => o!.getID,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'setid':
        return MethodReflection<User, R>(
            this,
            Entity,
            'setID',
            TypeReflection.tVoid,
            false,
            (o) => o!.setID,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tDynamic, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'tojsonencoded':
        return MethodReflection<User, R>(
            this,
            Entity,
            'toJsonEncoded',
            TypeReflection.tString,
            false,
            (o) => o!.toJsonEncoded,
            obj,
            false,
            null,
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>['fromMap'];

  @override
  MethodReflection<User, R>? staticMethod<R>(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return MethodReflection<User, R>(
            this,
            User,
            'fromMap',
            TypeReflection(FutureOr, [User]),
            false,
            (o) => User.fromMap,
            null,
            true,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }
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

List<Reflection> _listSiblingsReflection() => <Reflection>[
      User$reflection(),
      Store$reflection(),
      Address$reflection(),
      Role$reflection(),
      RoleType$reflection(),
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
