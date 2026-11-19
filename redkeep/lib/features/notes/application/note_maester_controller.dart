import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_jobs.dart' show aiErrorMessage;
import '../../ai/domain/ai_operation.dart';
import '../../ai/domain/ai_provider.dart';
import '../domain/note_document.dart';
import '../domain/note_rich_markdown.dart';
import '../domain/transform_contract.dart';
import 'notes_providers.dart';

/// The most writing the Maester rewrites at once, in UTF-8 bytes.
const noteMaesterTextBytes = 16384;

/// Room for a rewrite of [noteMaesterTextBytes] and some growth.
const noteMaesterOutputTokens = 8192;

/// What the Maester rewrites: [text], between [before] and [after], which
/// stay as they are. The whole body has both empty.
class NoteMaesterPassage {
  const NoteMaesterPassage({
    this.before = '',
    required this.text,
    this.after = '',
  });
  final String before, text, after;
  bool get whole => before.isEmpty && after.isEmpty;
  String join(String replacement) => '$before$replacement$after';
}

class NoteMaesterState {
  const NoteMaesterState({this.working = false, this.preview, this.error});

  /// The Maester is writing; editing waits until it is done.
  final bool working;

  /// The body as it is being rewritten. Null shows the note itself.
  final String? preview;

  /// Why the last request changed nothing.
  final String? error;
}

/// The note page's one Maester request. Nothing is kept between requests,
/// and leaving the note page stops the one in progress, changing nothing.
final noteMaesterProvider = NotifierProvider.autoDispose
    .family<NoteMaesterController, NoteMaesterState, String>(
      NoteMaesterController.new,
    );

class NoteMaesterController extends Notifier<NoteMaesterState> {
  NoteMaesterController(this.id);
  final String id;
  Completer<void>? _abort;

  /// How often the streamed body is shown: often enough to read as typing,
  /// rarely enough that long notes stay smooth.
  static const _frame = Duration(milliseconds: 50);

  @override
  NoteMaesterState build() {
    ref.onDispose(_cancel);
    return const NoteMaesterState();
  }

  void _cancel() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  /// Stops the request. The note stays as it was.
  void stop() {
    _cancel();
    if (ref.mounted) state = const NoteMaesterState();
  }

  void clearError() {
    if (state.error != null) state = NoteMaesterState(working: state.working);
  }

  /// Rewrites the saved note as [instruction] asks: all of it, or the
  /// [part] of its body that function picks. That part clears as the new
  /// words stream in, then they replace it.
  Future<bool> rewriteNote(
    String instruction, {
    NoteMaesterPassage Function(String body)? part,
  }) async {
    final opened = await ref.read(notesRepositoryProvider).openDocument(id);
    final note = opened.note;
    if (note == null || !opened.available) {
      if (ref.mounted) {
        state = const NoteMaesterState(error: 'This note is unavailable.');
      }
      return false;
    }
    final NoteMaesterPassage passage;
    try {
      passage =
          part?.call(note.text.body) ??
          NoteMaesterPassage(text: note.text.body);
    } on FormatException catch (error) {
      if (ref.mounted) state = NoteMaesterState(error: error.message);
      return false;
    }
    return _rewrite(
      instruction,
      passage,
      keep: (body) async {
        try {
          await ref
              .read(notesRepositoryProvider)
              .applyProposal(
                id,
                note.revision,
                text: PlainTextDocument(title: note.text.title, body: body),
                details: note.details.copy(tags: note.tags),
              );
        } on NoteException {
          throw const FormatException(
            'This note changed while the Maester wrote, so nothing was changed.',
          );
        }
      },
    );
  }

  Future<bool> _rewrite(
    String instruction,
    NoteMaesterPassage passage, {
    required Future<void> Function(String body) keep,
  }) async {
    final ask = instruction.trim();
    if (state.working || ask.isEmpty) return false;
    final problem = utf8.encode(ask).length > transformIntentBytes
        ? 'Keep the request to at most $transformIntentBytes bytes.'
        : utf8.encode(passage.text).length > noteMaesterTextBytes
        ? passage.whole
              ? 'This note is too long to rewrite at once. Select a part of it while editing.'
              : 'Select a shorter part to rewrite.'
        : null;
    if (problem != null) {
      state = NoteMaesterState(error: problem);
      return false;
    }
    final abort = _abort = Completer<void>();
    // The note stays as it is until the answer starts arriving.
    state = const NoteMaesterState(working: true);
    final written = StringBuffer();
    var shownAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final stream = ref
          .read(aiCloudProvider)
          .chatStream(
            system: AiOperation.noteCustom.system,
            user: jsonEncode({'text': passage.text, 'intent': ask}),
            outputTokens: noteMaesterOutputTokens,
            abort: abort.future,
          );
      await for (final piece in stream) {
        if (!ref.mounted || abort.isCompleted) return false;
        written.write(piece);
        final now = DateTime.now();
        if (now.difference(shownAt) >= _frame) {
          shownAt = now;
          state = NoteMaesterState(
            working: true,
            preview: passage.join(_streaming(written.toString())),
          );
        }
      }
      if (!ref.mounted || abort.isCompleted) return false;
      final replacement = _finished(written.toString(), passage);
      final body = passage.join(replacement);
      if (!richCompatible(body)) {
        throw const FormatException(richIncompatibleMessage);
      }
      state = NoteMaesterState(working: true, preview: body);
      await keep(body);
      if (ref.mounted) state = const NoteMaesterState();
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      final cancelled =
          abort.isCompleted ||
          error is AiProviderFailure &&
              error.kind == AiProviderFailureKind.cancelled;
      state = NoteMaesterState(error: cancelled ? null : aiErrorMessage(error));
      return false;
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }
}

/// While streaming, an opening code fence some models add is not shown.
String _streaming(String text) =>
    text.replaceFirst(RegExp(r'^\s*```[A-Za-z0-9_-]*[ \t]*(\r?\n|$)'), '');

/// The finished replacement, checked like every AI edit of a note.
String _finished(String text, NoteMaesterPassage passage) {
  var value = stripSurroundingCodeFence(text).replaceAll('\r\n', '\n');
  // A whole note keeps no stray blank lines around it.
  if (passage.whole) value = value.trim();
  if (value.trim().isEmpty ||
      RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(value) ||
      RegExp(r'</?[a-z][^>]*>', caseSensitive: false).hasMatch(value)) {
    throw const FormatException(
      'The Maester returned writing that could not be used. Try again.',
    );
  }
  return value;
}
