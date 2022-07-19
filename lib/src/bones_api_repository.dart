import 'package:async_extension/async_extension.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_initializable.dart';

/// A entity repository API.
abstract class APIRepository<O extends Object> with Initializable {
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
    this.entityRepository.ensureInitialized(parent: this);
  }

  void configure() {}

  bool _configured = false;

  void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
  }

  @override
  FutureOr<InitializationResult> initialize() =>
      entityRepository.executeInitialized(() {
        ensureConfigured();
        return InitializationResult.ok(this, dependencies: [entityRepository]);
      }, parent: this);

  EventStream<O> get onStore => entityRepository.onStore;

  EventStream<O> get onDelete => entityRepository.onDelete;

  FutureOr<bool> existsID(dynamic id) => entityRepository.existsID(id);

  FutureOr<O?> selectByID(dynamic id) => entityRepository.selectByID(id);

  FutureOr<Iterable<O>> selectAll({int? limit}) =>
      entityRepository.selectAll(limit: limit);

  FutureOr<int> length() => entityRepository.length();

  FutureOr<O?> selectFirstByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      entityRepository.selectFirstByQuery(
        query,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );

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

  FutureOr<O?> deleteEntity(O o) => entityRepository.deleteEntity(o);

  FutureOr<O?> tryDeleteEntity(O o) => entityRepository.tryDeleteEntity(o);

  FutureOr<O?> deleteByID(dynamic id) => entityRepository.deleteByID(id);

  FutureOr<O?> tryDeleteByID(dynamic id) => entityRepository.tryDeleteByID(id);

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      entityRepository.delete(matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable> deleteEntityCascade(O o) =>
      entityRepository.deleteEntityCascade(o);

  FutureOr<dynamic> store(O o, {Transaction? transaction}) =>
      entityRepository.store(o, transaction: transaction);

  FutureOr<O> storeFromJson(Map<String, dynamic> json,
          {Transaction? transaction}) =>
      entityRepository.storeFromJson(json);

  FutureOr<List<O>> storeAllFromJson(
          Iterable<Map<String, dynamic>> entitiesJson,
          {Transaction? transaction}) =>
      entityRepository.storeAllFromJson(entitiesJson);
}
