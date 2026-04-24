import 'package:dartmud/src/world/editor/editor_session.dart';
import 'package:test/test.dart';

void main() {
  test('range parser supports single lines and dollar upper bound', () {
    final single = EditorRange.parse('3');
    final span = EditorRange.parse('2,\$');

    expect(single.first, 3);
    expect(single.last, 3);
    expect(single.length, 1);
    expect(span.first, 2);
    expect(span.includes(50), isTrue);
  });

  test('editor append print change delete flow works', () {
    final editor = EditorSession();

    expect(editor.start(), ': ');
    expect(editor.handleInput('a').output, '~ ');
    expect(editor.handleInput('first line').output, '~ ');
    expect(editor.handleInput('second line').output, '~ ');
    expect(editor.handleInput('.').output, ': ');

    var result = editor.handleInput('1,\$ p');
    expect(result.output, contains('1 : first line'));
    expect(result.output, contains('2 : second line'));

    editor.handleInput('1 c');
    editor.handleInput('replacement');
    editor.handleInput('.');
    result = editor.handleInput('1,\$ p');
    expect(result.output, contains('1 : replacement'));
    expect(result.output, isNot(contains('first line')));

    editor.handleInput('2 d');
    result = editor.handleInput('1,\$ p');
    expect(result.output, isNot(contains('second line')));
  });
}
