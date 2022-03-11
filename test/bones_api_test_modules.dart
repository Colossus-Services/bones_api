import 'package:bones_api/bones_api.dart';

import 'bones_api_test_entities.dart';

part 'bones_api_test_modules.reflection.g.dart';

class TestAPIRoot extends APIRoot {
  TestAPIRoot() : super('Test', '1.0');

  @override
  Set<APIModule> loadModules() => {UserModule(this)};
}

@EnableReflection()
class UserModule extends APIModule {
  UserModule(APIRoot apiRoot) : super(apiRoot, 'user');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  String notARoute(int n) => 'foo';

  Future<String> notARouteAsync(int n) async => 'foo';

  APIResponse<User> getUser(int id) => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  APIResponse getDynamic(int id) => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse<User>> getUserAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse> geDynamicAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<dynamic> geDynamicAsync2(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));
}
