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
    entityRepository ??= provider?.getEntityRepositoryByType<O>(type ?? O);

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

  FutureOr<int> count({Transaction? transaction}) =>
      entityRepository.count(transaction: transaction);

  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) =>
      entityRepository.existsID(id, transaction: transaction);

  FutureOr<O?> selectByID(dynamic id,
          {Transaction? transaction, EntityResolutionRules? resolutionRules}) =>
      entityRepository.selectByID(id,
          transaction: transaction, resolutionRules: resolutionRules);

  FutureOr<List<O?>> selectByIDs(List<dynamic> ids,
          {Transaction? transaction, EntityResolutionRules? resolutionRules}) =>
      entityRepository.selectByIDs(ids,
          transaction: transaction, resolutionRules: resolutionRules);

  FutureOr<Iterable<O>> selectAll(
          {int? limit,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      entityRepository.selectAll(
          limit: limit,
          transaction: transaction,
          resolutionRules: resolutionRules);

  FutureOr<int> length() => entityRepository.length();

  FutureOr<O?> selectFirstByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      entityRepository.selectFirstByQuery(
        query,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        resolutionRules: resolutionRules,
      );

  FutureOr<Iterable<O>> selectByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      entityRepository.selectByQuery(query,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit,
          transaction: transaction,
          resolutionRules: resolutionRules);

  FutureOr<Iterable<O>> select(EntityMatcher<O> matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit,
          Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      entityRepository.select(matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit,
          transaction: transaction,
          resolutionRules: resolutionRules);

  FutureOr<Iterable<O>> deleteByQuery(String query,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          Transaction? transaction}) =>
      entityRepository.deleteByQuery(query,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          transaction: transaction);

  FutureOr<O?> deleteEntity(O o, {Transaction? transaction}) =>
      entityRepository.deleteEntity(o, transaction: transaction);

  FutureOr<O?> tryDeleteEntity(O o, {Transaction? transaction}) =>
      entityRepository.tryDeleteEntity(o, transaction: transaction);

  FutureOr<O?> deleteByID(dynamic id, {Transaction? transaction}) =>
      entityRepository.deleteByID(id, transaction: transaction);

  FutureOr<O?> tryDeleteByID(dynamic id, {Transaction? transaction}) =>
      entityRepository.tryDeleteByID(id, transaction: transaction);

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          Transaction? transaction}) =>
      entityRepository.delete(matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable> deleteEntityCascade(O o, {Transaction? transaction}) =>
      entityRepository.deleteEntityCascade(o, transaction: transaction);

  FutureOr<dynamic> store(O o, {Transaction? transaction}) =>
      entityRepository.store(o, transaction: transaction);

  FutureOr<List> storeAll(Iterable<O> os, {Transaction? transaction}) =>
      entityRepository.storeAll(os, transaction: transaction);

  FutureOr<O> storeFromJson(Map<String, dynamic> json,
          {Transaction? transaction, EntityResolutionRules? resolutionRules}) =>
      entityRepository.storeFromJson(json,
          transaction: transaction, resolutionRules: resolutionRules);

  FutureOr<List<O>> storeAllFromJson(
          Iterable<Map<String, dynamic>> entitiesJson,
          {Transaction? transaction,
          EntityResolutionRules? resolutionRules}) =>
      entityRepository.storeAllFromJson(entitiesJson,
          transaction: transaction, resolutionRules: resolutionRules);
}
