@TestOn('vm')
@Tags(['build', 'slow'])
@Timeout(Duration(minutes: 2))
library;

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

// Checks that the generated `reflection_factory` code (`.g.dart`) is up to
// date and committed. Skip with: `dart test -x build`
void main() {
  test(
    'ensure_build',
    () async => expectBuildClean(
      // This package is nested in the `bones_api` repository:
      packageRelativeDirectory: 'benchmark/db_users',
      gitDiffPathArguments: [':!pubspec.lock'],
    ),
  );
}
