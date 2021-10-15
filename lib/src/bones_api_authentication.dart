import 'dart:convert' as dart_convert;
import 'dart:math';

import 'package:bones_api/src/bones_api_security.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Represents a authentication credential.
class APICredential {
  /// The username/email of this credential.
  final String username;

  /// The entity of the username.
  dynamic usernameEntity;

  /// The [APIPassword] of this credential.
  final APIPassword? password;

  final String? token;

  APICredential(this.username,
      {this.token,
      String? passwordHash,
      APIPasswordHashAlgorithm? hashAlgorithm})
      : password = passwordHash != null
            ? APIPassword(passwordHash, hashAlgorithm: hashAlgorithm)
            : null;

  bool get hasPassword => password != null;

  bool get hasToken => token != null && token!.isNotEmpty;

  bool checkPassword(String? passwordOrHash) {
    if (passwordOrHash == null) return false;
    return password != null && password!.checkPassword(passwordOrHash);
  }

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

  static final RegExp _regExpHEX = RegExp(r'^(?:[0-9a-fA-F]{2})+$');

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

  APIAuthentication(this.token,
      {List<APIPermission>? permissions, this.resumed = false})
      : permissions =
            List<APIPermission>.unmodifiable(permissions ?? <APIPermission>[]);

  String get username => token.username;

  String get tokenKey => token.token;

  bool isExpired({DateTime? now}) => token.isExpired();

  List<APIPermission> enabledPermissions({DateTime? now}) {
    now ??= DateTime.now();
    return permissions.where((p) => p.isEnabled(now: now)).toList();
  }

  List<APIPermission> enabledPermissionsWhere(
      bool Function(APIPermission permission) test,
      {DateTime? now}) {
    return enabledPermissions(now: now).where((p) => test(p)).toList();
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
        'token': token,
        'permissions': permissions,
        if (resumed) 'resumed': resumed,
      };
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

  static final SecureRandom _advanceRandom = SecureRandom();

  static String generateToken(int length,
      {int variableLength = 0, String prefix = '', Random? random}) {
    random ??= SecureRandom();

    random.advance(maxSteps: 11, random: _advanceRandom);

    var token = StringBuffer();

    var alphabetLength = tokenDefaultAlphabet.length;

    if (variableLength > 0) {
      length += random.nextInt(variableLength);
      random.advance(maxSteps: 5, random: _advanceRandom);
    }

    var halfLength = length ~/ 2;

    while (token.length < halfLength) {
      var c = tokenDefaultAlphabet[random.nextInt(alphabetLength)];
      token.write(c);
    }

    random.advance(maxSteps: 11, random: _advanceRandom);

    while (token.length < length) {
      var c = tokenDefaultAlphabet[random.nextInt(alphabetLength)];
      token.write(c);
    }

    var fullToken = prefix.trim() + token.toString();
    return fullToken;
  }

  final String username;

  final String token;

  final DateTime issueTime;

  DateTime _accessTime = DateTime.now();

  final Duration duration;

  APIToken(this.username,
      {String? token, DateTime? issueTime, Duration? duration})
      : token = token ?? generateToken(512, variableLength: 32, prefix: 'TK'),
        issueTime = issueTime ?? DateTime.now(),
        duration = Duration(hours: 3);

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
      };
}

class APIPermission {
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
}