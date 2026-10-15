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

## Static files: `.aliases`

A directory served as static files (`--document-root` or `--domain`) can
define virtual paths for its files and subdirectories with a `.aliases` file.

```text
icons/
  .aliases
  sections/
    food.png
    drinks.png
```

`icons/.aliases`:

```text
# Serve icons/sections/* also as icons/*
./ = sections/
```

Now `/icons/food.png` serves `icons/sections/food.png`, and
`/icons/sections/food.png` keeps working.

### Format

One mapping per line, `<virtual> = <target>`, both relative to the directory
of the `.aliases` file (written literally, not URL-encoded). Blank lines are
ignored, and `#` starts a comment (at the line start or after a space).

```text
# File alias (exact path) and rename:
food.png = sections/food.png
beer.png = sections/drinks.png

# Directory alias (both sides end with '/'):
#   /icons/menu/<anything> → icons/sections/<anything>
menu/ = sections/
v2/   = brand/2024/
# An exact file alias beats the directory alias above:
v2/favicon.ico = brand/legacy/favicon.ico

# Pattern alias (by extension or path pattern):
#   `*` any characters in a segment, `?` one character,
#   `**/` zero or more whole segments.
*.png = sections/*.png
*.webp = sections/                  # same as `*.webp = sections/*.webp`
**/*.svg = vector/**/*.svg
img-??.jpg = photos/img-??.jpg
v*/logo.png = brand/v*/logo.png

# Overlay: any unresolved path here is looked up in `sections/`:
./ = sections/
```

A pattern target either repeats the pattern wildcards, in the same order
(the first ones can be used and the last ones dropped: `*-*.gif = x/*.gif`), or
is a directory (ending with `/`), to which the matched path is appended.
Wildcards are greedy: with `*-*.gif = x/*.gif`, `a-b-c.gif` → `x/a-b.gif`.
Patterns have at most 8 wildcards and 256 characters, and are only matched
against paths up to 1024 characters.

Invalid lines are skipped (with a logged warning) and the other lines still
apply:

```text
secret.txt = ../../etc/passwd     # '..' not allowed
/abs.png = sections/food.png      # absolute path
x.png = sections/                 # file → directory mismatch
.aliases = sections/food.png      # '.aliases' is reserved
just-a-name                       # no '='
```

### Resolution and precedence

1. A request for an existing physical file or directory is served as before:
   the physical path always wins over an alias.
2. Otherwise, the `.aliases` of each directory of the request path is
   checked, the closest (deepest) first, and in each one: the exact file alias,
   then directory aliases (longest prefix first), then patterns (file order),
   then the overlay `./`. The first target that exists is served.
3. A target can be a virtual path itself (aliases chain up to 8 levels).
   Each alias entry is applied at most once in a chain, so an overlay or a
   self-matching pattern never nests (`sections/sections/...`), and cycles
   (`a.png = b.png` + `b.png = a.png`) are detected and ignored.
4. Without an existing target the response is the usual `404`.
5. A virtual directory requested without a trailing `/` is redirected (`302`,
   since an alias can change) to the *virtual* path with `/`, then its
   `index.html` is served.

### Security

- A `.aliases` file is never served (`404`), in any letter case or encoding.
- `..`, absolute paths and `\` are rejected in `.aliases`: a target can only
  point into the `.aliases` directory or its subdirectories.
- Request paths with `.`, `..` or encoded separators are never aliased.
- Symlinks behave as for any static file: a target resolving outside the
  document root responds `404`. A `.aliases` symlink to outside the root is
  ignored.
- A malformed `.aliases` (bad lines, invalid UTF-8, larger than 64KB) never
  breaks the server: invalid content is skipped and logged.

### Caching

`.aliases` files and resolved paths are cached in memory and re-checked at
most every 10 seconds, so edits (including a new physical file shadowing an
alias) apply within that interval. Each directory costs a `.aliases` stat
every 10 seconds, and the walk stops at the first missing directory of the
request path (missing directories are cached apart, so repeated probes of
missing paths don't touch the file system). A path to which no alias applies
is never stat'ed by the aliases resolution, and a pattern is only matched
when its literal prefix/suffix (e.g. `.png`) match. The caches are bounded
(4096 entries each, evicting the oldest entries; directories with a
`.aliases` are kept).

An aliased file goes through the same pipeline as its physical path: the
response cache (shared: the cache key is the physical path), gzip, and the
static files headers (`Cache-Control`, cross-origin policies, cookieless).
The `Cache-Control` rules (`long-lived-static-files-cached`) apply to the
physical (target) path.

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

### Indexes

`@EntityField.indexed()` indexes one field. For an index over several fields
(a composite index), annotate the entity class with `@EntityIndex`:

```dart
@EnableReflection()
@EntityIndex(['state', 'city'])                     // address__state_city__idx
@EntityIndex(['zipCode', 'address1'], name: 'address_zip_idx')
class Address {
  // ...
}
```

The indexes are created with the tables (`generateTables`), and
`checkTables` reports a table missing one (an index over the same columns, in
the same order, with any name), with the `CREATE INDEX` SQL to create it.

With `unique: true` it's a composite unique constraint (as
`@EntityField.unique()` for one field):

```dart
@EntityIndex(['establishment', 'day'], unique: true)
// CONSTRAINT "sales_day__establishment_day__unique" UNIQUE ("establishment", "day")
class SalesDay {
  // ...
}
```

Index names are unique per schema in PostgreSQL and SQLite (not per table):
a `name:` in use by another table's index is reported by `checkTables`.

The unique constraints (`unique: true`, `@EntityField.unique()`) are enforced
by the SQL adapters and the `DBSQLMemoryAdapter`, not by the object adapters
(see [ObjectAdapter](#objectadapter)).

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

  /// Selects a page of [Account]s by field `state` (`page` starts at 1):
  FutureOr<Iterable<Account>> selectAccountsPage(String state, int page) {
    // `page` computes the offset from the page size, and implies `orderByID`,
    // so the pagination is stable
    // (translated to: ORDER BY <id> ASC LIMIT 20 OFFSET <(page - 1) * 20>).
    return selectByQuery(
      ' address.state == ? ',
      parameters: [state],
      limit: 20,
      page: page,
    );
  }

  /// Selects the 10 newest [Account]s (highest IDs first):
  FutureOr<Iterable<Account>> selectNewestAccounts() {
    return selectAll(
      limit: 10,
      orderByID: true,
      orderDirection: OrderDirection.descending,
    );
  }
}

```

### Ordering and pagination

The `select*` methods accept `limit`, `offset`, `page`, `orderByID` and
`orderDirection`:

- `orderByID` orders by the table's ID column, resolved automatically from the
  table scheme — no column name to spell out.
- A non-null `offset` turns `orderByID` on by default, since an offset without
  a stable order can return overlapping or missing rows across pages. With a
  SQL database a non-null `limit` does too: which rows an unordered `LIMIT`
  returns is undefined (it can change with the query plan). The in-memory
  adapters keep their rows in insertion order, so they order only for an
  `offset`. Pass `orderByID: false` to opt out.
- `orderDirection` is `OrderDirection.ascending` by default, and is ignored
  while the ordering is not active.
- `page` is the 1-based ergonomic form of `offset`, using `limit` as the page
  size: `page: 3, limit: 20` is `offset: 40`. It throws an `ArgumentError` if
  combined with an `offset`, if there is no positive `limit` to page by, or if
  it is below 1.

### Paginated reads: `EntityPagination`

For reading a result page by page, `paginateByQuery` (and `paginate` /
`paginateAll`) returns an `EntityPagination`, which keeps the pages it has
already loaded:

```dart
var page = accountRepository.paginateByQuery(
  ' address.state == ? ',
  parameters: ['NY'],
  limit: 20,
);

await page.loadNextPage();   // loads page 1
page[0];                     // synchronous: already loaded
page[45];                    // null: not loaded (never fetches)

await page.getAt(45);        // loads page 3 on demand
page.loadedPages;            // [1, 3] — page 2 is a gap
page.maxLoadedIndex;         // 59
page.totalLength;            // null: the end is not known yet

await page.loadAll();        // fills the gaps and resolves the end
page.totalLength;            // 57
page.finalPage;              // 3
```

Pages are 1-based and entry indexes 0-based. Synchronous access
(`operator []`, `loadedEntities`) never fetches — only the `FutureOr` methods
(`getAt`, `getPage`, `getRange`, `loadNextPage`, `loadAll`, `stream`) do.

It is deliberately not a `List`: a paginated select does not know its length
until it reaches the end, so `totalLength` is `null` until the final page is
identified (`isFinalPageResolved`). Until then you still know
`maxLoadedIndex`, `maxKnownPage` and which pages are loaded.

The optional `onEvent` hook reports what is being fetched, for progress
reporting and logging:

```dart
var page = accountRepository.paginateByQuery(
  ' address.state == ? ',
  parameters: ['NY'],
  limit: 20,
  onEvent: (event) {
    switch (event) {
      case EntityPaginationPageLoading(:var page):
        print('fetching page $page...');
      case EntityPaginationPageLoaded(:var page, :var entriesLength):
        print('page $page: $entriesLength entries');
      case EntityPaginationPageError(:var page, :var error):
        print('page $page failed: $error');
      case EntityPaginationPageSkipped(:var page, :var reason):
        print('page $page not fetched: ${reason.name}');
      case EntityPaginationEnd(:var totalLength):
        print('done: $totalLength entries');
      case EntityPaginationReset(:var discardedPages):
        print('discarded ${discardedPages.length} pages');
    }
  },
);
```

Events are delivered synchronously and in order, so the sequence is meaningful
even for a synchronous page loader. To consume them as a `Stream` instead,
forward them: `onEvent: myEventStream.add`.

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

- `DBPostgreSQLAdapter`: a [PostgreSQL][postgres] adapter.
  Import: `package:bones_api/bones_api_db_postgre.dart`
- `DBMySQLAdapter`: a [MySQL][mysql] adapter.
  Import: `package:bones_api/bones_api_db_mysql.dart`
- `DBSQLiteAdapter`: an embedded [SQLite][sqlite] adapter, for a database file
  or an in-memory database. Needs no server and no native library: the
  [`sqlite3`][sqlite3_pkg] package bundles SQLite itself.
  Import: `package:bones_api/bones_api_db_sqlite.dart`
- `DBSQLMemoryAdapter`: a portable `SQLAdapter` that stores entities in memory.

The `SQLAdapter` is responsible to connect to the database, manage the connection
pool and also to adjust the generated SQLs to the correct dialect.

Example of a SQLite configuration:

```yaml
db:
  sqlite:
    path: /var/lib/myapp/db.sqlite
    generateTables: true
```

Use `memory: true` (or `path: ':memory:'`) for an in-memory database.

[postgres]: https://www.postgresql.org/
[mysql]: https://www.mysql.com/
[sqlite]: https://www.sqlite.org/
[sqlite3_pkg]: https://pub.dev/packages/sqlite3

## ObjectAdapter

A `DBObjectAdapter` stores each entity as an independent object (a JSON, by
ID), in an object storage:

- `DBObjectGCSAdapter`: [Google Cloud Storage][gcs] (config: `object.gcs`).
  Import: `package:bones_api/bones_api_db_gcp.dart`
- `DBObjectDirectoryAdapter`: a local directory, a file per object. Useful for
  development (config: `object.directory`).
  Import: `package:bones_api/bones_api_db_directory.dart`
- `DBObjectMemoryAdapter`: in memory. Useful for tests (config:
  `object.memory`).

**Unique fields are not enforced** by the `DBObjectAdapter`s
(`@EntityField.unique()` and `@EntityIndex(..., unique: true)`): two entities
with the same unique value are both stored, without an error. Object storages
(e.g. Google Cloud Storage, Amazon S3) are not designed for that: there's no
index over the objects' values, nor transactions over multiple objects. When
the uniqueness is required, use a `SQLAdapter` (the database's `UNIQUE`
constraints) or the `DBSQLMemoryAdapter`.

[gcs]: https://cloud.google.com/storage

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

