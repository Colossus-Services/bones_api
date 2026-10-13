@TestOn('vm')
@Timeout(Duration(seconds: 30))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

class SqlItem extends Entity {
  int? id;
  String name;

  SqlItem(this.name, {this.id});

  SqlItem.empty() : this('');

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const ['id', 'name'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' => TypeInfo.tString,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'name':
        name = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'name': name};
}

final sqlItemHandler = GenericEntityHandler<SqlItem>(
  instantiatorDefault: SqlItem.empty,
  instantiatorFromMap: (m) => SqlItem(m['name'] as String, id: m['id'] as int?),
);

class SqlTestProvider
    extends DBSQLEntityRepositoryProvider<DBSQLMemoryAdapter> {
  @override
  Map<String, dynamic> get adapterConfig => {
    'sql.memory': {'generateTables': true},
  };

  @override
  List<DBSQLEntityRepository> buildRepositories(DBSQLAdapter adapter) => [
    DBSQLEntityRepository<SqlItem>(adapter, 'sql_item', sqlItemHandler),
  ];
}

void main() {
  setUpAll(() {
    DBSQLMemoryAdapter.boot();
    expect(sqlItemHandler.type, equals(SqlItem));
  });

  test('DBSQLEntityRepositoryProvider (memory)', () async {
    var provider = SqlTestProvider();
    addTearDown(provider.close);

    await provider.ensureInitialized();

    var adapter = await provider.adapter;
    expect(adapter, isA<DBSQLMemoryAdapter>());

    var repository =
        provider.getEntityRepository<SqlItem>()
            as DBSQLEntityRepository<SqlItem>;

    expect(repository.dialect, same(adapter.dialect));
    expect(repository.dialectName, equals(adapter.dialectName));

    var info = repository.information();
    expect(info['queryType'], equals('SQL'));
    expect(info['table'], equals('sql_item'));
    expect(info.containsKey('adapter'), isFalse);

    var infoExtended = repository.information(extended: true);
    expect(infoExtended['adapter'], isA<Map>());

    expect(repository.toString(), contains('sql_item'));

    var sqls = await provider.generateCreateTableSQLs();
    expect(sqls, isNotEmpty);
    expect(sqls.map((e) => e.buildSQL()).join('\n'), contains('sql_item'));

    var fullSQL = await provider.generateFullCreateTableSQLs(
      title: 'Cov Title',
      withDate: false,
    );
    expect(fullSQL, contains('Cov Title'));
    expect(fullSQL, contains('CREATE TABLE'));
    expect(fullSQL, contains('sql_item'));

    var id = await repository.store(SqlItem('a'));
    expect(id, isNotNull);
    var sel = await repository.selectByID(id);
    expect(sel!.name, equals('a'));

    var id2 = await repository.store(SqlItem('b'));

    var del1 = await repository.tryDeleteEntity(sel);
    expect(del1!.name, equals('a'));

    var del2 = await repository.tryDeleteByID(id2);
    expect(del2!.name, equals('b'));

    expect(await repository.tryDeleteByID(id2), isNull);
    expect(await repository.count(), equals(0));
  });
}
