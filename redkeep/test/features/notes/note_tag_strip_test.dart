import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/presentation/note_tag_strip.dart';

({String emoji, String name, String value}) _tag(String value) =>
    (emoji: '🏷️', name: value, value: value);

void main() {
  test('orders Pinned, All, user tags, then Trash', () {
    final arranged = NoteTagStrip.arrange([
      _tag(NoteTagStrip.all),
      _tag(NoteTagStrip.trash),
      _tag('drafts'),
      _tag(NoteTagStrip.pinned),
      _tag('work'),
      _tag('home'),
    ]).map((tag) => tag.value);
    expect(arranged, [
      NoteTagStrip.pinned,
      NoteTagStrip.all,
      'drafts',
      'work',
      'home',
      NoteTagStrip.trash,
    ]);
  });
}
