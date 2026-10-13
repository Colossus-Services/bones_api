@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_entity_db_object_gcs.dart';
import 'package:crclib/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// An in-memory fake of the Google Cloud Storage JSON API (the requests of
/// `package:gcloud`), for a [DBObjectGCSAdapter].
class _FakeGCS {
  final String bucket;

  _FakeGCS(this.bucket);

  /// The stored objects, by name.
  final Map<String, Uint8List> objects = {};

  /// The object names whose media read fails (a 5xx response).
  final Set<String> failingReads = {};

  final List<String> requests = [];

  late final MockClient client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    var url = request.url;
    requests.add('${request.method} ${url.path}?${url.query}');

    var path = url.path;
    var objectsPrefix = '/storage/v1/b/$bucket/o';
    var downloadPrefix = '/download$objectsPrefix';
    var uploadPrefix = '/upload$objectsPrefix';

    if (request.method == 'POST' && path == uploadPrefix) {
      return _upload(request);
    }

    if (path.startsWith(downloadPrefix) || path.startsWith(objectsPrefix)) {
      var rest = path.startsWith(downloadPrefix)
          ? path.substring(downloadPrefix.length)
          : path.substring(objectsPrefix.length);

      if (rest.isEmpty || rest == '/') {
        return _list(url.queryParameters['prefix'] ?? '');
      }

      var name = Uri.decodeComponent(rest.substring(1));

      if (request.method == 'DELETE') {
        var removed = objects.remove(name);
        return removed == null ? _notFound() : http.Response('', 204);
      }

      var media =
          url.queryParameters['alt'] == 'media' ||
          path.startsWith(downloadPrefix);

      if (media && failingReads.contains(name)) {
        return _json({
          'error': {'code': 503, 'message': 'Service Unavailable'},
        }, status: 503);
      }

      var data = objects[name];
      if (data == null) return _notFound();

      return media
          ? http.Response.bytes(
              data,
              200,
              headers: {
                'content-type': 'application/json',
                'content-length': '${data.length}',
              },
            )
          : _json(_objectInfo(name, data));
    }

    return http.Response('Unexpected request: ${request.url}', 400);
  }

  http.Response _upload(http.Request request) {
    var contentType = request.headers['content-type'] ?? '';
    var boundary = RegExp(
      r'boundary="?([^";]+)"?',
    ).firstMatch(contentType)![1]!;

    var body = latin1.decode(request.bodyBytes);
    var parts = body
        .split('--$boundary')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '--')
        .toList();

    String partBody(String part) {
      var idx = part.indexOf('\r\n\r\n');
      return part.substring(idx + 4).trim();
    }

    var metadata = json.decode(partBody(parts[0])) as Map<String, dynamic>;
    var name = metadata['name'] as String;

    var mediaPart = parts[1];
    var mediaBody = partBody(mediaPart);
    var bytes = mediaPart.toLowerCase().contains('base64')
        ? base64.decode(mediaBody.replaceAll(RegExp(r'\s'), ''))
        : latin1.encode(mediaBody);

    objects[name] = Uint8List.fromList(bytes);

    return _json(_objectInfo(name, objects[name]!));
  }

  http.Response _list(String prefix) => _json({
    'kind': 'storage#objects',
    'items': [
      for (var e in objects.entries)
        if (e.key.startsWith(prefix)) _objectInfo(e.key, e.value),
    ],
  });

  Map<String, dynamic> _objectInfo(String name, Uint8List data) {
    var crc = Crc32C().convert(data).toBigInt().toInt();
    var crcBytes = Uint8List(4)..buffer.asByteData().setUint32(0, crc);
    return {
      'kind': 'storage#object',
      'bucket': bucket,
      'name': name,
      'size': '${data.length}',
      'crc32c': base64.encode(crcBytes),
      'md5Hash': base64.encode(Uint8List(16)),
      'contentType': 'application/json',
      'generation': '1',
      'metageneration': '1',
      'updated': DateTime.utc(2020).toIso8601String(),
    };
  }

  http.Response _notFound() => _json({
    'error': {'code': 404, 'message': 'Not Found'},
  }, status: 404);

  http.Response _json(Object o, {int status = 200}) => http.Response(
    json.encode(o),
    status,
    headers: {'content-type': 'application/json'},
  );
}

class _GCSProvider extends DBEntityRepositoryProvider<DBObjectGCSAdapter> {
  final _FakeGCS gcs;

  _GCSProvider(this.gcs);

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBObjectGCSAdapter> buildAdapter() => DBObjectGCSAdapter(
    gcs.client,
    'cov-project',
    gcs.bucket,
    parentRepositoryProvider: this,
  );

  @override
  List<EntityRepository<Object>> buildRepositories(
    DBObjectGCSAdapter adapter,
  ) => [
    DBEntityRepository<Store>(
      adapter,
      'store',
      Store$reflection().entityHandler,
    ),
    DBEntityRepository<Role>(adapter, 'role', Role$reflection().entityHandler),
  ];

  DBEntityRepository<Store> get storeRepo =>
      getEntityRepositoryByType(Store) as DBEntityRepository<Store>;

  DBEntityRepository<Role> get roleRepo =>
      getEntityRepositoryByType(Role) as DBEntityRepository<Role>;
}

void main() {
  group('DBObjectGCSAdapter (fake GCS)', () {
    late _FakeGCS gcs;
    late _GCSProvider provider;

    setUp(() async {
      gcs = _FakeGCS('cov-bucket');
      provider = _GCSProvider(gcs);
      await provider.ensureInitialized();
    });

    tearDown(() => provider.close());

    // The stored object (in the bucket), its data fields:
    Map<String, dynamic>? stored(String file) {
      var bytes = gcs.objects[file];
      if (bytes == null) return null;
      var o = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      return {
        for (var k in ['id', 'name', 'number'])
          if (o.containsKey(k)) k: o[k],
      };
    }

    test('store: insert, multiple and partial updates', () async {
      var storeRepo = provider.storeRepo;

      // Insert:
      var s = Store('g1', 1, id: 901);
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g1', 'number': 1});

      // A partial update (only `name`): `number` kept.
      s.name = 'g2';
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 1});

      // A partial update (only `number`): `name` kept.
      s.number = 2;
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 2});

      // Unchanged:
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 2});

      // Another instance with the same ID (an updated copy):
      expect(await storeRepo.store(Store('g3', 3, id: 901)), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g3', 'number': 3});

      // Read back (a new instance):
      var s2 = (await storeRepo.selectByID(901))!;
      expect(s2, isNot(same(s)));
      expect(s2.name, equals('g3'));
      expect(s2.number, equals(3));

      expect(await storeRepo.count(), equals(1));
      expect(await storeRepo.existsID(901), isTrue);
      expect(await storeRepo.existsID(999), isFalse);
      expect(await storeRepo.selectByID(999), isNull);
    });

    test('update: a read error fails it (the stored object kept)', () async {
      var storeRepo = provider.storeRepo;

      var s = Store('e1', 10, id: 902);
      expect(await storeRepo.store(s), equals(902));

      // The bucket read of the stored object fails (not a "not found"):
      gcs.failingReads.add('store/902.json');

      // A partial update (only `name`) can't merge with the stored object:
      // it fails (previously: stored with only `name`, `number` lost).
      s.name = 'e2';
      Object? error;
      try {
        await storeRepo.store(s);
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect('$error', contains('503'));

      // The stored object is unchanged (not overwritten):
      expect(stored('store/902.json'), {'id': 902, 'name': 'e1', 'number': 10});

      // Readable again: the update works.
      gcs.failingReads.clear();
      s.name = 'e3';
      expect(await storeRepo.store(s), equals(902));
      expect(stored('store/902.json'), {'id': 902, 'name': 'e3', 'number': 10});
    });

    test('a read error in a select: as not found', () async {
      var storeRepo = provider.storeRepo;

      expect(await storeRepo.store(Store('r1', 1, id: 903)), equals(903));

      gcs.failingReads.add('store/903.json');
      expect(await storeRepo.selectByID(903), isNull);

      gcs.failingReads.clear();
      expect((await storeRepo.selectByID(903))!.name, equals('r1'));
    });

    test('enum and Decimal fields (JSON encoded)', () async {
      var roleRepo = provider.roleRepo;

      var role = Role(RoleType.admin, id: 951, value: Decimal.parse('3.25'));
      expect(await roleRepo.store(role), equals(951));

      var json = jsonDecode(utf8.decode(gcs.objects['role/951.json']!)) as Map;
      expect(json['type'], equals('admin'));
      expect(json['value'], equals('3.25'));

      var role2 = (await roleRepo.selectByID(951))!;
      expect(role2.type, equals(RoleType.admin));
      expect(role2.value, equals(Decimal.parse('3.25')));
    });

    test('delete', () async {
      var storeRepo = provider.storeRepo;

      expect(await storeRepo.store(Store('d1', 1, id: 904)), equals(904));
      expect(gcs.objects.containsKey('store/904.json'), isTrue);

      var del = await storeRepo.deleteByID(904);
      expect(del?.name, equals('d1'));
      expect(gcs.objects.containsKey('store/904.json'), isFalse);
      expect(await storeRepo.deleteByID(904), isNull);
    });
  });
}
