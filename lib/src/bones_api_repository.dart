import 'dart:async';

import 'bones_api_data.dart';

/// A data repository API.
abstract class APIRepository<O> {
  /// Resolves a [DataRepository].
  static DataRepository<O>? resolveDataRepository<O>(
      {DataRepository<O>? dataRepository,
      DataRepositoryProvider? provider,
      Type? type}) {
    return dataRepository ??
        provider?.getDataRepository<O>(type: type) ??
        DataRepositoryProvider.globalProvider.getDataRepository<O>(type: type);
  }

  final DataRepository<O> dataRepository;

  APIRepository(
      {DataRepository<O>? dataRepository,
      DataRepositoryProvider? provider,
      Type? type})
      : dataRepository = resolveDataRepository(
            dataRepository: dataRepository, provider: provider, type: type)! {
    this.dataRepository.ensureInitialized();
  }

  void configure();

  bool _configured = false;

  void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
  }

  FutureOr<O?> selectByID(dynamic id) => dataRepository.selectByID(id);

  FutureOr<int> length() => dataRepository.length();

  FutureOr<Iterable<O>> selectByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      dataRepository.selectByQuery(query,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);
}
