//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.0.24
// BUILD COMMAND: dart run build_runner build
//

// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_test_modules.dart';

// ignore: non_constant_identifier_names
UserModule UserModule$fromJson(Map<String, Object?> map) =>
    UserModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
UserModule UserModule$fromJsonEncoded(String jsonEncoded) =>
    UserModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class UserModule$reflection extends ClassReflection<UserModule> {
  UserModule$reflection([UserModule? object]) : super(UserModule, object);

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
  Version get languageVersion => Version.parse('2.14.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.0.24');

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
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection(APIRoot), 'apiRoot', false, true, null, null)
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
  List<Type> get supperTypes => const <Type>[APIModule];

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
          TypeReflection(APIRoot),
          'apiRoot',
          false,
          (o) => () => o!.apiRoot as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'name':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'name',
          false,
          (o) => () => o!.name as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'version':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'version',
          true,
          (o) => () => o!.version as T,
          null,
          obj,
          false,
          true,
          null,
        );
      case 'apiconfig':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection(APIConfig),
          'apiConfig',
          false,
          (o) => () => o!.apiConfig as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'defaultroutename':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'defaultRouteName',
          true,
          (o) => () => o!.defaultRouteName as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'allroutesnames':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection.tSetString,
          'allRoutesNames',
          false,
          (o) => () => o!.allRoutesNames as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'routes':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection(APIRouteBuilder, [APIModule]),
          'routes',
          false,
          (o) => () => o!.routes as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'authenticationroute':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection.tString,
          'authenticationRoute',
          false,
          (o) => () => o!.authenticationRoute as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'security':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
          TypeReflection(APISecurity),
          'security',
          true,
          (o) => () => o!.security as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<UserModule, T>(
          this,
          APIModule,
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
        'addRoute',
        'apiInfo',
        'call',
        'configure',
        'ensureConfigured',
        'geDynamicAsync',
        'geDynamicAsync2',
        'getDynamic',
        'getRouteHandler',
        'getRouteHandlerByRequest',
        'getRoutesHandlersNames',
        'getUser',
        'getUserAsync',
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
            TypeReflection.tVoid,
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
            TypeReflection.tString,
            false,
            (o) => o!.notARoute,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'n', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'notarouteasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'notARouteAsync',
            TypeReflection.tFutureString,
            false,
            (o) => o!.notARouteAsync,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'n', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'getuser':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getUser',
            TypeReflection(APIResponse, [User]),
            false,
            (o) => o!.getUser,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'getdynamic':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getDynamic',
            TypeReflection(APIResponse, [dynamic]),
            false,
            (o) => o!.getDynamic,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'getuserasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'getUserAsync',
            TypeReflection(Future, [
              TypeReflection(APIResponse, [User])
            ]),
            false,
            (o) => o!.getUserAsync,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'gedynamicasync':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'geDynamicAsync',
            TypeReflection(Future, [
              TypeReflection(APIResponse, [dynamic])
            ]),
            false,
            (o) => o!.geDynamicAsync,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'gedynamicasync2':
        return MethodReflection<UserModule, R>(
            this,
            UserModule,
            'geDynamicAsync2',
            TypeReflection.tFutureDynamic,
            false,
            (o) => o!.geDynamicAsync2,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tInt, 'id', false, true, null, null)
            ],
            null,
            null,
            null);
      case 'ensureconfigured':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'ensureConfigured',
            TypeReflection.tVoid,
            false,
            (o) => o!.ensureConfigured,
            obj,
            false,
            null,
            null,
            null,
            null);
      case 'getrouteshandlersnames':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRoutesHandlersNames',
            TypeReflection(Iterable, [String]),
            false,
            (o) => o!.getRoutesHandlersNames,
            obj,
            false,
            null,
            null,
            const <String, ParameterReflection>{
              'method': ParameterReflection(TypeReflection(APIRequestMethod),
                  'method', true, false, null, null)
            },
            null);
      case 'addroute':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'addRoute',
            TypeReflection(APIModule),
            false,
            (o) => o!.addRoute,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequestMethod), 'method',
                  true, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'name', false, true, null, null),
              ParameterReflection(TypeReflection(APIRouteFunction, [dynamic]),
                  'function', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'parameters': ParameterReflection(
                  TypeReflection(Map, [String, TypeInfo]),
                  'parameters',
                  true,
                  false,
                  null,
                  null),
              'rules': ParameterReflection(
                  TypeReflection(Iterable, [APIRouteRule]),
                  'rules',
                  true,
                  false,
                  null,
                  null)
            },
            null);
      case 'getroutehandler':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRouteHandler',
            TypeReflection(APIRouteHandler, [dynamic]),
            true,
            (o) => o!.getRouteHandler,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'name', false, true, null, null)
            ],
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequestMethod), 'method',
                  true, false, null, null)
            ],
            null,
            null);
      case 'getroutehandlerbyrequest':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'getRouteHandlerByRequest',
            TypeReflection(APIRouteHandler, [dynamic]),
            true,
            (o) => o!.getRouteHandlerByRequest,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'resolveroute':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'resolveRoute',
            TypeReflection.tString,
            false,
            (o) => o!.resolveRoute,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'call':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'call',
            TypeReflection(FutureOr, [
              TypeReflection(APIResponse, [dynamic])
            ]),
            false,
            (o) => o!.call,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'apiinfo':
        return MethodReflection<UserModule, R>(
            this,
            APIModule,
            'apiInfo',
            TypeReflection(APIModuleInfo),
            false,
            (o) => o!.apiInfo,
            obj,
            false,
            null,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection(APIRequest), 'apiRequest',
                  true, false, null, null)
            ],
            null,
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

extension UserModule$reflectionExtension on UserModule {
  /// Returns a [ClassReflection] for type [UserModule]. (Generated by [ReflectionFactory])
  ClassReflection<UserModule> get reflection => UserModule$reflection(this);

  /// Returns a JSON for type [UserModule]. (Generated by [ReflectionFactory])
  Object? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [UserModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [UserModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);

  /// Returns a JSON for type [UserModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields() => reflection.toJsonFromFields();
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
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
