# Bones_API

[![pub package](https://img.shields.io/pub/v/bones_api.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/bones_api)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Codecov](https://img.shields.io/codecov/c/github/Colossus-Services/bones_api)](https://app.codecov.io/gh/Colossus-Services/bones_api)
[![Dart CI](https://github.com/Colossus-Services/bones_api/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/Colossus-Services/bones_api/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/releases)
[![New Commits](https://img.shields.io/github/commits-since/Colossus-Services/bones_api/latest?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/network)
[![Last Commits](https://img.shields.io/github/last-commit/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api)
[![License](https://img.shields.io/github/license/Colossus-Services/bones_api?logo=open-source-initiative&logoColor=green)](https://github.com/Colossus-Services/bones_api/blob/master/LICENSE)

Bones_API - A powerful API backend framework for Dart. It comes with a built-in HTTP Server,
route handler, entity handler, SQL translator, and DB adapters.

## Usage

A simple `BTC-USD` API example:

```dart
import 'package:bones_api/bones_api_server.dart';
import 'package:mercury_client/mercury_client.dart';

/// APIs are organized in modules:
class MyBTCModule extends APIModule {
  MyBTCModule(APIRoot apiRoot) : super(apiRoot, 'btc');

  /// The default route for not matching routes:
  @override
  String? get defaultRouteName => '404';

  /// A configuration property from `apiConfig`.
  String get notFoundMsg => apiConfig['not_found_msg'] ?? 'Unknown route!';

  @override
  void configure() {
    routes.get('usd', (request) => fetchBtcUsd());

    routes.any('time', (request) => APIResponse.ok(DateTime.now()));

    routes.any('404', notFound);
  }

  /// A HTTP client for `fetchBtcUsd`:
  static final coinDeskClient = HttpClient("https://api.coindesk.com/v1/bpi");

  /// Fetches the BTS-USD price.
  Future<APIResponse<num>> fetchBtcUsd() async {
    var response = await coinDeskClient.get('currentprice.json');
    if (response.isNotOK) {
      return APIResponse.notFound();
    }

    var btcUsd = response.json['bpi']['USD']['rate_float'] as num?;
    return btcUsd != null ? APIResponse.ok(btcUsd) : APIResponse.notFound();
  }

  /// Not found route (`404`):
  FutureOr<APIResponse> notFound(request) {
    // The requested path:
    var path = request.path;

    var body = '''
    <h1>404</h1><br>
    <b>PATH:<b> $path
    <p>
    <i>$notFoundMsg</i>
    ''';

    // `APIResponse` with `content-type` and `cache-control`:
    return APIResponse.notFound(payload: body)
      ..payloadMimeType = 'text/html'
      ..headers['cache-control'] = 'no-store';
  }
}

/// The `APIRoot` defines the API version and modules to use:
class MyAPI extends APIRoot {
  MyAPI({dynamic apiConfig}) : super('example', '1.0', apiConfig: apiConfig);

  // Load the modules used by this API:
  @override
  Set<APIModule> loadModules() => {MyBTCModule(this)};
}

/// Starts an [APIServer] and calls the routes through [HttpClient]:
void main() async {
  // A JSON to configure the API:
  var apiConfigJson = '''
    {"not_found_msg": "This is 404!"}
  ''';

  var api = MyAPI(apiConfig: apiConfigJson);

  int? serverPort = await startAPIServer(api);

  var httpClient = HttpClient("http://localhost:$serverPort/");

  var btcUsd = (await httpClient.get('/btc/usd')).bodyAsString;
  print('BTC-USD: $btcUsd');

  var time = (await httpClient.post('/btc/time')).bodyAsString;
  print('TIME: $time');

  var foo = (await httpClient.get('/btc/foo')).bodyAsString;
  print('FOO:\n$foo');

  await stopAPIServer();
}

late final APIServer apiServer;

/// Starts the [APIServer] (HTTP Server) and returns the port.
/// - With Hot Reload if `--enable-vm-service` is passed to the Dart VM.
Future<int?> startAPIServer(MyAPI api) async {
  var serverPort = 8088;

  print('Starting APIServer...\n');

  apiServer = APIServer(api, '*', serverPort, hotReload: true);
  await apiServer.start();

  print('\n$apiServer');
  print('URL: ${apiServer.url}\n');

  return serverPort;
}

/// Stops the [APIServer].
Future<bool> stopAPIServer() async {
  await apiServer.stop();
  return true;
}
```

OUTPUT:

```text
Starting APIServer...

2021-10-08 02:15:17.924328 [CONFIG]  (main) APIHotReload > pkgConfigURL: ~/workspace/bones_api/.dart_tool/package_config.json
2021-10-08 02:15:17.959068 [CONFIG]  (main) APIHotReload > Watching [~/workspace/bones_api] with [MacOSDirectoryWatcher]...
2021-10-08 02:15:18.185128 [INFO]    (main) APIHotReload > Created HotReloader
2021-10-08 02:15:18.185624 [INFO]    (main) APIHotReload > Enabled Hot Reload: true
2021-10-08 02:15:18.185852 [INFO]    (main) APIServer    > Started HTTP server: 0.0.0.0:8088

APIServer{ apiType: MyAPI, apiRoot: example[1.0]{btc}, address: 0.0.0.0, port: 8088, hotReload: true, started: true, stopped: false }
URL: http://0.0.0.0:8088/

BTC-USD: 53742.76
TIME: 2021-10-08 02:15:18.294076
FOO:
    <h1>404</h1><br>
    <b>PATH:<b> /btc/foo
    <p>
    <i>This is 404!</i>

```

## CLI

You can use the built-in command-line interface (CLI) `bones_api`.

To activate it globally:

```bash
 $> dart pub global activate bones_api
```

Now you can use the CLI directly:

```bash
  $> bones_api --help
```

To serve an API project:

```bash
  $> bones_api serve --directory path/to/project --class MyAPIRoot --config api-prod.conf --port 80 --address 0.0.0.0 --build --hotreload --domain mydomain.com=/var/www
```

To create an API project file tree:

```bash
  $> bones_api create -o /path_to/workspace/foo_api -p project_name_dir=foo_api -p "project_name=Foo API" -p "project_description=API for Foo stuffs." -p homepage=http://foo.com
```

## Hot Reload

`APIServer` supports Hot Reload when the Dart VM is running with `--enable-vm-service`:

```dart
void main() async {
  var apiServer = APIServer(api, 'localhost', 8080, hotReload: true);
  await apiServer.start();
}
```

The CLI `bones_api`, when called with `--hotreload`,
will launch a new Dart VM with `--enable-vm-service` (if needed) to allow Hot Reload. 

To serve an API project with Hot Reload enabled:

```bash
  $> bones_api serve --directory path/to/project --class MyAPIRoot --hotreload
```

## Using Reflection

You can use the package [reflection_factory] to automate some
declarations.

[reflection_factory]: https://pub.dev/packages/reflection_factory

For example, you can map all routes in a class with one line of code:

File: `module_account.dart`:
```dart
import 'package:bones_api/bones_api.dart';
import 'package:reflection_factory/reflection_factory.dart';

// See Repositories sections below in this README:
import 'repositories.dart';

// The generated reflection code by `reflection_factory`:
part 'module_account.reflection.g.dart';

@EnableReflection()
class AccountModule extends APIModule {
  AccountModule(APIRoot apiRoot) : super(apiRoot, 'account');

  final AddressAPIRepository addressRepository = AddressAPIRepository();

  final AccountAPIRepository accountRepository = AccountAPIRepository();

  @override
  void configure() {
    // Maps the POST routes by reflection of any method in this class
    // that returns `APIResponse` or accepts `APIRequest`.
    routes.postFrom(reflection);
  }

  // The request parameters will be mapped to the correct
  // method parameter by name:
  Future<APIResponse> auth(String? email, String? password) async {
    if (email == null) {
      return APIResponse.error(error: 'Invalid parameters!');
    }

    if (password == null) {
      return APIResponse.unauthorized();
    }

    var sel = await accountRepository.selectAccountByEmail(email);

    if (sel.isEmpty) {
      return APIResponse.unauthorized();
    }

    var account = sel.first;

    // The object `account` will be automatically converted
    // to JSON when the response is sent through HTTP.
    return account.checkPassword(password)
        ? APIResponse.ok(account)
        : APIResponse.unauthorized();
  }
  
}
```

## Declaring Entities & Reflection

You can declare entities classes in portable Dart code (that also works in the Browser).

To easily enable `toJSon` and `fromJson`, just add `@EnableReflection()` to your entities.

File: `entities.dart`:
```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:reflection_factory/reflection_factory.dart';

part 'entities.reflection.g.dart';

@EnableReflection()
class Account {
  int? id;

  String email;
  String passwordHash;
  Address? address;

  Account(this.email, String passwordOrHash, this.address, {this.id})
      : passwordHash = hashPassword(passwordOrHash);

  Account.create() : this('', '', null);

  bool checkPassword(String password) {
    return passwordHash == hashPassword(password);
  }

  static final RegExp _regExpHEX = RegExp(r'ˆ(?:[0-9a-fA-F]{2})+$');

  static bool isHashedPassword(String password) {
    return password.length == 64 && _regExpHEX.hasMatch(password);
  }

  static String hashPassword(String password) {
    if (isHashedPassword(password)) {
      return password;
    }

    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    var hash = digest.toString();

    return hash;
  }
}

@EnableReflection()
class Address {
  int? id;

  String countryCode;
  String state;
  String city;
  String address1;
  String address2;

  String zipCode;

  Address(this.countryCode, this.state, this.city, this.address1, this.address2,
      this.zipCode,
      {this.id});

  Address.create() : this('', '', '', '', '', '');
}

```

See [reflection_factory] for more Reflection documentation.

## Repositories & Database

To stored entities in Databases and manipulate them you can set up an `EntityRepositoryProvider`:

File: `repositories.dart` 
```dart
import 'package:bones_api/bones_api.dart';

// Import the PostgreSQL Adapter:
import 'package:bones_api/bones_api_adapter_postgre.dart';

// Import the above entities file:
import 'entities.dart';

/// The API `EntityRepositoryProvider`:
class APIEntityRepositoryProvider extends EntityRepositoryProvider {
  static final APIEntityRepositoryProvider _instance =
      APIEntityRepositoryProvider._();

  // Singleton:
  factory APIEntityRepositoryProvider() => _instance;

  // Returns the current `APIRoot`:
  APIRoot? get apiRoot => APIRoot.get();

  APIEntityRepositoryProvider._() {
    // The current APIConfig:
    var apiConfig = apiRoot?.apiConfig;

    var postgreAdapter = PostgreSQLAdapter.fromConfig(
      apiConfig?['postgres'], // The connection configuration
      parentRepositoryProvider: this,
    );

    // Join the `PostgreSQLAdapter` and the Address/Account
    // `EntityHandler` (from reflection) to set up an
    // `EntityRepository` that uses SQL:
    
    // Entity `Address` in table `address`:
    SQLEntityRepository<Address>(
        postgreAdapter, 'address', Address$reflection().entityHandler);

    // Entity `Account` in table `account`:
    SQLEntityRepository<Account>(
        postgreAdapter, 'account', Account$reflection().entityHandler);
  }
}

/// The [Address] APIRepository:
class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository() : super(provider: APIEntityRepositoryProvider());

  /// Selects an [Address] by field `state`:
  FutureOr<Iterable<Address>> selectByState(String state) {
    return selectByQuery(' state == ? ', parameters: {'state': state});
  }
}

/// The [Account] APIRepository:
class AccountAPIRepository extends APIRepository<Account> {
  AccountAPIRepository() : super(provider: APIEntityRepositoryProvider());

  /// Selects an [Account] by field `email`:
  FutureOr<Iterable<Account>> selectAccountByEmail(String email) {
    return selectByQuery(' email == ? ', parameters: {'email': email});
  }

  /// Selects an Account by field `address` and sub-field `state`:
  FutureOr<Iterable<Account>> selectAccountByAddressState(String state) {
    // This condition will be translated to a SQL with INNER JOIN (when using an SQLAdapter):
    return selectByQuery(' address.state == ? ', parameters: [state]);
  }
}

```

The config file used above:

File: `api-local.yaml`
```yaml
postgres:
  database: yourdb
  username: postgres
  password: 123456
```
## SQLAdapter

To use a SQL database with your `EntityRepository` you need a `SQLAdapter`:

- `PostgreSQLAdapter`: a [PostgreSQL][postgres] adapter.
- `MySQLAdapter`: A [MySQL][mysql] adapter.
- `MemorySQLAdapter`: a portable `SQLAdapter` that stores entities in memory.

The `SQLAdapter` is responsible to connect to the database, manage the connection
pool and also to adjust the generated SQLs to the correct dialect.

[postgres]: https://www.postgresql.org/
[mysql]: https://www.mysql.com/

## Bones_UI

See also the package [Bones_UI][bones_ui], a simple and easy Web User Interface Framework for Dart.

[bones_ui]: https://pub.dev/packages/bones_ui

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Colossus-Services/bones_api/issues

# Contribution

Any help from the open-source community is always welcome and needed:

- Found an issue?
    - Please fill a bug report with details.
- Wish a feature?
    - Open a feature request with use cases.
- Are you using and liking the project?
    - Promote the project: create an article, do a post or make a donation.
- Are you a developer?
    - Fix a bug and send a pull request.
    - Implement a new feature.
    - Improve the Unit Tests.
- Have you already helped in any way?
    - **Many thanks from me, the contributors and everybody that uses this project!**

## Author

Graciliano M. Passos: [gmpassos@GitHub][gmpassos_github].

## License

[Artistic License - Version 2.0][artistic_license]


[gmpassos_github]: https://github.com/gmpassos
[colossus]: https://colossus.services/
[artistic_license]: https://github.com/Colossus-Services/bones_api/blob/master/LICENSE

