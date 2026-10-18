@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/bones_api_test_vm.dart';
import 'package:test/test.dart';

/// The calls of the cron routes: `(route, isSystem)`.
final List<(String, bool)> _calls = [];

class _SecureModule extends APIModule {
  _SecureModule(APIRoot apiRoot) : super(apiRoot, 'secure');

  @override
  void configure() {
    // Any authenticated caller (the scheduler passes it):
    routes.any('task', (request) {
      _calls.add(('task', request.authentication?.isSystem ?? false));
      return APIResponse.ok('task');
    }, rules: [const APIRouteAuthenticatedRule()]);

    // Only the scheduler (a system authentication):
    routes.any('cronOnly', (request) {
      var isSystem = request.authentication?.isSystem ?? false;
      _calls.add(('cronOnly', isSystem));
      if (!isSystem) return APIResponse.unauthorized();
      return APIResponse.ok('cron only');
    });
  }
}

class _CronServerAPIRoot extends APIRoot {
  _CronServerAPIRoot()
    : super(
        'cron-server-test',
        '1.0',
        apiConfig: {
          'cron': {
            'enabled': true,
            'check_interval': '1h',
            'jobs': {
              // Due at start (Jan 1st of this year):
              'task': {
                'path': '/secure/task',
                'schedule': '0 0 1 1 *',
                'max_lateness': '400d',
              },
              'cron-only': {
                'path': '/secure/cronOnly',
                'schedule': '0 0 1 1 *',
                'max_lateness': '400d',
              },
            },
          },
        },
      );

  @override
  Set<APIModule> loadModules() => {_SecureModule(this)};

  @override
  FutureOr<APICronStore> loadCronStore() => APICronStoreMemory();
}

Future<(int, String)> _get(String url, {Map<String, String>? headers}) async {
  var client = HttpClient();
  try {
    var req = await client.getUrl(Uri.parse(url));
    headers?.forEach(req.headers.set);
    var res = await req.close();
    var body = await utf8.decodeStream(res);
    return (res.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('APICronScheduler + APIServer', () {
    late _CronServerAPIRoot apiRoot;
    late APIServer apiServer;
    late String baseURL;

    setUpAll(() async {
      _calls.clear();

      var port = await resolveFreePort(6300);
      apiRoot = _CronServerAPIRoot();
      apiServer = APIServer(apiRoot, 'localhost', port, logToConsole: false);

      expect(await apiServer.start(), isTrue);
      baseURL = 'http://localhost:$port';
    });

    tearDownAll(() async {
      await apiServer.stop();
    });

    test('the scheduler runs the jobs at start, as the system', () async {
      var scheduler = (await apiRoot.cronSchedulerReady)!;
      expect(scheduler.isStarted, isTrue);

      for (var i = 0; i < 100 && _calls.length < 2; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      await scheduler.waitRunning();

      expect(_calls.toSet(), {('task', true), ('cronOnly', true)});

      var runs = [
        ...await scheduler.selectRuns('task'),
        ...await scheduler.selectRuns('cron-only'),
      ];
      expect(runs.map((r) => r.status).toSet(), {APICronRunStatus.succeeded});
    });

    test('HTTP clients can not act as the scheduler', () async {
      _calls.clear();

      var cronHeaders = {
        'X-Cron-Job': 'task',
        'X-Cron-Scheduled-At': DateTime.now().toIso8601String(),
        'X-Cron-Run': '1',
        'X-Cron-Attempt': '1',
      };

      // An authenticated route: refused without a real authentication, even
      // with the cron headers.
      var (status, _) = await _get(
        '$baseURL/secure/task',
        headers: cronHeaders,
      );
      expect(status, anyOf(HttpStatus.unauthorized, HttpStatus.forbidden));

      // A cron-only route: called, but not as the system.
      var (status2, _) = await _get(
        '$baseURL/secure/cronOnly',
        headers: cronHeaders,
      );
      expect(status2, anyOf(HttpStatus.unauthorized, HttpStatus.forbidden));
      expect(_calls, [('cronOnly', false)]);
    });

    test('the continuation header is exposed to HTTP clients', () {
      expect(APIResponse.exposeHeaders, contains('X-Continuation'));
    });

    test('stopping the server stops the scheduler', () async {
      var scheduler = apiRoot.cronScheduler!;
      await apiServer.stop();
      expect(scheduler.isStarted, isFalse);
      expect(apiRoot.cronScheduler, isNull);
    });
  });
}
