import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/notes/application/note_chat_controller.dart';
import 'package:redkeep/features/notes/domain/note_chat.dart';

import '../../support/notes_ai_harness.dart';

void main() {
  late NotesAiHarness h;
  setUp(() async {
    h = await NotesAiHarness.create();
    await h.save();
    // Stand in for the open chat page, which owns its request.
    h.scope.listen(noteChatProvider(notesTestId), (_, _) {});
    h.scope.listen(aiJobsProvider(noteChatScope(notesTestId)), (_, _) {});
  });
  tearDown(() => h.close());

  NoteChatController chat() =>
      h.scope.read(noteChatProvider(notesTestId).notifier);
  Future<List<NoteChatTurn>> turns() =>
      h.scope.read(noteChatsProvider).turns(notesTestId);
  AiToolCall call(String id, String name, Map<String, Object?> args) =>
      AiToolCall(id: id, name: name, arguments: args);

  Future<NoteChatAction> settled(String callId) async {
    for (var i = 0; i < 100; i++) {
      final action = (await turns()).last.actions.firstWhere(
        (a) => a.call.id == callId,
      );
      if (action.status != NoteChatActionStatus.running) return action;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('The change did not finish.');
  }

  test(
    'one change runs per reply; others are skipped, choices shown',
    () async {
      h.remote.output = 'Plant tomatoes. Water them daily.';
      h.aiProvider.turns.add(
        AiConverseReply(
          text: 'Two ideas.',
          calls: [
            call('a', 'edit_note', {
              'operation': 'clarify',
              'instruction': '',
              'passage': '',
            }),
            call('b', 'build_website', {'brief': ''}),
            call('c', 'offer_choices', {
              'question': 'Next?',
              'options': ['Shorter', 'Longer'],
            }),
            call('d', 'make_coffee', const {}),
          ],
        ),
      );
      expect(await chat().send('Polish it'), isTrue);
      final statuses = {
        for (final a in (await turns()).single.actions) a.call.id: a,
      };
      expect(statuses['b']!.status, NoteChatActionStatus.skipped);
      expect(statuses['b']!.detail, 'One change at a time.');
      expect(statuses['c']!.status, NoteChatActionStatus.shown);
      expect(statuses['d']!.status, NoteChatActionStatus.skipped);
      final edit = await settled('a');
      expect(edit.status, NoteChatActionStatus.ready);
      expect(chat().proposal(edit), isNotNull);
      // Nothing reaches the note until it is kept.
      expect(
        (await h.repository.openDocument(notesTestId)).note!.text.body,
        notesTestBody,
      );

      // A newer change sets the waiting proposal aside.
      h.aiProvider.turns.add(
        AiConverseReply(
          calls: [
            call('e', 'edit_note', {
              'operation': 'markdown',
              'instruction': '',
              'passage': '',
            }),
          ],
        ),
      );
      await chat().send('Organise it instead');
      final first = (await turns()).first.actions.first;
      expect(first.status, NoteChatActionStatus.discarded);
      expect(first.outcome, 'Set aside for a newer request.');
      await settled('e');
    },
  );

  test('a failed answer keeps nothing and says why', () async {
    h.aiProvider.failure = const AiProviderFailure(
      AiProviderFailureKind.rateLimited,
    );
    expect(await chat().send('Hello'), isFalse);
    expect(await turns(), isEmpty);
    expect(
      h.scope.read(noteChatProvider(notesTestId)).error,
      contains('rate limiting'),
    );
  });

  test('only the latest exchanges are sent as history', () async {
    for (var i = 0; i < noteChatKeptTurns + 2; i++) {
      h.aiProvider.turns.add(AiConverseReply(text: 'Reply $i'));
      await chat().send('Message $i');
    }
    expect(await turns(), hasLength(noteChatKeptTurns));
    final last = h.aiProvider.conversations.last;
    expect(last.history, hasLength(noteChatKeptTurns - 1));
    expect(last.history.last.user, 'Message $noteChatKeptTurns');
  });
}
