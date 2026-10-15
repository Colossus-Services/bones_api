import 'dart:convert' as dart_convert;

import 'package:bones_api/bones_api.dart';
import 'package:bones_api_db_users_benchmark/src/api_entities.dart';
import 'package:mercury_client/mercury_client.dart';

import '../../src/bench_runner.dart';

/// Benchmarks decoding a JSON response of [User]s (each with its [Address]
/// and [Role]s) into entities, as a client does with what `user/list` sends.
///
/// The payload is encoded the way `APIServer` encodes a response
/// (`toEncodable: ReflectionFactory.toJsonEncodable`), so every user carries
/// its full address and roles.
///
/// The `proxy:` benchmark is what a generated `APIModuleProxy` method does
/// with a response body, minus the HTTP request:
/// [APIModuleProxyHttpCaller.decodeJson], then
/// [APIModuleProxyCallerListener.resolveResponse] with the method's return
/// type (`Future<List<User>>`).
///
/// It has no `dart:io` dependency, so it also runs compiled to JavaScript,
/// which is what a browser runs:
///
/// ```
/// dart run bin/json_decode_benchmark.dart
///
/// dart compile js -O2 bin/json_decode_benchmark.dart -o build/json_decode_benchmark.js
/// node build/json_decode_benchmark.js
/// ```
///
/// Options: `--sizes=1,20,100,1000` (users per payload) and `--measure=2000`
/// (milliseconds measured per benchmark). Compiled to JavaScript, `node`
/// doesn't pass them to `main`: it always runs the defaults.
void main(List<String> args) {
  var sizes = _argInts(args, 'sizes') ?? const [1, 20, 100, 1000];
  var measureMs = _argInts(args, 'measure')?.first ?? 2000;

  // Registers the entities' reflection, as an app does before encoding or
  // decoding them (without it they encode as `"Instance of 'User'"`).
  User$reflection.boot();
  Address$reflection.boot();
  Role$reflection.boot();

  var runner = BenchRunner(
    measure: Duration(milliseconds: measureMs),
    warmup: Duration(milliseconds: measureMs ~/ 4),
  );

  var listType = TypeInfo<List<User>>.fromType(List, [User]);

  // No request is made: only the response handling is measured.
  var proxy = APIModuleProxyHttpCaller(HttpClient('http://localhost/'));

  for (var n in sizes) {
    var json = Json.encode(
      _users(n),
      toEncodable: ReflectionFactory.toJsonEncodable,
    );
    var maps = (dart_convert.json.decode(json) as List)
        .cast<Map<String, Object?>>();

    _check(n, json, maps, listType, proxy);

    print('\n## $n users (${json.length} chars)\n');

    // String -> maps, no entities: the floor any decoding pays.
    runner.run(
      '[$n] dart:convert decode',
      () => dart_convert.json.decode(json),
    );

    // Maps -> entities, by hand: the floor of building the objects.
    runner.run(
      '[$n] fromMap (hand-written)',
      () => maps.map(_userFromMap).toList(),
    );

    // Maps -> entities, through reflection_factory alone.
    runner.run(
      '[$n] User\$reflection.fromJson',
      () => maps.map(User$reflection.staticInstance.fromJson).toList(),
    );

    // Maps -> entities, through `Json` (reflection_factory's `JsonDecoder`
    // with the bones_api entity handlers and an entity cache).
    runner.run(
      '[$n] Json.fromJsonList<User>',
      () => Json.fromJsonList<User>(maps, type: User),
    );

    // String -> entities: what a client calls with a response body.
    runner.run(
      '[$n] Json.decode<List<User>>',
      () => Json.decode<List<User>>(json, typeInfo: listType),
    );

    // String -> entities, as an `APIModuleProxy` method resolves a response.
    runner.run(
      '[$n] proxy: decodeJson + resolveResponse',
      () => proxy.resolveResponse(_proxyReturnType, proxy.decodeJson(json)),
    );
  }

  runner.report();
}

/// The return type a generated proxy passes for a `Future<List<User>>`
/// method (see `modules_proxies.g.dart` in an app).
const _proxyReturnType = TypeReflection<Future<List<User>>>(Future, [
  TypeReflection<List<User>>(List, [TypeReflection<User>(User)]),
]);

final _roles = [
  Role('admin', id: 1),
  Role('editor', id: 2),
  Role('user', id: 3),
];

List<User> _users(int n) => List.generate(n, (i) {
  var id = i + 1;
  return User(
    'user$id@example.com',
    'User Name $id',
    'password$id',
    Address('US', 'NY', 'New York', '$id Main Street', '1000$id', id: id),
    [_roles[i % 3], _roles[(i + 1) % 3]],
    id: id,
    enabled: i % 7 != 0,
    creationTime: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
  );
});

User _userFromMap(Map<String, Object?> m) {
  var a = m['address'] as Map<String, Object?>;
  return User.create()
    ..id = m['id'] as int
    ..email = m['email'] as String
    ..name = m['name'] as String
    ..passwordHash = m['passwordHash'] as String
    ..enabled = m['enabled'] as bool
    ..creationTime = DateTime.parse(m['creationTime'] as String)
    ..address = (Address(
      a['countryCode'] as String,
      a['state'] as String,
      a['city'] as String,
      a['addressLine1'] as String,
      a['zipCode'] as String,
      id: a['id'] as int,
    ))
    ..roles = [
      for (var r in (m['roles'] as List).cast<Map<String, Object?>>())
        Role(r['name'] as String, id: r['id'] as int),
    ];
}

/// Fails if any of the measured decoders doesn't give back the users that
/// were encoded: a benchmark of a wrong decode measures nothing.
void _check(
  int n,
  String json,
  List<Map<String, Object?>> maps,
  TypeInfo<List<User>> listType,
  APIModuleProxyHttpCaller proxy,
) {
  var expected = maps.map(_userFromMap).map(_signature).toList();

  var decoded = <String, List<User?>>{
    'User\$reflection.fromJson': maps
        .map(User$reflection.staticInstance.fromJson)
        .toList(),
    'Json.fromJsonList<User>': Json.fromJsonList<User>(maps, type: User),
    'Json.decode<List<User>>': Json.decode<List<User>>(
      json,
      typeInfo: listType,
    ),
    'proxy: decodeJson + resolveResponse':
        (proxy.resolveResponse(_proxyReturnType, proxy.decodeJson(json))
                as List)
            .cast<User?>(),
  };

  for (var MapEntry(key: name, value: users) in decoded.entries) {
    var got = users.map((u) => u == null ? 'null' : _signature(u)).toList();
    if (got.length != n || got.join('\n') != expected.join('\n')) {
      var i = List.generate(n, (i) => i).firstWhere(
        (i) => i >= got.length || got[i] != expected[i],
        orElse: () => n,
      );
      throw StateError(
        '$name decoded a different user #$i:\n'
        '  expected: ${i < n ? expected[i] : '-'}\n'
        '  got:      ${i < got.length ? got[i] : '-'}',
      );
    }
  }
}

String _signature(User u) => [
  u.id,
  u.email,
  u.name,
  u.passwordHash,
  u.enabled,
  u.creationTime.toUtc().toIso8601String(),
  u.address.id,
  u.address.countryCode,
  u.address.state,
  u.address.city,
  u.address.addressLine1,
  u.address.zipCode,
  u.roles.map((r) => '${r.id}:${r.name}').join(','),
].join('|');

List<int>? _argInts(List<String> args, String name) {
  var prefix = '--$name=';
  var arg = args.where((a) => a.startsWith(prefix)).lastOrNull;
  return arg?.substring(prefix.length).split(',').map(int.parse).toList();
}
