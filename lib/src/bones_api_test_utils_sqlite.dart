import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart' as logging;

import 'bones_api_entity_db_sqlite.dart';
import 'bones_api_test_utils_config.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('APITestConfigSQLite');

/// A [APITestConfigDBSQL] for a SQLite database.
///
/// Unlike the PostgreSQL and MySQL test configurations this needs no Docker
/// container: SQLite is embedded, so [start] only decides *where* the database
/// lives — an in-memory database, or a file in a temporary directory that
/// [stop] deletes.
class APITestConfigSQLite extends APITestConfigDBSQL
    implements WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'APITestConfigSQLite';

  /// If `true` uses an in-memory database instead of a temporary file.
  final bool memory;

  /// The adapter under test.
  ///
  /// [runSQL] and [listTables] must reach the *same* database as the entity
  /// tests, and an in-memory database is only reachable through the adapter
  /// that owns its handle, so the test's adapter creator has to assign this.
  DBSQLiteAdapter? sqlAdapter;

  Directory? _tempDir;

  APITestConfigSQLite(Map<String, dynamic> apiConfig, {this.memory = false})
    : super('SQLite', apiConfig) {
    DBSQLiteAdapter.boot();
  }

  @override
  Map<String, dynamic> get dbConfig {
    var db = apiConfigMap['db'];
    if (db is! Map) {
      db = apiConfigMap['db'] = <String, dynamic>{};
    }

    var sqlite = db['sqlite'];
    if (sqlite is! Map) {
      sqlite = db['sqlite'] = <String, dynamic>{};
    }

    return sqlite as Map<String, dynamic>;
  }

  /// SQLite is embedded: there is no port to allocate.
  @override
  FutureOr<int> resolveFreePort(int port) => 0;

  /// The resolved database path (`:memory:` when [memory]).
  String get databasePath => dbConfig['path']?.toString() ?? sqliteMemoryPath;

  @override
  FutureOr<bool> start() {
    var config = dbConfig;

    if (memory) {
      config['memory'] = true;
      config['path'] = sqliteMemoryPath;
    } else {
      var dir = _tempDir ??= Directory.systemTemp.createTempSync(
        'bones_api_test_sqlite_',
      );
      config['memory'] = false;
      config['path'] = '${dir.path}/test.db';
    }

    _log.info('** STARTED> $this');

    return true;
  }

  @override
  FutureOr<bool> stop() {
    sqlAdapter = null;

    var dir = _tempDir;
    if (dir != null) {
      _tempDir = null;
      try {
        dir.deleteSync(recursive: true);
      } catch (e) {
        _log.warning("Error deleting temporary directory: ${dir.path}", e);
      }
    }

    return true;
  }

  @override
  Future<String?> runSQL(String sqlInline) async {
    var sqlAdapter = _requireAdapter();
    sqlAdapter.executeRawSQL(sqlInline);
    return '';
  }

  @override
  Future<List<String>> listTables() async =>
      _requireAdapter().listTablesNames();

  DBSQLiteAdapter _requireAdapter() {
    var sqlAdapter = this.sqlAdapter;
    if (sqlAdapter == null) {
      throw StateError(
        "Null `sqlAdapter`: the test's adapter creator must assign "
        "`APITestConfigSQLite.sqlAdapter`, so that `runSQL` and `listTables` "
        "reach the same database.",
      );
    }
    return sqlAdapter;
  }

  @override
  String toString() =>
      '$runtimeTypeNameSafe{${memory ? 'memory' : databasePath}}';
}
