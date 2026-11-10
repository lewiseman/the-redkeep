import 'dart:async';

import '../domain/note_rich_markdown.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_document.dart';
import '../domain/notes_repository.dart';
import 'notes_providers.dart';

final noteEditorProvider = AsyncNotifierProvider.autoDispose
    .family<NoteEditorController, NoteEditorState, String>(
      NoteEditorController.new,
      retry: (_, _) => null,
    );

class NoteEditorState {
  const NoteEditorState({
    required this.text,
    this.details = const NoteDetails(),
    required this.baseRevision,
    this.editVersion = 0,
    this.saving = false,
    this.dirty = false,
    this.conflict = false,
    this.message,
  });
  final PlainTextDocument text;
  final NoteDetails details;

  /// The saved revision this writing builds on; 0 until a new note is saved.
  final int baseRevision;
  final int editVersion;
  final bool saving;

  /// Writing that has not reached the note yet.
  final bool dirty;

  /// The note changed elsewhere or was deleted; only a copy can be saved.
  final bool conflict;
  final String? message;
}

/// Owns the working buffer and saves it straight into the note: shortly after
/// typing stops, and whenever the page asks (leaving editing, backgrounding).
class NoteEditorController extends AsyncNotifier<NoteEditorState> {
  NoteEditorController(this.id);
  final String id;

  static const autosaveDelay = Duration(milliseconds: 1500);

  late NotesRepository _repository;
  late PlainTextDocument _text;
  NoteDetails _details = const NoteDetails();
  late int _baseRevision;
  bool _saving = false;
  bool _conflict = false;
  int _sequence = 0;
  int _savedSequence = 0;
  Timer? _autosave;
  Future<bool>? _pending;
  void Function()? _releaseUnsaved;

  bool get _dirty => _sequence != _savedSequence;
  bool get _isEmpty => _text.isEmpty && !_details.hasWriting;

  /// The unsaved clearing of an existing note can be confirmed as a deletion.
  NoteEditorState? get clearedDraft {
    if (!ref.mounted ||
        !_dirty ||
        _conflict ||
        _baseRevision == 0 ||
        !_isEmpty) {
      return null;
    }
    return state.value;
  }

  @override
  Future<NoteEditorState> build() async {
    _repository = ref.watch(notesRepositoryProvider);
    ref.onDispose(() => _autosave?.cancel());
    final allocated = ref.read(noteNewIdsProvider).contains(id);
    final opened = await _repository.openDocument(id);
    final note = opened.note;
    if (note == null ? !allocated : !opened.available) {
      throw const NoteException(NoteFailure.unavailable);
    }
    _text = note?.text ?? const PlainTextDocument();
    _details = note?.details.copy(tags: note.tags) ?? const NoteDetails();
    _baseRevision = note?.revision ?? 0;
    final changes = _repository.watchDocument(id).listen(_adoptExternal);
    ref.onDispose(changes.cancel);
    return _snapshot();
  }

  /// Picks up a newer saved revision (an AI result, a sync import) while
  /// there is no unsaved writing that it would overwrite.
  void _adoptExternal(OpenNote opened) {
    final note = opened.note;
    if (!ref.mounted ||
        !state.hasValue ||
        _saving ||
        _dirty ||
        note == null ||
        !opened.available ||
        note.revision <= _baseRevision) {
      return;
    }
    _text = note.text;
    _details = note.details.copy(tags: note.tags);
    _baseRevision = note.revision;
    _sequence++;
    _savedSequence = _sequence;
    _conflict = false;
    _publish();
  }

  NoteEditorState _snapshot({String? message}) => NoteEditorState(
    text: _text,
    details: _details,
    baseRevision: _baseRevision,
    editVersion: _sequence,
    saving: _saving,
    dirty: _dirty,
    conflict: _conflict,
    message: message,
  );

  void _publish({String? message}) {
    if (ref.mounted) state = AsyncData(_snapshot(message: message));
  }

  /// Typing never waits for a save; writing that arrives mid-save is saved
  /// right after it.
  void edit(PlainTextDocument text) {
    if (!state.hasValue) return;
    _text = text;
    _changed();
  }

  void editDetails(NoteDetails details) {
    if (!state.hasValue) return;
    _details = details;
    _changed();
  }

  void _changed() {
    _sequence++;
    // Keep the buffer alive until it reaches the note, even if the page goes.
    _releaseUnsaved ??= ref.keepAlive().close;
    _publish();
    _autosave?.cancel();
    if (!_conflict) _autosave = Timer(autosaveDelay, () => unawaited(save()));
  }

  void _settled() {
    if (_dirty) return;
    _releaseUnsaved?.call();
    _releaseUnsaved = null;
  }

  /// Saves any unsaved writing. True when nothing is left unsaved, including
  /// a new note that is still empty (it is simply never created).
  Future<bool> save() {
    _autosave?.cancel();
    if (!state.hasValue) return Future.value(false);
    return _pending ??= _save().whenComplete(() => _pending = null);
  }

  Future<bool> _save() async {
    while (_dirty) {
      if (_conflict) return false;
      final sequence = _sequence;
      if (_isEmpty) {
        if (_baseRevision == 0) {
          _savedSequence = sequence;
          continue;
        }
        _publish();
        return false;
      }
      _saving = true;
      _publish();
      try {
        final saved = await _repository.saveNote(
          id: id,
          expectedRevision: _baseRevision,
          text: _text,
          details: _details,
        );
        _baseRevision = saved.revision;
        _savedSequence = sequence;
        if (ref.mounted) ref.read(noteNewIdsProvider.notifier).remove(id);
      } on NoteException catch (error) {
        _saving = false;
        if (error.failure == NoteFailure.staleRevision ||
            error.failure == NoteFailure.unavailable) {
          _conflict = true;
          _publish(
            message: 'This note changed somewhere else or was deleted. Your writing is still here: save it as a copy.',
          );
        } else {
          _publish(
            message:
                'This note could not be saved. Your writing is still here.',
          );
        }
        return false;
      } catch (_) {
        _saving = false;
        _publish(
          message: 'This note could not be saved. Your writing is still here; check device storage and try again.',
        );
        return false;
      }
      _saving = false;
    }
    _publish();
    _settled();
    return true;
  }

  /// Drops unsaved writing; the saved note (if any) is untouched.
  void discardChanges() {
    _autosave?.cancel();
    _savedSequence = _sequence;
    _conflict = false;
    _publish();
    _settled();
  }

  /// Keeps conflicting writing as a new note. Returns its id.
  Future<String?> saveCopy() async {
    if (_saving || !state.hasValue || _isEmpty) {
      return null;
    }
    _autosave?.cancel();
    final newId = ref.read(noteIdProvider)();
    _saving = true;
    _publish();
    try {
      await _repository.saveNote(
        id: newId,
        expectedRevision: 0,
        text: _text,
        details: _details,
      );
      _savedSequence = _sequence;
      _saving = false;
      _publish();
      _settled();
      return newId;
    } catch (_) {
      _saving = false;
      _publish(
        message: 'The copy could not be saved. Your writing is still here; try again.',
      );
      return null;
    }
  }

  /// Applies an edit only while the buffer and the saved note still match
  /// what the reviewer saw.
  Future<bool> _stillMatches(
    NoteEditorState expected,
    bool Function() valid,
  ) async {
    if (!valid()) return false;
    final opened = await _repository.openDocument(id);
    return valid() &&
        (expected.baseRevision == 0
            ? opened.note == null
            : opened.available &&
                  opened.note!.revision == expected.baseRevision);
  }

  bool _unchangedSince(
    NoteEditorState expected,
    bool Function() stillCurrent,
  ) =>
      ref.mounted &&
      !_saving &&
      state.hasValue &&
      stillCurrent() &&
      _sequence == expected.editVersion &&
      _baseRevision == expected.baseRevision &&
      _text.title == expected.text.title &&
      _text.body == expected.text.body;

  Future<bool> acceptReplacement({
    required NoteEditorState expected,
    required int start,
    required int end,
    required String replacement,
    required bool Function() stillCurrent,
  }) async {
    bool valid() => _unchangedSince(expected, stillCurrent);
    if (!valid() ||
        start < 0 ||
        end <= start ||
        end > _text.body.length ||
        replacement.trim().isEmpty) {
      return false;
    }
    if (!await _stillMatches(expected, valid)) return false;
    edit(
      PlainTextDocument(
        title: _text.title,
        body: _text.body.replaceRange(start, end, replacement),
      ),
    );
    return true;
  }

  /// Dictation is an append proposal, including for an initially empty note.
  /// The transcript remains retained by the caller when anything changed.
  Future<bool> appendReviewedTranscript({
    required NoteEditorState expected,
    required String transcript,
    required bool Function() stillCurrent,
  }) async {
    bool valid() => _unchangedSince(expected, stillCurrent);
    if (transcript.trim().isEmpty || !valid()) return false;
    if (!await _stillMatches(expected, valid)) return false;
    edit(
      PlainTextDocument(
        title: _text.title,
        body: [
          if (_text.body.isNotEmpty) _text.body,
          // Speech is plain words; nothing in it may read as formatting.
          markdownFromPlainText(transcript.trim()),
        ].join('\n\n'),
      ),
    );
    return true;
  }
}
