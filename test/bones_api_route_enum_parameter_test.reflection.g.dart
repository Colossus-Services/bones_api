//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.10.0
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

part of 'bones_api_route_enum_parameter_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.10.0');

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

// ignore: non_constant_identifier_names
Currency? Currency$from(Object? o) =>
    Currency$reflection.staticInstance.from(o);
// ignore: non_constant_identifier_names
ExternalIntegrationModule ExternalIntegrationModule$fromJson(
  Map<String, Object?> map,
) => ExternalIntegrationModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
ExternalIntegrationModule ExternalIntegrationModule$fromJsonEncoded(
  String jsonEncoded,
) => ExternalIntegrationModule$reflection.staticInstance.fromJsonEncoded(
  jsonEncoded,
);
// ignore: non_constant_identifier_names
PaymentType? PaymentType$from(Object? o) =>
    PaymentType$reflection.staticInstance.from(o);

class Currency$reflection extends EnumReflection<Currency>
    with __ReflectionMixin {
  static final Expando<Currency$reflection> _objectReflections = Expando();

  factory Currency$reflection([Currency? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Currency$reflection._(object);
  }

  Currency$reflection._([Currency? object])
    : super(Currency, r'Currency', object);

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
  Currency$reflection withObject([Currency? obj]) => Currency$reflection(obj);

  static Currency$reflection? _withoutObjectInstance;
  @override
  Currency$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Currency$reflection get staticInstance =>
      _withoutObjectInstance ??= Currency$reflection._();

  @override
  Currency$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Currency$reflection.staticInstance;
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<String> _staticFieldsNames = const <String>[
    'brl',
    'eur',
    'usd',
  ];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  static const Map<String, Currency> _valuesByName = const <String, Currency>{
    'brl': Currency.brl,
    'eur': Currency.eur,
    'usd': Currency.usd,
  };

  @override
  Map<String, Currency> get valuesByName => _valuesByName;
  @override
  List<Currency> get values => Currency.values;

  static const List<String> _fieldsNames = const <String>[];

  @override
  List<String> get fieldsNames => _fieldsNames;
}

class ExternalIntegrationModule$reflection
    extends ClassReflection<ExternalIntegrationModule>
    with __ReflectionMixin {
  static final Expando<ExternalIntegrationModule$reflection>
  _objectReflections = Expando();

  factory ExternalIntegrationModule$reflection([
    ExternalIntegrationModule? object,
  ]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??=
        ExternalIntegrationModule$reflection._(object);
  }

  ExternalIntegrationModule$reflection._([ExternalIntegrationModule? object])
    : super(ExternalIntegrationModule, r'ExternalIntegrationModule', object);

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
  ExternalIntegrationModule$reflection withObject([
    ExternalIntegrationModule? obj,
  ]) => ExternalIntegrationModule$reflection(obj)..setupInternalsWith(this);

  static ExternalIntegrationModule$reflection? _withoutObjectInstance;
  @override
  ExternalIntegrationModule$reflection withoutObjectInstance() =>
      staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static ExternalIntegrationModule$reflection get staticInstance =>
      _withoutObjectInstance ??= ExternalIntegrationModule$reflection._();

  @override
  ExternalIntegrationModule$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    ExternalIntegrationModule$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  ExternalIntegrationModule? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  ExternalIntegrationModule? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  ExternalIntegrationModule? createInstanceWithNoRequiredArgsConstructor() =>
      null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<ExternalIntegrationModule>>
  _constructors = {};

  @override
  ConstructorReflection<ExternalIntegrationModule>? constructor(
    String constructorName,
  ) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<ExternalIntegrationModule>? _constructorImpl(
    String constructorName,
  ) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<ExternalIntegrationModule>(
          this,
          ExternalIntegrationModule,
          '',
          () => ExternalIntegrationModule.new,
          const <__PR>[__PR(__TR<APIRoot>(APIRoot), 'apiRoot', false, true)],
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
  Object? callMethodToJson([ExternalIntegrationModule? obj]) => null;

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
    'version',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<ExternalIntegrationModule, dynamic>>
  _fieldsNoObject = {};

  final Map<String, FieldReflection<ExternalIntegrationModule, dynamic>>
  _fieldsObject = {};

  @override
  FieldReflection<ExternalIntegrationModule, T>? field<T>(
    String fieldName, [
    ExternalIntegrationModule? obj,
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

  FieldReflection<ExternalIntegrationModule, T>? _fieldNoObjectImpl<T>(
    String fieldName,
  ) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<ExternalIntegrationModule, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<ExternalIntegrationModule, T>;
  }

  FieldReflection<ExternalIntegrationModule, T>? _fieldObjectImpl<T>(
    String fieldName,
  ) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<ExternalIntegrationModule, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<ExternalIntegrationModule, dynamic>? _fieldImpl(
    String fieldName,
    ExternalIntegrationModule? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<ExternalIntegrationModule, APIRoot>(
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
        return FieldReflection<ExternalIntegrationModule, String>(
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
        return FieldReflection<ExternalIntegrationModule, String?>(
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
        return FieldReflection<ExternalIntegrationModule, APIConfig>(
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
        return FieldReflection<ExternalIntegrationModule, String?>(
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
        return FieldReflection<ExternalIntegrationModule, Set<String>>(
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
        return FieldReflection<
          ExternalIntegrationModule,
          APIRouteBuilder<APIModule>
        >(
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
        return FieldReflection<ExternalIntegrationModule, String>(
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
        return FieldReflection<ExternalIntegrationModule, APISecurity?>(
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
        return FieldReflection<ExternalIntegrationModule, int>(
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
        return FieldReflection<ExternalIntegrationModule, InitializationStatus>(
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
        return FieldReflection<ExternalIntegrationModule, bool>(
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
        return FieldReflection<ExternalIntegrationModule, bool>(
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
        return FieldReflection<ExternalIntegrationModule, bool>(
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
    ExternalIntegrationModule? obj, {
    bool withHashCode = false,
  }) {
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
  StaticFieldReflection<ExternalIntegrationModule, T>? staticField<T>(
    String fieldName,
  ) => null;

  static const List<String> _methodsNames = const <String>[
    'acceptsRequest',
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
    'resolveRoute',
    'updateOrderStatusFromBroker',
  ];

  @override
  List<String> get methodsNames => _methodsNames;

  static final Map<String, MethodReflection<ExternalIntegrationModule, dynamic>>
  _methodsNoObject = {};

  final Map<String, MethodReflection<ExternalIntegrationModule, dynamic>>
  _methodsObject = {};

  @override
  MethodReflection<ExternalIntegrationModule, R>? method<R>(
    String methodName, [
    ExternalIntegrationModule? obj,
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

  MethodReflection<ExternalIntegrationModule, R>? _methodNoObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsNoObject[methodName];
    if (m != null) {
      return m as MethodReflection<ExternalIntegrationModule, R>;
    }
    final m2 = _methodImpl(methodName, null);
    if (m2 == null) return null;
    _methodsNoObject[methodName] = m2;
    return m2 as MethodReflection<ExternalIntegrationModule, R>;
  }

  MethodReflection<ExternalIntegrationModule, R>? _methodObjectImpl<R>(
    String methodName,
  ) {
    final m = _methodsObject[methodName];
    if (m != null) {
      return m as MethodReflection<ExternalIntegrationModule, R>;
    }
    var m2 = _methodNoObjectImpl<R>(methodName);
    if (m2 == null) return null;
    m2 = m2.withObject(object!);
    _methodsObject[methodName] = m2;
    return m2;
  }

  MethodReflection<ExternalIntegrationModule, dynamic>? _methodImpl(
    String methodName,
    ExternalIntegrationModule? obj,
  ) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'configure':
        return MethodReflection<ExternalIntegrationModule, void>(
          this,
          ExternalIntegrationModule,
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
      case 'updateorderstatusfrombroker':
        return MethodReflection<
          ExternalIntegrationModule,
          APIResponse<Map<dynamic, dynamic>>
        >(
          this,
          ExternalIntegrationModule,
          'updateOrderStatusFromBroker',
          const __TR<APIResponse<Map>>(APIResponse, <__TR>[
            __TR<Map<dynamic, dynamic>>(Map, <__TR>[
              __TR.tDynamic,
              __TR.tDynamic,
            ]),
          ]),
          false,
          (o) => o!.updateOrderStatusFromBroker,
          obj,
          const <__PR>[
            __PR(__TR.tInt, 'orderId', false, true),
            __PR(__TR.tString, 'status', false, true),
            __PR(__TR.tBool, 'paid', false, true),
            __PR(__TR<PaymentType>(PaymentType), 'paymentType', true, true),
            __PR(__TR<Currency>(Currency), 'chargedCurrency', true, true),
            __PR(__TR.tDouble, 'chargedPrice', true, true),
          ],
          null,
          null,
          null,
        );
      case 'ensureconfigured':
        return MethodReflection<ExternalIntegrationModule, void>(
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
          ExternalIntegrationModule,
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
        return MethodReflection<ExternalIntegrationModule, Iterable<String>>(
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
        return MethodReflection<ExternalIntegrationModule, APIModule>(
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
        return MethodReflection<ExternalIntegrationModule, APIModule>(
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
        return MethodReflection<
          ExternalIntegrationModule,
          APIRouteHandler<dynamic>?
        >(
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
        return MethodReflection<
          ExternalIntegrationModule,
          APIRouteHandler<dynamic>?
        >(
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
        return MethodReflection<ExternalIntegrationModule, String>(
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
          ExternalIntegrationModule,
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
        return MethodReflection<ExternalIntegrationModule, bool>(
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
        return MethodReflection<ExternalIntegrationModule, APIModuleInfo>(
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
          ExternalIntegrationModule,
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
          ExternalIntegrationModule,
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
          ExternalIntegrationModule,
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
          ExternalIntegrationModule,
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
        return MethodReflection<ExternalIntegrationModule, void>(
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
        return MethodReflection<ExternalIntegrationModule, FutureOr<dynamic>>(
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
  StaticMethodReflection<ExternalIntegrationModule, R>? staticMethod<R>(
    String methodName,
  ) => null;
}

class PaymentType$reflection extends EnumReflection<PaymentType>
    with __ReflectionMixin {
  static final Expando<PaymentType$reflection> _objectReflections = Expando();

  factory PaymentType$reflection([PaymentType? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= PaymentType$reflection._(object);
  }

  PaymentType$reflection._([PaymentType? object])
    : super(PaymentType, r'PaymentType', object);

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
  PaymentType$reflection withObject([PaymentType? obj]) =>
      PaymentType$reflection(obj);

  static PaymentType$reflection? _withoutObjectInstance;
  @override
  PaymentType$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static PaymentType$reflection get staticInstance =>
      _withoutObjectInstance ??= PaymentType$reflection._();

  @override
  PaymentType$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    PaymentType$reflection.staticInstance;
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<String> _staticFieldsNames = const <String>[
    'creditCard',
    'debitCard',
    'pix',
  ];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  static const Map<String, PaymentType> _valuesByName =
      const <String, PaymentType>{
        'creditCard': PaymentType.creditCard,
        'debitCard': PaymentType.debitCard,
        'pix': PaymentType.pix,
      };

  @override
  Map<String, PaymentType> get valuesByName => _valuesByName;
  @override
  List<PaymentType> get values => PaymentType.values;

  static const List<String> _fieldsNames = const <String>[];

  @override
  List<String> get fieldsNames => _fieldsNames;
}

extension Currency$reflectionExtension on Currency {
  /// Returns a [EnumReflection] for type [Currency]. (Generated by [ReflectionFactory])
  EnumReflection<Currency> get reflection => Currency$reflection(this);

  /// Returns the name of the [Currency] instance. (Generated by [ReflectionFactory])
  String get enumName => Currency$reflection(this).name()!;

  /// Returns a JSON for type [Currency]. (Generated by [ReflectionFactory])
  String? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [Currency]. (Generated by [ReflectionFactory])
  Map<String, Object>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [Currency]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);
}

extension ExternalIntegrationModule$reflectionExtension
    on ExternalIntegrationModule {
  /// Returns a [ClassReflection] for type [ExternalIntegrationModule]. (Generated by [ReflectionFactory])
  ClassReflection<ExternalIntegrationModule> get reflection =>
      ExternalIntegrationModule$reflection(this);

  /// Returns a JSON for type [ExternalIntegrationModule]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [ExternalIntegrationModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [ExternalIntegrationModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [ExternalIntegrationModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension PaymentType$reflectionExtension on PaymentType {
  /// Returns a [EnumReflection] for type [PaymentType]. (Generated by [ReflectionFactory])
  EnumReflection<PaymentType> get reflection => PaymentType$reflection(this);

  /// Returns the name of the [PaymentType] instance. (Generated by [ReflectionFactory])
  String get enumName => PaymentType$reflection(this).name()!;

  /// Returns a JSON for type [PaymentType]. (Generated by [ReflectionFactory])
  String? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [PaymentType]. (Generated by [ReflectionFactory])
  Map<String, Object>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [PaymentType]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  Currency$reflection(),
  ExternalIntegrationModule$reflection(),
  PaymentType$reflection(),
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
