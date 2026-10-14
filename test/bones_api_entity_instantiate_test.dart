@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
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
  });
}
