import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';
import 'bones_api_mixin.dart';
import 'bones_api_types.dart';

/// A column information of a [SQLEntry].
class SQLColumn implements Comparable<SQLColumn> {
  /// The column table.
  final String table;

  /// The column name.
  final String name;

  /// The referenced table if this column is a `FOREIGN KEY`.
  final String? referenceTable;

  /// The referenced table column if this column is a `FOREIGN KEY`.
  final String? referenceColumn;

  SQLColumn(this.table, this.name, {this.referenceTable, this.referenceColumn});

  @override
  int compareTo(SQLColumn other) {
    var cmp = table.compareTo(other.table);
    if (cmp == 0) {
      cmp = name.compareTo(other.name);
    }
    return cmp;
  }
}

/// A generic entry in a [SQLBuilder].
class SQLEntry {
  /// The type of entry.
  final String type;

  /// The SQL.
  final String sql;

  /// The entry comment.
  final String? comment;

  /// The tables of this entry.
  final List<String>? tables;

  /// The referenced tables of this entry.
  final List<String>? referenceTables;

  /// The columns or referenced columns in this entry.
  final List<SQLColumn>? columns;

  SQLEntry(this.type, this.sql,
      {String? comment,
      List<String>? tables,
      List<String>? referenceTables,
      this.columns})
      : comment = comment != null && comment.isNotEmpty ? comment : null,
        tables = tables ??
            columns?.map((e) => e.table).whereNotNull().toSet().toList(),
        referenceTables = referenceTables ??
            columns
                ?.map((e) => e.referenceTable)
                .whereNotNull()
                .toSet()
                .toList();

  @override
  String toString() => comment == null ? sql : '$sql  -- $comment';
}

/// Base class for SQL builders
abstract class SQLBuilder implements Comparable<SQLBuilder> {
  /// The SQL dialect.
  final String dialect;

  /// The quote of the dialect.
  final String q;

  SQLBuilder(this.dialect, this.q);

  /// Returns a list of referenced tables.
  List<String>? get referenceTables;

  /// Returns a number of referenced tables.
  int get referenceTablesLength => referenceTables?.length ?? 0;

  /// Some extra SQL related to this `SQL`.
  List<SQLBuilder>? get extraSQLBuilders;

  /// All the `SQL`s of this builder tree.
  List<SQLBuilder> get allSQLBuilders =>
      <SQLBuilder>[this, ...?extraSQLBuilders?.expand((e) => e.allSQLBuilders)];

  /// Build the `SQL`.
  String buildSQL({bool multiline = true, bool ifNotExists = true});

  /// Build all the `SQL`s, including the [extraSQLBuilders].
  List<String> buildAllSQLs({bool multiline = true, bool ifNotExists = true}) {
    var allSQLBuilders = this.allSQLBuilders;
    var sqls = allSQLBuilders
        .map((e) => e.buildSQL(multiline: multiline, ifNotExists: ifNotExists))
        .toList();
    return sqls;
  }
}

/// A base class for `CREATE` and `ALTER` table SQLs.
abstract class TableSQL extends SQLBuilder {
  /// The table name.
  final String table;

  /// The fields and constraint entries.
  final List<SQLEntry> entries;

  /// The parent table;
  final String? parentTable;

  TableSQL(String dialect, this.table, this.entries,
      {String q = '"', this.parentTable})
      : super(dialect, q);

  @override
  List<String> get referenceTables;
}

/// A `CREATE TABLE` SQL builder.
class CreateTableSQL extends TableSQL {
  /// The related `ALTER TABLE` SQLs.
  List<AlterTableSQL>? alterTables;

  /// The related `CREATE TABLE` SQLs for relationships.
  List<CreateTableSQL>? relationships;

  /// The associated [EntityRepository] of this table.
  EntityRepository? entityRepository;

  CreateTableSQL(String dialect, String table, List<SQLEntry> entries,
      {String q = '"',
      this.alterTables,
      this.relationships,
      String? parentTable,
      this.entityRepository})
      : super(dialect, table, entries, q: q, parentTable: parentTable);

  List<String>? _referenceTables;

  @override
  List<String> get referenceTables => _referenceTables ??= <String>{
        ...entries.expand((e) => e.referenceTables ?? <String>[]),
      }.toList();

  List<String>? _relationshipsTables;

  /// Returns the tables of the [relationships].
  List<String> get relationshipsTables => _relationshipsTables ??= <String>{
        ...?relationships
            ?.expand((e) => e.referenceTables.where((t) => t != table)),
      }.toList();

  List<String>? _referenceAndRelationshipTables;

  /// Returns the tables in [referenceTables] and [relationshipsTables].
  List<String> get referenceAndRelationshipTables =>
      _referenceAndRelationshipTables ??=
          <String>{...referenceTables, ...relationshipsTables}.toList();

  @override
  List<SQLBuilder> get extraSQLBuilders =>
      <SQLBuilder>[...?relationships, ...?alterTables];

  /// Returns the `CONSTRAINT` [entries].
  List<SQLEntry> get constraints =>
      entries.where((e) => e.type == 'CONSTRAINT').toList();

  void _disposeCache() {
    _referenceTables = null;
    _relationshipsTables = null;
    _referenceAndRelationshipTables = null;
  }

  /// Converts the [constraints] to [AlterTableSQL].
  /// This helps to execute the dependente constraints.
  List<AlterTableSQL> constraintsAsAlterTable(
      {bool recursive = true, bool onlyDependents = true}) {
    var constraints = this.constraints;

    if (onlyDependents) {
      constraints = constraints
          .where((c) => c.referenceTables?.any((t) => t != table) ?? false)
          .toList();
    }

    var alterTablesConstraint = <AlterTableSQL>[];

    for (var c in constraints) {
      var e = SQLEntry('ADD', 'ADD ${c.sql}',
          comment: c.comment,
          tables: c.tables,
          columns: c.columns,
          referenceTables: c.referenceTables);
      var alterTable =
          AlterTableSQL(dialect, table, [e], q: q, parentTable: table);
      alterTablesConstraint.add(alterTable);
    }

    entries.removeAll(constraints);

    _disposeCache();

    var alterTables = this.alterTables ??= <AlterTableSQL>[];
    alterTables.addAll(alterTablesConstraint);

    if (recursive) {
      var extraSQLs = allSQLBuilders
          .whereType<CreateTableSQL>()
          .where((e) => !identical(e, this));
      for (var e in extraSQLs) {
        e.constraintsAsAlterTable(recursive: false);
      }
    }

    return alterTablesConstraint;
  }

  @override
  String buildSQL({bool multiline = true, bool ifNotExists = true}) {
    var ln = multiline ? '\n' : '';

    final sql = StringBuffer();

    sql.write('CREATE TABLE ');
    if (ifNotExists) {
      sql.write('IF NOT EXISTS ');
    }
    sql.write('$q$table$q ($ln');

    var maxLine = entries
            .where((e) => e.type != 'CONSTRAINT')
            .map((e) => e.sql.length)
            .max +
        3;

    var i = 0;
    for (var e in entries) {
      var line = e.sql;
      var comment = e.comment;

      var lineLength = line.length;
      var lastEntry = i == entries.length - 1;

      sql.write(line);
      if (!lastEntry) {
        sql.write(',');
        lineLength++;
      }

      if (multiline && comment != null) {
        var pad = maxLine - lineLength;
        var space = '  '.padRight(pad, ' ');
        sql.write('$space-- $comment');
      }

      if (!lastEntry) {
        sql.write(ln);
      }

      i++;
    }

    sql.write(' $ln) ;');

    return sql.toString();
  }

  @override
  int compareTo(SQLBuilder other) {
    if (other is CreateTableSQL) {
      var ref1 = referenceTablesLength + relationshipsTables.length;
      var ref2 = other.referenceTablesLength + other.relationshipsTables.length;

      var cmp = ref1.compareTo(ref2);
      if (cmp != 0) return cmp;

      return table.compareTo(other.table);
    } else if (other is AlterTableSQL) {
      return -1;
    } else {
      return 0;
    }
  }

  @override
  String toString() {
    var refs = referenceTables;
    var rels = relationshipsTables;

    var parentStr = parentTable != null ? 'parent: $parentTable' : null;
    var refsStr = refs.isNotEmpty ? 'refs: $refs' : null;
    var relsStr = rels.isNotEmpty ? 'rels: $rels' : null;

    return 'CREATE TABLE $table {${[
      if (parentStr != null) parentStr,
      if (refsStr != null) refsStr,
      if (relsStr != null) relsStr,
    ].join(', ')}}';
  }
}

/// A `ALTER TABLE` SQL builder.
class AlterTableSQL extends TableSQL {
  @override
  List<CreateTableSQL>? extraSQLBuilders;

  AlterTableSQL(String dialect, String table, List<SQLEntry> entries,
      {String q = '"', this.extraSQLBuilders, String? parentTable})
      : super(dialect, table, entries, q: q, parentTable: parentTable);

  List<String>? _referenceTables;

  @override
  List<String> get referenceTables => _referenceTables ??= <String>{
        ...entries.expand((e) => e.referenceTables ?? <String>[]).whereNotNull()
      }.toList();

  @override
  String buildSQL({bool multiline = true, bool ifNotExists = true}) {
    var ln = multiline ? '\n' : '';

    final sql = StringBuffer();

    sql.write('ALTER TABLE ');
    sql.write('$q$table$q $ln');

    var maxLine = entries.map((e) => e.sql.length).max + 3;

    var i = 0;
    for (var e in entries) {
      var line = e.sql;
      var comment = e.comment;

      var lineLength = line.length;
      var lastEntry = i == entries.length - 1;

      sql.write(line);
      if (!lastEntry) {
        sql.write(',');
        lineLength++;
      }

      if (multiline && comment != null) {
        var pad = maxLine - lineLength;
        var space = '  '.padRight(pad, ' ');
        sql.write('$space-- $comment');
      }

      if (!lastEntry) {
        sql.write(ln);
      }

      i++;
    }

    sql.write(' $ln ;');

    return sql.toString();
  }

  @override
  int compareTo(SQLBuilder other) {
    if (other is CreateTableSQL) {
      return -other.compareTo(this);
    } else if (other is AlterTableSQL) {
      return table.compareTo(other.table);
    } else {
      return 0;
    }
  }

  @override
  String toString() {
    var refs = referenceTables;

    var parentStr = parentTable != null ? 'parent: $parentTable' : null;
    var refsStr = refs.isNotEmpty ? 'refs: $refs' : null;

    return 'ALTER TABLE $table {${[
      if (parentStr != null) parentStr,
      if (refsStr != null) refsStr,
    ].join(', ')}}';
  }
}

extension SQLBuilderListExtension on List<SQLBuilder> {
  bool _headContainsReferenceTable(List<String> refTables, int length) {
    for (var t in refTables) {
      var found = false;

      for (var i = 0; i < length; ++i) {
        var e = this[i];
        if (e is! CreateTableSQL) continue;

        if (e.table == t) {
          found = true;
          break;
        }
      }

      if (!found) return false;
    }

    return true;
  }

  int? _indexOfTable(String table, int offset) {
    var length = this.length;

    for (var i = offset; i < length; ++i) {
      var e = this[i];
      if (e is! CreateTableSQL) continue;

      if (e.table == table) {
        return i;
      }
    }

    return null;
  }

  int? _indexWithAllReferenceTables(List<String> refTables, int offset) {
    var length = this.length;

    var toFind = refTables.toSet().toList();

    for (var i = offset; i < length && toFind.isNotEmpty; ++i) {
      var e = this[i];
      if (e is! CreateTableSQL) continue;

      if (toFind.contains(e.table)) {
        toFind.remove(e.table);

        if (toFind.isEmpty) {
          var foundIdx = i;

          for (var j = i + 1; j < length; ++j) {
            var o = this[j];
            if (o is! TableSQL) break;

            if (o.parentTable == e.table) {
              foundIdx = j;
            } else {
              break;
            }
          }

          return foundIdx;
        }
      }
    }

    return null;
  }

  /// Sorts the SQLs by table name.
  void sorteByName() {
    sort((a, b) {
      if (a is TableSQL && b is TableSQL) {
        return a.table.compareTo(b.table);
      }
      return 0;
    });
  }

  /// Sorts the SQLs in the best execution order,
  /// to avoid reference issues.
  void bestOrder() {
    sorteByName();

    var withParents =
        whereType<TableSQL>().where((e) => e.parentTable != null).toList();
    removeAll(withParents);

    var withRelationship = whereType<CreateTableSQL>()
        .where((e) => e.relationshipsTables.isNotEmpty)
        .toList();
    removeAll(withRelationship);

    var withReference = whereType<TableSQL>()
        .where((e) => e.referenceTables.isNotEmpty)
        .toList();
    removeAll(withReference);

    withParents._bestOrderLoop();
    withReference._bestOrderLoop();
    withRelationship._bestOrderLoop();

    _bestOrderLoop();

    refsGetter(TableSQL e) => e is CreateTableSQL
        ? e.referenceAndRelationshipTables
        : e.referenceTables;

    _addByRefPos(withReference, addAtEnd: true);
    _addByRefPos(withRelationship, addAtEnd: true, refsGetter: refsGetter);

    while (withReference.isNotEmpty || withRelationship.isNotEmpty) {
      var addRefs = _addByRefPos(withReference);
      _sortByRefsSimple();

      var addRels = _addByRefPos(withRelationship, refsGetter: refsGetter);

      _sortByRels();
      _sortByRefs();
      _bestOrderLoop();

      if (addRefs == 0 && addRels == 0) {
        if (withReference.isNotEmpty) {
          addAll(withReference);
          withReference.clear();
          _bestOrderLoop();
        } else if (withRelationship.isNotEmpty) {
          addAll(withRelationship);
          withRelationship.clear();
          _bestOrderLoop();
        } else {
          break;
        }
      }
    }

    for (var e in withParents.reversed) {
      var idx = _indexOfTable(e.table, 0) ?? 0;
      insert(idx, e);
    }

    withParents.clear();

    _bestOrderLoop();
  }

  int _addByRefPos(List<TableSQL> list,
      {List<String> Function(TableSQL e)? refsGetter, bool addAtEnd = false}) {
    refsGetter ??= (e) => e.referenceTables;

    var count = 0;

    if (addAtEnd) {
      for (var i = 0; i < list.length; ++i) {
        var e = list[i];
        var refs = refsGetter(e);
        var idx = _indexWithAllReferenceTables(refs, 0);

        if (idx != null) {
          add(e);
          list.removeAt(i);
          count++;
        }
      }
    } else {
      for (var i = list.length - 1; i >= 0; --i) {
        var e = list[i];
        var refs = refsGetter(e);
        var idx = _indexWithAllReferenceTables(refs, 0);

        if (idx != null) {
          ++idx;
          insert(idx, e);
          list.removeAt(i);
          count++;
        }
      }
    }

    return count;
  }

  void _bestOrderLoop() {
    while (true) {
      if (!_bestOrderImpl()) {
        break;
      }
    }
  }

  bool _bestOrderImpl() {
    final length = this.length;

    var moved = false;

    for (var i = 0; i < length;) {
      var e = this[i];
      var refs = e.referenceTables;
      if (refs == null || refs.isEmpty) {
        ++i;
        continue;
      }

      if (!_headContainsReferenceTable(refs, i)) {
        var idx = _indexWithAllReferenceTables(refs, 0);

        if (idx != null && idx > i) {
          moved = true;
          insert(idx + 1, e);
          var prev = removeAt(i);
          assert(identical(prev, e));
          continue;
        }
      }

      ++i;
    }

    return moved;
  }

  void _sortByRefsSimple() {
    sort((a, b) {
      if (a is TableSQL && b is TableSQL) {
        var ref1 = a.referenceTables.length;
        var ref2 = b.referenceTables.length;

        var rel1 = a is CreateTableSQL ? a.relationshipsTables.length : 0;
        var rel2 = b is CreateTableSQL ? b.relationshipsTables.length : 0;

        var cmp =
            (ref1 + rel1).clamp(0, 1).compareTo((ref2 + rel2).clamp(0, 1));
        return cmp;
      }
      return 0;
    });
  }

  void _sortByRels() {
    sort((a, b) {
      if (a is TableSQL && b is TableSQL) {
        var rel1 = a is CreateTableSQL ? a.relationshipsTables.length : 0;
        var rel2 = b is CreateTableSQL ? b.relationshipsTables.length : 0;

        var cmp = rel1.clamp(0, 1).compareTo(rel2.clamp(0, 1));
        return cmp;
      }
      return 0;
    });
  }

  void _sortByRefs() {
    sort((a, b) {
      if (a is TableSQL && b is TableSQL) {
        var ref1 = a.referenceTables.length;
        var ref2 = b.referenceTables.length;

        var rel1 = a is CreateTableSQL ? a.relationshipsTables.length : 0;
        var rel2 = b is CreateTableSQL ? b.relationshipsTables.length : 0;

        if (ref1 == 0 && rel1 == 0) {
          return ref2 == 0 && rel2 == 0 ? 0 : -1;
        } else if (ref2 == 0 && rel2 == 0) {
          return ref1 == 0 && rel1 == 0 ? 0 : 1;
        }

        if (ref1 > 0 && rel1 > 0) {
          return ref2 > 0 && rel2 > 0 ? 0 : 1;
        } else if (ref2 > 0 && rel2 > 0) {
          return ref1 > 0 && rel1 > 0 ? 0 : 1;
        }

        return 0;
      }
      return 0;
    });
  }
}

/// Base class for a `SQL` generator.
abstract class SQLGenerator {
  /// The generated SQL dialect.
  String get dialect;

  /// The type of "quote" to use to reference elements (tables and columns).
  String get sqlElementQuote;

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName});

  FutureOr<String> getTableForEntityRepository(
      EntityRepository entityRepository);

  String? typeToSQLType(Type type, String column) {
    if (type == String) {
      return 'VARCHAR';
    } else if (type == bool) {
      return 'BOOLEAN';
    } else if (type == DateTime) {
      return 'TIMESTAMP';
    } else if (type == Time) {
      return 'TIME';
    } else if (type == double || type == Decimal) {
      return 'DECIMAL';
    } else if (type == int) {
      return 'INT';
    } else if (type == BigInt || type == DynamicInt) {
      return 'BIGINT';
    } else if (type == Uint8List) {
      return 'BLOB';
    }

    return null;
  }

  /// Returns the preferred `VARCHAR` size for a [column] name.
  int getVarcharPreferredSize(String? column) {
    if (column == null) return 1024;

    column = column.trim();
    if (column.isEmpty) return 1024;

    column = FieldsFromMap.defaultFieldToSimpleKey(column);
    if (column.isEmpty) return 1024;

    switch (column) {
      case 'zip':
      case 'zipcode':
      case 'postalcode':
        return 32;

      case 'name':
      case 'firstname':
      case 'middlename':
      case 'lastname':
      case 'city':
        return 128;

      case 'address':
      case 'email':
        return 254;

      case 'http':
      case 'https':
      case 'url':
        return 2048;

      case 'text':
      case 'html':
      case 'xml':
      case 'json':
      case 'yaml':
      case 'yml':
      case 'data':
      case 'content':
      case 'base64':
        return 65535;

      default:
        return 1024;
    }
  }

  String? primaryKeyTypeToSQLType(Type type) {
    return 'SERIAL PRIMARY KEY';
  }

  /// Returns: table -> idName: sqlType
  FutureOr<MapEntry<String, MapEntry<String, String>>?> entityTypeToSQLType(
      Type type, String? column) {
    var typeEntityRepository = getEntityRepository(type: type);

    if (typeEntityRepository != null) {
      var entityHandler = typeEntityRepository.entityHandler;

      var idName = entityHandler.idFieldName();
      var idType = entityHandler.idType();

      var sqlType = foreignKeyTypeToSQLType(idType, idName);

      if (sqlType != null) {
        return getTableForEntityRepository(typeEntityRepository)
            .resolveMapped((table) {
          return MapEntry(table, MapEntry(idName, sqlType));
        });
      }
    }

    return null;
  }

  String? foreignKeyTypeToSQLType(Type idType, String idName) {
    if (idType == int) {
      idType = BigInt;
    }

    var sqlType = typeToSQLType(idType, idName);
    return sqlType;
  }

  /// Returns: ENUM: valuesNames
  FutureOr<MapEntry<String, List<String>>?> enumTypeToSQLType(
      Type type, String column) {
    var reflectionFactory = ReflectionFactory();
    var enumReflection = reflectionFactory.getRegisterEnumReflection(type);

    if (enumReflection != null) {
      var valuesNames = enumReflection.valuesByName.keys.toList()..sort();
      return MapEntry('ENUM', valuesNames);
    }

    return null;
  }

  FutureOr<List<SQLBuilder>> generateCreateTableSQLs(
      {bool ifNotExists = true, bool sortColumns = true});

  FutureOr<CreateTableSQL> generateCreateTableSQL(
      {EntityRepository? entityRepository,
      Object? obj,
      Type? type,
      String? name,
      String? tableName,
      bool ifNotExists = true,
      bool sortColumns = true}) async {
    entityRepository ??=
        getEntityRepository(type: type, obj: obj, name: name, tableName: name);
    if (entityRepository == null) {
      throw ArgumentError(
          "Can't resolve `EntityRepository`> obj: $obj ; type: $type ; name: $name ; tableName: $tableName");
    }

    var q = sqlElementQuote;

    var entityType = entityRepository.type;
    var table = await getTableForEntityRepository(entityRepository);
    var entityHandler = entityRepository.entityHandler;

    var idFieldName = entityHandler.idFieldName().toLowerCase();
    var idType = entityHandler.idType();
    var idTypeSQL = primaryKeyTypeToSQLType(idType);

    var sqlEntries = <SQLEntry>[
      SQLEntry('COLUMN', ' $q$idFieldName$q $idTypeSQL',
          comment: '$idType $idFieldName',
          columns: [SQLColumn(table, idFieldName)]),
    ];

    var fieldsEntries = entityHandler
        .fieldsTypes()
        .entries
        .where((e) => !e.value.isListEntity)
        .toList();

    if (sortColumns) {
      fieldsEntries.sort((a, b) => a.key.compareTo(b.key));
    }

    var referenceFields =
        <String, MapEntry<String, MapEntry<String, String>>>{};

    for (var e in fieldsEntries) {
      var fieldName = e.key.toLowerCase();
      var fieldType = e.value;
      if (fieldName == idFieldName) continue;

      var comment = '${e.value} ${e.key}';
      String? refTable;
      String? refColumn;

      var fieldSQLType = typeToSQLType(fieldType.type, fieldName);
      if (fieldSQLType == null) {
        var entityType = await entityTypeToSQLType(fieldType.type, fieldName);
        if (entityType != null) {
          referenceFields[fieldName] = entityType;
          fieldSQLType = entityType.value.value;

          refTable = entityType.key;
          refColumn = entityType.value.key;

          comment += ' @ $refTable.$refColumn';
        }
      }

      if (fieldSQLType == null) {
        var enumType = await enumTypeToSQLType(fieldType.type, fieldName);
        if (enumType != null) {
          var type = enumType.key;
          var values = enumType.value;

          if (type == 'ENUM') {
            fieldSQLType = type;
            fieldSQLType += '(${values.map((e) => "'$e'").join(',')})';
          } else if (type.endsWith(' CHECK')) {
            fieldSQLType = type;
            fieldSQLType +=
                '( $q$fieldName$q IN (${values.map((e) => "'$e'").join(',')}) )';
          } else {
            fieldSQLType = type;
          }

          comment += ' enum(${values.join(', ')})';
        }
      }

      if (fieldSQLType == null) continue;

      sqlEntries.add(SQLEntry('COLUMN', ' $q$fieldName$q $fieldSQLType',
          comment: comment,
          columns: [
            SQLColumn(table, fieldName,
                referenceTable: refTable, referenceColumn: refColumn)
          ]));
    }

    for (var e in referenceFields.entries) {
      var fieldName = e.key.toLowerCase();
      var ref = e.value;

      var refTableName = ref.key;
      var refField = ref.value.key.toLowerCase();

      var constrainName = '${table}__${fieldName}__fkey';

      sqlEntries.add(SQLEntry('CONSTRAINT',
          ' CONSTRAINT $q$constrainName$q FOREIGN KEY ($q$fieldName$q) REFERENCES $refTableName($q$refField$q) ON UPDATE CASCADE',
          comment: '${e.key} @ $refTableName.$refField',
          columns: [
            SQLColumn(table, fieldName,
                referenceTable: refTableName, referenceColumn: refField)
          ]));
    }

    var createSQL = CreateTableSQL(dialect, table, sqlEntries,
        q: q, entityRepository: entityRepository);

    var relationshipSQLs = <CreateTableSQL>[];

    var relationshipEntries = entityHandler
        .fieldsTypes()
        .entries
        .where((e) => e.value.isListEntity)
        .toList();

    for (var e in relationshipEntries) {
      var fieldName = e.key;
      var fieldType = e.value.listEntityType!;

      var srcFieldName = table.toLowerCase();
      var relSrcType = foreignKeyTypeToSQLType(idType, srcFieldName);

      var relDstType = await entityTypeToSQLType(fieldType.type, null);
      if (relDstType == null) continue;

      var relDstTable = relDstType.key;
      var relDstTableId = relDstType.value.key;
      var relDstTypeSQL = relDstType.value.value;

      var dstFieldName = relDstTable.toLowerCase();

      var relName = '${table}__${fieldName}__rel';

      var constrainUniqueName = '${relName}__unique';
      var constrainSrcName = '${relName}__${srcFieldName}__fkey';
      var constrainDstName = '${relName}__${dstFieldName}__fkey';

      var sqlRelEntries = <SQLEntry>[
        SQLEntry('COLUMN', ' $q$srcFieldName$q $relSrcType NOT NULL',
            comment: '$entityType.${e.key}',
            columns: [
              SQLColumn(relName, srcFieldName,
                  referenceTable: table, referenceColumn: idFieldName)
            ]),
        SQLEntry('COLUMN', ' $q$dstFieldName$q $relDstTypeSQL NOT NULL',
            comment: '${e.value} @ $relDstTable.$relDstTableId',
            columns: [
              SQLColumn(relName, dstFieldName,
                  referenceTable: relDstTable, referenceColumn: relDstTableId)
            ]),
        SQLEntry('CONSTRAINT',
            ' CONSTRAINT $q$constrainUniqueName$q UNIQUE ($q$srcFieldName$q, $q$dstFieldName$q)',
            columns: [
              SQLColumn(relName, srcFieldName),
              SQLColumn(relName, dstFieldName)
            ]),
        SQLEntry('CONSTRAINT',
            ' CONSTRAINT $q$constrainSrcName$q FOREIGN KEY ($q$srcFieldName$q) REFERENCES $q$table$q($q$idFieldName$q) ON UPDATE CASCADE ON DELETE CASCADE',
            comment: ' $srcFieldName @ $table.$idFieldName',
            columns: [
              SQLColumn(relName, srcFieldName,
                  referenceTable: table, referenceColumn: idFieldName)
            ]),
        SQLEntry('CONSTRAINT',
            ' CONSTRAINT $q$constrainDstName$q FOREIGN KEY ($q$dstFieldName$q) REFERENCES $q$relDstTable$q($q$relDstTableId$q) ON UPDATE CASCADE ON DELETE CASCADE',
            comment: ' $dstFieldName @ $relDstTable.$relDstTableId',
            columns: [
              SQLColumn(relName, dstFieldName,
                  referenceTable: relDstTable, referenceColumn: relDstTableId)
            ])
      ];

      var relSQL = CreateTableSQL(dialect, relName, sqlRelEntries,
          q: q, parentTable: table);
      relationshipSQLs.add(relSQL);
    }

    createSQL.relationships = relationshipSQLs;

    return createSQL;
  }

  /// Generate a full text with all the SQLs to create the tables.
  Future<String> generateFullCreateTableSQLs(
      {String? title,
      bool withDate = true,
      bool ifNotExists = true,
      bool sortColumns = true}) async {
    return generateCreateTableSQLs(
            ifNotExists: ifNotExists, sortColumns: sortColumns)
        .resolveMapped((allSQLs) {
      if (allSQLs.isEmpty) return '';

      var dialect = allSQLs.first.dialect;

      var fullSQL = StringBuffer();

      if (title != null && title.isNotEmpty) {
        var parts = title.split(RegExp(r'\r?\n'));
        for (var l in parts) {
          fullSQL.write('-- $l\n');
        }
      }

      fullSQL.write('-- SQLAdapter: $runtimeType\n');
      fullSQL.write('-- Dialect: $dialect\n');
      fullSQL.write('-- Generator: BonesAPI/${BonesAPI.VERSION}\n');
      if (withDate) fullSQL.write('-- Date: ${DateTime.now()}\n');
      fullSQL.write('\n');

      for (var s in allSQLs) {
        if (s is CreateTableSQL && s.entityRepository != null) {
          var sqlEntityRepository = s.entityRepository!;
          fullSQL.write(
              '-- Entity: ${sqlEntityRepository.type} @ ${sqlEntityRepository.name}\n\n');
        }

        var sql = s.buildSQL(multiline: s is! AlterTableSQL);
        fullSQL.write('$sql\n\n');
      }

      return fullSQL.toString();
    });
  }
}
