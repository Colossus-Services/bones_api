//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.13.0
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

part of 'bones_api_route_raw_handler_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.13.0');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"allowInProgress":
      return const Symbol(r"allowInProgress");
    case r"config":
      return const Symbol(r"config");
    case r"establishmentId":
      return const Symbol(r"establishmentId");
    case r"id":
      return const Symbol(r"id");
    case r"label":
      return const Symbol(r"label");
    case r"method":
      return const Symbol(r"method");
    case r"otherId":
      return const Symbol(r"otherId");
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
RawHandlerModule RawHandlerModule$fromJson(Map<String, Object?> map) =>
    RawHandlerModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
RawHandlerModule RawHandlerModule$fromJsonEncoded(String jsonEncoded) =>
    RawHandlerModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class RawHandlerModule$reflection extends ClassReflection<RawHandlerModule>
    with __ReflectionMixin {
  static final Expando<RawHandlerModule$reflection> _objectReflections =
      Expando();

  factory RawHandlerModule$reflection([RawHandlerModule? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= RawHandlerModule$reflection._(object);
  }

  RawHandlerModule$reflection._([RawHandlerModule? object])
    : super(RawHandlerModule, r'RawHandlerModule', object);

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
  RawHandlerModule$reflection withObject([RawHandlerModule? obj]) =>
      RawHandlerModule$reflection(obj)..setupInternalsWith(this);

  static RawHandlerModule$reflection? _withoutObjectInstance;
  @override
  RawHandlerModule$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static RawHandlerModule$reflection get staticInstance =>
      _withoutObjectInstance ??= RawHandlerModule$reflection._();

  @override
  RawHandlerModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    RawHandlerModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  RawHandlerModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  RawHandlerModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  RawHandlerModule? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<RawHandlerModule>>
  _constructors = {};

  @override
  ConstructorReflection<RawHandlerModule>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<RawHandlerModule>? _constructorImpl(
    String constructorName,
  ) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<RawHandlerModule>(
          this,
          RawHandlerModule,
          '',
          () => RawHandlerModule.new,
          const <__PR>[__PR(__TR<APIRoot>(APIRoot), 'apiRoot', false, true)],
          null,
          null,
          null,
          invoker: (a) => RawHandlerModule(a[0] as APIRoot),
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
  Object? callMethodToJson([RawHandlerModule? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'allRoutesNames',
    'apiConfig',
    'apiRoot',
    'authenticationRoute',
    'cronJobs',
    'cyclicDependencies',
    'defaultRouteName',
    'hashCode',
    'initializationStatus',
    'isAsyncInitialization',
    'isInitialized',
    'isInitializing',
    'name',
    'routes',
    'security',
    'version',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<RawHandlerModule, dynamic>>
  _fieldsNoObject = {};

  final Map<String, FieldReflection<RawHandlerModule, dynamic>> _fieldsObject =
      {};

  @override
  FieldReflection<RawHandlerModule, T>? field<T>(
    String fieldName, [
    RawHandlerModule? obj,
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

  FieldReflection<RawHandlerModule, T>? _fieldNoObjectImpl<T>(
    String fieldName,
  ) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<RawHandlerModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<RawHandlerModule, T>;
  }

  FieldReflection<RawHandlerModule, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<RawHandlerModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<RawHandlerModule, dynamic>? _fieldImpl(
    String fieldName,
    RawHandlerModule? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<RawHandlerModule, APIRoot>(
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
        return FieldReflection<RawHandlerModule, String>(
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
        return FieldReflection<RawHandlerModule, String?>(
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
        return FieldReflection<RawHandlerModule, APIConfig>(
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
        return FieldReflection<RawHandlerModule, String?>(
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
      case 'cronjobs':
        return FieldReflection<RawHandlerModule, List<APICronJob>>(
          this,
          APIModule,
          const __TR<List<APICronJob>>(List, <__TR>[
            __TR<APICronJob>(APICronJob),
          ]),
          'cronJobs',
          false,
          (o) =>
              () => o!.cronJobs,
          null,
          obj,
          false,
        );
      case 'allroutesnames':
        return FieldReflection<RawHandlerModule, Set<String>>(
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
        return FieldReflection<RawHandlerModule, APIRouteBuilder<APIModule>>(
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
        return FieldReflection<RawHandlerModule, String>(
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
      case 'security':
        return FieldReflection<RawHandlerModule, APISecurity?>(
          this,
          APIModule,
          const __TR<APISecurity>(APISecurity),
          'security',
          true,
          (o) =>
              () => o!.security,
          null,
          obj,
          false,
        );
      case 'hashcode':
        return FieldReflection<RawHandlerModule, int>(
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
        return FieldReflection<RawHandlerModule, InitializationStatus>(
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
        return FieldReflection<RawHandlerModule, bool>(
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
        return FieldReflection<RawHandlerModule, bool>(
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
        return FieldReflection<RawHandlerModule, bool>(
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
      case 'cyclicdependencies':
        return FieldReflection<RawHandlerModule, List<Initializable>>(
          this,
          Initializable,
          const __TR<List<Initializable>>(List, <__TR>[
            __TR<Initializable>(Initializable),
          ]),
          'cyclicDependencies',
          false,
          (o) =>
              () => o!.cyclicDependencies,
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
    RawHandlerModule? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'apiRoot': obj?.apiRoot,
      'name': obj?.name,
      'version': obj?.version,
      'apiConfig': obj?.apiConfig,
      'defaultRouteName': obj?.defaultRouteName,
      'cronJobs': obj?.cronJobs,
      'allRoutesNames': obj?.allRoutesNames,
      'routes': obj?.routes,
      'authenticationRoute': obj?.authenticationRoute,
      'security': obj?.security,
      'initializationStatus': obj?.initializationStatus,
      'isInitialized': obj?.isInitialized,
      'isInitializing': obj?.isInitializing,
      'isAsyncInitialization': obj?.isAsyncInitialization,
      'cyclicDependencies': obj?.cyclicDependencies,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<RawHandlerModule, T>? staticField<T>(
    String fieldName,
  ) => null;

  static const List<String> _methodsNames = const <String>[
    'acceptsRequest',
    'addCronJob',
    'addRoute',
    'addRouteHandler',
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
    'raw',
    'rawNoResponse',
    'resolveRoute',
    'withCredential',
    'withNamed',
    'withNamedNoResponse',
    'withOptional',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<RawHandlerModule, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<RawHandlerModule, dynamic>>
  _methodsObject = {};

  @override
  MethodReflection<RawHandlerModule, R>? method<R>(
    String methodName, [
    RawHandlerModule? obj,
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

  MethodReflection<RawHandlerModule, R>? _methodNoObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<RawHandlerModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<RawHandlerModule, R>;
  }

  MethodReflection<RawHandlerModule, R>? _methodObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<RawHandlerModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<RawHandlerModule, dynamic>? _methodImpl(
    String methodName,
    RawHandlerModule? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<RawHandlerModule, void>(
          this,
          RawHandlerModule,
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
      case 'raw':
        return MethodReflection<
          RawHandlerModule,
          APIResponse<Map<dynamic, dynamic>>
        >(
          this,
          RawHandlerModule,
          'raw',
          const __TR<APIResponse<Map>>(APIResponse, <__TR>[
            __TR<Map<dynamic, dynamic>>(Map, <__TR>[
              __TR.tDynamic,
              __TR.tDynamic,
            ]),
          ]),
          false,
          (o) => o!.raw,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          null,
        );
      case 'rawnoresponse':
        return MethodReflection<RawHandlerModule, Future<String>>(
          this,
          RawHandlerModule,
          'rawNoResponse',
          __TR.tFutureString,
          false,
          (o) => o!.rawNoResponse,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          null,
        );
      case 'withnamed':
        return MethodReflection<
          RawHandlerModule,
          Future<APIResponse<Map<dynamic, dynamic>>>
        >(
          this,
          RawHandlerModule,
          'withNamed',
          const __TR<Future<APIResponse<Map>>>(Future, <__TR>[
            __TR<APIResponse<Map>>(APIResponse, <__TR>[
              __TR<Map<dynamic, dynamic>>(Map, <__TR>[
                __TR.tDynamic,
                __TR.tDynamic,
              ]),
            ]),
          ]),
          false,
          (o) => o!.withNamed,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          const <String, __PR>{
            'establishmentId': __PR(__TR.tInt, 'establishmentId', false, true),
            'label': __PR(__TR.tString, 'label', false, false, 'def'),
            'otherId': __PR(__TR.tInt, 'otherId', true, false),
          },
          const [EstablishmentRule()],
        );
      case 'withoptional':
        return MethodReflection<
          RawHandlerModule,
          APIResponse<Map<dynamic, dynamic>>
        >(
          this,
          RawHandlerModule,
          'withOptional',
          const __TR<APIResponse<Map>>(APIResponse, <__TR>[
            __TR<Map<dynamic, dynamic>>(Map, <__TR>[
              __TR.tDynamic,
              __TR.tDynamic,
            ]),
          ]),
          false,
          (o) => o!.withOptional,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          const <__PR>[__PR(__TR.tInt, 'id', true, false)],
          null,
          null,
        );
      case 'withnamednoresponse':
        return MethodReflection<RawHandlerModule, Map<dynamic, dynamic>>(
          this,
          RawHandlerModule,
          'withNamedNoResponse',
          const __TR<Map<dynamic, dynamic>>(Map, <__TR>[
            __TR.tDynamic,
            __TR.tDynamic,
          ]),
          false,
          (o) => o!.withNamedNoResponse,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
        );
      case 'withcredential':
        return MethodReflection<
          RawHandlerModule,
          APIResponse<Map<dynamic, dynamic>>
        >(
          this,
          RawHandlerModule,
          'withCredential',
          const __TR<APIResponse<Map>>(APIResponse, <__TR>[
            __TR<Map<dynamic, dynamic>>(Map, <__TR>[
              __TR.tDynamic,
              __TR.tDynamic,
            ]),
          ]),
          false,
          (o) => o!.withCredential,
          obj,
          const <__PR>[
            __PR(__TR<APICredential>(APICredential), 'credential', true, true),
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          const <String, __PR>{
            'establishmentId': __PR(__TR.tInt, 'establishmentId', false, true),
          },
          null,
        );
      case 'addcronjob':
        return MethodReflection<RawHandlerModule, void>(
          this,
          APIModule,
          'addCronJob',
          __TR.tVoid,
          false,
          (o) => o!.addCronJob,
          obj,
          const <__PR>[__PR(__TR<APICronJob>(APICronJob), 'job', false, true)],
          null,
          null,
          null,
        );
      case 'ensureconfigured':
        return MethodReflection<RawHandlerModule, void>(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<InitializationResult>
        >(
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
        return MethodReflection<RawHandlerModule, Iterable<String>>(
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
        return MethodReflection<RawHandlerModule, APIModule>(
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
        return MethodReflection<RawHandlerModule, APIModule>(
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
        return MethodReflection<RawHandlerModule, APIRouteHandler<dynamic>?>(
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
        return MethodReflection<RawHandlerModule, APIRouteHandler<dynamic>?>(
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
        return MethodReflection<RawHandlerModule, String>(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<APIResponse<dynamic>>
        >(
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
        return MethodReflection<RawHandlerModule, bool>(
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
        return MethodReflection<RawHandlerModule, APIModuleInfo>(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<InitializationResult>
        >(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<InitializationResult>
        >(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<InitializationResult>
        >(
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
        return MethodReflection<
          RawHandlerModule,
          FutureOr<List<Initializable>>
        >(
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
        return MethodReflection<RawHandlerModule, void>(
          this,
          Initializable,
          'checkInitialized',
          __TR.tVoid,
          false,
          (o) => o!.checkInitialized,
          obj,
          null,
          null,
          const <String, __PR>{
            'allowInProgress': __PR(
              __TR.tBool,
              'allowInProgress',
              false,
              false,
              true,
            ),
          },
          null,
        );
      case 'executeinitialized':
        return MethodReflection<RawHandlerModule, FutureOr<dynamic>>(
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
  StaticMethodReflection<RawHandlerModule, R>? staticMethod<R>(
    String methodName,
  ) => null;
}

extension RawHandlerModule$reflectionExtension on RawHandlerModule {
  /// Returns a [ClassReflection] for type [RawHandlerModule]. (Generated by [ReflectionFactory])
  ClassReflection<RawHandlerModule> get reflection =>
      RawHandlerModule$reflection(this);

  /// Returns a JSON for type [RawHandlerModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [RawHandlerModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [RawHandlerModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [RawHandlerModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension RawHandlerModuleProxy$reflectionProxy on RawHandlerModuleProxy {
  Future<Map> raw() {
    var ret = onCall(
      this,
      'raw',
      <String, dynamic>{},
      const __TR<Future<Map>>(Future, <__TR>[
        __TR<Map<dynamic, dynamic>>(Map, <__TR>[__TR.tDynamic, __TR.tDynamic]),
      ]),
    );
    return __retFut$<Map>(ret);
  }

  Future<String> rawNoResponse() {
    var ret = onCall(
      this,
      'rawNoResponse',
      <String, dynamic>{},
      __TR.tFutureString,
    );
    return __retFut$<String>(ret);
  }

  Future<Map> withNamed({
    required int establishmentId,
    int? otherId,
    String label = 'def',
  }) {
    var ret = onCall(
      this,
      'withNamed',
      <String, dynamic>{
        'establishmentId': establishmentId,
        'otherId': otherId,
        'label': label,
      },
      const __TR<Future<Map>>(Future, <__TR>[
        __TR<Map<dynamic, dynamic>>(Map, <__TR>[__TR.tDynamic, __TR.tDynamic]),
      ]),
    );
    return __retFut$<Map>(ret);
  }

  Future<Map> withOptional([int? id]) {
    var ret = onCall(
      this,
      'withOptional',
      <String, dynamic>{'id': id},
      const __TR<Future<Map>>(Future, <__TR>[
        __TR<Map<dynamic, dynamic>>(Map, <__TR>[__TR.tDynamic, __TR.tDynamic]),
      ]),
    );
    return __retFut$<Map>(ret);
  }

  Future<Map> withNamedNoResponse({int? id}) {
    var ret = onCall(
      this,
      'withNamedNoResponse',
      <String, dynamic>{'id': id},
      const __TR<Future<Map>>(Future, <__TR>[
        __TR<Map<dynamic, dynamic>>(Map, <__TR>[__TR.tDynamic, __TR.tDynamic]),
      ]),
    );
    return __retFut$<Map>(ret);
  }

  Future<Map> withCredential({required int establishmentId}) {
    var ret = onCall(
      this,
      'withCredential',
      <String, dynamic>{'establishmentId': establishmentId},
      const __TR<Future<Map>>(Future, <__TR>[
        __TR<Map<dynamic, dynamic>>(Map, <__TR>[__TR.tDynamic, __TR.tDynamic]),
      ]),
    );
    return __retFut$<Map>(ret);
  }
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  RawHandlerModule$reflection(),
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
