import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('HTMLDocument', () {
    test('basic', () async {
      var htmlDoc = HTMLDocument(
        title: 'Title Test 1',
        styles: '.foo { color: red; }',
        top: 'Top:<hr>',
        content: [
          'This is just a test: ',
          ['a', 'b', 'c'],
        ],
        footer: '<hr>\nFooter!',
      );

      var html = htmlDoc.build();
      print(html);

      expect(html, contains('<title>Title Test 1</title>'));
      expect(html, contains('<style>\n.foo { color: red; }\n</style>'));
      expect(html, contains('Top:<hr>\n'));
      expect(html, contains('This is just a test: abc\n'));
      expect(html, contains('<hr>\nFooter!'));
    });
  });
}
