import 'package:async_extension/async_extension.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_entity_adapter_db_relational.dart';
import 'bones_api_entity_adapter_sql.dart';
import 'bones_api_initializable.dart';
import 'bones_api_sql_builder.dart';

class SQLEntityRepository<O extends Object>
    extends DBRelationalEntityRepository<O> {
  @override
  SQLRepositoryAdapter<O> get repositoryAdapter =>
      super.repositoryAdapter as SQLRepositoryAdapter<O>;

  SQLEntityRepository(
      SQLAdapter adapter, String name, EntityHandler<O> entityHandler,
      {SQLRepositoryAdapter<O>? repositoryAdapter, Type? type})
      : super(adapter, name, entityHandler,
            repositoryAdapter: repositoryAdapter, type: type);

  @override
  FutureOr<InitializationResult> initialize() => provider
          .executeInitialized(
              () => repositoryAdapter.ensureInitialized(parent: this),
              parent: this)
          .resolveMapped((result) {
        return InitializationResult.ok(this, dependencies: [
          provider,
          repositoryAdapter,
          ...result.dependencies
        ]);
      });

  @override
  SQLDialect get dialect => repositoryAdapter.dialect;

  @override
  Map<String, dynamic> information({bool extended = false}) => {
        'queryType': 'SQL',
        'dialect': dialectName,
        'table': name,
        if (extended) 'adapter': repositoryAdapter.information(extended: true),
      };

  // ignore: unused_element
  String _resolveTableColumnToEntityField(String tableField, [O? o]) {
    var fieldsNames = entityHandler.fieldsNames(o);
    var entityFieldName =
        entityHandler.resolveFiledName(fieldsNames, tableField);
    if (entityFieldName == null) {
      throw StateError(
          "Can't resolve the table column `$tableField` to one of the entity `${entityHandler.type}` fields: $fieldsNames");
    }
    return entityFieldName;
  }

  @override
  String toString() {
    var info = information();
    return '$runtimeType[$name]@${provider.runtimeType}$info';
  }
}

/// Base class for [EntityRepositoryProvider] with [SQLAdapter]s.
abstract class SQLEntityRepositoryProvider<A extends SQLAdapter>
    extends DBEntityRepositoryProvider<A> {
  @override
  FutureOr<A> buildAdapter() => SQLAdapter.fromConfig(
        adapterConfig,
        parentRepositoryProvider: this,
        workingPath: workingPath,
      );

  @override
  List<SQLEntityRepository> buildRepositories(SQLAdapter adapter);

  FutureOr<List<SQLBuilder>> generateCreateTableSQLs() =>
      adapter.resolveMapped((adapter) => adapter.generateCreateTableSQLs());

  FutureOr<String> generateFullCreateTableSQLs(
          {String? title, bool withDate = true}) =>
      adapter.resolveMapped((adapter) => adapter.generateFullCreateTableSQLs(
          title: title, withDate: withDate));
}
