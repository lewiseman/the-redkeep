import 'package:intl/intl.dart';

import 'civil_date.dart';

enum DiaryPeriodKind { year, month, week, day }

/// A diary page's calendar scope. Dates remain real Gregorian civil dates;
/// page keys distinguish a day from all of its containing periods.
class DiaryPeriod implements Comparable<DiaryPeriod> {
  const DiaryPeriod._(this.kind, this.start, this.end);

  factory DiaryPeriod(int year, int month, int day) =>
      DiaryPeriod.day(CivilDate(year, month, day));
  factory DiaryPeriod.day(CivilDate date) =>
      DiaryPeriod._(DiaryPeriodKind.day, date, date);
  factory DiaryPeriod.fromComponents(DateTime date) =>
      DiaryPeriod.day(CivilDate.fromComponents(date));
  factory DiaryPeriod.week(CivilDate date) {
    final start = date.shift(1 - date.weekday)!;
    return DiaryPeriod._(
      DiaryPeriodKind.week,
      start,
      start.shift(6) ?? CivilDate(9999, 12, 31),
    );
  }
  factory DiaryPeriod.month(int year, int month) {
    final start = CivilDate(year, month, 1);
    return DiaryPeriod._(
      DiaryPeriodKind.month,
      start,
      CivilDate(year, month, start.daysInMonth),
    );
  }
  factory DiaryPeriod.year(int year) => DiaryPeriod._(
    DiaryPeriodKind.year,
    CivilDate(year, 1, 1),
    CivilDate(year, 12, 31),
  );

  final DiaryPeriodKind kind;
  final CivilDate start, end;
  bool get isDay => kind == DiaryPeriodKind.day;
  int get year => start.year;
  int get month => start.month;
  int get day => start.day;
  int get weekday => start.weekday;
  int get daysInMonth => start.daysInMonth;
  DateTime get calendarDate => DateTime(year, month, day);
  String get key => switch (kind) {
    DiaryPeriodKind.day => start.key,
    DiaryPeriodKind.week => 'week-${start.key}',
    DiaryPeriodKind.month => 'month-${start.key.substring(0, 7)}',
    DiaryPeriodKind.year => 'year-${start.key.substring(0, 4)}',
  };
  bool contains(CivilDate date) =>
      start.compareTo(date) <= 0 && end.compareTo(date) >= 0;
  bool isCurrent(DateTime today) => contains(CivilDate.fromComponents(today));
  bool hasStarted(DateTime today) =>
      start.compareTo(CivilDate.fromComponents(today)) <= 0;
  bool overlaps(CivilDate from, CivilDate to) =>
      start.compareTo(to) <= 0 && end.compareTo(from) >= 0;
  DiaryPeriod? shift(int days) {
    final date = start.shift(days);
    return date == null ? null : DiaryPeriod.day(date);
  }

  String label([String? locale]) => switch (kind) {
    DiaryPeriodKind.day => DateFormat.yMMMd(locale).format(calendarDate),
    DiaryPeriodKind.week =>
      'Week · ${DateFormat.MMMd(locale).format(calendarDate)} – ${DateFormat.yMMMd(locale).format(DateTime(end.year, end.month, end.day))}',
    DiaryPeriodKind.month =>
      'Month · ${DateFormat.yMMMM(locale).format(calendarDate)}',
    DiaryPeriodKind.year => 'Year · $year',
  };
  String shortLabel([String? locale]) => switch (kind) {
    DiaryPeriodKind.day => '$day',
    DiaryPeriodKind.week => 'Week',
    DiaryPeriodKind.month => DateFormat.MMM(locale).format(calendarDate),
    DiaryPeriodKind.year => '$year',
  };

  static DiaryPeriod? tryParse(String key) {
    try {
      if (CivilDate.tryParse(key) case final date?) {
        return DiaryPeriod.day(date);
      }
      DiaryPeriod? result;
      if (key.startsWith('week-')) {
        final date = CivilDate.tryParse(key.substring(5));
        if (date != null) result = DiaryPeriod.week(date);
      } else if (RegExp(r'^month-\d{4}-\d{2}$').hasMatch(key)) {
        result = DiaryPeriod.month(
          int.parse(key.substring(6, 10)),
          int.parse(key.substring(11)),
        );
      } else if (RegExp(r'^year-\d{4}$').hasMatch(key)) {
        result = DiaryPeriod.year(int.parse(key.substring(5)));
      }
      return result?.key == key ? result : null;
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(DiaryPeriod other) {
    final date = start.compareTo(other.start);
    return date == 0 ? kind.index.compareTo(other.kind.index) : date;
  }

  @override
  bool operator ==(Object other) => other is DiaryPeriod && key == other.key;
  @override
  int get hashCode => key.hashCode;
  @override
  String toString() => key;
}
