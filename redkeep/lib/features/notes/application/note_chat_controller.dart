import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../../ai/domain/ai_provider.dart';
import '../../sync/application/sync_providers.dart';
import '../data/drift_note_chats.dart';
import '../domain/note_chat.dart';
import '../domain/note_chat_contract.dart';
import 'note_ai_controller.dart';
import 'note_editor_controller.dart';
import 'notes_providers.dart';

final noteChatsProvider = Provider<DriftNoteChats>(
  (ref) => DriftNoteChats(ref.watch(appDatabaseProvider)),
);

/// The note's kept exchanges, oldest first.
final noteChatTurnsProvider = StreamProvider.autoDispose
    .family<List<NoteChatTurn>, String>(
      (ref, id) => ref.watch(noteChatsProvider).watch(id),
    );

/// The chat's one change request. The chat page owns it: leaving the page
/// stops it, as with every notes AI tool.
String noteChatScope(String id) => noteAiScope('chat', id);

class NoteChatState {
  const NoteChatState({this.pending, this.error});

  /// What the person sent, while the Maester answers.
  final String? pending;

  /// Why the last message could not be answered; it was not kept.
  final String? error;
  bool get sending => pending != null;
}

final noteChatProvider = NotifierProvider.autoDispose
    .family<NoteChatController, NoteChatState, String>(NoteChatController.new);

class NoteChatController extends Notifier<NoteChatState> {
  NoteChatController(this.id);
  final String id;
  Completer<void>? _abort;

  @override
  NoteChatState build() {
    ref.onDispose(_stopSending);
    return const NoteChatState();
  }

  void _stopSending() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  String get _scope => noteChatScope(id);
  DriftNoteChats get _chats => ref.read(noteChatsProvider);

  /// What the Maester is told about the note: the open writing when it is
  /// being edited, else the saved note.
  Future<NoteChatContext> _context() async {
    final opened = await ref.read(notesRepositoryProvider).openDocument(id);
    final editing = ref.exists(noteEditorProvider(id))
        ? ref.read(noteEditorProvider(id)).value
        : null;
    final note = opened.note;
    if ((note == null || !opened.available) && editing == null) {
      throw const FormatException('This note is unavailable.');
    }
    final text = editing?.text ?? note!.text;
    final website = note == null
        ? null
        : await ref.read(noteWebsitesProvider).get(id);
    return NoteChatContext(
      title: text.title,
      body: text.body,
      saved: note != null,
      canEdit: ref.read(syncCanEditProvider),
      website: website == null
          ? null
          : NoteChatWebsite(
              brief: website.brief,
              madeAt: website.madeAt,
              outdated: website.isOutdatedFor(text.body),
            ),
    );
  }

  /// Sends [message]. Returns false when nothing was sent or the answer
  /// could not be kept; [NoteChatState.error] says why.
  Future<bool> send(String message) async {
    final ask = message.trim();
    if (state.sending || ask.isEmpty) return false;
    if (ask.runes.length > noteChatMessageChars) {
      state = const NoteChatState(
        error: 'Keep a message to at most $noteChatMessageChars characters.',
      );
      return false;
    }
    _stopSending();
    final abort = _abort = Completer<void>();
    state = NoteChatState(pending: ask);
    try {
      final context = await _context();
      final earlier = await _chats.turns(id);
      // The new exchange is the tenth; older ones are no longer sent.
      final history = [
        for (final turn in earlier.skip(
          earlier.length < noteChatKeptTurns
              ? 0
              : earlier.length - noteChatKeptTurns + 1,
        ))
          turn.exchange,
      ];
      final reply = await ref
          .read(aiCloudProvider)
          .converse(
            system: noteChatSystem(context, today: ref.read(aiClockProvider)()),
            history: history,
            user: ask,
            tools: NoteChatTools.forContext(context),
            outputTokens: noteChatOutputTokens,
            abort: abort.future,
          );
      if (!ref.mounted || abort.isCompleted) return false;
      final jobs = ref.read(aiJobsProvider(_scope));
      final actions = <NoteChatAction>[];
      NoteChatAction? run;
      NoteChatIntent? intent;
      for (final call in reply.calls.take(6)) {
        NoteChatIntent parsed;
        try {
          parsed = NoteChatIntent.parse(call, context);
        } on FormatException catch (error) {
          actions.add(
            NoteChatAction(
              call: call,
              status: NoteChatActionStatus.skipped,
              detail: error.message,
            ),
          );
          continue;
        }
        if (!parsed.runs) {
          actions.add(
            NoteChatAction(call: call, status: NoteChatActionStatus.shown),
          );
        } else if (run != null || jobs.busy) {
          actions.add(
            NoteChatAction(
              call: call,
              status: NoteChatActionStatus.skipped,
              detail: 'One change at a time.',
            ),
          );
        } else {
          intent = parsed;
          run = NoteChatAction(
            call: call,
            status: NoteChatActionStatus.running,
          );
          actions.add(run);
        }
      }
      final turn = NoteChatTurn(
        id: ref.read(aiIdProvider)(),
        noteId: id,
        at: ref.read(aiClockProvider)().toUtc(),
        ask: ask,
        reply: reply.text.trim(),
        actions: actions,
      );
      if (run != null) await _setAsideOpen();
      await _chats.add(turn);
      state = const NoteChatState();
      if (run != null && intent != null) {
        unawaited(_run(turn.id, run.call.id, intent));
      }
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      final cancelled =
          error is AiProviderFailure &&
          error.kind == AiProviderFailureKind.cancelled;
      state = NoteChatState(error: cancelled ? null : aiErrorMessage(error));
      return false;
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  /// Stops waiting for the Maester's answer. Nothing is kept.
  void stopSending() {
    _stopSending();
    if (ref.mounted) state = const NoteChatState();
  }

  /// A proposal still waiting when a newer one starts is set aside: the
  /// chat has room for one request.
  Future<void> _setAsideOpen() async {
    for (final turn in await _chats.turns(id)) {
      for (final action in turn.actions) {
        if (action.status.open) {
          await _chats.updateAction(
            turn.id,
            action.call.id,
            (a) => a.copy(
              status: NoteChatActionStatus.discarded,
              detail: 'Set aside for a newer request.',
            ),
          );
        }
      }
    }
    await ref.read(aiJobsProvider(_scope).notifier).clear();
  }

  Future<void> _run(String turnId, String callId, NoteChatIntent intent) async {
    final chats = _chats;
    final controller = ref.read(noteAiControllerProvider);
    Future<void> mark(NoteChatAction Function(NoteChatAction) change) async {
      try {
        await chats.updateAction(turnId, callId, change);
      } catch (_) {
        /* The chat was reset or cleared meanwhile. */
      }
    }

    try {
      switch (intent) {
        case NoteChatEdit(:final operation, :final instruction, :final passage):
          // The part is found again in the writing as it is now.
          final range = passage.isEmpty
              ? null
              : noteChatPassageRange((await _context()).body, passage);
          if (passage.isNotEmpty && range == null) {
            throw const FormatException(
              'That part of the note changed. Ask again.',
            );
          }
          await controller.start(
            operation,
            id,
            scope: _scope,
            intent: instruction,
            selectionStart: range?.start,
            selectionEnd: range?.end,
          );
        case NoteChatDraft(:final idea):
          await controller.start(
            AiOperation.noteDraft,
            id,
            scope: _scope,
            topic: idea,
          );
        case NoteChatBuildWebsite(:final brief):
          await controller.start(
            AiOperation.noteWebsite,
            id,
            scope: _scope,
            description: brief,
          );
        case NoteChatUpdateWebsite(:final instruction):
          await controller.start(
            AiOperation.noteWebsiteRemix,
            id,
            scope: _scope,
            intent: instruction,
          );
        case NoteChatChoices():
          return;
      }
    } catch (error) {
      await mark(
        (a) => a.copy(
          status: NoteChatActionStatus.failed,
          detail: aiErrorMessage(error),
        ),
      );
      return;
    }
    if (!ref.mounted) return;
    final jobs = ref.read(aiJobsProvider(_scope));
    final job = jobs.job;
    if (job == null || job.phase == 'cancelled') {
      await mark((a) => a.copy(status: NoteChatActionStatus.stopped));
      return;
    }
    if (job.phase != 'completed') {
      await mark(
        (a) => a.copy(
          status: NoteChatActionStatus.failed,
          detail: jobs.message ?? 'The Maester could not finish.',
        ),
      );
      return;
    }
    // Websites live beside the note and can be undone, so they land at
    // once; words in the note wait to be kept.
    if (intent is NoteChatBuildWebsite || intent is NoteChatUpdateWebsite) {
      try {
        await controller.apply(job, scope: _scope);
        await mark((a) => a.copy(status: NoteChatActionStatus.kept));
      } catch (error) {
        await mark(
          (a) => a.copy(
            status: NoteChatActionStatus.failed,
            detail: aiErrorMessage(error),
          ),
        );
      }
      return;
    }
    await mark(
      (a) => a.copy(status: NoteChatActionStatus.ready, jobId: job.id),
    );
  }

  /// The proposal behind [action], while it can still be reviewed.
  AiJob? proposal(NoteChatAction action) {
    final job = ref.read(aiJobsProvider(_scope)).job;
    return job != null &&
            action.status == NoteChatActionStatus.ready &&
            job.id == action.jobId &&
            job.phase == 'completed'
        ? job
        : null;
  }

  /// Keeps a reviewed proposal in the note. Throws [FormatException] with a
  /// reason when it cannot.
  Future<void> keep(NoteChatTurn turn, NoteChatAction action) async {
    final job = proposal(action);
    if (job == null) {
      throw const FormatException('This proposal is no longer available.');
    }
    await ref.read(noteAiControllerProvider).apply(job, scope: _scope);
    await _chats.updateAction(
      turn.id,
      action.call.id,
      (a) => a.copy(status: NoteChatActionStatus.kept),
    );
  }

  Future<void> discard(NoteChatTurn turn, NoteChatAction action) async {
    if (proposal(action) != null) {
      await ref.read(aiJobsProvider(_scope).notifier).clear();
    }
    await _chats.updateAction(
      turn.id,
      action.call.id,
      (a) => a.copy(status: NoteChatActionStatus.discarded),
    );
  }

  /// Stops the change being made; the running card records it.
  Future<void> stop() => ref.read(aiJobsProvider(_scope).notifier).cancel();

  /// Puts back the website from before the last change.
  Future<bool> undoWebsite() => ref.read(noteWebsitesProvider).undo(id);

  /// Forgets this note's conversation on this device.
  Future<void> clear() async {
    _stopSending();
    await ref.read(aiJobsProvider(_scope).notifier).clear();
    await _chats.clear(id);
    if (ref.mounted) state = const NoteChatState();
  }
}
