//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.2.22
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('1.2.22');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJson(Map<String, Object?> map) =>
    MyInfoModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJsonEncoded(String jsonEncoded) =>
    MyInfoModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class MyInfoModule$reflection extends ClassReflection<MyInfoModule>
    with __ReflectionMixin {
  MyInfoModule$reflection([MyInfoModule? object])
      : super(MyInfoModule, 'MyInfoModule', object);

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
  MyInfoModule$reflection withObject([MyInfoModule? obj]) =>
      MyInfoModule$reflection(obj);

  static MyInfoModule$reflection? _withoutObjectInstance;
  @override
  MyInfoModule$reflection withoutObjectInstance() => _withoutObjectInstance ??=
      super.withoutObjectInstance() as MyInfoModule$reflection;

  static MyInfoModule$reflection get staticInstance =>
      _withoutObjectInstance ??= MyInfoModule$reflection();

  @override
  MyInfoModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    MyInfoModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  MyInfoModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  MyInfoModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  MyInfoModule? createInstanceWithNoRequiredArgsConstructor() => null;

  @override
  List<String> get constructorsNames => const <String>[''];

  @override
  ConstructorReflection<MyInfoModule>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<MyInfoModule>(
            this,
            MyInfoModule,
            '',
            () => (APIRoot apiRoot) => MyInfoModule(apiRoot),
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
  Object? callMethodToJson([MyInfoModule? obj]) => null;

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
  FieldReflection<MyInfoModule, T>? field<T>(String fieldName,
      [MyInfoModule? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
  FieldReflection<MyInfoModule, T>? staticField<T>(String fieldName) {
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
        'echo',
        'ensureConfigured',
        'ensureInitialized',
        'ensureInitializedAsync',
        'executeInitialized',
        'getRouteHandler',
        'getRouteHandlerByRequest',
        'getRoutesHandlersNames',
        'initialize',
        'initializeDependencies',
        'resolveRoute',
        'toUpperCase'
      ];

  @override
  MethodReflection<MyInfoModule, R>? method<R>(String methodName,
      [MyInfoModule? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
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
      case 'echo':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
            'echo',
            __TR<FutureOr<APIResponse<String>>>(FutureOr, <__TR>[
              __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString])
            ]),
            false,
            (o) => o!.echo,
            obj,
            false,
            const <__PR>[
              __PR(__TR.tString, 'msg', false, true),
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'touppercase':
        return MethodReflection<MyInfoModule, R>(
            this,
            MyInfoModule,
            'toUpperCase',
            __TR<FutureOr<APIResponse<String>>>(FutureOr, <__TR>[
              __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString])
            ]),
            false,
            (o) => o!.toUpperCase,
            obj,
            false,
            const <__PR>[__PR(__TR.tString, 'msg', false, true)],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
  MethodReflection<MyInfoModule, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

extension MyInfoModule$reflectionExtension on MyInfoModule {
  /// Returns a [ClassReflection] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  ClassReflection<MyInfoModule> get reflection => MyInfoModule$reflection(this);

  /// Returns a JSON for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded(
          {bool pretty = false, bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonEncoded(
          pretty: pretty, duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns a JSON for type [MyInfoModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension MyInfoModuleProxy$reflectionProxy on MyInfoModuleProxy {
  Future<String> echo(String msg) {
    var ret = onCall(
        this,
        'echo',
        <String, dynamic>{
          'msg': msg,
        },
        __TR.tFutureString);
    return ret is Future<String>
        ? ret as Future<String>
        : (ret is Future
            ? ret.then((v) => v as String)
            : Future<String>.value(ret as dynamic));
  }

  Future<String> toUpperCase(String msg) {
    var ret = onCall(
        this,
        'toUpperCase',
        <String, dynamic>{
          'msg': msg,
        },
        __TR.tFutureString);
    return ret is Future<String>
        ? ret as Future<String>
        : (ret is Future
            ? ret.then((v) => v as String)
            : Future<String>.value(ret as dynamic));
  }
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
      MyInfoModule$reflection(),
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
