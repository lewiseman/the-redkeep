import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';
import 'package:redkeep/features/notes/presentation/notes_collection_sheet.dart';

NoteCollectionOption _tag(String value) =>
    (emoji: '🏷️', name: value, value: value);

void main() {
  test('orders Pinned, All, user tags, then Trash', () {
    final arranged = NoteCollection.arrange([
      _tag(NoteCollection.all),
      _tag(NoteCollection.trash),
      _tag('drafts'),
      _tag(NoteCollection.pinned),
      _tag('work'),
      _tag('home'),
    ]).map((tag) => tag.value);
    expect(arranged, [
      NoteCollection.pinned,
      NoteCollection.all,
      'drafts',
      'work',
      'home',
      NoteCollection.trash,
    ]);
  });

  test('a query shows exactly one collection, Trash first', () {
    expect(NoteCollection.of(const NotesQuery()), NoteCollection.all);
    expect(
      NoteCollection.of(const NotesQuery(pinnedOnly: true)),
      NoteCollection.pinned,
    );
    expect(NoteCollection.of(const NotesQuery(tag: '💡#Ideas')), '💡#Ideas');
    expect(
      NoteCollection.of(const NotesQuery(tag: '💡#Ideas', trash: true)),
      NoteCollection.trash,
    );
    expect(NoteCollection.option('💡#Ideas'), (
      emoji: '💡',
      name: 'Ideas',
      value: '💡#Ideas',
    ));
  });
}
