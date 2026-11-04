import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/domain/diary_history_contract.dart';
import 'package:redkeep/features/diary/domain/diary_history_day.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';

DiaryEntry entry(String id, String date, String body) => DiaryEntry(
  id: id,
  date: CivilDate.tryParse(date)!,
  text: DiaryText(body: body),
  revision: 1,
  createdAt: DateTime.parse(date),
  updatedAt: DateTime.parse(date),
);
void main() {
  final today = DateTime(2026, 11, 4);
  test('date scopes use civil days, exclude future writing, and retain a bounded exact-source preview', () {
    final selection = DiaryHistorySelection.select(
      question: 'What happened at the garden last week?',
      today: today,
      days: [
        DiaryHistoryDay('2026-10-28', [
          entry('a' * 32, '2026-10-28', 'I planted the garden. ' * 200),
        ]),
        DiaryHistoryDay('2026-11-05', [
          entry('b' * 32, '2026-11-05', 'Future garden writing'),
        ]),
      ],
    );
    expect(selection.sources.length, 1);
    expect(selection.sources.single.uuid, 'a' * 32);
    expect(selection.sources.single.truncated, isTrue);
    expect(
      utf8.encode(selection.request()).length,
      lessThanOrEqualTo(historyInputBytes),
    );
    expect(
      DiaryHistorySelection.decode(selection.encode()).sources.single.version,
      selection.sources.single.version,
    );
  });
  test(
    'answers reject unknown citations and identify edited/deleted sources',
    () {
      final item = entry('a' * 32, '2026-11-03', 'I planted the garden.');
      final day = DiaryHistoryDay('2026-11-03', [item]);
      final selection = DiaryHistorySelection.select(
        question: 'What did I plant?',
        today: today,
        days: [day],
      );
      final answer = DiaryHistoryAnswer.parse(
        '{"status":"answered","answer":"You planted the garden.","citations":["s0"]}',
        selection,
      );
      expect(answer.citations.single.uuid, item.id);
      expect(
        () => DiaryHistoryAnswer.parse(
          '{"status":"answered","answer":"Something else","citations":["s99"]}',
          selection,
        ),
        throwsA(isA<DiaryAnswerRejected>()),
      );
      expect(
        sourceStatus(selection.sources.single, (_) => day),
        DiarySourceStatus.current,
      );
      expect(
        sourceStatus(
          selection.sources.single,
          (_) => DiaryHistoryDay('2026-11-03', [
            entry(item.id, '2026-11-03', 'Edited words'),
          ]),
        ),
        DiarySourceStatus.edited,
      );
      expect(
        sourceStatus(selection.sources.single, (_) => null),
        DiarySourceStatus.deleted,
      );
    },
  );
}
