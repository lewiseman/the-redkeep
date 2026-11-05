import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/application/diary_ai_sources.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_history_contract.dart';
import 'package:redkeep/features/diary/domain/diary_history_day.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/domain/diary_photo_question_contract.dart';
import 'package:redkeep/features/diary/domain/daily_question_contract.dart';
import 'package:redkeep/features/recall/data/recall_sources.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';

void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  final today = DateTime(2026, 11, 5);
  final periods = [
    DiaryPeriod.week(DiaryPeriod.fromComponents(today).start),
    DiaryPeriod.month(2026, 11),
    DiaryPeriod.year(2026),
  ];
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => today);
  });
  tearDown(() => db.close());

  test(
    'page details alone count; cleared details and tombstones do not',
    () async {
      for (final (i, period) in periods.indexed) {
        expect(await repo.watchSavedPeriods().first, isNot(contains(period)));
        await repo.saveDay(
          DiaryDay(
            date: period,
            heading: i == 0 ? 'A quiet week' : '',
            mood: i == 1 ? DiaryMood.calm : null,
            themes: i == 2 ? ['Garden'] : [],
          ),
        );
        expect(await repo.watchSavedPeriods().first, contains(period));
        await repo.saveDay(DiaryDay(date: period, revision: 1));
        expect(await repo.watchSavedPeriods().first, isNot(contains(period)));
        final id = '${i + 1}'.padLeft(32, '0');
        await repo.save(
          id: id,
          date: period,
          text: const DiaryText(body: 'Saved words'),
          expectedRevision: 0,
        );
        expect(await repo.watchSavedPeriods().first, contains(period));
        await repo.deleteEntry(id, 1);
        expect(await repo.watchSavedPeriods().first, isNot(contains(period)));
      }
    },
  );

  test('text, photos, conversations and page details sync with distinct period ownership', () async {
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final imported = DriftDiaryRepository(other, clock: () => today);
    for (final (i, period) in periods.indexed) {
      final id = '${i + 1}'.padLeft(32, '0');
      await repo.saveDay(
        DiaryDay(date: period, heading: 'My ${period.kind.name}'),
      );
      await repo.save(
        id: id,
        date: period,
        text: DiaryText(body: 'Exact ${period.kind.name} 🌿'),
        expectedRevision: 0,
      );
      await repo.savePhotoStory(
        id: '${i + 4}'.padLeft(32, '0'),
        date: period,
        photos: [
          DiaryPhoto(
            id: 'photo_test',
            path: 'diary_photos/test.png',
            sha256: 'a' * 64,
            caption: 'Garden',
          ),
        ],
        expectedRevision: 0,
      );
      await repo.saveConversation(
        id: '${i + 7}'.padLeft(32, '0'),
        date: period,
        conversation: DiaryAiConversation(
          turns: const [
            {'speaker': 'user', 'text': 'A quiet time.'},
          ],
          createdAt: today,
        ),
        expectedRevision: 0,
      );
      final document = (await DriftSyncCollection(
        db,
        'diary',
      ).read(period.key))!;
      expect(document.payload['schema'], 3);
      await DriftSyncCollection(
        other,
        'diary',
      ).mergeRemote(document, now: today);
      expect((await imported.watchEntries(date: period).first).length, 3);
      expect((await imported.openDocument(id)).entry!.date, period);
      expect(
        (await imported.watchDay(period).first).heading,
        'My ${period.kind.name}',
      );
      expect(await imported.watchSavedPeriods().first, contains(period));
    }
    expect(
      await imported.watchEntries(date: DiaryPeriod(2026, 11, 2)).first,
      isEmpty,
    );
    expect(
      (await repo.watchEntries(search: 'Exact').first)
          .map((e) => e.date)
          .toSet(),
      periods.toSet(),
    );
    final sources = await RecallSources(db).all('diary');
    expect(
      sources.map((s) => s.date).toSet(),
      periods.map((p) => p.key).toSet(),
    );
  });

  test('AI questions and details use only the selected page, not its daily entries', () async {
    await repo.save(
      id: 'd' * 32,
      date: DiaryPeriod.fromComponents(today),
      text: const DiaryText(body: 'Daily words must stay separate'),
      expectedRevision: 0,
    );
    final ai = DiaryAiSources(repo);
    for (final (i, period) in periods.indexed) {
      await repo.save(
        id: '${i + 1}'.padLeft(32, '0'),
        date: period,
        text: DiaryText(body: 'My ${period.kind.name} garden'),
        expectedRevision: 0,
      );
      final source = await ai.day(period);
      expect(source.texts, ['My ${period.kind.name} garden']);
      expect(jsonDecode(source.request())['period'], period.kind.name);
      expect(await ai.current(source), isTrue);
      final question = await ai.question(period, []);
      expect(question.today.single.date, period.key);
      expect(question.prior, isEmpty);
      expect(jsonDecode(question.request())['period'], period.kind.name);
      expect(await ai.questionCurrent(question), isTrue);
      expect(DailyQuestionSource.decode(question.encode()).date, period.key);
      final photoSource = DiaryPhotoQuestionSource(
        date: period.key,
        photoSha: 'a' * 64,
        imageSha: 'b' * 64,
      );
      expect(
        DiaryPhotoQuestionSource.decode(photoSource.encode()).date,
        period.key,
      );
    }
  });

  test(
    'historical date scopes overlap periods and disclose their full range',
    () async {
      final period = DiaryPeriod.year(2026);
      final entry = await repo.save(
        id: 'a' * 32,
        date: period,
        text: const DiaryText(body: 'I planted the garden.'),
        expectedRevision: 0,
      );
      final selection = DiaryHistorySelection.select(
        question: 'garden in October',
        today: today,
        days: [
          DiaryHistoryDay(period.key, [entry]),
        ],
      );
      expect(selection.sources.single.date, period.key);
      final sent = (jsonDecode(selection.request())['sources'] as List).single;
      expect(sent['period'], 'year');
      expect(sent['from'], '2026-01-01');
      expect(sent['to'], '2026-12-31');
      expect(
        DiaryHistorySelection.decode(selection.encode()).sources.single.period,
        period,
      );
    },
  );

  test('secondary devices may append current periods but cannot edit or create past periods', () async {
    final values = DriftSyncKeyValueStore(db);
    await values.write('deviceId', 'secondary');
    await values.write('role', jsonEncode({'device_id': 'primary'}));
    for (final (i, period) in periods.indexed) {
      final id = '${i + 1}'.padLeft(32, '0');
      await repo.save(
        id: id,
        date: period,
        text: const DiaryText(body: 'New writing'),
        expectedRevision: 0,
      );
      await expectLater(
        repo.save(
          id: id,
          date: period,
          text: const DiaryText(body: 'Edit'),
          expectedRevision: 1,
        ),
        throwsStateError,
      );
    }
    await expectLater(
      repo.save(
        id: 'f' * 32,
        date: DiaryPeriod.month(2026, 10),
        text: const DiaryText(body: 'Past'),
        expectedRevision: 0,
      ),
      throwsStateError,
    );
  });
}
