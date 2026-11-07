import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/drift_note_websites.dart';
import '../data/drift_notes_repository.dart';
import '../data/platform_note_link_launcher.dart';
import '../domain/note_link_launcher.dart';
import '../domain/note_document.dart';
import '../domain/note_collection_entry.dart';
import '../domain/note_website.dart';
import '../domain/notes_repository.dart';
import '../domain/notes_query.dart';

final notesClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final noteIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
});
final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => DriftNotesRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(notesClockProvider),
  ),
);

/// Websites kept beside notes on this device.
final noteWebsitesProvider = Provider<DriftNoteWebsites>(
  (ref) => DriftNoteWebsites(ref.watch(appDatabaseProvider)),
);

/// The note's website, or null when it has none.
final noteWebsiteProvider = StreamProvider.autoDispose
    .family<NoteWebsite?, String>(
      (ref, id) => ref.watch(noteWebsitesProvider).watch(id),
    );

final notesListProvider = StreamProvider.autoDispose<List<NoteListing>>(
  (ref) => ref
      .watch(notesRepositoryProvider)
      .watchNotes(query: ref.watch(notesFilterProvider)),
  retry: (_, _) => null,
);
final notesCollectionProvider =
    StreamProvider.autoDispose<List<NoteCollectionEntry>>(
      (ref) => ref
          .watch(notesRepositoryProvider)
          .watchCollection(query: ref.watch(notesFilterProvider)),
      retry: (_, _) => null,
    );

final noteDocumentProvider = StreamProvider.autoDispose
    .family<OpenNote, String>(
      (ref, id) => ref.watch(notesRepositoryProvider).watchDocument(id),
      retry: (_, _) => null,
    );

final notesActionsProvider = NotifierProvider.autoDispose<NotesActions, bool>(
  NotesActions.new,
);

class NotesActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> create() async {
    if (state) return null;
    state = true;
    final keep = ref.keepAlive();
    try {
      final id = ref.read(noteIdProvider)();
      ref.read(noteNewIdsProvider.notifier).add(id);
      return id;
    } finally {
      if (ref.mounted) state = false;
      keep.close();
    }
  }

  Future<void> organize(
    NoteDocument note, {
    required bool pinned,
    required List<String> tags,
  }) => _run(
    () => ref
        .read(notesRepositoryProvider)
        .organize(note.id, note.revision, pinned: pinned, tags: tags),
  );
  Future<void> restore(NoteDocument note) => _run(
    () => ref.read(notesRepositoryProvider).restoreNote(note.id, note.revision),
  );
  Future<void> permanentlyDelete(NoteDocument note) => _run(
    () => ref
        .read(notesRepositoryProvider)
        .permanentlyDelete(note.id, note.revision),
  );
  Future<void> _run(Future<void> Function() action) async {
    if (state) throw StateError('An action is already pending');
    state = true;
    final keep = ref.keepAlive();
    try {
      await action();
    } finally {
      if (ref.mounted) state = false;
      keep.close();
    }
  }

  Future<void> delete(NoteDocument note) => _run(
    () => ref.read(notesRepositoryProvider).deleteNote(note.id, note.revision),
  );
}

final notesFilterProvider = NotifierProvider<NotesFilter, NotesQuery>(
  NotesFilter.new,
);

class NotesFilter extends Notifier<NotesQuery> {
  @override
  NotesQuery build() => const NotesQuery();
  void set(NotesQuery query) => state = query;
}

final noteTagsProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref
      .watch(notesRepositoryProvider)
      .watchTags(trash: ref.watch(notesFilterProvider.select((q) => q.trash))),
  retry: (_, _) => null,
);

final noteLinkLauncherProvider = Provider<NoteLinkLauncher>(
  (ref) => const PlatformNoteLinkLauncher(),
);

/// Allocated new editors have no database row until there is writing to save.
final noteNewIdsProvider = NotifierProvider<NewNoteIds, Set<String>>(
  NewNoteIds.new,
);

class NewNoteIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void add(String id) => state = {...state, id};
  void remove(String id) => state = {...state}..remove(id);
}
