import 'dart:async';

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
    required this.baseRevision,
    this.draftRevision,
    this.editVersion = 0,
    this.saving = false,
    this.recovering = false,
    this.recoveryFailed = false,
    this.message,
    this.sourceUnavailable = false,
  });
  final PlainTextDocument text;
  final int baseRevision;
  final int? draftRevision;
  final int editVersion;
  final bool saving;
  final bool recovering;
  final bool recoveryFailed;
  final bool sourceUnavailable;
  final String? message;
}

/// The editing boundary owns the working buffer and serializes recovery writes.
/// Navigation never owns a live model and never discards the buffer implicitly.
class NoteEditorController extends AsyncNotifier<NoteEditorState> {
  NoteEditorController(this.id);
  final String id;
  late NotesRepository _repository;
  late PlainTextDocument _text;
  late int _baseRevision;
  int? _draftRevision;
  bool _unavailable = false;
  bool _saving = false;
  bool _recoveryFailed = false;
  int _sequence = 0;
  int _persistedSequence = 0;
  Future<bool>? _pending;
  void Function()? _releaseFailedBuffer;

  @override
  Future<NoteEditorState> build() async {
    _repository = ref.watch(notesRepositoryProvider);
    final opened = await _repository.openDocument(id);
    if (!opened.available &&
        opened.draft == null &&
        (opened.note != null || !ref.read(noteNewIdsProvider).contains(id))) {
      throw const NoteException(NoteFailure.unavailable);
    }
    _text =
        opened.draft?.text ?? opened.note?.text ?? const PlainTextDocument();
    _baseRevision = opened.draft?.baseRevision ?? opened.note?.revision ?? 0;
    _draftRevision = opened.draft?.draftRevision;
    _unavailable = !opened.available && _baseRevision != 0;
    return _snapshot(
      message: opened.draft == null
          ? null
          : 'Recovery draft reopened. Save to commit this writing.',
    );
  }

  NoteEditorState _snapshot({String? message}) => NoteEditorState(
    text: _text,
    baseRevision: _baseRevision,
    draftRevision: _draftRevision,
    editVersion: _sequence,
    saving: _saving,
    recovering: _sequence != _persistedSequence && !_recoveryFailed,
    recoveryFailed: _recoveryFailed,
    sourceUnavailable: _unavailable,
    message: message,
  );

  void _publish({String? message}) {
    if (ref.mounted) state = AsyncData(_snapshot(message: message));
  }

  void edit(PlainTextDocument text) {
    if (_saving || !state.hasValue) return;
    _text = text;
    _sequence++;
    _recoveryFailed = false;
    _publish();
    unawaited(flushRecovery());
  }

  /// Explicit proposal acceptance changes only this working buffer. Recheck
  /// authoritative source/draft tokens after recovery and again synchronously
  /// against editor/selection guards before touching text. Manual commit still
  /// uses the repository's atomic source revision check.
  Future<bool> acceptReplacement({
    required NoteEditorState expected,
    required int start,
    required int end,
    required String replacement,
    required bool Function() stillCurrent,
  }) async {
    bool valid() =>
        ref.mounted &&
        !_saving &&
        state.hasValue &&
        stillCurrent() &&
        _sequence == expected.editVersion &&
        _baseRevision == expected.baseRevision &&
        _text.title == expected.text.title &&
        _text.body == expected.text.body;
    if (!valid() ||
        start < 0 ||
        end <= start ||
        end > _text.body.length ||
        replacement.trim().isEmpty) {
      return false;
    }
    if (!await flushRecovery() || !valid()) return false;
    final opened = await _repository.openDocument(id);
    if (!valid() ||
        (expected.baseRevision == 0
            ? opened.note != null
            : !opened.available ||
                  opened.note!.revision != expected.baseRevision) ||
        opened.draft?.draftRevision != _draftRevision) {
      return false;
    }
    edit(
      PlainTextDocument(
        title: _text.title,
        body: _text.body.replaceRange(start, end, replacement),
      ),
    );
    return true;
  }

  /// Coalesces changes during a write and retains this provider until settled.
  Future<bool> flushRecovery() {
    if (_pending != null) return _pending!;
    final keep = ref.keepAlive();
    final future = _flush();
    _pending = future;
    unawaited(
      future.then((recovered) {
        _pending = null;
        if (recovered) {
          _releaseFailedBuffer?.call();
          _releaseFailedBuffer = null;
          keep.close();
        } else if (_releaseFailedBuffer == null) {
          // A platform destination can bypass a page's back guard. Retain the
          // failed working buffer in this scope for a subsequent editor visit.
          _releaseFailedBuffer = keep.close;
        } else {
          keep.close();
        }
      }),
    );
    return future;
  }

  Future<bool> _flush() async {
    while (_persistedSequence != _sequence) {
      final sequence = _sequence;
      final text = _text;
      try {
        if (text.isEmpty) {
          if (_draftRevision != null) {
            await _repository.discardDraft(id, _draftRevision!);
            _draftRevision = null;
          }
        } else {
          final draft = await _repository.putDraft(
            id: id,
            text: text,
            baseRevision: _baseRevision,
            expectedDraftRevision: _draftRevision,
          );
          _draftRevision = draft.draftRevision;
        }
        _persistedSequence = sequence;
        _recoveryFailed = false;
      } catch (_) {
        _recoveryFailed = true;
        _publish(
          message: 'Recovery could not be saved. Keep this editor open and retry, or save a copy.',
        );
        return false;
      }
    }
    _publish();
    return true;
  }

  Future<bool> save() async {
    if (_saving || !state.hasValue || _text.isEmpty) return false;
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      if (!await flushRecovery()) return false;
      if (_draftRevision == null) return true;
      final saved = await _repository.commitDraft(id, _draftRevision!);
      _draftRevision = null;
      _baseRevision = saved.revision;
      ref.read(noteNewIdsProvider.notifier).remove(id);
      _unavailable = false;
      _saving = false;
      _publish(message: 'Saved revision ${saved.revision} on this device.');
      return true;
    } on NoteException catch (error) {
      _saving = false;
      if (error.failure == NoteFailure.draftChanged) {
        _recoveryFailed = true;
        _persistedSequence = -1;
        if (ref.mounted) _releaseFailedBuffer ??= ref.keepAlive().close;
      }
      _publish(
        message: error.failure == NoteFailure.draftChanged
            ? 'The recovery draft changed elsewhere. Keep this editor open and save a copy.'
            : 'This note changed or was deleted. Your recovery draft is kept. Save a copy to keep both versions.',
      );
      return false;
    } catch (_) {
      _saving = false;
      _publish(
        message: 'Save failed. Your recovery draft is kept. Check device storage and retry.',
      );
      return false;
    } finally {
      _saving = false;
      // Preserve the specific result message, including recovery failure.
      if (ref.mounted) _publish(message: state.value?.message);
      keep.close();
    }
  }

  /// Explicit conflict recovery; the source and its recovery draft are retained.
  Future<String?> saveCopy() async {
    if (_saving || !state.hasValue || _text.isEmpty) return null;
    final newId = ref.read(noteIdProvider)();
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      final draft = await _repository.putDraft(
        id: newId,
        text: _text,
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await _repository.commitDraft(newId, draft.draftRevision);
      _releaseFailedBuffer?.call();
      _releaseFailedBuffer = null;
      return newId;
    } catch (_) {
      _publish(
        message: 'Copy could not be committed. Your writing is kept; check Recovery drafts and retry.',
      );
      return null;
    } finally {
      _saving = false;
      if (ref.mounted) _publish(message: state.value?.message);
      keep.close();
    }
  }

  Future<bool> discard() async {
    if (_saving) return false;
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      if (!await flushRecovery()) return false;
      if (_draftRevision != null) {
        await _repository.discardDraft(id, _draftRevision!);
        _draftRevision = null;
      }
      ref.read(noteNewIdsProvider.notifier).remove(id);
      return true;
    } catch (_) {
      _publish(message: 'Draft could not be discarded. It has been kept.');
      return false;
    } finally {
      _saving = false;
      if (ref.mounted) _publish(message: state.value?.message);
      keep.close();
    }
  }
}
