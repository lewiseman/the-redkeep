import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diary_document.dart';
import '../domain/diary_repository.dart';
import 'diary_providers.dart';

final diaryEditorProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryEditorController, DiaryEditorState, DiaryAddress>(
      DiaryEditorController.new,
      retry: (_, _) => null,
    );

class DiaryEditorState {
  const DiaryEditorState({
    required this.text,
    required this.baseRevision,
    this.editVersion = 0,
    this.saving = false,
    this.changed = false,
    this.message,
    this.sourceUnavailable = false,
  });
  final DiaryText text;
  final int baseRevision;
  final int editVersion;
  final bool saving;
  final bool changed;
  final bool sourceUnavailable;
  final String? message;
}

/// Unsaved edits stay in memory. Only an explicit save writes to storage.
class DiaryEditorController extends AsyncNotifier<DiaryEditorState> {
  DiaryEditorController(this.address);
  final DiaryAddress address;
  String get id => address.id;
  late DiaryRepository _repository;
  late DiaryText _text;
  late DiaryText _saved;
  int _baseRevision = 0;
  int _sequence = 0;
  bool _saving = false;
  bool _unavailable = false;

  @override
  Future<DiaryEditorState> build() async {
    _repository = ref.watch(diaryRepositoryProvider);
    final opened = await _repository.openDocument(id);
    if (opened.entry == null
        ? !ref.read(diaryNewIdsProvider).contains(id)
        : !opened.available || opened.date != address.date) {
      throw const DiaryException(DiaryFailure.unavailable);
    }
    _text = _saved = opened.entry?.text ?? const DiaryText();
    _baseRevision = opened.entry?.revision ?? 0;
    return _snapshot();
  }

  bool get _changed => _text.title != _saved.title || _text.body != _saved.body;

  DiaryEditorState _snapshot({String? message}) => DiaryEditorState(
    text: _text,
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

  void edit(DiaryText text) {
    if (_saving || !state.hasValue) return;
    _text = text;
    _sequence++;
    _publish();
  }

  Future<bool> save() async {
    if (_saving || !state.hasValue || _text.isEmpty) return false;
    if (!_changed && _baseRevision > 0) return true;
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      final saved = await _repository.save(
        id: id,
        date: address.date,
        text: _text,
        expectedRevision: _baseRevision,
      );
      _baseRevision = saved.revision;
      ref.read(diaryNewIdsProvider.notifier).remove(id);
      _saved = _text;
      _unavailable = false;
      _publish(message: 'Saved revision ${saved.revision} on this device.');
      return true;
    } on DiaryException catch (_) {
      _unavailable = true;
      _publish(
        message: 'This entry changed or was deleted. Keep this editor open and save a copy.',
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
    if (_saving || !state.hasValue || _text.isEmpty) return null;
    final newId = ref.read(diaryIdProvider)();
    _saving = true;
    _publish();
    final keep = ref.keepAlive();
    try {
      await _repository.save(
        id: newId,
        date: address.date,
        text: _text,
        expectedRevision: 0,
      );
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
    _text = _saved;
    ref.read(diaryNewIdsProvider.notifier).remove(id);
    _sequence++;
    _publish();
    return true;
  }
}
