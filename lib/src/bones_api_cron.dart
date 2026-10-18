import 'dart:math' as math;

import 'package:meta/meta_meta.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:timezone/timezone.dart' as tz;

import 'bones_api_base.dart';
import 'bones_api_cron_expression.dart';

/// Parses a [Duration] from a config value: a number of seconds, or a string
/// with a unit suffix: `ms`, `s`, `m`, `h` or `d` (e.g. `30s`, `5m`, `1h`).
///
/// Returns [def] if [value] is `null` or invalid.
Duration? parseCronDuration(Object? value, [Duration? def]) {
  if (value == null) return def;
  if (value is Duration) return value;
  if (value is num) return Duration(milliseconds: (value * 1000).round());

  var s = value.toString().trim().toLowerCase();
  if (s.isEmpty) return def;

  var m = RegExp(r'^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)?$').firstMatch(s);
  if (m == null) return def;

  var n = double.parse(m.group(1)!);
  var unitMs = switch (m.group(2)) {
    'ms' => 1,
    'm' => 60 * 1000,
    'h' => 60 * 60 * 1000,
    'd' => 24 * 60 * 60 * 1000,
    _ => 1000,
  };

  return Duration(milliseconds: (n * unitMs).round());
}

/// The retry policy of the calls of an [APICronJob].
///
/// A call is retried after an [APIResponseStatus.ERROR] response or a thrown
/// error, up to [attempts] (the first call included), waiting [delayFor]
/// between attempts (or the response `Retry-After` header, in seconds, at
/// most [maxDelay]). [APIResponseStatus.UNAUTHORIZED],
/// [APIResponseStatus.BAD_REQUEST] and [APIResponseStatus.NOT_FOUND] are not
/// retried (retrying won't change them). A call slower than
/// [APICronJob.timeout] is not retried: it's waited for (see
/// [APICronJob.timeout]).
class APICronRetry {
  static const APICronRetry defaultRetry = APICronRetry();

  /// No retries: a single attempt.
  static const APICronRetry none = APICronRetry(attempts: 1);

  /// The maximum attempts of a call (the first call included).
  final int attempts;

  /// The delay before the 2nd attempt.
  final Duration initialDelay;

  /// The factor applied to the delay for each next attempt.
  final double multiplier;

  /// The maximum delay between attempts.
  final Duration maxDelay;

  const APICronRetry({
    this.attempts = 3,
    this.initialDelay = const Duration(seconds: 30),
    this.multiplier = 4,
    this.maxDelay = const Duration(minutes: 15),
  });

  /// The delay before the attempt after [attempt] (`1` is the first call):
  /// `initialDelay × multiplier^(attempt-1)`, at most [maxDelay].
  Duration delayFor(int attempt) {
    if (attempt < 1) attempt = 1;
    var ms = initialDelay.inMilliseconds * math.pow(multiplier, attempt - 1);
    var maxMs = maxDelay.inMilliseconds;
    return Duration(milliseconds: ms > maxMs ? maxMs : ms.round());
  }

  /// Returns `true` if a call with [response] can be retried.
  bool isRetryable(APIResponse response) =>
      response.status == APIResponseStatus.ERROR;

  /// Applies [config] (`attempts`, `initial_delay`, `multiplier`,
  /// `max_delay`) over this instance.
  APICronRetry withConfig(Map? config) {
    if (config == null || config.isEmpty) return this;
    return APICronRetry(
      attempts: parseInt(config['attempts']) ?? attempts,
      initialDelay: parseCronDuration(
        config['initial_delay'] ?? config['initialDelay'],
        initialDelay,
      )!,
      multiplier: parseDouble(config['multiplier']) ?? multiplier,
      maxDelay: parseCronDuration(
        config['max_delay'] ?? config['maxDelay'],
        maxDelay,
      )!,
    );
  }

  @override
  String toString() =>
      'APICronRetry{attempts: $attempts, initialDelay: $initialDelay, multiplier: $multiplier, maxDelay: $maxDelay}';
}

/// A route of the API called on a cron [schedule] by the
/// [APICronScheduler].
///
/// - The route is called with an internal system authentication
///   ([APIAuthentication.system]) and the headers [headerJob],
///   [headerScheduledAt], [headerRun] and [headerAttempt].
/// - While the response has an `X-Continuation` header
///   ([APIResponse.continuation]) the route is called again with the
///   parameter `continuation`, up to [maxCalls] calls per run.
/// - Failed calls are retried by [retry].
class APICronJob {
  static const String headerJob = 'X-Cron-Job';
  static const String headerScheduledAt = 'X-Cron-Scheduled-At';
  static const String headerRun = 'X-Cron-Run';
  static const String headerAttempt = 'X-Cron-Attempt';

  /// The parameter with the continuation token of the previous call.
  static const String parameterContinuation = 'continuation';

  /// The unique name of this job.
  final String name;

  final CronExpression schedule;

  /// The IANA time zone of the [schedule] (e.g. `Europe/Paris`). `null`:
  /// `UTC`.
  final String? timeZone;

  /// The route request method.
  final APIRequestMethod method;

  /// The route path (e.g. `/module/route`).
  final String path;

  final Map<String, dynamic> parameters;

  final Object? payload;

  final bool enabled;

  /// The expected maximum duration of a call: a slower call is logged (a
  /// warning every [timeout] while it's still running). A route can't be
  /// cancelled: the call is waited for (never retried or overlapped while
  /// running), so the job never runs in parallel, and its result is used.
  final Duration timeout;

  /// The maximum calls of a run (continuations included).
  final int maxCalls;

  /// How late (after its scheduled time) an occurrence still runs: a missed
  /// occurrence older than it is not run.
  final Duration maxLateness;

  /// The lease of the job lock, renewed while running: if the instance
  /// running it stops, another instance takes the run over after it.
  final Duration leaseDuration;

  final APICronRetry retry;

  /// The location of [timeZone], resolved on first use (loading the time
  /// zones database only when needed: not while the routes are configured,
  /// nor with the scheduler disabled). Throws an [ArgumentError] for an
  /// unknown time zone (see [validate]).
  late final tz.Location location = resolveCronTimeZone(timeZone);

  /// Validates what is resolved lazily ([location]). Throws an
  /// [ArgumentError] if invalid.
  void validate() => location;

  APICronJob({
    required this.name,
    required Object schedule,
    required this.path,
    this.timeZone,
    this.method = APIRequestMethod.GET,
    Map<String, dynamic>? parameters,
    this.payload,
    this.enabled = true,
    this.timeout = const Duration(minutes: 5),
    this.maxCalls = 100,
    this.maxLateness = const Duration(days: 1),
    this.leaseDuration = const Duration(minutes: 5),
    this.retry = APICronRetry.defaultRetry,
  }) : schedule = schedule is CronExpression
           ? schedule
           : CronExpression.parse(schedule.toString()),
       parameters = Map<String, dynamic>.unmodifiable(parameters ?? const {}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Empty');
    }
    if (maxCalls < 1) {
      throw ArgumentError.value(maxCalls, 'maxCalls', 'Not positive');
    }
    // A zero lease would let another instance take the lock (and run the
    // job in parallel) at once:
    for (var (n, d) in [
      ('timeout', timeout),
      ('maxLateness', maxLateness),
      ('leaseDuration', leaseDuration),
    ]) {
      if (d <= Duration.zero) {
        throw ArgumentError.value(d, n, 'Not positive');
      }
    }
    if (retry.attempts < 1) {
      throw ArgumentError.value(retry.attempts, 'retry.attempts', '< 1');
    }
  }

  /// The next occurrence after [from].
  tz.TZDateTime? nextAfter(DateTime from) => schedule.nextAfter(from, location);

  /// The latest occurrence not after [to].
  tz.TZDateTime? previousBefore(DateTime to) =>
      schedule.previousBefore(to, location);

  /// A copy of this job with [config] applied (the `cron.jobs.<name>`
  /// config): `schedule`, `time_zone`, `method`, `path`, `parameters`,
  /// `enabled`, `timeout`, `max_calls`, `max_lateness`, `lease_duration`,
  /// `retry` and `attempts` (over the attempts of `retry`).
  APICronJob withConfig(Map? config) {
    if (config == null || config.isEmpty) return this;
    return APICronJob.fromConfig(name, config, base: this);
  }

  /// A job from [config] (the `cron.jobs.<name>` config), over [base] if
  /// given. Without a [base], `schedule` and `path` are required.
  factory APICronJob.fromConfig(String name, Map config, {APICronJob? base}) {
    Object? get(String key, [String? key2]) =>
        config[key] ?? (key2 != null ? config[key2] : null);

    var schedule = get('schedule')?.toString() ?? base?.schedule.expression;
    var path = get('path')?.toString() ?? base?.path;

    if (schedule == null || path == null) {
      throw ArgumentError(
        'Cron job `$name` config without `schedule` or `path`: $config',
      );
    }

    var parameters = get('parameters');

    var retryConfig = get('retry');
    var retry = (base?.retry ?? APICronRetry.defaultRetry).withConfig(
      retryConfig is Map ? retryConfig : null,
    );

    var attempts = parseInt(get('attempts'));
    if (attempts != null) {
      retry = retry.withConfig({'attempts': attempts});
    }

    return APICronJob(
      name: name,
      schedule: schedule,
      path: path,
      timeZone: get('time_zone', 'timeZone')?.toString() ?? base?.timeZone,
      method:
          parseAPIRequestMethod(get('method')?.toString()) ??
          base?.method ??
          APIRequestMethod.GET,
      parameters: parameters is Map
          ? parameters.map((k, v) => MapEntry('$k', v))
          : base?.parameters,
      payload: get('payload') ?? base?.payload,
      enabled: parseBool(get('enabled')) ?? base?.enabled ?? true,
      timeout: parseCronDuration(
        get('timeout'),
        base?.timeout ?? const Duration(minutes: 5),
      )!,
      maxCalls: parseInt(get('max_calls', 'maxCalls')) ?? base?.maxCalls ?? 100,
      maxLateness: parseCronDuration(
        get('max_lateness', 'maxLateness'),
        base?.maxLateness ?? const Duration(days: 1),
      )!,
      leaseDuration: parseCronDuration(
        get('lease_duration', 'leaseDuration'),
        base?.leaseDuration ?? const Duration(minutes: 5),
      )!,
      retry: retry,
    );
  }

  /// `true` if [config] (a `cron.jobs.<name>` config) defines a whole job
  /// (`schedule` and `path`), not only overrides of a job of the code.
  static bool isFullConfig(Map config) =>
      config['schedule'] != null && config['path'] != null;

  @override
  String toString() =>
      'APICronJob{name: $name, schedule: $schedule, timeZone: ${timeZone ?? 'UTC'}, ${method.name} $path${enabled ? '' : ', disabled'}}';
}

/// Schedules an API route method to be called by the [APICronScheduler]
/// (see [APICronJob]).
///
/// With a cron expression ([APICron.new]) or by its fields ([APICron.at]):
///
/// ```dart
/// @APICron('30 23 * * *', timeZone: 'Europe/Paris')
/// Future<APIResponse<int>> updateRates(APIRequest request) async { ... }
///
/// @APICron.at(minute: '30', hour: '23', timeZone: 'Europe/Paris')
/// Future<APIResponse<int>> updateRates2(APIRequest request) async { ... }
/// ```
///
/// The job name defaults to `<module>.<route>` and can be overridden (or
/// disabled) by the `cron.jobs.<name>` config, which also overrides the
/// options of the annotation.
@Target({TargetKind.method})
class APICron {
  /// The cron expression (see [CronExpression]).
  final String schedule;

  /// The job name. Default: `<module>.<route>`.
  final String? name;

  final String? timeZone;

  final Map<String, dynamic>? parameters;

  final bool enabled;

  /// The maximum calls of a run. Default: `100`.
  final int? maxCalls;

  /// The maximum attempts of each call (overrides the attempts of [retry]).
  /// Default: `3`.
  final int? attempts;

  /// See [APICronJob.timeout]. Default: 5 minutes.
  final Duration? timeout;

  /// See [APICronJob.maxLateness]. Default: 1 day.
  final Duration? maxLateness;

  /// See [APICronJob.leaseDuration]. Default: 5 minutes.
  final Duration? leaseDuration;

  /// The retry policy. Default: [APICronRetry.defaultRetry].
  final APICronRetry? retry;

  /// A job on the cron expression [schedule] (5 fields:
  /// `minute hour day-of-month month day-of-week`, or a macro like
  /// `@daily`).
  const APICron(
    this.schedule, {
    this.name,
    this.timeZone,
    this.parameters,
    this.enabled = true,
    this.maxCalls,
    this.attempts,
    this.timeout,
    this.maxLateness,
    this.leaseDuration,
    this.retry,
  });

  /// A job on the schedule of the cron fields [minute], [hour],
  /// [dayOfMonth], [month] and [dayOfWeek] (each a cron field: `*`, a value,
  /// a list, a range or a step; default `*`).
  ///
  /// ```dart
  /// @APICron.at(minute: '*/15', hour: '9-18', dayOfWeek: 'MON-FRI')
  /// ```
  const APICron.at({
    String minute = '*',
    String hour = '*',
    String dayOfMonth = '*',
    String month = '*',
    String dayOfWeek = '*',
    this.name,
    this.timeZone,
    this.parameters,
    this.enabled = true,
    this.maxCalls,
    this.attempts,
    this.timeout,
    this.maxLateness,
    this.leaseDuration,
    this.retry,
  }) : schedule = '$minute $hour $dayOfMonth $month $dayOfWeek';

  /// The retry policy of the job: [retry], with [attempts] if given.
  APICronRetry get jobRetry {
    var retry = this.retry ?? APICronRetry.defaultRetry;
    var attempts = this.attempts;
    if (attempts == null || attempts == retry.attempts) return retry;
    return APICronRetry(
      attempts: attempts,
      initialDelay: retry.initialDelay,
      multiplier: retry.multiplier,
      maxDelay: retry.maxDelay,
    );
  }

  /// The [APICronJob] of the route [routeName] of the module [moduleName].
  APICronJob toJob(
    String moduleName,
    String routeName, [
    APIRequestMethod? method,
  ]) => APICronJob(
    name: name ?? '$moduleName.$routeName',
    schedule: schedule,
    timeZone: timeZone,
    path: '/$moduleName/$routeName',
    method: method ?? APIRequestMethod.GET,
    parameters: parameters,
    enabled: enabled,
    maxCalls: maxCalls ?? 100,
    timeout: timeout ?? const Duration(minutes: 5),
    maxLateness: maxLateness ?? const Duration(days: 1),
    leaseDuration: leaseDuration ?? const Duration(minutes: 5),
    retry: jobRetry,
  );

  @override
  String toString() => 'APICron{schedule: $schedule, name: $name}';
}

/// The `cron` section of the API config.
///
/// ```yaml
/// cron:
///   enabled: true
///   check_interval: 30s
///   history_days: 90
///   jobs:
///     <name>:
///       path: /module/route
///       schedule: "30 23 * * *"
///       time_zone: Europe/Paris
/// ```
class APICronConfig {
  final bool enabled;

  /// How often the scheduler checks the due jobs.
  final Duration checkInterval;

  /// The days the run history is kept (`0`: forever).
  final int historyDays;

  /// The `jobs` config, by job name.
  final Map<String, Map> jobs;

  const APICronConfig({
    this.enabled = false,
    this.checkInterval = const Duration(seconds: 30),
    this.historyDays = 90,
    this.jobs = const {},
  });

  factory APICronConfig.fromMap(Map? config) {
    if (config == null) return const APICronConfig();

    var jobs = config['jobs'];

    return APICronConfig(
      enabled: parseBool(config['enabled']) ?? false,
      checkInterval: parseCronDuration(
        config['check_interval'] ?? config['checkInterval'],
        const Duration(seconds: 30),
      )!,
      historyDays:
          parseInt(config['history_days'] ?? config['historyDays']) ?? 90,
      jobs: jobs is Map
          ? {
              for (var e in jobs.entries)
                if (e.value is Map) '${e.key}': e.value as Map,
            }
          : const {},
    );
  }

  @override
  String toString() =>
      'APICronConfig{enabled: $enabled, checkInterval: $checkInterval, historyDays: $historyDays, jobs: ${jobs.keys.toList()}}';
}
