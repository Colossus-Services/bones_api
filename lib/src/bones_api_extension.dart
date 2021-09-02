import 'package:reflection_factory/builder.dart';

import 'bones_api_base.dart';
import 'bones_api_data.dart';

/// [ClassReflection] extension.
extension ClassReflectionExtension<O> on ClassReflection<O> {
  /// Returns a [ClassReflectionDataHandler] for instances of this reflected class ([classType]).
  ClassReflectionDataHandler<O> get reflectionDataHandler =>
      ClassReflectionDataHandler<O>(O);

  /// Lists the API methods of this reflected class.
  /// See [MethodReflectionExtension.isAPIMethod].
  List<MethodReflection<O>> apiMethods() =>
      allMethods().where((m) => m.isAPIMethod).toList();
}

/// [MethodReflection] extension.
extension MethodReflectionExtension<O> on MethodReflection<O> {
  /// Returns `true` if this reflected method is an API method ([returnsAPIResponse] OR [receivesAPIRequest]).
  bool get isAPIMethod => returnsAPIResponse || receivesAPIRequest;

  /// Returns `true` if this reflected method is [returnsAPIResponse] AND [receivesAPIRequest].
  bool get isFullAPIMethod => returnsAPIResponse && receivesAPIRequest;

  /// Returns `true` if this reflected method receives an [APIRequest] as parameter.
  bool get receivesAPIRequest => equalsNormalParametersTypes([APIRequest]);

  /// Returns `true` if this reflected method returns an [APIResponse].
  bool get returnsAPIResponse => returnType == APIResponse;
}
