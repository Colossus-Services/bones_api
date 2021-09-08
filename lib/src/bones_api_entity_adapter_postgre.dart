import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:postgres/postgres.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

final _log = logging.Logger('PostgreAdapter');

class PostgreSQLAdapter extends SQLAdapter<PostgreSQLConnection> {
  final String host;
  final int port;
  final String databaseName;

  final String username;

  final String? _password;
  final PasswordProvider? _passwordProvider;

  PostgreSQLAdapter(this.host, this.databaseName, this.username,
      {String? password,
      PasswordProvider? passwordProvider,
      this.port = 5432,
      int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider})
      : _password = password,
        _passwordProvider = passwordProvider,
        super(minConnections, maxConnections, 'postgre',
            parentRepositoryProvider: parentRepositoryProvider) {
    if (_password == null && passwordProvider == null) {
      throw ArgumentError("No `password` or `passwordProvider` ");
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  FutureOr<String> _getPassword() {
    if (_password != null) {
      return _password!;
    } else {
      return _passwordProvider!(username);
    }
  }

  @override
  FutureOr<PostgreSQLConnection> createConnection() async {
    var password = await _getPassword();

    var connection = PostgreSQLConnection(host, port, databaseName,
        username: username, password: password);
    await connection.open();

    _log.log(logging.Level.INFO, 'createConnection> $connection');

    return connection;
  }

  @override
  FutureOr<bool> isConnectionValid(PostgreSQLConnection connection) {
    if (connection.isClosed) {
      return false;
    }
    return true;
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String table, SQL sql, PostgreSQLConnection connection,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return connection
        .mappedResultsQuery(sql.sql, substitutionValues: sql.parameters)
        .resolveMapped((results) {
      var entries =
          results.map((e) => e[table]).whereType<Map<String, dynamic>>();

      return entries;
    });
  }
}
