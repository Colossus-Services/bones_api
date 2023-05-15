import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_base.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_extension.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'package:logging/logging.dart' as logging;

final _log = logging.Logger('SQLBuilder');

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

class SQLDialect extends DBDialect {
  /// The type of "quote" to use to reference elements (tables and columns).
  final String elementQuote;

  /// If `true` indicates that this adapter's SQL uses the `OUTPUT` syntax for inserts/deletes.
  final bool acceptsOutputSyntax;

  /// If `true` indicates that this adapter's SQL uses the `RETURNING` syntax for inserts/deletes.
  final bool acceptsReturningSyntax;

  /// If `true` indicates that this adapter's SQL needs a temporary table to return rows for inserts/deletes.
  final bool acceptsTemporaryTableForReturning;

  /// If `true` indicates that this adapter's SQL can use the `DEFAULT VALUES` directive for inserts.
  final bool acceptsInsertDefaultValues;

  /// If `true` indicates that this adapter's SQL uses the `IGNORE` syntax for inserts.
  final bool acceptsInsertIgnore;

  /// If `true` indicates that this adapter's SQL uses the `ON CONFLICT` syntax for inserts.
  final bool acceptsInsertOnConflict;

  /// If `true` indicates that the `VARCHAR` can be defined without a maximum size.
  final bool acceptsVarcharWithoutMaximumSize;

  const SQLDialect(
    String name, {
    this.elementQuote = '',
    this.acceptsOutputSyntax = false,
    this.acceptsReturningSyntax = false,
    this.acceptsTemporaryTableForReturning = false,
    this.acceptsInsertDefaultValues = false,
    this.acceptsInsertIgnore = false,
    this.acceptsInsertOnConflict = false,
    this.acceptsVarcharWithoutMaximumSize = false,
  }) : super(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SQLDialect &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return 'SQLDialect{name: $name, elementQuote: $elementQuote, acceptsOutputSyntax: $acceptsOutputSyntax, acceptsReturningSyntax: $acceptsReturningSyntax, acceptsTemporaryTableForReturning: $acceptsTemporaryTableForReturning, acceptsInsertDefaultValues: $acceptsInsertDefaultValues, acceptsInsertIgnore: $acceptsInsertIgnore, acceptsInsertOnConflict: $acceptsInsertOnConflict}';
  }
}

/// Base class for SQL builders
abstract class SQLBuilder implements Comparable<SQLBuilder> {
  /// The SQL dialect.
  final SQLDialect dialect;

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

/// A `CREATE INDEX` SQL builder.
class CreateIndexSQL extends SQLBuilder {
  /// The table name.
  final String table;

  /// The column;
  final String column;

  /// The name of the index;
  final String? indexName;

  CreateIndexSQL(SQLDialect dialect, this.table, this.column, this.indexName,
      {String q = '"'})
      : super(dialect, q);

  @override
  String buildSQL({bool multiline = true, bool ifNotExists = true}) {
    final sql = StringBuffer();

    sql.write('CREATE INDEX ');

    if (ifNotExists) {
      sql.write('IF NOT EXISTS ');
    }

    sql.write('$q$indexName$q ON $q$table$q ($q$column$q)');

    return sql.toString();
  }

  @override
  int compareTo(SQLBuilder other) {
    if (other is CreateIndexSQL) {
      return 0;
    }
    if (other is CreateTableSQL) {
      if (other.table == table) {
        return 1;
      }

      var ref1 = referenceTablesLength;
      var ref2 = other.referenceTablesLength + other.relationshipsTables.length;

      var cmp = ref1.compareTo(ref2);
      if (cmp != 0) return cmp;

      return table.compareTo(other.table);
    } else {
      var referenceTables = other.referenceTables;
      return referenceTables != null && referenceTables.contains(table)
          ? -1
          : 0;
    }
  }

  @override
  List<SQLBuilder>? get extraSQLBuilders => null;

  @override
  List<String> get referenceTables => <String>[table];

  @override
  String toString() => buildSQL(multiline: false, ifNotExists: false);
}

/// A base class for `CREATE` and `ALTER` table SQLs.
abstract class TableSQL extends SQLBuilder {
  /// The table name.
  final String table;

  /// The fields and constraint entries.
  final List<SQLEntry> entries;

  /// The parent table;
  final String? parentTable;

  TableSQL(SQLDialect dialect, this.table, this.entries,
      {String q = '"', this.parentTable})
      : super(dialect, q);

  @override
  List<String> get referenceTables;
}

/// A `CREATE TABLE` SQL builder.
class CreateTableSQL extends TableSQL {
  /// The related `CREATE INDEX` SQLs.
  List<CreateIndexSQL>? indexes;

  /// The related `ALTER TABLE` SQLs.
  List<AlterTableSQL>? alterTables;

  /// The related `CREATE TABLE` SQLs for relationships.
  List<CreateTableSQL>? relationships;

  /// The associated [EntityRepository] of this table.
  EntityRepository? entityRepository;

  CreateTableSQL(SQLDialect dialect, String table, List<SQLEntry> entries,
      {String q = '"',
      this.indexes,
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
      <SQLBuilder>[...?indexes, ...?relationships, ...?alterTables];

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
    } else if (other is CreateIndexSQL) {
      var cmp = other.compareTo(this);
      return -cmp;
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

  AlterTableSQL(SQLDialect dialect, String table, List<SQLEntry> entries,
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
    } else if (other is CreateIndexSQL) {
      var cmp = other.compareTo(this);
      return -cmp;
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

extension SQLBuilderMapExtension<K> on Map<K, CreateTableSQL> {
  Map<K, CreateTableSQL> bestOrder() {
    var allSQLs = values.expand((e) => e.allSQLBuilders).toList();
    allSQLs.bestOrder();

    var ordered = entries.bestOrder().toMapFromEntries();
    return ordered;
  }
}

extension SQLBuilderIterableMapEntryExtension<K>
    on Iterable<MapEntry<K, CreateTableSQL>> {
  List<MapEntry<K, CreateTableSQL>> bestOrder() {
    var allSQLs = expand((e) => e.value.allSQLBuilders).toList();
    allSQLs.bestOrder();

    var ordered = sorted((a, b) {
      var i1 = allSQLs.indexOf(a.value);
      var i2 = allSQLs.indexOf(b.value);
      var cmp = i1.compareTo(i2);
      return cmp;
    }).toList();

    return ordered;
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

  List<String> _referenceTablesInList(List<String>? refTables) {
    return refTables == null || refTables.isEmpty
        ? <String>[]
        : refTables.where((r) => _indexOfTable(r, 0) != null).toList();
  }

  Map<SQLBuilder, List<String>> _entriesRefsInList() =>
      map((e) => MapEntry(e, _referenceTablesInList(e.referenceTables)))
          .toMapFromEntries();

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

    var withReference = where((e) {
      var referenceTables = e.referenceTables;
      return referenceTables != null && referenceTables.isNotEmpty;
    }).toList();
    removeAll(withReference);

    withParents._bestOrderLoop();
    withReference._bestOrderLoop();
    withRelationship._bestOrderLoop();

    _bestOrderLoop();

    refsGetter(SQLBuilder e) => e is CreateTableSQL
        ? e.referenceAndRelationshipTables
        : e.referenceTables ?? [];

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

  int _addByRefPos(List<SQLBuilder> list,
      {List<String> Function(SQLBuilder e)? refsGetter,
      bool addAtEnd = false}) {
    refsGetter ??= (e) => e.referenceTables ?? [];

    var count = 0;

    if (addAtEnd) {
      for (var i = 0; i < list.length; ++i) {
        var e = list[i];
        var refs = refsGetter(e);
        var refsInList = _referenceTablesInList(refs);
        var idx = _indexWithAllReferenceTables(refsInList, 0);

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
        var refsInList = _referenceTablesInList(refs);
        var idx = _indexWithAllReferenceTables(refsInList, 0);

        if (idx != null) {
          ++idx;
          while (idx! < length && this[idx] is CreateIndexSQL) {
            ++idx;
          }

          insert(idx, e);
          list.removeAt(i);
          count++;
        }
      }
    }

    return count;
  }

  void _bestOrderLoop() {
    var entriesRefsInList = _entriesRefsInList();

    while (true) {
      if (!_bestOrderImpl(entriesRefsInList)) {
        break;
      }
    }
  }

  bool _bestOrderImpl(Map<SQLBuilder, List<String>> entriesRefsInList) {
    final length = this.length;

    var moved = false;

    for (var i = 0; i < length;) {
      var e = this[i];
      var refsInList = entriesRefsInList[e]!;
      if (refsInList.isEmpty) {
        ++i;
        continue;
      }

      if (!_headContainsReferenceTable(refsInList, i)) {
        var idx = _indexWithAllReferenceTables(refsInList, 0);

        if (idx != null && idx > i) {
          ++idx;
          while (idx! < length && this[idx] is CreateIndexSQL) {
            ++idx;
          }

          insert(idx, e);
          var prev = removeAt(i);
          moved = true;

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
  SQLDialect get dialect;

  /// The generated SQL dialect name.
  String get dialectName;

  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName});

  EntityRepository<O>? getEntityRepositoryByType<O extends Object>(Type type);

  EntityRepository<O>? getEntityRepositoryByTypeInfo<O extends Object>(
      TypeInfo typeInfo);

  String getTableForEntityRepository(EntityRepository entityRepository);

  String? typeToSQLType(TypeInfo type, String column,
      {List<EntityField>? entityFieldAnnotations}) {
    if (type.isString) {
      var maximum = entityFieldAnnotations?.maximum.firstOrNull;
      return maximum != null && maximum > 0 ? 'VARCHAR($maximum)' : 'VARCHAR';
    } else if (type.isBool) {
      return 'BOOLEAN';
    } else if (type.isDateTime) {
      return 'TIMESTAMP';
    } else if (type.type == Time) {
      return 'TIME';
    } else if (type.isDouble || type.type == Decimal) {
      return 'DECIMAL';
    } else if (type.isInt) {
      return 'INT';
    } else if (type.isBigInt || type.type == DynamicInt) {
      return 'BIGINT';
    } else if (type.isUInt8List) {
      return 'BLOB';
    }

    return null;
  }

  /// Returns the preferred `VARCHAR` size for a [column] name.
  int getVarcharPreferredSize(String? column) {
    if (column == null) return 1024;

    column = column.trim();
    if (column.isEmpty) return 1024;

    column = normalizeColumnName(column);
    if (column.isEmpty) return 1024;

    switch (column) {
      case 'tel':
      case 'cel':
      case 'cell':
      case 'phone':
      case 'celphone':
      case 'cellphone':
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

      case 'hash':
      case 'pass':
      case 'passhash':
      case 'password':
      case 'passwordhash':
      case 'passphrase':
      case 'passphrasehash':
        return 512;

      case 'title':
      case 'description':
        return 1024;

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

  String? primaryKeyTypeToSQLType(Type type,
      {List<EntityField>? entityFieldAnnotations}) {
    if (type.isNumericOrDynamicNumberType) {
      return 'SERIAL PRIMARY KEY';
    } else if (type == String) {
      if (dialect.acceptsVarcharWithoutMaximumSize) {
        return 'VARCHAR PRIMARY KEY';
      } else {
        var maximum = entityFieldAnnotations?.maximum.firstOrNull ?? 254;
        return 'VARCHAR($maximum) PRIMARY KEY';
      }
    } else {
      return 'PRIMARY KEY';
    }
  }

  /// Returns `true` if [columnType] is a sibling of the [tableRepository].
  bool isSiblingEntityType(EntityRepository tableRepository, Type columnType,
      {EntityRepository? columnRepository}) {
    columnRepository ??= getEntityRepositoryByType(columnType);
    if (columnRepository == null) return false;

    if (tableRepository is DBEntityRepository) {
      var tableAdapter = tableRepository.repositoryAdapter.databaseAdapter;

      if (columnRepository is DBEntityRepository) {
        var columnAdapter = columnRepository.repositoryAdapter.databaseAdapter;
        if (columnAdapter != tableAdapter) {
          return false;
        }
      }
    } else if (tableRepository.provider != columnRepository.provider) {
      return false;
    }

    return true;
  }

  /// Returns info for the column: table -> idName: sqlType
  MapEntry<String, MapEntry<String, String>>? entityTypeToSQLType(
      TypeInfo type, String? column,
      {List<EntityField>? entityFieldAnnotations}) {
    var typeEntityRepository = getEntityRepositoryByTypeInfo(type);
    if (typeEntityRepository == null) return null;

    var entityHandler = typeEntityRepository.entityHandler;

    var idName = entityHandler.idFieldName();
    var idType = entityHandler.idType();
    var idEntityAnnotations = entityHandler
        .getFieldEntityAnnotations(null, idName)
        ?.whereType<EntityField>()
        .toList();

    var sqlType = foreignKeyTypeToSQLType(TypeInfo.fromType(idType), idName,
        entityFieldAnnotations: idEntityAnnotations);

    if (sqlType == null) return null;

    var table = getTableForEntityRepository(typeEntityRepository);

    return MapEntry(table, MapEntry(idName, sqlType));
  }

  String? foreignKeyTypeToSQLType(TypeInfo idType, String idName,
      {List<EntityField>? entityFieldAnnotations}) {
    if (idType.isInt) {
      idType = TypeInfo.tBigInt;
    }

    var sqlType = typeToSQLType(idType, idName,
        entityFieldAnnotations: entityFieldAnnotations);
    return sqlType;
  }

  /// Returns: ENUM: valuesNames
  MapEntry<String, List<String>>? enumTypeToSQLType(Type type, String column,
      {List<EntityField>? entityFieldAnnotations}) {
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

  CreateTableSQL generateCreateTableSQL(
      {EntityRepository? entityRepository,
      Object? obj,
      Type? type,
      String? name,
      String? tableName,
      bool ifNotExists = true,
      bool sortColumns = true}) {
    entityRepository ??=
        getEntityRepository(type: type, obj: obj, name: name, tableName: name);
    if (entityRepository == null) {
      throw ArgumentError(
          "Can't resolve `EntityRepository`> obj: $obj ; type: $type ; name: $name ; tableName: $tableName");
    }

    var q = dialect.elementQuote;

    var entityType = entityRepository.type;
    var entityHandler = entityRepository.entityHandler;

    var table = getTableForEntityRepository(entityRepository);

    var idFieldName = entityHandler.idFieldName();
    var idType = entityHandler.idType();

    var idColumnName = normalizeColumnName(idFieldName);
    var idAnnotations = entityHandler
        .getFieldEntityAnnotations(null, idFieldName)
        ?.whereType<EntityField>()
        .toList();

    var idTypeSQL =
        primaryKeyTypeToSQLType(idType, entityFieldAnnotations: idAnnotations);

    var sqlEntries = <SQLEntry>[
      SQLEntry('COLUMN', ' $q$idColumnName$q $idTypeSQL',
          comment: '$idType $idFieldName',
          columns: [SQLColumn(table, idColumnName)]),
    ];

    var indexSQLs = <CreateIndexSQL>[];

    var fieldsEntries = entityHandler
        .fieldsTypes()
        .entries
        .where((e) => !e.value.isListEntityOrReference)
        .toList();

    if (sortColumns) {
      fieldsEntries.sort((a, b) => a.key.compareTo(b.key));
    }

    var referenceFields =
        <String, MapEntry<String, MapEntry<String, String>>>{};

    for (var e in fieldsEntries) {
      var fieldName = e.key;
      var fieldType = e.value;
      if (fieldName == idFieldName) continue;

      var entityFieldAnnotations = entityHandler
          .getFieldEntityAnnotations(null, fieldName)
          ?.whereType<EntityField>()
          .toList();

      var columnName = normalizeColumnName(fieldName);
      var comment = '${fieldType.toString(withT: false)} $fieldName';

      String? refTable;
      String? refColumn;

      var fieldSQLType = typeToSQLType(fieldType, columnName,
          entityFieldAnnotations: entityFieldAnnotations);

      if (fieldSQLType == null) {
        var entityType = entityTypeToSQLType(fieldType, columnName,
            entityFieldAnnotations: entityFieldAnnotations);
        if (entityType != null) {
          if (isSiblingEntityType(entityRepository, fieldType.type)) {
            referenceFields[columnName] = entityType;
          }

          fieldSQLType = entityType.value.value;

          refTable = entityType.key;
          refColumn = entityType.value.key;

          comment += ' @ $refTable.$refColumn';
        }
      }

      if (fieldSQLType == null) {
        var enumType = enumTypeToSQLType(fieldType.type, columnName,
            entityFieldAnnotations: entityFieldAnnotations);
        if (enumType != null) {
          var type = enumType.key;
          var values = enumType.value;

          if (type == 'ENUM') {
            fieldSQLType = type;
            fieldSQLType += '(${values.map((e) => "'$e'").join(',')})';
          } else if (type.endsWith(' CHECK')) {
            fieldSQLType = type;
            fieldSQLType +=
                '( $q$columnName$q IN (${values.map((e) => "'$e'").join(',')}) )';
          } else {
            fieldSQLType = type;
          }

          comment += ' enum(${values.join(', ')})';
        }
      }

      if (fieldSQLType == null) {
        _log.warning("Can't define field SQL type: `$table`.`$fieldName`");
        continue;
      }

      sqlEntries.add(SQLEntry('COLUMN', ' $q$columnName$q $fieldSQLType',
          comment: comment,
          columns: [
            SQLColumn(table, columnName,
                referenceTable: refTable, referenceColumn: refColumn)
          ]));

      if (entityFieldAnnotations != null) {
        if (entityFieldAnnotations.hasUnique) {
          var constrainUniqueName = '${table}__${columnName}__unique';

          sqlEntries.add(SQLEntry('CONSTRAINT',
              ' CONSTRAINT $q$constrainUniqueName$q UNIQUE ($q$columnName$q)',
              columns: [
                SQLColumn(table, columnName,
                    referenceTable: refTable, referenceColumn: refColumn)
              ]));
        } else if (entityFieldAnnotations.hasIndexed) {
          var indexName = '${table}__${columnName}__idx';
          indexSQLs
              .add(CreateIndexSQL(dialect, table, columnName, indexName, q: q));
        }
      }
    }

    for (var e in referenceFields.entries) {
      var fieldName = e.key;
      var ref = e.value;

      var columnName = normalizeColumnName(fieldName);

      var refTableName = ref.key;
      var refField = ref.value.key.toLowerCase();

      var constrainName = '${table}__${columnName}__fkey';

      sqlEntries.add(SQLEntry('CONSTRAINT',
          ' CONSTRAINT $q$constrainName$q FOREIGN KEY ($q$columnName$q) REFERENCES $q$refTableName$q($q$refField$q)',
          comment: '$fieldName @ $refTableName.$refField',
          columns: [
            SQLColumn(table, columnName,
                referenceTable: refTableName, referenceColumn: refField)
          ]));
    }

    sqlEntries.sort((a, b) {
      var c1 = a.type == 'CONSTRAINT';
      var c2 = b.type == 'CONSTRAINT';

      if (c1) {
        return c2 ? 0 : 1;
      } else {
        return c2 ? -1 : 0;
      }
    });

    var createSQL = CreateTableSQL(dialect, table, sqlEntries,
        q: q, entityRepository: entityRepository, indexes: indexSQLs);

    var relationshipSQLs = <CreateTableSQL>[];

    var relationshipEntries = entityHandler
        .fieldsTypes()
        .entries
        .where((e) => e.value.isListEntityOrReference)
        .toList();

    for (var e in relationshipEntries) {
      var fieldName = e.key;
      var fieldType = e.value.arguments0!;

      var entityFieldAnnotations = entityHandler
          .getFieldEntityAnnotations(null, fieldName)
          ?.whereType<EntityField>()
          .toList();

      var columnName = normalizeColumnName(fieldName);

      var srcFieldName = normalizeColumnName(table);
      var relSrcType = foreignKeyTypeToSQLType(
          TypeInfo.fromType(idType), srcFieldName,
          entityFieldAnnotations: entityFieldAnnotations);

      var relDstType = entityTypeToSQLType(fieldType, null);
      if (relDstType == null) continue;

      var relDstTable = relDstType.key;
      var relDstTableId = relDstType.value.key;
      var relDstTypeSQL = relDstType.value.value;

      var dstFieldName = normalizeColumnName(relDstTable);

      var relName = '${table}__${columnName}__rel';

      var constrainUniqueName = '${relName}__unique';
      var constrainSrcName = '${relName}__${srcFieldName}__fkey';
      var constrainDstName = '${relName}__${dstFieldName}__fkey';

      var sqlRelEntries = <SQLEntry>[
        SQLEntry('COLUMN', ' $q$srcFieldName$q $relSrcType NOT NULL',
            comment: '$entityType.${e.key}',
            columns: [
              SQLColumn(relName, srcFieldName,
                  referenceTable: table, referenceColumn: idColumnName)
            ]),
        SQLEntry('COLUMN', ' $q$dstFieldName$q $relDstTypeSQL NOT NULL',
            comment:
                '${e.value.toString(withT: false)} @ $relDstTable.$relDstTableId',
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
            ' CONSTRAINT $q$constrainSrcName$q FOREIGN KEY ($q$srcFieldName$q) REFERENCES $q$table$q($q$idColumnName$q) ON DELETE CASCADE',
            comment: ' $srcFieldName @ $table.$idColumnName',
            columns: [
              SQLColumn(relName, srcFieldName,
                  referenceTable: table, referenceColumn: idColumnName)
            ]),
        SQLEntry('CONSTRAINT',
            ' CONSTRAINT $q$constrainDstName$q FOREIGN KEY ($q$dstFieldName$q) REFERENCES $q$relDstTable$q($q$relDstTableId$q) ON DELETE CASCADE',
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

  String normalizeColumnName(String fieldName) =>
      StringUtils.toLowerCaseUnderscore(fieldName, simple: true);

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
      fullSQL.write('-- Dialect: ${dialect.name}\n');
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
