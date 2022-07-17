// Documentation canonicals:
// - Generated with:
//   $> dart doc --dry-run 2>/tmp/dartdoc.txt
//   $> cat /tmp/dartdoc.txt | grep "ambiguous reexport " |  awk '{ print $5 }' | sed 's/,//' | awk '{ print "/// {@canonicalFor " $0 "}" }'
//
/// {@canonicalFor bones_api_authentication.APIAuthentication}
/// {@canonicalFor bones_api_authentication.APICredential}
/// {@canonicalFor bones_api_authentication.APIPasswordHashAlgorithm}
/// {@canonicalFor bones_api_authentication.APIPasswordNotHashed}
/// {@canonicalFor bones_api_authentication.APIPasswordSHA256}
/// {@canonicalFor bones_api_authentication.APIPassword}
/// {@canonicalFor bones_api_authentication.APIPermission}
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
/// {@canonicalFor bones_api_condition.KeyConditionINBase}
/// {@canonicalFor bones_api_condition.KeyConditionIN}
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
/// {@canonicalFor bones_api_entity.IterableEntityRepositoryProviderExtension}
/// {@canonicalFor bones_api_entity.IterableEntityRepository}
/// {@canonicalFor bones_api_entity.JsonReviver}
/// {@canonicalFor bones_api_entity.JsonToEncodable}
/// {@canonicalFor bones_api_entity.SetEntityRepository}
/// {@canonicalFor bones_api_entity.TransactionAbortedError}
/// {@canonicalFor bones_api_entity.TransactionExecution}
/// {@canonicalFor bones_api_entity.TransactionOperationConstrainRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationCount}
/// {@canonicalFor bones_api_entity.TransactionOperationDelete}
/// {@canonicalFor bones_api_entity.TransactionOperationSelectRelationships}
/// {@canonicalFor bones_api_entity.TransactionOperationSelectRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationSelect}
/// {@canonicalFor bones_api_entity.TransactionOperationStoreRelationship}
/// {@canonicalFor bones_api_entity.TransactionOperationStore}
/// {@canonicalFor bones_api_entity.TransactionOperationTypeExtension}
/// {@canonicalFor bones_api_entity.TransactionOperationType}
/// {@canonicalFor bones_api_entity.TransactionOperationUpdate}
/// {@canonicalFor bones_api_entity.TransactionOperation}
/// {@canonicalFor bones_api_entity.Transaction}
/// {@canonicalFor bones_api_entity_adapter.DBAdapterCapability}
/// {@canonicalFor bones_api_entity_adapter.DBAdapterInstantiator}
/// {@canonicalFor bones_api_entity_adapter.DBAdapter}
/// {@canonicalFor bones_api_entity_adapter.DBEntityRepositoryProvider}
/// {@canonicalFor bones_api_entity_adapter.DBRepositoryAdapter}
/// {@canonicalFor bones_api_entity_adapter.MultipleSQL}
/// {@canonicalFor bones_api_entity_adapter.PasswordProvider}
/// {@canonicalFor bones_api_entity_adapter.PreFinishDBOperation}
/// {@canonicalFor bones_api_entity_adapter.SQLWrapper}
/// {@canonicalFor bones_api_entity_adapter_memory.MemorySQLAdapterContext}
/// {@canonicalFor bones_api_entity_adapter_memory.MemorySQLAdapter}
/// {@canonicalFor bones_api_entity_adapter_sql.SQLAdapterCapability}
/// {@canonicalFor bones_api_entity_adapter_sql.SQLAdapterInstantiator}
/// {@canonicalFor bones_api_entity_adapter_sql.SQLAdapter}
/// {@canonicalFor bones_api_entity_adapter_sql.SQLRepositoryAdapter}
/// {@canonicalFor bones_api_entity_adapter_sql.SQL}
/// {@canonicalFor bones_api_entity_sql.SQLEntityRepositoryProvider}
/// {@canonicalFor bones_api_entity_sql.SQLEntityRepository}
/// {@canonicalFor bones_api_extension.ClassReflectionExtension}
/// {@canonicalFor bones_api_extension.MapGetterExtension}
/// {@canonicalFor bones_api_extension.MapMultiValueExtension}
/// {@canonicalFor bones_api_extension.MethodReflectionExtension}
/// {@canonicalFor bones_api_extension.ReflectionFactoryExtension}
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
/// {@canonicalFor bones_api_sql_builder.CreateTableSQL}
/// {@canonicalFor bones_api_sql_builder.SQLBuilderListExtension}
/// {@canonicalFor bones_api_sql_builder.SQLBuilder}
/// {@canonicalFor bones_api_sql_builder.SQLColumn}
/// {@canonicalFor bones_api_sql_builder.SQLEntry}
/// {@canonicalFor bones_api_sql_builder.SQLGenerator}
/// {@canonicalFor bones_api_sql_builder.TableSQL}
/// {@canonicalFor bones_api_test_utils.APITestConfigBase}
/// {@canonicalFor bones_api_test_utils.APITestConfigDBMemory}
/// {@canonicalFor bones_api_test_utils.APITestConfigDBMixin}
/// {@canonicalFor bones_api_test_utils.APITestConfigDBSQLMixin}
/// {@canonicalFor bones_api_test_utils.APITestConfigDBSQL}
/// {@canonicalFor bones_api_test_utils.APITestConfigDB}
/// {@canonicalFor bones_api_test_utils.APITestConfigDockerDBSQL}
/// {@canonicalFor bones_api_test_utils.APITestConfigDockerDB}
/// {@canonicalFor bones_api_test_utils.APITestConfigDocker}
/// {@canonicalFor bones_api_test_utils.APITestConfigExtension}
/// {@canonicalFor bones_api_test_utils.APITestConfig}
/// {@canonicalFor bones_api_types.GenericObjectExtension}
/// {@canonicalFor bones_api_types.Time}
/// {@canonicalFor bones_api_utils_arguments.Arguments}
/// {@canonicalFor bones_api_utils_collections.PositionalFields}
/// {@canonicalFor bones_api_utils_collections.ValueEquality}
/// {@canonicalFor bones_api_utils_collections.deepCopyList}
/// {@canonicalFor bones_api_utils_collections.deepCopyMap}
/// {@canonicalFor bones_api_utils_collections.deepCopySet}
/// {@canonicalFor bones_api_utils_collections.deepCopy}
/// {@canonicalFor bones_api_utils_collections.enumFromName}
/// {@canonicalFor bones_api_utils_collections.enumToName}
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
/// {@canonicalFor bones_api_utils_json.Json}
/// {@canonicalFor bones_api_utils_json.ToEncodable}
/// {@canonicalFor bones_api_utils_timedmap.TimedMap}

/// Bones_API Library.
library bones_api;

export 'dart:async';

export 'package:meta/meta_meta.dart';
export 'package:reflection_factory/reflection_factory.dart';

export 'src/bones_api_authentication.dart';
export 'src/bones_api_base.dart';
export 'src/bones_api_condition.dart';
export 'src/bones_api_condition_encoder.dart';
export 'src/bones_api_condition_parser.dart';
export 'src/bones_api_condition_sql.dart';
export 'src/bones_api_config.dart';
export 'src/bones_api_entity.dart';
export 'src/bones_api_entity_adapter.dart';
export 'src/bones_api_entity_adapter_memory.dart';
export 'src/bones_api_entity_adapter_sql.dart';
export 'src/bones_api_entity_annotation.dart';
export 'src/bones_api_entity_sql.dart';
export 'src/bones_api_extension.dart';
export 'src/bones_api_initializable.dart';
export 'src/bones_api_module.dart';
export 'src/bones_api_platform.dart';
export 'src/bones_api_repository.dart';
export 'src/bones_api_root_starter.dart';
export 'src/bones_api_security.dart';
export 'src/bones_api_session.dart';
export 'src/bones_api_sql_builder.dart';
export 'src/bones_api_types.dart';
export 'src/bones_api_utils_arguments.dart';
export 'src/bones_api_utils_collections.dart';
export 'src/bones_api_utils_httpclient.dart';
export 'src/bones_api_utils_instance_tracker.dart';
export 'src/bones_api_utils_json.dart';
export 'src/bones_api_utils_timedmap.dart';
