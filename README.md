# Bones_API

[![pub package](https://img.shields.io/pub/v/bones_api.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/bones_api)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![CI](https://img.shields.io/github/workflow/status/Colossus-Services/bones_api/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/Colossus-Services/bones_api/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/releases)
[![New Commits](https://img.shields.io/github/commits-since/Colossus-Services/bones_api/latest?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/network)
[![Last Commits](https://img.shields.io/github/last-commit/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api)
[![License](https://img.shields.io/github/license/Colossus-Services/bones_api?logo=open-source-initiative&logoColor=green)](https://github.com/Colossus-Services/bones_api/blob/master/LICENSE)

Bones_API - Simple and easy API framework, with routes and HTTP Server.

## Usage

A simple usage example:

```dart
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_server.dart';

void main() async {
  var api = MyAPI();

  // Calling the API directly:
  var r1 = await api.call(APIRequest.get('/service/base/foo'));
  print(r1);
  
  // Serving the API trough a HTTP Server:
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
```

## CLI

You can use the built-in command-line interface (CLI) `bones_api`.

To activate it globally:

```bash
 $> dart pub global activate bones_api
```

Now tou can use the CLI directly:

```bash
  $> bones_api --help
```

To serve an API project:

```bash
  $> bones_api serve --directory path/to/project --class MyAPIRoot
```

## Bones_UI

See also the package [Bones_UI][bones_ui], a simple and easy Web User Interface Framework for Dart.

[bones_ui]: https://pub.dev/packages/bones_ui

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Colossus-Services/bones_api/issues

## Colossus.Services

This is an open-source project from [Colossus.Services][colossus]:
the gateway for smooth solutions.

## Author

Graciliano M. Passos: [gmpassos@GitHub][gmpassos_github].

## License

[Artistic License - Version 2.0][artistic_license]


[gmpassos_github]: https://github.com/gmpassos
[colossus]: https://colossus.services/
[artistic_license]: https://github.com/Colossus-Services/bones_api/blob/master/LICENSE

