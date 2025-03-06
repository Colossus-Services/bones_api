import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_html_document.dart';
import 'bones_api_module.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('APIDBModule');

class APIDBModule extends APIModule {
  final bool onlyOnDevelopment;

  final APICredential? credential;

  APIDBModule(APIRoot apiRoot,
      {String name = 'db', this.onlyOnDevelopment = true, this.credential})
      : super(apiRoot, name);

  bool get development => apiConfig.development;

  @override
  String? get defaultRouteName => 'tables';

  String get basePath => '/$name/';

  @override
  void configure() {
    if (onlyOnDevelopment && !development) return;

    routes.add(null, 'info', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var openTransactions = Transaction.openInstances;

      var info =
          StringBuffer('Open Transactions (${openTransactions.length}):\n');

      for (var t in openTransactions) {
        info.write(t);
        info.write('\n');
      }

      Transaction.executingTransaction;

      return APIResponse.ok(info.toString());
    });

    routes.add(null, 'tables', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'tables');

      var json = _containsKey(pathParams ?? [], 'json');
      return tables(json: json);
    });

    routes.add(null, 'select', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'select');
      if (pathParams == null) {
        return APIResponse.notFound();
      }

      var table = pathParams.removeAt(0);

      var eager = pathParams.any((p) => equalsIgnoreAsciiCase(p, 'eager'))
          ? true
          : null;

      var json = _containsKey(pathParams, 'json');
      return select(table, request, eager: eager, json: json);
    });

    routes.add(null, 'insert', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'insert');
      if (pathParams == null) {
        return APIResponse.notFound();
      }

      var table = pathParams.removeAt(0);

      return insert(table, request);
    });

    routes.add(null, 'update', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'update');
      if (pathParams == null) {
        return APIResponse.notFound();
      }

      var table = pathParams.removeAt(0);
      var id = pathParams.isNotEmpty ? pathParams.removeAt(0) : null;

      return insert(table, request, id: id);
    });

    routes.add(null, 'delete', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'delete');
      if (pathParams == null) {
        return APIResponse.notFound();
      }

      var table = pathParams.removeAt(0);
      var id = pathParams.isNotEmpty ? pathParams.removeAt(0) : null;

      return delete(table, request, id);
    });

    routes.add(null, 'dump', (request) async {
      var authResp = await checkAuthentication(request);
      if (authResp != null) return authResp;

      var pathParams = _parsePath(request, 'dump');
      if (pathParams == null) {
        return APIResponse.notFound();
      }

      var zip = pathParams.any((p) => equalsIgnoreAsciiCase(p, 'zip'));

      return dump(zip);
    });
  }

  Future<APIResponse<Object>?> checkAuthentication(APIRequest request) async {
    var credential = this.credential;
    if (credential == null) {
      if (!development) {
        throw APIResponse.error(
            error:
                "Not a `development` environment to allow unauthenticated access.");
      }

      return null;
    }

    var requestCredential = request.originalCredential;
    if (requestCredential != null &&
        credential.checkCredential(requestCredential)) {
      return null;
    }

    return APIResponse.unauthorized(payload: 'Authorization required.')
      ..requireAuthentication(require: true, realm: 'DB', type: 'Basic');
  }

  List<String>? _parsePath(APIRequest request, String route) {
    var pathParts = request.pathParts;

    var idx = pathParts.indexOf(route);
    if (idx < 0) {
      return null;
    } else if (idx == pathParts.length - 1) {
      return [];
    }

    var pathParams = pathParts.sublist(idx + 1);
    return pathParams;
  }

  bool _containsKey(List<String> pathParams, String key) =>
      pathParams.any((p) => equalsIgnoreAsciiCase(p, key));

  List<EntityRepositoryProvider>? _entityRepositoryProviders;

  Future<List<EntityRepositoryProvider>> get entityRepositoryProviders async =>
      _entityRepositoryProviders ??=
          await apiRoot.loadEntityRepositoryProviders();

  Future<APIResponse<dynamic>> tables({bool json = false}) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    _log.info("APIDBModule[REQUEST]> tables");

    var allRepositories = (await entityRepositoryProviders).allRepositories();

    var allRepositoriesEntries = allRepositories.entries
        .sorted((a, b) => a.value.name.compareTo(b.value.name))
        .toList();

    if (json) {
      var map = allRepositoriesEntries
          .map((e) {
            var type = e.key;
            var repo = e.value;
            return MapEntry('$type', repo.name);
          })
          .sorted((a, b) => a.key.compareTo(b.key))
          .toMapFromEntries();

      return APIResponse.ok(map, mimeType: 'json');
    }

    var htmlDoc = HTMLDocument.darkTheme(
      title: 'DB - Tables',
      top:
          _buildTop(apiRootName: apiRoot.name, apiRootVersion: apiRoot.version),
      footer: _buildFooter(),
    );

    var content = [];

    content.add('<br><table class="center">');
    content.add(
        '<thead><tr><td style="text-align: right">Type: &nbsp;</td><td style="text-align: center">Table:</td><td style="text-align: center">Operations:</td></tr></thead>');

    for (var e in allRepositoriesEntries) {
      var type = e.key;
      var repo = e.value;
      var repoName = repo.name;
      content.add(
          '<tr><td style="text-align: right"><b>$type:</b> &nbsp;</td><td style="text-align: center">$repoName</td><td> &nbsp; [ <a href="${basePath}select/$repoName">select</a> &nbsp;|&nbsp; <a href="${basePath}insert/$repoName">insert</a> ] &nbsp;</td></tr>');
    }

    content.add('</table>');

    content.add(
        '<br><div style="width: 100%; text-align: center;"><i><a href="${basePath}tables/json">JSON</a></i></div>');

    htmlDoc.content = content;

    var html = htmlDoc.build();

    return APIResponse.ok(html, mimeType: 'html');
  }

  Future<APIResponse<dynamic>> select(String table, APIRequest apiRequest,
      {bool? eager, bool json = false}) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    var requestedUri = apiRequest.requestedUri;

    final entityRepositoryProviders = await this.entityRepositoryProviders;

    var entityRepository =
        entityRepositoryProviders.getEntityRepository(name: table);

    if (entityRepository == null) {
      return APIResponse.error(error: "Can't find table: $table");
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
        "table: `$table` ; "
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

    list.sort((a, b) {
      var id1 = entityRepository.getEntityID(a);
      var id2 = entityRepository.getEntityID(b);

      if (id1 == null && id2 == null) {
        return 0;
      } else if (id1 == null) {
        return 1;
      } else if (id2 == null) {
        return -1;
      } else if (id1 is num && id2 is num) {
        return id1.compareTo(id2);
      } else if (id1 is String && id2 is String) {
        return id1.compareTo(id2);
      } else {
        return 0;
      }
    });

    if (json) {
      var entitiesJson = _entitiesToJsonMap(list);
      return APIResponse.ok(entitiesJson, mimeType: 'json');
    }

    var entityType = entityRepository.type;

    var htmlDoc = HTMLDocument.darkTheme(
      title: 'DB - Tables',
      top: _buildTop(
          apiRootName: apiRoot.name,
          apiRootVersion: apiRoot.version,
          table: table,
          entityType: entityType),
      footer: _buildFooter(),
    );

    var content = [];

    var entityHandler = entityRepository.entityHandler;

    var repoName = entityRepository.name;

    var fieldsEntries = _fieldsOrdered(entityHandler);

    content.add('<br><h2>$entityType</h2>');

    content.add('<table class="center">');

    content.add('<thead><tr>');
    content.add('<td style="text-align: left">#</td>');
    for (var e in fieldsEntries) {
      content.add('<td style="text-align: center">${e.key}</td>');
    }
    content.add(
        '<td style="text-align: center; min-width: 100px;">[operations]</td>');
    content.add('</tr></thead>');

    var i = 0;
    for (var o in list) {
      content.add('<tr>');
      content.add('<td>$i</td>');

      for (var e in fieldsEntries) {
        var fieldName = e.key;
        var fieldType = e.value;

        var v = entityHandler.getField(o, fieldName);
        var v2 = _resolveValue(v, fieldType);

        var entityType = fieldType.entityType ?? fieldType.listEntityType?.type;
        var fieldEntityRepository = entityType != null
            ? entityRepositoryProviders.getEntityRepositoryByType(entityType)
            : null;

        if (fieldEntityRepository != null) {
          var repoName = fieldEntityRepository.name;

          content.add('<td style="text-align: center">');

          if (v2 is List) {
            var ids = v2
                .map((e) => '<a href="${basePath}update/$repoName/$e">$e</a>')
                .join(' , ');
            content.add(ids);
          } else {
            content.add('<a href="${basePath}update/$repoName/$v2">$v2</a>');
          }

          content.add('</td>');
        } else {
          content.add('<td style="text-align: center">$v2</td>');
        }
      }

      var id = entityHandler.getID(o);

      if (id != null) {
        content.add('<td style="text-align: center"> &nbsp; [ ');

        content.add('<a href="../update/$repoName/$id">edit</a>');

        content.add(' &nbsp;|&nbsp; <a href="../delete/$repoName/$id">del</a>');

        content.add(' ] &nbsp;</td>');
      }

      content.add('</tr>');
      ++i;
    }

    content.add(
        '<tr><td colspan="${fieldsEntries.length + 2}" style="text-align: right"><a href="${basePath}insert/$repoName">&nbsp;+&nbsp;</a></td></tr>');

    content.add('</table>');

    content.add(
        '<br><div style="width: 100%; text-align: center;"><i><a href="${basePath}select/$repoName/json${query.isNotEmpty ? '?$query' : ''}">JSON</a></i></div>');

    htmlDoc.content = content;

    var html = htmlDoc.build();

    return APIResponse.ok(html, mimeType: 'html');
  }

  static const _fieldsNamesOrder = [
    'id',
    'active',
    'enabled',
    'disabled',
    'allowed',
    'name',
    'email',
    'username',
    'password',
    'passwordHash',
    'title',
    'description',
    'text',
  ];

  static const _fieldsTypesOrder = [
    int,
    double,
    num,
    bool,
    String,
    Enum,
    DateTime,
    EntityReference,
    EntityReferenceList
  ];

  Future<APIResponse<String>> insert(String table, APIRequest apiRequest,
      {Object? id}) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    var entityRepository =
        (await entityRepositoryProviders).getEntityRepository(name: table);

    if (entityRepository == null) {
      return APIResponse.error(error: "Can't find table: $table");
    }

    final entityType = entityRepository.type;
    final entityHandler = entityRepository.entityHandler;

    var update = false;
    Object? entity;

    if (id != null) {
      var id2 = entityHandler.resolveID(id);
      entity = await entityRepository.selectByID(id2);
      update = entity != null;
    }

    var htmlDoc = HTMLDocument.darkTheme(
      title: 'DB - ${update ? 'update' : 'insert'} @ $entityType',
      top: _buildTop(
          apiRootName: apiRoot.name,
          apiRootVersion: apiRoot.version,
          table: table,
          entityType: entityType),
      footer: _buildFooter(),
    );

    var content = [];

    _addScriptFixDateTime(content);

    var parameters = Map<String, dynamic>.from(apiRequest.parameters);
    if (parameters.isNotEmpty) {
      _fixParametersDateTime(parameters);

      var entity2 = await entityHandler.createFromMap(parameters,
          entityProvider: entityRepository.provider,
          resolutionRules: EntityResolutionRules(allowEntityFetch: true));

      try {
        if (entity != null) {
          var fields = entityHandler.getFields(entity2);
          entity = await entityHandler.setFieldsFromMap(entity, fields);
        } else {
          entity = entity2;
        }
      } catch (e, s) {
        content.add(
            '<h3 style="text-align: left;">Error instantiating `$entityType`:</h3>\n');
        content.add(
            '<pre>Parameters: ${Json.encode(parameters, pretty: true)}</pre>\n');
        content.add('<pre>ERROR:\n$e\n$s\n</pre>');
        content.add('<hr>\n');
      }

      if (entity != null) {
        try {
          var id = await entityRepository.store(entity);

          content.add(
              '<br><h2 style="text-align: left;">${update ? 'Updated' : 'Inserted'}: #$id</h2>\n');

          _writeEntityJson(entityHandler, entityType, entity, content);

          content.add('<br><hr>');
        } catch (e, s) {
          content.add(
              '<br><h3 style="text-align: left;">Error storing `$entityType`:</h3>\n');
          content.add('<pre>EntityRepository: $entityRepository</pre>\n');
          content.add('<pre>ERROR:\n$e\n$s\n</pre>');
          content.add('<br><hr>\n');
        }
      }
    }

    content.add('<form method="post">');
    content.add(
        '<input id="LOCAL_TIMEZONE" type="hidden" name="__LOCAL_TIMEZONE__">');

    _writeInputTable(entityRepository, content, entity);

    content.add(
        '<br><div style="text-align: center; width: 100%;"><button type="submit">${update ? 'Update' : 'Insert'}</button></div>');

    content.add('</form>');

    content.add(
        "<script type='application/javascript'> setLocalTimeZone() ; fixAllInputsDateTimeToLocal() ;</script>");

    htmlDoc.content = content;

    var html = htmlDoc.build();

    return APIResponse.ok(html, mimeType: 'html');
  }

  void _fixParametersDateTime(Map<String, dynamic> parameters) {
    var localTimeZoneStr = parameters.remove('__LOCAL_TIMEZONE__');

    if (localTimeZoneStr != null) {
      var localTimeZoneMin = TypeParser.parseInt(localTimeZoneStr);

      if (localTimeZoneMin != null && localTimeZoneMin != 0) {
        for (var e in parameters.entries) {
          var key = e.key;
          var value = e.value;

          if (value is String &&
              RegExp(r'^\d\d\d\d-\d\d-\d\dT\d\d:\d\d(?::\d\d)?Z?$')
                  .hasMatch(value)) {
            var d = TypeParser.parseDateTime(value);
            if (d != null) {
              var d2 = DateTime.utc(
                  d.year, d.month, d.day, d.hour, d.minute, d.second);
              var d3 = d2.add(Duration(minutes: localTimeZoneMin));
              parameters[key] = d3;
            }
          }
        }
      }
    }
  }

  void _addScriptFixDateTime(List<dynamic> content) {
    content.add(r'''
<script type="application/javascript">
  function toLocalISOString(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0'); // Months are 0-based
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    const s = year + '-' + month + '-' + day + 'T' + hours + ':' + minutes + ':' + seconds;
    return s;
  }

  function fixInputDateTimeToLocal(input) {
    let dStr = input.value;
    if (dStr.length < 16) {
      return ;
    }
    
    const d = new Date(dStr);
    console.log(d);
    
    const dLocal = new Date(Date.UTC(
      d.getFullYear(),
      d.getMonth(),
      d.getDate(),
      d.getHours(),
      d.getMinutes(),
      d.getSeconds()
    ));
    
    console.log(dLocal);
    
    const dLocalStr = toLocalISOString(dLocal);
    input.value = dLocalStr;
    console.log("-- Fixed DataTime: "+ dStr + " -> "+ dLocalStr); 
  }
  
  function fixAllInputsDateTimeToLocal() {
    const inputs = document.querySelectorAll('input[type="datetime-local"]');

    inputs.forEach(input => {
      fixInputDateTimeToLocal(input);
    });
  }
  
  function setLocalTimeZone() {
    const offsetMinutes = new Date().getTimezoneOffset();
    const inputLocalTimeZone = document.querySelector('#LOCAL_TIMEZONE');
    inputLocalTimeZone.value = offsetMinutes;
    console.log("-- LOCAL_TIMEZONE: "+ offsetMinutes +" min");
  }
</script>
''');
  }

  void _writeEntityJson(EntityHandler entityHandler, Type entityType,
      Object entity, List content) {
    var json = entityHandler.toJson(entity);
    var jsonEnc = Json.encode(json, pretty: true);

    content.add('<pre>\n');
    content.add('$entityType $jsonEnc\n');
    content.add('</pre>\n');
  }

  void _writeInputTable(
      EntityRepository<Object> entityRepository, List content, Object? entity) {
    var entityHandler = entityRepository.entityHandler;

    var fieldsEntries = _fieldsOrdered(entityHandler);

    content.add('<br><table class="center">');

    content.add(
        '<tr><td colspan="3"><h2>${entityRepository.type}:</h2></td></tr>');

    var repoName = entityRepository.name;
    var idFieldName = entityHandler.idFieldName(entity);

    for (var e in fieldsEntries) {
      var name = e.key;
      var type = e.value;

      var isID = name == idFieldName;

      Object? value;
      if (entity != null) {
        value = entityHandler.getField(entity, name);
      }

      content.add('<tr><td style="text-align: right; vertical-align: top;">');

      if (isID && value != null) {
        var href = '${basePath}select/$repoName?id==$value';
        content.add('<a href="$href">$name</a>: &nbsp;\n');
      } else {
        content.add('$name: &nbsp;\n');
      }

      content.add('</td><td>');

      content.add(HTMLInput(name, type, value: value));

      content.add('</td><td>');

      String typeStr;
      if (type.isEntityReferenceType) {
        typeStr = type.isValidGenericType
            ? type.genericType.toString()
            : type.toString(withT: false);
      } else if (type.isEntityReferenceListType) {
        typeStr = type.isValidGenericType
            ? type.genericType.toString()
            : type.toString(withT: false);
      } else if (type.isListEntity) {
        typeStr = type.genericType.toString();
      } else {
        typeStr = (type.hasArguments ? type : type.type).toString();
      }

      typeStr = typeStr.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

      content.add('&nbsp;&nbsp;<span class="note">$typeStr</span>');

      content.add('</td></tr>');
    }

    content.add('</table>');
  }

  Future<APIResponse<String>> delete(
      String table, APIRequest apiRequest, Object? id) async {
    if (onlyOnDevelopment && !development) {
      return APIResponse.error(error: "Unsupported request!");
    }

    var entityRepository =
        (await entityRepositoryProviders).getEntityRepository(name: table);

    if (entityRepository == null) {
      return APIResponse.error(error: "Can't find table: $table");
    }

    final entityType = entityRepository.type;
    final entityHandler = entityRepository.entityHandler;

    id = entityHandler.resolveID(id) ?? id;
    if (id == null) {
      return APIResponse.notFound(payloadDynamic: "Null ID.");
    }

    var entityExists = await entityRepository.existsID(id);
    if (!entityExists) {
      return APIResponse.notFound(
          payloadDynamic: "Can't find `$entityType` entity with ID: $id");
    }

    var htmlDoc = HTMLDocument.darkTheme(
      title: 'DB - delete @ $entityType',
      top: _buildTop(
          apiRootName: apiRoot.name,
          apiRootVersion: apiRoot.version,
          table: table,
          entityType: entityType),
      footer: _buildFooter(),
    );

    var content = [];

    var confirmed = apiRequest.parameters.getAsBool('confirm') ?? false;

    if (confirmed) {
      try {
        var entity = await entityRepository.deleteByID(id);

        if (entity == null) {
          throw StateError("Delete returned a null Entity: $id @ $entityType");
        }

        content.add('<br><h2 style="text-align: left;">Deleted: #$id</h2>\n');

        _writeEntityJson(entityHandler, entityType, entity, content);
      } catch (e, s) {
        content.add(
            '<h3 style="text-align: left;">Error storing `$entityType`:</h3>\n');
        content.add('<pre>EntityRepository: $entityRepository</pre>\n');
        content.add('<pre>ERROR:\n$e\n$s\n</pre>\n');
      }
    } else {
      try {
        var entity = await entityRepository.selectByID(id);

        if (entity == null) {
          throw StateError("Can't select entity: $id @ $entityType");
        }

        content.add('<br><h2 style="text-align: left;">Delete? #$id</h2>\n');

        _writeEntityJson(entityHandler, entityType, entity, content);
      } catch (e, s) {
        content.add(
            '<h3 style="text-align: left;">Error storing `$entityType`:</h3>\n');
        content.add('<pre>EntityRepository: $entityRepository</pre>\n');
        content.add('<pre>ERROR:\n$e\n$s\n</pre>\n');
      }

      var url = apiRequest.requestedUri;

      content.add(
          '''<br><div style="text-align: left; width: 100%;"><button type="submit" onclick="window.location='${url.path}?confirm=true'">Confirm Deletion</button></div>''');
    }

    htmlDoc.content = content;

    var html = htmlDoc.build();

    return APIResponse.ok(html, mimeType: 'html');
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

      var encode = zipEncoder.encode(archive);
      var zipData = encode is Uint8List ? encode : Uint8List.fromList(encode);

      var zipFileName = '$zipName.zip';

      return APIResponse.ok(zipData, mimeType: 'application/zip', headers: {
        'Content-Disposition': 'attachment; filename="$zipFileName"'
      });
    }

    return APIResponse.ok(dumpJson, mimeType: 'json');
  }

  Object? _resolveValue(Object? o, TypeInfo typeInfo) {
    if (o == null) return null;

    if (typeInfo.isPrimitiveType) {
      return o;
    } else if (o is EntityReference) {
      return o.entityOrID;
    } else if (o is EntityReferenceList) {
      return o.entitiesOrIDs;
    }

    var reflectionFactory = ReflectionFactory();

    var enumReflection =
        reflectionFactory.getRegisterEnumReflection(typeInfo.type);
    if (enumReflection != null) {
      return enumReflection.name(o);
    }

    var entityType = typeInfo.entityType ?? typeInfo.listEntityType?.type;

    var classReflection =
        reflectionFactory.getRegisterClassReflection(entityType);
    if (classReflection != null) {
      var entityHandler = classReflection.entityHandler;

      var id =
          o is List ? entityHandler.resolveIDs(o) : entityHandler.resolveID(o);

      return id;
    }

    return o;
  }

  static Type _resolveTypeForSorting(Type t) {
    var enumReflection = ReflectionFactory().getRegisterEnumReflection(t);
    return enumReflection != null ? Enum : t;
  }

  List<MapEntry<String, TypeInfo>> _fieldsOrdered(EntityHandler entityHandler) {
    var fieldsTypes = entityHandler.getFieldsTypes();

    var fieldsEntries = fieldsTypes.entries.toList();

    fieldsEntries.sort((a, b) {
      var i1 = _fieldsNamesOrder.indexOf(a.key);
      var i2 = _fieldsNamesOrder.indexOf(b.key);

      if (i1 >= 0) {
        if (i2 >= 0) {
          return i1.compareTo(i2);
        } else {
          return -1;
        }
      } else if (i2 >= 0) {
        return 1;
      } else {
        i1 = _fieldsTypesOrder.indexOf(_resolveTypeForSorting(a.value.type));
        i2 = _fieldsTypesOrder.indexOf(_resolveTypeForSorting(b.value.type));

        if (i1 >= 0) {
          if (i2 >= 0) {
            return i1.compareTo(i2);
          } else {
            return -1;
          }
        } else if (i2 >= 0) {
          return 1;
        } else {
          return 0;
        }
      }
    });

    return fieldsEntries;
  }

  String _buildTop(
      {String? apiRootName,
      String? apiRootVersion,
      String? table,
      Type? entityType}) {
    var html = StringBuffer();

    apiRootName = apiRootName?.trim();
    apiRootVersion = apiRootVersion?.trim();

    html.write('<b>DB');
    if (apiRootName != null && apiRootName.isNotEmpty) {
      html.write(
          '[$apiRootName${apiRootVersion != null && apiRootVersion.isNotEmpty ? '/$apiRootVersion' : ''}]');
    }
    html.write(':</b> &nbsp; ');

    html.write('<a href="${basePath}tables">Tables</a>');

    if (table != null && table.isNotEmpty && entityType != null) {
      html.write(
          ' &nbsp;|&nbsp; <a href="${basePath}select/$table">Select / $entityType</a></li>');
    }

    html.write(' &nbsp;|&nbsp; <a href="${basePath}dump">Dump</a>');

    html.write('\n<hr>');

    return html.toString();
  }

  String _buildFooter() {
    var html = StringBuffer();

    html.write('<br><hr>');
    html.write(
        '<a href="https://pub.dev/packages/bones_api" target="_blank">Bones_API/${BonesAPI.VERSION}</a>');

    return html.toString();
  }

  List<Map<String, dynamic>> _entitiesToJsonMap(Iterable<Object> list) {
    return list.map(_entityToJsonMap).toList();
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
