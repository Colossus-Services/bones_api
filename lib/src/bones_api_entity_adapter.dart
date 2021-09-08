import 'dart:async';
import 'dart:convert';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_condition.dart';
import 'bones_api_condition_sql.dart';
import 'bones_api_entity.dart';
import 'bones_api_mixin.dart';

final _log = logging.Logger('SQLRepositoryAdapter');

typedef PasswordProvider = FutureOr<String> Function(String user);

class SQL {
  final String sql;

  final dynamic parameters;

  SQL(this.sql, this.parameters);

  @override
  String toString() {
    return 'SQL<< $sql >>( ${json.encode(parameters)} )';
  }
}

abstract class SQLAdapter<C>
    with Initializable, Pool<C>
    implements EntityRepositoryProvider {
  final int minConnections;

  final int maxConnections;

  final String dialect;

  final EntityRepositoryProvider? parentRepositoryProvider;

  SQLAdapter(this.minConnections, this.maxConnections, this.dialect,
      {this.parentRepositoryProvider});

  static final ConditionSQLEncoder _conditionSQLGenerator =
      ConditionSQLEncoder();

  @override
  void initialize();

  String generateLengthSQL(String table) {
    throw UnimplementedError();
  }

  SQL generateSelectSQL(String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (matcher is Condition) {
      Map<String, dynamic> sqlParameters = <String, dynamic>{};

      var conditionSQL = _conditionSQLGenerator.encode(matcher, sqlParameters,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      String sqlQuery;
      if (conditionSQL.isNotEmpty) {
        sqlQuery = 'SELECT * FROM $table WHERE $conditionSQL';
      } else {
        sqlQuery = 'SELECT * FROM $table';
      }

      var sql = SQL(sqlQuery, sqlParameters);

      return sql;
    } else {
      throw StateError('$matcher');
    }
  }

  String generateInsertSQL(String table, Map<String, dynamic> fields) {
    throw UnimplementedError();
  }

  T? executeSQL<T>(String sql) {
    return null;
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(String table, SQL sql,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return catchFromPool().resolveMapped((connection) {
      _log.log(logging.Level.INFO, 'selectSQL> $sql');

      return doSelectSQL(table, sql, connection,
              parameters: parameters,
              positionalParameters: positionalParameters,
              namedParameters: namedParameters)
          .resolveMapped((entries) {
        if (mapper != null) {
          return entries.map(mapper);
        } else {
          return entries;
        }
      });
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String table, SQL sql, C connection,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});

  FutureOr<C> createConnection();

  FutureOr<bool> isConnectionValid(C connection);

  FutureOr<bool> checkConnections() => removeInvalidElementsFromPool();

  @override
  FutureOr<bool> isPoolElementValid(C o) => isConnectionValid(o);

  @override
  FutureOr<bool> checkPool() =>
      checkPoolSize(minConnections, maxConnections, 30000);

  @override
  FutureOr<C?> createPoolElement() {
    if (poolSize < maxConnections) {
      return createConnection();
    } else {
      return null;
    }
  }

  final Map<String, SQLRepositoryAdapter> _repositoriesAdapters =
      <String, SQLRepositoryAdapter>{};

  SQLRepositoryAdapter<O> getRepositoryAdapter<O>(String name,
      {String? tableName, Type? type}) {
    return _repositoriesAdapters.putIfAbsent(
        name,
        () => SQLRepositoryAdapter<O>(this, name,
            tableName: tableName, type: type)) as SQLRepositoryAdapter<O>;
  }

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  @override
  void registerEntityRepository<O>(EntityRepository<O> entityRepository) {
    _entityRepositories[entityRepository.type] = entityRepository;
  }

  @override
  EntityRepository<O>? getEntityRepository<O>({O? obj, Type? type}) =>
      _getEntityRepositoryImpl<O>(obj: obj, type: type) ??
      EntityRepositoryProvider.globalProvider
          .getEntityRepository<O>(obj: obj, type: type);

  EntityRepository<O>? _getEntityRepositoryImpl<O>({O? obj, Type? type}) {
    var entityRepository = _entityRepositories[O];

    if (entityRepository == null && obj != null) {
      entityRepository = _entityRepositories[obj.runtimeType];
    }

    if (entityRepository == null && type != null) {
      entityRepository = _entityRepositories[type];
    }

    if (entityRepository != null) {
      return entityRepository as EntityRepository<O>;
    }

    entityRepository =
        parentRepositoryProvider?.getEntityRepository<O>(obj: obj, type: type);
    if (entityRepository != null) {
      return entityRepository as EntityRepository<O>;
    }

    for (var p in _knownEntityRepositoryProviders) {
      entityRepository = p.getEntityRepository<O>(obj: obj, type: type);
      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      }
    }

    return null;
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  @override
  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    _knownEntityRepositoryProviders.add(provider);
  }
}

class SQLRepositoryAdapter<O> with Initializable {
  final SQLAdapter databaseAdapter;

  final String name;

  final String tableName;

  final Type type;

  SQLRepositoryAdapter(this.databaseAdapter, this.name,
      {String? tableName, Type? type})
      : tableName = tableName ?? name,
        type = type ?? O;

  @override
  void initialize() {
    databaseAdapter.ensureInitialized();
  }

  String get dialect => databaseAdapter.dialect;

  FutureOr<int> lengthSQL() {
    var sql = databaseAdapter.generateLengthSQL(tableName);
    return databaseAdapter.executeSQL(sql)!;
  }

  SQL generateSelectSQL(EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      databaseAdapter.generateSelectSQL(tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(SQL sql,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return databaseAdapter.selectSQL(tableName, sql,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  String generateInsertSQL(O o, Map<String, dynamic> fields) {
    return databaseAdapter.generateInsertSQL(tableName, fields);
  }

  Iterable<O> insertSQL(String sql, Map<String, dynamic> fields) {
    return databaseAdapter.executeSQL(sql)!;
  }
}
