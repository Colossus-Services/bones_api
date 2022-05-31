## 1.1.25

- `EntityRepositoryProvider`:
  - `storeAllFromJson`: ensure that operations are executed sequentially. 

## 1.1.24

- Improve populate of entities using ID as reference to sub entities fields.
- `EntitySource`:
  - Added `existsID`. 
- `SQLAdapter`:
  - Fixed storage (and update fallback) of entities with pre-defined IDs. 
- `MemorySQLAdapter`:
  - Fixed `count` with a condition.s 
- petitparser: ^4.4.0

## 1.1.23

- Small path for the last version.

## 1.1.22

- `MemorySQLAdapter`:
  - Fixed when comparing entities and IDs. 

## 1.1.21

- `Initializable`:
  - Now allows async initializations.
- `MethodReflectionExtension`:
  - `isAPIMethod` now accepts `FutureOr<APIResponse>`.
- `EntityRepository`:
  - Added `selectAll`.
- reflection_factory: ^1.1.2
- crypto: ^3.0.2
- shelf: ^1.3.0
- hotreloader: ^3.0.4
- args: ^2.3.1
- yaml: ^3.1.1

## 1.1.20

- `APIServer`:
  - Improve resolution of `APICredential` username.
- mercury_client: ^2.1.6

## 1.1.19

- `APIServer`:
  - Improved resolution of request payload.
- Added `decodeQueryStringParameters`, for full decoding of query string with single and multiple parameters. 

## 1.1.18

- `APIRoot`:
  - Added `callAuthenticate`.
- `APIRequest`:
  -  Added `credential` to constructors.

## 1.1.17

- `APIModuleProxy`:
  - ignoreParametersTypes: added type `APICredential` (should exist only in the implementation). 
- reflection_factory: ^1.1.0

## 1.1.16

- reflection_factory: ^1.0.29

## 1.1.15

- Improved GitHub CI.
- Added browser tests.
- mercury_client: ^2.1.5
- swiss_knife: ^3.1.0
- data_serializer: ^1.0.7

## 1.1.14

- `MemorySQLAdapter`: fix `nextID` when entities are stored with pre-defined IDs. 
- `EntityHandler`: Rename `idFieldsName` to `idFieldName`.

## 1.1.13

- `ClassReflectionEntityHandler`:
  - Improve `createFromMap`.
  - Compatibility with `JsonFieldAlias`.
- reflection_factory: ^1.0.28

## 1.1.12

- `SQLAdapter` (`PostgreSQL`, `MySQL` and in-memory):
  - Allow auto insert of new entities with explicit IDs. It was trying to update an entity that is not stored. 
- `MemorySQLAdapter`:
  - Fixed support for relationship tables.
  - Fixed isolation of internal data (memory) that was leaking through queries results.
  - Improved tests: now running same tests of `PostgreSQL` and `MySQL`.
- Better resolution of `EntityRepository` when multiple candidates are present.
- Added helpers: `deepCopy`, `deepCopyList`, `deepCopySet` and `deepCopyMap`.

## 1.1.11

- `Transaction`:
  - Queries now reuse already instantiated entities in the same transaction.
- Added `EntityCache` for entity instantiation from `Map` or JSON.
- `EntityRepository`:
  - Added `storeAllFromJson` and `storeFromJson`.
- `MemorySQLAdapter`:
  - Fixed relationships of `TableScheme` loaded by the memory SQLAdapter.  
- Fix update of sub-entities, that was being ignored.
- Improve error logging.
- reflection_factory: ^1.0.27

## 1.1.10

- Optimize relationship requests to resolve entities.
- `MemorySQLAdapter`: support of returned columns with alias name.

## 1.1.9

- Fix update SQL when a set value is null.

## 1.1.8

- `APIServer` and `APIModule`: improved error logging.
- statistics: ^1.0.20

## 1.1.7

- `APIModuleProxy`: ignoring `APIRequest` parameters.
- reflection_factory: ^1.0.25

## 1.1.6

- `APIServer`:
  - Improved CORES response (`OPTIONS` request).
- `APISecurity`:
  - Improved resolution of credential token and related username.
  - Improved tests.

## 1.1.5

- SQL:
  - Added: `numeric` type mapped to `Decimal`. 
- Fix JSON parsing of `Decimal` types.

## 1.1.4

- Integrate `Decimal` to entities, repositories, JSON and SQL.
- Improve `APIPlatform`.
- statistics: ^1.0.19

## 1.1.3

- `EntityHandler.resolveValueByType`:
  - Avoid `dev_compiler` bug https://github.com/dart-lang/sdk/issues/48631 when generating JS code.

## 1.1.2

- Added `ConditionIdIN`: to allow optimized selection of multiple IDs with one query.
- Added `EntityProvider` to all entity field resolution related operations, like `createFromMap` and `Json.decode`.
- Improve `APIModuleHttpProxy` response body decoding. 
- reflection_factory: ^1.0.24
- mercury_client: ^2.1.4

## 1.1.1

- Fix `MethodReflectionExtension.returnsAPIResponse`.

## 1.1.0

- Added `APIModuleProxy` and `APIModuleHttpProxy`.
- reflection_factory: ^1.0.23
- meta: ^1.7.0

## 1.0.39

- Added support to Let's Encrypt HTTPS certificates.
- `bones_api.dart` CLI:
  - Allow domain static files. 
- `APIRoot`:
  - `APILogger`: to allow logging of `APIRoot` events.
  - `APIRequestHandler`: for personalized request handlers.
  - New fields `preApiRequestHandlers` and `posApiRequestHandlers`.
- Fix `SQLAdapter.generateInsertRelationshipSQLs`.
- Added test tag: `slow`
- shelf_static: ^1.1.0
- shelf_letsencrypt: ^1.0.0
- dart_spawner: ^1.0.6
- data_serializer: ^1.0.6
- mercury_client: ^2.1.3
- build_verify: ^3.0.0
- path: ^1.8.1
- sdk: '>=2.14.0 <3.0.0'

## 1.0.38

- Fix references and naming: `postgre` to `postgres`.
- `APIServer`: added support for `Gzip` encoding, through package `shelf_gzip`.
- shelf_gzip: ^4.0.0
- reflection_factory: ^1.0.21
- data_serializer: ^1.0.3

## 1.0.37

- Added support to `Condition` operator `=~` (`IN`).
- Added support to SQL operator `IN`.
- postgres: ^2.4.3
- test: ^1.19.5
- dependency_validator: ^3.1.2

## 1.0.36

- `TypeParser` and `TypeInfo` moved to package `reflection_factory`.
- reflection_factory: ^1.0.20

## 1.0.35

- Fix `TypeInfo`:
  - Now `TypeInfo` handles `Type` comparison in a special way (to keep consistence between VM and JS/Web).    

## 1.0.34

- Improved `EntityHandler` resolution of fields while creating instances from `Map`.
- reflection_factory: ^1.0.19

## 1.0.33

- `Entity` & `EntityHandler`:
  - Added support for enums.
- Added `enumToName` and `enumFromName`
- reflection_factory: ^1.0.18

## 1.0.32

- `Json`:
  - Integrated with `reflection_factory` `JsonCodec`.
- `FieldsFromMap.getFieldsValuesFromMap`: added parameter `includeAbsentFields`.
- `isAPIMethod`: now ignores methods declared by `APIModule`, since `reflection_factory` now supports supper classes.
- reflection_factory: ^1.0.17
- postgres: ^2.4.2
- build_runner: ^2.1.5
- test: ^1.19.3

## 1.0.31

- Added `APIServer.apiInfoURL`.
- Updated `bones_api_template.tar.gz`.
- CLI `serve`: fix an issue when mixing parameters `-b` and `-r`. 

## 1.0.30

- `Json.toJson`:
  - Added parameters: `removeNullFields` and `entityHandlerProvider`.
  - Fixed application of `removeField` and `maskField` over an entity.

## 1.0.29

- Improved `Json.toJson`.
- Added field `APIAuthentication.data`.
- `APISecurity`: added `getAuthenticationData`.

## 1.0.28

- Added `API-INFO` path: describes the API routes.

## 1.0.27

- Improved resolution of `ClassReflectionEntityHandler`.
- Extension:
  - `ReflectionFactory.createFromMap`.
  - `ClassReflection.createFromMap`.
- async_extension: ^1.0.9
- reflection_factory: ^1.0.16

## 1.0.26

- Added `APICredential`, `APIPassword` and `APISecurity`.
- Routes now can have `APIRouteRule` annotations.
- `EntityHandler`: now using also using sibling reflections to resolve.
- `DataTime`: `toJson` now converts to a `UTC` string.
- Added `MapMultiValueExtension`.
- Updated `bones_api_template.tar.gz`.
- reflection_factory: ^1.0.14
- crypto: ^3.0.1

## 1.0.25

- Update template: `lib/src/template/bones_api_template.tar.gz`

## 1.0.24

- `TableFieldReference` and `TableFieldReference` now also have the fields type.
- `SchemeProvider` now can resolve an entity ID.
- Fix `Condition` value when an entity is passed or referenced.

## 1.0.23

- `Transaction`:
  - Added `abort` to cancel the current executing transaction.
  - Better error handling. 
- Error Zone:
  - `runErrorZone` transformed into `createErrorZone` and an extension with `runGuardedAsync` and `asyncTry`.
- `executeWithPool`: added `validator` parameter.
- async_extension: ^1.0.8

## 1.0.22

- `Condition`:
  - Improved sub-field match.
- `SQL`:
  - Allow `Condition` with fields that are a relationship table. 
- `MySQLAdapter`: 
  - Using `sqlElementQuote` "`" to avoid issues with reserved words.

## 1.0.21

- Better handling of route parameters with `null` and empty values.
- Improve example and `README.md`.
- mercury_client: ^2.1.1

## 1.0.20

- `APIRouteBuilder`:
  - Better conversion of parameters types.
  - Payload only for parameter of type `Uint8List`.
- `APIServer`:
  - Better handling of errors of async payloads (`Future` resolution). 

## 1.0.19

- Improved `SQLEntityRepository` tests.
- Fixed `MemorySQLAdapter`:
  - Ensure that relationships entries are unique.
  - Update previous entity fields.
- Improved tests tags: `version`, `docker` and `build`.

## 1.0.18

- `APIResponseStatus`:
  - Added `BAD_REQUEST`.
- Added `InstanceTracker` to track entities fields changes.
- `EntityRepository`:
  - tracking entity fields changes.
- SQL:
  - Fix update syntax.
  - Improved `UPDATE` to set only modified fields.

## 1.0.17

- Optimize imports.
- Fix wrong import, that was preventing to use in JS/Browser platforms.

## 1.0.16

- Better handling of `APIServer` errors and logging.
- Added `runErrorZone` helper.
- Added logging for entity operations errors.
- reflection_factory: ^1.0.13

## 1.0.15

- `EntityHandler`:
  - `resolveValueByType` now can select an entity by its ID when necessary.
- `ClassReflectionEntityHandler`:
  - Fixed `fieldsTypes` and `findIdFieldName`, to ignore fields that are final or doesn't have a setter.
  - Fixed use of `reflection` to ensure that current object is used.
- Improved tests to run `Entity` tests repositories with reflection and without reflection.
- reflection_factory: ^1.0.12

## 1.0.14

- Added `SQLAdapter` for `MySQL`.
- SQL: 
  - Improve generated SQL, to adapt to different dialects.
  - Allow generation of SQL with only positional parameters (needed for MySQL).
  - Improve return of DELETE, to circumvent SQL dialects without `RETURNNG` and `OUTPUT`.
  - Improved supported types.
- mysql1: ^0.19.2
- docker_commander: ^2.0.13 

## 1.0.13

- Added `TypeInfo` to represent better types with generics.
- Added `TableRelationshipReference` for use in `TableScheme`.
- Added `TimedMap` to help with timed caches.
- Added `KeyConditionIN` and `KeyConditionNotIN`.
- Entities:
  - Added support to relationship fields.
  - Added support for List fields pointing to another entity.
- `SQLEntityRepository`:
  - Added support to UPDATE.
  - Added support to relationship tables.

## 1.0.12

- CLI:
  - Added option `--build` to automatically build reflection files when detected by inspector.
  - Added commands:
    - `create`: creates a `bones_api` backend project tree.
    - `info`: show information about the `bones_api` backend project template.
- reflection_factory: ^1.0.10
- project_template: ^1.0.2
- resource_portable: ^3.0.0

## 1.0.11

- `APIRequest`:
  - Added `scheme`, `requesterSource` and `_requesterAddress`.
- `APIResponse`:
  - Added metrics support (used to generate `Server-Timing` headers). 
  - Added `setCORS`.
- Added `TypeParser`, for lenient parsing of basic Dart types.
- Entities:
  - Better automatic conversion of types when setting entities fields.
  - Added support for transactions.
- Repositories:
  - Added `limit` support for queries.
  - Better resolution of correct `EntityRepository` and `EntityHandler` for a type while loading it.
  - Better resolution of sub-entities in fields.
- Improved tests:
  - Using Docker container to test PostgreSQL adapter.
- async_extension: ^1.0.7
- reflection_factory: ^1.0.8
- docker_commander: ^2.0.12

## 1.0.10

- `TableScheme`:
  - Added `getFieldsValues` and `getFieldValue`.
- `EntityHandler`: optimized fiel resolution on `setFieldsFromMap`.
- Improved dartdoc references.
- Improved tests.

## 1.0.9

- `apiMethod` now can receive an `APIRequest` parameter while receiving other normal parameters.
- `PostgreSQLAdapter`: correctly resolving `idFieldName` by primary key column.
- Added test to ensure that `APIRoot.VERSION` is compatible with `pubspec.yaml`.
- Added test that uses reflection.
- Added `build_verify` test.
- reflection_factory: ^1.0.7

## 1.0.8

- Added `APIConfig`:
  - CLI now accepts a `--config` option. 
- Rename `Data` classes to `Entity`.
- Added `MemorySQLAdapter`.
- Added `TableScheme` to help `ConditionEncoder`:
  - SQL now can perform inner join:
    - Example Condition: ` address.state = "NY" `
- Improved `ConditionID` encoding:
  - ID field name (primary key) can be resolved for each table.
  - `#ID` can be used to point to the primary key field/column.
- `APIRepository` & `EntityRepository`:
  - Added delete operation.
- `EntityHandler` now handles better fields that points
  to other entities.
- Improved tests.
- async_extension: ^1.0.5
- reflection_factory: ^1.0.6
- yaml: ^3.1.0
- yaml_writer: ^1.0.1
- mercury_client: ^2.1.0

## 1.0.7

- Added `APIPayload.payloadFileExtension`.
- Added `ConditionEncoder`, `ConditionSQLEncoder`.
- Improved Data & Entity framework:
  - Added `SQLDatabaseAdapter` and `PostgreAdapter`.
  - Added `DataRepositorySQL`.
- Added DB Adapter for PostgreSQL.
- APIServer:
  - Better auto MIME Type resolution.
- Now API methods can return `FutureOr<APIResponse>`.
- mime: ^1.0.0

## 1.0.6

- CLI Hot Reload fixed:
  - Avoid reload of main Isolate (bones_api CLI),
    since API is spawned in it's own Isolate.
- `DataEntity`:
  - Added `fieldsNames`.
- `DataHandlerProvider`:
  - Fixed `getDataHandler`.
- Added `EntityDataHandler` and `DataRepositoryProvider`.

## 1.0.5

- Added integration with `ReflectionFactory`.
  - Routes can be configured using a `reflection` object. 
- `APIServer`:
  - Added support to Dart VM Hot Reload.
- CLI `bones_api`:
  - Added flag `--hotreload` to serve the API with Hot Reload enabled.  
- Added `DataEntity` and `DataHandler` framework
- Added `Condition`:
  - Allow queries using a syntax similar to Dart.
- New `APIRepository`, to allow database agnostic integration.
- dart_spawner: ^1.0.5
- reflection_factory: ^1.0.4
- args: ^2.2.0 
- petitparser: ^4.2.0
- hotreloader: ^3.0.1
- logging: ^1.0.1
- collection: ^1.15.0
- lints: ^1.0.1

## 1.0.4

- CLI `bones_api`:
  - Added command `console`.
  - Command `serve`: added header `Content-Type`.
- Added `Arguments` tool.
- Added `APIRequest.fromArgs` and `APIRequest.fromArgsLine`.
- Added `APIRequest`/`APIResponse` `payloadMimeType`.

## 1.0.3

- `APIServer`:
  - Added `create` and `run` helpers.

## 1.0.2

- `APIServer`:
  - Add `isStopped` and `waitStopped()`.
  - Removed `isClosed`.
- Fix `PATCH` method.
- CLI:
  - Improved serve console logging.
- Using `dart_spawner` to spawn/run an `API`.
- dart_spawner: ^1.0.2
- Removed `yaml: ^3.1.0`

## 1.0.1

- Improve documentation.
- Fix typo.

## 1.0.0

- CLI: `bones_api` with `serve` command.
- Initial version.
