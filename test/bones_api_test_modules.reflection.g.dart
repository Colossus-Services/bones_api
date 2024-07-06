//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.4.2
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: no_leading_underscores_for_local_identifiers
// ignore_for_file: camel_case_types
// ignore_for_file: camel_case_extensions
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test_modules.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.4.2');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

// ignore: non_constant_identifier_names
AboutModule AboutModule$fromJson(Map<String, Object?> map) =>
    AboutModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
AboutModule AboutModule$fromJsonEncoded(String jsonEncoded) =>
    AboutModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
UserModule UserModule$fromJson(Map<String, Object?> map) =>
    UserModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
UserModule UserModule$fromJsonEncoded(String jsonEncoded) =>
    UserModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class AboutModule$reflection extends ClassReflection<AboutModule>
    with __ReflectionMixin {
  static final Expando<AboutModule$reflection> _objectReflections = Expando();

  factory AboutModule$reflection([AboutModule? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= AboutModule$reflection._(object);
  }

  AboutModule$reflection._([AboutModule? object])
      : super(AboutModule, 'AboutModule', object);

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
  Version get languageVersion => Version.parse('3.3.0');

  @override
  AboutModule$reflection withObject([AboutModule? obj]) =>
      AboutModule$reflection(obj)..setupInternalsWith(this);

  static AboutModule$reflection? _withoutObjectInstance;
  @override
  AboutModule$reflection withoutObjectInstance() => staticInstance;

  static AboutModule$reflection get staticInstance =>
      _withoutObjectInstance ??= AboutModule$reflection._();

  @override
  AboutModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    AboutModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  AboutModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  AboutModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  AboutModule? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<AboutModule>> _constructors =
      {};

  @override
  ConstructorReflection<AboutModule>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<AboutModule>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<AboutModule>(
            this,
            AboutModule,
            '',
            () => (APIRoot apiRoot) => AboutModule(apiRoot),
            const <__PR>[__PR(__TR<APIRoot>(APIRoot), 'apiRoot', false, true)],
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

  static const List<Type> _supperTypes = const <Type>[APIModule, Initializable];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([AboutModule? obj]) => null;

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
    'routes',
    'security',
    'version'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<AboutModule, dynamic>>
      _fieldsNoObject = {};

  final Map<String, FieldReflection<AboutModule, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<AboutModule, T>? field<T>(String fieldName,
      [AboutModule? obj]) {
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

  FieldReflection<AboutModule, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<AboutModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<AboutModule, T>;
  }

  FieldReflection<AboutModule, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<AboutModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<AboutModule, dynamic>? _fieldImpl(
      String fieldName, AboutModule? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<AboutModule, APIRoot>(
          this,
          APIModule,
          __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot,
          null,
          obj,
          true,
        );
      case 'name':
        return FieldReflection<AboutModule, String>(
          this,
          APIModule,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name,
          null,
          obj,
          true,
        );
      case 'version':
        return FieldReflection<AboutModule, String?>(
          this,
          APIModule,
          __TR.tString,
          'version',
          true,
          (o) => () => o!.version,
          null,
          obj,
          true,
        );
      case 'apiconfig':
        return FieldReflection<AboutModule, APIConfig>(
          this,
          APIModule,
          __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig,
          null,
          obj,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<AboutModule, String?>(
          this,
          APIModule,
          __TR.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName,
          null,
          obj,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<AboutModule, Set<String>>(
          this,
          APIModule,
          __TR.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames,
          null,
          obj,
          false,
        );
      case 'routes':
        return FieldReflection<AboutModule, APIRouteBuilder<APIModule>>(
          this,
          APIModule,
          __TR<APIRouteBuilder<APIModule>>(
              APIRouteBuilder, <__TR>[__TR<APIModule>(APIModule)]),
          'routes',
          false,
          (o) => () => o!.routes,
          null,
          obj,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<AboutModule, String>(
          this,
          APIModule,
          __TR.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute,
          null,
          obj,
          false,
        );
      case 'security':
        return FieldReflection<AboutModule, APISecurity?>(
          this,
          APIModule,
          __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) => () => o!.security,
          null,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<AboutModule, int>(
          this,
          APIModule,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'initializationstatus':
        return FieldReflection<AboutModule, InitializationStatus>(
          this,
          Initializable,
          __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) => () => o!.initializationStatus,
          null,
          obj,
          false,
        );
      case 'isinitialized':
        return FieldReflection<AboutModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitialized',
          false,
          (o) => () => o!.isInitialized,
          null,
          obj,
          false,
        );
      case 'isinitializing':
        return FieldReflection<AboutModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitializing',
          false,
          (o) => () => o!.isInitializing,
          null,
          obj,
          false,
        );
      case 'isasyncinitialization':
        return FieldReflection<AboutModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isAsyncInitialization',
          false,
          (o) => () => o!.isAsyncInitialization,
          null,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(AboutModule? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'apiRoot': obj?.apiRoot,
      'name': obj?.name,
      'version': obj?.version,
      'apiConfig': obj?.apiConfig,
      'defaultRouteName': obj?.defaultRouteName,
      'allRoutesNames': obj?.allRoutesNames,
      'routes': obj?.routes,
      'authenticationRoute': obj?.authenticationRoute,
      'security': obj?.security,
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
  StaticFieldReflection<AboutModule, T>? staticField<T>(String fieldName) =>
      null;

  static const List<String> _methodsNames = const <String>[
    'about',
    'acceptsRequest',
    'addRoute',
    'apiInfo',
    'call',
    'checkInitialized',
    'configure',
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
    'resolveRoute'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<AboutModule, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<AboutModule, dynamic>> _methodsObject = {};

  @override
  MethodReflection<AboutModule, R>? method<R>(String methodName,
      [AboutModule? obj]) {
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

  MethodReflection<AboutModule, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<AboutModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<AboutModule, R>;
  }

  MethodReflection<AboutModule, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<AboutModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<AboutModule, dynamic>? _methodImpl(
      String methodName, AboutModule? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<AboutModule, void>(
            this,
            AboutModule,
            'configure',
            __TR.tVoid,
            false,
            (o) => o!.configure,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'about':
        return MethodReflection<AboutModule, APIResponse<String>>(
            this,
            AboutModule,
            'about',
            __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
            false,
            (o) => o!.about,
            obj,
            null,
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<AboutModule, void>(
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
            null);
      case 'initialize':
        return MethodReflection<AboutModule, FutureOr<InitializationResult>>(
            this,
            APIModule,
            'initialize',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.initialize,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<AboutModule, Iterable<String>>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            __TR<Iterable<String>>(Iterable, <__TR>[__TR.tString]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            null,
            null,
            const <String, __PR>{
              'method': __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method',
                  true, false)
            },
            null);
      case 'addroute':
        return MethodReflection<AboutModule, APIModule>(
            this,
            APIModule,
            'addRoute',
            __TR<APIModule>(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  true),
              __PR(__TR.tString, 'name', false, true),
              __PR(
                  __TR<APIRouteFunction<dynamic>>(
                      APIRouteFunction, <__TR>[__TR.tDynamic]),
                  'function',
                  false,
                  true)
            ],
            null,
            const <String, __PR>{
              'config': __PR(
                  __TR<APIRouteConfig>(APIRouteConfig), 'config', true, false),
              'parameters': __PR(
                  __TR<Map<String, TypeInfo>>(Map, <__TR>[
                    __TR.tString,
                    __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic])
                  ]),
                  'parameters',
                  true,
                  false),
              'rules': __PR(
                  __TR<Iterable<APIRouteRule>>(
                      Iterable, <__TR>[__TR<APIRouteRule>(APIRouteRule)]),
                  'rules',
                  true,
                  false)
            },
            null);
      case 'getroutehandler':
        return MethodReflection<AboutModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandler',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            const <__PR>[__PR(__TR.tString, 'name', false, true)],
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  false)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<AboutModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            const <__PR>[__PR(__TR.tString, 'routeName', true, false)],
            null,
            null);
      case 'resolveroute':
        return MethodReflection<AboutModule, String>(
            this,
            APIModule,
            'resolveRoute',
            __TR.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<AboutModule, FutureOr<APIResponse<dynamic>>>(
            this,
            APIModule,
            'call',
            __TR<FutureOr<APIResponse>>(FutureOr, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'acceptsrequest':
        return MethodReflection<AboutModule, bool>(
            this,
            APIModule,
            'acceptsRequest',
            __TR.tBool,
            false,
            (o) => o!.acceptsRequest,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', false, true)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<AboutModule, APIModuleInfo>(
            this,
            APIModule,
            'apiInfo',
            __TR<APIModuleInfo>(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            null,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', true, false)
            ],
            null,
            null);
      case 'ensureinitialized':
        return MethodReflection<AboutModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitialized',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitialized,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'ensureinitializedasync':
        return MethodReflection<AboutModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitializedAsync',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitializedAsync,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'doinitialization':
        return MethodReflection<AboutModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'doInitialization',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.doInitialization,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'initializedependencies':
        return MethodReflection<AboutModule, FutureOr<List<Initializable>>>(
            this,
            Initializable,
            'initializeDependencies',
            __TR<FutureOr<List<Initializable>>>(FutureOr, <__TR>[
              __TR<List<Initializable>>(
                  List, <__TR>[__TR<Initializable>(Initializable)])
            ]),
            false,
            (o) => o!.initializeDependencies,
            obj,
            null,
            null,
            null,
            null);
      case 'checkinitialized':
        return MethodReflection<AboutModule, void>(
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
            null);
      case 'executeinitialized':
        return MethodReflection<AboutModule, FutureOr<dynamic>>(
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
                      ExecuteInitializedCallback, <__TR>[__TR.tDynamic]),
                  'callback',
                  false,
                  true)
            ],
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<AboutModule, R>? staticMethod<R>(String methodName) =>
      null;
}

class UserModule$reflection extends ClassReflection<UserModule>
    with __ReflectionMixin {
  static final Expando<UserModule$reflection> _objectReflections = Expando();

  factory UserModule$reflection([UserModule? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= UserModule$reflection._(object);
  }

  UserModule$reflection._([UserModule? object])
      : super(UserModule, 'UserModule', object);

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
  Version get languageVersion => Version.parse('3.3.0');

  @override
  UserModule$reflection withObject([UserModule? obj]) =>
      UserModule$reflection(obj)..setupInternalsWith(this);

  static UserModule$reflection? _withoutObjectInstance;
  @override
  UserModule$reflection withoutObjectInstance() => staticInstance;

  static UserModule$reflection get staticInstance =>
      _withoutObjectInstance ??= UserModule$reflection._();

  @override
  UserModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    UserModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  UserModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  UserModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  UserModule? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<UserModule>> _constructors =
      {};

  @override
  ConstructorReflection<UserModule>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<UserModule>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<UserModule>(
            this,
            UserModule,
            '',
            () => (APIRoot apiRoot) => UserModule(apiRoot),
            const <__PR>[__PR(__TR<APIRoot>(APIRoot), 'apiRoot', false, true)],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = const [
    APIEntityAccessRules(EntityAccessRules.blockFields(User, ['email'],
        condition: _blockUserEmailCondition)),
    APIEntityResolutionRules(EntityResolutionRules.fetchEager([User]))
  ];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[APIModule, Initializable];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([UserModule? obj]) => null;

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
    'routes',
    'security',
    'version'
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<UserModule, dynamic>>
      _fieldsNoObject = {};

  final Map<String, FieldReflection<UserModule, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<UserModule, T>? field<T>(String fieldName,
      [UserModule? obj]) {
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

  FieldReflection<UserModule, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<UserModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<UserModule, T>;
  }

  FieldReflection<UserModule, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<UserModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<UserModule, dynamic>? _fieldImpl(
      String fieldName, UserModule? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<UserModule, APIRoot>(
          this,
          APIModule,
          __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot,
          null,
          obj,
          true,
        );
      case 'name':
        return FieldReflection<UserModule, String>(
          this,
          APIModule,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name,
          null,
          obj,
          true,
        );
      case 'version':
        return FieldReflection<UserModule, String?>(
          this,
          APIModule,
          __TR.tString,
          'version',
          true,
          (o) => () => o!.version,
          null,
          obj,
          true,
        );
      case 'apiconfig':
        return FieldReflection<UserModule, APIConfig>(
          this,
          APIModule,
          __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig,
          null,
          obj,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<UserModule, String?>(
          this,
          APIModule,
          __TR.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName,
          null,
          obj,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<UserModule, Set<String>>(
          this,
          APIModule,
          __TR.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames,
          null,
          obj,
          false,
        );
      case 'routes':
        return FieldReflection<UserModule, APIRouteBuilder<APIModule>>(
          this,
          APIModule,
          __TR<APIRouteBuilder<APIModule>>(
              APIRouteBuilder, <__TR>[__TR<APIModule>(APIModule)]),
          'routes',
          false,
          (o) => () => o!.routes,
          null,
          obj,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<UserModule, String>(
          this,
          APIModule,
          __TR.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute,
          null,
          obj,
          false,
        );
      case 'security':
        return FieldReflection<UserModule, APISecurity?>(
          this,
          APIModule,
          __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) => () => o!.security,
          null,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<UserModule, int>(
          this,
          APIModule,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode,
          null,
          obj,
          false,
          const [override],
        );
      case 'initializationstatus':
        return FieldReflection<UserModule, InitializationStatus>(
          this,
          Initializable,
          __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) => () => o!.initializationStatus,
          null,
          obj,
          false,
        );
      case 'isinitialized':
        return FieldReflection<UserModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitialized',
          false,
          (o) => () => o!.isInitialized,
          null,
          obj,
          false,
        );
      case 'isinitializing':
        return FieldReflection<UserModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isInitializing',
          false,
          (o) => () => o!.isInitializing,
          null,
          obj,
          false,
        );
      case 'isasyncinitialization':
        return FieldReflection<UserModule, bool>(
          this,
          Initializable,
          __TR.tBool,
          'isAsyncInitialization',
          false,
          (o) => () => o!.isAsyncInitialization,
          null,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(UserModule? obj,
      {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'apiRoot': obj?.apiRoot,
      'name': obj?.name,
      'version': obj?.version,
      'apiConfig': obj?.apiConfig,
      'defaultRouteName': obj?.defaultRouteName,
      'allRoutesNames': obj?.allRoutesNames,
      'routes': obj?.routes,
      'authenticationRoute': obj?.authenticationRoute,
      'security': obj?.security,
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
  StaticFieldReflection<UserModule, T>? staticField<T>(String fieldName) =>
      null;

  static const List<String> _methodsNames = const <String>[
    'acceptsRequest',
    'addRoute',
    'apiInfo',
    'call',
    'checkInitialized',
    'configure',
    'doInitialization',
    'echoListUser',
    'echoListUser2',
    'echoUser',
    'ensureConfigured',
    'ensureInitialized',
    'ensureInitializedAsync',
    'executeInitialized',
    'geDynamicAsync',
    'geDynamicAsync2',
    'getContextEntityResolutionRules',
    'getDynamic',
    'getRequestEntityAccessRules',
    'getRequestEntityResolutionRules',
    'getRouteHandler',
    'getRouteHandlerByRequest',
    'getRoutesHandlersNames',
    'getUser',
    'getUserAsync',
    'initialize',
    'initializeDependencies',
    'notARoute',
    'notARouteAsync',
    'resolveRoute'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<UserModule, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<UserModule, dynamic>> _methodsObject = {};

  @override
  MethodReflection<UserModule, R>? method<R>(String methodName,
      [UserModule? obj]) {
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

  MethodReflection<UserModule, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<UserModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<UserModule, R>;
  }

  MethodReflection<UserModule, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<UserModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<UserModule, dynamic>? _methodImpl(
      String methodName, UserModule? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<UserModule, void>(
            this,
            UserModule,
            'configure',
            __TR.tVoid,
            false,
            (o) => o!.configure,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'notaroute':
        return MethodReflection<UserModule, String>(
            this,
            UserModule,
            'notARoute',
            __TR.tString,
            false,
            (o) => o!.notARoute,
            obj,
            const <__PR>[__PR(__TR.tInt, 'n', false, true)],
            null,
            null,
            null);
      case 'notarouteasync':
        return MethodReflection<UserModule, Future<String>>(
            this,
            UserModule,
            'notARouteAsync',
            __TR.tFutureString,
            false,
            (o) => o!.notARouteAsync,
            obj,
            const <__PR>[__PR(__TR.tInt, 'n', false, true)],
            null,
            null,
            null);
      case 'getuser':
        return MethodReflection<UserModule, APIResponse<User>>(
            this,
            UserModule,
            'getUser',
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
            false,
            (o) => o!.getUser,
            obj,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'echouser':
        return MethodReflection<UserModule, APIResponse<User>>(
            this,
            UserModule,
            'echoUser',
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
            false,
            (o) => o!.echoUser,
            obj,
            const <__PR>[__PR(__TR<User>(User), 'user', false, true)],
            null,
            null,
            null);
      case 'echolistuser':
        return MethodReflection<UserModule, APIResponse<List<User>>>(
            this,
            UserModule,
            'echoListUser',
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.echoListUser,
            obj,
            const <__PR>[
              __PR(__TR<List<User>>(List, <__TR>[__TR<User>(User)]), 'users',
                  false, true)
            ],
            null,
            null,
            null);
      case 'echolistuser2':
        return MethodReflection<UserModule, APIResponse<List<User>>>(
            this,
            UserModule,
            'echoListUser2',
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.echoListUser2,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'msg', false, true),
              __PR(__TR<List<User>>(List, <__TR>[__TR<User>(User)]), 'users',
                  false, true)
            ],
            null,
            null,
            null);
      case 'getdynamic':
        return MethodReflection<UserModule, APIResponse<dynamic>>(
            this,
            UserModule,
            'getDynamic',
            __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic]),
            false,
            (o) => o!.getDynamic,
            obj,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'getuserasync':
        return MethodReflection<UserModule, Future<APIResponse<User>>>(
            this,
            UserModule,
            'getUserAsync',
            __TR<Future<APIResponse<User>>>(Future, <__TR>[
              __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.getUserAsync,
            obj,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'gedynamicasync':
        return MethodReflection<UserModule, Future<APIResponse<dynamic>>>(
            this,
            UserModule,
            'geDynamicAsync',
            __TR<Future<APIResponse>>(Future, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.geDynamicAsync,
            obj,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'gedynamicasync2':
        return MethodReflection<UserModule, Future<dynamic>>(
            this,
            UserModule,
            'geDynamicAsync2',
            __TR.tFutureDynamic,
            false,
            (o) => o!.geDynamicAsync2,
            obj,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'getcontextentityresolutionrules':
        return MethodReflection<UserModule,
                Future<APIResponse<Map<dynamic, dynamic>>>>(
            this,
            UserModule,
            'getContextEntityResolutionRules',
            __TR<Future<APIResponse<Map>>>(Future, <__TR>[
              __TR<APIResponse<Map>>(APIResponse, <__TR>[
                __TR<Map<dynamic, dynamic>>(
                    Map, <__TR>[__TR.tDynamic, __TR.tDynamic])
              ])
            ]),
            false,
            (o) => o!.getContextEntityResolutionRules,
            obj,
            null,
            null,
            null,
            null);
      case 'getrequestentityresolutionrules':
        return MethodReflection<UserModule,
                Future<APIResponse<Map<dynamic, dynamic>>>>(
            this,
            UserModule,
            'getRequestEntityResolutionRules',
            __TR<Future<APIResponse<Map>>>(Future, <__TR>[
              __TR<APIResponse<Map>>(APIResponse, <__TR>[
                __TR<Map<dynamic, dynamic>>(
                    Map, <__TR>[__TR.tDynamic, __TR.tDynamic])
              ])
            ]),
            false,
            (o) => o!.getRequestEntityResolutionRules,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'getrequestentityaccessrules':
        return MethodReflection<UserModule,
                Future<APIResponse<Map<dynamic, dynamic>>>>(
            this,
            UserModule,
            'getRequestEntityAccessRules',
            __TR<Future<APIResponse<Map>>>(Future, <__TR>[
              __TR<APIResponse<Map>>(APIResponse, <__TR>[
                __TR<Map<dynamic, dynamic>>(
                    Map, <__TR>[__TR.tDynamic, __TR.tDynamic])
              ])
            ]),
            false,
            (o) => o!.getRequestEntityAccessRules,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<UserModule, void>(
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
            null);
      case 'initialize':
        return MethodReflection<UserModule, FutureOr<InitializationResult>>(
            this,
            APIModule,
            'initialize',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.initialize,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<UserModule, Iterable<String>>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            __TR<Iterable<String>>(Iterable, <__TR>[__TR.tString]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            null,
            null,
            const <String, __PR>{
              'method': __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method',
                  true, false)
            },
            null);
      case 'addroute':
        return MethodReflection<UserModule, APIModule>(
            this,
            APIModule,
            'addRoute',
            __TR<APIModule>(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  true),
              __PR(__TR.tString, 'name', false, true),
              __PR(
                  __TR<APIRouteFunction<dynamic>>(
                      APIRouteFunction, <__TR>[__TR.tDynamic]),
                  'function',
                  false,
                  true)
            ],
            null,
            const <String, __PR>{
              'config': __PR(
                  __TR<APIRouteConfig>(APIRouteConfig), 'config', true, false),
              'parameters': __PR(
                  __TR<Map<String, TypeInfo>>(Map, <__TR>[
                    __TR.tString,
                    __TR<TypeInfo<dynamic>>(TypeInfo, <__TR>[__TR.tDynamic])
                  ]),
                  'parameters',
                  true,
                  false),
              'rules': __PR(
                  __TR<Iterable<APIRouteRule>>(
                      Iterable, <__TR>[__TR<APIRouteRule>(APIRouteRule)]),
                  'rules',
                  true,
                  false)
            },
            null);
      case 'getroutehandler':
        return MethodReflection<UserModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandler',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            const <__PR>[__PR(__TR.tString, 'name', false, true)],
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  false)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<UserModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            const <__PR>[__PR(__TR.tString, 'routeName', true, false)],
            null,
            null);
      case 'resolveroute':
        return MethodReflection<UserModule, String>(
            this,
            APIModule,
            'resolveRoute',
            __TR.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<UserModule, FutureOr<APIResponse<dynamic>>>(
            this,
            APIModule,
            'call',
            __TR<FutureOr<APIResponse>>(FutureOr, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'acceptsrequest':
        return MethodReflection<UserModule, bool>(
            this,
            APIModule,
            'acceptsRequest',
            __TR.tBool,
            false,
            (o) => o!.acceptsRequest,
            obj,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', false, true)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<UserModule, APIModuleInfo>(
            this,
            APIModule,
            'apiInfo',
            __TR<APIModuleInfo>(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            null,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', true, false)
            ],
            null,
            null);
      case 'ensureinitialized':
        return MethodReflection<UserModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitialized',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitialized,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'ensureinitializedasync':
        return MethodReflection<UserModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitializedAsync',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitializedAsync,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'doinitialization':
        return MethodReflection<UserModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'doInitialization',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.doInitialization,
            obj,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'initializedependencies':
        return MethodReflection<UserModule, FutureOr<List<Initializable>>>(
            this,
            Initializable,
            'initializeDependencies',
            __TR<FutureOr<List<Initializable>>>(FutureOr, <__TR>[
              __TR<List<Initializable>>(
                  List, <__TR>[__TR<Initializable>(Initializable)])
            ]),
            false,
            (o) => o!.initializeDependencies,
            obj,
            null,
            null,
            null,
            null);
      case 'checkinitialized':
        return MethodReflection<UserModule, void>(
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
            null);
      case 'executeinitialized':
        return MethodReflection<UserModule, FutureOr<dynamic>>(
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
                      ExecuteInitializedCallback, <__TR>[__TR.tDynamic]),
                  'callback',
                  false,
                  true)
            ],
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      default:
        return null;
    }
  }

  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<UserModule, R>? staticMethod<R>(String methodName) =>
      null;
}

extension AboutModule$reflectionExtension on AboutModule {
  /// Returns a [ClassReflection] for type [AboutModule]. (Generated by [ReflectionFactory])
  ClassReflection<AboutModule> get reflection => AboutModule$reflection(this);

  /// Returns a JSON for type [AboutModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [AboutModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [AboutModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded(
          {bool pretty = false, bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonEncoded(
          pretty: pretty, duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [AboutModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension UserModule$reflectionExtension on UserModule {
  /// Returns a [ClassReflection] for type [UserModule]. (Generated by [ReflectionFactory])
  ClassReflection<UserModule> get reflection => UserModule$reflection(this);

  /// Returns a JSON for type [UserModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [UserModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [UserModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded(
          {bool pretty = false, bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonEncoded(
          pretty: pretty, duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [UserModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
      AboutModule$reflection(),
      UserModule$reflection(),
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
