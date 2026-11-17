import 'civil_date.dart';
import 'diary_period.dart';

/// How far back a raven's letter comes from.
enum DiaryEcho { year, month, week }

/// An earlier written day that echoes the page being read: the same date a
/// year or a month before, or the same weekday a week before.
class DiaryRavenLetter {
  const DiaryRavenLetter({required this.from, required this.echo});

  final DiaryPeriod from;
  final DiaryEcho echo;

  @override
  bool operator ==(Object other) =>
      other is DiaryRavenLetter && other.from == from && other.echo == echo;

  @override
  int get hashCode => Object.hash(from, echo);
}

/// The letter a raven brings to [date], or none. A year ago comes first, then
/// a month ago, then the same weekday last week. Only days
/// that have writing, as listed in [written], are ever brought back.
DiaryRavenLetter? diaryRavenLetter(DiaryPeriod date, Set<DiaryPeriod> written) {
  if (!date.isDay) return null;
  final day = date.start;
  bool wrote(CivilDate? value) =>
      value != null && written.contains(DiaryPeriod.day(value));

  final yearAgo = _tryDate(day.year - 1, day.month, day.day);
  if (wrote(yearAgo)) {
    return DiaryRavenLetter(
      from: DiaryPeriod.day(yearAgo!),
      echo: DiaryEcho.year,
    );
  }
  final previousMonth = day.month == 1 ? 12 : day.month - 1;
  final monthAgo = _tryDate(
    day.month == 1 ? day.year - 1 : day.year,
    previousMonth,
    day.day,
  );
  if (wrote(monthAgo)) {
    return DiaryRavenLetter(
      from: DiaryPeriod.day(monthAgo!),
      echo: DiaryEcho.month,
    );
  }
  final weekAgo = day.shift(-7);
  if (wrote(weekAgo)) {
    return DiaryRavenLetter(
      from: DiaryPeriod.day(weekAgo!),
      echo: DiaryEcho.week,
    );
  }
  return null;
}

CivilDate? _tryDate(int year, int month, int day) {
  try {
    return CivilDate(year, month, day);
  } on FormatException {
    return null;
  }
}
