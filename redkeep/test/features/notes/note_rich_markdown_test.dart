import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:redkeep/features/notes/domain/note_rich_markdown.dart';

String html(String markdown) =>
    md.markdownToHtml(markdown, extensionSet: md.ExtensionSet.gitHubFlavored);

void main() {
  test('the core round-trips exactly', () {
    const notes = [
      '',
      'Just a line',
      'Two lines\nof one paragraph\n\nAnd another',
      '# Big\n## Medium\n### Small',
      '- milk\n- bread',
      '1. one\n2. two\n3. three',
      '- [ ] buy milk\n- [x] bake bread',
      'some **bold** and *italic* and ***both*** words',
      '**bold with *italic* inside**',
      '- [ ] a **bold** task',
      'trailing newline\n',
    ];
    for (final note in notes) {
      final delta = richFromMarkdown(note);
      expect(delta, isNotNull, reason: note);
      expect(markdownFromRich(delta!), note, reason: note);
    }
  });

  test('the editor sees structure, not symbols', () {
    final ops = richFromMarkdown('- [x] **done**\n# Title')!.toList();
    expect(ops[0].data, 'done');
    expect(ops[0].attributes, {'bold': true});
    expect(ops[1].attributes, {'list': 'checked'});
    expect(ops[2].data, 'Title');
    expect(ops[3].attributes, {'header': 1});
  });

  test('numbered lists are written in order', () {
    final delta = richFromMarkdown('1. a\n1. b\n1. c')!;
    expect(markdownFromRich(delta), '1. a\n2. b\n3. c');
  });

  test('anything outside the core stays plain text', () {
    const notes = [
      '| a | b |\n|---|---|\n| 1 | 2 |',
      '```\ncode\n```',
      'a [link](https://example.com)',
      '> a quote',
      '- parent\n  - child',
      'use `code` here',
      '~~struck~~',
      '<b>html</b>',
      '3. starts at three',
      'Setext\n======',
      'tab\tindented',
    ];
    for (final note in notes) {
      expect(richFromMarkdown(note), isNull, reason: note);
    }
  });

  test('ordinary punctuation stays rich and renders the same', () {
    const notes = [
      '2 * 3 = 6',
      'snake_case_name',
      r'a \* literal star',
      'https://example.com/a_b',
      'Cost: \$5 & up',
    ];
    for (final note in notes) {
      final delta = richFromMarkdown(note);
      expect(delta, isNotNull, reason: note);
      expect(html(markdownFromRich(delta!)), html(note), reason: note);
    }
  });

  test('typed symbols are kept literal, not turned into Markdown', () {
    String write(String text, [Map<String, dynamic>? line]) => markdownFromRich(
      Delta()
        ..insert(text)
        ..insert('\n', line),
    );
    const typed = [
      '# not a heading',
      '- not a list',
      '1. not numbered',
      '*not italic*',
      '**not bold**',
      '[ ] not a task',
      '---',
      '`tick`',
      '<b>tag</b>',
      '    four spaces',
    ];
    for (final text in typed) {
      final written = write(text);
      final back = richFromMarkdown(written);
      expect(back, isNotNull, reason: written);
      expect(
        back!.toList().map((op) => op.data).join(),
        '${text.trimLeft()}\n',
        reason: written,
      );
      expect(back.toList().first.attributes, isNull, reason: written);
    }
    expect(
      richFromMarkdown(write('[ ] inside a bullet', {'list': 'bullet'}))!
          .toList()
          .first
          .data,
      '[ ] inside a bullet',
    );
  });

  test('formatting hugs the words so it stays valid Markdown', () {
    final written = markdownFromRich(
      Delta()
        ..insert('a ')
        ..insert(' bold ', {'bold': true})
        ..insert('b\n'),
    );
    expect(written, 'a  **bold** b');
    expect(html(written), contains('<strong>bold</strong>'));
  });

  test('unknown formatting is dropped but text is kept', () {
    final written = markdownFromRich(
      Delta()
        ..insert('linked', {'link': 'https://x.y', 'underline': true})
        ..insert('\n', {'blockquote': true})
        ..insert({'image': 'x.png'})
        ..insert('\n'),
    );
    expect(written, 'linked\n');
  });
}
