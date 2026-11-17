
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

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

}
