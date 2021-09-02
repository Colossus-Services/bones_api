import 'dart:convert' as dart_convert;

import 'package:collection/collection.dart';
import 'package:reflection_factory/builder.dart';

import 'bones_api_condition.dart';

typedef JsonToEncodable = Object? Function(dynamic object);

typedef JsonReviver = Object? Function(Object? key, Object? value);

abstract class DataEntity {
  V? getID<V>() => getField('id');

  void setID<V>(V id) => setField('id', id);

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
      _getDataHandlerImpl<O>() ?? _globalProvider._getDataHandlerImpl<O>();

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
        type = O {
    if (!isValidType(this.type)) {
      throw StateError('Invalid DataHandler type: $O ?? $type');
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

  Iterable storeSet(Iterable<O> o);
}

abstract class DataRepository<O> extends DataAccessor<O>
    implements DataSource<O>, DataStorage<O> {
  DataRepository(String name) : super(name);

  DataHandler<O>? dataHandler;

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
}

abstract class IterableDataRepository<O> extends DataRepository<O>
    with DataFieldAccessor<O> {
  IterableDataRepository(String name) : super(name);

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
  int store(O o) {
    var oId = getID(o, dataHandler: dataHandler);

    if (oId == null) {
      oId = nextID();
      setID(o, oId, dataHandler: dataHandler);
    }

    put(o);

    return oId;
  }

  @override
  Iterable<int> storeSet(Iterable<O> os) {
    return os.map((o) => store(o)).toList();
  }
}

class SetDataRepository<O> extends IterableDataRepository<O> {
  SetDataRepository(String name) : super(name);

  final Set<O> _entries = <O>{};

  @override
  Iterable<O> iterable() => _entries;

  @override
  int nextID() => _entries.length + 1;

  @override
  void put(O o) {
    _entries.add(o);
  }
}
