import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;

final _log = logging.Logger('APIDBModule');

class APIDBModule extends APIModule {
  APIDBModule(APIRoot apiRoot) : super(apiRoot, 'db');

  bool get development => apiConfig.development;

  @override
  String? get defaultRouteName => 'tables';

  @override
  void configure() {
    routes.add(null, 'tables', (request) => tables());

    routes.add(null, 'select', (request) {
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
  }

  List<EntityRepositoryProvider>? _entityRepositoryProviders;

  List<EntityRepositoryProvider> get entityRepositoryProviders =>
      _entityRepositoryProviders ??= apiRoot.loadEntityRepositoryProviders()
          as List<EntityRepositoryProvider>;

  Future<APIResponse<Map<String, String>>> tables() async {
    if (!development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    _log.info("APIDBModule[REQUEST]> tables");

    var map = entityRepositoryProviders
        .allRepositories()
        .map((type, repo) => MapEntry('$type', repo.name));
    return APIResponse.ok(map, mimeType: 'json');
  }

  Future<APIResponse<List>> select(String selectTable, APIRequest apiRequest,
      {bool? eager}) async {
    if (!development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    var requestedUri = apiRequest.requestedUri;

    var entityRepository =
        entityRepositoryProviders.getEntityRepository(name: selectTable);

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

    if (query.isEmpty) {
      var selectAll =
          await entityRepository.selectAll(resolutionRules: resolutionRules);
      var list = selectAll.toList();
      return APIResponse.ok(list, mimeType: 'json');
    } else {
      var selectByQuery = await entityRepository.selectByQuery(query,
          resolutionRules: resolutionRules);
      var list = selectByQuery.toList();
      return APIResponse.ok(list, mimeType: 'json');
    }
  }
}
