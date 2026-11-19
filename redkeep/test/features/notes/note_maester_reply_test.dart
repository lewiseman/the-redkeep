import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/note_maester_reply.dart';

void main() {
  NoteMaesterReply done(String raw) =>
      NoteMaesterReply.read(raw, complete: true);

  test('a reply changes the title, the text, or both', () {
    expect(done('<<TITLE>> Trip plan').title, 'Trip plan');
    expect(done('<<TITLE>> Trip plan').text, isNull);
    final both = done('<<TITLE>> Trip\n<<TEXT>>\n- Pack\n- Go');
    expect((both.title, both.text), ('Trip', '- Pack\n- Go'));
    final text = done('<<TEXT>>\nJust words');
    expect((text.title, text.text), (null, 'Just words'));
  });

  test('a reply without markers, or in a code fence, is still read', () {
    expect(done('Plain rewrite').text, 'Plain rewrite');
    expect(done('```\n<<TEXT>>\nFenced\n```').text, 'Fenced');
  });

  test('while streaming, a half-written marker shows nothing yet', () {
    for (final raw in ['', '<<', '<<TIT', '<<TITLE>> Trip\n<<TE']) {
      expect(NoteMaesterReply.read(raw).text, isNull, reason: raw);
    }
    // The title shows as it arrives; the text once its marker is done.
    expect(NoteMaesterReply.read('<<TITLE>> Tri').title, 'Tri');
    expect(NoteMaesterReply.read('<<TEXT>>\n- Pa').text, '- Pa');
    expect(NoteMaesterReply.read('<<TEXT>>').text, '');
  });

  test('titles that could not be typed are refused', () {
    expect(checkedNoteMaesterTitle('  Trip  '), 'Trip');
    for (final bad in ['', 'a\tb', '<b>x</b>', 'x' * 121]) {
      expect(() => checkedNoteMaesterTitle(bad), throwsFormatException);
    }
  });
}
