import 'dart:io';

import 'package:bones_api/bones_api.dart';

import 'src/bench_runner.dart';

/// Benchmarks for the DB entity path, against `DBSQLMemoryAdapter`.
///
/// ```
/// dart run benchmark/db_benchmark.dart
/// ```
///
/// The memory adapter keeps I/O out of the picture, so most of what is left is
/// framework: condition parsing, SQL generation, and mapping rows to and from
/// entities.
///
/// One exception, and it is easy to misread: the memory adapter answers a
/// non-ID condition by *scanning* the table and evaluating the condition per
/// row, which a real SQL adapter does not do. `selectByQuery` is therefore
/// linear in the row count — see `--rows=N` below and `README.md`.
Future<void> main(List<String> args) async {
  var provider = _BenchProvider();
  await provider.ensureInitialized();

  var adapter = await provider.adapter;
  var repository = provider.userRepository;

  // `DBSQLMemoryAdapter` answers a non-ID condition with a full scan of the
  // table `Map`, so the row count is a parameter of the result, not a detail.
  // Vary it with `--rows=N` to separate per-row cost from fixed cost.
  var rows =
      int.tryParse(
        args
            .firstWhere((a) => a.startsWith('--rows='), orElse: () => '')
            .split('=')
            .last,
      ) ??
      50;

  for (var i = 1; i <= rows; ++i) {
    await repository.store(
      BenchUser('user$i', 'user$i@example.com', i, id: null),
    );
  }

  print('-- table rows: $rows');

  var runner = BenchRunner();

  // -----------------------------------------------------------------------
  // Entity <-> Map, the row mapping every adapter performs.
  // -----------------------------------------------------------------------

  var entity = BenchUser('joe', 'joe@example.com', 42, id: 1);
  var row = <String, dynamic>{
    'id': 1,
    'name': 'joe',
    'email': 'joe@example.com',
    'level': 42,
  };

  runner.run('Entity.toJson', () => entity.toJson());

  await runner.runAsync(
    'EntityHandler.createFromMap',
    () => benchUserEntityHandler.createFromMap(row),
  );

  // -----------------------------------------------------------------------
  // Query parsing (cached by `ConditionParseCache`) and SQL generation.
  // -----------------------------------------------------------------------

  // A `ConditionParser` builds its PetitParser grammar lazily on first use,
  // which costs ~125us. `bones_api` holds it in a `static final`, so that is a
  // one-off; re-creating one per query would not be.
  var parser = ConditionParser();
  parser.parse(' email == ? '); // build the grammar outside the measurement.

  runner.run(
    'ConditionParser.parse (shared parser)',
    () => parser.parse(' email == ? '),
  );

  var parseCache = ConditionParseCache<BenchUser>();

  runner.run(
    'ConditionParseCache.parseQuery (cached)',
    () => parseCache.parseQuery(' email == ? '),
  );

  var transaction = Transaction.autoCommit();
  var condition = parseCache.parseQuery(' email == ? ');

  await runner.runAsync(
    'generateSelectSQL: email == ?',
    () => adapter.generateSelectSQL(
      transaction,
      'BenchUser',
      'bench_user',
      condition,
      parameters: {'email': 'user7@example.com'},
    ),
  );

  // -----------------------------------------------------------------------
  // Repository operations, end to end through the adapter.
  //
  // `selectByID` is a keyed lookup and so is flat in the row count.
  // `selectByQuery` is not: it is roughly a fixed cost plus a per-row scan,
  // and only the fixed part is shared with a real SQL adapter.
  // -----------------------------------------------------------------------

  await runner.runAsync(
    'Transaction.executeBlock (empty)',
    () => Transaction.executeBlock((t) => 1),
  );

  await runner.runAsync(
    'repository.selectByID',
    () => repository.selectByID(7),
  );

  await runner.runAsync(
    'repository.selectByQuery: email == ?',
    () => repository.selectByQuery(
      ' email == ? ',
      parameters: {'email': 'user7@example.com'},
    ),
  );

  await runner.runAsync(
    'repository.selectAll (all rows)',
    () => repository.select(ConditionANY()),
  );

  runner.report(baseline: _baseline);

  if (args.contains('--emit-baseline')) {
    print('const _baseline = <String, double>{');
    runner.asBaseline().forEach((k, v) {
      print("  '$k': ${v.toStringAsFixed(0)},");
    });
    print('};');
  }

  provider.close();
  exit(0);
}

/// See the note on `_baseline` in `bones_api_benchmark.dart`.
const _baseline = <String, double>{};

final benchUserEntityHandler = GenericEntityHandler<BenchUser>(
  instantiatorDefault: BenchUser.empty,
  instantiatorFromMap: BenchUser.fromMap,
  type: BenchUser,
  typeName: 'BenchUser',
);

class BenchUser extends Entity {
  int? id;
  String name;
  String email;
  int level;

  BenchUser(this.name, this.email, this.level, {this.id});

  BenchUser.empty() : this('', '', 0);

  static BenchUser fromMap(Map<String, dynamic> map) => BenchUser(
    map.getAsString('name') ?? '',
    map.getAsString('email') ?? '',
    map.getAsInt('level') ?? 0,
    id: map['id'] as int?,
  );

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const <String>[
    'id',
    'name',
    'email',
    'level',
  ];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    'email' => email as V?,
    'level' => level as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' => TypeInfo.tString,
    'email' => TypeInfo.tString,
    'level' => TypeInfo.tInt,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'name':
        name = (value as String?) ?? '';
      case 'email':
        email = (value as String?) ?? '';
      case 'level':
        level = (value as int?) ?? 0;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'level': level,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BenchUser && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

class _BenchProvider extends DBSQLEntityRepositoryProvider {
  late final DBSQLEntityRepository<BenchUser> userRepository;

  @override
  Map<String, dynamic> get adapterConfig => {'sql.memory': {}};

  @override
  FutureOr<DBSQLAdapter> buildAdapter() =>
      DBSQLMemoryAdapter(parentRepositoryProvider: this);

  @override
  List<DBSQLEntityRepository> buildRepositories(DBSQLAdapter adapter) => [
    userRepository = DBSQLEntityRepository<BenchUser>(
      adapter,
      'bench_user',
      benchUserEntityHandler,
    ),
  ];
}
