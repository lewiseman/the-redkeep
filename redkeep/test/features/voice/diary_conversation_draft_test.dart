import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/voice/application/diary_conversation_draft.dart';

void main() {
  final date = DiaryPeriod(2026, 11, 4), now = DateTime.utc(2026, 11, 4);
  const turns = [
    {'speaker': 'user', 'text': 'Today I enjoyed walking home.'},
  ];
  DiaryEntry entry({int revision = 1, String body = ''}) => DiaryEntry(
    id: 'a' * 32,
    date: date,
    text: DiaryText(body: body),
    revision: revision,
    createdAt: now,
    updatedAt: now,
    conversation: DiaryAiConversation(turns: turns, createdAt: now),
  );
  Map<String, dynamic> source() => {
    'id': 'a' * 32,
    'date': date.key,
    'revision': 0,
    'new': true,
    'turns': turns,
  };
  test('a recovered secondary creation can use its exact first append', () {
    expect(conversationDraftRevision(entry(), source()), 1);
  });
  test('later changes and existing words never adopt a new save revision', () {
    expect(conversationDraftRevision(entry(revision: 2), source()), 0);
    expect(conversationDraftRevision(entry(body: 'Manual words'), source()), 0);
    expect(conversationDraftRevision(entry(), source()..remove('new')), 0);
  });
  test('another date, entry, or changed turns cannot use the result', () {
    for (final changed in [
      source()..['id'] = 'b' * 32,
      source()..['date'] = '2026-11-03',
      source()
        ..['turns'] = [
          {'speaker': 'user', 'text': 'Different words'},
        ],
    ]) {
      expect(
        () => conversationDraftRevision(entry(), changed),
        throwsStateError,
      );
    }
  });
}
