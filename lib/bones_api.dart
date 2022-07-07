// Generated with:
// $> dartdoc --no-generate-docs 2>/tmp/dartdoc.txt
// $> cat /tmp/dartdoc.txt | grep "ambiguous reexport " |  awk '{ print $5 }' | sed 's/,//' | awk '{ print "/// {@canonicalFor " $0 "}" }'
//
/// {@canonicalFor bones_api_base.Arguments}
/// {@canonicalFor bones_api_entity_adapter.SQLRepositoryAdapter}
/// {@canonicalFor bones_api_condition_parser.JsonGrammarLexer}
/// {@canonicalFor bones_api_condition_parser.JsonGrammarDefinition}
/// {@canonicalFor bones_api_condition_parser.ConditionGrammarDefinition}
/// {@canonicalFor bones_api_condition.KeyConditionEQ}
/// {@canonicalFor bones_api_condition.Condition}
/// {@canonicalFor bones_api_entity.EntityFieldAccessor}
/// {@canonicalFor bones_api_condition.KeyCondition}
/// {@canonicalFor bones_api_condition.ConditionElement}
/// {@canonicalFor bones_api_base.APIModule}
/// {@canonicalFor bones_api_extension.MethodReflectionExtension}
/// {@canonicalFor bones_api_base.APIRoot}
/// {@canonicalFor bones_api_condition.ConditionParameter}
/// {@canonicalFor bones_api_condition_sql.ConditionSQLEncoder}
/// {@canonicalFor bones_api_condition_encoder.ConditionEncoder}
/// {@canonicalFor bones_api_entity.EntityHandler}
/// {@canonicalFor bones_api_entity.GenericEntityHandler}
/// {@canonicalFor bones_api_entity.ClassReflectionEntityHandler}
/// {@canonicalFor bones_api_base.APIRequest}
/// {@canonicalFor bones_api_base.APIPayload}
/// {@canonicalFor bones_api_base.APIResponseStatus}
/// {@canonicalFor bones_api_entity.EntityHandlerProvider}
/// {@canonicalFor bones_api_config.APIConfig}
/// {@canonicalFor bones_api_condition_encoder.EncodingContext}
/// {@canonicalFor bones_api_entity.SetEntityRepository}
/// {@canonicalFor bones_api_entity.EntityRepository}
/// {@canonicalFor bones_api_entity.IterableEntityRepository}
/// {@canonicalFor bones_api_entity.EntityAccessor}
/// {@canonicalFor bones_api_entity.EntityRepositoryProvider}
/// {@canonicalFor bones_api_condition.GroupCondition}
/// {@canonicalFor bones_api_condition.GroupConditionAND}
/// {@canonicalFor bones_api_condition.GroupConditionOR}
/// {@canonicalFor bones_api_condition.ConditionID}
/// {@canonicalFor bones_api_condition.KeyConditionNotEQ}
/// {@canonicalFor bones_api_entity.EntityFieldAccessorGeneric}
/// {@canonicalFor bones_api_entity_sql.SQLEntityRepository}
/// {@canonicalFor bones_api_entity_adapter.SQLAdapter}
/// {@canonicalFor bones_api_condition_encoder.SchemeProvider}
/// {@canonicalFor bones_api_repository.APIRepository}
/// {@canonicalFor bones_api_utils.Json}
/// {@canonicalFor bones_api_base.APIRouteBuilder}
/// {@canonicalFor bones_api_base.APIResponse}
/// {@canonicalFor bones_api_condition.EntityMatcher}
/// {@canonicalFor bones_api_condition.ConditionKey}
/// {@canonicalFor bones_api_condition.ConditionKeyField}
/// {@canonicalFor bones_api_condition.ConditionKeyIndex}
/// {@canonicalFor bones_api_condition.ConditionParseCache}
/// {@canonicalFor bones_api_condition.ConditionQuery}
/// {@canonicalFor bones_api_condition_encoder.TableScheme}
/// {@canonicalFor bones_api_condition_encoder.ConditionEncodingError}
/// {@canonicalFor bones_api_condition_parser.JsonParser}
/// {@canonicalFor bones_api_condition_parser.ConditionParser}
/// {@canonicalFor bones_api_entity.Entity}
/// {@canonicalFor bones_api_entity.EntitySource}
/// {@canonicalFor bones_api_entity.EntityStorage}
/// {@canonicalFor bones_api_entity_adapter.SQL}
/// {@canonicalFor bones_api_base.APIRequestMethod}
/// {@canonicalFor bones_api_condition_encoder.TableFieldReference}
/// {@canonicalFor bones_api_entity.JsonToEncodable}
/// {@canonicalFor bones_api_extension.ClassReflectionExtension}
/// {@canonicalFor bones_api_base.APIRequestMethodExtension}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeChars}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeChars2}
/// {@canonicalFor bones_api_config.APIConfigProvider}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeCharsString2}
/// {@canonicalFor bones_api_entity_adapter.PasswordProvider}
/// {@canonicalFor bones_api_base.parseAPIRequestMethod}
/// {@canonicalFor bones_api_entity.InstantiatorFromMap}
/// {@canonicalFor bones_api_base.APIRouteHandler}
/// {@canonicalFor bones_api_entity.JsonReviver}
/// {@canonicalFor bones_api_condition_parser.jsonEscapeCharsString}
/// {@canonicalFor bones_api_entity.InstantiatorDefault}

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
export 'src/bones_api_entity_sql.dart';
export 'src/bones_api_extension.dart';
export 'src/bones_api_initializable.dart';
export 'src/bones_api_module.dart';
export 'src/bones_api_platform.dart';
export 'src/bones_api_repository.dart';
export 'src/bones_api_security.dart';
export 'src/bones_api_types.dart';
export 'src/bones_api_utils_arguments.dart';
export 'src/bones_api_utils_collections.dart';
export 'src/bones_api_utils_httpclient.dart';
export 'src/bones_api_utils_instance_tracker.dart';
export 'src/bones_api_utils_json.dart';
export 'src/bones_api_utils_timedmap.dart';
