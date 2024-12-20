import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';

import 'bones_api_test_entities.dart';

part 'bones_api_test_modules.reflection.g.dart';

class TestAPIRoot extends APIRoot {
  TestAPIRoot({super.apiConfig}) : super('Test', '1.0');

  @override
  Set<APIModule> loadModules() => {AboutModule(this), UserModule(this)};
}

@EnableReflection()
class AboutModule extends APIModule {
  AboutModule(APIRoot apiRoot) : super(apiRoot, 'about');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  APIResponse<String> about() => APIResponse.ok('About...');
}

bool _blockUserEmailCondition(EntityAccessRulesContext? c) =>
    c?.objectAs<User>()?.email.contains('secret') ?? false;

@APIEntityAccessRules(EntityAccessRules.blockFields(User, ['email'],
    condition: _blockUserEmailCondition))
@APIEntityResolutionRules(EntityResolutionRules.fetchEager([User]))
@EnableReflection()
class UserModule extends APIModule {
  UserModule(APIRoot apiRoot) : super(apiRoot, 'user');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  String notARoute(int n) => 'foo';

  Future<String> notARouteAsync(int n) async => 'foo';

  APIResponse<User> getUser(int id) => APIResponse.ok(User(
      'joe@email.com', 'pass123', Address('SC', 'NY', '', 123), [],
      creationTime: DateTime.utc(2021, 10, 11, 12, 13, 14)));

  APIResponse<User> echoUser(User user) =>
      APIResponse.ok(user..email += '.echo');

  APIResponse<List<User>> echoListUser(List<User> users) => APIResponse.ok(
      users.mapIndexed((i, e) => e..email += '.echo[$i]').toList());

  APIResponse<List<User>> echoListUser2(String msg, List<User> users) =>
      APIResponse.ok(
          users.mapIndexed((i, e) => e..email += '.echo[$i]{$msg}').toList());

  APIResponse getDynamic(int id) => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse<User>> getUserAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse> geDynamicAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<dynamic> geDynamicAsync2(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse<Map>> getContextEntityResolutionRules() async {
    var contextProvider = EntityRulesResolver.cotextProviders.first;
    var resolutionRules = contextProvider.getContextEntityResolutionRules();
    return APIResponse.ok(
        {'context.resolutionRules': resolutionRules?.toJson()});
  }

  Future<APIResponse<Map>> getRequestEntityResolutionRules(
      APIRequest request) async {
    var routeHandler = request.routeHandler;
    var resolutionRules = routeHandler?.entityResolutionRules;
    return APIResponse.ok({'resolutionRules': resolutionRules?.toJson()});
  }

  Future<APIResponse<Map>> getRequestEntityAccessRules(
      APIRequest request) async {
    var routeHandler = request.routeHandler;
    var accessRules = routeHandler?.entityAccessRules;
    return APIResponse.ok({'accessRules': accessRules?.toJson()});
  }

  Future<APIResponse<String>> returnAPIResponseError(String message) async {
    return APIResponse.error(error: 'Return error: $message');
  }

  Future<APIResponse<String>> throwAPIResponseError(String message) async {
    throw APIResponse.error(error: 'Throw error: $message');
  }

  Future<APIResponse<String>> asyncError(String message) async {
    Future.delayed(Duration(milliseconds: 1), () {
      throw StateError("Async Error!");
    });

    await Future.delayed(Duration(seconds: 1));

    return APIResponse.ok('Message: $message');
  }
}
