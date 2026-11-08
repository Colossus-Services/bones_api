import 'dart:convert' as dart_convert;
import 'dart:io';
import 'dart:math' as math;

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_object.dart';
import 'bones_api_extension.dart';
import 'bones_api_extension_io.dart';
import 'bones_api_logging.dart';
import 'bones_api_types.dart';

final _log = logging.Logger('DBObjectDirectoryAdapter')..registerAsDbLogger();

/// See [DBObjectDirectoryAdapter.fileLimited].
final FileLimited _fileLimited = FileLimited(name: 'DBObjectDirectoryAdapter');

class DBObjectDirectoryAdapterContext
    implements Comparable<DBObjectDirectoryAdapterContext> {
  final int id;

  DBObjectDirectoryAdapterContext(this.id);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    _closed = true;
  }

  @override
  int compareTo(DBObjectDirectoryAdapterContext other) =>
      id.compareTo(other.id);
}

/// A [DBObjectAdapter] that stores objects in a [Directory].
///
/// Simulates an Object Database adapter. Useful for development.
///
/// Doesn't enforce unique fields, as the other [DBObjectAdapter]s (see
/// [DBObjectAdapter]: "Unique fields are not enforced").
class DBObjectDirectoryAdapter
    extends DBObjectAdapter<DBObjectDirectoryAdapterContext> {
  /// Limits the concurrent object file reads of all the
  /// [DBObjectDirectoryAdapter]s (default: [FileLimited.defaultSemaphoreLimit]),
  /// so concurrent selects of large tables can't open thousands of files at
  /// once (`Too many open files`). Also the batch size of a select's reads.
  ///
  /// Tune it with [FileLimited.setSemaphoreLimit] (e.g. for a low limit of
  /// open files shared with other components).
  static FileLimited get fileLimited => _fileLimited;

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBObjectAdapter.boot();

    DBObjectAdapter.registerAdapter(
      ['object.directory', 'obj.dir'],
      DBObjectDirectoryAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBObjectDirectoryAdapter?> _instantiate(
    Map<String, dynamic> config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBObjectDirectoryAdapter.fromConfig(
        config,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath,
      );
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final bool development;
  final Directory directory;

  DBObjectDirectoryAdapter(
    this.directory, {
    bool? development,
    super.generateTables,
    super.populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.workingPath,
    super.log,
  }) : development = development ?? false,
       super(
         'object.directory',
         1,
         3,
         const DBAdapterCapability(
           dialect: DBDialect('object'),
           transactions: true,
           transactionAbort: true,
           constraintSupport: false,
           multiIsolateSupport: true,
           connectivity: DBAdapterCapabilityConnectivity.none,
         ),
       ) {
    boot();

    var directoryExists = directory.existsSync();

    if (!directoryExists &&
        this.development &&
        directory.path.contains('/tmp/')) {
      directory.createSync();
      directoryExists = directory.existsSync();
      if (directoryExists) {
        _log.warning(
          "[development] Auto-created `directory`: ${directory.path}",
        );
      }
    }

    if (!directoryExists) {
      throw ArgumentError(
        "[DBObjectDirectoryAdapter]: Directory doesn't exists: $directory",
      );
    }

    var modeString = directory.statSync().modeString();
    if (!modeString.contains('rw')) {
      throw StateError(
        "[DBObjectDirectoryAdapter]: Can't read+write the directory: $directory",
      );
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<DBObjectDirectoryAdapter> fromConfig(
    Map<String, dynamic>? config, {
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var directoryPath = config?['path'] ?? config?['directory'];

    if (directoryPath == null) {
      throw ArgumentError("Config without `path` entry!");
    }

    var development = config?.getAsBool('development') ?? false;

    var populate = config?['populate'];

    var generateTables = false;
    Object? populateTables;
    Object? populateSource;
    Object? populateSourceVariables;

    if (populate is Map) {
      generateTables =
          populate.getAsBool('generateTables', ignoreCase: true) ??
          populate.getAsBool('generate-tables', ignoreCase: true) ??
          populate.getAsBool('generate_tables', ignoreCase: true) ??
          false;

      populateTables = populate['tables'];
      populateSource = populate['source'];
      populateSourceVariables = populate['variables'];
    }

    var directory = Directory(directoryPath);

    var adapter = DBObjectDirectoryAdapter(
      directory,
      development: development,
      parentRepositoryProvider: parentRepositoryProvider,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      populateSourceVariables: populateSourceVariables,
      workingPath: workingPath,
    );

    return adapter;
  }

  @override
  String getConnectionURL(DBObjectDirectoryAdapterContext connection) =>
      'object.directory://${connection.id}';

  int _connectionCount = 0;

  /// The shared [DBObjectAdapter.openTransaction], typed as this adapter's
  /// context: it opens synchronously ([createConnection] is synchronous), as
  /// this adapter's own `openTransaction` was declared before the shared
  /// implementation (a caller may rely on the concrete type).
  @override
  DBObjectDirectoryAdapterContext openTransaction(Transaction transaction) =>
      super.openTransaction(transaction) as DBObjectDirectoryAdapterContext;

  @override
  DBObjectDirectoryAdapterContext createConnection() {
    var id = ++_connectionCount;

    return DBObjectDirectoryAdapterContext(id);
  }

  @override
  bool closeConnection(DBObjectDirectoryAdapterContext connection) {
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  Map<String, dynamic> information({bool extended = false, String? table}) {
    var info = <String, dynamic>{};
    info['tables'] = _listTablesNames();
    return info;
  }

  @override
  logging.Logger get adapterLogger => _log;

  @override
  DBObjectDirectoryAdapterException createAdapterException(
    String type,
    String message, {
    Object? parentError,
    StackTrace? parentStackTrace,
    Object? operation,
    Object? previousError,
  }) => DBObjectDirectoryAdapterException(
    type,
    message,
    parentError: parentError,
    parentStackTrace: parentStackTrace,
    operation: operation,
    previousError: previousError,
  );

  @override
  String toString() {
    var closedStr = isClosed ? '{closed}' : '';
    return 'DBObjectDirectoryAdapter#$instanceID$closedStr@${directory.path}';
  }

  @override
  FutureOr<int> doCount(
    TransactionOperation op,
    String entityName,
    String table, {
    EntityMatcher? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<int, int>? preFinish,
  }) {
    return executeOperation(
      op,
      (conn) => _doCountImpl(op, table, matcher, parameters ?? namedParameters),
      preFinish,
    );
  }

  int _doCountImpl(
    TransactionOperation op,
    String table,
    EntityMatcher? matcher,
    Object? parameters,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return 0;

    if (matcher != null) {
      if (matcher is ConditionID) {
        var id = matcher.resolveIDValue(parameters: parameters);

        var objFile = _resolveObjectFile(table, id);
        return objFile.existsSync() ? 1 : 0;
      }

      throw UnsupportedError("Relationship count not supported for: $matcher");
    }

    var list = _listTableFiles(tableDir);
    return list.length;
  }

  List<File> _listTableFiles(Directory tableDir) {
    var list = tableDir.listSync(recursive: false).whereType<File>().where((e) {
      var path = e.path;
      return path.endsWith('.json') && !path.startsWith('.');
    }).toList();
    return list;
  }

  List<Directory> _listTablesDirs() {
    var dirs = directory.listSync().whereType<Directory>().toList();
    return dirs;
  }

  List<String> _listTablesNames() =>
      _listTablesDirs().map((d) => pack_path.split(d.path).last).toList();

  @override
  FutureOr<List<I>> doExistIDs<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    List<I> ids,
  ) {
    return executeOperation<List<I>, List<I>>(
      op,
      (conn) => _doExistIDsImpl(op, table, ids),
      null,
    );
  }

  List<I> _doExistIDsImpl<I extends Object>(
    TransactionOperation op,
    String table,
    List<I> ids,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var existIDs = ids.where((id) {
      var objFile = _resolveObjectFile(table, id);
      return objFile.existsSync();
    }).toList();

    return existIDs;
  }

  @override
  FutureOr<R?> doSelectByID<R>(
    TransactionOperation op,
    String entityName,
    String table,
    Object id, {
    PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish,
  }) => executeOperation<Map<String, dynamic>?, R?>(
    op,
    (conn) => _doSelectByIDImpl<R>(table, id, entityName),
    preFinish,
  );

  FutureOr<Map<String, dynamic>?> _doSelectByIDImpl<R>(
    String table,
    Object id,
    String entityName,
  ) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return null;

    var entry = await _readObject(table, id);
    return entry;
  }

  @override
  FutureOr<List<R>> doSelectByIDs<R>(
    TransactionOperation op,
    String entityName,
    String table,
    List<Object> ids, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<List<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeOperation<List<Map<String, dynamic>>, List<R>>(
    op,
    (conn) => _doSelectByIDsImpl<R>(
      table,
      ids,
      entityName,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ),
    preFinish,
  );

  FutureOr<List<Map<String, dynamic>>> _doSelectByIDsImpl<R>(
    String table,
    List<Object> ids,
    String entityName, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var entries = await _readObjects(table, ids);

    return applyTableOrderAndPagination(
      table,
      entries,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    );
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
    TransactionOperation op,
    String entityName,
    String table, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>? preFinish,
  }) => executeOperation<Iterable<Map<String, dynamic>>, List<R>>(
    op,
    (conn) => _doSelectAllImpl<R>(
      table,
      entityName,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ),
    preFinish,
  );

  FutureOr<List<Map<String, dynamic>>> _doSelectAllImpl<R>(
    String table,
    String entityName, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    var files = _listTableFiles(tableDir);

    var ids = files.map((f) {
      var fileName = pack_path.split(f.path).last;
      return pack_path.withoutExtension(fileName);
    });

    var entries = _readObjects(table, ids);

    return entries.resolveMapped(
      (entries) => applyTableOrderAndPagination(
        table,
        entries,
        limit: limit,
        offset: offset,
        orderByID: orderByID,
        orderDirection: orderDirection,
      ),
    );
  }

  @override
  FutureOr<R> doDelete<R>(
    TransactionOperation op,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  }) => executeOperation<Iterable<Map<String, dynamic>>, R>(
    op,
    (conn) =>
        _doDeleteImpl<R>(op, table, matcher, parameters ?? namedParameters),
    preFinish,
  );

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteImpl<R>(
    TransactionOperation op,
    String table,
    EntityMatcher<dynamic> matcher,
    Object? parameters,
  ) async {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) return [];

    if (matcher is ConditionID) {
      var id = matcher.resolveIDValue(parameters: parameters);

      // Synchronous (as `store`), not queued behind the reads of concurrent
      // selects. A concurrent delete of the same object can remove the file
      // at any point: then nothing is deleted here.
      var entry = _readObjectSync(table, id);
      if (entry == null) return [];

      try {
        _resolveObjectFile(table, id).deleteSync();
      } on PathNotFoundException {
        return [];
      }

      return [entry];
    }

    throw UnsupportedError("Relationship delete not supported for: $matcher");
  }

  @override
  FutureOr<dynamic> doInsert<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation? preFinish,
  }) => executeOperation<dynamic, dynamic>(
    op,
    (conn) => _doInsertImpl<O>(op, table, fields, entityName),
    preFinish,
  );

  Object _doInsertImpl<O>(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    var entry = normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    var idField = getTableIDFieldName(table);
    var id = entry[idField];

    _log.info(
      '[transaction:${op.transactionId}] doInsert> INSERT INTO $table OBJECT `$id`',
    );

    if (id == null) {
      throw StateError("Can't determine object ID to store it: $fields");
    }

    _saveObject(table, id, entry);

    return id;
  }

  @override
  FutureOr<dynamic> doUpdate<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Object id,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation? preFinish,
    bool allowAutoInsert = false,
  }) => executeOperation<dynamic, dynamic>(
    op,
    (conn) => _doUpdateImpl(op, table, fields, entityName, id),
    preFinish,
  );

  Object _doUpdateImpl(
    TransactionOperation op,
    String table,
    Map<String, dynamic> fields,
    String entityName,
    Object id,
  ) {
    var tableDir = _resolveTableDirectory(table);
    if (!tableDir.existsSync()) {
      tableDir.createSync();
    }

    _log.info(
      '[transaction:${op.transactionId}] doUpdate> UPDATE INTO $table OBJECT `$id`',
    );

    var changes = normalizeEntityJSON(
      fields,
      entityName: entityName,
      table: table,
    );

    // A partial update (only the changed `fields`): merged into the stored
    // object (if any: an auto-insert).
    var entry = <String, dynamic>{
      ...?_readStoredObjectForUpdate(table, id),
      ...changes,
    };

    var idField = getTableIDFieldName(table);
    entry[idField] = id;

    _saveObject(table, id, entry);

    return id;
  }

  /// The stored object to merge an update into: `null` if it doesn't exist,
  /// or can't be parsed (e.g. a file truncated by a crash in the middle of a
  /// write: the update rewrites it, as before the merge).
  Map<String, dynamic>? _readStoredObjectForUpdate(String table, Object id) {
    try {
      return _readObjectSync(table, id);
    } on FormatException catch (e) {
      _log.warning(
        "Can't parse the stored object `$table`#$id (rewritten by the "
        "update): $e",
      );
      return null;
    }
  }

  /// Reads synchronously (as [_saveObject] writes). Returns `null` if the
  /// object doesn't exist.
  Map<String, dynamic>? _readObjectSync(String table, Object? id) {
    var file = _resolveObjectFile(table, id);
    String enc;
    try {
      enc = file.readAsStringSync();
    } on PathNotFoundException {
      return null;
    }
    return dart_convert.json.decode(enc) as Map<String, dynamic>;
  }

  /// Writes synchronously, and must stay synchronous.
  ///
  /// Every reader in this adapter checks the filesystem synchronously
  /// ([Directory.listSync], [File.existsSync]), so an asynchronous write would
  /// let a store return before its object is visible: a `store` immediately
  /// followed by a `selectAll`/`selectByID` could miss it, and
  /// [_doSelectAllImpl] would silently drop it (a not-yet-written file reads
  /// back as `null`, which `resolveAllNotNull` discards).
  void _saveObject(String table, Object? id, Map<String, dynamic> obj) {
    var file = _resolveObjectFile(table, id);
    var enc = dart_convert.json.encode(
      obj,
      toEncodable: DBObjectAdapter.toEncodableJson,
    );
    file.writeAsStringSync(enc);
  }

  /// Reads an object under [fileLimited]. Returns `null` if the object
  /// doesn't exist, including when it's deleted while the read waits for the
  /// semaphore (no `existsSync` before it: the file is just opened).
  Future<Map<String, dynamic>?> _readObject(String table, Object? id) async {
    var file = _resolveObjectFile(table, id);
    String enc;
    try {
      enc = await _fileLimited.readAsString(file);
    } on PathNotFoundException {
      return null;
    }
    var obj = dart_convert.json.decode(enc) as Map<String, dynamic>;
    return obj;
  }

  /// Reads the objects of [ids] (the existing ones, in order) in batches of
  /// the [fileLimited] limit: concurrent selects queue at most a batch of
  /// reads each (not one read per object).
  Future<List<Map<String, dynamic>>> _readObjects(
    String table,
    Iterable<Object?> ids,
  ) async {
    var idsList = ids.toList();
    var batchSize = _fileLimited.getSemaphoreLimit();

    var entries = <Map<String, dynamic>>[];

    for (var i = 0; i < idsList.length; i += batchSize) {
      var batch = idsList.sublist(i, math.min(i + batchSize, idsList.length));
      var objs = await Future.wait(batch.map((id) => _readObject(table, id)));
      entries.addAll(objs.nonNulls);
    }

    return entries;
  }

  File _resolveObjectFile(String table, Object? id) {
    var idStr = normalizeObjectID(id);
    var tableDir = _resolveTableDirectory(table);
    var file = File(pack_path.join(tableDir.path, '$idStr.json'));
    return file;
  }

  Directory _resolveTableDirectory(String table) {
    var tableStr = normalizeTableName(table);
    var tableDir = Directory(pack_path.join(directory.path, tableStr));
    return tableDir;
  }
}

/// Error thrown by [DBObjectDirectoryAdapter] operations.
class DBObjectDirectoryAdapterException extends DBObjectAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectDirectoryAdapterException';

  DBObjectDirectoryAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}
