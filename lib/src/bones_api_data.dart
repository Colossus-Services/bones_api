import 'dart:convert' as dart_convert;

import 'package:collection/collection.dart';
import 'package:reflection_factory/builder.dart';

import 'bones_api_condition.dart';

typedef JsonToEncodable = Object? Function(dynamic object);

typedef JsonReviver = Object? Function(Object? key, Object? value);

abstract class DataEntity {
  V? getID<V>() => getField('id');

  void setID<V>(V id) => setField('id', id);

  List<String> get fieldsNames;

  V? getField<V>(String key);

  void setField<V>(String key, V? value);

  Map<String, dynamic> toJson();

  String toJsonEncoded() => dart_convert.json.encode(toJson());
}

class DataHandlerProvider {
  static final DataHandlerProvider _globalProvider = DataHandlerProvider();

  static DataHandlerProvider get globalProvider => _globalProvider;

  final Map<Type, DataHandler> _dataHandlers = <Type, DataHandler>{};

  void _register<O>(DataHandler<O> dataHandler) {
    _dataHandlers[dataHandler.type] = dataHandler;
  }

  DataHandler<O>? getDataHandler<O>([O? o]) =>
      _getDataHandlerImpl<O>(o) ?? _globalProvider._getDataHandlerImpl<O>(o);

  DataHandler<O>? _getDataHandlerImpl<O>([O? o]) {
    var dataHandler = _dataHandlers[O];
    if (dataHandler == null && o != null) {
      dataHandler = _dataHandlers[o.runtimeType];
    }
    return dataHandler as DataHandler<O>?;
  }
}

abstract class DataHandler<O> {
  final DataHandlerProvider provider;
  final Type type;

  DataHandler(DataHandlerProvider? provider, {Type? type})
      : provider = provider ?? DataHandlerProvider.globalProvider,
        type = type ?? O {
    if (!isValidType(this.type)) {
      throw StateError('Invalid DataHandler type: $type ?? $O');
    }

    this.provider._register(this);
  }

  static bool isValidType<T>([Type? type]) {
    type ??= T;
    return type != Object &&
        type != dynamic &&
        type != String &&
        type != int &&
        type != double &&
        type != num &&
        type != bool;
  }

  DataHandler<T>? getDataHandler<T>([T? o]) {
    if (T == O && isValidType<T>()) {
      return this as DataHandler<T>;
    } else if (o != null && o.runtimeType == O && isValidType<O>()) {
      return this as DataHandler<T>;
    } else {
      return provider.getDataHandler<T>(o);
    }
  }

  V? getID<V>(O o) => getField(o, 'id');

  void setID<V>(O o, V id) => setField(o, 'id', id);

  List<String> fieldsNames([O? o]);

  V? getField<V>(O o, String key);

  void setField<V>(O o, String key, V? value);

  JsonReviver? jsonReviver;

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
}

class EntityDataHandler<O extends DataEntity> extends DataHandler<O> {
  EntityDataHandler(
      {Type? type, O? sampleEntity, DataHandlerProvider? provider})
      : super(provider, type: type ?? O) {
    if (sampleEntity != null) {
      _populateFieldsNames(sampleEntity);
    }
  }

  List<String>? _fieldsNames;

  @override
  List<String> fieldsNames([O? o]) {
    var fieldsNames = _fieldsNames;

    if (fieldsNames == null && o != null) {
      _populateFieldsNames(o);
      fieldsNames = _fieldsNames;
    }

    if (fieldsNames == null) {
      throw StateError(
          "`fieldsNames` Not populated yet! No DataEntity instances presented to this EntityDataHandler yet.");
    }

    return fieldsNames;
  }

  void _populateFieldsNames(O o) {
    _fieldsNames ??= o.fieldsNames;
  }

  @override
  String encodeObjectJson(O o) {
    _populateFieldsNames(o);
    return super.encodeObjectJson(o);
  }

  @override
  V? getID<V>(O o) {
    _populateFieldsNames(o);
    return o.getID();
  }

  @override
  void setID<V>(O o, V id) {
    _populateFieldsNames(o);
    o.setID(id);
  }

  @override
  V? getField<V>(O o, String key) {
    _populateFieldsNames(o);
    return o.getField<V>(key);
  }

  @override
  void setField<V>(O o, String key, V? value) {
    _populateFieldsNames(o);
    return o.setField<V>(key, value);
  }
}

class ClassReflectionDataHandler<O> extends DataHandler<O> {
  Type classType;

  ClassReflection<O>? _reflection;

  ClassReflectionDataHandler(this.classType,
      {DataHandlerProvider? provider, ClassReflection<O>? reflection})
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
  void setField<V>(O o, String key, V? value) =>
      reflection.setField(key, value, o);

  @override
  List<String> fieldsNames([O? o]) => reflection.fieldsNames;
}

mixin DataFieldAccessor<O> {
  dynamic getID(O o, {DataHandler<O>? dataHandler}) {
    if (o is DataEntity) {
      return o.getID();
    } else if (dataHandler != null) {
      return dataHandler.getID(o);
    } else {
      throw StateError('getID: No DataHandler provided for: $o');
    }
  }

  void setID(O o, Object id, {DataHandler<O>? dataHandler}) {
    if (o is DataEntity) {
      return o.setID(id);
    } else if (dataHandler != null) {
      return dataHandler.setID(o, id);
    } else {
      throw StateError('setID: No DataHandler provided for: $o');
    }
  }

  dynamic getField(O o, String key, {DataHandler<O>? dataHandler}) {
    if (o is DataEntity) {
      return o.getField(key);
    } else if (dataHandler != null) {
      return dataHandler.getField(o, key);
    } else {
      throw StateError('getField($key): No DataHandler provided for: $o');
    }
  }

  void setField(O o, String key, Object? value, {DataHandler<O>? dataHandler}) {
    if (o is DataEntity) {
      o.setField(key, value);
    } else if (dataHandler != null) {
      dataHandler.setField(o, key, value);
    } else {
      throw StateError('setField($key): No DataHandler provided for: $o');
    }
  }
}

class DataFieldAccessorGeneric<O> with DataFieldAccessor<O> {}

abstract class DataAccessor<O> {
  final String name;

  DataAccessor(this.name);
}

abstract class DataSource<O> extends DataAccessor<O> {
  DataSource(String name) : super(name);

  O? selectByID(dynamic id) {
    var ret = select(IDCondition(id));
    return ret.isNotEmpty ? ret.first : null;
  }

  int length();

  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  Iterable<O> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  Iterable<O> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters});
}

abstract class DataStorage<O> extends DataAccessor<O> {
  DataStorage(String name) : super(name);

  dynamic store(O o);

  Iterable storeAll(Iterable<O> o);
}

class DataRepositoryProvider {
  static final DataRepositoryProvider _globalProvider =
      DataRepositoryProvider();

  static DataRepositoryProvider get globalProvider => _globalProvider;

  final Map<Type, DataRepository> _dataRepositories = <Type, DataRepository>{};

  void _register<O>(DataRepository<O> dataRepository) {
    _dataRepositories[dataRepository.type] = dataRepository;
  }

  DataRepository<O>? getDataRepository<O>([O? o]) =>
      _getDataRepositoryImpl<O>(o) ??
      _globalProvider._getDataRepositoryImpl<O>(o);

  DataRepository<O>? _getDataRepositoryImpl<O>([O? o]) {
    var dataRepository = _dataRepositories[O];
    if (dataRepository == null && o != null) {
      dataRepository = _dataRepositories[o.runtimeType];
    }
    return dataRepository as DataRepository<O>?;
  }
}

abstract class DataRepository<O> extends DataAccessor<O>
    implements DataSource<O>, DataStorage<O> {
  final DataRepositoryProvider provider;

  final DataHandler<O> dataHandler;
  final Type type;

  DataRepository(
      DataRepositoryProvider? provider, String name, this.dataHandler,
      {Type? type})
      : provider = provider ?? DataRepositoryProvider.globalProvider,
        type = type ?? O,
        super(name) {
    if (!DataHandler.isValidType(this.type)) {
      throw StateError('Invalid DataRepository type: $type ?? $O');
    }

    this.provider._register(this);
  }

  bool _initialized = false;

  void ensureInitialized() {
    if (_initialized) {
      return;
    }

    _initialized = true;

    initialize();
  }

  void initialize() {}

  dynamic ensureStored(O o);

  void ensureReferencesStored(O o);

  @override
  final ConditionParseCache<O> _parseCache = ConditionParseCache.get<O>();

  @override
  Iterable<O> selectByQuery(String query,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var condition = _parseCache.parseQuery(query);

    return select(condition,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);
  }

  Map<String, dynamic> information();

  @override
  String toString() {
    var info = information();
    return 'DataRepository{ name: $name, provider: $provider, type: $type, information: $info }';
  }
}

abstract class IterableDataRepository<O> extends DataRepository<O>
    with DataFieldAccessor<O> {
  IterableDataRepository(String name, DataHandler<O> dataHandler,
      {DataRepositoryProvider? provider})
      : super(provider, name, dataHandler);

  Iterable<O> iterable();

  dynamic nextID();

  void put(O o);

  @override
  Iterable<O> select(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return iterable().where((o) {
      return matcher.matches(
        o,
        dataHandler: dataHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      );
    }).toList();
  }

  @override
  O? selectByID(id) {
    return iterable().firstWhereOrNull((o) {
      var oId = getID(o, dataHandler: dataHandler);
      return oId == id;
    });
  }

  @override
  dynamic store(O o) {
    var oId = getID(o, dataHandler: dataHandler);

    if (oId == null) {
      oId = nextID();
      setID(o, oId, dataHandler: dataHandler);
    }

    put(o);

    ensureReferencesStored(o);

    return oId;
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }

  @override
  dynamic ensureStored(O o) {
    var id = getID(o, dataHandler: dataHandler);

    if (id == null) {
      return store(o);
    }

    return null;
  }

  @override
  void ensureReferencesStored(O o) {
    for (var fieldName in dataHandler.fieldsNames(o)) {
      var value = dataHandler.getField(o, fieldName);
      if (value == null) {
        continue;
      }

      var repository = provider.getDataRepository(value);
      if (repository == null) {
        continue;
      }

      repository.ensureStored(value);
    }
  }

  @override
  Map<String, dynamic> information() => {
        'length': length(),
        'nextID': nextID(),
      };
}

class SetDataRepository<O> extends IterableDataRepository<O> {
  SetDataRepository(String name, DataHandler<O> dataHandler,
      {DataRepositoryProvider? provider})
      : super(name, dataHandler, provider: provider);

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
}
