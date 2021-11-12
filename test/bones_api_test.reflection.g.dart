//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.0.19
// BUILD COMMAND: dart run build_runner build
//

// ignore_for_file: unnecessary_const

part of 'bones_api_test.dart';

// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJson(Map<String, Object?> map) =>
    MyInfoModule$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
MyInfoModule MyInfoModule$fromJsonEncoded(String jsonEncoded) =>
    MyInfoModule$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class MyInfoModule$reflection extends ClassReflection<MyInfoModule> {
  MyInfoModule$reflection([MyInfoModule? object]) : super(MyInfoModule, object);

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
  Version get languageVersion => Version.parse('2.13.0');

  @override
  Version get reflectionFactoryVersion => Version.parse('1.0.19');

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
  Object? callMethodToJson([MyInfoModule? obj]) => null;

  @override
  List<String> get fieldsNames => const <String>[
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
  FieldReflection<MyInfoModule, T>? field<T>(String fieldName,
      [MyInfoModule? obj]) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'apiroot':
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
      case 'routes':
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
        return FieldReflection<MyInfoModule, T>(
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
  FieldReflection<MyInfoModule, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames => const <String>[
        'addRoute',
        'apiInfo',
        'call',
        'configure',
        'echo',
        'getRouteHandler',
        'getRouteHandlerByRequest',
        'resolveRoute'
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
            null,
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
            TypeReflection(FutureOr, [
              TypeReflection(APIResponse, [dynamic])
            ]),
            false,
            (o) => o!.echo,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'msg', false, true, null, null),
              ParameterReflection(TypeReflection(APIRequest), 'request', false,
                  true, null, null)
            ],
            null,
            null,
            null);
      case 'addroute':
        return MethodReflection<MyInfoModule, R>(
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
              ParameterReflection(
                  TypeReflection.tFunction, 'function', false, true, null, null)
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
        return MethodReflection<MyInfoModule, R>(
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
  MethodReflection<MyInfoModule, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

extension MyInfoModule$reflectionExtension on MyInfoModule {
  /// Returns a [ClassReflection] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  ClassReflection<MyInfoModule> get reflection => MyInfoModule$reflection(this);

  /// Returns a JSON for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Object? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [MyInfoModule]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);

  /// Returns a JSON for type [MyInfoModule] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields() => reflection.toJsonFromFields();
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
