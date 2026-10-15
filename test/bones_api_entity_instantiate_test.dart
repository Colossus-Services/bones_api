@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

part 'bones_api_entity_instantiate_test.reflection.g.dart';

@EnableReflection()
enum TaskState { open, closed }

@EnableReflection()
class TaskStep {
  int? id;
  String name;

  TaskStep(this.name, {this.id});
}

/// Only a constructor with parameters (no instance without arguments), whose
/// parameters have the fields' types: `ClassReflectionEntityHandler` resolves
/// the values up front and calls it directly from the map.
@EnableReflection()
class Task {
  int? id;
  String title;
  TaskState state;
  DateTime due;
  double score;
  List<TaskStep> steps;

  Task(this.title, this.state, this.due, this.steps, {this.id, this.score = 0});
}

/// The `created` parameter has another type than its field: the values are
/// resolved by `createInstanceFromMap`, by the parameters' types.
@EnableReflection()
class Note {
  int? id;
  String text;
  DateTime created;

  Note(this.text, {Object? created, this.id})
    : created = created is DateTime
          ? created
          : DateTime.parse(created?.toString() ?? '2000-01-01T00:00:00Z');
}

/// The `titleText` parameter isn't a field: a map with that key is resolved
/// by `createInstanceFromMap`.
@EnableReflection()
class Ticket {
  int? id;
  String title;

  Ticket(String titleText, {this.id}) : title = titleText;
}

/// Entity references as constructor parameters with the fields' types
/// (`EntityReference<TaskStep>`, `EntityReferenceList<TaskStep>`), and
/// `Decimal`, `bool` (`0`/`1` in SQLite), `Time` and `DateTime` values:
/// resolved up front and called directly from the map.
@EnableReflection()
class Project {
  int? id;
  String name;
  EntityReference<TaskStep> mainStep;
  EntityReference<TaskStep>? reviewStep;
  EntityReferenceList<TaskStep> steps;
  Decimal? budget;
  bool active;
  Time? startTime;
  DateTime? createdAt;

  Project(
    this.name,
    this.mainStep,
    this.steps, {
    this.id,
    this.reviewStep,
    this.budget,
    this.active = true,
    this.startTime,
    this.createdAt,
  });
}

/// Collections and maps of plain values (no DB).
@EnableReflection()
class Settings {
  int? id;
  List<String> tags;
  List<int>? ranks;
  Map<String, dynamic>? meta;
  Set<String>? flags;

  Settings({this.id, this.tags = const [], this.ranks, this.meta, this.flags});
}

/// A field with a JSON name alias.
@EnableReflection()
class Label {
  int? id;
  String name;

  @JsonFieldAlias('colorCode')
  String? color;

  Label(this.name, {this.id, this.color});
}

/// A `@JsonConstructor`, and another constructor.
@EnableReflection()
class Invoice {
  int? id;
  String number;
  Decimal total;

  @JsonConstructor()
  Invoice(this.number, this.total, {this.id});

  Invoice.empty() : this('', Decimal.zero);
}

abstract class Counted<T> {
  T? value;
  List<T> values;

  Counted(this.values, {this.value});
}

/// Fields inherited with a type argument: the field types (`List<dynamic>`)
/// aren't the parameters' (`List<int>`), so values are resolved by
/// `createInstanceFromMap`.
@EnableReflection()
class Counter extends Counted<int> {
  int? id;

  Counter(super.values, {super.value, this.id});
}

/// No constructor with parameters: `create()` + setters.
@EnableReflection()
class Profile {
  int? id;
  String name = '';
  String? bio = 'initial';
  bool verified = false;
  DateTime? lastSeen;
  Decimal? balance;

  Profile();
}

/// A DB with the [Task]s and their [TaskStep]s, whose entity handlers are
/// `ClassReflectionEntityHandler`s (reflection based instantiation).
class _TaskProvider extends EntityRepositoryProvider {
  late final DBSQLAdapter adapter;
  late final DBSQLEntityRepository<TaskStep> stepRepository;
  late final DBSQLEntityRepository<Task> taskRepository;
  late final DBSQLEntityRepository<Project> projectRepository;

  _TaskProvider({required bool sqlite}) {
    adapter = sqlite
        ? DBSQLiteAdapter(
            sqliteMemoryPath,
            parentRepositoryProvider: this,
            generateTables: true,
          )
        : DBSQLMemoryAdapter(parentRepositoryProvider: this);

    stepRepository = DBSQLEntityRepository<TaskStep>(
      adapter,
      'task_step',
      TaskStep$reflection().entityHandler,
    );

    taskRepository = DBSQLEntityRepository<Task>(
      adapter,
      'task',
      Task$reflection().entityHandler,
    );

    projectRepository = DBSQLEntityRepository<Project>(
      adapter,
      'project',
      Project$reflection().entityHandler,
    );
  }

  void dispose() {
    adapter.close();
    close();
  }
}

/// The instance as JSON (comparable), `null`, or the error type.
Object? _outcome(Object? Function() create) {
  try {
    var o = create();
    return o == null ? null : Json.toJson(o);
  } catch (e) {
    return e.runtimeType;
  }
}

/// [ClassReflectionEntityHandler.instantiateFromMapImpl] before it resolved
/// the values up front: `createInstanceFromMap` with the JSON resolvers.
O? _instantiateWithResolvers<O>(
  ClassReflectionEntityHandler<O> handler,
  Map<String, dynamic> map,
) => handler.reflection.createInstanceFromMap(
  map,
  fieldNameResolver: Json.defaultFieldNameResolver,
  fieldValueResolver: (f, v, t) => Json.defaultFieldValueResolver(
    f,
    v,
    t,
    Json.defaultDecoder,
    handler.provider,
  ),
);

/// Checks that [ClassReflectionEntityHandler.instantiateFromMapImpl] gives
/// the same outcome for [map] as `createInstanceFromMap` with the JSON
/// resolvers, and that [map] isn't changed. Returns the outcome.
Object? _expectSameAsWithResolvers<O>(
  ClassReflectionEntityHandler<O> handler,
  Map<String, dynamic> map,
) {
  var mapCopy = Map<String, dynamic>.of(map);

  var outcome = _outcome(() => handler.instantiateFromMapImpl(map) as O?);

  expect(map, equals(mapCopy), reason: 'changed: $mapCopy');

  expect(
    outcome,
    equals(_outcome(() => _instantiateWithResolvers<O>(handler, map))),
    reason: '$map',
  );

  return outcome;
}

/// Whether each constructor parameter named as a field has that field's
/// type: then `ClassReflectionEntityHandler` can resolve the values up front
/// (by the field types) and pass them with `valuesResolved`.
bool _parametersHaveFieldsTypes(ClassReflection reflection) {
  for (var c in reflection.allConstructors()) {
    for (var p in c.allParameters) {
      var field = reflection.field(p.name);
      if (field != null && p.type.typeInfo != field.type.typeInfo) {
        return false;
      }
    }
  }
  return true;
}

void main() {
  group('ClassReflectionEntityHandler.instantiateFromMapImpl', () {
    final due = DateTime.utc(2026, 1, 2, 3, 4, 5);

    test(
      'values from JSON: enum, DateTime, int as double, entity list',
      () async {
        var handler = Task$reflection().entityHandler;

        var task = await handler.createFromMap({
          'id': 1,
          'title': 'Write tests',
          'state': 'closed',
          'due': due.toIso8601String(),
          'score': 2,
          'steps': [
            {'id': 10, 'name': 'a'},
            {'name': 'b'},
          ],
        });

        expect(task.id, equals(1));
        expect(task.title, equals('Write tests'));
        expect(task.state, equals(TaskState.closed));
        expect(task.due, equals(due));
        expect(task.score, isA<double>());
        expect(task.score, equals(2.0));
        expect(task.steps, isA<List<TaskStep>>());
        expect(task.steps.map((s) => s.name), equals(['a', 'b']));
        expect(task.steps.first.id, equals(10));
      },
    );

    test('values already resolved', () async {
      var handler = Task$reflection().entityHandler;

      var task = await handler.createFromMap({
        'title': 'Resolved',
        'state': TaskState.open,
        'due': due,
        'steps': <TaskStep>[TaskStep('x')],
      });

      expect(task.id, isNull);
      expect(task.state, equals(TaskState.open));
      expect(task.due, equals(due));
      // A default typed by its parameter (`double score = 0`):
      expect(task.score, isA<double>());
      expect(task.score, equals(0.0));
      expect(task.steps.single.name, equals('x'));
    });

    test('a parameter with another type than its field', () async {
      var handler = Note$reflection().entityHandler;

      var note = await handler.createFromMap({
        'id': 3,
        'text': 'hello',
        'created': due.toIso8601String(),
      });

      expect(note.id, equals(3));
      expect(note.text, equals('hello'));
      expect(note.created, equals(due));
    });

    test('a key that is a constructor parameter, not a field', () async {
      var handler = Ticket$reflection().entityHandler;

      var ticket = await handler.createFromMap({'id': 4, 'titleText': 'T'});

      expect(ticket.id, equals(4));
      expect(ticket.title, equals('T'));
    });

    test('same outcome as with the JSON resolvers', () {
      var dueISO = due.toIso8601String();

      void expectSame<O>(
        ClassReflectionEntityHandler<O> handler,
        Map<String, dynamic> map,
      ) {
        expect(
          _outcome(() => handler.instantiateFromMapImpl(map) as O?),
          equals(_outcome(() => _instantiateWithResolvers<O>(handler, map))),
          reason: '$map',
        );
      }

      var tasks = Task$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        // JSON values:
        {
          'id': 1,
          'title': 't',
          'state': 'closed',
          'due': dueISO,
          'score': 2,
          'steps': [
            {'id': 10, 'name': 'a'},
            {'name': 'b'},
          ],
        },
        // Resolved values:
        {
          'title': 't',
          'state': TaskState.open,
          'due': due,
          'score': 1.5,
          'steps': <TaskStep>[TaskStep('x')],
        },
        // Absent and null optional values:
        {'title': 't', 'state': 'open', 'due': dueISO, 'steps': []},
        {
          'title': 't',
          'state': 'open',
          'due': dueISO,
          'steps': [],
          'score': null,
          'id': null,
        },
        // A value the resolver can't resolve (an unknown enum name):
        {'title': 't', 'state': 'nope', 'due': dueISO, 'steps': []},
        // A value converted by the resolver (an `int` for a `String`):
        {'title': 7, 'state': 'open', 'due': dueISO, 'steps': []},
        // A key that isn't a field:
        {'title': 't', 'state': 'open', 'due': dueISO, 'steps': [], 'x': 1},
        // Missing required values:
        {'title': 't'},
        {},
      ]) {
        expectSame(tasks, map);
      }

      var notes = Note$reflection().entityHandler;
      expectSame(notes, {'text': 'n', 'created': dueISO});
      expectSame(notes, {'text': 'n', 'created': due, 'id': 2});

      var tickets = Ticket$reflection().entityHandler;
      expectSame(tickets, {'titleText': 'T'});
      expectSame(tickets, {'title': 'T'});
    });
  });

  group('instantiateFromMapImpl: value shapes', () {
    final created = DateTime.utc(2026, 3, 4, 5, 6, 7);
    final createdISO = created.toIso8601String();

    final stepsHandler = TaskStep$reflection().entityHandler;

    test('which classes take the direct call', () {
      for (var r in <ClassReflection>[
        Task$reflection(),
        Project$reflection(),
        Settings$reflection(),
        Label$reflection(),
        Invoice$reflection(),
        Profile$reflection(),
      ]) {
        expect(_parametersHaveFieldsTypes(r), isTrue, reason: r.className);
      }

      for (var r in <ClassReflection>[
        Note$reflection(),
        Counter$reflection(),
      ]) {
        expect(_parametersHaveFieldsTypes(r), isFalse, reason: r.className);
      }
    });

    test('entity references: as IDs, maps, entities and references', () {
      var handler = Project$reflection().entityHandler;

      var step = TaskStep('s', id: 10);
      var step2 = TaskStep('s2', id: 11);

      EntityReferenceList<TaskStep> stepsOf(List<Object> ids) =>
          EntityReferenceList<TaskStep>.fromIDs(
            ids,
            entityHandler: stepsHandler,
          );

      // An `EntityReference` parameter resolves an ID, a map, an entity or a
      // reference (an `EntityReferenceList` parameter takes a reference list:
      // see below):
      for (var map in <Map<String, dynamic>>[
        // IDs (as in DB rows):
        {
          'id': 1,
          'name': 'p',
          'mainStep': 10,
          'steps': stepsOf([10, 11]),
        },
        // Maps (as in JSON):
        {
          'name': 'p',
          'mainStep': {'id': 10, 'name': 's'},
          'reviewStep': {'name': 'r'},
          'steps': stepsOf([]),
        },
        // Entities:
        {
          'name': 'p',
          'mainStep': step,
          'reviewStep': step2,
          'steps': EntityReferenceList<TaskStep>.fromEntities([step, step2]),
        },
        // References:
        {
          'name': 'p',
          'mainStep': EntityReference<TaskStep>.fromID(
            10,
            entityHandler: stepsHandler,
          ),
          'steps': stepsOf([10]),
        },
        {
          'name': 'p',
          'mainStep': EntityReference<TaskStep>.fromEntity(step),
          'steps': EntityReferenceList<TaskStep>.fromEntities([step]),
        },
        // Null and absent:
        {'name': 'p', 'mainStep': 10, 'steps': stepsOf([]), 'reviewStep': null},
      ]) {
        var outcome = _expectSameAsWithResolvers(handler, map);
        expect(outcome, isA<Map>(), reason: '$map');
      }

      // Plain lists for an `EntityReferenceList` parameter (as in JSON):
      // resolved as an `EntityReferenceList` by
      // `Json.defaultFieldValueResolver`.
      for (var (steps, ids) in <(Object, List<Object?>)>[
        ([10, 11], [10, 11]),
        (
          [
            {'id': 10, 'name': 's'},
          ],
          [10],
        ),
        (<TaskStep>[step, step2], [10, 11]),
        (<dynamic>[step], [10]),
        ([10, null], [10, null]),
        ([], []),
      ]) {
        var map = {'name': 'p', 'mainStep': 10, 'steps': steps};
        var outcome = _expectSameAsWithResolvers(handler, map);
        expect(outcome, isA<Map>(), reason: '$map');

        var p = handler.instantiateFromMapImpl(map) as Project;
        expect(p.steps, isA<EntityReferenceList<TaskStep>>());
        expect(p.steps.ids, equals(ids), reason: '$map');
      }

      // Not instantiable, on both paths:
      for (var map in <Map<String, dynamic>>[
        // A `null` or absent non-nullable reference:
        {'name': 'p', 'mainStep': null, 'steps': stepsOf([])},
        {'name': 'p', 'steps': stepsOf([])},
        {'name': 'p', 'mainStep': 10, 'steps': null},
        // Values that aren't IDs, entities or entities maps:
        {
          'name': 'p',
          'mainStep': 10,
          'steps': [true],
        },
      ]) {
        var outcome = _expectSameAsWithResolvers(handler, map);
        expect(outcome, isNot(isA<Map>()), reason: '$map');
      }

      var p =
          handler.instantiateFromMapImpl({
                'name': 'p',
                'mainStep': 10,
                'steps': stepsOf([10, 11]),
              })
              as Project;
      expect(p.mainStep, isA<EntityReference<TaskStep>>());
      expect(p.mainStep.id, equals(10));
      expect(p.steps, isA<EntityReferenceList<TaskStep>>());
      expect(p.steps.ids, equals([10, 11]));
      expect(p.reviewStep, isNull);
      expect(p.active, isTrue);

      var p2 =
          handler.instantiateFromMapImpl({
                'name': 'p',
                'mainStep': step,
                'reviewStep': {'id': 11, 'name': 's2'},
                'steps': EntityReferenceList<TaskStep>.fromEntities([step]),
              })
              as Project;
      expect(p2.mainStep.entity, same(step));
      expect(p2.reviewStep!.entity!.name, equals('s2'));
      expect(p2.steps.entities, equals([step]));
    });

    test('Decimal, bool, Time and DateTime', () {
      var handler = Project$reflection().entityHandler;

      Map<String, dynamic> project(Map<String, dynamic> values) => {
        'name': 'p',
        'mainStep': 10,
        'steps': EntityReferenceList<TaskStep>.fromIDs([
          10,
        ], entityHandler: stepsHandler),
        ...values,
      };

      for (var values in <Map<String, dynamic>>[
        {'budget': '1.50'},
        {'budget': 2},
        {'budget': 1.25},
        {'budget': Decimal.parse('3.75')},
        // `bool` as in SQLite (`0`/`1`) and as text:
        {'active': 0},
        {'active': 1},
        {'active': 'true'},
        {'active': 'false'},
        {'active': false},
        {'active': null},
        {'startTime': '07:30:00'},
        {'startTime': Time(7, 30)},
        {'createdAt': createdISO},
        {'createdAt': created.millisecondsSinceEpoch},
        {'createdAt': created},
      ]) {
        var outcome = _expectSameAsWithResolvers(handler, project(values));
        expect(outcome, isA<Map>(), reason: '$values');
      }

      // Values that don't resolve (the same outcome, instantiated or not):
      for (var values in <Map<String, dynamic>>[
        {'budget': 'x'},
        {'active': 'x'},
        {'startTime': '7h'},
        {'createdAt': 'x'},
      ]) {
        _expectSameAsWithResolvers(handler, project(values));
      }

      var p =
          handler.instantiateFromMapImpl(
                project({
                  'budget': '1.50',
                  'active': 0,
                  'startTime': '07:30:00',
                  'createdAt': created.millisecondsSinceEpoch,
                }),
              )
              as Project;
      expect(p.budget, equals(Decimal.parse('1.5')));
      expect(p.active, isFalse);
      expect(p.startTime, equals(Time(7, 30)));
      expect(p.createdAt!.isAtSameMomentAs(created), isTrue);
    });

    test('lists, sets and maps', () {
      var handler = Settings$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        {},
        // JSON lists (`List<dynamic>`):
        {
          'tags': ['a', 'b'],
          'ranks': [1, 2],
        },
        {
          'tags': <String>['a'],
          'ranks': <int>[1],
        },
        {
          'meta': {
            'a': 1,
            'b': [true],
          },
        },
        {'tags': null, 'ranks': null, 'meta': null, 'flags': null},
      ]) {
        var outcome = _expectSameAsWithResolvers(handler, map);
        expect(outcome, isA<Map>(), reason: '$map');
      }

      // A `Set` field, from a JSON list or a set:
      for (var flags in <Object>[
        ['x', 'y', 'x'],
        <String>{'x', 'y'},
        <dynamic>{'x', 'y'},
      ]) {
        var map = {'flags': flags};
        var outcome = _expectSameAsWithResolvers(handler, map);
        expect(outcome, isA<Map>(), reason: '$map');

        var s = handler.instantiateFromMapImpl(map) as Settings;
        expect(s.flags, isA<Set<String>>());
        expect(s.flags, equals({'x', 'y'}));
      }

      // Instantiated or not, the same outcome:
      for (var map in <Map<String, dynamic>>[
        {
          'flags': [1],
        },
        {
          'ranks': ['1', 2],
        },
        {'meta': '{"a": 1}'},
        {'tags': 'a'},
      ]) {
        _expectSameAsWithResolvers(handler, map);
      }

      var s =
          handler.instantiateFromMapImpl({
                'tags': ['a'],
                'ranks': [1],
              })
              as Settings;
      expect(s.tags, isA<List<String>>());
      expect(s.tags, equals(['a']));
      expect(s.ranks, isA<List<int>>());
      expect(s.flags, isNull);
    });

    test('Json.defaultFieldValueResolver: EntityReferenceList and Set', () {
      Object? resolve(TypeReflection type, Object? value) =>
          Json.defaultFieldValueResolver(
            'f',
            value,
            type,
            Json.defaultDecoder,
            null,
          );

      var stepsType = Project$reflection().field('steps')!.type;
      var flagsType = Settings$reflection().field('flags')!.type;

      var step = TaskStep('s', id: 21);

      for (var (value, ids) in <(Object, List<Object?>)>[
        ([21, 22], [21, 22]),
        (<Object?>[21, null], [21, null]),
        (
          [
            {'id': 21, 'name': 's'},
          ],
          [21],
        ),
        (<TaskStep>[step], [21]),
        (<dynamic>[step], [21]),
        ([], []),
      ]) {
        var r = resolve(stepsType, value);
        expect(r, isA<EntityReferenceList<TaskStep>>(), reason: '$value');
        expect((r as EntityReferenceList).ids, equals(ids), reason: '$value');
      }

      // An `EntityReferenceList` of the type is kept:
      var refs = EntityReferenceList<TaskStep>.fromIDs([1]);
      expect(resolve(stepsType, refs), same(refs));

      expect(resolve(stepsType, null), isNull);

      for (var value in <Object>[
        ['a', 'b', 'a'],
        <String>{'a', 'b'},
        <Object>['a', 'b'],
      ]) {
        var r = resolve(flagsType, value);
        expect(r, isA<Set<String>>(), reason: '$value');
        expect(r, equals({'a', 'b'}));
      }

      expect(resolve(flagsType, null), isNull);
    });

    test('a JSON name alias', () {
      var handler = Label$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        {'name': 'n', 'color': 'red'},
        // The alias isn't a field name (resolved by `createInstanceFromMap`):
        {'name': 'n', 'colorCode': 'red'},
        {'name': 'n', 'id': 1},
        {'name': 'n', 'color': null},
      ]) {
        _expectSameAsWithResolvers(handler, map);
      }

      var label =
          handler.instantiateFromMapImpl({'name': 'n', 'colorCode': 'red'})
              as Label;
      expect(label.color, equals('red'));
    });

    test('a @JsonConstructor', () {
      var handler = Invoice$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        {'number': 'A1', 'total': '9.99'},
        {'number': 'A1', 'total': 10, 'id': 2},
        {'number': 'A1', 'total': Decimal.parse('1.5')},
        {'number': 'A1'},
        {},
      ]) {
        _expectSameAsWithResolvers(handler, map);
      }

      var invoice =
          handler.instantiateFromMapImpl({'number': 'A1', 'total': '9.99'})
              as Invoice;
      expect(invoice.total, equals(Decimal.parse('9.99')));
    });

    test('fields inherited with a type argument', () {
      var handler = Counter$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        {
          'values': [1, 2],
          'value': 3,
        },
        {
          'values': <int>[1],
          'id': 1,
        },
        {
          'values': ['1', 2],
        },
        {'values': []},
      ]) {
        _expectSameAsWithResolvers(handler, map);
      }

      var c =
          handler.instantiateFromMapImpl({
                'values': [1, 2],
                'value': 3,
              })
              as Counter;
      expect(c.values, isA<List<int>>());
      expect(c.value, equals(3));
    });

    test('create() + setters', () {
      var handler = Profile$reflection().entityHandler;

      for (var map in <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'n',
          'bio': null,
          'verified': 1,
          'lastSeen': createdISO,
          'balance': '1.5',
        },
        {'bio': 'b'},
        {'name': 'n', 'verified': 'x'},
        {'name': null},
        {},
      ]) {
        _expectSameAsWithResolvers(handler, map);
      }

      var p =
          handler.instantiateFromMapImpl({
                'name': 'n',
                'bio': null,
                'verified': 1,
                'balance': '1.5',
              })
              as Profile;
      // A `null` value sets a nullable field to `null`:
      expect(p.bio, isNull);
      expect(p.verified, isTrue);
      expect(p.balance, equals(Decimal.parse('1.5')));
    });

    test('keys in other cases', () {
      // Keys that aren't field names are resolved by `createInstanceFromMap`,
      // with `Json.defaultFieldNameResolver` (ignoring case):
      var p = _expectSameAsWithResolvers(Project$reflection().entityHandler, {
        'NAME': 'p',
        'MainStep': 10,
        'steps': EntityReferenceList<TaskStep>.fromIDs([
          10,
        ], entityHandler: stepsHandler),
        'createdat': createdISO,
      });
      expect(p, isA<Map>());
      expect(p, containsPair('name', 'p'));

      var profile = _expectSameAsWithResolvers(
        Profile$reflection().entityHandler,
        {'NAME': 'n', 'LASTSEEN': createdISO},
      );
      expect(profile, isA<Map>());
      expect(profile, containsPair('name', 'n'));

      // Not matched (`_` in a key isn't ignored): the same on both paths.
      _expectSameAsWithResolvers(Project$reflection().entityHandler, {
        'name': 'p',
        'main_step': 10,
        'steps': EntityReferenceList<TaskStep>.fromIDs([
          10,
        ], entityHandler: stepsHandler),
      });
    });

    test('repeated, with alternating shapes', () {
      var handler = Project$reflection().entityHandler;

      EntityReferenceList<TaskStep> stepsOf(List<Object> ids) =>
          EntityReferenceList<TaskStep>.fromIDs(
            ids,
            entityHandler: stepsHandler,
          );

      final maps = <Map<String, dynamic>>[
        {'name': 'a', 'mainStep': 10, 'steps': stepsOf([])},
        {
          'name': 'b',
          'mainStep': {'id': 11, 'name': 's'},
          'steps': stepsOf([11]),
          'budget': '2',
        },
        {'NAME': 'c', 'MainStep': 12, 'steps': stepsOf([])},
        {'name': 'd', 'mainStep': 'x', 'steps': stepsOf([])},
        {'name': 'e', 'mainStep': 13, 'steps': []},
      ];

      var firstList = maps
          .map((m) => _expectSameAsWithResolvers(handler, m))
          .toList();
      for (var i = 0; i < 3; ++i) {
        expect(firstList[i], isA<Map>(), reason: '${maps[i]}');
      }

      for (var i = 0; i < 3; ++i) {
        expect(
          maps.reversed
              .map((m) => _outcome(() => handler.instantiateFromMapImpl(m)))
              .toList()
              .reversed
              .toList(),
          equals(firstList),
        );
      }
    });
  });

  for (var sqlite in [false, true]) {
    group('DB rows (${sqlite ? 'SQLite' : 'memory'})', () {
      late _TaskProvider provider;

      final due = DateTime.utc(2026, 1, 2, 3, 4, 5);

      setUp(() async {
        provider = _TaskProvider(sqlite: sqlite);
        await provider.ensureInitialized();
        await provider.adapter.ensureInitialized();
      });

      tearDown(() => provider.dispose());

      void expectTask(Task t, String title, TaskState state, double score) {
        expect(t.title, equals(title));
        expect(t.state, equals(state));
        expect(t.due.isAtSameMomentAs(due), isTrue, reason: '${t.due}');
        expect(t.score, isA<double>());
        expect(t.score, equals(score));
        expect(t.steps, isA<List<TaskStep>>());
      }

      test('store from JSON, load as DB rows', () async {
        var stored = await provider.taskRepository.storeAllFromJson([
          {
            'title': 'first',
            'state': 'closed',
            'due': due.toIso8601String(),
            'score': 2,
            'steps': [
              {'name': 'a'},
              {'name': 'b'},
            ],
          },
          {
            'title': 'second',
            'state': 'open',
            'due': due.toIso8601String(),
            'steps': [],
          },
        ]);

        expect(stored.length, equals(2));
        expectTask(stored[0], 'first', TaskState.closed, 2.0);
        expectTask(stored[1], 'second', TaskState.open, 0.0);

        var id1 = stored[0].id;
        expect(id1, isNotNull);

        var t1 = (await provider.taskRepository.selectByID(id1))!;
        expectTask(t1, 'first', TaskState.closed, 2.0);
        expect(t1.steps.map((s) => s.name), unorderedEquals(['a', 'b']));
        expect(t1.steps.every((s) => s.id != null), isTrue);

        var all = await provider.taskRepository.selectAll();
        expect(all.map((t) => t.title), unorderedEquals(['first', 'second']));
        expectTask(
          all.firstWhere((t) => t.title == 'second'),
          'second',
          TaskState.open,
          0.0,
        );
      });

      test('store entities, load as DB rows', () async {
        var task = Task('third', TaskState.open, due, [
          TaskStep('c'),
        ], score: 7.25);

        var id = await provider.taskRepository.store(task);
        expect(id, isNotNull);

        var loaded = (await provider.taskRepository.selectByID(id))!;
        expect(identical(loaded, task), isFalse);
        expectTask(loaded, 'third', TaskState.open, 7.25);
        expect(loaded.steps.single.name, equals('c'));
      });

      test('entity references, Decimal, bool and Time from DB rows', () async {
        var s1 = TaskStep('s1');
        var s2 = TaskStep('s2');
        await provider.stepRepository.storeAll([s1, s2]);
        expect(s1.id, isNotNull);
        expect(s2.id, isNotNull);

        var p1 = Project(
          'first',
          EntityReference<TaskStep>.fromEntity(s1),
          EntityReferenceList<TaskStep>.fromEntities([s1, s2]),
          reviewStep: EntityReference<TaskStep>.fromEntity(s2),
          budget: Decimal.parse('12.50'),
          active: false,
          startTime: Time(8, 15),
          createdAt: due,
        );

        var p2 = Project(
          'second',
          EntityReference<TaskStep>.fromEntity(s2),
          EntityReferenceList<TaskStep>.fromEntities([]),
        );

        var id1 = await provider.projectRepository.store(p1);
        var id2 = await provider.projectRepository.store(p2);

        void expectFirst(Project p) {
          expect(p.name, equals('first'));
          expect(p.mainStep, isA<EntityReference<TaskStep>>());
          expect(p.mainStep.id, equals(s1.id));
          expect(p.reviewStep?.id, equals(s2.id));
          expect(p.steps, isA<EntityReferenceList<TaskStep>>());
          expect(p.steps.ids, unorderedEquals([s1.id, s2.id]));
          expect(p.budget, equals(Decimal.parse('12.5')));
          expect(p.active, isFalse);
          expect(p.startTime, equals(Time(8, 15)));
          expect(p.createdAt!.isAtSameMomentAs(due), isTrue);
        }

        void expectSecond(Project p) {
          expect(p.name, equals('second'));
          expect(p.mainStep.id, equals(s2.id));
          expect(p.reviewStep?.id, isNull);
          expect(p.steps.ids ?? [], isEmpty);
          expect(p.budget, isNull);
          expect(p.active, isTrue);
          expect(p.startTime, isNull);
        }

        var loaded1 = (await provider.projectRepository.selectByID(id1))!;
        expect(identical(loaded1, p1), isFalse);
        expectFirst(loaded1);

        // The referenced entities, resolved:
        var main = await loaded1.mainStep.get();
        expect(main?.name, equals('s1'));

        expectSecond((await provider.projectRepository.selectByID(id2))!);

        var all = await provider.projectRepository.selectAll();
        expect(all.length, equals(2));
        expectFirst(all.firstWhere((p) => p.name == 'first'));
        expectSecond(all.firstWhere((p) => p.name == 'second'));

        var active = await provider.projectRepository.selectByQuery(
          'active == ?',
          parameters: [true],
        );
        expect(active.map((p) => p.name), equals(['second']));
      });

      test('entity references from JSON with IDs', () async {
        var s1 = TaskStep('s1');
        await provider.stepRepository.store(s1);

        var stored = await provider.projectRepository.storeAllFromJson([
          {
            'name': 'json',
            'mainStep': s1.id,
            'steps': [s1.id],
            'budget': '3.25',
            'active': 1,
            'startTime': '09:00:00',
          },
        ]);

        var id = stored.single.id;
        var loaded = (await provider.projectRepository.selectByID(id))!;
        expect(loaded.mainStep.id, equals(s1.id));
        expect(loaded.steps.ids, equals([s1.id]));
        expect(loaded.budget, equals(Decimal.parse('3.25')));
        expect(loaded.active, isTrue);
        expect(loaded.startTime, equals(Time(9)));
      });
    });
  }
}
