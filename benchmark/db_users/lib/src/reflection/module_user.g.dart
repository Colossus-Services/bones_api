//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.10.1
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

part of '../module_user.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.10.1');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"addressLine1":
      return const Symbol(r"addressLine1");
    case r"city":
      return const Symbol(r"city");
    case r"config":
      return const Symbol(r"config");
    case r"countryCode":
      return const Symbol(r"countryCode");
    case r"email":
      return const Symbol(r"email");
    case r"enabled":
      return const Symbol(r"enabled");
    case r"id":
      return const Symbol(r"id");
    case r"limit":
      return const Symbol(r"limit");
    case r"method":
      return const Symbol(r"method");
    case r"name":
      return const Symbol(r"name");
    case r"page":
      return const Symbol(r"page");
    case r"pageSize":
      return const Symbol(r"pageSize");
    case r"parameters":
      return const Symbol(r"parameters");
    case r"parent":
      return const Symbol(r"parent");
    case r"password":
      return const Symbol(r"password");
    case r"roles":
      return const Symbol(r"roles");
    case r"rules":
      return const Symbol(r"rules");
    case r"state":
      return const Symbol(r"state");
    case r"zipCode":
      return const Symbol(r"zipCode");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
ModuleUser ModuleUser$fromJson(Map<String, Object?> map) =>
    ModuleUser$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
ModuleUser ModuleUser$fromJsonEncoded(String jsonEncoded) =>
    ModuleUser$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class ModuleUser$reflection extends ClassReflection<ModuleUser>
    with __ReflectionMixin {
  static final Expando<ModuleUser$reflection> _objectReflections = Expando();

  factory ModuleUser$reflection([ModuleUser? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= ModuleUser$reflection._(object);
  }

  ModuleUser$reflection._([ModuleUser? object])
    : super(ModuleUser, r'ModuleUser', object);

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
  Version get languageVersion => Version.parse('3.10.0');

  @override
  ModuleUser$reflection withObject([ModuleUser? obj]) =>
      ModuleUser$reflection(obj)..setupInternalsWith(this);

  static ModuleUser$reflection? _withoutObjectInstance;
  @override
  ModuleUser$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static ModuleUser$reflection get staticInstance =>
      _withoutObjectInstance ??= ModuleUser$reflection._();

  @override
  ModuleUser$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    ModuleUser$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  ModuleUser? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  ModuleUser? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  ModuleUser? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<ModuleUser>> _constructors =
      {};

  @override
  ConstructorReflection<ModuleUser>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<ModuleUser>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<ModuleUser>(
          this,
          ModuleUser,
          '',
          () => ModuleUser.new,
          const <__PR>[
            __PR(__TR<UsersAPIRoot>(UsersAPIRoot), 'apiRoot', false, true),
          ],
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

  static const List<Type> _supperTypes = const <Type>[APIModule, Initializable];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([ModuleUser? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'allRoutesNames',
    'apiConfig',
    'apiRoot',
    'authenticationRoute',
    'defaultRouteName',
    'hashCode',
    'initializationStatus',
    'isAsyncInitialization',
    'isInitialized',
    'isInitializing',
    'name',
    'roleRepository',
    'routes',
    'security',
    'userRepository',
    'version',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<ModuleUser, dynamic>>
  _fieldsNoObject = {};

  final Map<String, FieldReflection<ModuleUser, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<ModuleUser, T>? field<T>(
    String fieldName, [
    ModuleUser? obj,
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

  FieldReflection<ModuleUser, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<ModuleUser, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<ModuleUser, T>;
  }

  FieldReflection<ModuleUser, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<ModuleUser, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<ModuleUser, dynamic>? _fieldImpl(
    String fieldName,
    ModuleUser? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'rolerepository':
        return FieldReflection<ModuleUser, RoleAPIRepository>(
          this,
          ModuleUser,
          const __TR<RoleAPIRepository>(RoleAPIRepository),
          'roleRepository',
          false,
          (o) =>
              () => o!.roleRepository,
          null,
          obj,
          true,
        );
      case 'userrepository':
        return FieldReflection<ModuleUser, UserAPIRepository>(
          this,
          ModuleUser,
          const __TR<UserAPIRepository>(UserAPIRepository),
          'userRepository',
          false,
          (o) =>
              () => o!.userRepository,
          null,
          obj,
          true,
        );
      case 'security':
        return FieldReflection<ModuleUser, APISecurity>(
          this,
          ModuleUser,
          const __TR<APISecurity>(APISecurity),
          'security',
          false,
          (o) =>
              () => o!.security,
          null,
          obj,
          false,
          const [override],
        );
      case 'apiroot':
        return FieldReflection<ModuleUser, APIRoot>(
          this,
          APIModule,
          const __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) =>
              () => o!.apiRoot,
          null,
          obj,
          true,
        );
      case 'name':
        return FieldReflection<ModuleUser, String>(
          this,
          APIModule,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          null,
          obj,
          true,
        );
      case 'version':
        return FieldReflection<ModuleUser, String?>(
          this,
          APIModule,
          __TR.tString,
          'version',
          true,
          (o) =>
              () => o!.version,
          null,
          obj,
          true,
        );
      case 'apiconfig':
        return FieldReflection<ModuleUser, APIConfig>(
          this,
          APIModule,
          const __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) =>
              () => o!.apiConfig,
          null,
          obj,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<ModuleUser, String?>(
          this,
          APIModule,
          __TR.tString,
          'defaultRouteName',
          true,
          (o) =>
              () => o!.defaultRouteName,
          null,
          obj,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<ModuleUser, Set<String>>(
          this,
          APIModule,
          __TR.tSetString,
          'allRoutesNames',
          false,
          (o) =>
              () => o!.allRoutesNames,
          null,
          obj,
          false,
        );
      case 'routes':
        return FieldReflection<ModuleUser, APIRouteBuilder<APIModule>>(
          this,
          APIModule,
          const __TR<APIRouteBuilder<APIModule>>(APIRouteBuilder, <__TR>[
            __TR<APIModule>(APIModule),
          ]),
          'routes',
          false,
          (o) =>
              () => o!.routes,
          null,
          obj,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<ModuleUser, String>(
          this,
          APIModule,
          __TR.tString,
          'authenticationRoute',
          false,
          (o) =>
              () => o!.authenticationRoute,
          null,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<ModuleUser, int>(
          this,
          APIModule,
          __TR.tInt,
          'hashCode',
          false,
          (o) =>
              () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'initializationstatus':
        return FieldReflection<ModuleUser, InitializationStatus>(
          this,
          Initializable,
          const __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) =>
              () => o!.initializationStatus,
          null,
          obj,
          false,
        );
      case 'isinitialized':
        return FieldReflection<ModuleUser, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitialized',
          false,
          (o) =>
              () => o!.isInitialized,
          null,
          obj,
          false,
        );
      case 'isinitializing':
        return FieldReflection<ModuleUser, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitializing',
          false,
          (o) =>
              () => o!.isInitializing,
          null,
          obj,
          false,
        );
      case 'isasyncinitialization':
        return FieldReflection<ModuleUser, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isAsyncInitialization',
          false,
          (o) =>
              () => o!.isAsyncInitialization,
          null,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    ModuleUser? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'roleRepository': obj?.roleRepository,
      'userRepository': obj?.userRepository,
      'security': obj?.security,
      'apiRoot': obj?.apiRoot,
      'name': obj?.name,
      'version': obj?.version,
      'apiConfig': obj?.apiConfig,
      'defaultRouteName': obj?.defaultRouteName,
      'allRoutesNames': obj?.allRoutesNames,
      'routes': obj?.routes,
      'authenticationRoute': obj?.authenticationRoute,
      'initializationStatus': obj?.initializationStatus,
      'isInitialized': obj?.isInitialized,
      'isInitializing': obj?.isInitializing,
      'isAsyncInitialization': obj?.isAsyncInitialization,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<ModuleUser, T>? staticField<T>(String fieldName) =>
      null;

  static const List<String> _methodsNames = const <String>[
    'acceptsRequest',
    'addRoute',
    'addRouteHandler',
    'apiInfo',
    'byEmail',
    'byId',
    'byState',
    'call',
    'checkInitialized',
    'configure',
    'count',
    'doInitialization',
    'ensureConfigured',
    'ensureInitialized',
    'ensureInitializedAsync',
    'executeInitialized',
    'getRouteHandler',
    'getRouteHandlerByRequest',
    'getRoutesHandlersNames',
    'initialize',
    'initializeDependencies',
    'list',
    'register',
    'remove',
    'resolveRoute',
    'update',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<ModuleUser, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<ModuleUser, dynamic>> _methodsObject = {};

  @override
  MethodReflection<ModuleUser, R>? method<R>(
    String methodName, [
    ModuleUser? obj,
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

  MethodReflection<ModuleUser, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<ModuleUser, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<ModuleUser, R>;
  }

  MethodReflection<ModuleUser, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<ModuleUser, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<ModuleUser, dynamic>? _methodImpl(
    String methodName,
    ModuleUser? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<ModuleUser, void>(
          this,
          ModuleUser,
          'configure',
          __TR.tVoid,
          false,
          (o) => o!.configure,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'register':
        return MethodReflection<ModuleUser, Future<APIResponse<User>>>(
          this,
          ModuleUser,
          'register',
          const __TR<Future<APIResponse<User>>>(Future, <__TR>[
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
          ]),
          false,
          (o) => o!.register,
          obj,
          null,
          null,
          const <String, __PR>{
            'addressLine1': __PR(__TR.tString, 'addressLine1', true, false),
            'city': __PR(__TR.tString, 'city', false, true),
            'countryCode': __PR(__TR.tString, 'countryCode', false, true),
            'email': __PR(__TR.tString, 'email', false, true),
            'name': __PR(__TR.tString, 'name', false, true),
            'password': __PR(__TR.tString, 'password', false, true),
            'roles': __PR(__TR.tString, 'roles', true, false),
            'state': __PR(__TR.tString, 'state', false, true),
            'zipCode': __PR(__TR.tString, 'zipCode', true, false),
          },
          null,
        );
      case 'byid':
        return MethodReflection<ModuleUser, Future<APIResponse<User>>>(
          this,
          ModuleUser,
          'byId',
          const __TR<Future<APIResponse<User>>>(Future, <__TR>[
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
          ]),
          false,
          (o) => o!.byId,
          obj,
          const <__PR>[__PR(__TR.tInt, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'update':
        return MethodReflection<ModuleUser, Future<APIResponse<User>>>(
          this,
          ModuleUser,
          'update',
          const __TR<Future<APIResponse<User>>>(Future, <__TR>[
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
          ]),
          false,
          (o) => o!.update,
          obj,
          null,
          null,
          const <String, __PR>{
            'city': __PR(__TR.tString, 'city', true, false),
            'enabled': __PR(__TR.tBool, 'enabled', true, false),
            'id': __PR(__TR.tInt, 'id', false, true),
            'name': __PR(__TR.tString, 'name', true, false),
            'state': __PR(__TR.tString, 'state', true, false),
          },
          null,
        );
      case 'remove':
        return MethodReflection<ModuleUser, Future<APIResponse<int>>>(
          this,
          ModuleUser,
          'remove',
          const __TR<Future<APIResponse<int>>>(Future, <__TR>[
            __TR<APIResponse<int>>(APIResponse, <__TR>[__TR.tInt]),
          ]),
          false,
          (o) => o!.remove,
          obj,
          const <__PR>[__PR(__TR.tInt, 'id', false, true)],
          null,
          null,
          null,
        );
      case 'byemail':
        return MethodReflection<ModuleUser, Future<APIResponse<User>>>(
          this,
          ModuleUser,
          'byEmail',
          const __TR<Future<APIResponse<User>>>(Future, <__TR>[
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
          ]),
          false,
          (o) => o!.byEmail,
          obj,
          const <__PR>[__PR(__TR.tString, 'email', false, true)],
          null,
          null,
          null,
        );
      case 'bystate':
        return MethodReflection<ModuleUser, Future<APIResponse<List<User>>>>(
          this,
          ModuleUser,
          'byState',
          const __TR<Future<APIResponse<List<User>>>>(Future, <__TR>[
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)]),
            ]),
          ]),
          false,
          (o) => o!.byState,
          obj,
          const <__PR>[__PR(__TR.tString, 'state', false, true)],
          null,
          const <String, __PR>{'limit': __PR(__TR.tInt, 'limit', true, false)},
          null,
        );
      case 'list':
        return MethodReflection<ModuleUser, Future<APIResponse<List<User>>>>(
          this,
          ModuleUser,
          'list',
          const __TR<Future<APIResponse<List<User>>>>(Future, <__TR>[
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)]),
            ]),
          ]),
          false,
          (o) => o!.list,
          obj,
          null,
          null,
          const <String, __PR>{
            'page': __PR(__TR.tInt, 'page', true, false),
            'pageSize': __PR(__TR.tInt, 'pageSize', true, false),
          },
          null,
        );
      case 'count':
        return MethodReflection<ModuleUser, Future<APIResponse<int>>>(
          this,
          ModuleUser,
          'count',
          const __TR<Future<APIResponse<int>>>(Future, <__TR>[
            __TR<APIResponse<int>>(APIResponse, <__TR>[__TR.tInt]),
          ]),
          false,
          (o) => o!.count,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'ensureconfigured':
        return MethodReflection<ModuleUser, void>(
          this,
          APIModule,
          'ensureConfigured',
          __TR.tVoid,
          false,
          (o) => o!.ensureConfigured,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'initialize':
        return MethodReflection<ModuleUser, FutureOr<InitializationResult>>(
          this,
          APIModule,
          'initialize',
          const __TR<FutureOr<InitializationResult>>(FutureOr, <__TR>[
            __TR<InitializationResult>(InitializationResult),
          ]),
          false,
          (o) => o!.initialize,
          obj,
          null,
          null,
          null,
          const [override],
        );
      case 'getrouteshandlersnames':
        return MethodReflection<ModuleUser, Iterable<String>>(
          this,
          APIModule,
          'getRoutesHandlersNames',
          const __TR<Iterable<String>>(Iterable, <__TR>[__TR.tString]),
          false,
          (o) => o!.getRoutesHandlersNames,
          obj,
          null,
          null,
          const <String, __PR>{
            'method': __PR(
              __TR<APIRequestMethod>(APIRequestMethod),
              'method',
              true,
              false,
            ),
          },
          null,
        );
      case 'addroute':
        return MethodReflection<ModuleUser, APIModule>(
          this,
          APIModule,
          'addRoute',
          const __TR<APIModule>(APIModule),
          false,
          (o) => o!.addRoute,
          obj,
          const <__PR>[
            __PR(
              __TR<APIRequestMethod>(APIRequestMethod),
              'method',
              true,
              true,
            ),
            __PR(__TR.tString, 'name', false, true),
            __PR(
              __TR<APIRouteFunction<dynamic>>(APIRouteFunction, <__TR>[
                __TR.tDynamic,
              ]),
              'function',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'config': __PR(
              __TR<APIRouteConfig>(APIRouteConfig),
              'config',
              true,
              false,
            ),
            'parameters': __PR(
              __TR<Map<String, TypeInfo>>(Map, <__TR>[
                __TR.tString,
                __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic]),
              ]),
              'parameters',
              true,
              false,
            ),
            'rules': __PR(
              __TR<Iterable<APIRouteRule>>(Iterable, <__TR>[
                __TR<APIRouteRule>(APIRouteRule),
              ]),
              'rules',
              true,
              false,
            ),
          },
          null,
        );
      case 'addroutehandler':
        return MethodReflection<ModuleUser, APIModule>(
          this,
          APIModule,
          'addRouteHandler',
          const __TR<APIModule>(APIModule),
          false,
          (o) => o!.addRouteHandler,
          obj,
          const <__PR>[
            __PR(
              __TR<APIRouteHandler<dynamic>>(APIRouteHandler, <__TR>[
                __TR.tDynamic,
              ]),
              'routeHandler',
              false,
              true,
            ),
          ],
          null,
          null,
          null,
        );
      case 'getroutehandler':
        return MethodReflection<ModuleUser, APIRouteHandler<dynamic>?>(
          this,
          APIModule,
          'getRouteHandler',
          const __TR<APIRouteHandler<dynamic>>(APIRouteHandler, <__TR>[
            __TR.tDynamic,
          ]),
          true,
          (o) => o!.getRouteHandler,
          obj,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          const <__PR>[
            __PR(
              __TR<APIRequestMethod>(APIRequestMethod),
              'method',
              true,
              false,
            ),
          ],
          null,
          null,
        );
      case 'getroutehandlerbyrequest':
        return MethodReflection<ModuleUser, APIRouteHandler<dynamic>?>(
          this,
          APIModule,
          'getRouteHandlerByRequest',
          const __TR<APIRouteHandler<dynamic>>(APIRouteHandler, <__TR>[
            __TR.tDynamic,
          ]),
          true,
          (o) => o!.getRouteHandlerByRequest,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          const <__PR>[__PR(__TR.tString, 'routeName', true, false)],
          null,
          null,
        );
      case 'resolveroute':
        return MethodReflection<ModuleUser, String>(
          this,
          APIModule,
          'resolveRoute',
          __TR.tString,
          false,
          (o) => o!.resolveRoute,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          null,
        );
      case 'call':
        return MethodReflection<ModuleUser, FutureOr<APIResponse<dynamic>>>(
          this,
          APIModule,
          'call',
          const __TR<FutureOr<APIResponse>>(FutureOr, <__TR>[
            __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic]),
          ]),
          false,
          (o) => o!.call,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          null,
        );
      case 'acceptsrequest':
        return MethodReflection<ModuleUser, bool>(
          this,
          APIModule,
          'acceptsRequest',
          __TR.tBool,
          false,
          (o) => o!.acceptsRequest,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'apiRequest', false, true),
          ],
          null,
          null,
          null,
        );
      case 'apiinfo':
        return MethodReflection<ModuleUser, APIModuleInfo>(
          this,
          APIModule,
          'apiInfo',
          const __TR<APIModuleInfo>(APIModuleInfo),
          false,
          (o) => o!.apiInfo,
          obj,
          null,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'apiRequest', true, false),
          ],
          null,
          null,
        );
      case 'ensureinitialized':
        return MethodReflection<ModuleUser, FutureOr<InitializationResult>>(
          this,
          Initializable,
          'ensureInitialized',
          const __TR<FutureOr<InitializationResult>>(FutureOr, <__TR>[
            __TR<InitializationResult>(InitializationResult),
          ]),
          false,
          (o) => o!.ensureInitialized,
          obj,
          null,
          null,
          const <String, __PR>{
            'parent': __PR(
              __TR<Initializable>(Initializable),
              'parent',
              true,
              false,
            ),
          },
          null,
        );
      case 'ensureinitializedasync':
        return MethodReflection<ModuleUser, FutureOr<InitializationResult>>(
          this,
          Initializable,
          'ensureInitializedAsync',
          const __TR<FutureOr<InitializationResult>>(FutureOr, <__TR>[
            __TR<InitializationResult>(InitializationResult),
          ]),
          false,
          (o) => o!.ensureInitializedAsync,
          obj,
          null,
          null,
          const <String, __PR>{
            'parent': __PR(
              __TR<Initializable>(Initializable),
              'parent',
              true,
              false,
            ),
          },
          null,
        );
      case 'doinitialization':
        return MethodReflection<ModuleUser, FutureOr<InitializationResult>>(
          this,
          Initializable,
          'doInitialization',
          const __TR<FutureOr<InitializationResult>>(FutureOr, <__TR>[
            __TR<InitializationResult>(InitializationResult),
          ]),
          false,
          (o) => o!.doInitialization,
          obj,
          null,
          null,
          const <String, __PR>{
            'parent': __PR(
              __TR<Initializable>(Initializable),
              'parent',
              true,
              false,
            ),
          },
          null,
        );
      case 'initializedependencies':
        return MethodReflection<ModuleUser, FutureOr<List<Initializable>>>(
          this,
          Initializable,
          'initializeDependencies',
          const __TR<FutureOr<List<Initializable>>>(FutureOr, <__TR>[
            __TR<List<Initializable>>(List, <__TR>[
              __TR<Initializable>(Initializable),
            ]),
          ]),
          false,
          (o) => o!.initializeDependencies,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'checkinitialized':
        return MethodReflection<ModuleUser, void>(
          this,
          Initializable,
          'checkInitialized',
          __TR.tVoid,
          false,
          (o) => o!.checkInitialized,
          obj,
          null,
          null,
          null,
          null,
        );
      case 'executeinitialized':
        return MethodReflection<ModuleUser, FutureOr<dynamic>>(
          this,
          Initializable,
          'executeInitialized',
          __TR.tFutureOrDynamic,
          false,
          (o) => o!.executeInitialized,
          obj,
          const <__PR>[
            __PR(
              __TR<ExecuteInitializedCallback<dynamic>>(
                ExecuteInitializedCallback,
                <__TR>[__TR.tDynamic],
              ),
              'callback',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'parent': __PR(
              __TR<Initializable>(Initializable),
              'parent',
              true,
              false,
            ),
          },
          null,
        );
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<ModuleUser, R>? staticMethod<R>(String methodName) =>
      null;
}

extension ModuleUser$reflectionExtension on ModuleUser {
  /// Returns a [ClassReflection] for type [ModuleUser]. (Generated by [ReflectionFactory])
  ClassReflection<ModuleUser> get reflection => ModuleUser$reflection(this);

  /// Returns a JSON for type [ModuleUser]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [ModuleUser]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [ModuleUser]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [ModuleUser] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  ModuleUser$reflection(),
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
