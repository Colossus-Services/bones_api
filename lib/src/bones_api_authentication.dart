import 'dart:convert' as dart_convert;
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_extension.dart';
import 'bones_api_security.dart';
import 'bones_api_utils_json.dart';

/// Represents a authentication credential.
class APICredential {
  /// The username/email of this credential.
  final String username;

  /// The entity of the username.
  dynamic usernameEntity;

  /// The [APIPassword] of this credential.
  final APIPassword? password;

  /// The token of this credential.
  final String? token;

  APICredential(this.username,
      {this.token,
      String? passwordHash,
      APIPasswordHashAlgorithm? hashAlgorithm})
      : password = passwordHash != null
            ? APIPassword(passwordHash, hashAlgorithm: hashAlgorithm)
            : null;

  APICredential._(
      this.username, this.usernameEntity, this.password, this.token);

  static APICredential? fromMap(Map<String, dynamic>? map,
      {bool requiresUsernameAndPassword = false}) {
    if (map == null) {
      if (!requiresUsernameAndPassword) {
        return null;
      }

      map = {};
    }

    var username = map.getAsString('username', ignoreCase: true) ??
        map.getAsString('user', ignoreCase: true)?.trim();

    var password = map.getAsString('password', ignoreCase: true) ??
        map.getAsString('pass', ignoreCase: true)?.trim();

    if (requiresUsernameAndPassword) {
      if (password == null || password.isEmpty) {
        throw ArgumentError("Can't define `password` from passed `map`.");
      }

      if (username == null || username.isEmpty) {
        throw ArgumentError("Can't define `username` from passed `map`.");
      }
    } else {
      if (username == null) return null;
    }

    return APICredential(username, passwordHash: password);
  }

  /// Returns a copy of this [APICredential].
  APICredential copy(
          {bool withUsernameEntity = true,
          bool withPassword = true,
          bool withToken = true}) =>
      APICredential._(username, withUsernameEntity ? usernameEntity : null,
          withPassword ? password : null, withToken ? token : null);

  /// Returns a copy of this [APICredential] with [username].
  APICredential withUsername(String username) =>
      APICredential._(username, usernameEntity, password, token);

  /// Returns `true` if this [APICredential] has a [password].
  bool get hasPassword => password != null;

  /// Returns `true` if this [APICredential] has a [token].
  bool get hasToken => token != null && token!.isNotEmpty;

  /// Checks if the parameter [passwordOrHash] matches this [APICredential] [password].
  bool checkPassword(String? passwordOrHash) {
    if (passwordOrHash == null) return false;
    return password != null && password!.checkPassword(passwordOrHash);
  }

  /// Checks if the passed [credential] matches `this` credential's [username] and [password].
  bool checkCredential(APICredential? credential) {
    if (credential == null) return false;

    if (username != credential.username) return false;

    return !hasPassword || checkPassword(credential.password?.passwordHash);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is APICredential &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password &&
          token == other.token &&
          identical(usernameEntity, other.usernameEntity);

  @override
  int get hashCode => username.hashCode ^ password.hashCode ^ token.hashCode;

  @override
  String toString() {
    return 'APICredential{username: $username, ${hasToken ? 'token: $token' : 'password: $password'}';
  }
}

class APIPassword {
  /// The algorithm to hash this password.
  final APIPasswordHashAlgorithm hashAlgorithm;

  /// The hashed password.
  late String passwordHash;

  APIPassword(String passwordOrHash, {APIPasswordHashAlgorithm? hashAlgorithm})
      : hashAlgorithm = hashAlgorithm ??
            APIPasswordHashAlgorithm.detect(passwordOrHash) ??
            APIPasswordSHA256() {
    passwordHash = this.hashAlgorithm.ensureHashedPassword(passwordOrHash);
  }

  /// Checks if [passwordHash] matches this [passwordHash].
  bool checkPassword(String passwordOrHash) {
    return passwordHash == hashAlgorithm.ensureHashedPassword(passwordOrHash);
  }

  @override
  String toString() {
    return 'APIPassword{hashAlgorithm: ${hashAlgorithm.name}, passwordHash: ***}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is APIPassword &&
          runtimeType == other.runtimeType &&
          hashAlgorithm == other.hashAlgorithm &&
          passwordHash == other.passwordHash;

  @override
  int get hashCode => hashAlgorithm.hashCode ^ passwordHash.hashCode;
}

/// Base class for password hashing.
abstract class APIPasswordHashAlgorithm {
  /// Detects the hashing algorithm of [data] or return `null`.
  static APIPasswordHashAlgorithm? detect(String data) {
    var apiPasswordSHA256 = APIPasswordSHA256();
    if (apiPasswordSHA256.isHashedPassword(data)) {
      return apiPasswordSHA256;
    }

    return null;
  }

  /// Returns the name of this algorithm.
  String get name;

  /// Returns `true` if [passwordOrHash] is hashed with this algorithm.
  bool isHashedPassword(String passwordOrHash);

  /// Hashes [password] with this algorithm.
  String hashPassword(String password);

  /// Ensures that [passwordOrHash] is hashed with this algorithm.
  String ensureHashedPassword(String passwordOrHash) =>
      isHashedPassword(passwordOrHash)
          ? passwordOrHash
          : hashPassword(passwordOrHash);

  @override
  String toString() {
    return 'APIPasswordHashAlgorithm{$name}';
  }
}

/// Password hashing using `SHA-256`.
class APIPasswordSHA256 extends APIPasswordHashAlgorithm {
  static final APIPasswordSHA256 _instance = APIPasswordSHA256._();

  APIPasswordSHA256._();

  factory APIPasswordSHA256() => _instance;

  @override
  String get name => 'sha256';

  static final RegExp _regExpHEX = RegExp(r'^(?:[a-fA-F\d]{2})+$');

  @override
  bool isHashedPassword(String passwordOrHash) {
    return passwordOrHash.length == 64 && _regExpHEX.hasMatch(passwordOrHash);
  }

  @override
  String hashPassword(String password) {
    if (isHashedPassword(password)) {
      return password;
    }

    var bytes = dart_convert.utf8.encode(password);
    var digest = crypto.sha256.convert(bytes);
    var hash = digest.toString();

    return hash;
  }
}

/// Password without hashing.
/// This is marked as [Deprecated] to indicate to not use in production!
@Deprecated('Do not use in production')
class APIPasswordNotHashed extends APIPasswordHashAlgorithm {
  static final APIPasswordNotHashed _instance = APIPasswordNotHashed._();

  APIPasswordNotHashed._();

  factory APIPasswordNotHashed() => _instance;

  @override
  String get name => 'none';

  @override
  bool isHashedPassword(String passwordOrHash) {
    return false;
  }

  @override
  String hashPassword(String password) => password;
}

class APIAuthentication {
  final APIToken token;

  final List<APIPermission> permissions;

  final bool resumed;

  final dynamic data;

  APICredential? _credential;

  APIAuthentication(this.token,
      {List<APIPermission>? permissions,
      this.resumed = false,
      this.data,
      APICredential? credential})
      : permissions =
            List<APIPermission>.unmodifiable(permissions ?? <APIPermission>[]),
        _credential = credential;

  String get username => token.username;

  String get tokenKey => token.token;

  APICredential get credential =>
      _credential ?? APICredential(username, token: tokenKey);

  bool isExpired({DateTime? now}) => token.isExpired();

  List<APIPermission> enabledPermissions({DateTime? now}) {
    now ??= DateTime.now();
    return permissions.where((p) => p.isEnabled(now: now)).toList();
  }

  List<APIPermission> enabledPermissionsWhere(
      bool Function(APIPermission permission) test,
      {DateTime? now}) {
    return enabledPermissions(now: now).where(test).toList();
  }

  List<APIPermission> enabledPermissionsOfType(String type, {DateTime? now}) {
    now ??= DateTime.now();
    return permissions
        .where((p) => p.type == type && p.isEnabled(now: now))
        .toList();
  }

  List<APIPermission> enabledPermissionsOfTypes(Iterable<String> types,
      {DateTime? now}) {
    now ??= DateTime.now();
    return permissions
        .where((p) => types.contains(p.type) && p.isEnabled(now: now))
        .toList();
  }

  bool containsPermissionOfType(String type) =>
      enabledPermissionsOfType(type).isNotEmpty;

  APIPermission? firstPermissionOfType(String type) =>
      enabledPermissionsOfType(type).firstOrNull;

  Map<String, dynamic> toJson() => {
        'token': token.toJson(),
        if (permissions.isNotEmpty)
          'permissions': permissions.map((e) => e.toJson()).toList(),
        if (resumed) 'resumed': resumed,
        if (data != null)
          'data': Json.toJson(data, maskField: Json.standardJsonMaskField),
      };

  factory APIAuthentication.fromJson(Map json) {
    var token = APIToken.fromJson(json['token']);
    var permissions = APIPermission.listFromJson(json['permissions']);
    return APIAuthentication(token, permissions: permissions);
  }
}

class APIToken implements Comparable<APIToken> {
  static const List<String> tokenDefaultAlphabet = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  static List<String> tokenDefaultAlphabetPairsRandom = List.unmodifiable(
      tokenDefaultAlphabet
          .expand((a) => tokenDefaultAlphabet.map((b) => '$a$b'))
          .toList()
        ..shuffle());

  static final SecureRandom _advanceRandom = SecureRandom();

  static String generateToken(int length,
      {int variableLength = 0, String prefix = '', Random? random}) {
    random ??= SecureRandom();

    random.advance(maxSteps: 11, random: _advanceRandom);

    var alphabetLength = tokenDefaultAlphabet.length;

    if (variableLength > 0) {
      length += random.nextInt(variableLength);
      random.advance(maxSteps: 5, random: _advanceRandom);
    }

    var halfLength = length ~/ 2;

    var token = StringBuffer();

    while (token.length < halfLength) {
      var p = tokenDefaultAlphabetPairsRandom[random.nextInt(alphabetLength)];
      token.write(p);
    }

    random.advance(maxSteps: 11, random: _advanceRandom);

    while (token.length < length) {
      var p = tokenDefaultAlphabetPairsRandom[random.nextInt(alphabetLength)];
      token.write(p);
    }

    var fullToken = prefix.trim() + token.toString();
    return fullToken;
  }

  final String username;

  final String token;

  final DateTime issueTime;

  DateTime _accessTime = DateTime.now();

  final Duration duration;

  final String? refreshToken;

  APIToken(this.username,
      {String? token,
      DateTime? issueTime,
      Duration? duration,
      String? refreshToken,
      bool withRefreshToken = false})
      : token = token ?? generateToken(512, variableLength: 32, prefix: 'TK'),
        issueTime = issueTime ?? DateTime.now(),
        duration = duration ?? Duration(hours: 3),
        refreshToken = refreshToken == null && withRefreshToken
            ? generateToken(640, variableLength: 64, prefix: 'RTK')
            : refreshToken;

  DateTime get accessTime => _accessTime;

  void markAccessTime() => _accessTime = DateTime.now();

  DateTime get expireTime => issueTime.add(duration);

  bool isExpired({DateTime? now}) {
    now ??= DateTime.now();
    return now.compareTo(expireTime) > 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is APIToken &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          token == other.token;

  @override
  int get hashCode => username.hashCode ^ token.hashCode;

  @override
  int compareTo(APIToken other) => expireTime.compareTo(other.expireTime);

  @override
  String toString() {
    return 'APIToken{username: $username, issueTime: $issueTime, duration: $duration}';
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'token': token,
        'issueTime': issueTime,
        'duration': duration.inSeconds,
        'expireTime': expireTime,
        if (refreshToken != null) 'refreshToken': refreshToken,
      };

  factory APIToken.fromJson(Map json) => APIToken(
        json['username'],
        token: json['token'],
        issueTime: TypeParser.parseDateTime(json['issueTime']),
        duration: Duration(seconds: TypeParser.parseInt(json['issueTime'], 0)!),
        refreshToken: json['refreshToken'],
      );
}

extension APITokenExtension on List<APIToken> {
  List<APIToken> expiredTokens({DateTime? now}) {
    now ??= DateTime.now();
    return where((t) => t.isExpired(now: now)).toList();
  }

  List<APIToken> removeExpiredTokens({DateTime? now}) {
    var expired = expiredTokens(now: now);
    removeAll(expired);
    return expired;
  }
}

class APIPermission {
  static List<APIPermission> listFromJson(Object? json) {
    if (json == null) return <APIPermission>[];

    if (json is APIPermission) return <APIPermission>[json];

    if (json is List) {
      return json.map((e) => APIPermission.fromJson(e)).toList();
    }

    return <APIPermission>[];
  }

  static String normalizeType(String type) {
    return type.toLowerCase().trim();
  }

  static bool validateType(String type) {
    return normalizeType(type).isNotEmpty;
  }

  final String type;

  final bool enabled;

  final DateTime? initTime;

  final DateTime? endTime;

  final Map<String, Object> properties;

  APIPermission(String type,
      {this.enabled = true,
      this.initTime,
      this.endTime,
      Map<String, Object>? properties})
      : type = normalizeType(type),
        properties =
            Map<String, Object>.unmodifiable(properties ?? <String, Object>{}) {
    if (!validateType(type)) {
      throw ArgumentError('Invalid type: $type');
    }
  }

  APIPermission copy(
      {bool? enabled,
      DateTime? initTime,
      DateTime? endTime,
      Map<String, Object>? properties}) {
    return APIPermission(type,
        enabled: enabled ?? this.enabled,
        initTime: initTime ?? this.initTime,
        endTime: endTime ?? this.endTime,
        properties: properties ?? this.properties);
  }

  bool isEnabled({DateTime? now}) {
    if (!enabled) return false;

    if (initTime != null) {
      now ??= DateTime.now();
      if (now.compareTo(initTime!) < 0) {
        return false;
      }
    }

    if (endTime != null) {
      now ??= DateTime.now();
      if (now.compareTo(endTime!) > 0) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() {
    return 'APIPermission{type: $type, enabled: $enabled'
        '${initTime != null ? ', initTime: $initTime' : ''}'
        '${endTime != null ? ', endTime: $endTime' : ''}'
        '${properties.isNotEmpty ? ', properties: $properties' : ''}'
        '}';
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'enabled': enabled,
        if (initTime != null) 'initTime': initTime,
        if (endTime != null) 'endTime': endTime,
        if (properties.isNotEmpty) 'properties': properties,
      };

  factory APIPermission.fromJson(Map json) => APIPermission(
        json['type'],
        enabled: TypeParser.parseBool(json['enabled'], false)!,
        initTime: TypeParser.parseDateTime(json['initTime']),
        endTime: TypeParser.parseDateTime(json['endTime']),
        properties: TypeParser.parseMap(json['properties']),
      );
}
