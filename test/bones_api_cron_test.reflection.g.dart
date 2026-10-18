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

part of 'bones_api_cron_test.dart';

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

// ignore: non_constant_identifier_names
CronReflectedModule CronReflectedModule$fromJson(Map<String, Object?> map) =>
    CronReflectedModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
CronReflectedModule CronReflectedModule$fromJsonEncoded(String jsonEncoded) =>
    CronReflectedModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class CronReflectedModule$reflection
    extends ClassReflection<CronReflectedModule>
    with __ReflectionMixin {
  static final Expando<CronReflectedModule$reflection> _objectReflections =
      Expando();

  factory CronReflectedModule$reflection([CronReflectedModule? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= CronReflectedModule$reflection._(
      object,
    );
  }

  CronReflectedModule$reflection._([CronReflectedModule? object])
    : super(CronReflectedModule, r'CronReflectedModule', object);

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
  CronReflectedModule$reflection withObject([CronReflectedModule? obj]) =>
      CronReflectedModule$reflection(obj)..setupInternalsWith(this);

  static CronReflectedModule$reflection? _withoutObjectInstance;
  @override
  CronReflectedModule$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static CronReflectedModule$reflection get staticInstance =>
      _withoutObjectInstance ??= CronReflectedModule$reflection._();

  @override
  CronReflectedModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    CronReflectedModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  CronReflectedModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  CronReflectedModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  CronReflectedModule? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<CronReflectedModule>>
  _constructors = {};

  @override
  ConstructorReflection<CronReflectedModule>? constructor(
    String constructorName,
  ) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<CronReflectedModule>? _constructorImpl(
    String constructorName,
  ) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<CronReflectedModule>(
          this,
          CronReflectedModule,
          '',
          () => CronReflectedModule.new,
          const <__PR>[__PR(__TR<APIRoot>(APIRoot), 'apiRoot', false, true)],
          null,
          null,
          null,
          invoker: (a) => CronReflectedModule(a[0] as APIRoot),
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
  Object? callMethodToJson([CronReflectedModule? obj]) => null;

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

  static final Map<String, FieldReflection<CronReflectedModule, dynamic>>
  _fieldsNoObject = {};

  final Map<String, FieldReflection<CronReflectedModule, dynamic>>
  _fieldsObject = {};

  @override
  FieldReflection<CronReflectedModule, T>? field<T>(
    String fieldName, [
    CronReflectedModule? obj,
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

  FieldReflection<CronReflectedModule, T>? _fieldNoObjectImpl<T>(
    String fieldName,
  ) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<CronReflectedModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<CronReflectedModule, T>;
  }

  FieldReflection<CronReflectedModule, T>? _fieldObjectImpl<T>(
    String fieldName,
  ) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<CronReflectedModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<CronReflectedModule, dynamic>? _fieldImpl(
    String fieldName,
    CronReflectedModule? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<CronReflectedModule, APIRoot>(
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
        return FieldReflection<CronReflectedModule, String>(
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
        return FieldReflection<CronReflectedModule, String?>(
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
        return FieldReflection<CronReflectedModule, APIConfig>(
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
        return FieldReflection<CronReflectedModule, String?>(
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
        return FieldReflection<CronReflectedModule, List<APICronJob>>(
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
        return FieldReflection<CronReflectedModule, Set<String>>(
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
        return FieldReflection<CronReflectedModule, APIRouteBuilder<APIModule>>(
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
        return FieldReflection<CronReflectedModule, String>(
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
        return FieldReflection<CronReflectedModule, APISecurity?>(
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
        return FieldReflection<CronReflectedModule, int>(
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
        return FieldReflection<CronReflectedModule, InitializationStatus>(
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
        return FieldReflection<CronReflectedModule, bool>(
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
        return FieldReflection<CronReflectedModule, bool>(
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
        return FieldReflection<CronReflectedModule, bool>(
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
        return FieldReflection<CronReflectedModule, List<Initializable>>(
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
    CronReflectedModule? obj, {
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
  StaticFieldReflection<CronReflectedModule, T>? staticField<T>(
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
    'notScheduled',
    'refresh',
    'report',
    'resolveRoute',
    'workHours',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<CronReflectedModule, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<CronReflectedModule, dynamic>>
  _methodsObject = {};

  @override
  MethodReflection<CronReflectedModule, R>? method<R>(
    String methodName, [
    CronReflectedModule? obj,
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

  MethodReflection<CronReflectedModule, R>? _methodNoObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<CronReflectedModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<CronReflectedModule, R>;
  }

  MethodReflection<CronReflectedModule, R>? _methodObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<CronReflectedModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<CronReflectedModule, dynamic>? _methodImpl(
    String methodName,
    CronReflectedModule? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<CronReflectedModule, void>(
          this,
          CronReflectedModule,
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
      case 'refresh':
        return MethodReflection<CronReflectedModule, APIResponse<String>>(
          this,
          CronReflectedModule,
          'refresh',
          const __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
          false,
          (o) => o!.refresh,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          const [APICron('*/5 * * * *', timeZone: 'Europe/Paris', maxCalls: 7)],
        );
      case 'report':
        return MethodReflection<CronReflectedModule, APIResponse<String>>(
          this,
          CronReflectedModule,
          'report',
          const __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
          false,
          (o) => o!.report,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          const [
            APICron(
              '0 1 * * *',
              name: 'daily-report',
              parameters: {'kind': 'daily'},
              timeout: Duration(minutes: 2),
              maxLateness: Duration(hours: 6),
              leaseDuration: Duration(minutes: 10),
              retry: APICronRetry(
                attempts: 4,
                initialDelay: Duration(minutes: 1),
              ),
            ),
          ],
        );
      case 'workhours':
        return MethodReflection<CronReflectedModule, APIResponse<String>>(
          this,
          CronReflectedModule,
          'workHours',
          const __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
          false,
          (o) => o!.workHours,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          const [
            APICron.at(
              minute: '*/15',
              hour: '9-18',
              dayOfWeek: 'MON-FRI',
              timeZone: 'America/Sao_Paulo',
              attempts: 2,
              retry: APICronRetry(
                attempts: 5,
                initialDelay: Duration(seconds: 10),
              ),
            ),
          ],
        );
      case 'notscheduled':
        return MethodReflection<CronReflectedModule, APIResponse<String>>(
          this,
          CronReflectedModule,
          'notScheduled',
          const __TR<APIResponse<String>>(APIResponse, <__TR>[__TR.tString]),
          false,
          (o) => o!.notScheduled,
          obj,
          const <__PR>[
            __PR(__TR<APIRequest>(APIRequest), 'request', false, true),
          ],
          null,
          null,
          null,
        );
      case 'addcronjob':
        return MethodReflection<CronReflectedModule, void>(
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
        return MethodReflection<CronReflectedModule, void>(
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
          CronReflectedModule,
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
        return MethodReflection<CronReflectedModule, Iterable<String>>(
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
        return MethodReflection<CronReflectedModule, APIModule>(
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
        return MethodReflection<CronReflectedModule, APIModule>(
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
        return MethodReflection<CronReflectedModule, APIRouteHandler<dynamic>?>(
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
        return MethodReflection<CronReflectedModule, APIRouteHandler<dynamic>?>(
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
        return MethodReflection<CronReflectedModule, String>(
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
          CronReflectedModule,
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
        return MethodReflection<CronReflectedModule, bool>(
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
        return MethodReflection<CronReflectedModule, APIModuleInfo>(
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
          CronReflectedModule,
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
          CronReflectedModule,
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
          CronReflectedModule,
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
          CronReflectedModule,
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
        return MethodReflection<CronReflectedModule, void>(
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
        return MethodReflection<CronReflectedModule, FutureOr<dynamic>>(
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
  StaticMethodReflection<CronReflectedModule, R>? staticMethod<R>(
    String methodName,
  ) => null;
}

extension CronReflectedModule$reflectionExtension on CronReflectedModule {
  /// Returns a [ClassReflection] for type [CronReflectedModule]. (Generated by [ReflectionFactory])
  ClassReflection<CronReflectedModule> get reflection =>
      CronReflectedModule$reflection(this);

  /// Returns a JSON for type [CronReflectedModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [CronReflectedModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [CronReflectedModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [CronReflectedModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  CronReflectedModule$reflection(),
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
