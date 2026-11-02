import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/drift_notes_repository.dart';
import '../domain/note_document.dart';
import '../domain/notes_repository.dart';

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
final notesListProvider = StreamProvider.autoDispose<List<NoteListing>>(
  (ref) => ref.watch(notesRepositoryProvider).watchNotes(),
  retry: (_, _) => null,
);
final recoveryListProvider = StreamProvider.autoDispose<List<NoteListing>>(
  (ref) => ref.watch(notesRepositoryProvider).watchDrafts(),
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
      await ref
          .read(notesRepositoryProvider)
          .putDraft(
            id: id,
            text: const PlainTextDocument(),
            baseRevision: 0,
            expectedDraftRevision: null,
          );
      return id;
    } finally {
      if (ref.mounted) state = false;
      keep.close();
    }
  }

  Future<void> delete(NoteDocument note) async {
    if (state) return;
    state = true;
    final keep = ref.keepAlive();
    try {
      await ref
          .read(notesRepositoryProvider)
          .deleteNote(note.id, note.revision);
    } finally {
      if (ref.mounted) state = false;
      keep.close();
    }
  }
}
