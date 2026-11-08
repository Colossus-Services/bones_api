import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:logging/logging.dart' as logging;
import 'package:meta/meta.dart';
import 'package:statistics/statistics.dart' show StringExtension;
import 'package:swiss_knife/swiss_knife.dart' show parseBool;

import 'bones_api_logging.dart';

final _log = logging.Logger('DBObjectAdapter')..registerAsDbLogger();

/// Base class for Object DB adapters.
///
/// A [DBObjectAdapter] implementation is responsible to connect to the database
/// and store/fecth/delete the objects.
///
/// All [DBObjectAdapter]s comes with a built-in connection pool.
///
/// ## Unique fields are not enforced
///
/// The [DBObjectAdapter]s ([DBObjectMemoryAdapter], `DBObjectDirectoryAdapter`
/// and `DBObjectGCSAdapter`) store each entity as an independent object (by
/// ID), and don't enforce the unique fields: [EntityField.unique] and
/// [EntityIndex.unique]. Two entities with the same unique value are both
/// stored, without an error.
///
/// Object storages (e.g. Google Cloud Storage, Amazon S3) are not designed
/// for that: there's no index over the objects' values, nor transactions over
/// multiple objects. Checking by scanning the stored objects is slow and,
/// with concurrent writers, not reliable.
///
/// When the uniqueness is required, use a SQL adapter (the database's
/// `UNIQUE` constraints: `DBPostgreSQLAdapter`, `DBMySQLAdapter`,
/// `DBSQLiteAdapter`), or [DBSQLMemoryAdapter] (in memory, it checks them).
abstract class DBObjectAdapter<C extends Object> extends DBAdapter<C> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBAdapter.boot();
    DBObjectMemoryAdapter.boot();
  }

  static final DBAdapterRegister<Object, DBObjectAdapter<Object>>
  adapterRegister = DBAdapter.adapterRegister.createRegister();

  static List<String> get registeredAdaptersNames =>
      adapterRegister.registeredAdaptersNames;

  static List<Type> get registeredAdaptersTypes =>
      adapterRegister.registeredAdaptersTypes;

  static void registerAdapter<C extends Object, A extends DBObjectAdapter<C>>(
    List<String> names,
    Type type,
    DBAdapterInstantiator<C, A> adapterInstantiator,
  ) {
    boot();
    adapterRegister.registerAdapter(names, type, adapterInstantiator);
  }

  static DBAdapterInstantiator<C, A>?
  getAdapterInstantiator<C extends Object, A extends DBObjectAdapter<C>>({
    String? name,
    Type? type,
  }) => adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBAdapterInstantiator<C, A>, Map<String, dynamic>>>
  getAdapterInstantiatorsFromConfig<
    C extends Object,
    A extends DBObjectAdapter<C>
  >(Map<String, dynamic> config) =>
      adapterRegister.getAdapterInstantiatorsFromConfig<C, A>(config);

  static bool? parseConfigLog(Map<String, dynamic>? config) {
    var log = config?['log'];
    return parseBool(log);
  }

  /// The `toEncodable` of the JSON encoding of a stored object: converts a
  /// value that is not JSON encodable (e.g. a [DateTime], an enum or a
  /// `Decimal`) as [Json.toJson] (parsed back by the entity's handler).
  static Object? toEncodableJson(Object? o) => Json.toJson(o);

  final bool log;

  DBObjectAdapter(
    super.name,
    super.minConnections,
    super.maxConnections,
    super.capability, {
    bool generateTables = false,
    Object? populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.connectivity,
    super.workingPath,
    this.log = false,
  }) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static FutureOr<A> fromConfig<C extends Object, A extends DBObjectAdapter<C>>(
    Map<String, dynamic> config, {
    int minConnections = 1,
    int maxConnections = 3,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
        "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}",
      );
    }

    return DBAdapter.instantiateAdaptor<C, A>(
      instantiators,
      config,
      minConnections: minConnections,
      maxConnections: maxConnections,
      parentRepositoryProvider: parentRepositoryProvider,
      workingPath: workingPath,
    );
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[?parentRepositoryProvider];
  }

  // -----------------------------------------------------------------------
  // Implementation shared by the object adapters (memory, directory, GCS).
  //
  // The members below were copy-pasted in each adapter, differing only in the
  // context type `C`, the logger, the exception type and the encoding of the
  // bytes fields. Those differences are the hooks [adapterLogger],
  // [createAdapterException] and [encodeBytesAsDataURL].
  // -----------------------------------------------------------------------

  /// The logger of this adapter's messages (e.g. the resolved [TableScheme]s).
  ///
  /// Each adapter overrides it with its own logger, so its messages keep
  /// their logger name (e.g. `DBObjectDirectoryAdapter`).
  @protected
  logging.Logger get adapterLogger => _log;

  /// Creates the error of a failed operation of this adapter (see
  /// [resolveError]).
  ///
  /// Each adapter overrides it to throw its own exception type (e.g.
  /// `DBObjectGCSAdapterException`): callers can catch an adapter's errors by
  /// type.
  @protected
  DBObjectAdapterException createAdapterException(
    String type,
    String message, {
    Object? parentError,
    StackTrace? parentStackTrace,
    Object? operation,
    Object? previousError,
  }) => DBObjectAdapterException(
    type,
    message,
    parentError: parentError,
    parentStackTrace: parentStackTrace,
    operation: operation,
    previousError: previousError,
  );

  /// If `true`, a bytes ([Uint8List]) field is stored as a [DataURLBase64]
  /// string, by [normalizeEntityJSON].
  ///
  /// The adapters that encode the objects as JSON (directory, GCS) need it,
  /// as JSON has no bytes type. [DBObjectMemoryAdapter] keeps the objects in
  /// memory, so it stores the bytes as they are (overriding it as `false`).
  @protected
  bool get encodeBytesAsDataURL => true;

  /// The registered [TableScheme]s, by table name (see [addTableSchemes]).
  ///
  /// A table without a registered scheme has it resolved from its
  /// [EntityHandler] (see [getTableSchemeImpl]).
  final Map<String, TableScheme> tablesSchemes = <String, TableScheme>{};

  /// Registers [tablesSchemes] (replacing the ones with the same name).
  void addTableSchemes(Iterable<TableScheme> tablesSchemes) {
    for (var s in tablesSchemes) {
      this.tablesSchemes[s.name] = s;
    }
  }

  @override
  TableScheme? getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) {
    var tableScheme = tablesSchemes[table];
    if (tableScheme != null) return tableScheme;

    var entityHandler = getEntityHandler(tableName: table);
    if (entityHandler == null) {
      // A relationship table has no entity: its scheme is the 2 ID fields
      // (source and target) of the relationship.
      if (relationship != null) {
        var sourceId =
            '${relationship.sourceTable}_${relationship.sourceField}';
        var targetId =
            '${relationship.targetTable}_${relationship.targetField}';

        tableScheme = TableScheme(
          table,
          relationship: true,
          idFieldName: sourceId,
          fieldsTypes: {
            sourceId: relationship.sourceFieldType,
            targetId: relationship.targetFieldType,
          },
        );

        adapterLogger.info('relationship> $tableScheme');

        return tableScheme;
      }

      throw StateError(
        "Can't resolve `TableScheme` for table `$table`. No `EntityHandler` found for table `$table`!",
      );
    }

    var idFieldName = entityHandler.idFieldName();

    var entityFieldsTypes = entityHandler.fieldsTypes();

    var fieldsTypes = entityFieldsTypes.map(
      (key, value) => MapEntry(key, value.type),
    );

    tableScheme = TableScheme(
      table,
      relationship: relationship != null,
      idFieldName: idFieldName,
      fieldsTypes: fieldsTypes,
    );

    adapterLogger.info('$tableScheme');

    return tableScheme;
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) {
    return tablesSchemes[table]?.fieldsTypes;
  }

  @override
  FutureOr<bool> isConnectionValid(C connection, {bool checkUsage = true}) =>
      true;

  /// The ID field of [table]: from its registered [TableScheme], or `id`.
  @protected
  String getTableIDFieldName(String table) {
    var tablesScheme = tablesSchemes[table];

    var idField = tablesScheme?.idFieldName ?? 'id';
    return idField;
  }

  /// Orders (by the ID field of [table]) and paginates the selected
  /// [entries]: the object adapters select all the objects (no query
  /// engine), and then apply the select's order and limits here.
  @protected
  List<Map<String, dynamic>> applyTableOrderAndPagination(
    String table,
    Iterable<Map<String, dynamic>> entries, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    var idField = getTableIDFieldName(table);

    return applySelectOrderAndPagination(
      entries,
      (e) => e[idField],
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ).toList();
  }

  static final _regExpNormalizeIDInvalidChars = RegExp(r'[^\w.-]+');
  static final _regExpNormalizeIDInvalidPrefix = RegExp(r'^\.+');

  /// Normalizes the object ID [o] into a safe file/object name: only word
  /// characters, `.` and `-`, no leading `.` (no hidden files, nor `..`),
  /// and at most 220 characters (below the usual file name limits).
  @protected
  String normalizeObjectID(Object? o) {
    var id = o?.toString() ?? '';
    if (id.isEmpty) {
      throw StateError("Empty ID string.");
    }

    id = id
        .replaceAll(_regExpNormalizeIDInvalidChars, '')
        .replaceAll(_regExpNormalizeIDInvalidPrefix, '');
    id = id.truncate(220);
    return id;
  }

  static final _regExpNormalizeTableNonWord = RegExp(r'\W');

  /// Normalizes [table] into a safe directory/prefix name (non-word
  /// characters replaced by `_`).
  @protected
  String normalizeTableName(String table) {
    table = table.trim().replaceAll(_regExpNormalizeTableNonWord, '_');
    if (table.isEmpty) {
      throw StateError("Empty table name.");
    }
    return table;
  }

  /// Normalizes an entity JSON to be stored: the references to other
  /// entities (single, [EntityReference], lists and [EntityReferenceList])
  /// become their IDs, and a bytes field becomes a [DataURLBase64] string
  /// (if [encodeBytesAsDataURL]).
  @protected
  Map<String, dynamic> normalizeEntityJSON(
    Map<String, dynamic> entityJson, {
    String? entityName,
    String? table,
    EntityRepository? entityRepository,
  }) {
    entityRepository ??= getEntityRepository(
      name: entityName,
      tableName: table,
    );

    if (entityRepository == null) {
      throw StateError(
        "Can't determine `EntityRepository` for: entityName=$entityName ; tableName=$table",
      );
    }

    var entityHandler = entityRepository.entityHandler;

    var encodeBytesAsDataURL = this.encodeBytesAsDataURL;

    var entityJsonNormalized = entityJson.map((key, value) {
      if (value == null || (value as Object).isPrimitiveValue) {
        return MapEntry(key, value);
      } else if (encodeBytesAsDataURL && value is Uint8List) {
        var dataURLBase64 = DataURLBase64.from(value);
        return MapEntry(key, dataURLBase64.toString());
      }

      var fieldType = entityHandler.getFieldType(
        null,
        key,
        resolveFiledName: false,
      );

      if (fieldType != null) {
        if (fieldType.isEntityReferenceType) {
          var entityType = fieldType.arguments0!.type;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType",
            );
          }

          if (value is EntityReference) {
            if (value.isNull) {
              value = null;
            } else if (value.isIdSet) {
              value = value.id;
            } else if (value.isEntitySet) {
              value = fieldEntityRepository.getEntityID(value.entity);
            } else {
              throw StateError("Invalid state: $value");
            }
          } else if (!value.isPrimitiveValue) {
            value = fieldEntityRepository.getEntityID(value);
          }
        } else if (fieldType.isEntityReferenceListType) {
          var listEntityType = fieldType.arguments0!;

          var fieldListEntityRepository = getEntityRepositoryByTypeInfo(
            listEntityType,
          );
          if (fieldListEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType",
            );
          }

          if (value is EntityReferenceList) {
            // Its IDs (from its entities, if only those are set):
            value = value.isNull ? null : value.ids;
          } else {
            var valIter = value is Iterable ? value : [value];

            value = valIter
                .map(
                  (v) => fieldListEntityRepository.isOfEntityType(v)
                      ? fieldListEntityRepository.getEntityID(v)
                      : v,
                )
                .toList();
          }
        } else if (fieldType.isListEntity) {
          var listEntityType = fieldType.listEntityType!;

          var fieldListEntityRepository = getEntityRepositoryByTypeInfo(
            listEntityType,
          );
          if (fieldListEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key` List type: fieldType=$fieldType",
            );
          }

          var valIter = value is Iterable ? value : [value];

          value = valIter
              .map(
                (v) => fieldListEntityRepository.isOfEntityType(v)
                    ? fieldListEntityRepository.getEntityID(v)
                    : v,
              )
              .toList();
        } else if (!fieldType.isPrimitiveType && fieldType.entityType != null) {
          var entityType = fieldType.entityType!;
          var fieldEntityRepository = getEntityRepositoryByType(entityType);

          if (fieldEntityRepository == null) {
            throw StateError(
              "Can't determine `EntityRepository` for field `$key`: fieldType=$fieldType",
            );
          }

          value = fieldEntityRepository.getEntityID(value);
        }
      }

      return MapEntry(key, value);
    });

    return entityJsonNormalized;
  }

  /// The open transactions' contexts, with their opening time.
  ///
  /// Registered by [openTransaction], and removed when the transaction is
  /// canceled ([cancelTransaction]) or closed ([closeTransaction]). An
  /// adapter can delay the consolidation of a closed transaction while
  /// others are still open (see [onTransactionContextClosed]).
  final Map<C, DateTime> _openTransactionsContexts = <C, DateTime>{};

  @override
  FutureOr<C> openTransaction(Transaction transaction) =>
      createConnection().resolveMapped((conn) {
        _openTransactionsContexts[conn] = DateTime.now();

        transaction.transactionFuture
        // ignore: discarded_futures
        .then(
          // ignore: discarded_futures
          (res) => resolveTransactionResult(res, transaction, conn),
          onError: (e, s) {
            cancelTransaction(transaction, conn, e, s);
            throw e;
          },
        );

        return conn;
      });

  @override
  bool get cancelTransactionResultWithError => true;

  @override
  bool get throwTransactionResultWithError => false;

  @override
  bool cancelTransaction(
    Transaction transaction,
    C? connection,
    Object? error,
    StackTrace? stackTrace,
  ) {
    _openTransactionsContexts.remove(connection);
    if (connection != null) {
      onTransactionContextCanceled(connection);
    }
    return true;
  }

  /// Called when the transaction of [context] is canceled (after removing it
  /// from the open ones). Default: does nothing (the object adapters write
  /// immediately). [DBObjectMemoryAdapter] rolls back its tables.
  @protected
  void onTransactionContextCanceled(C context) {}

  @override
  bool get callCloseTransactionRequired => true;

  @override
  FutureOr<void> closeTransaction(Transaction transaction, C? connection) {
    if (connection != null) {
      _consolidateTransactionContext(connection);
    }
  }

  /// Removes the closed transaction [context] from the open ones, and
  /// notifies [onTransactionContextClosed]. Used by [closeTransaction].
  void _consolidateTransactionContext(C context) {
    _openTransactionsContexts.remove(context);

    onTransactionContextClosed(
      context,
      otherTransactionsOpen: _openTransactionsContexts.isNotEmpty,
    );
  }

  /// Called when the transaction of [context] is closed (after removing it
  /// from the open ones). [otherTransactionsOpen] tells if other
  /// transactions are still open. Default: does nothing.
  /// [DBObjectMemoryAdapter] consolidates its tables (once all the
  /// transactions are closed).
  @protected
  void onTransactionContextClosed(
    C context, {
    required bool otherTransactionsOpen,
  }) {}

  /// Resolves an operation [error] into this adapter's exception (see
  /// [createAdapterException]).
  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) => createAdapterException(
    'error',
    '$error',
    parentError: error,
    parentStackTrace: stackTrace,
    previousError: previousError,
    operation: operation,
  );

  /// Finishes [op] with [res] (see [finishOperation]), resolving the errors
  /// with [resolveError]. Used by [executeOperation].
  FutureOr<R> _finishOperation<T, R>(
    TransactionOperation op,
    T res,
    PreFinishDBOperation<T, R>? preFinish,
  ) => finishOperation<T, R>(op, res, preFinish, errorResolver: resolveError);

  /// Executes [f] in the transaction of [op], and finishes [op] (with
  /// [preFinish]) after that execution, not inside it: a [preFinish] can
  /// issue other operations in the same transaction (e.g. selecting the
  /// sub-entities), executed after this one (inside it, they would wait for
  /// it, that waits for them).
  @protected
  FutureOr<R> executeOperation<T, R>(
    TransactionOperation op,
    FutureOr<T> Function(C connection) f,
    PreFinishDBOperation<T, R>? preFinish,
  ) => executeTransactionOperation<T>(
    op,
    f,
  ).resolveMapped((res) => _finishOperation<T, R>(op, res, preFinish));

  /// Executes [f] with a connection of the transaction of [op]: from the
  /// pool if it's a single operation transaction, otherwise as an execution
  /// of the transaction (opening it if needed).
  FutureOr<R> executeTransactionOperation<R>(
    TransactionOperation op,
    FutureOr<R> Function(C connection) f,
  ) {
    var transaction = op.transaction;

    if (isTransactionWithSingleOperation(op)) {
      return executeWithPool(
        f,
        onError: (e, s) => transaction.notifyExecutionError(
          e,
          s,
          errorResolver: resolveError,
          operation: op,
          debugInfo: () => op.toString(),
        ),
      );
    }

    if (transaction.isOpen) {
      return transaction.addExecution<R, C>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => op.toString(),
      );
    }

    if (!transaction.isOpening) {
      transaction.open(
        () => openTransaction(transaction),
        callCloseTransactionRequired
            ? () => closeTransaction(transaction, transaction.context as C?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, C>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => op.toString(),
      );
    });
  }
}

/// Error thrown by [DBObjectAdapter] operations.
class DBObjectAdapterException extends DBAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBObjectAdapterException';

  DBObjectAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}
