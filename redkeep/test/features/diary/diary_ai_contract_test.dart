import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_ai_contract.dart';
import 'package:redkeep/features/diary/domain/daily_question_contract.dart';

void main() {
  final date = DiaryPeriod(2026, 11, 4);
  DiaryEntry entry(
    String id,
    String body, {
    DiaryPeriod? day,
    int revision = 1,
  }) => DiaryEntry(
    id: id,
    date: day ?? date,
    text: DiaryText(body: body),
    revision: revision,
    createdAt: DateTime.utc(2026, 11, 4),
    updatedAt: DateTime.utc(2026, 11, 4),
  );
  test('day suggestions are grounded, sensitive inventions are dropped, and mixed stays unsuggested', () {
    final source = DiarySuggestionSource.fromEntries(date, [
      entry('a', 'I felt calm planting the garden.'),
    ]);
    final output = jsonEncode({
      'title': 'Garden morning',
      'mood': {'value': 'calm', 'evidence': 'felt calm'},
      'themes': [
        {'label': 'Gardening', 'evidence': 'planting the garden'},
      ],
    });
    final result = DiarySuggestions.parse(output, source);
    expect(result.title, 'Garden morning');
    expect(result.mood.mood?.name, 'calm');
    final invalid = DiarySuggestions.parse(
      jsonEncode({
        'title': 'A distant spaceship',
        'mood': {'value': 'happy', 'evidence': 'felt happy'},
        'themes': [
          {'label': 'Depression', 'evidence': 'planting the garden'},
        ],
      }),
      source,
    );
    expect(invalid.title, isNull);
    expect(invalid.mood.mood, isNull);
    expect(invalid.themes, isEmpty);
    expect(invalid.dropped, 3);
    final mixed = DiarySuggestions.parse(
      jsonEncode({
        'title': '',
        'mood': {'value': 'mixed', 'evidence': 'felt calm'},
        'themes': [],
      }),
      source,
    );
    expect(mixed.mood.mood, isNull);
    expect(
      () => DiarySuggestions.parse('not json', source),
      throwsFormatException,
    );
    expect(
      () => DiarySuggestionSource.fromEntries(date, [
        entry('a', 'x' * 2001),
      ]).request(),
      throwsFormatException,
    );
    expect(
      () => DiarySuggestionSource.fromEntries(date, []).request(),
      throwsFormatException,
    );
  });
  test('a brief good day keeps a grounded title, mood and theme from the companion', () {
    final source = DiarySuggestionSource.fromEntries(date, [
      entry('a', 'today was a good day'),
    ]);
    for (final title in [
      'A good day',
      'A happy day',
      'A positive day',
      'A day of joy',
    ]) {
      final result = DiarySuggestions.parse(
        jsonEncode({
          'title': title,
          'mood': {'value': 'happy', 'evidence': 'a good day'},
          'themes': [
            {'label': 'Positivity', 'evidence': 'a good day'},
          ],
        }),
        source,
      );
      expect(result.title, title);
      expect(result.mood.mood?.name, 'happy');
      expect(result.themes.single.label, 'Positivity');
      expect(result.dropped, 0);
    }
    expect(source.titleGrounded('Winning the lottery'), false);
    expect(source.titleGrounded('Happy holiday in Paris'), false);
  });
  test('short source words can support titles without matching inside unrelated words', () {
    final source = DiarySuggestionSource.fromEntries(date, [
      entry('a', 'I sat by the sea in the sun.'),
    ]);
    expect(source.titleGrounded('Sun and sea'), true);
    final unrelated = DiarySuggestionSource.fromEntries(date, [
      entry('a', 'I started cleaning the garden.'),
    ]);
    expect(unrelated.titleGrounded('Art day'), false);
    expect(unrelated.titleGrounded('And the moon'), false);
    final negative = DiarySuggestionSource.fromEntries(date, [
      entry('a', "today wasn't a good day"),
    ]);
    expect(negative.titleGrounded('A happy day'), false);
  });
  test('omitted fields are distinguished from suggestions rejected against the source', () {
    final source = DiarySuggestionSource.fromEntries(date, [
      entry('a', 'today was a good day'),
    ]);
    final absent = DiarySuggestions.parse(
      jsonEncode({
        'title': '',
        'mood': {'value': 'happy', 'evidence': 'good day'},
        'themes': [],
      }),
      source,
    );
    expect(absent.rejectedFields, isEmpty);
    expect(absent.dropped, 0);
    final rejected = DiarySuggestions.parse(
      jsonEncode({
        'title': 'Winning the lottery',
        'mood': {'value': 'happy', 'evidence': 'good day'},
        'themes': [
          {'label': 'Success', 'evidence': 'won the lottery'},
        ],
      }),
      source,
    );
    expect(rejected.rejectedFields, {'title', 'themes'});
    expect(rejected.dropped, 2);
  });

  test(
    'daily selection is bounded and basis changes when saved text changes',
    () {
      final items = [
        for (var i = 0; i < 6; i++) entry('today$i', 'Garden observation $i'),
      ];
      final older = [
        for (var i = 0; i < 12; i++)
          entry('older$i', 'An earlier observation $i', day: date.shift(-1)),
      ];
      final source = DailyQuestionSource.select(
        today: date.key,
        day: (key) => key == date.key
            ? items
            : key == date.shift(-1)!.key
            ? older
            : const [],
        avoid: ['What stood out yesterday?'],
      );
      expect(source.today.length, 4);
      expect(source.prior.length, 8);
      expect(utf8.encode(source.request()).length, lessThanOrEqualTo(2000));
      final edited = [
        entry('today0', 'Different writing', revision: 2),
        ...items.skip(1),
      ];
      expect(dailyQuestionBasis(date.key, edited), isNot(source.basis));
      expect(source.request(), isNot(contains('today0')));
      expect(source.request(), isNot(contains(date.key)));
      final question = DailyQuestion.parse(
        jsonEncode({
          'question': 'What did you notice in the garden?',
          'source': 't0',
          'evidence': 'Garden observation',
        }),
        source,
      );
      expect(question.grounded, isTrue);
      expect(
        () => DailyQuestion.parse(
          jsonEncode({
            'question': 'What stood out yesterday?',
            'source': '',
            'evidence': '',
          }),
          source,
        ),
        throwsA(isA<DailyQuestionRejected>()),
      );
      expect(
        () => DailyQuestion.parse(
          jsonEncode({
            'question': 'How is the garden today?',
            'source': 'p0',
            'evidence': 'earlier observation',
          }),
          source,
        ),
        throwsA(isA<DailyQuestionRejected>()),
      );
    },
  );
  test(
    'AI-derived day save validates entry provenance inside the transaction',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftDiaryRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 4),
      );
      final original = await repo.save(
        id: 'a' * 32,
        date: date,
        text: const DiaryText(body: 'I felt calm planting the garden.'),
        expectedRevision: 0,
      );
      final source = DiarySuggestionSource.fromEntries(date, [original]);
      await repo.save(
        id: original.id,
        date: date,
        text: const DiaryText(body: 'Newer writing'),
        expectedRevision: 1,
      );
      await expectLater(
        repo.saveDay(
          DiaryDay(date: date, heading: 'Garden morning'),
          expectedEntries: source.encode(),
        ),
        throwsA(isA<DiaryException>()),
      );
      expect((await repo.watchDay(date).first).heading, isEmpty);
      await repo.saveDay(DiaryDay(date: date, heading: 'My manual title'));
      expect((await repo.watchDay(date).first).heading, 'My manual title');
    },
  );
}
