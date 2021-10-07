# Bones_API

[![pub package](https://img.shields.io/pub/v/bones_api.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/bones_api)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Codecov](https://img.shields.io/codecov/c/github/Colossus-Services/bones_api)](https://app.codecov.io/gh/Colossus-Services/bones_api)
[![CI](https://img.shields.io/github/workflow/status/Colossus-Services/bones_api/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/Colossus-Services/bones_api/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/releases)
[![New Commits](https://img.shields.io/github/commits-since/Colossus-Services/bones_api/latest?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/network)
[![Last Commits](https://img.shields.io/github/last-commit/Colossus-Services/bones_api?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_api/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/Colossus-Services/bones_api?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_api)
[![License](https://img.shields.io/github/license/Colossus-Services/bones_api?logo=open-source-initiative&logoColor=green)](https://github.com/Colossus-Services/bones_api/blob/master/LICENSE)

Bones_API - A Powerful API backend framework for Dart. Comes with a built-in HTTP Server,
routes handler, entity handler, SQL translator, and DB adapters.

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

Now you can use the CLI directly:

```bash
  $> bones_api --help
```

To serve an API project:

```bash
  $> bones_api serve --directory path/to/project --class MyAPIRoot
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

// The PostgreSQL Adapter:
import 'package:bones_api/bones_api_adapter_postgre.dart';

// The above entities file:
import 'entities.dart';

// The `EntityRepository` provider:
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

// The Address repository:
class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository() : super(provider: APIEntityRepositoryProvider());

  // Selects an Address by field `state`:
  FutureOr<Iterable<Address>> selectByState(String state) {
    return selectByQuery(' state == ? ', parameters: {'state': state});
  }
}

// The Account repository:
class AccountAPIRepository extends APIRepository<Account> {
  AccountAPIRepository() : super(provider: APIEntityRepositoryProvider());

  // Selects an Account by field `email`:
  FutureOr<Iterable<Account>> selectAccountByEmail(String email) {
    return selectByQuery(' email == ? ', parameters: {'email': email});
  }

  // Selects an Account by field `address` and sub-field `state`:
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

