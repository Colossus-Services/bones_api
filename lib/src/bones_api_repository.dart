import 'dart:async';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';

/// A entity repository API.
abstract class APIRepository<O extends Object> {
  /// Resolves a [EntityRepository].
  static EntityRepository<O>? resolveEntityRepository<O extends Object>(
      {EntityRepository<O>? entityRepository,
      EntityRepositoryProvider? provider,
      Type? type,
      bool required = false}) {
    entityRepository ??= provider?.getEntityRepository<O>(type: type);

    entityRepository ??= EntityRepositoryProvider.globalProvider
        .getEntityRepository<O>(type: type);

    if (entityRepository == null && required) {
      throw StateError("Can't resolve `EntityRepository` for type: $type");
    }

    return entityRepository;
  }

  final EntityRepository<O> entityRepository;

  APIRepository(
      {EntityRepository<O>? entityRepository,
      EntityRepositoryProvider? provider,
      Type? type})
      : entityRepository = resolveEntityRepository(
            entityRepository: entityRepository,
            provider: provider,
            type: type ?? O,
            required: true)! {
    this.entityRepository.ensureInitialized();
  }

  void configure() {}

  bool _configured = false;

  void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
  }

  FutureOr<O?> selectByID(dynamic id) => entityRepository.selectByID(id);

  FutureOr<int> length() => entityRepository.length();

  FutureOr<Iterable<O>> selectByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit}) =>
      entityRepository.selectByQuery(query,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);

  FutureOr<Iterable<O>> select(EntityMatcher<O> matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit}) =>
      entityRepository.select(matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);

  FutureOr<Iterable<O>> deleteByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      entityRepository.deleteByQuery(query,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      entityRepository.delete(matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<dynamic> store(O o, {Transaction? transaction}) =>
      entityRepository.store(o, transaction: transaction);
}
