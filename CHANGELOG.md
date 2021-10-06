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
