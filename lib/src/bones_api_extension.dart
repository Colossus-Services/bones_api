import 'dart:async';

import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';

/// [ClassReflection] extension.
extension ClassReflectionExtension<O> on ClassReflection<O> {
  /// Returns a [ClassReflectionEntityHandler] for instances of this reflected class ([classType]).
  ClassReflectionEntityHandler<O> get entityHandler =>
      ClassReflectionEntityHandler<O>(O);

  /// Lists the API methods of this reflected class.
  /// See [MethodReflectionExtension.isAPIMethod].
  List<MethodReflection<O, dynamic>> apiMethods() =>
      allMethods().where((m) => m.isAPIMethod).toList();
}

/// [MethodReflection] extension.
extension MethodReflectionExtension<O, R> on MethodReflection<O, R> {
  /// Returns `true` if this reflected method is an API method ([returnsAPIResponse] OR [receivesAPIRequest]).
  bool get isAPIMethod => returnsAPIResponse || receivesAPIRequest;

  /// Returns `true` if this reflected method is [returnsAPIResponse] AND [receivesAPIRequest].
  bool get isFullAPIMethod => returnsAPIResponse && receivesAPIRequest;

  /// Returns `true` if this reflected method receives an [APIRequest] as parameter.
  bool get receivesAPIRequest => equalsNormalParametersTypes([APIRequest]);

  /// Returns `true` if this reflected method returns an [APIResponse].
  bool get returnsAPIResponse {
    var returnType = this.returnType;
    if (returnType == null) return false;

    var type = returnType.type;

    return type == APIResponse ||
        ((type == Future || type == FutureOr) &&
            (returnType.equalsArgumentsTypes([APIResponse])));
  }
}
