@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
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

/// A DB with the [Task]s and their [TaskStep]s, whose entity handlers are
/// `ClassReflectionEntityHandler`s (reflection based instantiation).
class _TaskProvider extends EntityRepositoryProvider {
  late final DBSQLAdapter adapter;
  late final DBSQLEntityRepository<TaskStep> stepRepository;
  late final DBSQLEntityRepository<Task> taskRepository;

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
    });
  }
}
