import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../data/drift_note_websites.dart';
import '../domain/note_checklist.dart';
import '../domain/note_document.dart';
import '../domain/website/website_contract.dart';
import 'notes_providers.dart';

/// Asks the person whether a tick on the page may change the note.
/// `remember` turns asking off for this website.
typedef NoteWebsiteCheckConfirm =
    Future<({bool allow, bool remember})> Function(String item, bool done);

/// The app's side of `window.redkeep`: the only things a page can ask for.
/// It may keep a little state for itself, tick or untick a checklist item
/// that is already in the note (after the person agrees), and ask for a
/// haptic tap. Everything else, and anything malformed, is ignored.
class NoteWebsiteBridge {
  NoteWebsiteBridge(
    this.scope,
    this.noteId, {
    required this.confirm,
    this.saveDelay = const Duration(milliseconds: 400),
  });

  /// The app's providers; a page's view passes its own scope.
  final ProviderContainer scope;
  final String noteId;
  final NoteWebsiteCheckConfirm confirm;
  final Duration saveDelay;

  static const messageBytes = DriftNoteWebsites.stateBytes + 1024;

  Timer? _saveTimer;
  String? _pendingState;
  Future<void> _checks = Future.value();
  bool _closed = false;

  /// Handles one message from the page. For a request that expects an
  /// answer, returns its id and result for the page's promise.
  Future<({Object id, bool ok})?> handle(String raw) async {
    if (_closed || raw.length > messageBytes) return null;
    Object? message;
    try {
      message = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (message is! Map) return null;
    switch (message['type']) {
      case 'save':
        _queueSave(message['state']);
        return null;
      case 'check':
        final Object? id = message['id'];
        final text = message['text'];
        final done = message['done'];
        if ((id is! int && id is! String) || text is! String || done is! bool) {
          return null;
        }
        // One at a time, so two quick ticks never race or double-ask.
        final result = Completer<bool>();
        _checks = _checks.then((_) async {
          try {
            result.complete(await _check(text, done));
          } catch (_) {
            result.complete(false);
          }
        });
        return (id: id!, ok: await result.future);
      case 'haptic':
        await switch (message['kind']) {
          'medium' => HapticFeedback.mediumImpact(),
          'heavy' => HapticFeedback.heavyImpact(),
          'selection' => HapticFeedback.selectionClick(),
          'success' => HapticFeedback.mediumImpact(),
          _ => HapticFeedback.lightImpact(),
        };
        return null;
    }
    return null;
  }

  void _queueSave(Object? state) {
    final String text;
    try {
      text = jsonEncode(state);
    } catch (_) {
      return;
    }
    if (text.length > DriftNoteWebsites.stateBytes) return;
    _pendingState = text;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, flush);
  }

  /// Writes a waiting save now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    final state = _pendingState;
    _pendingState = null;
    if (state == null || !scope.read(syncCanEditProvider)) return;
    try {
      await scope.read(noteWebsitesProvider).saveState(noteId, state);
    } catch (_) {
      // A page that cannot save simply forgets; the note is never affected.
    }
  }

  Future<bool> _check(String text, bool done) async {
    if (!scope.read(syncCanEditProvider)) return false;
    final repo = scope.read(notesRepositoryProvider);
    final opened = await repo.openDocument(noteId);
    final note = opened.note;
    if (!opened.available || note == null) return false;
    final body = note.text.body;
    final changed = setNoteChecklistItem(body, text, done);
    if (changed == null) return false;
    if (changed == body) return true;
    final websites = scope.read(noteWebsitesProvider);
    final website = await websites.get(noteId);
    if (website == null) return false;
    if (!website.syncChecks) {
      final item = noteChecklist(body)
          .firstWhere(
            (i) => i.text == text.trim() || i.plain == noteChecklistPlain(text),
          )
          .plain;
      final answer = await confirm(item, done);
      if (!answer.allow || _closed) return false;
      if (answer.remember) await websites.setSyncChecks(noteId, true);
    }
    // The note may have moved on while the person decided.
    final current = (await repo.openDocument(noteId)).note;
    if (current == null || current.revision != note.revision) return false;
    await repo.applyProposal(
      noteId,
      note.revision,
      text: PlainTextDocument(title: note.text.title, body: changed),
      details: note.details.copy(tags: note.tags),
    );
    // The page made this change itself, so it still matches the note.
    await websites.followNote(
      noteId,
      from: websiteContentHash(body),
      to: websiteContentHash(changed),
    );
    return true;
  }

  /// Saves what is waiting and stops answering the page.
  Future<void> close() async {
    await flush();
    _closed = true;
  }
}
