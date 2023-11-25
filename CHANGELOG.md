## 1.5.2

- `APIServerConfig`:
  - Fix `name` and `version` resolution

## 1.5.1

- new `APIServerConfig`:
  - Holds the configuration need for `APIServer` and `APIServerWorker`.
  - Can be created from command-line arguments or a JSON object.

- Created an abstract base class `_APIServerBase` for  `APIServer` and `APIServerWorker`.
  - `start` and `stop` methods, delegating to `startImpl` and `stopImpl`.
  - Add a new boolean property `isStarting` to determine if the server is in the process of starting.

- `APIServer`
  - Support for spawning auxiliary workers in separate isolates when needed.
  - Starting and stopping of auxiliary `APIServerWorker` instances using isolates. Main worker starts normally.

- New `APIServerWorker` to handle multi-worker `APIServer`.
  - Add `_processWhileInitializing` to handle API requests while the server is still initializing,
    including a timeout for initialization.

- `APIRequest`:
  - Can also handle metrics.
  - Added `transactions` field, automatically populated with all the `Transactions` of the request.

- `APIRequest` and `APIResponse`:
  - Improved metrics: added `description` parameter.
  - Added `Transaction`s duration to `Server-Timing`.

- `APIRoot:`
  - Added `isIsolateCopy`.

- `DBAdapterCapability`:
  - Added `multiIsolateSupport`;

- `DBAdapter`
  - Added `auxiliaryMode` and `enableAuxiliaryMode`.
  - `DBSQLMemoryAdapter` and `DBObjectMemoryAdapter` don't support `auxiliaryMode`, since they don't support `multiIsolateSupport`.

- `SQLGenerator.generateCreateTableSQL`: skip annotated hidden fields.

- `APISessionSet`: using `SharedStoreField` and `SharedMapField` to store the the sessions.

- New `APITokenStore`:
  - Shared tokens among `Isolate`s. 

- shared_map: ^1.0.10
- args_simple: ^1.1.0
- coverage: ^1.7.1
- vm_service: ^13.0.0

## 1.5.0

- sdk: '>=3.2.0 <4.0.0'
  - Simple workaround for Kernel/Fasta issue https://github.com/dart-lang/sdk/issues/54062

- reflection_factory: ^2.2.4

## 1.4.37

- `DBObjectGCSAdapter`:
  - Fix cached file parent directory creation. 

## 1.4.36

- `APIConfig`: fix resolution of variables keys.
- `DBAdapter`:
  - Added parameter `populateSourceVariables`: allow variables in populate source.
- Improved related tests.

- data_serializer: ^1.0.12
- hotreloader: ^4.1.0

## 1.4.35

- `DBSQLMemoryAdapter._findFieldsReferencedTables`: Fix referenced field name.

## 1.4.34

- `APIConfig`: added field `test`.
- `DBSQLMemoryAdapter`:
  - Fix `_findFieldsReferencedTables`:
    - Normalize entity field to table column name.
- `DBSQLAdapter`:
  - Fix`_checkDBTableScheme`:
    - Normalize entity field to table column name.
  - Fix `checkDBTableField`:
    - Allow `EntityReferenceList` fields.

## 1.4.33

- `EntityReferenceBase`: added `isNotNull`.
- New `NullEntityReferenceBaseExtension` and `NullEntityReferenceExtension`.
- meta: ^1.11.0
- hotreloader: ^4.0.0
- archive: ^3.4.6

## 1.4.32

- `APIModuleProxy`: added `ignoreMethods`.
- reflection_factory: ^2.2.3

## 1.4.31

- Added `EntityHandler.constructors`.
- `EntityHandler._createFromMapDefaultImpl`: improve `UnsupportedError` message.

- statistics: ^1.0.26
- data_serializer: ^1.0.11
- docker_commander: ^2.1.5
- postgres: ^2.6.3
- archive: ^3.4.5
- collection: ^1.18.0
- dependency_validator: ^3.2.3
- coverage: ^1.6.4
- test: ^1.24.7

## 1.4.30

- `EntityResolutionRules`:
  - New factory constructor `fetchTypes`.

- docker_commander: ^2.1.2

## 1.4.29

- New abstract class `DBConnectionWrapper`:
  - Implementations `DBMySqlConnectionWrapper` and `PostgreSQLConnectionWrapper`.
- `Pool`
  - Added `createPoolElementForced` (non-nullable).
  - `_catchFromPopulatedPool`: now can return null. 
- `DBAdapter`:
  - New `connectionInactivityLimit`.
  - `isConnectionValid`:
    - `MySQL` and `PostgreSQL`: checking `connection.isInactive`.
 
- Using `Graph` to resolve the correct order of `CreateTableSQL` and to populate samples.
- Checking `SQLBuilder` order and warning invalid orders.

- `EntityReferenceList.fromJson`:
  - Fix issue with some entities null in the JSON.
- `APIRouteBuilder._apiMethodInvocation`:
  - Check if returned value is a `FutureOr<APIResponse>` or return an `APIResponse.error`.

- graph_explorer: ^1.0.2
- ascii_art_tree: ^1.0.6
- docker_commander: ^2.1.1
- petitparser: ^6.0.1
- archive: ^3.3.9

## 1.4.28

- `getTableScheme`, `getTableSchemeImpl` and `getTableSchemeForEntityRepository`:
  - Added optional `contextID` parameter to allow multiple calls with the
    same `contextID` to share internal caches.
- `DBMySQLAdapter` and `DBPostgreSQLAdapter`:
  - Optimize `getTableScheme` and `getRepositoriesSchemes`
    with use of `contextID` and internal shared caches.

- async_extension: ^1.2.5

## 1.4.27

- `DBSQLAdapter`:
  - `_checkDBTableScheme`: ignore fields annotated with `EntityField.hidden`.
- reflection_factory: ^2.2.1
- mercury_client: ^2.2.0
- archive: ^3.3.8

## 1.4.26

- `APIServer`:
  - Integrate `LetsEncrypt` logger with `APIServer` logger.
- shelf_letsencrypt: ^1.2.2
- dart_spawner: ^1.1.0
- vm_service: ^11.10.0

## 1.4.25

- `SQLBuilderListExtension`:
  - `bestOrder`: fix dependencies order of table relationships.
- `EntityRepositoryProviderExtension`:
  - `storeAllFromJson`: store by `allRepositories` orders.

## 1.4.24

- async_extension: ^1.2.3
- docker_commander: ^2.1.0 

## 1.4.23

- New `FutureOrAPIResponseExtension` and `FutureAPIResponseExtension`.

- async_extension: ^1.2.2
- reflection_factory: ^2.2.0

## 1.4.22

- `APIServer`:
  - `_resolvePayload`:
    - Better resolution of `MimeType` when `content-type` header is not provided.
    - String `MimeType`s: use `charsetEncoding` to decode the `String`.
    - Optimize load of payload bytes as `Uint8List`.

- async_extension: ^1.2.0
- data_serializer: ^1.0.10
- gcloud: ^0.8.11
- test: ^1.24.6
- vm_service: ^11.9.0

## 1.4.21

- `ConditionSQLEncoder`:
  - `resolveValueToCompatibleType`: force `DateTime.toUtc()` to avoid DB adapter issues.
- `Transaction`
  - Added `waitOperation`.
    - Added `timeout` parameter.
- `EntityRepository`:
  - `ensureStored` implementations (`DBRelationalEntityRepository`, `DBEntityRepository`, `IterableEntityRepository`):
    - Avoid multiple `store` of the same entity in the same [Transaction].
      - Fix issue with unique fields.
    - Throws `RecursiveRelationshipLoopError` if a loop is detected. 
- `EntityFieldInvalid`:
  - Added field `operation`. 
- Added missing `APIRequestMethod.HEAD`.
- `EntityHandler`:
  - Avoid recursive loop call to `_validateFieldValueImpl`.
- `APIDBModule`:
  - select: sort entities by id.
  - update: fix enum selected option (`HTMLInput`).
- `LogFileRotate`:
  - Fix `needRotation` for a log file not created yet.

- async_events: ^1.0.12
- stream_channel: ^2.1.2
- gcloud: ^0.8.10
- postgres: ^2.6.2
- petitparser: ^5.4.0

## 1.4.20

- `ConditionElement`:
  - Added field `parent`.
  - Added `isInner`.
- `EncodingContext`:
  - `resolveEntityAlias`:
    - Better alias naming for `_ref` and `_rel` tables.
    - Better naming for long names.
- `DBRelationalEntityRepository._getCachedEntitiesRelationships`:
  - Fix issue with `EntityReferenceList` and `EntityReference` values.
- New `LogFileRotate` (used by default when logging to files).
- `APIServer`: log `Response.internalServerError` (error 500  responses) as severe.

- shelf_letsencrypt: ^1.2.1
- http: ^1.1.0

## 1.4.19

- Update `bones_api_template.tar.gz`.

## 1.4.18

- `ConditionEncoder`:
  - `encodeEncodingValueList`: fix SQL encoding of empty list as `( null )` and not `( )`.

## 1.4.17

- `logErrorMessage` and `logDBMessage`: fix resolution of `MessageLogger`.

## 1.4.16

- API Config:
  - Allow  `log.all`, `log.error` and `log.db` to files.
- `DBAdapter`:
  - Better `boot` hierarchy.
  - `registerAsDbLogger` loggers of implementations of `DBAdapter`.
- `LoggerHandler`:
  - Added `resolveLogDestiny` and `logBuffered`.
- `DBAdapterException`:
  - Added field `operation`. 

## 1.4.15

- `SQLBuilderListExtension`:
  - Optimize `bestOrder`:
    - Use internal Quick Sort algorithm for better pivot selection (producing a better order of elements).

## 1.4.14

- `APIRouteBuilder.apiMethod`:
  - Ignores framework methods from `APIModule` that could be interpreted as routes.
- `SQLBuilder`:
  - Added `mainTable` getter.
    - Used for better sorting using table name (`sorteByName`).

- resource_portable: ^3.1.0
- collection: ^1.17.2
- test: ^1.24.4
- vm_service: ^11.8.0

## 1.4.13

- `Initializable._finalizeInitializationWithDeps`:
  - When finalizing root `Initializable`: wait for still initializing dependencies. 
- Fix `InitializationChain._completeCircularDependency`:
  - Check if `Completer` is already completed before call `complete`.
- build_runner: ^2.4.6

## 1.4.12

- Fix `GroupConditionOR.cast`.
- `ConditionSQLEncoder.keyFieldReferenceToSQL`: throw exception when a field can't by found in table.

## 1.4.11

- Added `APIModuleProxyCaller` and `APIModuleProxyDirectCaller`.
- Rename `APIModuleHttpProxy` to `APIModuleProxyHttpCaller`.
- reflection_factory: ^2.1.6

## 1.4.10

- Added `StringUtils.toLowerCaseSimpleCached`.
- Optimize `Json.defaultFieldNameResolver`. 
- Optimize `FieldsFromMap.getFieldsValuesFromMap`.

- async_extension: ^1.1.1
- reflection_factory: ^2.1.4

## 1.4.9

- New `WeakList`.
- Added `DBAdapter.instances`.
- `Transaction`:
  - `_onErrorZoneUncaughtError`: get the `error`'s `Transaction` and pass it to `printZoneError` as message.
  - Added `Transaction.openInstances`.
  - Added `canPropagate` to indicated that a `Transaction` can have multiple operations.
  - Added `initTime`, `endTime` and `duration` getters.
  - Log slow and long transactions.
  - `_onExecutionError`: only logs and rethrows the error in the 1st error notification.
  - `_abortImpl`:
    - call `_transactionCompleter.complete` instead of `completeError` to avoid issues with hidden error `Zone`.
- `TransactionOperation`:
  - Added `initTime`, `endTime` and `duration` getters.
- `TransactionAbortedError`:
  - Renamed `abortError` to `error`.
  - Renamed `abortStackTrace` to `errorStackTrace`.
- Added `APIRouteConfig`.
- `APIRouteHandler.call`: log response time.
- `DBMySQLAdapter` and `DBPostgreSQLAdapter`.
  - Allow `minConnections` and `maxConnections` from config.
  - `getTableSchemeImpl` and `getTableFieldsTypesImpl`: fix `releaseIntoPool` and `disposePoolElement` behavior.
- `DBEntityRepository`: optimize `_getRelationshipFields`.
- `DBAdapter`:
  - added `isTransactionWithSingleOperation`.
  - Fix `executeTransactionOperation`: identify single operation transactions.
  - Fix `createPoolElement`: respect `maxConnections` with correct `poolAliveElementsSize` calculation.
  - Added `cancelTransactionResultWithError, `throwTransactionResultWithError` and `resolveTransactionResult`.
    - Used by `openTransaction` result resolution.
- `Pool`:
  - Fix `poolDisposedElementsCount` to also count `_invalidatedElementsCount`.
  - Fix `_catchFromEmptyPool`:
    - allow `createPoolElement(force: true)` if reached the limit and can't catch a reused element. 
- `InitializationStatus`:
  - New `finalizing` status.
- `InitializationChain`:
  - Fix `_isParent`
    - Avoid analyzing dependencies of `initializable` if it exists in the parent's tree.
- `Initializable`
  - `_doInitializationImpl`: allow circular initialization with timeout.

- lints: ^2.1.1
- build_runner: ^2.4.5

## 1.4.8

- `DBEntityRepository`
  - `_resolveEntitiesSubEntities`: fix passing of parameter `resolutionRules` on special case.

- args: ^2.4.2

## 1.4.7

- `APIServer`:
  - `_redirectToHttpsMiddleware`: do not redirect `/.well-known/acme-challenge/` paths.
- sdk: '>=3.0.0 <4.0.0'
- collection: ^1.17.1
- googleapis_auth: ^1.4.1
- shelf_letsencrypt: ^1.2.0
- lints: ^2.1.0

## 1.4.6

- `ConditionEncoder`:
  - Fix `_resolveValueToTypeImpl`:
    - Convert `Enum` values to `String` calling `Enum.name`.
    - Convert `Enum` values to `int|num|BigInt` calling `Enum.index`.
- reflection_factory: ^2.1.3

## 1.4.5

- `DBSQLAdapter`:
  - Now checks for missing reference columns.
  - Suggest `ALTER TABLE` with CONSTRAINTs.
- `SQLGenerator`:
  - `generateAddColumnAlterTableSQL`:
    - Handle enums and references.
    - Generate CONSTRAINTs for `FOREIGN KEY` and `UNIQUE`.

## 1.4.4

- `AlterTableSQL`:
  - Added `indexes`.
  - `buildSQL`: implement `ifNotExists` for `ADD COLUMN`.
- `SQLGenerator`:
  - Added `generateAddColumnAlterTableSQL`.
- `DBSQLAdapter`:
  - `checkDBTables`:
    - Now prints in the log a suggestion of `ALTER TABLE` SQLs to fix missing table columns.
- args: ^2.4.1
- crypto: ^3.0.3
- gcloud: ^0.8.8
- http: ^0.13.6
- shelf: ^1.4.1
- shelf_static: ^1.1.2
- yaml: ^3.1.2

## 1.4.3

- `DBAdapter`:
  - Added `checkDB`: checks DB tables and fields.
    - Moved call to `generateTables` to `checkDB`. 
  - `createPoolElement`: optimize calls to `createConnection` when creating multiple connections simultaneously.
- `FieldsFromMap`:
  - Added `getFieldsKeysInMap`.
- `TableScheme`:
  - Added `relationshipTables`.
- `EntityHandler`:
  - Fix `valueToDynamicNumber` for `DateTime` types.
- Added `APIEntityTypeNullableExtension` to avoid resolution to `APIEntityObjectExtension` on `Type?` variables.
- `SQLBuilder`: added logger and messages.
- `DBMySQLAdapter`:
  - Decode `TIME` SQL type as `Time` class. 
- sdk: '>=2.18.0 <4.0.0'

## 1.4.2

- `Json`:
  - Fix `_jsonEncodableProvider`: do not use `EntityHandler` if there's a registered `ClassReflection`.
- `APIServer`:
  - Fix `_toJsonEncodableAccessRules` when there's an `EntityAccessRules` for
    an entity but there's no encodable function.

## 1.4.1

- `APIModuleHttpProxy`:
  - Force `POST` request if any parameter is a `List` or `Map`. 
- `APIRouteBuilder.resolveValueByType`:
  - Renamed: `_resolveValueType` to `resolveValueByType`
  - Exposed and static.
  - Fix parsing of typed `List`, `Set` and `Map` parameters.
  - Improved tests.
- reflection_factory: ^2.1.2

## 1.4.0

- reflection_factory: ^2.1.0

## 1.3.69

- `APIAuthentication`:
  - Added `_credential` field to allow return (by `get credential`) of the `APICredential` instance used in the authentication process. 

## 1.3.68

- `APISecurity`:
  - Added `authenticateMultiple` for when the request has an `APICredential` and also a payload with credential.
- `APICredential`:
  - Added `originalCredential` field.
  - Added `APICredential.fromMap` and `checkCredential`.
- `APIDBModule`: Added `credential` support.
- async_events: ^1.0.11
- test: ^1.24.1

## 1.3.67

- `Time.toString`:
  - Fix `withSeconds` parameter.
- Added `Time.copyWith`.

## 1.3.66

- reflection_factory: ^2.0.7
- hotreloader: ^3.0.6
- statistics: ^1.0.25
- petitparser: ^5.3.0
- meta: ^1.9.1

## 1.3.65

- `decodeQueryStringParameters`:
  - Added parameter `charset`.
- swiss_knife: ^3.1.5
- resource_portable: ^3.0.2
- archive: ^3.3.7

## 1.3.64

- `APIRoot`:
  - Added `loadDependencies`.

## 1.3.63

- New `HTMLDocument`.
- `APIDBModule`:
  - Added insert & update support.
  - Added delete operation.
  - Added UI (HTML).
- `EntityHandler`:
  - Added `resolveIDs`.
  - Improve `resolveValueByType`.
- reflection_factory: ^2.0.6

## 1.3.62

- `EntityReferenceList`:
  - Fix `add`.

## 1.3.61

- Added `CreateIndexSQL`.
- `EntityField`:
  - Added `_indexed` and `isIndexed`.
  - Added constructor `EntityField.indexed()`.
- `DBSQLAdapter`:
  - Added getter `entityRepositoriesBuildOrder`.
- `DBAdapter`:
  - `allRepositories`:
    - Use `entityRepositoriesBuildOrder` to return the repositores in the build order.
- `APIDBModule`:
  - `tables`: list repositories ordered by name.
  - `dump`: list repositories in build order to allow use of the dump to populate a DB. 

## 1.3.60

- `ConditionEncoder`:
  - Fix queries using values of type `Decimal` or `DynamicInt`. 
- `ConditionSQLEncoder`:
  - Handle `Decimal` as `double`.
  - Handle `DynamicInt` as `BigInt`.

## 1.3.59

- `DBObjectGCSAdapter`:
  - Fix call to `bucket.info`: replace with `_getObjectInfo` & try/catch.

## 1.3.58

- New `DBObjectGCSAdapter`.
- New library: `bones_api_db_gcp.dart`.
- `DBObjectDirectoryAdapter`: clean code.
- `DBEntityRepositoryProvider`:
  - Added `requiredAdapters` and `requiredEntityRepositoryProviders`:
    - Used by `initializeDependencies`.
- reflection_factory: ^2.0.5
- http: ^0.13.5
- googleapis_auth: ^1.4.0
- crclib: ^3.0.0

## 1.3.57

- New `DBObjectAdapter`:
  - Base class for `DBObjectMemoryAdapter` and `DBObjectDirectoryAdapter`.
- New `DBAdapterRegister`:
  - handles `DBAdapter` registration, avoiding repetitive static code in
    `DBSQLAdapter`, `DBObjectAdapter` and `DBRelationalAdapter`.
- `EntityHandler`
  - Added `equalsValuesEntityMap`.
  - Added `getEntityIDFrom`.
  - `equalsValuesEntity` now also using `equalsValuesEntityMap`.
    - This fixes an issue for `DBSQLMemoryAdapter`. 

## 1.3.56

- `EntityReference`:
  - `disposeEntities`: force `_resolveID` before dispose.
- `EntityReferenceList`:
  - `disposeEntities`: force `_resolveIDs` before dispose.
- `APIRouteBuilder`:
  - `_resolveValueType`: resulve `List`, `Set`, `Map` generic types. 

## 1.3.55

- `APIResponseStatus`
  - Added `REDIRECT`: to perform URL/Location redirects.

## 1.3.54

- `DBObjectDirectoryAdapter`:
  - `_normalizeID`: ensure safe ID for `File` path.
- `EntityReferenceBase`:
  - Improve `_getEntityID`: allow use of `dynamic.id` if there's not `EntityHandler`. 

## 1.3.53

- petitparser: ^5.2.0
- postgres: ^2.6.1

## 1.3.52

- Renamed `DBMemorySQLAdapter` to `DBSQLMemoryAdapter`.
  - Renamed `DBMemorySQLAdapterException` to `DBSQLMemoryAdapterException`.
- `DBSQLMemoryAdapter`: `name` changed to "sql.memory".
- `DBObjectMemoryAdapter`: `name` changed to "object.memory".
- `DBMySQLAdapter`: added alias "sql.mysql".
- `DBPostgreSQLAdapter`: added alias "sql.postgresql".
- New `DBObjectDirectoryAdapter`.
- `EntityHandler`:
  - Fix `_resolveValueByEntityHandler` for when `entityRepositoryProvider` is `null`.
- `DBAdapter`:
  - Added `onClose`.

## 1.3.51

- Renamed `DBMemoryObjectAdapter` to `DBObjectMemoryAdapter`.
  - Renamed `DBMemoryObjectAdapterException` to `DBObjectMemoryAdapterException`.

## 1.3.50

- `APIServer`:
  - Added `allowRequestLetsEncryptCertificate`.
- shelf_letsencrypt: ^1.1.1

## 1.3.49

- `EntityHandler`:
  - Optimize `isValidEntityType`.
- `APIToken`:
  - Optimize `generateToken`.
- `IterableEntityRepositoryProviderExtension`:
  - `getEntityRepository`: added parameter `removeClosedProviders`.
- reflection_factory: ^2.0.4

## 1.3.48

- `APIConfig`:
  - Added `getAsMap`, `getAsList`, `getAs`.
- Added `WithRuntimeTypeNameSafe`.
- Added `ExtensionRuntimeTypeNameUnsafe`:
  - `runtimeTypeNameUnsafe`
- Added linter rules:
  - `avoid_dynamic_calls`.
  - `avoid_type_to_string`.
  - `no_runtimeType_toString`.
  - `discarded_futures`.
  - `no_adjacent_strings_in_list`.

## 1.3.47

- Improve internal use of `EntityCache`.
- `EntityReferenceBase`:
  - Added `_entityCache`.
- Optimize `_InitializationChain._isParent`.
- `APIModuleHttpProxy`:
  - `onCall`: using `Json.decoder` with `EntityHandlerProvider.globalProvider`.
- `Json`:
  - Added `decoder`.
- reflection_factory: ^2.0.3

## 1.3.46

- `Json.defaultFieldValueResolver`:
  - Improve resolution of `EntityReference` and ``.
- reflection_factory: ^2.0.1

## 1.3.45

- `KeyCondition`: added support to `>`, `>=`, `<` and `<=` operators. 
  - `KeyConditionGreaterThan`, `KeyConditionGreaterThanOrEqual`.
  - `KeyConditionLessThan`, `KeyConditionLessThanOrEqual`.
- `EntityHandler.createFromMap`: added parameter `jsonDecoder`.

## 1.3.44

- `APIRouteRule`:
  - Adde properties `globalRules` and `noGlobalRules`.
- archive: ^3.3.6
- args: ^2.4.0

## 1.3.43

- Added `APIEntityRules`.

## 1.3.42

- New `APIEntityAccessRules`, `EntityAccessRules`, `EntityAccessRulesCached` and `EntityAccessRulesContext`:
- Renamed `MergeEntityResolutionRulesError` to `MergeEntityRulesError`.
- Renamed `ValidateEntityResolutionRulesError` to `ValidateEntityRulesError`.
- `EntityAccessRules` and `EntityResolutionRules` now extends `EntityRules`.
- `APIRouteHandler`:
  - Added `entityAccessRules`.
  - Optimize `entityResolutionRules`.
- `APIResponse`:
  - Added field `apiRequest`.
- `EntityReferenceBase`:
  - `toJson`: added parameter `jsonEncoder`.
    - Fixes some to JSON issues, preserving the parent `jsonEncoder`. 
- `Json`:
  - `toJson`: expose parameter `toEncodableProvider`.
- `APIServer`:
  - `resolveBody`:
    - When converting to JSON respect the `EntityAccessRules` of the context.
- test: ^1.23.1

## 1.3.41

- `EntityResolutionRules`:
  - Added `mergeTolerant`.
  - `copyWith`: added `conflictingEntityTypes`.
  - `merge`: allowing conflicting merge when `mergeTolerant` is present.

## 1.3.40

- `EntityResolutionRules`:
  - Added `innocuous` const instance.
  - Added: `isInnocuous`, `isValid`, `validate`.
  - Added: `copyWith` and `merge`.
  - Added `ValidateEntityResolutionRulesError` and `MergeEntityResolutionRulesError`.
- Added `EntityRulesResolver`.
  - `resolveEntityResolutionRules`: returns a `EntityResolutionRulesResolved`.
  - Added `registerContextProvider(EntityRulesContextProvider)`.
- `APIRoot`:
  - Initialization register: `EntityRulesResolver.registerContextProvider`.
- Added `APIEntityResolutionRules`.
- `APIRouteHandler`: added `entityResolutionRules`.
- `APIRequest`: added `routeHandler`.
- Moved entity rules classes to `bones_api_entity_rules.dart`.

## 1.3.39

- `APIRoot._callZoned`:
  - Better handling of errors: throwing with `StackTrace`. 
- `EntityResolutionRules`:
  - Added `isEagerEntityTypeInfo` and `isLazyEntityTypeInfo`.
- `DBEntityRepository`:
  - Optimize: `resolveEntities` and `_resolveEntitiesSubEntities`.
- `APIServer`:
  - `_sendAPIResponse`: better handling of error response.
- `Time.parse`:
  - Fix issue parsing input `String` as bytes.  
- coverage: ^1.6.3

## 1.3.38

- `SQLGenerator`:
  - Remove unecessary `UPDATE CASCADE` for `id` (auto increment) references.
- reflection_factory: ^2.0.0
- async_events: ^1.0.9

## 1.3.37

- `TransactionEntityProvider`:
  - Fix `getEntityByID` implementation: wasn't passing parameter `resolutionRules` to sub-calls.
- reflection_factory: ^1.2.25

## 1.3.36

- `DBRelationalEntityRepository`:
  - `_ensureRelationshipsStored`: avoid store of relationship fields if not in `changedFields`.
- `DBMemorySQLAdapter` and `DBMemoryObjectAdapter`:
  - Construct `TableScheme` without relationship fields duplicated in the main fields.
- args: ^2.3.2
- reflection_factory: ^1.2.22

## 1.3.35

- New `testAPIServer` tool.
- Updated `bones_api_template.tar.gz`.
- shelf_gzip: ^4.0.1
- mime: ^1.0.4
- stream_channel: ^2.1.1
- test: ^1.22.2
- coverage: ^1.6.2

## 1.3.34

- reflection_factory: ^1.2.21

## 1.3.33

- reflection_factory: ^1.2.19

## 1.3.32

- `APIServer`:
  - `defaultApiCacheControl` and `defaultStaticFilesCacheControl`:
    - Added `no-transform` directive.
- reflection_factory: ^1.2.18

## 1.3.31

- `APIServer`:
  - Optimize headers.
  - Added fields: `apiCacheControl` and `staticFilesCacheControl`.
  - Better `cache-control` default values.

## 1.3.30

- statistics: ^1.0.24
- resource_portable: ^3.0.1
- swiss_knife: ^3.1.3
- archive: ^3.3.5
- mercury_client: ^2.1.8

## 1.3.29

- `DBAdapter` and `DBRepositoryAdapter`:
  - Added `doSelectAll`
- `DBMemoryObjectAdapter`:
  - Added support for `doSelectAll`.
- `APIDBModule`:
  - Added `dump` route.
  - JSON output compact: compatible with DB populate source samples.
- mime: ^1.0.3  
- path: ^1.8.3
- yaml_writer: ^1.0.3
- build_runner: ^2.3.3
- build_verify: ^3.1.0
- test: ^1.22.1

## 1.3.28

- `APIRoot._callZoned`: fix error handling.

## 1.3.27

- `APIDBModule`:
  - Added constructor parameter `name` and `onlyOnDevelopment`.
- `APISecurity`:
  - Allow call to `authenticate` with `request` parameter from an `APIModule`.

## 1.3.26

- `APIModule`:
  - Allow method routes with parameter `APIAuthentication`.
- `APIRoot._callZoned`: ensure that is catching `Future` errors.
- Added `APIConfig.development` to inform development environment. 
- Added `APIDBModule`: a development module only to show DB entities.

## 1.3.25

- `APISecurity`:
  - Added `disposeAuthenticationData`.
- swiss_knife: ^3.1.2
- pubspec: ^2.3.0
- coverage: ^1.6.1

## 1.3.24

- `APIResponse`:
  - Fix constructor parameter `headers` to ensure that it's always modifiable.
- `APIServer`:
  - Static files:
    - Added `gzip` encoding.
    - Added `cache-control` response header.
- logging: ^1.1.0
- collection: ^1.17.0
- mercury_client: ^2.1.7
- async_events: ^1.0.8
- archive: ^3.3.4
- lints: ^2.0.1
- build_runner: ^2.3.2
- test: ^1.22.0

## 1.3.23

- `APISecurity`:
  - Added `logout` and `invalidateToken`.
- Fixed `OPTIONS` method for `authenticationRoute` (`/authenticate`).
- sdk: '>=2.18.0 <3.0.0'
- petitparser: ^5.1.0

## 1.3.22

- reflection_factory: ^1.2.17
- async_events: ^1.0.7

## 1.3.21

- `APIServer`:
  - Added `useSessionID` to enable/disable the `SESSIONID` cookie.
  - Added option `cookieless` for a server that blocks all cookies.
  - Added support for `Keep-Alive`.
- `APIRequest`:
  - Added `protocol` and `keepAlive`.
- `APIResponse`:
  - Added `keepAliveTimeout` and `keepAliveMaxRequests`.

## 1.3.20

- reflection_factory: ^1.2.16

## 1.3.19

- `ClassReflectionExtension`:
  - Added: `toEntityReference`, `toEntityReferenceList` and `toList`.
- `TypeInfoEntityExtension`:
  - Added `isValidEntityReferenceType` and `isValidEntityReferenceListType`.
- `JsonDecoder.registerTypeDecoder` for `EntityReference` and `EntityReferenceList`:
  -  Allow decoding of `null` values as `EntityReference.asNull` and `EntityReferenceList.asNull`.
- reflection_factory: ^1.2.15
- shelf: ^1.4.0
- postgres: ^2.5.2
- build_runner: ^2.2.1
- test: ^1.21.6

## 1.3.18

- `APIRoot.resolveModule`: defaults to path part `#0`.
- `APIModule.resolveRoute`: defaults to path part `#1 ?? #0`.
  - Ensure that any route resolution passes through `resolveRoute` method (allowing personalization).
- `APIRouteBuilder`: allow path parts as parameter value by `parameterIndex`.
- reflection_factory: ^1.2.14

## 1.3.17

- Added `Etag`: `WeakEtag` and `StrongEtag`.
- Added `CacheControlDirective` and `CacheControl`.
- `APIResponse`:
  - Added `payloadETag` and `cacheControl`.
  - Added `APIResponse.notModified`.
- archive: ^3.3.1

## 1.3.16

- `APISecurity`:
  - Adjust `_storeTokeInfo`.
- async_events: ^1.0.6

## 1.3.15

- `DBSQLAdapter.generateCreateTableSQLs`:
  - Fix CREATE TABLE SQLs order when a field is referencing to another DB. 

## 1.3.14

- `APISecurity`:
  - `getCredentialPermissions`: Added parameter `previousPermissions`.
  - `getAuthenticationData`: Added parameter `previousData`.
- async_events: ^1.0.5

## 1.3.13

- Ensure that parameter `EntityResolutionRules? resolutionRules` is
  fully propagated while fetching and resolving entities.
- Added `TransactionEntityProvider` to correctly resolve entities while
  calling `entityHandler.createFromMap` inside a `Transaction`.
- `EntityReferenceBase`:
  - Added `typeName` for correct generation of JSON.
  - Added parameter `withEntity` to `copy`.
- Export `MimeType` and `DataURLBase64` from package `swiss_knife`.
- reflection_factory: ^1.2.13

## 1.3.12

- Add `EntityHandler.typeName` to avoid minification issues with `Type`s name.
- async_events: ^1.0.4
- reflection_factory: ^1.2.12

## 1.3.11

- `DBAdapter`:
  - Fix resolution of `EntityReferenceBase` field table. 
- `DBMemorySQLAdapter`:
  - Fix resolution of relationship tables with multiple candidates.

## 1.3.10

- `EntityReference.fromID`: accepts null ID (works like `asNull`).
- `Initializable`:
  - `InitializationChain._isParent`: improve speed of search in the parent tree.
- Fix update of `Uint8List` fields. 

## 1.3.9

- Improved `enumFromName`.
- Added `IterableEnumExtension`.
- Added `Type.tryParse`.
- `EntityReference` and `EntityReferenceList`:
  - improve `fromJson`.
- Fix `EntityRepository.selectFirstByQuery`:
  - `resolutionRules` wasn't being passed to sub calls.

## 1.3.8

- Added `APIRequest.id`.
- Added `APIRoot.currentAPIRequest`.
  - Logging messages now show the current `APIRequest.id`.  
- `/API-INFO`:
  - Now accepts a selected module. Example: `/API-INFO/user`
- Added `APIRequest.parsingDuration`.
- Added `APIRepository.count`.
- Added `DBEntityRepositoryProvider.extraDependencies`.
- Added `Transaction.parentTransaction`:
  - `cacheEntity` now also propagates cache to `parentTransaction`.
- `EntityHandler`:
  - `Uint8List` resolution: now accepts `base64`, `HEX` and `Data URL`. 
- Added `EntityReferenceList`: a version of `EntityReference` for entities lists.
- Fix `EntityRepository._entitiesTracker`: now tracked fields values are isolated from tracked entity.
- Fix `APISecurity._resolveAuthentication`: avoid multiple parallel calls for user resolution. 
- Added tests for `DBMemoryObjectAdapter`.
- reflection_factory: ^1.2.10

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
- Added `SQLDialect` for better handling of syntax variations.
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
  - Improved subfield match.
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
    since API is spawned in its own Isolate.
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
