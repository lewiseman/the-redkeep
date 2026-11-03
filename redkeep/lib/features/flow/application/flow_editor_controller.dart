import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/thought.dart';
import '../domain/flow_repository.dart';
import 'flow_providers.dart';

final flowEditorProvider = AsyncNotifierProvider.autoDispose
    .family<FlowEditorController, FlowEditorState, String?>(
      FlowEditorController.new,
      retry: (_, _) => null,
    );

class FlowEditorState {
  const FlowEditorState({
    required this.body,
    required this.baseRevision,
    this.draftRevision,
    this.editVersion = 0,
    this.saving = false,
    this.recovering = false,
    this.recoveryFailed = false,
    this.message,
    this.sourceUnavailable = false,
  });
  final String body;
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
class FlowEditorController extends AsyncNotifier<FlowEditorState> {
  FlowEditorController(this.documentId);
  final String? documentId;
  bool get capture => documentId == null;
  late String id;
  late FlowRepository _repository;
  late String _body;
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
  Future<FlowEditorState> build() async {
    _repository = ref.watch(flowRepositoryProvider);
    final opened = capture
        ? OpenThought(draft: await _repository.openCapture())
        : await _repository.openDocument(documentId!);
    if (!capture &&
        (!opened.available && opened.draft == null ||
            opened.draft?.capture == true)) {
      throw const FlowException(FlowFailure.unavailable);
    }
    id = documentId ?? opened.draft?.id ?? ref.read(flowIdProvider)();
    _body = opened.draft?.body ?? opened.thought?.body ?? '';
    _baseRevision = opened.draft?.baseRevision ?? opened.thought?.revision ?? 0;
    _draftRevision = opened.draft?.draftRevision;
    _unavailable = !opened.available && _baseRevision != 0;
    return _snapshot(
      message: opened.draft == null
          ? null
          : 'Recovery draft reopened. Save to commit this writing.',
    );
  }

  FlowEditorState _snapshot({String? message}) => FlowEditorState(
    body: _body,
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

  void edit(String body) {
    if (_saving || !state.hasValue) return;
    _body = body;
    _sequence++;
    _recoveryFailed = false;
    _publish();
    unawaited(flushRecovery());
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
      final body = _body;
      try {
        final draft = await _repository.putDraft(
          id: id,
          capture: capture,
          body: body,
          baseRevision: _baseRevision,
          expectedDraftRevision: _draftRevision,
        );
        _draftRevision = draft.draftRevision;
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
    if (_saving || !state.hasValue || _body.trim().isEmpty) return false;
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      if (!await flushRecovery()) return false;
      if (_draftRevision == null) return true;
      final saved = await _repository.commitDraft(id, _draftRevision!);
      _draftRevision = null;
      _baseRevision = saved.revision;
      _unavailable = false;
      if (capture) {
        // Only a committed transaction can clear the working composer.
        _body = '';
        _baseRevision = 0;
        _sequence = 0;
        _persistedSequence = 0;
        id = ref.read(flowIdProvider)();
      }
      _saving = false;
      _publish(
        message: capture
            ? 'Thought captured on this device.'
            : 'Saved revision ${saved.revision} on this device.',
      );
      return true;
    } on FlowException catch (error) {
      _saving = false;
      if (error.failure == FlowFailure.draftChanged) {
        _recoveryFailed = true;
        _persistedSequence = -1;
        if (ref.mounted) _releaseFailedBuffer ??= ref.keepAlive().close;
      }
      _publish(
        message: error.failure == FlowFailure.draftChanged
            ? 'The recovery draft changed elsewhere. Keep this editor open and save a copy.'
            : 'This thought changed or was deleted. Your recovery draft is kept. Save a copy to keep both versions.',
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
    if (_saving || !state.hasValue) return null;
    final newId = ref.read(flowIdProvider)();
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      final draft = await _repository.putDraft(
        id: newId,
        capture: false,
        body: _body,
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
      }
      _releaseFailedBuffer?.call();
      _releaseFailedBuffer = null;
      if (capture) {
        _body = '';
        _baseRevision = 0;
        _draftRevision = null;
        _sequence = _persistedSequence = 0;
        id = ref.read(flowIdProvider)();
      }
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
