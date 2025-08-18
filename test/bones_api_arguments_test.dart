@TestOn('vm')
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

void main() {
  group('Arguments', () {
    setUp(() {});

    test('Arguments.parseLine 1', () async {
      var args = Arguments.parseLine('x -a 1 -b 2 -f');

      print(args);

      expect(args.parameters, equals({'a': '1', 'b': '2'}));
      expect(args.flags, equals({'f'}));
      expect(args.args, equals(['x']));

      expect(args.toArgumentsLine(), equals('-f --a 1 --b 2'));
    });

    test('Arguments.parseLine 2', () async {
      var args = Arguments.parseLine(
        '-a host -port 80 -v a b',
        abbreviations: {'a': 'address', 'v': 'verbose'},
        flags: {'verbose'},
      );

      expect(args.parameters, equals({'address': 'host', 'port': '80'}));
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));

      expect(args.toArgumentsLine(), equals('-v --address host --port 80'));
      expect(
        args.toArgumentsLine(abbreviateFlags: false),
        equals('-verbose --address host --port 80'),
      );

      expect(
        args.toArgumentsLine(
          abbreviateFlags: false,
          abbreviateParameters: true,
        ),
        equals('-verbose --a host --port 80'),
      );
    });

    test('Arguments.parseLine 3', () async {
      var args = Arguments.parseLine(
        '-a host -port 80 -list 1 -list 2 -v a b',
        abbreviations: {'a': 'address', 'v': 'verbose'},
        flags: {'verbose'},
      );

      expect(
        args.parameters,
        equals({
          'address': 'host',
          'port': '80',
          'list': ['1', '2'],
        }),
      );
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));
    });

    test('Arguments.parseLine 3', () async {
      var args = Arguments.parseLine(
        '-a host -port 80 -list 1 -list 2 -list 3 -v a b',
        abbreviations: {'a': 'address', 'v': 'verbose'},
        flags: {'verbose'},
      );

      expect(
        args.parameters,
        equals({
          'address': 'host',
          'port': '80',
          'list': ['1', '2', '3'],
        }),
      );
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));

      expect(
        args.toArgumentsLine(),
        equals('-v --address host --port 80 --list 1 --list 2 --list 3'),
      );
    });
  });
}
