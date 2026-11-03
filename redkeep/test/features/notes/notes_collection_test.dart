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

  Future<RecoveryDraft> draft(
    int i, {
    String title = 'Draft',
    String body = 'Working text',
    int base = 0,
  }) => repo.putDraft(
    id: key(i),
    text: PlainTextDocument(title: title, body: body),
    baseRevision: base,
    expectedDraftRevision: null,
  );
  Future<NoteDocument> saved(
    int i, {
    String title = 'Saved',
    String body = 'Committed text',
    bool pinned = false,
    List<String> tags = const [],
  }) async {
    final d = await draft(i, title: title, body: body);
    final n = await repo.commitDraft(key(i), d.draftRevision);
    if (pinned || tags.isNotEmpty) {
      await repo.organize(n.id, n.revision, pinned: pinned, tags: tags);
    }
    return (await repo.openDocument(n.id)).note!;
  }

  test(
    'one card per ID overlays before search and bounds excerpts in SQLite',
    () async {
      final n = await saved(
        1,
        title: 'Committed title',
        body: 'Hidden saved words',
        pinned: true,
        tags: ['travel'],
      );
      final body = '${List.filled(700, '🌿').join()} hidden-needle';
      await draft(1, title: 'Working title', body: body, base: n.revision);
      await draft(2);
      final entries = await repo.watchCollection().first;
      expect(entries.map((e) => e.id), [key(1), key(2)]);
      expect(entries.first.title, 'Working title');
      expect(entries.first.excerpt.runes.length, 600);
      expect(entries.first.excerpt, List.filled(600, '🌿').join());
      expect(entries.first.isDraft, isTrue);
      expect(entries.first.pinned, isTrue);
      expect(entries.first.sourceUnavailable, isFalse);
      expect(
        await repo
            .watchCollection(query: const NotesQuery(search: 'committed'))
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
      // The pre-existing saved-only stream keeps its contract.
      expect(
        (await repo
                .watchNotes(query: const NotesQuery(search: 'committed'))
                .first)
            .single
            .title,
        'Committed title',
      );
    },
  );

  test(
    'orphaned and deleted-source drafts survive; Trash uses saved versions',
    () async {
      final n = await saved(1, title: 'Before deletion', tags: ['work']);
      await draft(1, title: 'Recovery after deletion', base: n.revision);
      await repo.deleteNote(n.id, n.revision);
      await draft(2, title: 'Missing source', base: 7);
      await draft(3, title: 'New writing');
      final entries = await repo.watchCollection(draftsOnly: true).first;
      expect(entries.length, 3);
      expect(entries.where((e) => e.sourceUnavailable).map((e) => e.id), [
        key(1),
        key(2),
      ]);
      final trash = await repo
          .watchCollection(query: const NotesQuery(trash: true))
          .first;
      expect(trash.single.title, 'Before deletion');
      expect(trash.single.isDraft, isFalse);
      expect(
        await repo
            .watchCollection(
              query: const NotesQuery(trash: true),
              draftsOnly: true,
            )
            .first,
        isEmpty,
      );
      expect(
        (await repo.watchCollection(query: const NotesQuery(tag: 'work')).first)
            .single
            .title,
        'Recovery after deletion',
      );
    },
  );

  test(
    'pin ordering, effective update ordering, and ID ties are stable',
    () async {
      await saved(3);
      await saved(1, pinned: true);
      await saved(2);
      now = now.add(const Duration(minutes: 1));
      await draft(3, base: 1);
      expect((await repo.watchCollection().first).map((e) => e.id), [
        key(1),
        key(3),
        key(2),
      ]);
      now = now.add(const Duration(minutes: 1));
      await draft(2, base: 1);
      expect((await repo.watchCollection().first).map((e) => e.id), [
        key(1),
        key(2),
        key(3),
      ]);
      expect(
        (await repo.watchCollection(draftsOnly: true).first).map((e) => e.id),
        [key(2), key(3)],
      );
    },
  );

  test(
    'provider reacts to draft/save/discard, query and system Drafts selection',
    () async {
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
      container.read(notesDraftsOnlyProvider.notifier).set(true);
      expect(await container.read(notesCollectionProvider.future), isEmpty);
      final changed = Completer<void>();
      final updates = container.listen(notesCollectionProvider, (_, next) {
        if (!changed.isCompleted &&
            (next.value?.any((e) => e.title == 'Recovery') ?? false)) {
          changed.complete();
        }
      });
      final d = await draft(1, title: 'Recovery', base: 2);
      await changed.future;
      updates.close();
      expect(
        (await repo.watchCollection(draftsOnly: true).first).single.title,
        'Recovery',
      );
      await repo.discardDraft(key(1), d.draftRevision);
      expect(await repo.watchCollection(draftsOnly: true).first, isEmpty);
      final next = await draft(1, title: 'New committed title', base: 2);
      await repo.commitDraft(key(1), next.draftRevision);
      expect(
        (await repo.watchCollection().first)
            .where((e) => e.id == key(1))
            .single
            .title,
        'New committed title',
      );
      expect(await repo.watchCollection(draftsOnly: true).first, isEmpty);
    },
  );
}
