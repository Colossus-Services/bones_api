## 1.3.8

- `/API-INFO`:
  - Now accepts a selected module. Example: `/API-INFO/user`
- Added `APIRequest.parsingDuration`.
- Added `EntityReferenceList`: a version of `EntityReference` for entities lists.
- Fix `EntityRepository._entitiesTracker`: now tracked fields values are isolated from tracked entity.

## 1.3.7

- Added `EntityReference`:
  An entity field wrapper that allows lazy load of sub-entities.
- Added `EntityResolutionRules` to allow lazy or eager selects.
- `EntityProvider`:
  - `getEntityByID`: Added parameter `sync`.
- reflection_factory: ^1.2.9

## 1.3.6

- Added integration with `AsyncEvent`.
- reflection_factory: ^1.2.6
- async_events: ^1.0.3
- statistics: ^1.0.23
- postgres: ^2.4.6
- shelf: ^1.3.2
- yaml_writer: ^1.0.2

## 1.3.5

- `SQL`:
  - Added `isFullyDummy`.
- `DBSQLAdapter`:
  - Improve `fieldValueToSQL` when the entity is from another adapter.
  - `updateSQL` and `doUpdateSQL`: return the ID even when the `SQL.isDummy`.

## 1.3.4

- `APIRouteBuilder`: Accepts Data URL for `Uint8List` parameters.
- `APIModuleHttpProxy.doRequest`: converts `Uint8List` to Data URL (through `Json.toJson`).

## 1.3.3

- Added `EntityResolutionRules`.
- `populateFromSource`:
  - Allow source samples with `url(path/to/file.txt)`, that will be read from a local file. 

## 1.3.2

- Clean code.

## 1.3.1

- `DBMemorySQLAdapter`, `DBMemoryObjectAdapter`, `DBPostgreSQLAdapter` `DBMySQLAdapter`:
  - Improve `toString`: show `instanceID`.
- `SQLGenerator`:
  - Fix CONSTRAINT to an entity type from another DBAdapter. 

## 1.3.0

- Clean code:
  - Renamed `MemorySQLAdapter` to `DBMemorySQLAdapter`.
  - Renamed `MemoryObjectAdapter` to `DBMemoryObjectAdapter`.
  - Renamed `SQLAdapter` to `DBSQLAdapter`.
    - Renamed `SQLEntityRepository` to `DBSQLEntityRepository`.
    - Renamed `SQLEntityRepositoryProvider` to `DBSQLEntityRepositoryProvider`.
  - Renamed `MySQLAdapter` to `DBMySQLAdapter`.
  - Renamed `PostgreSQLAdapter` to `DBPostgreSQLAdapter`.
  - Renamed `bones_api_adapter_mysql.dart` to `bones_api_db_mysql.dart`.
  - Renamed `bones_api_adapter_postgre.dart` to `bones_api_db_postgre.dart`.
  - Renamed some `lib/src/*.dart` files.

## 1.2.26

- Fix resolution of `EntityRepository` when the same instance is returned by multiple providers.
- Fix `selectByID` with null parameters and null ID.
- Fix resolution of route parameters with a type of `List` of entities. 
- sdk: '>=2.17.0 <3.0.0'
- reflection_factory: ^1.2.5

## 1.2.25

- Added `ZoneField`:
  - A field value based on the current `Zone`.
  - Used to correctly resolve `Transaction.executingTransaction` and
    allow multiple simultaneous `Transaction`s. 
- `APIRouteBuilder`:
  - Improve resolution of request parameters (entities, `Decimal` and bytes).
  - Allow resolution of entities and parameters using the request's payload.
- New `MemoryObjectAdapter`: allow storage of objects without relationships.
- Added `DBRelationalAdapter`:
  - Refactor `DBAdapter` and `SQLAdapter` to have an intermediate `DBRelationalAdapter`.
- `Transaction`:
  - Fix finalization when some complex asynchronous errors happens in the `Transaction`.
  - Added `TransactionOperationSubTransaction`, to wrap sub transactions as an operation
    of the parent transaction (used when multiple `DBAdapter`s are used in a `Transaction`).
- data_serializer: ^1.0.7
- map_history: ^1.0.3
- async_extension: ^1.0.11
- reflection_factory: ^1.2.4
 
## 1.2.24

- `bin/bones_api.dart`:
  - Fix parameter `--lib` when respawning for Hot Reload.
- Added `SQLDialect` for better handling of syntax varaitions.
- `SQLAdapter`:
  - Moved to `SQLDialect`:
    `sqlElementQuote`, `sqlAcceptsOutputSyntax`, `sqlAcceptsReturningSyntax`, `sqlAcceptsTemporaryTableForReturning`,
    `sqlAcceptsInsertDefaultValues`, `sqlAcceptsInsertIgnore`, `sqlAcceptsInsertOnConflict`.
- `SQLGenerator`: allow `VARCHAR PRIMARY KEY`.
- `EntityHandler`:
  - Fix `EntityCache` interaction issues:
    - Some instance were not being cached depending on the instantiation type.
    - Internal call to `Json.fromJson` were wrongly clearing the `EntityCache`.
  - Respecting new parameter `EntityCache.allowEntityFetch`.
- `APIPayload` (`APIRequest`, `APIResponse`):
  - Changed `payloadMimeType` from `String` to `MimeType`.
- async_extension: ^1.0.10
- reflection_factory: ^1.2.3
- statistics: ^1.0.22

## 1.2.23

- `APIConfig`:
  - Added `sourceParentPath`.
- `EntityRepositoryProvider`:
  - `populateFromSource`: added parameter `workingPath`.
- `DBAdapter` and `SQLAdapter`:
  - added parameter `workingPath`.
- `APIPlatform`:
  - `resolveFilePath`: added parameter `parentPath`.
- `bin/bones_api.dart`:
  - Added command `inspect`.
- Updated `lib/src/template/bones_api_template.tar.gz`.
- reflection_factory: ^1.2.2

## 1.2.22

- `SQLAdapterCapability`:
  - Fix declaration for `PostgreSQLAdapter` and `MySQLAdapter`. 

## 1.2.21

- `APIRepository`:
  - Add missing `transaction` parameters.
- `Transaction`:
  - Added `executeOrError`.
- `APIResponse`:
  - added field `stackTrace`.
- `APIRouteHandler`:
  - Added logging of route call. 
- Added `MapAsCacheExtension`.

## 1.2.20

- `SQLAdapter`:
  - generateTables: fix, to avoid generation if `capability.tableSQL` is `false`.
- reflection_factory: ^1.2.1

## 1.2.19

- `TableScheme`:
  - `getTableRelationshipReference`:
    better resolution when an entity has multiple `List` fields referencing the same entity/table.

## 1.2.18

- `Transaction`:
  - Fix synchronization of final return for long transactions. 
- Added `SQLAdapterException` and `DBAdapterException` for better exception/error handling:
  - `MemorySQLAdapterException`.
  - `PostgreSQLAdapterException`.
  - `MySQLAdapterException`.
- Added `FieldNameMapper`.

## 1.2.17

- Fix resolution of table columns to entity fields when resolving sub-entities.

## 1.2.16

- `MemorySQLAdapter`:
  - Fix delete constraint for tables without referenced fields. 
- `APIRoot`:
  - Added `getByType`.
  - Added `close` (removes from available `APIRoot` instances).
  - `stop` now also closes the `APIRoot`.
- `APIServer`:
  - `stop` now also closes the `APIRoot`.
- `EntityRepositoryProvider`:
  - Optimize `getEntityRepository`
  - Added `getEntityRepositoryByType`.
- `EntityHandler`:
  - Added `getEntityHandlerByType` and `getEntityRepositoryByType`.
- `EntityHandlerProvider`:
  - Added `getEntityHandlerByType` and `getEntityRepositoryByType`.
- `clearPool`:
  - `clearPool` now also closes/disposes all elements in the pool.

## 1.2.15

- `ConditionSQLEncoder`:
  - `keyFieldToSQL`: fix resolution of class field to table column name.
  - Added `resolveFieldName`.
- `EntityStorage`:
  - Added `tryDeleteEntity` and `tryDeleteByID`.
- `MemorySQLAdapter` now check references constraint before delete.
- `PostgreSQLAdapter`: improved connection retry.
- Added `tryCallMapped` and `tryCall` utils.

## 1.2.14

- `SQLAdapter`:
  - Added option `generateTables`: will automatically generate the tables when initialized.
- `PostgreSQLAdapter`:
  - When update auto inserts (new entity with pre-defined ID), a fix of the primary key sequence is performed.

## 1.2.13

- `SQLGenerator`:
  - Added `normalizeColumnName`: now generates column names using underscore (from camel-case fields).
- `StringUtils`:
  - Added `toLowerCaseSimple` and `toLowerCaseUnderscore`.

## 1.2.12

- `MemorySQLAdapter`: check for unique fields.
- `PostgreSQLAdapter` and `MySQLAdapter`: handles unique field errors as `EntityFieldInvalid`.
- `EntityFieldInvalid`: improved error information (added `tableName` and `parentError`).

## 1.2.11

- `EntityHandler`: Fix `validateFieldValue` for sub-entities.

## 1.2.10

- Generate `CREATE TABLE` SQL with unique constraint (from `EntityField`). 

## 1.2.9

- Generate `CREATE TABLE` SQL using `EntityField` information.

## 1.2.8

- Add `EntityField`: annotation to inform if a field is `hidden`, `unique` and its limits (`minimum`,`maximum`).
- `EntityStorage`: now checks entity fields validity (`EntityField`).

## 1.2.7

- Split `bones_api_entity_adapter.dart` into `bones_api_entity_adapter_sql.dart`.
- `PostgreSQLAdapter`:
  - dialect: "PostgreSQL"
- `MySQLAdapter`:
  - dialect: "MySQL"
- `SQLGenerator`:
  - `generateCreateTableSQL`:
    - Added parameters `ifNotExists` and `sortColumns`. 
    - fix column generation for enum fields.
  - `generateFullCreateTableSQLs`: added parameters `withDate`, `ifNotExists` and `sortColumns`.
- `SQLAdapter` tests:
  - Now is creating tables using `generateFullCreateTableSQLs` (`MySQL` and `PostgreSQL`).

## 1.2.6

- Added `SQLBuilder` that is used to generate the entities `CREATE TABLE` SQLs.
- Added `SQLGenerator` that is capable to generate entities tables and relationships SQLs.
- Split `SQLAdapter` and `SQLAdapterCapability` into `DBAdapterCapability` and `DBAdapter`.
- `SQLAdapter`:
  - Added `generateCreateTableSQLs`, `generateFullCreateTableSQLs`, `generateEntityRepositoresCreateTableSQLs`.
- Added `DBEntityRepositoryProvider` and `SQLEntityRepositoryProvider`.
- statistics: ^1.0.21
- test: ^1.21.4
- dependency_validator: ^3.2.2

## 1.2.5

- sdk: '>=2.15.0 <3.0.0'
- petitparser: ^5.0.0
- hotreloader: ^3.0.5

## 1.2.4

- `SQLAdapter`:
  - Fix `extractSQLs`.
- `APITestConfigDBMemory`:
  - Now starts creating a `MemorySQLAdapter`.
- `APITestConfigDockerPostgreSQL`:
  - Fix `listTables` implementation.
- `APITestConfigDockerMySQL`:
  - Fix `listTables` implementation.

## 1.2.3

- `APIRootStarter`:
  - Added `isStopped`.
  - Improved documentation.
  - Improved tests.
- `APIRouteBuilder`:
  - `apiInfo` now also returns `APIRouteInfo` for method specific routes.
- `APITestConfig`:
  - Added `resolveSupported`, `isSupported`, `isUnsupported` and `unsupportedReason`. 
  - New `APITestConfigDockerDBSQL`: adding SQL methods for DB containers with SQL support.
- Better hierarchy of  `APITestConfig` implementations.
- `LoggerHandler`:
  - Exposed global function `logToConsole`.
  - Added `cancelLogToConsole`.
- Added library `bones_api_test_vm.dart`.
  - Exposes `resolveFreePort` (now uses a random approach to avoid collision between parallel tests).
- docker_commander: ^2.0.15

## 1.2.2

- Fix library names:
  - `bones_api_test`
  - `bones_api_test.mysql`.
  - `bones_api_test.postgres`.

## 1.2.1

- `EntityAccessor`: added `nameSimplified`.
- `LoggerHandler`:
  - `logToConsole`: avoid multiple listeners to the root logger.
- `APITestConfigDocker`: remove unnecessary call to `logToConsole()`.
- Fix imports at `bones_api_root_starter.dart`.

## 1.2.0

- Added `APIRootStarter` helper.
- Added `APITestConfig`: an `APIRoot` test helper.
- Added `APITestConfigDocker`, a base class for `Docker` database containers:
  - `APITestConfigDockerMySQL` (MySQL container)
  - `APITestConfigDockerPostgreSQL` (PostgreSQL container)
- `APIConfig`: now supports variables (%VAR_NAME%).
- `SQLAdapterCapability`: added capability `tableSQL`.
- `SQLAdapter`:
  - Added parameters `populateTables` and `populateSource` (previously present only for `MemorySQLAdapter`).
  - Added `populateTables` and `executeTableSQL` methods.
  - `generateInsertSQL`: fix issue when all values are null. 
- `MySQLAdapter` and `PostgreSQLAdapter`:
  - Improved automatic resolution of relationship tables.
- `MemorySQLAdapter`:
  - `populateFromSource` moved to `EntityRepositoryProvider` extension.
- `APIPlatform`:
  - `getProperty`: read a property from an "environment variable" (VM) or `window.location.href` (Browser).
- `APISession` and `APISessionSet`: moved to `bones_api_session.dart`.
- Change named parameter `caseInsensitive` to `caseSensitive` to follow `RegExp` parameters naming style.
- Split `bones_api_utils.dart` in multiple utils files:
  - `bones_api_utils_collections.dart`
  - `bones_api_utils_httpclient.dart`
  - `bones_api_utils_json.dart`
  - `bones_api_utils_timedmap.dart`
- docker_commander: ^2.0.14

## 1.1.34

- `MemorySQLAdapter`:
  - Consolidating tables after a transaction is finished, removing unnecessary history data. 
- map_history: ^1.0.2

## 1.1.33

- mysql1: ^0.20.0
- postgres: ^2.4.5
- lints: ^2.0.0
- coverage: ^1.3.2

## 1.1.32

- `MemorySQLAdapter`:
  - Using `MapHistory` for internal representation, to allow rollback of transactions.
  - `SQLAdapterCapability`:
    - `transactionAbort`: `true` (rollback support). 
- Tests for `SQLAdapter`:
  - Improve detection of `Docker` daemon and skipping of tests group when `Docker` is not running.
- map_history: ^1.0.1

## 1.1.31

- `EntityHandler`:
  - `castListNullable` and `castIterableNullable`. 
  - `castList`:
    better exception message when an element is null.
- `Condition`:
  Better resolution and matching of JSON collections and entities.
- `KeyCondition`:
   - Fix `_resolveValueEntityHandler` for `List` entities types.
- `MemorySQLAdapter`:
  - Fix `_normalizeEntityJSON`.

## 1.1.30

- `MemorySQLAdapter`:
  - Ensure that the stored data has only valid JSON values for the whole entity tree.
- `EntityRepository`:
  - Added `isOfEntityType`.

## 1.1.29

- `EntityRepository`:
  - Added `deleteEntity`, `deleteByID` and `deleteEntityCascade`.
- `EntityHandler`:
  - Renamed `isValidType` to `isValidEntityType`.
- shelf: ^1.3.1
- shelf_static: ^1.1.1
- reflection_factory: ^1.2.0
- postgres: ^2.4.4

## 1.1.28

- `EntitySource`:
  - Added `selectFirstByQuery`.
- Clean code.

## 1.1.27 

- `Initializable`:
  - `Initializable.initialize`:
    Now returns a `InitializationResult`, allow improved results and dependencies in the result.
  - Improve automatic detection of circular dependencies and avoid deadlocks.
  - Refactor of dependency chain analysis code.

## 1.1.26

- `Initializable`:
  - Moved code to `bones_api_initializable.dart`.
  - Initialization of circular dependencies:
    - Automatically identify initialization of circular dependencies.
    - "Fix" the asynchronous deadlock caused by wait of circular dependencies.

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
