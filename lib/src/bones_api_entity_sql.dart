import 'package:async_extension/async_extension.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_relational.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_initializable.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_utils.dart';

class DBSQLEntityRepository<O extends Object>
    extends DBRelationalEntityRepository<O> {
  @override
  DBSQLRepositoryAdapter<O> get repositoryAdapter =>
      super.repositoryAdapter as DBSQLRepositoryAdapter<O>;

  DBSQLEntityRepository(
      DBSQLAdapter adapter, String name, EntityHandler<O> entityHandler,
      {DBSQLRepositoryAdapter<O>? repositoryAdapter, Type? type})
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
    return '$runtimeTypeNameUnsafe[$name]@${provider.runtimeTypeNameUnsafe}$info';
  }
}

/// Base class for [EntityRepositoryProvider] with [DBSQLAdapter]s.
abstract class DBSQLEntityRepositoryProvider<A extends DBSQLAdapter>
    extends DBEntityRepositoryProvider<A> {
  @override
  FutureOr<A> buildAdapter() => DBSQLAdapter.fromConfig(
        adapterConfig,
        parentRepositoryProvider: this,
        workingPath: workingPath,
      );

  @override
  List<DBSQLEntityRepository> buildRepositories(DBSQLAdapter adapter);

  FutureOr<List<SQLBuilder>> generateCreateTableSQLs() =>
      adapter.resolveMapped((adapter) => adapter.generateCreateTableSQLs());

  FutureOr<String> generateFullCreateTableSQLs(
          {String? title, bool withDate = true}) =>
      adapter.resolveMapped((adapter) => adapter.generateFullCreateTableSQLs(
          title: title, withDate: withDate));
}
