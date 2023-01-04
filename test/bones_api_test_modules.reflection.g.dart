//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.2.18
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test_modules.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('1.2.18');

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
  AboutModule$reflection([AboutModule? object])
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
  Version get languageVersion => Version.parse('2.18.0');

  @override
  AboutModule$reflection withObject([AboutModule? obj]) =>
      AboutModule$reflection(obj);

  static AboutModule$reflection? _withoutObjectInstance;
  @override
  AboutModule$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as AboutModule$reflection;

  static AboutModule$reflection get staticInstance =>
      _withoutObjectInstance ??= AboutModule$reflection();

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

  @override
  List<String> get constructorsNames => const <String>[''];

  @override
  ConstructorReflection<AboutModule>? constructor<R>(String constructorName) {
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

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<Type> get supperTypes => const <Type>[APIModule, Initializable];

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([AboutModule? obj]) => null;

  @override
  List<String> get fieldsNames => const <String>[
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
  FieldReflection<AboutModule, T>? field<T>(String fieldName,
      [AboutModule? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot as T,
          null,
          obj,
          false,
          true,
        );
      case 'name':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name as T,
          null,
          obj,
          false,
          true,
        );
      case 'version':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tString,
          'version',
          true,
          (o) => () => o!.version as T,
          null,
          obj,
          false,
          true,
        );
      case 'apiconfig':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig as T,
          null,
          obj,
          false,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName as T,
          null,
          obj,
          false,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames as T,
          null,
          obj,
          false,
          false,
        );
      case 'routes':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR<APIRouteBuilder<APIModule>>(
              APIRouteBuilder, <__TR>[__TR<APIModule>(APIModule)]),
          'routes',
          false,
          (o) => () => o!.routes as T,
          null,
          obj,
          false,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute as T,
          null,
          obj,
          false,
          false,
        );
      case 'security':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) => () => o!.security as T,
          null,
          obj,
          false,
          false,
        );
      case 'hashcode':
        return FieldReflection<AboutModule, T>(
          this,
          APIModule,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'initializationstatus':
        return FieldReflection<AboutModule, T>(
          this,
          Initializable,
          __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) => () => o!.initializationStatus as T,
          null,
          obj,
          false,
          false,
        );
      case 'isinitialized':
        return FieldReflection<AboutModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isInitialized',
          false,
          (o) => () => o!.isInitialized as T,
          null,
          obj,
          false,
          false,
        );
      case 'isinitializing':
        return FieldReflection<AboutModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isInitializing',
          false,
          (o) => () => o!.isInitializing as T,
          null,
          obj,
          false,
          false,
        );
      case 'isasyncinitialization':
        return FieldReflection<AboutModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isAsyncInitialization',
          false,
          (o) => () => o!.isAsyncInitialization as T,
          null,
          obj,
          false,
          false,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<AboutModule, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
  MethodReflection<AboutModule, R>? method<R>(String methodName,
      [AboutModule? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<AboutModule, R>(
            this,
            AboutModule,
            'configure',
            __TR.tVoid,
            false,
            (o) => o!.configure,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'about':
        return MethodReflection<AboutModule, R>(
            this,
            AboutModule,
            'about',
            __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
            false,
            (o) => o!.about,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'ensureConfigured',
            __TR.tVoid,
            false,
            (o) => o!.ensureConfigured,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'initialize':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'initialize',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.initialize,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            __TR<Iterable<String>>(Iterable, <__TR>[__TR.tString]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'method': __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method',
                  true, false)
            },
            null);
      case 'addroute':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'addRoute',
            __TR<APIModule>(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            false,
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
              'parameters': __PR(
                  __TR<Map<String, TypeInfo<dynamic>>>(Map, <__TR>[
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
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'getRouteHandler',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            false,
            const <__PR>[__PR(__TR.tString, 'name', false, true)],
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  false)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            const <__PR>[__PR(__TR.tString, 'routeName', true, false)],
            null,
            null);
      case 'resolveroute':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'resolveRoute',
            __TR.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'call',
            __TR<FutureOr<APIResponse<dynamic>>>(FutureOr, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'acceptsrequest':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'acceptsRequest',
            __TR.tBool,
            false,
            (o) => o!.acceptsRequest,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', false, true)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<AboutModule, R>(
            this,
            APIModule,
            'apiInfo',
            __TR<APIModuleInfo>(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            false,
            null,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', true, false)
            ],
            null,
            null);
      case 'ensureinitialized':
        return MethodReflection<AboutModule, R>(
            this,
            Initializable,
            'ensureInitialized',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitialized,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'ensureinitializedasync':
        return MethodReflection<AboutModule, R>(
            this,
            Initializable,
            'ensureInitializedAsync',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitializedAsync,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'doinitialization':
        return MethodReflection<AboutModule, R>(
            this,
            Initializable,
            'doInitialization',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.doInitialization,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'initializedependencies':
        return MethodReflection<AboutModule, R>(
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
            false,
            null,
            null,
            null,
            null);
      case 'checkinitialized':
        return MethodReflection<AboutModule, R>(
            this,
            Initializable,
            'checkInitialized',
            __TR.tVoid,
            false,
            (o) => o!.checkInitialized,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'executeinitialized':
        return MethodReflection<AboutModule, R>(
            this,
            Initializable,
            'executeInitialized',
            __TR.tFutureOrDynamic,
            false,
            (o) => o!.executeInitialized,
            obj,
            false,
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

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<AboutModule, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

class UserModule$reflection extends ClassReflection<UserModule>
    with __ReflectionMixin {
  UserModule$reflection([UserModule? object])
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
  Version get languageVersion => Version.parse('2.18.0');

  @override
  UserModule$reflection withObject([UserModule? obj]) =>
      UserModule$reflection(obj);

  static UserModule$reflection? _withoutObjectInstance;
  @override
  UserModule$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as UserModule$reflection;

  static UserModule$reflection get staticInstance =>
      _withoutObjectInstance ??= UserModule$reflection();

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

  @override
  List<String> get constructorsNames => const <String>[''];

  @override
  ConstructorReflection<UserModule>? constructor<R>(String constructorName) {
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

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<Type> get supperTypes => const <Type>[APIModule, Initializable];

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([UserModule? obj]) => null;

  @override
  List<String> get fieldsNames => const <String>[
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
  FieldReflection<UserModule, T>? field<T>(String fieldName,
      [UserModule? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot as T,
          null,
          obj,
          false,
          true,
        );
      case 'name':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tString,
          'name',
          false,
          (o) => () => o!.name as T,
          null,
          obj,
          false,
          true,
        );
      case 'version':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tString,
          'version',
          true,
          (o) => () => o!.version as T,
          null,
          obj,
          false,
          true,
        );
      case 'apiconfig':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig as T,
          null,
          obj,
          false,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName as T,
          null,
          obj,
          false,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames as T,
          null,
          obj,
          false,
          false,
        );
      case 'routes':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR<APIRouteBuilder<APIModule>>(
              APIRouteBuilder, <__TR>[__TR<APIModule>(APIModule)]),
          'routes',
          false,
          (o) => () => o!.routes as T,
          null,
          obj,
          false,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute as T,
          null,
          obj,
          false,
          false,
        );
      case 'security':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) => () => o!.security as T,
          null,
          obj,
          false,
          false,
        );
      case 'hashcode':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          __TR.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          [override],
        );
      case 'initializationstatus':
        return FieldReflection<UserModule, T>(
          this,
          Initializable,
          __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) => () => o!.initializationStatus as T,
          null,
          obj,
          false,
          false,
        );
      case 'isinitialized':
        return FieldReflection<UserModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isInitialized',
          false,
          (o) => () => o!.isInitialized as T,
          null,
          obj,
          false,
          false,
        );
      case 'isinitializing':
        return FieldReflection<UserModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isInitializing',
          false,
          (o) => () => o!.isInitializing as T,
          null,
          obj,
          false,
          false,
        );
      case 'isasyncinitialization':
        return FieldReflection<UserModule, T>(
          this,
          Initializable,
          __TR.tBool,
          'isAsyncInitialization',
          false,
          (o) => () => o!.isAsyncInitialization as T,
          null,
          obj,
          false,
          false,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<UserModule, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
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
        'getDynamic',
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
  MethodReflection<UserModule, R>? method<R>(String methodName,
      [UserModule? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'configure',
            __TR.tVoid,
            false,
            (o) => o!.configure,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'notaroute':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'notARoute',
            __TR.tString,
            false,
            (o) => o!.notARoute,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'n', false, true)],
            null,
            null,
            null);
      case 'notarouteasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'notARouteAsync',
            __TR.tFutureString,
            false,
            (o) => o!.notARouteAsync,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'n', false, true)],
            null,
            null,
            null);
      case 'getuser':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getUser',
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
            false,
            (o) => o!.getUser,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'echouser':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'echoUser',
            __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)]),
            false,
            (o) => o!.echoUser,
            obj,
            false,
            const <__PR>[__PR(__TR<User>(User), 'user', false, true)],
            null,
            null,
            null);
      case 'echolistuser':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'echoListUser',
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.echoListUser,
            obj,
            false,
            const <__PR>[
              __PR(__TR<List<User>>(List, <__TR>[__TR<User>(User)]), 'users',
                  false, true)
            ],
            null,
            null,
            null);
      case 'echolistuser2':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'echoListUser2',
            __TR<APIResponse<List<User>>>(APIResponse, <__TR>[
              __TR<List<User>>(List, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.echoListUser2,
            obj,
            false,
            const <__PR>[
              __PR(__TR.tString, 'msg', false, true),
              __PR(__TR<List<User>>(List, <__TR>[__TR<User>(User)]), 'users',
                  false, true)
            ],
            null,
            null,
            null);
      case 'getdynamic':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getDynamic',
            __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic]),
            false,
            (o) => o!.getDynamic,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'getuserasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getUserAsync',
            __TR<Future<APIResponse<User>>>(Future, <__TR>[
              __TR<APIResponse<User>>(APIResponse, <__TR>[__TR<User>(User)])
            ]),
            false,
            (o) => o!.getUserAsync,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'gedynamicasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'geDynamicAsync',
            __TR<Future<APIResponse<dynamic>>>(Future, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.geDynamicAsync,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'gedynamicasync2':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'geDynamicAsync2',
            __TR.tFutureDynamic,
            false,
            (o) => o!.geDynamicAsync2,
            obj,
            false,
            const <__PR>[__PR(__TR.tInt, 'id', false, true)],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'ensureConfigured',
            __TR.tVoid,
            false,
            (o) => o!.ensureConfigured,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'initialize':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'initialize',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.initialize,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            __TR<Iterable<String>>(Iterable, <__TR>[__TR.tString]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'method': __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method',
                  true, false)
            },
            null);
      case 'addroute':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'addRoute',
            __TR<APIModule>(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            false,
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
              'parameters': __PR(
                  __TR<Map<String, TypeInfo<dynamic>>>(Map, <__TR>[
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
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRouteHandler',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            false,
            const <__PR>[__PR(__TR.tString, 'name', false, true)],
            const <__PR>[
              __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method', true,
                  false)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            __TR<APIRouteHandler<dynamic>>(
                APIRouteHandler, <__TR>[__TR.tDynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            const <__PR>[__PR(__TR.tString, 'routeName', true, false)],
            null,
            null);
      case 'resolveroute':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'resolveRoute',
            __TR.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'call',
            __TR<FutureOr<APIResponse<dynamic>>>(FutureOr, <__TR>[
              __TR<APIResponse<dynamic>>(APIResponse, <__TR>[__TR.tDynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'acceptsrequest':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'acceptsRequest',
            __TR.tBool,
            false,
            (o) => o!.acceptsRequest,
            obj,
            false,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', false, true)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'apiInfo',
            __TR<APIModuleInfo>(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            false,
            null,
            const <__PR>[
              __PR(__TR<APIRequest>(APIRequest), 'apiRequest', true, false)
            ],
            null,
            null);
      case 'ensureinitialized':
        return MethodReflection<UserModule, R>(
            this,
            Initializable,
            'ensureInitialized',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitialized,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'ensureinitializedasync':
        return MethodReflection<UserModule, R>(
            this,
            Initializable,
            'ensureInitializedAsync',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.ensureInitializedAsync,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'doinitialization':
        return MethodReflection<UserModule, R>(
            this,
            Initializable,
            'doInitialization',
            __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.doInitialization,
            obj,
            false,
            null,
            null,
            const <String, __PR>{
              'parent': __PR(
                  __TR<Initializable>(Initializable), 'parent', true, false)
            },
            null);
      case 'initializedependencies':
        return MethodReflection<UserModule, R>(
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
            false,
            null,
            null,
            null,
            null);
      case 'checkinitialized':
        return MethodReflection<UserModule, R>(
            this,
            Initializable,
            'checkInitialized',
            __TR.tVoid,
            false,
            (o) => o!.checkInitialized,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'executeinitialized':
        return MethodReflection<UserModule, R>(
            this,
            Initializable,
            'executeInitialized',
            __TR.tFutureOrDynamic,
            false,
            (o) => o!.executeInitialized,
            obj,
            false,
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

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<UserModule, R>? staticMethod<R>(String methodName) {
    return null;
  }
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
