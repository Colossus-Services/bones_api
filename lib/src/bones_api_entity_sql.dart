import 'dart:async';

import 'package:async_extension/async_extension.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

class SQLEntityRepository<O> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  final SQLRepositoryAdapter<O> sqlRepositoryAdapter;

  SQLEntityRepository(
      this.sqlRepositoryAdapter,
      EntityRepositoryProvider? provider,
      String name,
      EntityHandler<O> entityHandler,
      {Type? type})
      : super(provider, name, entityHandler, type: type);

  @override
  void initialize() {
    sqlRepositoryAdapter.ensureInitialized();
  }

  String get dialect => sqlRepositoryAdapter.dialect;

  @override
  Map<String, dynamic> information() =>
      {'queryType': 'SQL', 'dialect': dialect};

  @override
  dynamic ensureStored(o) {
    var id = getID(o, entityHandler: entityHandler);

    if (id == null) {
      return store(o);
    } else {
      ensureReferencesStored(o);
    }

    return id;
  }

  @override
  void ensureReferencesStored(o) {
    for (var fieldName in entityHandler.fieldsNames(o)) {
      var value = entityHandler.getField(o, fieldName);
      if (value == null) {
        continue;
      }

      var repository = provider.getEntityRepository(obj: value);
      if (repository == null) {
        continue;
      }

      repository.ensureStored(value);
    }
  }

  @override
  FutureOr<int> length() => sqlRepositoryAdapter.lengthSQL();

  @override
  FutureOr<Iterable<O>> select(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var sql = sqlRepositoryAdapter.generateSelectSQL(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var selRet = sqlRepositoryAdapter.selectSQL(sql,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return selRet.resolveMapped((sel) {
      var entities = sel.map((e) => entityHandler.createFromMap(e)).toList();
      return entities.resolveAll();
    });
  }

  @override
  dynamic store(O o) {
    var fields = entityHandler.getFields(o);
    var sql = sqlRepositoryAdapter.generateInsertSQL(o, fields);
    return sqlRepositoryAdapter.insertSQL(sql, fields);
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }
}
