import 'dart:async';

import 'package:bones_api/bones_api.dart';

import 'package:async_extension/async_extension.dart';

import 'bones_api_data_adapter.dart';

class DataRepositorySQL<O> extends DataRepository<O> with DataFieldAccessor<O> {
  final SQLRepositoryAdapter<O> sqlRepositoryAdapter;

  DataRepositorySQL(this.sqlRepositoryAdapter, DataRepositoryProvider? provider,
      String name, DataHandler<O> dataHandler,
      {Type? type})
      : super(provider, name, dataHandler, type: type);

  @override
  void initialize() {
    sqlRepositoryAdapter.ensureInitialized();
  }

  @override
  Map<String, dynamic> information() =>
      {'queryType': 'SQL', 'dialect': sqlRepositoryAdapter.dialect};

  @override
  dynamic ensureStored(o) {
    var id = getID(o, dataHandler: dataHandler);

    if (id == null) {
      return store(o);
    } else {
      ensureReferencesStored(o);
    }

    return id;
  }

  @override
  void ensureReferencesStored(o) {
    for (var fieldName in dataHandler.fieldsNames(o)) {
      var value = dataHandler.getField(o, fieldName);
      if (value == null) {
        continue;
      }

      var repository = provider.getDataRepository(obj: value);
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
      var entities = sel.map((e) => dataHandler.createFromMap(e)).toList();
      return entities.resolveAll();
    });
  }

  @override
  dynamic store(O o) {
    var fields = dataHandler.getFields(o);
    var sql = sqlRepositoryAdapter.generateInsertSQL(o, fields);
    return sqlRepositoryAdapter.insertSQL(sql, fields);
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }
}
