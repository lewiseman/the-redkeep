import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/notes/domain/notes_query.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  var now = DateTime.utc(2026, 11, 4);
  String key(int i) => i.toRadixString(16).padLeft(32, '0');
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 4);
    repo = DriftNotesRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<NoteDocument> saved(
    int i, {
    String title = 'Saved',
    String body = 'Saved text',
    bool pinned = false,
    List<String> tags = const [],
    int expected = 0,
  }) async {
    final n = await repo.saveNote(
      id: key(i),
      text: PlainTextDocument(title: title, body: body),
      expectedRevision: expected,
      details: const NoteDetails(),
    );
    if (pinned || tags.isNotEmpty) {
      await repo.organize(n.id, n.revision, pinned: pinned, tags: tags);
    }
    return (await repo.openDocument(n.id)).note!;
  }

  test('search runs in SQLite and excerpts are bounded', () async {
    final body = '${List.filled(700, '🌿').join()} hidden-needle';
    await saved(
      1,
      title: 'Working title',
      body: body,
      pinned: true,
      tags: ['travel'],
    );
    await saved(2);
    final entries = await repo.watchCollection().first;
    expect(entries.map((e) => e.id), [key(1), key(2)]);
    expect(entries.first.title, 'Working title');
    expect(entries.first.excerpt.runes.length, 600);
    expect(entries.first.excerpt, List.filled(600, '🌿').join());
    expect(entries.first.pinned, isTrue);
    expect(
      await repo
          .watchCollection(query: const NotesQuery(search: 'missing'))
          .first,
      isEmpty,
    );
    expect(
      (await repo
              .watchCollection(
                query: const NotesQuery(
                  search: 'working hidden-needle',
                  tag: 'travel',
                  pinnedOnly: true,
                ),
              )
              .first)
          .single
          .id,
      key(1),
    );
  });

  test('Trash lists deleted notes only', () async {
    final n = await saved(1, title: 'Before deletion', tags: ['work']);
    await saved(2, title: 'Kept');
    await repo.deleteNote(n.id, n.revision);
    expect((await repo.watchCollection().first).single.title, 'Kept');
    final trash = await repo
        .watchCollection(query: const NotesQuery(trash: true))
        .first;
    expect(trash.single.title, 'Before deletion');
    expect(
      await repo.watchCollection(query: const NotesQuery(tag: 'work')).first,
      isEmpty,
    );
  });

  test('pin ordering, update ordering, and ID ties are stable', () async {
    await saved(3);
    await saved(1, pinned: true);
    await saved(2);
    now = now.add(const Duration(minutes: 1));
    await saved(3, expected: 1, body: 'Edited');
    expect((await repo.watchCollection().first).map((e) => e.id), [
      key(1),
      key(3),
      key(2),
    ]);
    now = now.add(const Duration(minutes: 1));
    await saved(2, expected: 1, body: 'Edited');
    expect((await repo.watchCollection().first).map((e) => e.id), [
      key(1),
      key(2),
      key(3),
    ]);
  });

  test('provider reacts to saves and queries', () async {
    await saved(1, tags: ['drafts']);
    await saved(2, tags: ['travel']);
    final container = ProviderContainer.test(
      overrides: [notesRepositoryProvider.overrideWithValue(repo)],
    );
    final subscription = container.listen(notesCollectionProvider, (_, _) {});
    addTearDown(subscription.close);
    expect((await container.read(notesCollectionProvider.future)).length, 2);
    container
        .read(notesFilterProvider.notifier)
        .set(const NotesQuery(tag: 'drafts'));
    expect(
      (await container.read(notesCollectionProvider.future)).single.id,
      key(1),
    );
    container.read(notesFilterProvider.notifier).set(const NotesQuery());
    final changed = Completer<void>();
    final updates = container.listen(notesCollectionProvider, (_, next) {
      if (!changed.isCompleted &&
          (next.value?.any((e) => e.title == 'New title') ?? false)) {
        changed.complete();
      }
    });
    await saved(1, title: 'New title', expected: 2);
    await changed.future;
    updates.close();
  });
}
