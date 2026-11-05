import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_timeline.dart';

void main() {
  test(
    'canonical keys separate scopes and reject invalid or aliased periods',
    () {
      final periods = [
        DiaryPeriod(2026, 11, 2),
        DiaryPeriod.week(CivilDate(2026, 11, 5)),
        DiaryPeriod.month(2026, 11),
        DiaryPeriod.year(2026),
      ];
      expect(periods.map((p) => p.key), [
        '2026-11-02',
        'week-2026-11-02',
        'month-2026-11',
        'year-2026',
      ]);
      for (final period in periods) {
        expect(DiaryPeriod.tryParse(period.key), period);
        expect(
          validatedNavigationLocation(diaryDayLocation(period)),
          diaryDayLocation(period),
        );
        expect(
          validatedNavigationLocation(
            diaryEntryLocation(period, 'a' * 32, edit: true),
          ),
          diaryEntryLocation(period, 'a' * 32, edit: true),
        );
      }
      for (final invalid in [
        'week-2026-11-03',
        'month-2026-13',
        'month-2026-1',
        'year-0000',
        'year-10000',
        '2026-02-29',
        'week-0000-12-31',
        'year-2026-01-01',
      ]) {
        expect(DiaryPeriod.tryParse(invalid), isNull, reason: invalid);
        expect(
          validatedNavigationLocation('/diary/$invalid'),
          AppDestination.unavailable.location,
        );
      }
    },
  );

  test(
    'weeks cross months and years; leap years and civil limits remain valid',
    () {
      final week = DiaryPeriod.week(CivilDate(2027, 1, 1));
      expect(week, DiaryPeriod.week(CivilDate(2026, 12, 28)));
      expect(week.start.key, '2026-12-28');
      expect(week.end.key, '2027-01-03');
      expect(DiaryPeriod.month(2024, 2).end.key, '2024-02-29');
      expect(DiaryPeriod.month(2026, 2).end.key, '2026-02-28');
      expect(DiaryPeriod.week(CivilDate(1, 1, 1)).start, CivilDate(1, 1, 1));
      expect(
        DiaryPeriod.week(CivilDate(9999, 12, 31)).end,
        CivilDate(9999, 12, 31),
      );
      expect(week.isCurrent(DateTime(2027, 1, 1)), isTrue);
      expect(week.isCurrent(DateTime(2027, 1, 4)), isFalse);
    },
  );

  test('implicit daily sequence interleaves year, month, week before their start day', () {
    final day = DiaryPeriod(2024, 1, 1);
    final year = DiaryPeriod.year(2024),
        month = DiaryPeriod.month(2024, 1),
        week = DiaryPeriod.week(day.start);
    final timeline = DiaryTimeline(
      today: DateTime(2024, 1, 2),
      saved: [week, month, year],
    );
    expect(
      [
        for (var offset = -4; offset <= 1; offset++)
          timeline.offset(day, offset),
      ],
      [
        DiaryPeriod(2023, 12, 31),
        year,
        month,
        week,
        day,
        DiaryPeriod(2024, 1, 2),
      ],
    );
    for (final period in [year, month, week, day]) {
      final previous = timeline.neighbor(period, -1)!;
      expect(timeline.neighbor(previous, 1), period);
    }
    expect(timeline.neighbor(DiaryPeriod(2024, 1, 2), 1), isNull);
  });

  test(
    'unsaved special selection is temporary; future periods are excluded',
    () {
      final today = DateTime(2026, 11, 5);
      final selected = DiaryPeriod.month(2026, 11);
      final timeline = DiaryTimeline(
        today: today,
        saved: [DiaryPeriod.month(2026, 12)],
      );
      expect(timeline.neighbor(selected, 1), DiaryPeriod(2026, 11, 1));
      expect(timeline.neighbor(selected, -1), DiaryPeriod(2026, 10, 31));
      expect(
        timeline.neighbor(DiaryPeriod(2026, 11, 1), -1),
        DiaryPeriod(2026, 10, 31),
      );
      expect(timeline.specials, isEmpty);
      expect(
        DiaryTimeline(today: today).neighbor(DiaryPeriod(1, 1, 1), -1),
        isNull,
      );
    },
  );
}
