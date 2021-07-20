import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_server.dart';

void main() async {
  var api = MyAPI();

  print(api);

  var r1 = await api.call(APIRequest.get('/service/base/foo'));
  print(r1);

  var r2 = await api
      .call(APIRequest.post('/service/base/foo', parameters: {'a': 1}));
  print(r2);

  var r3 = await api.call(APIRequest.get('/service/base/bar'));
  print(r3);

  var apiServer = APIServer(api, '*', 8088);
  await apiServer.start();

  print('Running: $apiServer');
  print('URL: ${apiServer.url}');
}

class MyAPI extends APIRoot {
  MyAPI() : super('example', '1.0');

  @override
  Set<APIModule> loadModules() => {MyBaseModule()};
}

class MyBaseModule extends APIModule {
  MyBaseModule() : super('base');

  @override
  String? get defaultRouteName => '404';

  @override
  void configure() {
    routes.get('foo', (request) => APIResponse.ok('Hi[GET]!'));
    routes.post(
        'foo', (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'));

    routes.any('time', (request) => APIResponse.ok(DateTime.now()));

    routes.any('404',
        (request) => APIResponse.notFound(payload: '404: ${request.path}'));
  }
}
