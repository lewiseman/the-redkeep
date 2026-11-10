import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../domain/note_document.dart';
import 'notes_providers.dart';

final noteReadingChecklistProvider = NotifierProvider.autoDispose
    .family<NoteReadingChecklist, NoteReadingChecklistState, String>(
      NoteReadingChecklist.new,
    );

typedef NoteChecklistLayout = ({int revision, String body});

class NoteReadingChecklistState {
  const NoteReadingChecklistState({
    this.layout,
    this.checks = const {},
    this.error,
  });

  /// Checkbox-only saves can keep using the same parsed Markdown.
  final NoteChecklistLayout? layout;
  final Map<int, bool> checks;
  final String? error;
}

class NoteReadingChecklist extends Notifier<NoteReadingChecklistState> {
  NoteReadingChecklist(this.id);
  final String id;

  _ChecklistSession? _session;
  Future<void>? _saving;
  Future<void>? get saving => _saving;

  static const _saveError = 'Could not save the checklist change. Try again.';

  @override
  NoteReadingChecklistState build() {
    ref.listen(noteDocumentProvider(id), (_, next) {
      if (!next.isLoading) _observe(next.value?.note);
    });
    return const NoteReadingChecklistState();
  }

  bool isChecklistSave(NoteDocument note) =>
      note.deletedAt == null &&
      _session?.writes[note.revision] == note.text.body;

  void _observe(NoteDocument? note) {
    final session = _session;
    if (session == null) return;
    if (note != null && note.deletedAt == null) {
      if (isChecklistSave(note)) {
        session.writes.removeWhere((revision, _) => revision < note.revision);
        return;
      }
      if (note.revision == session.layout.revision &&
          note.text.body == session.layout.body) {
        return;
      }
    }
    _session = null;
    state = NoteReadingChecklistState(
      error: session.pending.isNotEmpty ? _saveError : state.error,
    );
  }

  void toggle(String body, int marker, bool checked) {
    if (!ref.read(syncCanEditProvider)) return;
    final opened = ref.read(noteDocumentProvider(id)).value;
    if (opened?.available != true) return;
    final session = _session ?? _ChecklistSession(opened!.note!);
    if (session.layout.body != body ||
        marker < 1 ||
        marker + 1 >= body.length ||
        body[marker - 1] != '[' ||
        body[marker + 1] != ']' ||
        !' xX'.contains(body[marker])) {
      return;
    }
    _session = session;
    session.pending[marker] = checked;
    state = NoteReadingChecklistState(
      layout: session.layout,
      checks: {...state.checks, marker: checked},
    );
    _saving ??= _save().whenComplete(() => _saving = null);
  }

  Future<void> _save() async {
    final keep = ref.keepAlive();
    try {
      // A second tap is reflected immediately and waits behind the current
      // write. Multiple waiting taps are saved together.
      while (ref.mounted) {
        final session = _session;
        if (session == null || session.pending.isEmpty) break;
        final note = session.saved;
        final body = _applyChecks(note.text.body, session.pending);
        session.pending.clear();
        if (body == null) continue;
        final revision = note.revision + 1;
        session.writes[revision] = body;
        try {
          if (!ref.read(syncCanEditProvider)) {
            throw const NoteException(NoteFailure.unavailable);
          }
          session.saved = await ref
              .read(notesRepositoryProvider)
              .saveNote(
                id: note.id,
                expectedRevision: note.revision,
                text: PlainTextDocument(title: note.text.title, body: body),
                details: note.details.copy(tags: note.tags),
              );
        } catch (error) {
          if (!ref.mounted) return;
          if (identical(_session, session)) {
            // A concurrent save can reach the same checkbox state first.
            final latest = ref.read(noteDocumentProvider(id)).value?.note;
            if (error is NoteException &&
                error.failure == NoteFailure.staleRevision &&
                latest != null &&
                latest.revision == revision &&
                isChecklistSave(latest)) {
              session.saved = latest;
              continue;
            }
            session.pending.clear();
            session.writes.remove(revision);
            state = NoteReadingChecklistState(
              layout: session.layout,
              checks: {
                for (final marker in state.checks.keys)
                  marker: note.text.body[marker] != ' ',
              },
              error: _saveError,
            );
          } else if (_session == null) {
            state = const NoteReadingChecklistState(error: _saveError);
          }
        }
      }
    } finally {
      keep.close();
    }
  }
}

class _ChecklistSession {
  _ChecklistSession(this.saved)
    : layout = (revision: saved.revision, body: saved.text.body);

  final NoteChecklistLayout layout;
  NoteDocument saved;
  final pending = <int, bool>{};

  /// Keep the expected bodies until the watcher has caught up. Drift can
  /// report a commit before the save Future completes or skip revisions.
  final writes = <int, String>{};
}

String? _applyChecks(String body, Map<int, bool> checks) {
  final changed = [
    for (final entry in checks.entries)
      if ((body[entry.key] != ' ') != entry.value) entry.key,
  ]..sort();
  if (changed.isEmpty) return null;
  final result = StringBuffer();
  var start = 0;
  for (final marker in changed) {
    result
      ..write(body.substring(start, marker))
      ..write(checks[marker]! ? 'x' : ' ');
    start = marker + 1;
  }
  return (result..write(body.substring(start))).toString();
}
