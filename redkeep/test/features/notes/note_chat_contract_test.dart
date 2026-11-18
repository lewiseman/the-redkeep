import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/domain/ai_conversation.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/notes/domain/note_chat_contract.dart';

void main() {
  const body = 'Plant tomatoes.\n\nWater them every morning.';
  NoteChatContext context({String text = body}) =>
      NoteChatContext(title: 'Garden', body: text, saved: true);
  AiToolCall call(String name, Map<String, Object?> arguments) =>
      AiToolCall(id: 'c', name: name, arguments: arguments);
  Set<String> tools(NoteChatContext c) =>
      NoteChatTools.forContext(c).map((t) => t.name).toSet();

  test('offers only the tools that fit the note now', () {
    expect(tools(context()), {'edit_note', 'offer_choices'});
    expect(tools(context(text: '  ')), {'draft_note', 'offer_choices'});
  });

  test('edits name a known kind and, optionally, one exact passage', () {
    final edit = NoteChatIntent.parse(
      call('edit_note', {
        'operation': 'markdown',
        'instruction': '',
        'passage': 'Water them every morning.',
      }),
      context(),
    ) as NoteChatEdit;
    expect(edit.operation, AiOperation.noteMarkdown);
    expect(noteChatPassageRange(body, edit.passage), (
      start: 17,
      end: body.length,
    ));
    for (final bad in [
      {'operation': 'delete', 'instruction': 'x', 'passage': ''},
      {'operation': 'custom', 'instruction': '  ', 'passage': ''},
      {'operation': 'rewrite', 'instruction': 'x', 'passage': 'Not there'},
      {'operation': 'rewrite', 'instruction': 'é' * 241, 'passage': ''},
    ]) {
      expect(
        () => NoteChatIntent.parse(call('edit_note', bad), context()),
        throwsFormatException,
        reason: '$bad',
      );
    }
    // A tool the note does not offer now is refused.
    expect(
      () => NoteChatIntent.parse(
        call('draft_note', {'idea': 'A garden plan'}),
        context(),
      ),
      throwsFormatException,
    );
  });

  test('choices are two to four short, distinct replies', () {
    final choices = NoteChatIntent.parse(
      call('offer_choices', {
        'question': 'Which look?',
        'options': ['Dark', 'dark', 'Light'],
      }),
      context(),
    ) as NoteChatChoices;
    expect(choices.options, ['Dark', 'Light']);
    expect(choices.runs, isFalse);
    for (final options in [
      ['Only one'],
      ['a', 'b', 'c', 'd', 'e'],
      ['x' * 61, 'ok'],
      ['Same', 'same'],
    ]) {
      expect(
        () => NoteChatIntent.parse(
          call('offer_choices', {'question': '', 'options': options}),
          context(),
        ),
        throwsFormatException,
        reason: '$options',
      );
    }
  });

  test('the system prompt carries the note as data', () {
    final system = noteChatSystem(
      context(text: 'é' * 7000),
      today: DateTime.utc(2026, 11, 12),
    );
    expect(system, contains('2026-11-12'));
    expect(system, contains('untrusted data'));
    expect(system, isNot(contains('website')));
    // A long note is cut to the byte budget, on a character boundary.
    expect(system, contains('Only the start of a long note is shown.'));
    expect('é'.allMatches(system).length, noteChatBodyBytes ~/ 2);
  });
}
