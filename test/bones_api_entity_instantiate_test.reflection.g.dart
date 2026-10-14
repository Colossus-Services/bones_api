//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.12.0
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: no_leading_underscores_for_local_identifiers
// ignore_for_file: camel_case_types
// ignore_for_file: camel_case_extensions
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_entity_instantiate_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.12.0');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"created":
      return const Symbol(r"created");
    case r"id":
      return const Symbol(r"id");
    case r"score":
      return const Symbol(r"score");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
Note Note$fromJson(Map<String, Object?> map) =>
    Note$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Note Note$fromJsonEncoded(String jsonEncoded) =>
    Note$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Task Task$fromJson(Map<String, Object?> map) =>
    Task$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Task Task$fromJsonEncoded(String jsonEncoded) =>
    Task$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
TaskState? TaskState$from(Object? o) =>
    TaskState$reflection.staticInstance.from(o);
// ignore: non_constant_identifier_names
TaskStep TaskStep$fromJson(Map<String, Object?> map) =>
    TaskStep$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
TaskStep TaskStep$fromJsonEncoded(String jsonEncoded) =>
    TaskStep$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Ticket Ticket$fromJson(Map<String, Object?> map) =>
    Ticket$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Ticket Ticket$fromJsonEncoded(String jsonEncoded) =>
    Ticket$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class Note$reflection extends ClassReflection<Note> with __ReflectionMixin {
  static final Expando<Note$reflection> _objectReflections = Expando();

  factory Note$reflection([Note? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Note$reflection._(object);
  }

  Note$reflection._([Note? object]) : super(Note, r'Note', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.10.0');

  @override
  Note$reflection withObject([Note? obj]) =>
      Note$reflection(obj)..setupInternalsWith(this);

  static Note$reflection? _withoutObjectInstance;
  @override
  Note$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Note$reflection get staticInstance =>
      _withoutObjectInstance ??= Note$reflection._();

  @override
  Note$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Note$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Note? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Note? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Note? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Note>> _constructors = {};

  @override
  ConstructorReflection<Note>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Note>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Note>(
          this,
          Note,
          '',
          () => Note.new,
          const <__PR>[__PR(__TR.tString, 'text', false, true)],
          null,
          const <String, __PR>{
            'created': __PR(__TR.tObject, 'created', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
          invoker: (a) => Note(
            a[0] as String,
            created: identical(a[1], ConstructorReflection.absentArgument)
                ? null
                : a[1] as Object?,
            id: identical(a[2], ConstructorReflection.absentArgument)
                ? null
                : a[2] as int?,
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Note? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'created',
    'id',
    'text',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Note, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Note, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Note, T>? field<T>(String fieldName, [Note? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Note, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Note, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Note, T>;
  }

  FieldReflection<Note, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Note, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Note, dynamic>? _fieldImpl(String fieldName, Note? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Note, int?>(
          this,
          Note,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'text':
        return FieldReflection<Note, String>(
          this,
          Note,
          __TR.tString,
          'text',
          false,
          (o) =>
              () => o!.text,
          (o) =>
              (v) => o!.text = v,
          obj,
          false,
        );
      case 'created':
        return FieldReflection<Note, DateTime>(
          this,
          Note,
          const __TR<DateTime>(DateTime),
          'created',
          false,
          (o) =>
              () => o!.created,
          (o) =>
              (v) => o!.created = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Note? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'text': obj?.text,
      'created': obj?.created,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Note, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Note, R>? method<R>(String methodName, [Note? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Note, R>? staticMethod<R>(String methodName) => null;
}

class Task$reflection extends ClassReflection<Task> with __ReflectionMixin {
  static final Expando<Task$reflection> _objectReflections = Expando();

  factory Task$reflection([Task? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Task$reflection._(object);
  }

  Task$reflection._([Task? object]) : super(Task, r'Task', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.10.0');

  @override
  Task$reflection withObject([Task? obj]) =>
      Task$reflection(obj)..setupInternalsWith(this);

  static Task$reflection? _withoutObjectInstance;
  @override
  Task$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Task$reflection get staticInstance =>
      _withoutObjectInstance ??= Task$reflection._();

  @override
  Task$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Task$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Task? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Task? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Task? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Task>> _constructors = {};

  @override
  ConstructorReflection<Task>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Task>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Task>(
          this,
          Task,
          '',
          () => Task.new,
          const <__PR>[
            __PR(__TR.tString, 'title', false, true),
            __PR(__TR<TaskState>(TaskState), 'state', false, true),
            __PR(__TR<DateTime>(DateTime), 'due', false, true),
            __PR(
              __TR<List<TaskStep>>(List, <__TR>[__TR<TaskStep>(TaskStep)]),
              'steps',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'id': __PR(__TR.tInt, 'id', true, false),
            'score': __PR(__TR.tDouble, 'score', false, false, 0),
          },
          null,
          invoker: (a) => Task(
            a[0] as String,
            a[1] as TaskState,
            a[2] as DateTime,
            a[3] as List<TaskStep>,
            id: identical(a[4], ConstructorReflection.absentArgument)
                ? null
                : a[4] as int?,
            score: identical(a[5], ConstructorReflection.absentArgument)
                ? 0
                : a[5] as double,
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Task? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'due',
    'id',
    'score',
    'state',
    'steps',
    'title',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Task, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Task, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Task, T>? field<T>(String fieldName, [Task? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Task, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Task, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Task, T>;
  }

  FieldReflection<Task, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Task, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Task, dynamic>? _fieldImpl(String fieldName, Task? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Task, int?>(
          this,
          Task,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'title':
        return FieldReflection<Task, String>(
          this,
          Task,
          __TR.tString,
          'title',
          false,
          (o) =>
              () => o!.title,
          (o) =>
              (v) => o!.title = v,
          obj,
          false,
        );
      case 'state':
        return FieldReflection<Task, TaskState>(
          this,
          Task,
          const __TR<TaskState>(TaskState),
          'state',
          false,
          (o) =>
              () => o!.state,
          (o) =>
              (v) => o!.state = v,
          obj,
          false,
        );
      case 'due':
        return FieldReflection<Task, DateTime>(
          this,
          Task,
          const __TR<DateTime>(DateTime),
          'due',
          false,
          (o) =>
              () => o!.due,
          (o) =>
              (v) => o!.due = v,
          obj,
          false,
        );
      case 'score':
        return FieldReflection<Task, double>(
          this,
          Task,
          __TR.tDouble,
          'score',
          false,
          (o) =>
              () => o!.score,
          (o) =>
              (v) => o!.score = v,
          obj,
          false,
        );
      case 'steps':
        return FieldReflection<Task, List<TaskStep>>(
          this,
          Task,
          const __TR<List<TaskStep>>(List, <__TR>[__TR<TaskStep>(TaskStep)]),
          'steps',
          false,
          (o) =>
              () => o!.steps,
          (o) =>
              (v) => o!.steps = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Task? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'title': obj?.title,
      'state': obj?.state,
      'due': obj?.due,
      'score': obj?.score,
      'steps': obj?.steps,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Task, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Task, R>? method<R>(String methodName, [Task? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Task, R>? staticMethod<R>(String methodName) => null;
}

class TaskState$reflection extends EnumReflection<TaskState>
    with __ReflectionMixin {
  static final Expando<TaskState$reflection> _objectReflections = Expando();

  factory TaskState$reflection([TaskState? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= TaskState$reflection._(object);
  }

  TaskState$reflection._([TaskState? object])
    : super(TaskState, r'TaskState', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.10.0');

  @override
  TaskState$reflection withObject([TaskState? obj]) =>
      TaskState$reflection(obj);

  static TaskState$reflection? _withoutObjectInstance;
  @override
  TaskState$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static TaskState$reflection get staticInstance =>
      _withoutObjectInstance ??= TaskState$reflection._();

  @override
  TaskState$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    TaskState$reflection.staticInstance;
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<String> _staticFieldsNames = const <String>[
    'closed',
    'open',
  ];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  static const Map<String, TaskState> _valuesByName = const <String, TaskState>{
    'closed': TaskState.closed,
    'open': TaskState.open,
  };

  @override
  Map<String, TaskState> get valuesByName => _valuesByName;
  @override
  List<TaskState> get values => TaskState.values;

  static const List<String> _fieldsNames = const <String>[];

  @override
  List<String> get fieldsNames => _fieldsNames;
}

class TaskStep$reflection extends ClassReflection<TaskStep>
    with __ReflectionMixin {
  static final Expando<TaskStep$reflection> _objectReflections = Expando();

  factory TaskStep$reflection([TaskStep? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= TaskStep$reflection._(object);
  }

  TaskStep$reflection._([TaskStep? object])
    : super(TaskStep, r'TaskStep', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.10.0');

  @override
  TaskStep$reflection withObject([TaskStep? obj]) =>
      TaskStep$reflection(obj)..setupInternalsWith(this);

  static TaskStep$reflection? _withoutObjectInstance;
  @override
  TaskStep$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static TaskStep$reflection get staticInstance =>
      _withoutObjectInstance ??= TaskStep$reflection._();

  @override
  TaskStep$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    TaskStep$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  TaskStep? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  TaskStep? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  TaskStep? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<TaskStep>> _constructors = {};

  @override
  ConstructorReflection<TaskStep>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<TaskStep>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<TaskStep>(
          this,
          TaskStep,
          '',
          () => TaskStep.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
          invoker: (a) => TaskStep(
            a[0] as String,
            id: identical(a[1], ConstructorReflection.absentArgument)
                ? null
                : a[1] as int?,
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([TaskStep? obj]) => null;

  static const List<String> _fieldsNames = const <String>['id', 'name'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<TaskStep, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<TaskStep, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<TaskStep, T>? field<T>(String fieldName, [TaskStep? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<TaskStep, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<TaskStep, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<TaskStep, T>;
  }

  FieldReflection<TaskStep, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<TaskStep, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<TaskStep, dynamic>? _fieldImpl(
    String fieldName,
    TaskStep? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<TaskStep, int?>(
          this,
          TaskStep,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<TaskStep, String>(
          this,
          TaskStep,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    TaskStep? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<TaskStep, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<TaskStep, R>? method<R>(
    String methodName, [
    TaskStep? obj,
  ]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<TaskStep, R>? staticMethod<R>(String methodName) =>
      null;
}

class Ticket$reflection extends ClassReflection<Ticket> with __ReflectionMixin {
  static final Expando<Ticket$reflection> _objectReflections = Expando();

  factory Ticket$reflection([Ticket? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Ticket$reflection._(object);
  }

  Ticket$reflection._([Ticket? object]) : super(Ticket, r'Ticket', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.10.0');

  @override
  Ticket$reflection withObject([Ticket? obj]) =>
      Ticket$reflection(obj)..setupInternalsWith(this);

  static Ticket$reflection? _withoutObjectInstance;
  @override
  Ticket$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Ticket$reflection get staticInstance =>
      _withoutObjectInstance ??= Ticket$reflection._();

  @override
  Ticket$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Ticket$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Ticket? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Ticket? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Ticket? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Ticket>> _constructors = {};

  @override
  ConstructorReflection<Ticket>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Ticket>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Ticket>(
          this,
          Ticket,
          '',
          () => Ticket.new,
          const <__PR>[__PR(__TR.tString, 'titleText', false, true)],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
          invoker: (a) => Ticket(
            a[0] as String,
            id: identical(a[1], ConstructorReflection.absentArgument)
                ? null
                : a[1] as int?,
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Ticket? obj]) => null;

  static const List<String> _fieldsNames = const <String>['id', 'title'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Ticket, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Ticket, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Ticket, T>? field<T>(String fieldName, [Ticket? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Ticket, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Ticket, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Ticket, T>;
  }

  FieldReflection<Ticket, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Ticket, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Ticket, dynamic>? _fieldImpl(String fieldName, Ticket? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Ticket, int?>(
          this,
          Ticket,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'title':
        return FieldReflection<Ticket, String>(
          this,
          Ticket,
          __TR.tString,
          'title',
          false,
          (o) =>
              () => o!.title,
          (o) =>
              (v) => o!.title = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Ticket? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'title': obj?.title,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Ticket, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Ticket, R>? method<R>(String methodName, [Ticket? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Ticket, R>? staticMethod<R>(String methodName) => null;
}

extension Note$reflectionExtension on Note {
  /// Returns a [ClassReflection] for type [Note]. (Generated by [ReflectionFactory])
  ClassReflection<Note> get reflection => Note$reflection(this);

  /// Returns a JSON for type [Note]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Note]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Note]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Note] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Task$reflectionExtension on Task {
  /// Returns a [ClassReflection] for type [Task]. (Generated by [ReflectionFactory])
  ClassReflection<Task> get reflection => Task$reflection(this);

  /// Returns a JSON for type [Task]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Task]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Task]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Task] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension TaskState$reflectionExtension on TaskState {
  /// Returns a [EnumReflection] for type [TaskState]. (Generated by [ReflectionFactory])
  EnumReflection<TaskState> get reflection => TaskState$reflection(this);

  /// Returns the name of the [TaskState] instance. (Generated by [ReflectionFactory])
  String get enumName => TaskState$reflection(this).name()!;

  /// Returns a JSON for type [TaskState]. (Generated by [ReflectionFactory])
  String? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [TaskState]. (Generated by [ReflectionFactory])
  Map<String, Object>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [TaskState]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);
}

extension TaskStep$reflectionExtension on TaskStep {
  /// Returns a [ClassReflection] for type [TaskStep]. (Generated by [ReflectionFactory])
  ClassReflection<TaskStep> get reflection => TaskStep$reflection(this);

  /// Returns a JSON for type [TaskStep]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [TaskStep]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [TaskStep]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [TaskStep] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Ticket$reflectionExtension on Ticket {
  /// Returns a [ClassReflection] for type [Ticket]. (Generated by [ReflectionFactory])
  ClassReflection<Ticket> get reflection => Ticket$reflection(this);

  /// Returns a JSON for type [Ticket]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Ticket]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Ticket]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Ticket] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  Note$reflection(),
  Task$reflection(),
  TaskState$reflection(),
  TaskStep$reflection(),
  Ticket$reflection(),
];

List<Reflection>? _siblingsReflectionList;
List<Reflection> _siblingsReflection() => _siblingsReflectionList ??=
    List<Reflection>.unmodifiable(_listSiblingsReflection());

bool _registerSiblingsReflectionCalled = false;
void _registerSiblingsReflection() {
  if (_registerSiblingsReflectionCalled) return;
  _registerSiblingsReflectionCalled = true;
  var length = _listSiblingsReflection().length;
  assert(length > 0);
}
