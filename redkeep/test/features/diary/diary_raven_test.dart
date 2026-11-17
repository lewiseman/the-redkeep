import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_raven.dart';

void main() {
  final today = DiaryPeriod(2026, 11, 17);

  test('brings nothing when no echoing day was written', () {
    expect(diaryRavenLetter(today, {DiaryPeriod(2026, 11, 16)}), isNull);
    expect(diaryRavenLetter(today, const {}), isNull);
  });

  test('prefers a year ago, then a month ago, then last week', () {
    final written = {
      DiaryPeriod(2025, 11, 17),
      DiaryPeriod(2026, 10, 17),
      DiaryPeriod(2026, 11, 10),
    };
    expect(
      diaryRavenLetter(today, written),
      DiaryRavenLetter(from: DiaryPeriod(2025, 11, 17), echo: DiaryEcho.year),
    );
    written.remove(DiaryPeriod(2025, 11, 17));
    expect(
      diaryRavenLetter(today, written),
      DiaryRavenLetter(from: DiaryPeriod(2026, 10, 17), echo: DiaryEcho.month),
    );
    written.remove(DiaryPeriod(2026, 10, 17));
    expect(
      diaryRavenLetter(today, written),
      DiaryRavenLetter(from: DiaryPeriod(2026, 11, 10), echo: DiaryEcho.week),
    );
  });

  test('only the same weekday last week counts, not earlier weeks', () {
    expect(diaryRavenLetter(today, {DiaryPeriod(2026, 11, 3)}), isNull);
    expect(diaryRavenLetter(today, {DiaryPeriod(2026, 10, 27)}), isNull);
    expect(diaryRavenLetter(today, {DiaryPeriod(2026, 11, 11)}), isNull);
  });

  test('handles dates missing from the earlier month or year', () {
    final leap = DiaryPeriod(2028, 2, 29);
    expect(diaryRavenLetter(leap, {DiaryPeriod(2027, 2, 28)}), isNull);
    final march31 = DiaryPeriod(2026, 3, 31);
    expect(diaryRavenLetter(march31, {DiaryPeriod(2026, 2, 28)}), isNull);
    expect(
      diaryRavenLetter(DiaryPeriod(2026, 1, 9), {DiaryPeriod(2025, 12, 9)}),
      DiaryRavenLetter(from: DiaryPeriod(2025, 12, 9), echo: DiaryEcho.month),
    );
  });

  test('only ordinary days receive letters', () {
    final week = DiaryPeriod.week(today.start);
    expect(diaryRavenLetter(week, {DiaryPeriod(2026, 11, 10)}), isNull);
  });
}
