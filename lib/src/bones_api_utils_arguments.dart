class Arguments {
  /// The positional arguments.
  List<String> args;

  /// The parameters (keys with `--` prefixes).
  Map<String, dynamic> parameters;

  /// The flags (keys with `--` prefixes and no values).
  Set<String> flags;

  /// The abbreviations used to [parse].
  Map<String, String> abbreviations;

  Arguments(this.args,
      {Map<String, dynamic>? parameters,
      Set<String>? flags,
      Map<String, String>? abbreviations})
      : parameters = parameters ?? <String, dynamic>{},
        flags = flags ?? <String>{},
        abbreviations = abbreviations ?? <String, String>{};

  /// The keys abbreviations.
  Map<String, String> get keysAbbreviations {
    var keysAbbrev = <String, String>{};

    for (var e in abbreviations.entries) {
      if (!keysAbbrev.containsKey(e.value)) {
        keysAbbrev[e.value] = e.key;
      }
    }

    return keysAbbrev;
  }

  /// Converts this instances to a [String] line.
  ///
  /// The inverse of [parseLine].
  String toArgumentsLine(
          {bool abbreviateFlags = true, bool abbreviateParameters = false}) =>
      toArgumentsList(
              abbreviateFlags: abbreviateFlags,
              abbreviateParameters: abbreviateParameters)
          .join(' ');

  /// Converts this instances to a [String] line.
  ///
  /// The inverse of [parse].
  List<String> toArgumentsList(
      {bool abbreviateFlags = true, bool abbreviateParameters = false}) {
    var arguments = <String>[];

    var keysAbbreviations = abbreviateFlags || abbreviateParameters
        ? this.keysAbbreviations
        : abbreviations;

    for (var f in flags) {
      if (abbreviateFlags) {
        var abbrev = keysAbbreviations[f];
        if (abbrev != null) {
          f = abbrev;
        }
      }
      arguments.add('-$f');
    }

    for (var e in parameters.entries) {
      var k = e.key;

      if (abbreviateParameters) {
        var abbrev = keysAbbreviations[k];
        if (abbrev != null) {
          k = abbrev;
        }
      }

      var v = e.value;

      if (v is Iterable) {
        for (var val in v) {
          arguments.add('--$k');
          arguments.add('$val');
        }
      } else {
        arguments.add('--$k');
        arguments.add('$v');
      }
    }

    return arguments;
  }

  @override
  String toString() {
    return 'Arguments{ args: $args, parameters: $parameters, flags: $flags }';
  }

  static final RegExp _regexpSpace = RegExp(r'\s+');

  /// Splits [argsLine] to a [List].
  static List<String> splitArgumentsLine(String argsLine) =>
      argsLine.split(_regexpSpace);

  /// Parses [argsLine].
  ///
  /// - See [parse].
  factory Arguments.parseLine(
    String argsLine, {
    Set<String>? flags,
    Map<String, String>? abbreviations,
    bool caseSensitive = false,
  }) {
    var args = splitArgumentsLine(argsLine);
    return Arguments.parse(args,
        flags: flags,
        abbreviations: abbreviations,
        caseSensitive: caseSensitive);
  }

  static final RegExp _namedParameter = RegExp(r'^--?(\w+)$');

  /// Parses [args].
  ///
  /// - [flags] the flags keys.
  /// - [abbreviations] the keys abbreviations.
  /// - [caseSensitive] if `false`, keys are `toLowerCase`.
  factory Arguments.parse(
    List<String> args, {
    Set<String>? flags,
    Map<String, String>? abbreviations,
    bool caseSensitive = false,
  }) {
    abbreviations ??= <String, String>{};

    var parsedParams = <String, dynamic>{};
    var parsedFlags = <String>{};

    for (var i = 0; i < args.length;) {
      var key = args[i];

      String? name;
      var flagName = false;

      if (key.startsWith('-')) {
        var match = _namedParameter.firstMatch(key);

        if (match != null) {
          name = match.group(1)!;

          if (!caseSensitive) {
            name = name.toLowerCase();
          }

          if (!key.startsWith('--')) {
            var name2 = abbreviations[name];
            if (name2 != null) {
              name = name2;
            } else if (i < args.length - 1) {
              var next = args[i + 1];
              var nextKey = _namedParameter.hasMatch(next);
              flagName = nextKey;
            } else {
              flagName = true;
            }
          }
        }
      }

      if (name != null) {
        if (flags != null && flags.contains(name)) {
          args.removeAt(i);
          parsedFlags.add(name);
        } else if (flagName) {
          args.removeAt(i);
          parsedFlags.add(name);
        } else if (i < args.length - 1) {
          var val = args.removeAt(i + 1);
          args.removeAt(i);
          _addToMap(parsedParams, name, val);
        } else {
          throw StateError('Should be a flag');
        }
      } else {
        ++i;
      }
    }

    return Arguments(args,
        parameters: parsedParams,
        flags: parsedFlags,
        abbreviations: abbreviations);
  }

  static void _addToMap(Map<String, dynamic> map, String key, String value) {
    if (map.containsKey(key)) {
      var prev = map[key];
      if (prev is List) {
        prev.add(value);
      } else {
        map[key] = [prev, value];
      }
    } else {
      map[key] = value;
    }
  }
}
