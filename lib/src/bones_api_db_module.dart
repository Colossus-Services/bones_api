import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

final _log = logging.Logger('APIDBModule');

class APIDBModule extends APIModule {
  final bool onlyOnDevelopment;

  APIDBModule(APIRoot apiRoot,
      {String name = 'db', this.onlyOnDevelopment = true})
      : super(apiRoot, name);

  bool get development => apiConfig.development;

  @override
  String? get defaultRouteName => 'tables';

  @override
  void configure() {
    if (onlyOnDevelopment && !development) return;

    routes.add(null, 'tables', (request) async => tables());

    routes.add(null, 'select', (request) async {
      var pathParts = request.pathParts;

      var idx = pathParts.indexOf('select');
      if (idx < 0 || idx == pathParts.length - 1) {
        return APIResponse.notFound();
      }

      var pathParams = pathParts.sublist(idx + 1);

      var table = pathParams.removeAt(0);

      var eager = pathParams.any((p) => equalsIgnoreAsciiCase(p, 'eager'))
          ? true
          : null;

      return select(table, request, eager: eager);
    });

    routes.add(null, 'dump', (request) async {
      var pathParts = request.pathParts;

      var idx = pathParts.indexOf('dump');
      if (idx < 0) {
        return APIResponse.notFound();
      }

      var pathParams = pathParts.sublist(idx + 1);

      var zip = pathParams.any((p) => equalsIgnoreAsciiCase(p, 'zip'));

      return dump(zip);
    });
  }

  List<EntityRepositoryProvider>? _entityRepositoryProviders;

  Future<List<EntityRepositoryProvider>> get entityRepositoryProviders async =>
      _entityRepositoryProviders ??=
          await apiRoot.loadEntityRepositoryProviders();

  Future<APIResponse<Map<String, String>>> tables() async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    _log.info("APIDBModule[REQUEST]> tables");

    var allRepositories = (await entityRepositoryProviders).allRepositories();

    var map = allRepositories.map((type, repo) => MapEntry('$type', repo.name));
    return APIResponse.ok(map, mimeType: 'json');
  }

  Future<APIResponse<List>> select(String selectTable, APIRequest apiRequest,
      {bool? eager}) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    var requestedUri = apiRequest.requestedUri;

    var entityRepository = (await entityRepositoryProviders)
        .getEntityRepository(name: selectTable);

    if (entityRepository == null) {
      return APIResponse.error(error: "Can't find table: $selectTable");
    }

    var query = Uri.decodeQueryComponent(requestedUri.query);

    if (query == 'EAGER=true') {
      query = '';
      eager = true;
    } else if (query.endsWith('&EAGER=true')) {
      query = query.substring(0, query.length - 11);
      eager = true;
    }

    eager ??= false;

    _log.info("APIDBModule[REQUEST]> select> "
        "table: `$selectTable` ; "
        "eager: $eager"
        "${query.isNotEmpty ? ' ; QUERY> $query' : ''}");

    var resolutionRules = eager ? EntityResolutionRules(allEager: eager) : null;

    List<Object> list;

    if (query.isEmpty) {
      var selectAll =
          await entityRepository.selectAll(resolutionRules: resolutionRules);
      list = selectAll.toList();
    } else {
      var selectByQuery = await entityRepository.selectByQuery(query,
          resolutionRules: resolutionRules);
      list = selectByQuery.toList();
    }

    var entitiesJson = _entitiesToJsonMap(list);
    return APIResponse.ok(entitiesJson, mimeType: 'json');
  }

  Future<APIResponse<Object>> dump(bool zip) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    _log.info("APIDBModule[REQUEST]> dump");

    var allRepositories = (await entityRepositoryProviders).allRepositories();

    var dump = await allRepositories.values
        .map((repo) => MapEntry(repo.name, repo.selectAll()))
        .toMapFromEntries()
        .resolveAllValues();

    var dumpJson = dump.entries
        .map((e) => MapEntry(e.key, _entitiesToJsonMap(e.value)))
        .where((e) => e.value.isNotEmpty)
        .toMapFromEntries();

    if (zip) {
      var apiName =
          apiRoot.name.toLowerCase().trim().replaceAll(RegExp(r'\W+'), '_');

      var zipTime = DateTime.now().millisecondsSinceEpoch;

      var zipName = 'db-dump--$apiName--$zipTime';

      var archive = Archive();

      {
        var dumpJsonBytes = Json.encodeToBytes(dumpJson);

        var archiveFile = ArchiveFile(
            '$zipName/dump.json', dumpJsonBytes.length, dumpJsonBytes);
        archive.addFile(archiveFile);
      }

      var zipEncoder = ZipEncoder();

      var encode = zipEncoder.encode(archive)!;
      var zipData = encode is Uint8List ? encode : Uint8List.fromList(encode);

      var zipFileName = '$zipName.zip';

      return APIResponse.ok(zipData, mimeType: 'application/zip', headers: {
        'Content-Disposition': 'attachment; filename="$zipFileName"'
      });
    }

    return APIResponse.ok(dumpJson, mimeType: 'json');
  }

  List<Map<String, dynamic>> _entitiesToJsonMap(Iterable<Object> list) {
    return list.map((e) => _entityToJsonMap(e)).toList();
  }

  Map<String, dynamic> _entityToJsonMap(Object e) {
    var o = Json.toJson(e);
    return _normalizeEntityJson(o);
  }

  Map<String, dynamic> _normalizeEntityJson(o) {
    if (o is Map) {
      return o.entries.map((e) {
        var value = _normalizeEntityJsonValue(e.value);
        return MapEntry<String, dynamic>('${e.key}', value);
      }).toMapFromEntries();
    } else {
      return {};
    }
  }

  Object? _normalizeEntityJsonValue(value) {
    if (value is Map) {
      if (value.containsKey('EntityReference') && value.containsKey('id')) {
        value = value['id'];
      } else if (value.containsKey('EntityReferenceList') &&
          value.containsKey('ids')) {
        value = value['ids'];
      } else if (value.containsKey('id')) {
        value = value['id'];
      }
    } else if (value is List) {
      value = value.map(_normalizeEntityJsonValue).toList();
    }
    return value;
  }
}
