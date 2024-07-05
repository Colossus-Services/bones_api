import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:args_simple/args_simple_io.dart';
import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as pack_path;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_gzip/shelf_gzip.dart';
import 'package:shelf_letsencrypt/shelf_letsencrypt.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:statistics/statistics.dart' hide IterableIntExtension;
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_config.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_extension.dart';
import 'bones_api_hotreload.dart';
import 'bones_api_logging.dart';
import 'bones_api_server_cache.dart';
import 'bones_api_session.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_httpclient.dart';
import 'bones_api_utils_isolate.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('APIServer');

final _logLetsEncrypt = logging.Logger('LetsEncrypt');

/// API Server Config.
class APIServerConfig {
  final bool development;

  /// The bind address of this server.
  final String address;

  /// The listen port of this server (HTTP).
  final int port;

  /// The listen secure port of this server (HTTPS).
  final int securePort;

  /// If `true` enabled Let's Encrypt.
  ///
  /// - See [LetsEncrypt].
  final bool letsEncrypt;

  /// The Let's Encrypt certificates [Directory].
  ///
  /// - See [LetsEncrypt].
  final Directory? letsEncryptDirectory;

  /// If `true` runs Let's Encrypt in production mode.
  final bool letsEncryptProduction;

  /// If `true` allows the request of Let's Encrypt certificates.
  final bool allowRequestLetsEncryptCertificate;

  /// The name of this server.
  ///
  /// This is used for the `server` header.
  final String name;

  /// The version of this server.
  ///
  /// This is used for the `server` header.
  final String version;

  /// If `true` enables Hot Reload ([APIHotReload.enable]).
  final bool hotReload;

  /// The domains root directories.
  final Map<Pattern, Directory> domainsRoots;

  /// Returns a list of domains at [domainsRoots] keys (non [RegExp] entries).
  List<String> get domains => domainsRoots.keys.whereType<String>().toList();

  /// If `true` the server will use/generate a `SESSIONID` for each request.
  /// If `false` will ignore any `SESSIONID` cookie (useful to comply with cookieless servers).
  /// - If [cookieless] is `true` `SESSIONID` is disabled.
  final bool useSessionID;

  /// The number of [APIServerWorker] instances to spawn.
  /// - If [totalWorkers] is equal to 1, it will execute 1 [APIServerWorker] in the current [Isolate].
  /// - If [totalWorkers] is greater than 1, it will execute multiple [APIServerWorker] instances in new [Isolate]s.
  /// - The [totalWorkers] will be set in the range of 1 to 100.
  final int totalWorkers;

  /// If `true` will remove any `Set-Cookie` or `Cookie` header.
  ///
  /// See [useSessionID].
  final bool cookieless;

  /// The `cache-control` header for API responses.
  final String apiCacheControl;

  /// The `cache-control` header for static files.
  final String staticFilesCacheControl;

  /// The default value for [apiCacheControl].
  static const String defaultApiCacheControl =
      'private, no-transform, must-revalidate, max-age=0, no-store, no-cache';

  /// The default value for [staticFilesCacheControl].
  static const String defaultStaticFilesCacheControl =
      'private, no-transform, must-revalidate, max-age=60, stale-while-revalidate=600, stale-if-error=300';

  /// If `true` will cache static files. Default: true
  final bool cacheStaticFilesResponses;

  /// The maximum memory size (in bytes) for storing all cached [Response]s. Default: 50M
  final int staticFilesCacheMaxMemorySize;

  /// The maximum `Content-Length` (in bytes) allowed for a cached [Response]. Default: 10M
  final int staticFilesCacheMaxContentLength;

  /// If `true` log messages to [stdout] (console).
  late final bool logToConsole;

  /// If `false` disables log flush queue.
  /// - See [LoggerHandler.disableLogQueue()]
  /// - Useful while debugging.
  late final bool logQueue;

  /// A forced delay in each server response.
  /// Only active if [development] is `true`.
  final Duration? serverResponseDelay;

  /// The [APIConfig] of the [APIRoot].
  final APIConfig? apiConfig;

  /// All the parsed arguments, using [ArgsSimple].
  final ArgsSimple args;

  APIServerConfig({
    bool? development,
    String? name,
    String? version,
    String? address,
    int? port,
    int? securePort,
    Object? documentRoot,
    Object? domains,
    Object? letsEncryptDirectory,
    this.letsEncrypt = false,
    bool? letsEncryptProduction,
    bool? allowRequestLetsEncryptCertificate,
    this.hotReload = false,
    int? totalWorkers = 1,
    this.cookieless = false,
    bool? useSessionID,
    String? apiCacheControl,
    String? staticFilesCacheControl,
    bool? cacheStaticFilesResponses,
    int? staticFilesCacheMaxMemorySize,
    int? staticFilesCacheMaxContentLength,
    this.apiConfig,
    bool? logToConsole,
    bool? logQueue,
    this.serverResponseDelay,
    Object? args,
  })  : development = development ?? false,
        name = name != null && name.trim().isNotEmpty ? name : 'Bones_API',
        version = version != null && version.trim().isNotEmpty
            ? version
            : BonesAPI.VERSION,
        address = normalizeAddress(address, apiConfig: apiConfig),
        port = resolvePort(port, apiConfig: apiConfig),
        securePort = resolveSecurePort(securePort,
            apiConfig: apiConfig, letsEncrypt: letsEncrypt),
        domainsRoots = parseDomains(domains,
            apiConfig: apiConfig,
            documentRoot: documentRoot,
            checkDirectoryExistence: true),
        letsEncryptProduction = resolveLetsEncryptProduction(
            letsEncryptProduction,
            apiConfig: apiConfig),
        allowRequestLetsEncryptCertificate =
            resolveAllowRequestLetsEncryptCertificate(
                allowRequestLetsEncryptCertificate,
                apiConfig: apiConfig),
        letsEncryptDirectory = resolveLetsEncryptDirectory(letsEncryptDirectory,
            apiConfig: apiConfig, letsEncrypt: letsEncrypt),
        apiCacheControl =
            normalizeHeaderValue(apiCacheControl, defaultApiCacheControl),
        staticFilesCacheControl = normalizeHeaderValue(
            staticFilesCacheControl, defaultStaticFilesCacheControl),
        cacheStaticFilesResponses = resolveCacheStaticFilesResponses(
            cacheStaticFilesResponses,
            apiConfig: apiConfig),
        staticFilesCacheMaxMemorySize = resolveStaticFilesCacheMaxMemorySize(
            staticFilesCacheMaxMemorySize,
            apiConfig: apiConfig),
        staticFilesCacheMaxContentLength =
            resolveStaticFilesCacheMaxContentLength(
                staticFilesCacheMaxContentLength,
                apiConfig: apiConfig),
        useSessionID = resolveUseSessionID(cookieless, useSessionID),
        totalWorkers = resolveTotalWorkers(totalWorkers, apiConfig: apiConfig),
        logToConsole = resolveLogToConsole(logToConsole, apiConfig: apiConfig),
        logQueue = resolveLogQueue(logQueue, apiConfig: apiConfig),
        args = resolveArgs(args);

  static ArgsSimple resolveArgs(Object? args) {
    if (args == null) return ArgsSimple();
    if (args is ArgsSimple) return args;

    if (args is List) {
      return ArgsSimple.parse(args.map((e) => e.toString()).toList());
    } else if (args is String) {
      return ArgsSimple.fromEncodedJson(args);
    }

    return ArgsSimple();
  }

  factory APIServerConfig.fromArgs(List<String> args) {
    var a = ArgsSimple.parse(args);

    var development = a.flagOr('development', null);

    var name = a.optionAsString('name');
    var version = a.optionAsString('version');

    var port = a.optionAsInt('port');
    var securePort = a.optionAsInt('secure-port');
    var address = a.optionAsString('address');

    var letsEncrypt = a.flag('letsencrypt');
    var letsEncryptProduction = letsEncrypt && a.flag('letsencrypt-production');
    var allowRequestLetsEncryptCertificate =
        letsEncrypt && a.flag('allow-request-letsencrypt-certificate');
    var letsEncryptDirectory =
        letsEncrypt ? a.optionAsDirectory('letsencrypt-directory') : null;

    var hotReload = a.flag('hot-reload');
    var totalWorkers = a.optionAsInt('total-workers');

    var cookieless = a.flag('cookieless');
    var useSessionID = a.flagOr('use-session-id', !cookieless)!;

    var apiCacheControl = a.optionAsString('api-cache-control');
    var staticFilesCacheControl =
        a.optionAsString('static-files-cache-control');

    var cacheStaticFilesResponses =
        a.optionAsBool('cache-static-files-responses');
    var staticFilesCacheMaxMemorySize =
        a.optionAsInt('static-files-cache-max-memory-size');
    var staticFilesCacheMaxContentLength =
        a.optionAsInt('static-files-cache-max-content-length');

    var logToConsole = a.flagOr('log-toConsole', null);

    var logQueue = a.flagOr('log-queue', null);

    var documentRoot = a.optionAsDirectory('document-root');

    var domains = a.optionAsList('domains');

    var apiConfigUri = a.optionAsString("api-config");
    if (apiConfigUri == null) {
      var arg0 = a.argumentAsString(0);
      if (arg0 != null &&
          (arg0.endsWith('.yml') ||
              arg0.endsWith('.yaml') ||
              arg0.endsWith('.json'))) {
        apiConfigUri = arg0;
      }
    }

    var apiConfig = apiConfigUri != null ? APIConfig.from(apiConfigUri) : null;

    var serverResponseDelay = tryParseDuration(
      a.optionAsString('server-response-delay') ??
          apiConfig?.getPath<String>('server', 'response-delay'),
    );

    return APIServerConfig(
      development: development ?? apiConfig?.development,
      name: name,
      version: version,
      address: address,
      port: port,
      securePort: securePort,
      documentRoot: documentRoot,
      domains: domains,
      letsEncryptDirectory: letsEncryptDirectory,
      letsEncrypt: letsEncrypt,
      letsEncryptProduction: letsEncryptProduction,
      allowRequestLetsEncryptCertificate: allowRequestLetsEncryptCertificate,
      hotReload: hotReload,
      totalWorkers: totalWorkers,
      cookieless: cookieless,
      useSessionID: useSessionID,
      apiCacheControl: apiCacheControl,
      staticFilesCacheControl: staticFilesCacheControl,
      cacheStaticFilesResponses: cacheStaticFilesResponses,
      staticFilesCacheMaxMemorySize: staticFilesCacheMaxMemorySize,
      staticFilesCacheMaxContentLength: staticFilesCacheMaxContentLength,
      serverResponseDelay: serverResponseDelay,
      apiConfig: apiConfig,
      logToConsole: logToConsole,
      logQueue: logQueue,
      args: a,
    );
  }

  static String normalizeAddress(String? address, {APIConfig? apiConfig}) {
    address ??= apiConfig?.getPath('server', 'address');

    address = address?.trim() ?? '';

    if (address == '*' ||
        address == '0' ||
        address == '::' ||
        address == '0:0:0:0:0:0:0:0') {
      return '0.0.0.0';
    }

    if (address.isEmpty ||
        address == 'local' ||
        address == '1' ||
        address == '127' ||
        address == '::1' ||
        address == '0:0:0:0:0:0:0:1') {
      return 'localhost';
    }

    return address;
  }

  static int resolvePort(int? port, {APIConfig? apiConfig}) {
    port ??= apiConfig?.getPath('server', 'port');

    return port != null && port > 10 ? port : 80;
  }

  static int resolveSecurePort(int? securePort,
      {APIConfig? apiConfig, bool? letsEncrypt}) {
    securePort ??= apiConfig?.getPath('server', 'securePort');

    return (letsEncrypt ?? false)
        ? (securePort != null && securePort > 10 ? securePort : 443)
        : (securePort ?? -1);
  }

  static String normalizeHeaderValue(String? header, String def) {
    if (header == null) return def;
    header = header.trim();
    return header.isNotEmpty ? header : def;
  }

  static Map<String, Directory> resolveDomainsRoots(List domains,
      [Directory? rootDir]) {
    var domainsRoots = domains
        .map((e) {
          var s = e.toString();
          var parts = s.split('=');

          var domain = parts[0];

          if (parts.length == 1) {
            return rootDir != null ? MapEntry(domain, rootDir) : null;
          } else {
            var path = parts[1].trim();
            var dir = path.isNotEmpty ? Directory(path) : rootDir;
            return dir != null ? MapEntry(domain, dir) : null;
          }
        })
        .nonNulls
        .toMapFromEntries();
    return domainsRoots;
  }

  static bool resolveLetsEncryptProduction(bool? letsEncryptProduction,
      {APIConfig? apiConfig}) {
    letsEncryptProduction ??= apiConfig?.getPath('letsencrypt', 'production');
    letsEncryptProduction ??= false;
    return letsEncryptProduction;
  }

  static bool resolveAllowRequestLetsEncryptCertificate(
      bool? allowRequestLetsEncryptCertificate,
      {APIConfig? apiConfig}) {
    allowRequestLetsEncryptCertificate ??=
        apiConfig?.getPath('letsencrypt', 'allow-request-certificate');
    allowRequestLetsEncryptCertificate ??= false;
    return allowRequestLetsEncryptCertificate;
  }

  static Directory? resolveLetsEncryptDirectory(Object? directory,
      {APIConfig? apiConfig, bool letsEncrypt = false}) {
    directory ??= apiConfig?.getPath('letsencrypt', 'directory');

    if (directory != null) {
      Directory? dir;
      if (directory is Directory) {
        dir = directory;
      } else if (directory is String) {
        directory = directory.trim();
        if (directory.isNotEmpty) {
          dir = Directory(directory);
        }
      }

      if (dir != null) {
        if (letsEncrypt && !dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir.existsSync() ? dir.absolute : dir;
      }
    }

    var paths = ['/etc/letsencrypt/live', '/etc/letsencrypt'];

    var userDir = _getUserDirectory();
    if (userDir != null) {
      paths.add(pack_path.join(userDir.path, '.letsencrypt'));
      paths.add(pack_path.join(userDir.path, '.lets-encrypt'));
      paths.add(pack_path.join(userDir.path, 'letsencrypt'));
      paths.add(pack_path.join(userDir.path, 'lets-encrypt'));
    }

    for (var p in paths) {
      var dir = Directory(p);
      if (dir.existsSync() && dir.statSync().canWrite) {
        return dir.absolute;
      }
    }

    if (letsEncrypt && userDir != null) {
      var dir = Directory(pack_path.join(userDir.path, '.letsencrypt'));
      dir.createSync();
      return dir;
    }

    return null;
  }

  static Directory? _getUserDirectory() {
    var envVars = Platform.environment;

    String? home;
    if (Platform.isMacOS) {
      home = envVars['HOME'];
    } else if (Platform.isLinux) {
      home = envVars['HOME'];
    } else if (Platform.isWindows) {
      home = envVars['UserProfile'];
    }

    if (home != null) {
      var dir = Directory(home);
      if (dir.existsSync()) {
        return dir.absolute;
      }
    }

    var dir = Directory('~/');
    if (dir.existsSync()) {
      return dir.absolute;
    }

    return null;
  }

  static int resolveTotalWorkers(int? totalWorkers, {APIConfig? apiConfig}) {
    totalWorkers ??= apiConfig?.getPath('server', 'totalWorkers');

    return (totalWorkers ?? 1).clamp(1, 100);
  }

  static bool resolveUseSessionID(bool cookieless, bool? useSessionID) {
    return cookieless ? false : (useSessionID ?? true);
  }

  static bool resolveCacheStaticFilesResponses(bool? cache,
      {APIConfig? apiConfig}) {
    if (cache != null) return cache;

    if (apiConfig != null) {
      cache ??= apiConfig.getAs('cache-static-files-responses');
      cache ??= apiConfig.getAs('cache_static_files_responses');

      var entryCacheStaticFiles = apiConfig.getPath('cache', 'static_files');
      if (entryCacheStaticFiles is bool) {
        cache = entryCacheStaticFiles;
      }

      cache ??= apiConfig.getPath('cache', 'static_files', 'enabled');
    }

    cache ??= true;
    return cache;
  }

  static int resolveStaticFilesCacheMaxMemorySize(int? max,
      {APIConfig? apiConfig}) {
    if (max != null) return max;

    if (apiConfig != null) {
      max ??= apiConfig.getAs('static-files-cache-max-memory-size');
      max ??= apiConfig.getAs('static_files_cache_max_memory_size');
      max ??= apiConfig.getPath('cache', 'static_files', 'max_memory_size');
    }

    max ??= APIServerResponseCache.defaultMaxMemorySize;
    return max;
  }

  static int resolveStaticFilesCacheMaxContentLength(int? max,
      {APIConfig? apiConfig}) {
    if (max != null) return max;

    if (apiConfig != null) {
      max ??= apiConfig.getAs('static-files-cache-max-content-length');
      max ??= apiConfig.getAs('static_files_cache_max_content_length');
      max ??= apiConfig.getPath('cache', 'static_files', 'max_content_length');
    }

    max ??= APIServerResponseCache.defaultMaxContentLength;
    return max;
  }

  // If `logToConsole` not defined and NOT logging all, set `logToConsole = true`:
  static bool resolveLogToConsole(bool? logToConsole, {APIConfig? apiConfig}) {
    logToConsole ??= apiConfig?.getPath('log', 'console');

    return logToConsole ?? LoggerHandler.getLogAllTo() == null;
  }

  static bool resolveLogQueue(bool? logQueue, {APIConfig? apiConfig}) {
    logQueue ??= apiConfig?.getPath('log', 'queue');

    return logQueue ?? true;
  }

  /// Parses a set of domains to serve static files.
  ///
  /// - See: [APIServer.domainsRoots], [parseDomainPattern], [parseDomainDirectory].
  static Map<Pattern, Directory> parseDomains(Object? o,
      {APIConfig? apiConfig,
      Object? documentRoot,
      bool checkDirectoryExistence = false}) {
    o ??= apiConfig?.get('domains');

    var documentRootDir = parseDomainDirectory(documentRoot,
        checkDirectoryExistence: checkDirectoryExistence);

    var domains =
        _parseDomains(o, checkDirectoryExistence: checkDirectoryExistence);

    var domains2 = {
      ...domains,
      if (documentRootDir != null) RegExp(r'.*'): documentRootDir,
    };

    return domains2;
  }

  static Map<Pattern, Directory> _parseDomains(Object? o,
      {bool checkDirectoryExistence = false}) {
    if (o == null) return {};

    if (o is Map) {
      var map = o.map((key, value) => MapEntry(
          parseDomainPattern(key),
          parseDomainDirectory(value,
              checkDirectoryExistence: checkDirectoryExistence)));
      return _removeInvalidDomains(map);
    }

    List values;

    if (o is List) {
      values = o;
    } else if (o is String) {
      values = o.split('&');
    } else {
      values = [o];
    }

    var entries = values
        .map((e) => parseDomainEntry(e,
            checkDirectoryExistence: checkDirectoryExistence))
        .nonNulls
        .toList();
    if (entries.isEmpty) return {};

    var map =
        _removeInvalidDomains(Map<Pattern, Directory?>.fromEntries(entries));

    return map.isNotEmpty ? map : {};
  }

  static Map<Pattern, Directory> _removeInvalidDomains(
      Map<Pattern, Directory?> domains) {
    return domains.entries
        .map((e) {
          var domain = e.key;
          var dir = e.value;
          if (dir == null || (domain is String && domain.isEmpty)) {
            return null;
          }
          return MapEntry(e.key, dir);
        })
        .nonNulls
        .toMapFromEntries();
  }

  /// Parses a domain entry as [MapEntry].
  ///
  /// - See [APIServer.domainsRoots].
  static MapEntry<Pattern, Directory?>? parseDomainEntry(Object? o,
      {bool checkDirectoryExistence = false}) {
    if (o == null) return null;
    if (o is MapEntry) {
      return MapEntry(
          parseDomainPattern(o.key),
          parseDomainDirectory(o.value,
              checkDirectoryExistence: checkDirectoryExistence));
    }

    var s = o.toString();

    var parts = s.split('=');
    var domain = parts[0].trim();
    var path = parts.length > 1 ? parts[1].trim() : '';

    return MapEntry(
        parseDomainPattern(domain),
        parseDomainDirectory(path,
            checkDirectoryExistence: checkDirectoryExistence));
  }

  /// Parses a domain pattern.
  ///
  /// - If is in the format `r/.../` it will be parsed as a [RegExp]. Example: `r/(www\.)?mydomain.com/`
  /// - See [APIServer.domainsRoots].
  static Pattern parseDomainPattern(Pattern domainPatter) {
    if (domainPatter is RegExp) return domainPatter;

    var s = domainPatter.toString().trim();

    if (s.startsWith('r/') && s.endsWith('/')) {
      var re = s.substring(2, s.length - 1);
      return RegExp(re);
    }

    if (s == '*' || s == '.') {
      return RegExp(r'.*');
    }

    return s;
  }

  /// Parses a domain [Directory].
  ///
  /// - See [APIServer.domainsRoots].
  static Directory? parseDomainDirectory(Object? dirPath,
      {bool checkDirectoryExistence = false}) {
    if (dirPath == null) return null;
    if (dirPath is Directory) return dirPath;
    var p = dirPath.toString();
    var dir = Directory(p);
    return !checkDirectoryExistence || dir.existsSync() ? dir : null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'address': address,
        'port': port,
        'securePort': securePort,
        'domains': domainsRoots.map((k, v) => MapEntry(k, v.path)),
        'letsEncrypt': letsEncrypt,
        'letsEncryptProduction': letsEncryptProduction,
        if (letsEncryptDirectory != null)
          'letsEncryptDirectory': letsEncryptDirectory?.path,
        'cookieless': cookieless,
        'useSessionID': useSessionID,
        'hotReload': hotReload,
        'totalWorkers': totalWorkers,
        'apiCacheControl': apiCacheControl,
        'staticFilesCacheControl': staticFilesCacheControl,
        'cacheStaticFilesResponses': cacheStaticFilesResponses,
        'staticFilesCacheMaxMemorySize': staticFilesCacheMaxMemorySize,
        'staticFilesCacheMaxContentLength': staticFilesCacheMaxContentLength,
        'logToConsole': logToConsole,
        'logQueue': logQueue,
        if (args.isNotEmpty) 'args': args.toList(),
      };

  factory APIServerConfig.fromJson(Map<String, dynamic> json) {
    return APIServerConfig(
      name: json['name'],
      version: json['version'],
      address: json['address'],
      port: json['port'],
      securePort: json['securePort'],
      domains: json['domains'],
      letsEncrypt: json['letsEncrypt'],
      letsEncryptProduction: json['letsEncryptProduction'],
      letsEncryptDirectory: json['letsEncryptDirectory'],
      cookieless: json['cookieless'],
      useSessionID: json['useSessionID'],
      hotReload: json['hotReload'],
      totalWorkers: json['totalWorkers'],
      apiCacheControl: json['apiCacheControl'],
      staticFilesCacheControl: json['staticFilesCacheControl'],
      cacheStaticFilesResponses: json['cacheStaticFilesResponses'],
      logToConsole: json['logToConsole'],
      logQueue: json['logQueue'],
      args: json['args'],
    );
  }
}

/// Base class for an API Server.
abstract class _APIServerBase extends APIServerConfig {
  static final Map<Type, int> _idCounter = {};

  static int _newID(Object o) {
    var t = o.runtimeType;
    var c = _idCounter[t] ?? 0;
    ++c;
    _idCounter[t] = c;
    return c;
  }

  /// ID of this instance.
  late final int id = _newID(this);

  /// The API root of this server.
  final APIRoot apiRoot;

  _APIServerBase(
    this.apiRoot, {
    super.name,
    super.version,
    super.address,
    super.port,
    super.securePort,
    super.documentRoot,
    super.domains,
    super.letsEncrypt,
    super.letsEncryptProduction,
    super.letsEncryptDirectory,
    super.allowRequestLetsEncryptCertificate,
    super.hotReload,
    super.totalWorkers,
    super.cookieless,
    super.useSessionID,
    super.apiCacheControl,
    super.staticFilesCacheControl,
    super.cacheStaticFilesResponses,
    super.staticFilesCacheMaxMemorySize,
    super.staticFilesCacheMaxContentLength,
    super.serverResponseDelay,
    super.logToConsole,
    super.logQueue,
  }) : super(apiConfig: apiRoot.apiConfig);

  _APIServerBase.fromConfig(this.apiRoot, APIServerConfig apiServerConfig)
      : super(
          name: apiServerConfig.name,
          version: apiServerConfig.version,
          address: apiServerConfig.address,
          port: apiServerConfig.port,
          securePort: apiServerConfig.securePort,
          domains: apiServerConfig.domainsRoots,
          letsEncrypt: apiServerConfig.letsEncrypt,
          letsEncryptProduction: apiServerConfig.letsEncryptProduction,
          letsEncryptDirectory: apiServerConfig.letsEncryptDirectory,
          allowRequestLetsEncryptCertificate:
              apiServerConfig.allowRequestLetsEncryptCertificate,
          hotReload: apiServerConfig.hotReload,
          totalWorkers: apiServerConfig.totalWorkers,
          cookieless: apiServerConfig.cookieless,
          useSessionID: apiServerConfig.useSessionID,
          apiCacheControl: apiServerConfig.apiCacheControl,
          staticFilesCacheControl: apiServerConfig.staticFilesCacheControl,
          cacheStaticFilesResponses: apiServerConfig.cacheStaticFilesResponses,
          staticFilesCacheMaxMemorySize:
              apiServerConfig.staticFilesCacheMaxMemorySize,
          staticFilesCacheMaxContentLength:
              apiServerConfig.staticFilesCacheMaxContentLength,
          serverResponseDelay: apiServerConfig.serverResponseDelay,
          logToConsole: apiServerConfig.logToConsole,
          logQueue: apiServerConfig.logQueue,
        );

  _APIServerBase.fromArgs(APIRoot apiRoot, List<String> args)
      : this.fromConfig(apiRoot, APIServerConfig.fromArgs(args));

  /// The `server` header value.
  String get serverName => '$name/$version';

  /// The host of [url];
  String get urlHost {
    switch (address) {
      case '0.0.0.0':
      case '127.0.0.1':
        return 'localhost';
      default:
        return address;
    }
  }

  /// The local URL of this server.
  String get url => 'http://$urlHost:$port/';

  /// The local `API-INFO` URL of this server.
  String get apiInfoURL => 'http://$urlHost:$port/API-INFO';

  /// Returns `true` if the basic conditions for Let's Encrypt are configured.
  ///
  /// - See: [letsEncrypt], [letsEncryptDirectory], [domainsRoots].
  bool get canUseLetsEncrypt {
    return letsEncrypt && letsEncryptDirectory != null && domains.isNotEmpty;
  }

  bool _started = false;

  /// Returns `true` if this servers is started.
  bool get isStarted => _started;

  bool _starting = false;

  /// Returns `true` if this instance is currently in the process of starting.
  bool get isStarting => _starting;

  Future<bool>? _startAsync;

  /// Starts this server.
  Future<bool> start() async {
    if (_started) return true;
    _started = true;
    _starting = true;

    return _startAsync = _startImpl().then((ok) {
      _starting = false;
      _startAsync = null;
      return ok;
    }, onError: (e, s) {
      _starting = false;
      _startAsync = null;
      _log.severe("Initialization error", e, s);
      throw e;
    });
  }

  Future<bool> _startImpl();

  Completer<bool>? _stopped;

  Completer<bool> get _stoppedCompleter => _stopped ??= Completer<bool>();

  /// Returns `true` if this server is closed.type
  ///
  /// A closed server can't processe new requests.
  bool get isStopped => _stopped?.isCompleted ?? false;

  /// Returns a [Future] that completes when this server stops.
  Future<bool> waitStopped() => _stoppedCompleter.future;

  bool _stopping = false;

  /// Stops/closes this server.
  Future<void> stop() async {
    if (!_started || _stopping || isStopped) return;
    _stopping = true;

    await _stopImpl();

    _stoppedCompleter.complete(true);
  }

  Future<void> _stopImpl();
}

/// An API HTTP Server
class APIServer extends _APIServerBase {
  APIServer(
    super.apiRoot,
    String address,
    int port, {
    super.name = 'Bones_API',
    super.version = BonesAPI.VERSION,
    super.securePort,
    super.letsEncrypt,
    super.letsEncryptProduction,
    super.allowRequestLetsEncryptCertificate,
    super.letsEncryptDirectory,
    super.hotReload,
    super.documentRoot,
    super.domains,
    super.cookieless,
    super.useSessionID,
    super.totalWorkers,
    super.apiCacheControl,
    super.staticFilesCacheControl,
    super.cacheStaticFilesResponses,
    super.serverResponseDelay,
    super.logToConsole,
    super.logQueue,
  }) : super(address: address, port: port);

  APIServer.fromConfig(super.apiRoot, super.serverConfig) : super.fromConfig();

  APIServer.fromArgs(super.apiRoot, super.args) : super.fromArgs();

  final List<APIServerWorker> _auxiliaryWorkers = [];

  late final APIServerWorker _mainWorker;

  @override
  Future<bool> _startImpl() async {
    var mainWorker = _createWorker(0);

    var auxiliaryWorkers = <APIServerWorker>[];
    var totalAuxiliaryWorkers = totalWorkers - 1;

    if (totalAuxiliaryWorkers >= 1) {
      auxiliaryWorkers =
          List.generate(totalAuxiliaryWorkers, (i) => _createWorker(i + 1));
    }

    _mainWorker = mainWorker;

    assert(_auxiliaryWorkers.isEmpty);
    _auxiliaryWorkers.addAll(auxiliaryWorkers);

    Map<APIServerWorker, (Isolate?, PortListener?, SendPort?, Future<bool>?)>?
        workersSpawns;

    if (totalAuxiliaryWorkers >= 1) {
      _log.info("Spawning $totalAuxiliaryWorkers parallel workers...");

      workersSpawns = await _auxiliaryWorkers
          .map((e) => MapEntry(e, e.spawnIsolate()))
          .toMapFromEntries()
          .resolveAllValues();

      _log.info("Spawned $totalAuxiliaryWorkers parallel workers.");
    }

    var mainOK = await mainWorker.start();

    if (!mainOK) {
      _log.severe("Can't start main `APIServerWorker`> $this");
      return false;
    }

    if (workersSpawns != null) {
      for (var e in workersSpawns.entries) {
        var worker = e.key;
        var workerSpawn = e.value;
        var spawnPortListener = workerSpawn.$2;
        var resumePort = workerSpawn.$3;

        var ok = false;
        if (spawnPortListener != null && resumePort != null) {
          var confirmedAsync = spawnPortListener.next();
          resumePort.send("resume");
          var confirmed = await confirmedAsync;
          ok = confirmed == 'confirm';
        }

        if (!ok) {
          _log.severe(
              "Can't start #${worker.workerIndex}/$totalWorkers `APIServerWorker`> $this");

          return false;
        }
      }
    }

    await _log.flushMessages(delay: Duration(milliseconds: 50));

    return true;
  }

  APIServerWorker _createWorker(int workerIndex) {
    return APIServerWorker(
      workerIndex,
      apiRoot,
      address: address,
      domains: domainsRoots,
      apiCacheControl: apiCacheControl,
      staticFilesCacheControl: staticFilesCacheControl,
      cacheStaticFilesResponses: cacheStaticFilesResponses,
      staticFilesCacheMaxMemorySize: staticFilesCacheMaxMemorySize,
      staticFilesCacheMaxContentLength: staticFilesCacheMaxContentLength,
      letsEncryptDirectory: letsEncryptDirectory,
      securePort: securePort,
      useSessionID: useSessionID,
      logToConsole: this.logToConsole,
      logQueue: logQueue,
      port: port,
      letsEncrypt: letsEncrypt,
      letsEncryptProduction: letsEncryptProduction,
      allowRequestLetsEncryptCertificate: allowRequestLetsEncryptCertificate,
      name: name,
      version: version,
      hotReload: hotReload,
      cookieless: cookieless,
      totalWorkers: totalWorkers,
      serverResponseDelay: serverResponseDelay,
    );
  }

  @override
  Future<void> _stopImpl() async {
    for (var worker in _auxiliaryWorkers) {
      await worker.stop();
    }

    await _mainWorker.stop();
  }

  /// Converts a [request] to an [APIRequest].
  static FutureOr<APIRequest> toAPIRequest(Request request,
      {required bool cookieless, required bool useSessionID}) {
    var requestTime = DateTime.now();

    var method = parseAPIRequestMethod(request.method) ?? APIRequestMethod.GET;

    var headers = Map.fromEntries(request.headersAll.entries.map((e) {
      var values = e.value;
      return MapEntry(e.key, values.length == 1 ? values[0] : values);
    }));

    if (cookieless) {
      headers.remove('cookie');
    }

    var requestedUri = request.requestedUri;

    var path = requestedUri.path;
    var parameters =
        Map.fromEntries(requestedUri.queryParametersAll.entries.map((e) {
      var values = e.value;
      return MapEntry(e.key, values.length == 1 ? values[0] : values);
    }));

    var scheme = request.requestedUri.scheme;

    var connectionInfo = _getConnectionInfo(request);
    var requesterAddress = connectionInfo?.remoteAddress.address;

    var requesterSource = requesterAddress == null
        ? APIRequesterSource.unknown
        : (_isLocalAddress(requesterAddress)
            ? APIRequesterSource.local
            : APIRequesterSource.remote);

    String? sessionID;
    bool newSession = false;

    if (useSessionID && !cookieless) {
      var cookies = _parseCookies(request);
      if (cookies != null && cookies.isNotEmpty) {
        sessionID = cookies['SESSIONID'] ?? cookies['SESSION_ID'];
      }

      if (sessionID == null) {
        sessionID = APISession.generateSessionID();
        newSession = true;
      }
    }

    var keepAlive = false;

    if (request.protocolVersion == '1.1') {
      var headerConnection = headers[HttpHeaders.connectionHeader];
      if (headerConnection != null) {
        keepAlive = equalsIgnoreAsciiCase('$headerConnection', 'Keep-Alive');
      }
    }

    var credential = _resolveCredential(request);

    var parsingDuration = DateTime.now().difference(requestTime);

    return _resolvePayload(request).resolveMapped((payloadResolved) {
      var mimeType = payloadResolved?.$1;
      var payload = payloadResolved?.$2;

      Map<String, dynamic> parametersResolved;

      if (mimeType != null && payload != null && mimeType.isFormURLEncoded) {
        var payloadMap = payload as Map<String, dynamic>;

        parametersResolved = parameters.isEmpty
            ? payloadMap
            : <String, dynamic>{...parameters, ...payloadMap};

        payload = null;
        mimeType = null;
      } else {
        parametersResolved = Map<String, dynamic>.from(parameters);
      }

      var req = APIRequest(method, path,
          protocol: 'HTTP/${request.protocolVersion}',
          keepAlive: keepAlive,
          parameters: parametersResolved,
          requesterSource: requesterSource,
          requesterAddress: requesterAddress,
          headers: headers,
          sessionID: sessionID,
          newSession: newSession,
          credential: credential,
          scheme: scheme,
          requestedUri: request.requestedUri,
          originalRequest: request,
          payload: payload,
          payloadMimeType: mimeType,
          time: requestTime,
          parsingDuration: parsingDuration);

      return req;
    });
  }

  static Map<String, String>? _parseCookies(Request request) {
    var headerCookies = request.headersAll['cookie'];
    if (headerCookies == null || headerCookies.isEmpty) return null;

    var cookies = <String, String>{};

    for (var line in headerCookies) {
      for (var c in line.split(';')) {
        var idx = c.indexOf('=');
        if (idx > 0) {
          var k = c.substring(0, idx).trim();
          var v = c.substring(idx + 1).trim();
          cookies[k] = v;
        }
      }
    }

    return cookies;
  }

  static final MimeType _mimeTypeTextPlain =
      MimeType.parse(MimeType.textPlain)!;

  static Future<(MimeType, Object)?> _resolvePayload(Request request) {
    var contentLength = request.contentLength;

    var contentMimeType = _resolveContentMimeType(request);
    if (contentLength == null && contentMimeType == null) {
      return Future.value(null);
    }

    var mimeType = contentMimeType ?? _mimeTypeTextPlain;

    if (mimeType.isStringType) {
      return _resolvePayloadFromString(mimeType, request);
    } else {
      return _resolvePayloadBytes(mimeType, request);
    }
  }

  static MimeType? _resolveContentMimeType(Request request) {
    var contentType = request.headers[HttpHeaders.contentTypeHeader];

    var mimeType = MimeType.parse(contentType);

    if (mimeType == null) {
      var requestedUri = request.requestedUri;
      mimeType = _resolveMimeTypeByExtension(requestedUri.path);

      mimeType ??= requestedUri.queryParameters.entries
          .map((e) => _resolveMimeTypeByExtension(e.value))
          .nonNulls
          .firstOrNull;
    }

    return mimeType;
  }

  static MimeType? _resolveMimeTypeByExtension(String? path) {
    if (path == null || path.isEmpty) return null;

    var idx = path.lastIndexOf('.');
    if (idx < 0) return null;

    var ext = path.substring(idx + 1);
    return MimeType.byExtension(ext, defaultAsApplication: false);
  }

  static Future<(MimeType, Object)?> _resolvePayloadFromString(
          MimeType mimeType, Request request) =>
      _loadPayloadString(mimeType, request).then((s) {
        if (s == null) return null;

        Object payload = s;
        if (mimeType.isJSON) {
          payload = json.decode(s);
        } else if (mimeType.isFormURLEncoded) {
          payload = decodeQueryStringParameters(s, charset: mimeType.charset);
        }

        return (mimeType, payload);
      });

  static Future<String?> _loadPayloadString(
          MimeType mimeType, Request request) =>
      request.read().toList().then((bs) {
        var allBytes = _loadPayloadBytes(bs);

        var encoding = mimeType.charsetEncoding ?? utf8;

        try {
          return encoding.decode(allBytes);
        } catch (_) {
          return latin1.decode(allBytes);
        }
      });

  static Future<(MimeType, Uint8List)?> _resolvePayloadBytes(
          MimeType mimeType, Request request) =>
      request.read().toList().then((bs) {
        var allBytes = _loadPayloadBytes(bs);
        return (mimeType, allBytes);
      });

  static Uint8List _loadPayloadBytes(List<List<int>> payloadBlocks) {
    Uint8List bytes;

    if (payloadBlocks.length == 1) {
      final bs0 = payloadBlocks[0];
      if (bs0 is Uint8List) {
        bytes = bs0;
      } else {
        bytes = Uint8List.fromList(bs0);
      }

      assert(bytes.length == bs0.length);
    } else {
      var allBytesSz = payloadBlocks.map((e) => e.length).sum;

      bytes = Uint8List(allBytesSz);
      var bytesOffset = 0;

      for (var i = 0; i < payloadBlocks.length; ++i) {
        var l = payloadBlocks[i];
        var lng = l.length;

        bytes.setRange(bytesOffset, bytesOffset + lng, l);
        bytesOffset += lng;
      }

      assert(bytesOffset == allBytesSz);
    }

    return bytes;
  }

  static final RegExp _regExpSpace = RegExp(r'\s+');

  static APICredential? _resolveCredential(Request request) {
    var headerAuthorization = request.headers.getIgnoreCase('Authorization');
    if (headerAuthorization == null) return null;

    var idx = headerAuthorization.indexOf(_regExpSpace);
    if (idx <= 0) return null;

    var credentialType =
        headerAuthorization.substring(0, idx).trim().toLowerCase();
    var credential = headerAuthorization.substring(idx + 1).trim();

    if (credentialType == 'basic') {
      var decoded = base64.decode(credential);
      var decodedStr = utf8.decode(decoded);
      var idx2 = decodedStr.indexOf(':');

      var username = decodedStr.substring(0, idx2);
      var password = decodedStr.substring(idx2 + 1);

      return APICredential(username, passwordHash: password);
    } else if (credentialType == 'bearer') {
      return APICredential('', token: credential);
    } else if (credentialType == 'digest') {
      throw UnsupportedError('Unsupported `Authorization` type: digest');
    }

    return null;
  }

  static bool _isLocalAddress(String address) =>
      address == '127.0.0.1' ||
      address == '0.0.0.0' ||
      address == '::1' ||
      address == '::';

  static HttpConnectionInfo? _getConnectionInfo(Request request) {
    var val = request.context['shelf.io.connection_info'];
    return val is HttpConnectionInfo ? val : null;
  }

  static final String headerXAccessToken = "X-Access-Token";
  static final String headerXAccessTokenExpiration =
      "X-Access-Token-Expiration";

  static final String exposeHeaders =
      "Content-Length, Content-Type, Last-Modified, $headerXAccessToken, $headerXAccessTokenExpiration";

  static void setCORS(APIRequest request, APIResponse response) {
    var origin = getOrigin(request);

    var localhost = false;

    if (origin.isEmpty) {
      response.headers[HttpHeaders.accessControlAllowOriginHeader] = "*";
    } else {
      response.headers[HttpHeaders.accessControlAllowOriginHeader] = origin;

      if (origin.contains("://localhost:") ||
          origin.contains("://127.0.0.1:") ||
          origin.contains("://::1")) {
        localhost = true;
      }
    }

    response.headers[HttpHeaders.accessControlAllowMethodsHeader] =
        "GET,HEAD,PUT,POST,PATCH,DELETE,OPTIONS";

    response.headers[HttpHeaders.accessControlAllowCredentialsHeader] = "true";

    if (localhost) {
      response.headers[HttpHeaders.accessControlAllowHeadersHeader] =
          "Content-Type, Access-Control-Allow-Headers, Authorization, x-ijt";
    } else {
      response.headers[HttpHeaders.accessControlAllowHeadersHeader] =
          "Content-Type, Access-Control-Allow-Headers, Authorization";
    }

    response.headers[HttpHeaders.accessControlExposeHeadersHeader] =
        exposeHeaders;
  }

  static String getOrigin(APIRequest request) {
    var origin = request.headers['origin'];
    if (origin != null) return origin;

    var host = request.headers[HttpHeaders.hostHeader];
    if (host != null) {
      var scheme = request.requestedUri.scheme;

      origin = "$scheme://$host/";
      return origin;
    }

    origin = "http://localhost/";
    return origin;
  }

  /// Resolves a [payload] to an HTTP body (accepts [payload] as a [Future]).
  /// See [resolveBodySync].
  static FutureOr<Object?> resolveBody(
      dynamic payload, APIResponse apiResponse) {
    if (payload == null) return null;

    if (payload is Future) {
      return payload.then((value) {
        return resolveBody(value, apiResponse);
      }, onError: (e, s) {
        return apiResponse.asError(error: 'ERROR: $e\n$s');
      });
    }

    return _resolveBodyImpl(payload, apiResponse);
  }

  /// Resolves a [payload] to an HTTP body (Does NOT accept [payload] as a [Future]).
  /// See [resolveBody].
  static Object? resolveBodySync(dynamic payload, APIResponse apiResponse) {
    if (payload == null) return null;

    if (payload is Future) {
      throw ArgumentError(
          "`payload` can't be a `Future`. Use `resolveBody` for asynchronous call.");
    }

    return _resolveBodyImpl(payload, apiResponse);
  }

  static Object? _resolveBodyImpl(Object payload, APIResponse apiResponse) {
    var apiRequestMethod = apiResponse.apiRequest?.method;

    if (apiRequestMethod == APIRequestMethod.HEAD) {
      return null;
    }

    if (payload is String) {
      apiResponse.payloadMimeType ??=
          resolveBestTextMimeType(payload, apiResponse.payloadFileExtension);
      return payload;
    }

    if (payload is List<int> &&
        !(apiResponse.payloadMimeType?.isJSON ?? false)) {
      apiResponse.payloadMimeType ??= lookupMimeType(
              apiResponse.payloadFileExtension ?? 'bytes',
              headerBytes: payload) ??
          'application/octet-stream';
      return payload;
    }

    if (payload is Stream<List<int>>) {
      apiResponse.payloadMimeType ??=
          lookupMimeType(apiResponse.payloadFileExtension ?? 'bytes') ??
              'application/octet-stream';

      return payload;
    }

    if (payload is DateTime || payload is Time) {
      apiResponse.payloadMimeType ??=
          lookupMimeType(apiResponse.payloadFileExtension ?? 'text') ??
              'text/plain';
      return payload.toString();
    }

    try {
      var s = _jsonEncodePayload(apiResponse, payload);
      apiResponse.payloadMimeType ??= 'application/json';
      return s;
    } catch (e) {
      var s = payload.toString();
      apiResponse.payloadMimeType ??=
          resolveBestTextMimeType(s, apiResponse.payloadFileExtension);
      return s;
    }
  }

  static String _jsonEncodePayload(APIResponse<dynamic> apiResponse, payload) {
    final apiRequest = apiResponse.apiRequest;

    if (apiRequest != null) {
      final routeHandler = apiRequest.routeHandler;

      if (routeHandler != null) {
        var accessRules = routeHandler.entityAccessRules;

        if (!accessRules.isInnocuous) {
          return Json.encode(payload,
              toEncodableProvider: (o) => accessRules.toJsonEncodable(
                  apiRequest, Json.defaultToEncodableJsonProvider(), o));
        }
      }
    }

    return Json.encode(payload, toEncodable: ReflectionFactory.toJsonEncodable);
  }

  static final RegExp _htmlTag = RegExp(r'<\w+.*?>');

  static String resolveBestTextMimeType(String text, [String? fileExtension]) {
    if (fileExtension != null && fileExtension.isNotEmpty) {
      var mimeType = lookupMimeType(fileExtension);
      if (mimeType != null) {
        return mimeType;
      }
    }

    if (text.contains('<')) {
      if (_htmlTag.hasMatch(text)) {
        return 'text/html';
      }
    }

    return 'text/plain';
  }

  @override
  String toString() {
    var serverResponseDelayStr = serverResponseDelay != null
        ? ', serverResponseDelay: ${serverResponseDelay!.toStringUnit()}'
        : '';

    var domainsStr = domainsRoots.isNotEmpty
        ? ', domains: [${domainsRoots.entries.map((e) {
            var key = e.key;
            var val = e.value;

            return '${key is RegExp ? 'r/${key.pattern}/' : '`$key`'}=${val.path}';
          }).join(' ; ')}]'
        : '';

    var secureStr = securePort < 10
        ? ''
        : ', securePort: $securePort, '
            'letsEncrypt: $letsEncrypt'
            '${(letsEncrypt ? (letsEncryptProduction ? ' @production' : ' @staging') : '')}, '
            'letsEncryptDirectory: ${letsEncryptDirectory?.path}';

    return 'APIServer{ apiRoot: ${apiRoot.name}[${apiRoot.version}] (${apiRoot.runtimeTypeNameUnsafe}), address: $address, port: $port$serverResponseDelayStr$secureStr, totalWorkers: $totalWorkers, cacheStaticFilesResponses: $cacheStaticFilesResponses, hotReload: $hotReload (${APIHotReload.get().isEnabled ? 'enabled' : 'disabled'}), cookieless: $cookieless, SESSIONID: $useSessionID, started: $isStarted, stopped: $isStopped$domainsStr }';
  }

  /// Creates an [APIServer] with [apiRoot].
  static APIServer create(APIRoot apiRoot,
      [List<String> args = const <String>[], int argsOffset = 0]) {
    if (argsOffset > args.length) {
      argsOffset = args.length;
    }

    if (argsOffset > 0) {
      args = args.sublist(argsOffset);
    }

    String address;
    int port;
    var hotReload = false;
    String? configFile;

    if (args.isEmpty) {
      address = 'localhost';
      port = 8080;
    } else if (args.length == 1) {
      var a = args[0];
      var p = int.tryParse(a);

      if (p != null) {
        if (p >= 80) {
          address = 'localhost';
          port = p;
        } else {
          address = '$p';
          port = 8080;
        }
      } else {
        address = a;
        port = 8080;
      }
    } else {
      address = _parseArg(args, 'address', 'a', 'localhost', 0);
      port = int.parse(_parseArg(args, 'port', 'p', '8080', 1));

      var hotReloadStr =
          _parseArg(args, 'hotreload', 'r', 'false', 2, flag: true)
              .toLowerCase();

      hotReload = hotReloadStr == 'true' || hotReloadStr == 'hotreload';

      configFile = _parseArg(args, 'config', 'i', 'api-local.yaml', 3);
    }

    if (configFile != null) {
      var apiConfig = APIConfig.fromSync(configFile);
      if (apiConfig != null) {
        apiRoot.apiConfig = apiConfig;
      }
    }

    var apiServer = APIServer(apiRoot, address, port, hotReload: hotReload);

    return apiServer;
  }

  /// Runs [apiRoot] and returns the [APIServer].
  static Future<APIServer> run(APIRoot apiRoot, List<String> args,
      {int argsOffset = 0, bool verbose = false}) async {
    var apiServer = create(apiRoot, args, argsOffset);

    await apiServer.start();

    if (verbose) {
      print('\nRunning: $apiServer\n');
      print('${apiRoot.apiConfig}\n');
      print('URL: ${apiServer.apiInfoURL}\n');
    }

    return apiServer;
  }

  static String _parseArg(
      List<String> args, String name, String abbrev, String def, int index,
      {bool flag = false}) {
    if (args.isEmpty) return def;

    for (var i = 0; i < args.length; ++i) {
      var a = args[i];

      if (i < args.length - 1 &&
          (a == '--$name' || a == '-$name' || a == '-$abbrev')) {
        if (!flag) {
          var v = args[i + 1];
          return v;
        } else {
          return 'true';
        }
      }
    }

    if (index < args.length) {
      var val = args[index];
      if (val.startsWith('-')) return def;

      if (index > 0) {
        var prev = args[index - 1];
        return prev.startsWith('-') ? def : val;
      } else {
        return val;
      }
    }

    return def;
  }

  static String resolveServerTiming(Map<String, APIMetric> metrics) {
    var s = StringBuffer();

    for (var e in metrics.entries) {
      var metric = e.value;

      if (s.isNotEmpty) {
        s.write(', ');
      }

      s.write(e.key);

      var duration = metric.duration;
      if (duration != null) {
        s.write(';dur=');
        var ms = duration.inMicroseconds / 1000;
        s.write(ms);
      }

      var description = metric.description;
      if (description != null &&
          description.isNotEmpty &&
          !description.contains('"')) {
        s.write(';desc="');
        s.write(description);
        s.write('"');
      }

      var n = metric.n;
      if (n != null) {
        s.write(';int=');
        s.write(n);
      }
    }

    return s.toString();
  }
}

final class APIServerWorker extends _APIServerBase {
  static final _log = logging.Logger('APIServerWorker');

  final int workerIndex;

  bool get isMainWorker => workerIndex == 0;

  bool get isAuxiliaryWorker => !isMainWorker;

  APIServerWorker(
    this.workerIndex,
    super.apiRoot, {
    required super.name,
    required super.version,
    super.address,
    super.port,
    super.securePort,
    super.domains,
    super.letsEncryptDirectory,
    super.letsEncrypt,
    super.letsEncryptProduction,
    super.allowRequestLetsEncryptCertificate,
    super.hotReload,
    super.totalWorkers,
    super.cookieless,
    super.useSessionID,
    super.apiCacheControl,
    super.staticFilesCacheControl,
    super.cacheStaticFilesResponses,
    super.staticFilesCacheMaxMemorySize,
    super.staticFilesCacheMaxContentLength,
    super.serverResponseDelay,
    super.logToConsole,
    super.logQueue,
  }) {
    _configureAPIRoot(apiRoot);
  }

  void _configureAPIRoot(APIRoot apiRoot) {
    apiRoot.posApiRequestHandlers.add(_handleStaticFiles);
  }

  FutureOr<APIResponse<T>?> _handleStaticFiles<T>(
      APIRoot apiRoot, APIRequest apiRequest) {
    if (domainsRoots.isEmpty) return null;

    for (var e in domainsRoots.entries) {
      if (apiRequest.matchesHostname(e.key)) {
        return _serveFile<T>(apiRequest, e.value);
      }
    }

    return null;
  }

  FutureOr<APIResponse<T>> _serveFile<T>(
      APIRequest apiRequest, Directory rootDirectory) {
    var staticHandler = _getDirectoryStaticHandler(rootDirectory);

    return staticHandler(apiRequest.toRequest())
        .resolveMapped((response) => _APIResponseStaticFile<T>(response));
  }

  final Map<String, Handler> _directoriesStaticHandlers = <String, Handler>{};

  Handler _getDirectoryStaticHandler(Directory rootDirectory) =>
      _directoriesStaticHandlers[rootDirectory.path] ??=
          _createDirectoryHandler(rootDirectory);

  APIServerResponseCache? _responseCache;

  Handler _createDirectoryHandler(Directory rootDirectory) {
    rootDirectory = Directory(pack_path.normalize(rootDirectory.absolute.path));

    var pipeline = const Pipeline();

    var gzipCompressionLevel = 4;

    if (cacheStaticFilesResponses) {
      var responseCache = _responseCache = APIServerResponseCache(
        maxMemorySize: staticFilesCacheMaxMemorySize,
        maxContentLength: staticFilesCacheMaxContentLength,
      );

      pipeline = pipeline.addMiddleware(responseCache.middleware);

      // Allow higher compression if the `Response`s are being cached:
      gzipCompressionLevel = 7;
    }

    pipeline = pipeline
        .addMiddleware(createGzipMiddleware(
          compressionLevel: gzipCompressionLevel,
          addCompressionRatioHeader: true,
          addServerTiming: true,
        ))
        .addMiddleware((innerHandler) =>
            _staticFilesHeadersMiddleware(rootDirectory, innerHandler));

    var handler = pipeline.addHandler(
        createStaticHandler(rootDirectory.path, defaultDocument: 'index.html'));

    return handler;
  }

  Handler _staticFilesHeadersMiddleware(
          Directory rootDirectory, Handler innerHandler) =>
      (request) {
        return Future.sync(() => innerHandler(request)).then((response) =>
            _configureStaticFilesHeaders(rootDirectory, request, response));
      };

  Response _configureStaticFilesHeaders(
      Directory rootDirectory, Request request, Response response) {
    var statusCode = response.statusCode;
    if (statusCode < 200 || statusCode > 299) {
      return response.change(
        context: _buildResponseContext(rootDirectory, request, response),
      );
    }

    var headers = <String, String>{};
    headers[HttpHeaders.cacheControlHeader] = staticFilesCacheControl;

    headers[HttpHeaders.serverHeader] ??= serverName;

    return response.change(
      headers: headers,
      context: _buildResponseContext(rootDirectory, request, response),
    );
  }

  Map<String, Object>? _buildResponseContext(
      Directory rootDirectory, Request request, Response response) {
    var fileResolved = _resolveStaticFile(rootDirectory, request, response);
    if (fileResolved == null) return null;

    var file = fileResolved.file;
    var fileNotFound = fileResolved.fileNotFound;

    return {
      if (file != null) 'file': file,
      if (fileNotFound != null) 'file_not_found': fileNotFound,
    };
  }

  ({File? file, File? fileNotFound})? _resolveStaticFile(
      Directory rootDirectory, Request request, Response response) {
    final responseContext = response.context;

    var contextFile = responseContext['shelf_static:file'];
    var contextFileNotFound = responseContext['shelf_static:file_not_found'];

    if (contextFile is File) {
      return (file: contextFile, fileNotFound: null);
    } else if (contextFileNotFound is File) {
      return (file: null, fileNotFound: contextFileNotFound);
    }

    var filePath = pack_path.join(rootDirectory.path, request.url.path);
    filePath = pack_path.normalize(filePath);

    var file = File(filePath).absolute;
    var stat = file.statSync();
    var fileFound = false;

    if (stat.type == FileSystemEntityType.file) {
      fileFound = true;
    } else if (stat.type == FileSystemEntityType.directory) {
      var file2 = File(pack_path.join(file.path, 'index.html'));
      var stat2 = file2.statSync();

      if (stat2.type == FileSystemEntityType.file) {
        file = file2;
        fileFound = true;
      }
    }

    if (!pack_path.isWithin(rootDirectory.path, file.path)) {
      return null;
    }

    if (fileFound) {
      return (file: file, fileNotFound: null);
    } else {
      return (file: null, fileNotFound: file);
    }
  }

  bool get hasMultipleWorkers => totalWorkers > 1;

  String get workerDebugName => 'APIServerWorker#$id';

  Future<(Isolate?, PortListener?, SendPort?, Future<bool>?)>
      spawnIsolate() async {
    if (_started) {
      return (null, null, null, null);
    }

    final workerDebugName = this.workerDebugName;

    var spawnPort = ReceivePort('$workerDebugName:spawnPort');

    var spawnPortListener = PortListener(spawnPort);

    var resumePortAsync = spawnPortListener.next();

    final isolate = await Isolate.spawn(
      _isolateInit,
      (worker: this, mainWorkerPort: spawnPort.sendPort),
      debugName: workerDebugName,
    );

    var exitPort = ReceivePort();
    var completer = Completer<bool>();
    exitPort.listen((_) => completer.complete(true));
    isolate.addOnExitListener(exitPort.sendPort);

    SendPort resumePort = await resumePortAsync;

    return (isolate, spawnPortListener, resumePort, completer.future);
  }

  static void _isolateInit(
      ({APIServerWorker worker, SendPort mainWorkerPort}) params) async {
    final worker = params.worker;
    final mainWorkerPort = params.mainWorkerPort;

    final workerDebugName = worker.workerDebugName;

    var resumePort = ReceivePort('$workerDebugName:resumePort');

    _log.info("Waiting main `APIServerWorker` to start...");

    var resumeAsync = resumePort.first;
    mainWorkerPort.send(resumePort.sendPort);
    var resume = await resumeAsync;

    assert(resume == 'resume');

    await worker.start();

    mainWorkerPort.send("confirm");
  }

  static const _logSectionOpen =
      '\n<<<<<======================================================================<<<<<';
  static const _logSectionClose =
      '\n>>>>>======================================================================>>>>>';

  late HttpServer _httpServer;

  HttpServer? _httpSecureServer;

  @override
  Future<bool> _startImpl() async {
    var appliedProps = apiConfig?.applyProperties();

    if (this.logToConsole) {
      _log.handler.logToConsole();

      _log.info("Activated `logToConsole` from `APIServer`.");
    }

    if (!logQueue) {
      LoggerHandler.disableLogQueue();

      _log.info("Disabled `LoggerHandler` flush queue.");
    }

    {
      var isLoggingAll = LoggerHandler.getLogAllTo() != null;
      var isLoggingToConsole = LoggerHandler.getLogToConsole();
      var isLoggingError = LoggerHandler.root.getLogErrorTo() != null;
      var isLoggingDB = LoggerHandler.root.getLogDbTo() != null;

      _log.info(
          "LOGGING> toConsole: $isLoggingToConsole ; all: $isLoggingAll ; error: $isLoggingError ; db: $isLoggingDB");
    }

    if (appliedProps != null && appliedProps.isNotEmpty) {
      _log.info("Applied properties to `APIPlatform`:");
      for (var e in appliedProps.entries) {
        _log.info("  -- ${e.key}: ${e.value}");
      }
    }

    _log.info("Starting...$_logSectionOpen");

    return _startImpl2().then((ok) {
      _log.info("Started: ${ok ? 'OK' : 'Fail'}$_logSectionClose");

      return _log.flushMessages().then((_) => ok);
    });
  }

  Future<bool> _startImpl2() async {
    if (isAuxiliaryWorker) {
      DBAdapter.enableAuxiliaryMode();
    }

    if (canUseLetsEncrypt) {
      await _startLetsEncrypt();
    } else {
      await _startNormal();
    }

    if (hotReload) {
      await APIHotReload.get().enable();
    }

    if (cookieless) {
      _log.info('Cookieless Server: all cookies disabled! (NO `SESSIONID`)');
    } else if (useSessionID) {
      _log.info('Using `SESSIONID` cookies.');
    }

    var workerInfo = totalWorkers > 1
        ? '[${isMainWorker ? 'main' : 'auxiliary'} worker#$workerIndex/$totalWorkers]'
        : '';

    _log.info('Started HTTP Server$workerInfo at: $address:$port');

    _log.info('Initializing APIRoot$workerInfo `${apiRoot.name}`...');

    return apiRoot.ensureInitialized().then((result) {
      var modules = apiRoot.modules;
      _log.info('Loaded modules: ${modules.map((e) => e.name).toList()}');

      if (!result.ok) {
        _log.severe('Error loading APIRoot: ${apiRoot.name}');
      }

      return result.ok;
    });
  }

  Future<void> _startNormal() async {
    try {
      _httpServer = await shelf_io.serve(
        _process,
        address,
        port,
        shared: hasMultipleWorkers,
      );
    } catch (e, s) {
      _log.severe("Can't start `APIServer` at: $address:$port", e, s);
      rethrow;
    }

    _configureServer(_httpServer);
  }

  void _configureServer(HttpServer server) {
    // Enable built-in [HttpServer] gzip:
    server.autoCompress = true;
  }

  void _letsEncryptLogger(
      String level, Object? message, Object? error, StackTrace? stackTrace) {
    switch (level) {
      case 'INFO':
        {
          _logLetsEncrypt.info(message, error, stackTrace);
        }
      case 'WARNING':
        {
          _logLetsEncrypt.warning(message, error, stackTrace);
        }
      case 'ERROR':
        {
          _logLetsEncrypt.severe(message, error, stackTrace);
        }
      default:
        {
          var logLevel = logging.Level.LEVELS.firstWhereOrNull(
                  (e) => equalsIgnoreAsciiCase(e.name, level)) ??
              logging.Level.INFO;

          _logLetsEncrypt.log(logLevel, message, error, stackTrace);
        }
    }
  }

  Future<void> _startLetsEncrypt() async {
    var letsEncryptDirectory = this.letsEncryptDirectory;

    if (letsEncryptDirectory == null) {
      throw StateError("Let's Encrypt directory not set!");
    } else if (!letsEncryptDirectory.existsSync()) {
      throw StateError(
          "Let's Encrypt directory doesn't exists: $letsEncryptDirectory");
    }

    _log.info("Let's Encrypt directory: ${letsEncryptDirectory.path}");

    final certificatesHandler = CertificatesHandlerIO(letsEncryptDirectory);

    final LetsEncrypt letsEncrypt = LetsEncrypt(certificatesHandler,
        production: letsEncryptProduction, log: _letsEncryptLogger);

    var pipeline = const Pipeline().addMiddleware(_redirectToHttpsMiddleware);

    var handler = pipeline.addHandler(_process);

    final domains = this.domains;

    var domain = domains.first;
    var domainEmail = 'contact@$domain';

    _log.info("Let's Encrypt domain: $domain");

    if (!allowRequestLetsEncryptCertificate) {
      _log.warning("NOT allowed to request Let's Encrypt certificates!");
    }

    var servers = await letsEncrypt.startSecureServer(
      handler,
      {domain: domainEmail},
      port: port,
      securePort: securePort,
      bindingAddress: address,
      requestCertificate: allowRequestLetsEncryptCertificate,
      shared: hasMultipleWorkers,
    );

    var server = servers[0]; // HTTP Server.
    var secureServer = servers[1]; // HTTPS Server.

    _httpServer = server;
    _httpSecureServer = secureServer;

    _configureServer(server);
    _configureServer(secureServer);
  }

  Handler _redirectToHttpsMiddleware(Handler innerHandler) {
    return (request) {
      var requestedUri = request.requestedUri;

      if (requestedUri.scheme == 'http' &&
          !requestedUri.path.contains('/.well-known/acme-challenge/')) {
        final domains = this.domains;
        if (domains.contains(requestedUri.host)) {
          var secureUri = requestedUri.replace(scheme: 'https');
          return Response.seeOther(secureUri);
        }
      }

      return innerHandler(request);
    };
  }

  @override
  Future<void> _stopImpl() async {
    apiRoot.close();

    await _httpServer.close();

    if (_httpSecureServer != null) {
      await _httpSecureServer!.close();
    }

    _responseCache?.clear();
  }

  FutureOr<Response> _process(Request request) {
    APIRequest? apiRequest;
    try {
      return APIServer.toAPIRequest(request,
              cookieless: cookieless, useSessionID: useSessionID)
          .resolveMapped((apiReq) {
        apiRequest = apiReq;
        return _processAPIRequest(request, apiReq);
      });
    } catch (e, s) {
      return _errorProcessing(request, apiRequest, e, s);
    }
  }

  FutureOr<Response> _processAPIRequest(
      Request request, APIRequest apiRequest) {
    if (_starting) {
      return _processWhileInitializing(request, apiRequest);
    }

    try {
      if (apiRequest.method == APIRequestMethod.OPTIONS) {
        return _processOPTIONSRequest(request, apiRequest);
      } else {
        return _processCall(request, apiRequest);
      }
    } catch (e, s) {
      return _errorProcessing(request, apiRequest, e, s);
    }
  }

  static const initializationTimeout = Duration(seconds: 20);

  FutureOr<Response> _processWhileInitializing(
      Request request, APIRequest apiRequest) {
    final startAsync = _startAsync;

    // If is starting and there's no `_startAsync`,
    // he server failed to initialize and to handle its error.
    if (startAsync == null) {
      return Response.internalServerError(body: 'Server not available.');
    }

    return startAsync
        .timeout(initializationTimeout, onTimeout: () => false)
        .then((ok) {
      if (ok && !_starting) {
        apiRequest.setMetric('APIServerWorker-initialization',
            duration: apiRequest.elapsedTime);
        return _processAPIRequest(request, apiRequest);
      }

      return Response(
        HttpStatus.serviceUnavailable,
        body: 'Server is still initializing. Please try again later.',
      );
    });
  }

  Response _errorProcessing(
      Request request, APIRequest? apiRequest, Object error, StackTrace stack) {
    var requestStr = apiRequest ?? _requestToString(request);

    var message = 'ERROR processing request:\n\n$requestStr';
    _log.severe(message, error, stack);

    return Response.internalServerError(body: '$message\n\n$error\n$stack');
  }

  String _requestToString(Request request) {
    var s = StringBuffer();
    s.write('METHOD: ');
    s.write(request.method);
    s.write('\n');

    s.write('URI: ');
    s.write(request.requestedUri);
    s.write('\n');

    if (request.contentLength != null) {
      s.write('Content-Length: ');
      s.write(request.contentLength);
      s.write('\n');
    }

    s.write('HEADERS:\n');
    for (var e in request.headers.entries) {
      s.write('  - ');
      s.write(e.key);
      s.write(': ');
      s.write(e.value);
      s.write('\n');
    }

    return s.toString();
  }

  FutureOr<Response> _processOPTIONSRequest(
      Request request, APIRequest apiRequest) {
    APIResponse apiResponse;

    if (!apiRoot.acceptsRequest(apiRequest)) {
      apiResponse = APIResponse.notFound();
    } else {
      apiResponse = APIResponse.ok('');
    }

    return _processAPIResponse(request, apiRequest, apiResponse);
  }

  FutureOr<Response> _processCall(Request request, APIRequest apiRequest) {
    FutureOr<APIResponse> apiResponse;

    try {
      apiResponse = apiRoot.call(apiRequest);
      if (apiResponse is Future<APIResponse>) {
        apiResponse = apiResponse.catchError((e, s) {
          return APIResponse.error(error: e, stackTrace: s);
        });
      }
    } catch (e, s) {
      apiResponse = APIResponse.error(error: e, stackTrace: s);
    }

    return apiResponse
        .resolveMapped((res) => _processAPIResponse(request, apiRequest, res));
  }

  FutureOr<Response> _processAPIResponse(
      Request request, APIRequest apiRequest, APIResponse apiResponse) {
    APIServer.setCORS(apiRequest, apiResponse);

    if (apiResponse is _APIResponseStaticFile) {
      return apiResponse.fileResponse;
    }

    var headers = <String, Object>{};

    if (!apiResponse.hasCORS) {
      apiResponse.setCORS(apiRequest);
    }

    if (apiResponse.requiresAuthentication) {
      var type = apiResponse.authenticationType;
      if (type == null || type.trim().isEmpty) {
        type = 'Basic';
      }

      var realm = apiResponse.authenticationRealm;
      if (realm == null || type.trim().isEmpty) {
        realm = 'API';
      }

      headers[HttpHeaders.wwwAuthenticateHeader] = '$type realm="$realm"';
    }

    for (var e in apiResponse.headers.entries) {
      var value = e.value;
      if (value != null) {
        headers[e.key] = value;
      }
    }

    headers[HttpHeaders.serverHeader] ??= serverName;

    if (apiRequest.newSession && !cookieless) {
      var setSessionID = 'SESSIONID=${apiRequest.sessionID}';
      headers.setMultiValue(HttpHeaders.setCookieHeader, setSessionID,
          ignoreCase: true);
    }

    var authentication = apiRequest.authentication;
    if (authentication != null) {
      var tokenKey = authentication.tokenKey;

      if (authentication.resumed ||
          _needToSendHeaderXAccessToken(headers, tokenKey)) {
        headers.setMultiValue('X-Access-Token', tokenKey, ignoreCase: true);
      }
    }

    headers[HttpHeaders.cacheControlHeader] = apiCacheControl;

    headers['X-API-Server-Worker'] = '$workerIndex/$totalWorkers';

    // headers['X-APIToken'] = apiRequest.credential?.token ?? '?';

    var retPayload = APIServer.resolveBody(apiResponse.payload, apiResponse);

    final serverResponseDelay = this.serverResponseDelay;
    if (serverResponseDelay != null && !serverResponseDelay.isNegative) {
      final retPayloadOrig = retPayload;

      _log.info(
          "[DEV] Response #${apiRequest.id} delayed in ${serverResponseDelay.toStringUnit()}: ${apiRequest.requestedUri}");

      retPayload = Future.delayed(serverResponseDelay, () async {
        var payload = await retPayloadOrig;
        return payload;
      });
    }

    return retPayload.resolveMapped((payload) {
      if (payload is APIResponse) {
        var apiResponse2 = payload;

        return APIServer.resolveBody(apiResponse2.payload, apiResponse2)
            .resolveMapped((payload2) {
          var response = _sendAPIResponse(
              request, apiRequest, apiResponse2, headers, payload2);

          apiResponse.disposeAsync();

          return _processResponse(apiRequest, apiResponse2, request, response);
        });
      } else {
        var response = _sendAPIResponse(
            request, apiRequest, apiResponse, headers, payload);

        return _processResponse(apiRequest, apiResponse, request, response);
      }
    });
  }

  FutureOr<Response> _processResponse(APIRequest apiRequest,
      APIResponse apiResponse, Request request, Response response) {
    apiResponse.disposeAsync();
    apiRequest.disposeAsync();

    if (!acceptsGzipEncoding(request)) {
      return response;
    } else {
      return gzipEncodeResponse(
        response,
        addCompressionRatioHeader: true,
        addServerTiming: true,
      );
    }
  }

  bool _needToSendHeaderXAccessToken(
      Map<String, Object> headers, String tokenKey) {
    var headerAuthorization = headers.getFirstValue('authorization');
    var notSentByAuthentication =
        headerAuthorization == null || !headerAuthorization.contains(tokenKey);

    var headerAccessToken =
        headers.getMultiValue('x-access-token', ignoreCase: true);
    var notSentByAccessToken =
        headerAccessToken == null || !headerAccessToken.contains(tokenKey);

    var needToSendHeaderXAccessToken =
        notSentByAuthentication && notSentByAccessToken;

    return needToSendHeaderXAccessToken;
  }

  Response _sendAPIResponse(Request request, APIRequest apiRequest,
      APIResponse apiResponse, Map<String, Object> headers, Object? payload) {
    _setTransactionsMetrics(apiRequest, apiResponse);

    apiResponse.setMetric('API-call', duration: apiRequest.elapsedTime);

    var parsingDuration = apiRequest.parsingDuration;
    if (parsingDuration != null) {
      apiResponse.setMetric('API-request-parsing', duration: parsingDuration);
    }

    apiRequest.stopAllMetrics();
    apiResponse.stopAllMetrics();

    var contentType = apiResponse.payloadMimeType;
    if (contentType != null) {
      headers[HttpHeaders.contentTypeHeader] = contentType.toString();
    }

    var etag = apiResponse.payloadETag;
    if (etag != null) {
      headers[HttpHeaders.etagHeader] = etag.toString();
    }

    var cacheControl = apiResponse.cacheControl;
    if (cacheControl != null) {
      headers[HttpHeaders.cacheControlHeader] = cacheControl.toString();
    }

    if (apiRequest.keepAlive && !apiResponse.isBadRequest) {
      var timeout = apiResponse.keepAliveTimeout.inSeconds.clamp(0, 3600);
      var max = apiResponse.keepAliveMaxRequests.clamp(0, 1000000);

      headers[HttpHeaders.connectionHeader] = 'Keep-Alive';
      headers['keep-alive'] = 'timeout=$timeout, max=$max';
    }

    var allMetrics = apiRequest.hasMetrics
        ? CombinedMapView([apiRequest.metrics, apiResponse.metrics])
        : apiResponse.metrics;

    headers['server-timing'] = APIServer.resolveServerTiming(allMetrics);

    if (cookieless) {
      headers.remove(HttpHeaders.setCookieHeader);
      headers['X-Cookieless-Server'] = 'Blocking all cookies';
    }

    switch (apiResponse.status) {
      case APIResponseStatus.OK:
        return Response.ok(payload, headers: headers);
      case APIResponseStatus.NOT_FOUND:
        return Response.notFound(payload, headers: headers);
      case APIResponseStatus.NOT_MODIFIED:
        {
          headers.remove('content-length');
          return Response.notModified(headers: headers);
        }
      case APIResponseStatus.UNAUTHORIZED:
        {
          var wwwAuthenticate =
              headers.getAsString('WWW-Authenticate', ignoreCase: true);

          if (wwwAuthenticate != null && wwwAuthenticate.isNotEmpty) {
            return Response(401, body: payload, headers: headers);
          } else {
            return Response.forbidden(payload, headers: headers);
          }
        }
      case APIResponseStatus.REDIRECT:
        {
          var location = apiResponse.payload;
          if (location is! Uri) {
            return Response(400, body: "Invalid redirect URL: $location");
          }

          var body =
              "<html><body>Redirecting to: <a href='$location'>$location</a></body></html>";

          headers[HttpHeaders.locationHeader] = location.toString();
          headers[HttpHeaders.contentTypeHeader] = 'text/html';

          return Response(307, body: body, headers: headers);
        }
      case APIResponseStatus.BAD_REQUEST:
        return Response(400, body: payload, headers: headers);
      case APIResponseStatus.ERROR:
        {
          var error = apiResponse.error ?? '';
          var stackTrace = apiResponse.stackTrace;

          _log.severe('500 Internal Server Error', error, stackTrace);

          var errorContent = stackTrace != null ? '$error\n$stackTrace' : error;

          var retError = APIServer.resolveBodySync(errorContent, apiResponse);

          headers[HttpHeaders.contentTypeHeader] ??= 'text/plain';

          return Response.internalServerError(body: retError, headers: headers);
        }
      default:
        return Response.notFound('NOT FOUND[${request.method}]: ${request.url}',
            headers: headers);
    }
  }

  void _setTransactionsMetrics(
      APIRequest apiRequest, APIResponse<dynamic> apiResponse) {
    var transactions = apiRequest.transactions;
    if (transactions.isEmpty) return;

    var total = Duration.zero;

    if (transactions.length > 50) {
      transactions = transactions.toList();
      transactions.sort((t1, t2) {
        var d1 = t1.duration ?? Duration.zero;
        var d2 = t2.duration ?? Duration.zero;
        return d2.compareTo(d1);
      });
      transactions = transactions.sublist(0, 50);
    }

    for (var t in transactions) {
      var duration = t.duration;
      if (duration != null) {
        apiResponse.setMetric('Transaction#${t.id}',
            duration: duration, description: t.info);
        total = total + duration;
      }
    }

    apiResponse.setMetric('All-Transactions',
        duration: total, n: transactions.length);
  }

  @override
  String toString() {
    var domainsStr = domainsRoots.isNotEmpty
        ? ', domains: [${domainsRoots.entries.map((e) {
            var key = e.key;
            var val = e.value;

            return '${key is RegExp ? 'r/${key.pattern}/' : '`$key`'}=${val.path}';
          }).join(' ; ')}]'
        : '';

    var secureStr = securePort < 10
        ? ''
        : ', securePort: $securePort, '
            'letsEncrypt: $letsEncrypt'
            '${(letsEncrypt ? (letsEncryptProduction ? ' @production' : ' @staging') : '')}, '
            'letsEncryptDirectory: ${letsEncryptDirectory?.path}';

    return 'APIServerWorker{ apiRoot: ${apiRoot.name}[${apiRoot.version}] (${apiRoot.runtimeTypeNameUnsafe}), address: $address, port: $port$secureStr, cacheStaticFilesResponses: $cacheStaticFilesResponses, hotReload: $hotReload (${APIHotReload.get().isEnabled ? 'enabled' : 'disabled'}), cookieless: $cookieless, SESSIONID: $useSessionID, started: $isStarted, stopped: $isStopped$domainsStr }';
  }
}

extension _FileStatExtension on FileStat {
  bool get canWrite => modeString().contains('w');
}

class _APIResponseStaticFile<T> extends APIResponse<T> {
  Response fileResponse;

  _APIResponseStaticFile(this.fileResponse)
      : super(parseAPIResponseStatus(fileResponse.statusCode) ??
            APIResponseStatus.NOT_FOUND);
}

extension _APIRequestExtension on APIRequest {
  Request toRequest() {
    var originalRequest = this.originalRequest;
    if (originalRequest is Request) {
      return originalRequest;
    }

    return Request(method.name, requestedUri);
  }
}
