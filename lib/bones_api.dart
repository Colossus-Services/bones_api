// Documentation canonicals:
// - Generated with:
//   ## remove the documentation canonicals from this file first.
//   $> dart doc --dry-run 2>/tmp/dartdoc.txt
//   $> cat /tmp/dartdoc.txt | grep "ambiguous reexport " |  awk '{ print $5 }' | sed 's/,//' | awk '{ print "/// {@canonicalFor " $0 "}" }' > /tmp/dartdoc-canonicals.txt
//   $> open /tmp/dartdoc-canonicals.txt
//   ## then sort the documentation canonicals lines to have a deterministic list.
//
/// {@canonicalFor bones_api_authentication.APIAuthentication}
/// {@canonicalFor bones_api_authentication.APICredential}
/// {@canonicalFor bones_api_authentication.APIPasswordHashAlgorithm}
/// {@canonicalFor bones_api_authentication.APIPasswordNotHashed}
/// {@canonicalFor bones_api_authentication.APIPasswordSHA256}
/// {@canonicalFor bones_api_authentication.APIPassword}
/// {@canonicalFor bones_api_authentication.APIPermission}
/// {@canonicalFor bones_api_authentication.APITokenExtension}
/// {@canonicalFor bones_api_authentication.APIToken}
/// {@canonicalFor bones_api_base.APILogger}
/// {@canonicalFor bones_api_base.APIPayload}
/// {@canonicalFor bones_api_base.APIRequestHandler}
/// {@canonicalFor bones_api_base.APIRequestMethodExtension}
/// {@canonicalFor bones_api_base.APIRequestMethod}
/// {@canonicalFor bones_api_base.APIRequesterSourceExtension}
/// {@canonicalFor bones_api_base.APIRequesterSource}
/// {@canonicalFor bones_api_base.APIRequest}
/// {@canonicalFor bones_api_base.APIResponseStatus}
/// {@canonicalFor bones_api_base.APIResponse}
/// {@canonicalFor bones_api_base.APIRootInfo}
/// {@canonicalFor bones_api_base.APIRoot}
/// {@canonicalFor bones_api_base.APIRouteFunction}
/// {@canonicalFor bones_api_base.APIRouteHandler}
/// {@canonicalFor bones_api_base.APIRouteInfo}
/// {@canonicalFor bones_api_base.BonesAPI}
/// {@canonicalFor bones_api_base.CacheControlDirective}
/// {@canonicalFor bones_api_base.CacheControl}
/// {@canonicalFor bones_api_base.Etag}
/// {@canonicalFor bones_api_base.StrongEtag}
/// {@canonicalFor bones_api_base.WeakEtag}
/// {@canonicalFor bones_api_base.parseAPIRequestMethod}
/// {@canonicalFor bones_api_base.parseAPIResponseStatus}
/// {@canonicalFor bones_api_condition.ConditionANY}
/// {@canonicalFor bones_api_condition.ConditionElement}
/// {@canonicalFor bones_api_condition.ConditionID}
/// {@canonicalFor bones_api_condition.ConditionIdIN}
/// {@canonicalFor bones_api_condition.ConditionKeyField}
/// {@canonicalFor bones_api_condition.ConditionKeyIndex}
/// {@canonicalFor bones_api_condition.ConditionKey}
/// {@canonicalFor bones_api_condition.ConditionParameter}
/// {@canonicalFor bones_api_condition.ConditionParseCache}
/// {@canonicalFor bones_api_condition.ConditionQuery}
/// {@canonicalFor bones_api_condition.Condition}
/// {@canonicalFor bones_api_condition.EntityMatcher}
/// {@canonicalFor bones_api_condition.GroupConditionAND}
/// {@canonicalFor bones_api_condition.GroupConditionOR}
/// {@canonicalFor bones_api_condition.GroupCondition}
/// {@canonicalFor bones_api_condition.KeyConditionEQ}
/// {@canonicalFor bones_api_condition.KeyConditionGreaterThanOrEqual}
/// {@canonicalFor bones_api_condition.KeyConditionGreaterThan}
/// {@canonicalFor bones_api_condition.KeyConditionINBase}
/// {@canonicalFor bones_api_condition.KeyConditionIN}
/// {@canonicalFor bones_api_condition.KeyConditionLessThanOrEqual}
/// {@canonicalFor bones_api_condition.KeyConditionLessThan}
/// {@canonicalFor bones_api_condition.KeyConditionNotEQ}
/// {@canonicalFor bones_api_condition.KeyConditionNotIN}
/// {@canonicalFor bones_api_condition.KeyConditionValue}
/// {@canonicalFor bones_api_condition.KeyCondition}
/// {@canonicalFor bones_api_condition_encoder.ConditionEncoder}
/// {@canonicalFor bones_api_condition_encoder.ConditionEncodingError}
/// {@canonicalFor bones_api_condition_encoder.EncodingContext}
/// {@canonicalFor bones_api_condition_encoder.EncodingPlaceholderIndex}
/// {@canonicalFor bones_api_condition_encoder.EncodingPlaceholder}
/// {@canonicalFor bones_api_condition_encoder.EncodingValueList}
/// {@canonicalFor bones_api_condition_encoder.EncodingValueNull}
/// {@canonicalFor bones_api_condition_encoder.EncodingValuePrimitive}
/// {@canonicalFor bones_api_condition_encoder.EncodingValueResolved}
/// {@canonicalFor bones_api_condition_encoder.EncodingValueText}
/// {@canonicalFor bones_api_condition_encoder.EncodingValue}
/// {@canonicalFor bones_api_condition_encoder.SchemeProvider}
/// {@canonicalFor bones_api_condition_encoder.TableFieldReference}
/// {@canonicalFor bones_api_condition_encoder.TableRelationshipReference}
/// {@canonicalFor bones_api_condition_encoder.TableScheme}
/// {@canonicalFor bones_api_condition_encoder.ValueEncoder}
/// {@canonicalFor bones_api_condition_parser.ConditionGrammarDefinition}
/// {@canonicalFor bones_api_condition_parser.ConditionParser}
/// {@canonicalFor bones_api_condition_parser.JsonGrammarDefinition}
/// {@canonicalFor bones_api_condition_parser.JsonGrammarLexer}
/// {@canonicalFor bones_api_condition_parser.JsonParser}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeChars2}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeCharsString2}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeCharsString}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeChars}
/// {@canonicalFor bones_api_condition_sql.ConditionSQLEncoder}
/// {@canonicalFor bones_api_config.APIConfigProvider}
/// {@canonicalFor bones_api_config.APIConfig}
/// {@canonicalFor bones_api_db_module.APIDBModule}
/// {@canonicalFor bones_api_entity.ClassReflectionEntityHandler}
/// {@canonicalFor bones_api_entity.EntityAccessor}
/// {@canonicalFor bones_api_entity.EntityCache}
/// {@canonicalFor bones_api_entity.EntityFieldAccessorGeneric}
/// {@canonicalFor bones_api_entity.EntityFieldAccessor}
/// {@canonicalFor bones_api_entity.EntityHandlerProvider}
/// {@canonicalFor bones_api_entity.EntityHandler}
/// {@canonicalFor bones_api_entity.EntityProvider}
/// {@canonicalFor bones_api_entity.EntityRepositoryProviderExtension}
/// {@canonicalFor bones_api_entity.EntityRepositoryProvider}
/// {@canonicalFor bones_api_entity.EntityRepository}
/// {@canonicalFor bones_api_entity.EntitySource}
/// {@canonicalFor bones_api_entity.EntityStorage}
/// {@canonicalFor bones_api_entity.Entity}
/// {@canonicalFor bones_api_entity.ErrorFilter}
/// {@canonicalFor bones_api_entity.GenericEntityHandler}
/// {@canonicalFor bones_api_entity.InstantiatorDefault}
/// {@canonicalFor bones_api_entity.InstantiatorFromMap}
/// {@canonicalFor bones_api_entity.IterableClassification}
/// {@canonicalFor bones_api_entity.IterableEntityRepositoryProviderExtension}
/// {@canonicalFor bones_api_entity.IterableEntityRepository}
/// {@canonicalFor bones_api_entity.JsonReviver}
/// {@canonicalFor bones_api_entity.JsonToEncodable}
/// {@canonicalFor bones_api_entity.SetEntityRepository}
/// {@canonicalFor bones_api_entity.TransactionAbortedError}
/// {@canonicalFor bones_api_entity.TransactionEntityProvider}
/// {@canonicalFor bones_api_entity.TransactionExecution}
/// {@canonicalFor bones_api_entity.TransactionOperationConstrainRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationCount}
/// {@canonicalFor bones_api_entity.TransactionOperationDelete}
/// {@canonicalFor bones_api_entity.TransactionOperationSelectRelationships}
/// {@canonicalFor bones_api_entity.TransactionOperationSelectRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationSelect}
/// {@canonicalFor bones_api_entity.TransactionOperationStoreRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationStore}
/// {@canonicalFor bones_api_entity.TransactionOperationSubTransaction}
/// {@canonicalFor bones_api_entity.TransactionOperationTypeExtension}
/// {@canonicalFor bones_api_entity.TransactionOperationType}
/// {@canonicalFor bones_api_entity.TransactionOperationUpdate}
/// {@canonicalFor bones_api_entity.TransactionOperation}
/// {@canonicalFor bones_api_entity.Transaction}
/// {@canonicalFor bones_api_entity_annotation.EntityAnnotation}
/// {@canonicalFor bones_api_entity_annotation.EntityFieldInvalid}
/// {@canonicalFor bones_api_entity_annotation.EntityField}
/// {@canonicalFor bones_api_entity_annotation.IterableEntityAnnotationExtension}
/// {@canonicalFor bones_api_entity_annotation.IterableEntityFieldExtension}
/// {@canonicalFor bones_api_entity_db.DBAdapterCapability}
/// {@canonicalFor bones_api_entity_db.DBAdapterException}
/// {@canonicalFor bones_api_entity_db.DBAdapterInstantiator}
/// {@canonicalFor bones_api_entity_db.DBAdapterRegister}
/// {@canonicalFor bones_api_entity_db.DBAdapter}
/// {@canonicalFor bones_api_entity_db.DBDialect}
/// {@canonicalFor bones_api_entity_db.DBEntityRepositoryProvider}
/// {@canonicalFor bones_api_entity_db.DBEntityRepository}
/// {@canonicalFor bones_api_entity_db.DBRepositoryAdapter}
/// {@canonicalFor bones_api_entity_db.PasswordProvider}
/// {@canonicalFor bones_api_entity_db.PreFinishDBOperation}
/// {@canonicalFor bones_api_entity_db_memory.DBMemorySQLAdapterException}
/// {@canonicalFor bones_api_entity_db_memory.DBMemorySQLAdapter}
/// {@canonicalFor bones_api_entity_db_memory.DBSQLMemoryAdapterContext}
/// {@canonicalFor bones_api_entity_db_memory.DBSQLMemoryAdapterException}
/// {@canonicalFor bones_api_entity_db_memory.DBSQLMemoryAdapter}
/// {@canonicalFor bones_api_entity_db_object_memory.DBMemoryObjectAdapterException}
/// {@canonicalFor bones_api_entity_db_object_memory.DBMemoryObjectAdapter}
/// {@canonicalFor bones_api_entity_db_object_memory.DBObjectMemoryAdapterContext}
/// {@canonicalFor bones_api_entity_db_object_memory.DBObjectMemoryAdapterException}
/// {@canonicalFor bones_api_entity_db_object_memory.DBObjectMemoryAdapter}
/// {@canonicalFor bones_api_entity_db_relational.DBRelationalAdapter}
/// {@canonicalFor bones_api_entity_db_relational.DBRelationalEntityRepositoryProvider}
/// {@canonicalFor bones_api_entity_db_relational.DBRelationalEntityRepository}
/// {@canonicalFor bones_api_entity_db_relational.DBRelationalRepositoryAdapter}
/// {@canonicalFor bones_api_entity_db_sql.DBSQLAdapterCapability}
/// {@canonicalFor bones_api_entity_db_sql.DBSQLAdapterException}
/// {@canonicalFor bones_api_entity_db_sql.DBSQLAdapterInstantiator}
/// {@canonicalFor bones_api_entity_db_sql.DBSQLAdapter}
/// {@canonicalFor bones_api_entity_db_sql.DBSQLRepositoryAdapter}
/// {@canonicalFor bones_api_entity_db_sql.MultipleSQL}
/// {@canonicalFor bones_api_entity_db_sql.SQLWrapper}
/// {@canonicalFor bones_api_entity_db_sql.SQL}
/// {@canonicalFor bones_api_entity_reference.EntitiesFetcher}
/// {@canonicalFor bones_api_entity_reference.EntityFetcher}
/// {@canonicalFor bones_api_entity_reference.EntityReferenceBase}
/// {@canonicalFor bones_api_entity_reference.EntityReferenceList}
/// {@canonicalFor bones_api_entity_reference.EntityReference}
/// {@canonicalFor bones_api_entity_rules.EntityAccessRuleType}
/// {@canonicalFor bones_api_entity_rules.EntityAccessRulesCached}
/// {@canonicalFor bones_api_entity_rules.EntityAccessRulesCondition}
/// {@canonicalFor bones_api_entity_rules.EntityAccessRulesContext}
/// {@canonicalFor bones_api_entity_rules.EntityAccessRules}
/// {@canonicalFor bones_api_entity_rules.EntityResolutionRulesResolved}
/// {@canonicalFor bones_api_entity_rules.EntityResolutionRules}
/// {@canonicalFor bones_api_entity_rules.EntityRulesContextProvider}
/// {@canonicalFor bones_api_entity_rules.EntityRulesResolver}
/// {@canonicalFor bones_api_entity_rules.EntityRules}
/// {@canonicalFor bones_api_entity_rules.MergeEntityRulesError}
/// {@canonicalFor bones_api_entity_rules.ValidateEntityRulesError}
/// {@canonicalFor bones_api_entity_sql.DBSQLEntityRepositoryProvider}
/// {@canonicalFor bones_api_entity_sql.DBSQLEntityRepository}
/// {@canonicalFor bones_api_error_zone.ErrorZoneExtension}
/// {@canonicalFor bones_api_error_zone.OnUncaughtError}
/// {@canonicalFor bones_api_error_zone.ZoneField}
/// {@canonicalFor bones_api_error_zone.createErrorZone}
/// {@canonicalFor bones_api_error_zone.printToZoneStderr}
/// {@canonicalFor bones_api_error_zone.printZoneError}
/// {@canonicalFor bones_api_extension.APIEntityObjectExtension}
/// {@canonicalFor bones_api_extension.APIEntityTypeExtension}
/// {@canonicalFor bones_api_extension.ClassReflectionExtension}
/// {@canonicalFor bones_api_extension.ListOfStringExtension}
/// {@canonicalFor bones_api_extension.MapGetterExtension}
/// {@canonicalFor bones_api_extension.MapMultiValueExtension}
/// {@canonicalFor bones_api_extension.MethodReflectionExtension}
/// {@canonicalFor bones_api_extension.ReflectionFactoryExtension}
/// {@canonicalFor bones_api_extension.TypeInfoEntityExtension}
/// {@canonicalFor bones_api_extension.TypeReflectionEntityExtension}
/// {@canonicalFor bones_api_html_document.HTMLDocument}
/// {@canonicalFor bones_api_html_document.HTMLInput}
/// {@canonicalFor bones_api_initializable.ExecuteInitializedCallback}
/// {@canonicalFor bones_api_initializable.InitializableListExtension}
/// {@canonicalFor bones_api_initializable.Initializable}
/// {@canonicalFor bones_api_initializable.InitializationResult}
/// {@canonicalFor bones_api_initializable.InitializationStatus}
/// {@canonicalFor bones_api_module.APIModuleHttpProxyRequestHandler}
/// {@canonicalFor bones_api_module.APIModuleHttpProxy}
/// {@canonicalFor bones_api_module.APIModuleInfo}
/// {@canonicalFor bones_api_module.APIModuleProxy}
/// {@canonicalFor bones_api_module.APIModule}
/// {@canonicalFor bones_api_module.APIRouteBuilder}
/// {@canonicalFor bones_api_platform.APIPlatformCapability}
/// {@canonicalFor bones_api_platform.APIPlatformTypeExtension}
/// {@canonicalFor bones_api_platform.APIPlatformType}
/// {@canonicalFor bones_api_platform.APIPlatform}
/// {@canonicalFor bones_api_repository.APIRepository}
/// {@canonicalFor bones_api_root_starter.APIRootStarter}
/// {@canonicalFor bones_api_security.APIEntityAccessRules}
/// {@canonicalFor bones_api_security.APIEntityResolutionRules}
/// {@canonicalFor bones_api_security.APIEntityRules}
/// {@canonicalFor bones_api_security.APIRouteAuthenticatedRule}
/// {@canonicalFor bones_api_security.APIRouteNotAuthenticatedRule}
/// {@canonicalFor bones_api_security.APIRoutePermissionTypeRule}
/// {@canonicalFor bones_api_security.APIRoutePublicRule}
/// {@canonicalFor bones_api_security.APIRouteRule}
/// {@canonicalFor bones_api_security.APISecurity}
/// {@canonicalFor bones_api_security.RandomExtension}
/// {@canonicalFor bones_api_security.SecureRandom}
/// {@canonicalFor bones_api_session.APISessionSet}
/// {@canonicalFor bones_api_session.APISession}
/// {@canonicalFor bones_api_sql_builder.AlterTableSQL}
/// {@canonicalFor bones_api_sql_builder.CreateIndexSQL}
/// {@canonicalFor bones_api_sql_builder.CreateTableSQL}
/// {@canonicalFor bones_api_sql_builder.SQLBuilderIterableMapEntryExtension}
/// {@canonicalFor bones_api_sql_builder.SQLBuilderListExtension}
/// {@canonicalFor bones_api_sql_builder.SQLBuilderMapExtension}
/// {@canonicalFor bones_api_sql_builder.SQLBuilder}
/// {@canonicalFor bones_api_sql_builder.SQLColumn}
/// {@canonicalFor bones_api_sql_builder.SQLDialect}
/// {@canonicalFor bones_api_sql_builder.SQLEntry}
/// {@canonicalFor bones_api_sql_builder.SQLGenerator}
/// {@canonicalFor bones_api_sql_builder.TableSQL}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigBase}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDBMemory}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDBMixin}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDBSQLMemory}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDBSQLMixin}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDBSQL}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDB}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDockerDBSQL}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDockerDB}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigDocker}
/// {@canonicalFor bones_api_test_utils_config.APITestConfigExtension}
/// {@canonicalFor bones_api_test_utils_config.APITestConfig}
/// {@canonicalFor bones_api_test_utils_server.runTestAPIServer}
/// {@canonicalFor bones_api_types.Time}
/// {@canonicalFor bones_api_utils.ExtensionRuntimeTypeNameUnsafe}
/// {@canonicalFor bones_api_utils.FieldNameMapper}
/// {@canonicalFor bones_api_utils.KeyMapper}
/// {@canonicalFor bones_api_utils.StringUtils}
/// {@canonicalFor bones_api_utils.WithRuntimeTypeNameSafe}
/// {@canonicalFor bones_api_utils.tryCallMapped}
/// {@canonicalFor bones_api_utils.tryCallSync}
/// {@canonicalFor bones_api_utils.tryCall}
/// {@canonicalFor bones_api_utils_arguments.Arguments}
/// {@canonicalFor bones_api_utils_collections.IterableEnumExtension}
/// {@canonicalFor bones_api_utils_collections.MapAsCacheExtension}
/// {@canonicalFor bones_api_utils_collections.PositionalFields}
/// {@canonicalFor bones_api_utils_collections.ValueEquality}
/// {@canonicalFor bones_api_utils_collections.deepCopyList}
/// {@canonicalFor bones_api_utils_collections.deepCopyMap}
/// {@canonicalFor bones_api_utils_collections.deepCopySet}
/// {@canonicalFor bones_api_utils_collections.deepCopy}
/// {@canonicalFor bones_api_utils_collections.enumFromName}
/// {@canonicalFor bones_api_utils_collections.enumToName}
/// {@canonicalFor bones_api_utils_collections.intersectsIterableDeep}
/// {@canonicalFor bones_api_utils_collections.isEqualsDeep}
/// {@canonicalFor bones_api_utils_collections.isEqualsIterableDeep}
/// {@canonicalFor bones_api_utils_collections.isEqualsListDeep}
/// {@canonicalFor bones_api_utils_collections.isEqualsMapDeep}
/// {@canonicalFor bones_api_utils_collections.isEqualsSetDeep}
/// {@canonicalFor bones_api_utils_httpclient.decodeQueryStringParameters}
/// {@canonicalFor bones_api_utils_httpclient.getURLAsByteArray}
/// {@canonicalFor bones_api_utils_httpclient.getURLAsString}
/// {@canonicalFor bones_api_utils_httpclient.getURL}
/// {@canonicalFor bones_api_utils_instance_tracker.InstanceInfoExtractor}
/// {@canonicalFor bones_api_utils_instance_tracker.InstanceTracker}
/// {@canonicalFor bones_api_utils_json.JsonEntityCacheExtension}
/// {@canonicalFor bones_api_utils_json.Json}
/// {@canonicalFor bones_api_utils_json.ToEncodable}
/// {@canonicalFor bones_api_utils_timedmap.TimedMap}

/// Bones_API Library.
library;

export 'dart:async';

export 'package:meta/meta_meta.dart';
export 'package:reflection_factory/reflection_factory.dart';
export 'package:swiss_knife/swiss_knife.dart' show MimeType, DataURLBase64;

export 'src/bones_api_authentication.dart';
export 'src/bones_api_base.dart';
export 'src/bones_api_condition.dart';
export 'src/bones_api_condition_encoder.dart';
export 'src/bones_api_condition_parser.dart';
export 'src/bones_api_condition_sql.dart';
export 'src/bones_api_config.dart';
export 'src/bones_api_db_module.dart';
export 'src/bones_api_entity.dart';
export 'src/bones_api_entity_annotation.dart';
export 'src/bones_api_entity_db.dart';
export 'src/bones_api_entity_db_memory.dart';
export 'src/bones_api_entity_db_object_memory.dart';
export 'src/bones_api_entity_db_relational.dart';
export 'src/bones_api_entity_db_sql.dart';
export 'src/bones_api_entity_reference.dart';
export 'src/bones_api_entity_rules.dart';
export 'src/bones_api_entity_sql.dart';
export 'src/bones_api_error_zone.dart';
export 'src/bones_api_extension.dart';
export 'src/bones_api_html_document.dart';
export 'src/bones_api_initializable.dart';
export 'src/bones_api_module.dart';
export 'src/bones_api_platform.dart';
export 'src/bones_api_repository.dart';
export 'src/bones_api_root_starter.dart';
export 'src/bones_api_security.dart';
export 'src/bones_api_session.dart';
export 'src/bones_api_sql_builder.dart';
export 'src/bones_api_types.dart';
export 'src/bones_api_utils.dart';
export 'src/bones_api_utils_arguments.dart';
export 'src/bones_api_utils_call.dart';
export 'src/bones_api_utils_collections.dart';
export 'src/bones_api_utils_httpclient.dart';
export 'src/bones_api_utils_instance_tracker.dart';
export 'src/bones_api_utils_json.dart';
export 'src/bones_api_utils_timedmap.dart';
export 'src/bones_api_utils_weaklist.dart';
