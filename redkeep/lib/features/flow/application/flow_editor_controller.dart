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
    this.editVersion = 0,
    this.saving = false,
    this.changed = false,
    this.message,
    this.sourceUnavailable = false,
  });
  final String body;
  final int baseRevision;
  final int editVersion;
  final bool saving;
  final bool changed;
  final bool sourceUnavailable;
  final String? message;
}

/// Unsaved edits stay in memory. Only an explicit save writes to storage.
class FlowEditorController extends AsyncNotifier<FlowEditorState> {
  FlowEditorController(this.documentId);
  final String? documentId;
  bool get capture => documentId == null;
  late String id;
  late FlowRepository _repository;
  late String _body;
  late String _saved;
  int _baseRevision = 0;
  int _sequence = 0;
  bool _saving = false;
  bool _unavailable = false;

  @override
  Future<FlowEditorState> build() async {
    _repository = ref.watch(flowRepositoryProvider);
    id = documentId ?? ref.read(flowIdProvider)();
    final opened = capture
        ? const OpenThought()
        : await _repository.openDocument(id);
    if (!capture && !opened.available) {
      throw const FlowException(FlowFailure.unavailable);
    }
    _body = _saved = opened.thought?.body ?? '';
    _baseRevision = opened.thought?.revision ?? 0;
    return _snapshot();
  }

  bool get _changed => _body != _saved;

  FlowEditorState _snapshot({String? message}) => FlowEditorState(
    body: _body,
    baseRevision: _baseRevision,
    editVersion: _sequence,
    saving: _saving,
    changed: _changed,
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
    _publish();
  }

  Future<bool> save() async {
    if (_saving || !state.hasValue || _body.trim().isEmpty) return false;
    if (!_changed && _baseRevision > 0) return true;
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      final saved = await _repository.save(
        id: id,
        body: _body,
        expectedRevision: _baseRevision,
      );
      _baseRevision = saved.revision;
      _saved = _body;
      _unavailable = false;
      if (capture) {
        _body = _saved = '';
        _baseRevision = 0;
        _sequence++;
        id = ref.read(flowIdProvider)();
      }
      _publish(
        message: capture
            ? 'Thought captured on this device.'
            : 'Saved revision ${saved.revision} on this device.',
      );
      return true;
    } on FlowException catch (_) {
      _unavailable = true;
      _publish(
        message: 'This thought changed or was deleted. Keep this editor open and save a copy.',
      );
      return false;
    } catch (_) {
      _publish(message: 'Save failed. Keep this editor open and retry.');
      return false;
    } finally {
      _saving = false;
      if (ref.mounted) _publish(message: state.value?.message);
      keep.close();
    }
  }

  Future<String?> saveCopy() async {
    if (_saving || !state.hasValue || _body.trim().isEmpty) return null;
    final newId = ref.read(flowIdProvider)();
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      await _repository.save(id: newId, body: _body, expectedRevision: 0);
      return newId;
    } catch (_) {
      _publish(
        message: 'Copy could not be saved. Keep this editor open and retry.',
      );
      return null;
    } finally {
      _saving = false;
      if (ref.mounted) _publish(message: state.value?.message);
      keep.close();
    }
  }

  Future<bool> discard() async {
    if (_saving || !state.hasValue) return false;
    _body = _saved;
    _sequence++;
    _publish();
    return true;
  }
}
