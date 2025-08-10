//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.5.3
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

part of 'bones_api_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.5.3');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"config":
      return const Symbol(r"config");
    case r"method":
      return const Symbol(r"method");
    case r"parameters":
      return const Symbol(r"parameters");
    case r"parent":
      return const Symbol(r"parent");
    case r"rules":
      return const Symbol(r"rules");
    default:
      return null;
  }
}

Future<T> __retFut$<T>(Object? o) => ClassProxy.returnFuture<T>(o);

// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJson(Map<String, Object?> map) =>
    MyInfoModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJsonEncoded(String jsonEncoded) =>
    MyInfoModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class MyInfoModule$reflection extends ClassReflection<MyInfoModule>
    with __ReflectionMixin {
  static final Expando<MyInfoModule$reflection> _objectReflections = Expando();

  factory MyInfoModule$reflection([MyInfoModule? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= MyInfoModule$reflection._(object);
  }

  MyInfoModule$reflection._([MyInfoModule? object])
      : super(MyInfoModule, r'MyInfoModule', object);

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
  MyInfoModule$reflection withObject([MyInfoModule? obj]) =>
      MyInfoModule$reflection(obj)..setupInternalsWith(this);

  static MyInfoModule$reflection? _withoutObjectInstance;
  @override
  MyInfoModule$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static MyInfoModule$reflection get staticInstance =>
      _withoutObjectInstance ??= MyInfoModule$reflection._();

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

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<MyInfoModule>> _constructors =
      {};

  @override
  ConstructorReflection<MyInfoModule>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<MyInfoModule>? _constructorImpl(
      String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<MyInfoModule>(
            this,
            MyInfoModule,
            '',
            () => MyInfoModule.new,
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
  Object? callMethodToJson([MyInfoModule? obj]) => null;

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

  static final Map<String, FieldReflection<MyInfoModule, dynamic>>
      _fieldsNoObject = {};

  final Map<String, FieldReflection<MyInfoModule, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<MyInfoModule, T>? field<T>(String fieldName,
      [MyInfoModule? obj]) {
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

  FieldReflection<MyInfoModule, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<MyInfoModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<MyInfoModule, T>;
  }

  FieldReflection<MyInfoModule, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<MyInfoModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<MyInfoModule, dynamic>? _fieldImpl(
      String fieldName, MyInfoModule? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<MyInfoModule, APIRoot>(
          this,
          APIModule,
          const __TR<APIRoot>(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot,
          null,
          obj,
          true,
        );
      case 'name':
        return FieldReflection<MyInfoModule, String>(
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
        return FieldReflection<MyInfoModule, String?>(
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
        return FieldReflection<MyInfoModule, APIConfig>(
          this,
          APIModule,
          const __TR<APIConfig>(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig,
          null,
          obj,
          false,
        );
      case 'defaultroutename':
        return FieldReflection<MyInfoModule, String?>(
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
        return FieldReflection<MyInfoModule, Set<String>>(
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
        return FieldReflection<MyInfoModule, APIRouteBuilder<APIModule>>(
          this,
          APIModule,
          const __TR<APIRouteBuilder<APIModule>>(
              APIRouteBuilder, <__TR>[__TR<APIModule>(APIModule)]),
          'routes',
          false,
          (o) => () => o!.routes,
          null,
          obj,
          false,
        );
      case 'authenticationroute':
        return FieldReflection<MyInfoModule, String>(
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
        return FieldReflection<MyInfoModule, APISecurity?>(
          this,
          APIModule,
          const __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) => () => o!.security,
          null,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<MyInfoModule, int>(
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
        return FieldReflection<MyInfoModule, InitializationStatus>(
          this,
          Initializable,
          const __TR<InitializationStatus>(InitializationStatus),
          'initializationStatus',
          false,
          (o) => () => o!.initializationStatus,
          null,
          obj,
          false,
        );
      case 'isinitialized':
        return FieldReflection<MyInfoModule, bool>(
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
        return FieldReflection<MyInfoModule, bool>(
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
        return FieldReflection<MyInfoModule, bool>(
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
  Map<String, dynamic> getFieldsValues(MyInfoModule? obj,
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
  StaticFieldReflection<MyInfoModule, T>? staticField<T>(String fieldName) =>
      null;

  static const List<String> _methodsNames = const <String>[
    'acceptsRequest',
    'addRoute',
    'addRouteHandler',
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
    'listMultiplier',
    'mapKeys',
    'resolveRoute',
    'toUpperCase',
    'withPayload'
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<MyInfoModule, dynamic>>
      _methodsNoObject = {};

  final Map<String, MethodReflection<MyInfoModule, dynamic>> _methodsObject =
      {};

  @override
  MethodReflection<MyInfoModule, R>? method<R>(String methodName,
      [MyInfoModule? obj]) {
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

  MethodReflection<MyInfoModule, R>? _methodNoObjectImpl<R>(String methodName) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<MyInfoModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<MyInfoModule, R>;
  }

  MethodReflection<MyInfoModule, R>? _methodObjectImpl<R>(String methodName) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<MyInfoModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<MyInfoModule, dynamic>? _methodImpl(
      String methodName, MyInfoModule? obj) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<MyInfoModule, void>(
            this,
            MyInfoModule,
            'configure',
            __TR.tVoid,
            false,
            (o) => o!.configure,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'echo':
        return MethodReflection<MyInfoModule, FutureOr<APIResponse<String>>>(
            this,
            MyInfoModule,
            'echo',
            const __TR<FutureOr<APIResponse<String>>>(FutureOr, <__TR>[
              __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString])
            ]),
            false,
            (o) => o!.echo,
            obj,
            const <__PR>[
              __PR(__TR.tString, 'msg', false, true),
              __PR(__TR<APIRequest>(APIRequest), 'request', false, true)
            ],
            null,
            null,
            null);
      case 'touppercase':
        return MethodReflection<MyInfoModule, FutureOr<APIResponse<String>>>(
            this,
            MyInfoModule,
            'toUpperCase',
            const __TR<FutureOr<APIResponse<String>>>(FutureOr, <__TR>[
              __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString])
            ]),
            false,
            (o) => o!.toUpperCase,
            obj,
            const <__PR>[__PR(__TR.tString, 'msg', false, true)],
            null,
            null,
            null);
      case 'withpayload':
        return MethodReflection<MyInfoModule, FutureOr<APIResponse<String>>>(
            this,
            MyInfoModule,
            'withPayload',
            const __TR<FutureOr<APIResponse<String>>>(FutureOr, <__TR>[
              __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString])
            ]),
            false,
            (o) => o!.withPayload,
            obj,
            const <__PR>[
              __PR(__TR<Uint8List>(Uint8List), 'payload', true, true)
            ],
            null,
            null,
            null);
      case 'mapkeys':
        return MethodReflection<MyInfoModule,
                FutureOr<APIResponse<List<String>>>>(
            this,
            MyInfoModule,
            'mapKeys',
            const __TR<FutureOr<APIResponse<List<String>>>>(FutureOr, <__TR>[
              __TR<APIResponse<List<String>>>(
                  APIResponse, <__TR>[__TR.tListString])
            ]),
            false,
            (o) => o!.mapKeys,
            obj,
            const <__PR>[__PR(__TR.tMapStringDynamic, 'map', false, true)],
            null,
            null,
            null);
      case 'listmultiplier':
        return MethodReflection<MyInfoModule, FutureOr<APIResponse<List<int>>>>(
            this,
            MyInfoModule,
            'listMultiplier',
            const __TR<FutureOr<APIResponse<List<int>>>>(FutureOr, <__TR>[
              __TR<APIResponse<List<int>>>(APIResponse, <__TR>[__TR.tListInt])
            ]),
            false,
            (o) => o!.listMultiplier,
            obj,
            const <__PR>[
              __PR(__TR.tListInt, 'list', false, true),
              __PR(__TR.tInt, 'm', false, true)
            ],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<MyInfoModule, void>(
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
        return MethodReflection<MyInfoModule, FutureOr<InitializationResult>>(
            this,
            APIModule,
            'initialize',
            const __TR<FutureOr<InitializationResult>>(FutureOr,
                <__TR>[__TR<InitializationResult>(InitializationResult)]),
            false,
            (o) => o!.initialize,
            obj,
            null,
            null,
            null,
            const [override]);
      case 'getrouteshandlersnames':
        return MethodReflection<MyInfoModule, Iterable<String>>(
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
              'method': __PR(__TR<APIRequestMethod>(APIRequestMethod), 'method',
                  true, false)
            },
            null);
      case 'addroute':
        return MethodReflection<MyInfoModule, APIModule>(
            this,
            APIModule,
            'addRoute',
            const __TR<APIModule>(APIModule),
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
      case 'addroutehandler':
        return MethodReflection<MyInfoModule, APIModule>(
            this,
            APIModule,
            'addRouteHandler',
            const __TR<APIModule>(APIModule),
            false,
            (o) => o!.addRouteHandler,
            obj,
            const <__PR>[
              __PR(
                  __TR<APIRouteHandler<dynamic>>(
                      APIRouteHandler, <__TR>[__TR.tDynamic]),
                  'routeHandler',
                  false,
                  true)
            ],
            null,
            null,
            null);
      case 'getroutehandler':
        return MethodReflection<MyInfoModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandler',
            const __TR<APIRouteHandler<dynamic>>(
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
        return MethodReflection<MyInfoModule, APIRouteHandler<dynamic>?>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            const __TR<APIRouteHandler<dynamic>>(
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
        return MethodReflection<MyInfoModule, String>(
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
        return MethodReflection<MyInfoModule, FutureOr<APIResponse<dynamic>>>(
            this,
            APIModule,
            'call',
            const __TR<FutureOr<APIResponse>>(FutureOr, <__TR>[
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
        return MethodReflection<MyInfoModule, bool>(
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
        return MethodReflection<MyInfoModule, APIModuleInfo>(
            this,
            APIModule,
            'apiInfo',
            const __TR<APIModuleInfo>(APIModuleInfo),
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
        return MethodReflection<MyInfoModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitialized',
            const __TR<FutureOr<InitializationResult>>(FutureOr,
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
        return MethodReflection<MyInfoModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'ensureInitializedAsync',
            const __TR<FutureOr<InitializationResult>>(FutureOr,
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
        return MethodReflection<MyInfoModule, FutureOr<InitializationResult>>(
            this,
            Initializable,
            'doInitialization',
            const __TR<FutureOr<InitializationResult>>(FutureOr,
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
        return MethodReflection<MyInfoModule, FutureOr<List<Initializable>>>(
            this,
            Initializable,
            'initializeDependencies',
            const __TR<FutureOr<List<Initializable>>>(FutureOr, <__TR>[
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
        return MethodReflection<MyInfoModule, void>(
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
        return MethodReflection<MyInfoModule, FutureOr<dynamic>>(
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
  StaticMethodReflection<MyInfoModule, R>? staticMethod<R>(String methodName) =>
      null;
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
    return __retFut$<String>(ret);
  }

  Future<String> toUpperCase(String msg) {
    var ret = onCall(
        this,
        'toUpperCase',
        <String, dynamic>{
          'msg': msg,
        },
        __TR.tFutureString);
    return __retFut$<String>(ret);
  }

  Future<String> withPayload(Uint8List? payload) {
    var ret = onCall(
        this,
        'withPayload',
        <String, dynamic>{
          'payload': payload,
        },
        __TR.tFutureString);
    return __retFut$<String>(ret);
  }

  Future<List<String>> mapKeys(Map<String, dynamic> map) {
    var ret = onCall(
        this,
        'mapKeys',
        <String, dynamic>{
          'map': map,
        },
        const __TR<Future<List<String>>>(Future, <__TR>[__TR.tListString]));
    return __retFut$<List<String>>(ret);
  }

  Future<List<int>> listMultiplier(List<int> list, int m) {
    var ret = onCall(
        this,
        'listMultiplier',
        <String, dynamic>{
          'list': list,
          'm': m,
        },
        const __TR<Future<List<int>>>(Future, <__TR>[__TR.tListInt]));
    return __retFut$<List<int>>(ret);
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
