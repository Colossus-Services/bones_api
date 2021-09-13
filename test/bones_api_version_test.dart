@TestOn('vm')

import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';
import 'dart:io';

import 'package:path/path.dart' as path;

void main() {
  group('Bones_API.VERSION', () {
    setUp(() {});

    test('Check Version', () async {
      var projectDirectory = Directory.current;

      print(projectDirectory);

      var pubspecFile = File(path.join(projectDirectory.path, 'pubspec.yaml'));

      print('pubspecFile: $pubspecFile');

      var pubSpec = await PubSpec.loadFile(pubspecFile.path);

      print('PubSpec.name: ${pubSpec.name}');
      print('PubSpec.version: ${pubSpec.version}');

      var srcFile =
          File(path.join(projectDirectory.path, 'lib/src/bones_api_base.dart'));

      print(srcFile);

      var src = srcFile.readAsStringSync();

      var versionMatch = RegExp(r"VERSION\s*=\s*'(.*?)'").firstMatch(src)!;

      var srcVersion = versionMatch.group(1);

      print('srcVersion: $srcVersion');

      expect(pubSpec.version.toString(), equals(srcVersion),
          reason:
              'Bones_API.VERSION[$srcVersion] != PubSpec.version[${pubSpec.version}]');
    });
  });
}
