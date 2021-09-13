import 'dart:async';

import 'package:async_extension/async_extension.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

class SQLEntityRepository<O> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  final SQLRepositoryAdapter<O> sqlRepositoryAdapter;

  SQLEntityRepository(
      SQLAdapter adapter, String name, EntityHandler<O> entityHandler,
      {SQLRepositoryAdapter<O>? repositoryAdapter, Type? type})
      : sqlRepositoryAdapter =
            repositoryAdapter ?? adapter.getRepositoryAdapter<O>(name)!,
        super(adapter, name, entityHandler, type: type);

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
    ensureReferencesStored(o);

    var id = getID(o, entityHandler: entityHandler);

    if (id == null) {
      return store(o);
    } else {
      return id;
    }
  }

  @override
  void ensureReferencesStored(o) {
    for (var fieldName in entityHandler.fieldsNames(o)) {
      var value = entityHandler.getField(o, fieldName);
      if (value == null) {
        continue;
      }

      if (!EntityHandler.isValidType(value.runtimeType)) {
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
  FutureOr<int> length() => count();

  @override
  FutureOr<int> count(
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var retSql = sqlRepositoryAdapter.generateCountSQL(
        matcher: matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return retSql.resolveMapped((sql) => sqlRepositoryAdapter.countSQL(sql));
  }

  @override
  FutureOr<Iterable<O>> select(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var retSql = sqlRepositoryAdapter.generateSelectSQL(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return retSql.resolveMapped((sql) {
      var selRet = sqlRepositoryAdapter.selectSQL(sql);

      return selRet.resolveMapped((sel) {
        var entities = sel.map((e) => entityHandler.createFromMap(e)).toList();
        return entities.resolveAll();
      });
    });
  }

  @override
  FutureOr<dynamic> store(O o) {
    ensureReferencesStored(o);

    var fields = entityHandler.getFields(o);
    var retSql = sqlRepositoryAdapter.generateInsertSQL(o, fields);

    return retSql.resolveMapped((sql) {
      var retId = sqlRepositoryAdapter.insertSQL(sql, fields);

      return retId.resolveMapped((id) {
        entityHandler.setID(o, id);
        return id;
      });
    });
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var retSql = sqlRepositoryAdapter.generateDeleteSQL(matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return retSql.resolveMapped((sql) {
      var selRet = sqlRepositoryAdapter.deleteSQL(sql);

      return selRet.resolveMapped((sel) {
        var entities = sel.map((e) => entityHandler.createFromMap(e)).toList();
        return entities.resolveAll();
      });
    });
  }
}
