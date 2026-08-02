import 'package:async_extension/async_extension.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_pagination.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_initializable.dart';
import 'bones_api_types.dart';

/// A entity repository API.
abstract class APIRepository<O extends Object> with Initializable {
  /// Resolves a [EntityRepository].
  static EntityRepository<O>? resolveEntityRepository<O extends Object>({
    EntityRepository<O>? entityRepository,
    EntityRepositoryProvider? provider,
    Type? type,
    bool required = false,
  }) {
    entityRepository ??= provider?.getEntityRepositoryByType<O>(type ?? O);

    entityRepository ??= EntityRepositoryProvider.globalProvider
        .getEntityRepository<O>(type: type);

    if (entityRepository == null && required) {
      throw StateError(
        "Can't resolve `EntityRepository` for type: $type @ $provider",
      );
    }

    return entityRepository;
  }

  final EntityRepository<O> entityRepository;

  APIRepository({
    EntityRepository<O>? entityRepository,
    EntityRepositoryProvider? provider,
    Type? type,
  }) : entityRepository =
           resolveEntityRepository(
             entityRepository: entityRepository,
             provider: provider,
             type: type ?? O,
             required: true,
           )! {
    // ignore: discarded_futures
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

  FutureOr<int> countByQuery(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) => entityRepository.countByQuery(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    transaction: transaction,
  );

  FutureOr<int> count({
    EntityMatcher<O>? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) => entityRepository.count(
    matcher: matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    transaction: transaction,
  );

  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) =>
      entityRepository.existsID(id, transaction: transaction);

  FutureOr<Iterable<I>> existIDs<I extends Object>(
    List<I?> ids, {
    Transaction? transaction,
  }) => entityRepository.existIDs(ids, transaction: transaction);

  FutureOr<O?> selectByID(
    dynamic id, {
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.selectByID(
    id,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  FutureOr<List<O?>> selectByIDs(
    List<dynamic> ids, {
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.selectByIDs(
    ids,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  /// {@macro bones_api.select_pagination}
  FutureOr<Iterable<O>> selectAll({
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.selectAll(
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  FutureOr<int> length() => entityRepository.length();

  /// {@macro bones_api.select_pagination}
  FutureOr<O?> selectFirstByQuery(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.selectFirstByQuery(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  /// {@macro bones_api.select_pagination}
  FutureOr<Iterable<O>> selectByQuery(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.selectByQuery(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  /// {@macro bones_api.select_pagination}
  FutureOr<Iterable<I>> selectIDsByQuery<I extends Object>(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
  }) => entityRepository.selectIDsByQuery<I>(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
  );

  /// {@macro bones_api.select_pagination}
  FutureOr<Iterable<I>> selectIDsBy<I extends Object>(
    EntityMatcher<O> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
  }) => entityRepository.selectIDsBy(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
  );

  /// {@macro bones_api.select_pagination}
  FutureOr<Iterable<O>> select(
    EntityMatcher<O> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.select(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  /// {@macro bones_api.paginate}
  EntityPagination<O> paginateByQuery(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    required int limit,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
    EntityPaginationListener<O>? onEvent,
  }) => entityRepository.paginateByQuery(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
    onEvent: onEvent,
  );

  /// {@macro bones_api.paginate}
  EntityPagination<O> paginate(
    EntityMatcher<O> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    required int limit,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
    EntityPaginationListener<O>? onEvent,
  }) => entityRepository.paginate(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
    onEvent: onEvent,
  );

  /// {@macro bones_api.paginate}
  EntityPagination<O> paginateAll({
    required int limit,
    bool? orderByID,
    OrderDirection? orderDirection,
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
    EntityPaginationListener<O>? onEvent,
  }) => entityRepository.paginateAll(
    limit: limit,
    orderByID: orderByID,
    orderDirection: orderDirection,
    transaction: transaction,
    resolutionRules: resolutionRules,
    onEvent: onEvent,
  );

  FutureOr<Iterable<O>> deleteByQuery(
    String query, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) => entityRepository.deleteByQuery(
    query,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    transaction: transaction,
  );

  FutureOr<O?> deleteEntity(O o, {Transaction? transaction}) =>
      entityRepository.deleteEntity(o, transaction: transaction);

  FutureOr<O?> tryDeleteEntity(O o, {Transaction? transaction}) =>
      entityRepository.tryDeleteEntity(o, transaction: transaction);

  FutureOr<O?> deleteByID(dynamic id, {Transaction? transaction}) =>
      entityRepository.deleteByID(id, transaction: transaction);

  FutureOr<O?> tryDeleteByID(dynamic id, {Transaction? transaction}) =>
      entityRepository.tryDeleteByID(id, transaction: transaction);

  FutureOr<Iterable<O>> delete(
    EntityMatcher<O> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) => entityRepository.delete(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
  );

  FutureOr<Iterable> deleteEntityCascade(O o, {Transaction? transaction}) =>
      entityRepository.deleteEntityCascade(o, transaction: transaction);

  FutureOr<dynamic> store(O o, {Transaction? transaction}) =>
      entityRepository.store(o, transaction: transaction);

  FutureOr<List> storeAll(Iterable<O> os, {Transaction? transaction}) =>
      entityRepository.storeAll(os, transaction: transaction);

  FutureOr<O> storeFromJson(
    Map<String, dynamic> json, {
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.storeFromJson(
    json,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );

  FutureOr<List<O>> storeAllFromJson(
    Iterable<Map<String, dynamic>> entitiesJson, {
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) => entityRepository.storeAllFromJson(
    entitiesJson,
    transaction: transaction,
    resolutionRules: resolutionRules,
  );
}
