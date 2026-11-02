import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';

void main() {
  test(
    'canonical Gregorian keys reject rollover, zeroes and instant strings',
    () {
      for (final key in [
        '2026-02-29',
        '1900-02-29',
        '2026-04-31',
        '0000-01-01',
        '2026-00-01',
        '2026-01-00',
        '2026-13-01',
        '26-01-01',
        '2026-1-01',
        '2026-11-02Z',
        '2026-11-02T00:00:00-12:00',
      ]) {
        expect(CivilDate.tryParse(key), isNull, reason: key);
      }
      expect(CivilDate(2000, 2, 29).key, '2000-02-29');
      expect(CivilDate(2024, 2, 28).shift(1), CivilDate(2024, 2, 29));
      expect(CivilDate(2024, 2, 29).shift(1), CivilDate(2024, 3, 1));
      expect(CivilDate(2026, 12, 31).shift(1), CivilDate(2027, 1, 1));
      expect(CivilDate(1, 1, 1).shift(-1), isNull);
      expect(CivilDate(9999, 12, 31).shift(1), isNull);
    },
  );
  test('civil navigation crosses DST and skipped civil days without shifting keys', () {
    for (final key in [
      '2026-03-08',
      '2026-11-01',
      '2026-03-29',
      '2026-10-25',
      '2011-12-30',
    ]) {
      final date = CivilDate.tryParse(key)!;
      expect(date.shift(1)!.shift(-1), date);
      expect(CivilDate.tryParse(date.key), date);
    }
    // Run this test with TZ=America/New_York, Pacific/Apia, Pacific/Kiritimati
    // and Etc/GMT+12 as documented; DateTime below supplies local components.
    final local = DateTime(2026, 11, 1, 0, 30);
    expect(
      CivilDate.fromComponents(local).key,
      '2026-11-01',
      reason: Platform.environment['TZ'],
    );
    expect(
      CivilDate.fromComponents(DateTime.utc(2026, 11, 1, 23, 30)).key,
      '2026-11-01',
    );
  });
}
