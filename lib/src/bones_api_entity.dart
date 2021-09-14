import 'dart:convert' as dart_convert;

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition.dart';
import 'bones_api_mixin.dart';

typedef JsonToEncodable = Object? Function(dynamic object);

typedef JsonReviver = Object? Function(Object? key, Object? value);

abstract class Entity {
  V? getID<V>() => getField('id');

  void setID<V>(V id) => setField('id', id);

  String get idFieldName;

  List<String> get fieldsNames;

  V? getField<V>(String key);

  Type? getFieldType(String key);

  void setField<V>(String key, V? value);

  Map<String, dynamic> toJson();

  String toJsonEncoded() => dart_convert.json.encode(toJson());
}

class EntityHandlerProvider {
  static final EntityHandlerProvider _globalProvider = EntityHandlerProvider();

  static EntityHandlerProvider get globalProvider => _globalProvider;

  final Map<Type, EntityHandler> _entityHandlers = <Type, EntityHandler>{};

  void _register<O>(EntityHandler<O> entityHandler) {
    _entityHandlers[entityHandler.type] = entityHandler;
  }

  EntityHandler<O>? getEntityHandler<O>({O? obj, Type? type}) =>
      _getEntityHandlerImpl<O>(obj: obj, type: type) ??
      _globalProvider._getEntityHandlerImpl<O>(obj: obj, type: type);

  EntityHandler<O>? _getEntityHandlerImpl<O>({O? obj, Type? type}) {
    var entityHandler = _entityHandlers[O];

    if (entityHandler == null && obj != null) {
      entityHandler = _entityHandlers[obj.runtimeType];
    }

    if (entityHandler == null && type != null) {
      entityHandler = _entityHandlers[type];
    }

    return entityHandler as EntityHandler<O>?;
  }
}

abstract class EntityHandler<O> with FieldsFromMap {
  final EntityHandlerProvider provider;
  final Type type;

  EntityHandler(EntityHandlerProvider? provider, {Type? type})
      : provider = provider ?? EntityHandlerProvider.globalProvider,
        type = type ?? O {
    if (!isValidType(this.type)) {
      throw StateError('Invalid EntityHandler type: $type ?? $O');
    }

    this.provider._register(this);

    _jsonReviver = _defaultJsonReviver;
  }

  static bool isValidType<T>([Type? type]) {
    type ??= T;
    return type != Object && type != dynamic && !isPrimitiveType(type);
  }

  static bool isPrimitiveType<T>([Type? type]) {
    type ??= T;
    return type == String ||
        type == int ||
        type == double ||
        type == num ||
        type == bool;
  }

  EntityHandler<T>? getEntityHandler<T>({T? obj, Type? type}) {
    if (T == O && isValidType<T>()) {
      return this as EntityHandler<T>;
    } else if (obj != null && obj.runtimeType == O && isValidType<O>()) {
      return this as EntityHandler<T>;
    } else if (type != null && type == O && isValidType<O>()) {
      return this as EntityHandler<T>;
    } else {
      return provider.getEntityHandler<T>(obj: obj, type: type);
    }
  }

  V? getID<V>(O o) => getField(o, 'id');

  void setID<V>(O o, V id) => setField(o, 'id', id);

  String idFieldsName([O? o]);

  List<String> fieldsNames([O? o]);

  Map<String, int>? _fieldsNamesIndexes;

  Map<String, int> fieldsNamesIndexes([O? o]) {
    if (_fieldsNamesIndexes == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesIndexes = buildFieldsNamesIndexes(fieldsNames);
    }
    return _fieldsNamesIndexes!;
  }

  List<String>? _fieldsNamesLC;

  List<String> fieldsNamesLC([O? o]) {
    if (_fieldsNamesLC == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesLC = buildFieldsNamesLC(fieldsNames);
    }
    return _fieldsNamesLC!;
  }

  List<String>? _fieldsNamesSimple;

  List<String> fieldsNamesSimple([O? o]) {
    if (_fieldsNamesSimple == null) {
      var fieldsNames = this.fieldsNames(o);
      _fieldsNamesSimple = buildFieldsNamesSimple(fieldsNames);
    }
    return _fieldsNamesSimple!;
  }

  Type? getFieldType(O o, String key);

  V? getField<V>(O o, String key);

  Map<String, dynamic> getFields(O o) {
    return Map<String, dynamic>.fromEntries(fieldsNames(o)
        .map((key) => MapEntry<String, dynamic>(key, getField(o, key))));
  }

  void setField<V>(O o, String key, V? value);

  bool trySetField<V>(O o, String key, V? value) {
    try {
      setField(o, key, value);
      return true;
    } catch (e) {
      return false;
    }
  }

  late JsonReviver _jsonReviver;

  JsonReviver get jsonReviver => _jsonReviver;

  set jsonReviver(JsonReviver? value) {
    _jsonReviver = value ?? _defaultJsonReviver;
  }

  Object? _defaultJsonReviver(Object? key, Object? value) {
    if (key != null) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      return createFromMap(value);
    }

    return value;
  }

  O decodeObjectJson(String json) =>
      dart_convert.json.decode(json, reviver: jsonReviver);

  List<O> decodeObjectListJson(String json) {
    var itr =
        dart_convert.json.decode(json, reviver: jsonReviver) as Iterable<O>;
    return itr is List<O> ? itr : itr.toList();
  }

  dynamic decodeJson(String json) =>
      dart_convert.json.decode(json, reviver: jsonReviver);

  JsonToEncodable? jsonToEncodable;

  String encodeObjectJson(O o) =>
      dart_convert.json.encode(o, toEncodable: jsonToEncodable);

  String encodeObjectListJson(Iterable<O> o) =>
      dart_convert.json.encode(o.toList(), toEncodable: jsonToEncodable);

  String encodeJson(dynamic o) =>
      dart_convert.json.encode(o, toEncodable: jsonToEncodable);

  FutureOr<O> createFromMap(Map<String, dynamic> fields);

  FutureOr<O> setFieldsFromMap(O o, Map<String, dynamic> fields) {
    var fieldsNames = this.fieldsNames(o);

    var fieldsValues = getFieldsValuesFromMap(fieldsNames, fields,
        fieldsNamesIndexes: fieldsNamesIndexes(o),
        fieldsNamesLC: fieldsNamesLC(o),
        fieldsNamesSimple: fieldsNamesSimple(o));

    var setFutures = fieldsValues.entries.map((e) {
      return setFieldValueDynamic(o, e.key, e.value).resolveWithValue(true);
    });

    return setFutures.resolveAllWithValue(o);
  }

  FutureOr<dynamic> setFieldValueDynamic(O o, String key, dynamic value) {
    if (value == null) {
      return null;
    }

    var fieldType = getFieldType(o, key);

    if (fieldType == null ||
        fieldType == value.runtimeType ||
        isPrimitiveType(fieldType)) {
      setField(o, key, value);
      return value;
    } else if (value is Map && fieldType == Map) {
      setField(o, key, value);
      return value;
    } else if (value is Map<String, dynamic>) {
      var valEntityHandler = getEntityHandler(type: fieldType);
      valEntityHandler ??= getEntityRepository(type: fieldType)?.entityHandler;

      if (valEntityHandler != null) {
        var valEntity = valEntityHandler.createFromMap(value);
        setField(o, key, valEntity);
        return valEntity;
      } else {
        setField(o, key, value);
        return value;
      }
    } else {
      var valRepo = getEntityRepository(type: fieldType);
      var retValDynamic = valRepo?.selectByID(value);

      return retValDynamic.resolveMapped((valDynamic) {
        valDynamic ??= value;
        setField(o, key, valDynamic);
        return valDynamic;
      });
    }
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    _knownEntityRepositoryProviders.add(provider);
  }

  EntityRepository<T>? getEntityRepository<T>(
      {T? obj, Type? type, String? name}) {
    for (var provider in _knownEntityRepositoryProviders) {
      var repository =
          provider.getEntityRepository(obj: obj, type: type, name: name);
      if (repository != null) {
        return repository;
      }
    }

    return EntityRepositoryProvider.globalProvider
        .getEntityRepository<T>(obj: obj, type: type, name: name);
  }
}

typedef InstantiatorDefault<O> = FutureOr<O> Function();

typedef InstantiatorFromMap<O> = FutureOr<O> Function(Map<String, dynamic>);

class GenericEntityHandler<O extends Entity> extends EntityHandler<O> {
  final InstantiatorDefault<O>? instantiatorDefault;

  final InstantiatorFromMap<O>? instantiatorFromMap;

  GenericEntityHandler(
      {this.instantiatorDefault,
      this.instantiatorFromMap,
      Type? type,
      O? sampleEntity,
      EntityHandlerProvider? provider})
      : super(provider, type: type ?? O) {
    if (instantiatorDefault == null && instantiatorFromMap == null) {
      throw ArgumentError(
          "Null instantiators: `instantiatorDefault`, `instantiatorFromMap`");
    }

    if (sampleEntity != null) {
      _populate(sampleEntity);
    }
  }

  String? _idFieldsName;

  @override
  String idFieldsName([O? o]) {
    var idFieldsName = _idFieldsName;

    if (idFieldsName == null && o != null) {
      idFieldsName = _idFieldsName = o.idFieldName;
    }

    if (idFieldsName == null) {
      throw StateError(
          "`idFieldsName` Not populated yet! No Entity instance presented to this EntityHandler yet.");
    }

    return idFieldsName;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) {
    var fieldsNames = _fieldsNames;

    if (fieldsNames == null && o != null) {
      _populate(o);
      fieldsNames = _fieldsNames;
    }

    if (fieldsNames == null) {
      throw StateError(
          "`fieldsNames` Not populated yet! No Entity instance presented to this EntityHandler yet.");
    }

    return fieldsNames;
  }

  void _populate(O o) {
    _idFieldsName ??= o.idFieldName;
    _fieldsNames ??= List<String>.unmodifiable(o.fieldsNames);
  }

  @override
  String encodeObjectJson(O o) {
    _populate(o);
    return super.encodeObjectJson(o);
  }

  @override
  V? getID<V>(O o) {
    _populate(o);
    return o.getID();
  }

  @override
  void setID<V>(O o, V id) {
    _populate(o);
    o.setID(id);
  }

  @override
  V? getField<V>(O o, String key) {
    _populate(o);
    return o.getField<V>(key);
  }

  @override
  Type? getFieldType(O o, String key) {
    _populate(o);
    return o.getFieldType(key);
  }

  @override
  void setField<V>(O o, String key, V? value) {
    _populate(o);
    return o.setField<V>(key, value);
  }

  @override
  FutureOr<O> createFromMap(Map<String, dynamic> fields) {
    if (instantiatorFromMap != null) {
      return instantiatorFromMap!(fields);
    } else {
      var oRet = instantiatorDefault!();
      return oRet.resolveMapped((o) => setFieldsFromMap(o, fields));
    }
  }
}

class ClassReflectionEntityHandler<O> extends EntityHandler<O> {
  Type classType;

  ClassReflection<O>? _reflection;

  ClassReflectionEntityHandler(this.classType,
      {EntityHandlerProvider? provider, ClassReflection<O>? reflection})
      : _reflection = reflection,
        super(provider);

  ClassReflection<O> get reflection {
    _reflection ??=
        ReflectionFactory().getRegisterClassReflection<O>(classType);
    return _reflection!;
  }

  @override
  V? getField<V>(O o, String key) => reflection.getField(key, o);

  @override
  Type? getFieldType(O o, String key) {
    var field = reflection.field(key, o);
    return field?.type.type;
  }

  @override
  void setField<V>(O o, String key, V? value) =>
      reflection.setField(key, value, o);

  @override
  bool trySetField<V>(O o, String key, V? value) {
    var field = reflection.field<V>(key, o);
    if (field == null) return false;

    if (value == null) {
      if (field.nullable) {
        field.set(value);
        return true;
      } else {
        return false;
      }
    }

    if (field.type.type == value.runtimeType) {
      field.set(value);
      return true;
    } else {
      return false;
    }
  }

  String? _idFieldsName;

  @override
  String idFieldsName([O? o]) {
    if (_idFieldsName == null) {
      // Just to populate:
      if (_fieldsNames == null) {
        fieldsNames(o);
      }

      var fieldName = findIdFieldName();
      _idFieldsName = fieldName ?? 'id';
    }
    return _idFieldsName!;
  }

  String? findIdFieldName() {
    var possibleFields = reflection.fieldsWhere((f) {
      return f.type.isPrimitiveType;
    }).toList();

    if (possibleFields.isEmpty) {
      throw StateError(
          "Class without candidate for ID field: ${fieldsNames()}");
    }

    if (possibleFields.length == 1) {
      return possibleFields.first.name;
    }

    possibleFields.sort((a, b) {
      var n1 = a.nullable;
      var n2 = b.nullable;
      return n1 == n2 ? 0 : (n1 ? -1 : 1);
    });

    var idField = possibleFields.firstWhereOrNull((f) {
      var name = f.name.toLowerCase();
      return name == 'id' || name == 'key' || name == 'primary';
    });

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.type.isNumericType);

    if (idField != null) {
      return idField.name;
    }

    idField = possibleFields.firstWhereOrNull((f) => f.nullable);

    if (idField != null) {
      return idField.name;
    }

    return null;
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) => _fieldsNames ??= reflection.fieldsNames;

  @override
  FutureOr<O> createFromMap(Map<String, dynamic> fields) {
    var o = reflection.createInstance()!;
    return setFieldsFromMap(o, fields);
  }
}

mixin EntityFieldAccessor<O> {
  dynamic getID(O o, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getID();
    } else if (entityHandler != null) {
      return entityHandler.getID(o);
    } else {
      throw StateError('getID: No EntityHandler provided for: $o');
    }
  }

  void setID(O o, Object id, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.setID(id);
    } else if (entityHandler != null) {
      return entityHandler.setID(o, id);
    } else {
      throw StateError('setID: No EntityHandler provided for: $o');
    }
  }

  dynamic getField(O o, String key, {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      return o.getField(key);
    } else if (entityHandler != null) {
      return entityHandler.getField(o, key);
    } else {
      throw StateError('getField($key): No EntityHandler provided for: $o');
    }
  }

  void setField(O o, String key, Object? value,
      {EntityHandler<O>? entityHandler}) {
    if (o is Entity) {
      o.setField(key, value);
    } else if (entityHandler != null) {
      entityHandler.setField(o, key, value);
    } else {
      throw StateError('setField($key): No EntityHandler provided for: $o');
    }
  }
}

class EntityFieldAccessorGeneric<O> with EntityFieldAccessor<O> {}

abstract class EntityAccessor<O> {
  final String name;

  EntityAccessor(this.name);
}

abstract class EntitySource<O> extends EntityAccessor<O> {
  EntitySource(String name) : super(name);

  FutureOr<O?> selectByID(dynamic id) {
    return select(ConditionID(id)).resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    });
  }

  FutureOr<int> length() => count();

  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});

  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  FutureOr<Iterable<O>> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});

  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});
}

abstract class EntityStorage<O> extends EntityAccessor<O> {
  EntityStorage(String name) : super(name);

  FutureOr<dynamic> store(O o);

  FutureOr<Iterable> storeAll(Iterable<O> o);
}

class EntityRepositoryProvider {
  static final EntityRepositoryProvider _globalProvider =
      EntityRepositoryProvider();

  static EntityRepositoryProvider get globalProvider => _globalProvider;

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  void registerEntityRepository<O>(EntityRepository<O> entityRepository) {
    _entityRepositories[entityRepository.type] = entityRepository;
  }

  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  EntityRepository<O>? getEntityRepository<O>(
      {O? obj, Type? type, String? name}) {
    var entityRepository =
        _getEntityRepositoryImpl<O>(obj: obj, type: type, name: name);
    if (entityRepository != null) {
      return entityRepository;
    }

    if (!identical(this, _globalProvider)) {
      return _globalProvider._getEntityRepositoryImpl<O>(
          obj: obj, type: type, name: name);
    }

    return null;
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O>(
      {O? obj, Type? type, String? name}) {
    var entityRepository = _entityRepositories[O];

    if (entityRepository == null && obj != null) {
      entityRepository = _entityRepositories[obj.runtimeType];
    }

    if (entityRepository == null && type != null) {
      entityRepository = _entityRepositories[type];
    }

    if (entityRepository != null) {
      return entityRepository as EntityRepository<O>;
    }

    if (name != null) {
      entityRepository =
          _entityRepositories.values.where((e) => e.name == name).firstOrNull;
      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      }
    }

    for (var p in _knownEntityRepositoryProviders) {
      entityRepository =
          p.getEntityRepository<O>(obj: obj, type: type, name: name);
      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      }
    }

    return null;
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    _knownEntityRepositoryProviders.add(provider);
  }
}

abstract class EntityRepository<O> extends EntityAccessor<O>
    with Initializable
    implements EntitySource<O>, EntityStorage<O> {
  final EntityRepositoryProvider provider;

  final EntityHandler<O> entityHandler;
  final Type type;

  EntityRepository(
      EntityRepositoryProvider? provider, String name, this.entityHandler,
      {Type? type})
      : provider = provider ?? EntityRepositoryProvider.globalProvider,
        type = type ?? O,
        super(name) {
    if (!EntityHandler.isValidType(this.type)) {
      throw StateError('Invalid EntityRepository type: $type ?? $O');
    }

    this.provider.registerEntityRepository(this);

    entityHandler.notifyKnownEntityRepositoryProvider(this.provider);
  }

  @override
  FutureOr<O?> selectByID(dynamic id) {
    return select(ConditionID(id)).resolveMapped((sel) {
      return sel.isNotEmpty ? sel.first : null;
    });
  }

  dynamic ensureStored(O o);

  void ensureReferencesStored(O o);

  @override
  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  @override
  FutureOr<int> countByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return count(
        matcher: condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  FutureOr<Iterable<O>> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  @override
  FutureOr<Iterable<O>> deleteByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return delete(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  Map<String, dynamic> information();

  @override
  String toString() {
    var info = information();
    return 'EntityRepository{ name: $name, provider: $provider, type: $type, information: $info }';
  }
}

abstract class IterableEntityRepository<O> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  IterableEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(provider, name, entityHandler);

  Iterable<O> iterable();

  dynamic nextID();

  void put(O o);

  void remove(O o);

  @override
  FutureOr<int> count(
      {EntityMatcher<O>? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (matcher == null) {
      return iterable().length;
    }

    return iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    }).length;
  }

  @override
  Iterable<O> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return matches(matcher, parameters, positionalParameters, namedParameters);
  }

  @override
  O? selectByID(id) {
    return iterable().firstWhereOrNull((o) {
      var oId = getID(o, entityHandler: entityHandler);
      return oId == id;
    });
  }

  @override
  dynamic store(O o) {
    ensureReferencesStored(o);

    var oId = getID(o, entityHandler: entityHandler);

    if (oId == null) {
      oId = nextID();
      setID(o, oId, entityHandler: entityHandler);
      put(o);
    }

    return oId;
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }

  @override
  dynamic ensureStored(O o) {
    ensureReferencesStored(o);

    var id = getID(o, entityHandler: entityHandler);

    if (id == null) {
      return store(o);
    } else {
      return id;
    }
  }

  @override
  void ensureReferencesStored(O o) {
    for (var fieldName in entityHandler.fieldsNames(o)) {
      var value = entityHandler.getField(o, fieldName);
      if (value == null) {
        continue;
      }

      var repository = provider.getEntityRepository(obj: value);
      if (repository == null) {
        continue;
      }

      repository.ensureStored(value);
    }
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var del =
        matches(matcher, parameters, positionalParameters, namedParameters);

    for (var o in del) {
      remove(o);
    }

    return del;
  }

  List<O> matches(EntityMatcher<dynamic> matcher, Object? parameters,
      List? positionalParameters, Map<String, Object?>? namedParameters) {
    return iterable().where((o) {
      return matcher.matchesEntity(
        o,
        entityHandler: entityHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    }).toList();
  }

  @override
  Map<String, dynamic> information() => {
        'length': length(),
        'nextID': nextID(),
      };
}

class SetEntityRepository<O> extends IterableEntityRepository<O> {
  SetEntityRepository(String name, EntityHandler<O> entityHandler,
      {EntityRepositoryProvider? provider})
      : super(name, entityHandler, provider: provider);

  final Set<O> _entries = <O>{};

  @override
  Iterable<O> iterable() => _entries;

  @override
  int nextID() => _entries.length + 1;

  @override
  int length() => _entries.length;

  @override
  void put(O o) {
    _entries.add(o);
  }

  @override
  void remove(O o) {
    _entries.remove(o);
  }
}
