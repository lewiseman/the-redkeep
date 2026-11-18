import '../../appearance/domain/appearance_preferences.dart';
import '../../diary/domain/civil_date.dart';
import '../../diary/domain/diary_day_details.dart';
import '../../diary/domain/diary_period.dart';

/// How many days back the home screen widgets can see. Enough for a long
/// streak and a "year ago today" letter; the widgets work out the rest (the
/// month, the streak, today) from the real date, so they stay correct after
/// midnight without the app running.
const homeWidgetHistoryDays = 800;

/// What the Android home screen widgets show, as plain JSON for the platform.
///
/// Only written day dates and their mood emoji leave the app: no titles or
/// writing, because the widgets sit on the home screen.
Map<String, Object?> homeWidgetSnapshot({
  required Set<DiaryPeriod> written,
  required Map<DiaryPeriod, DiaryMood> moods,
  required AppearancePreferences appearance,
  required DateTime today,
}) {
  final last = CivilDate.fromComponents(today);
  final first = last.shift(-homeWidgetHistoryDays) ?? last;
  bool inWindow(DiaryPeriod period) =>
      period.isDay &&
      period.start.compareTo(first) >= 0 &&
      period.start.compareTo(last) <= 0;

  final days = <String, String>{
    for (final period in written)
      if (inWindow(period)) period.start.key: '',
    for (final MapEntry(key: period, value: mood) in moods.entries)
      if (inWindow(period)) period.start.key: mood.emoji,
  };
  final keys = days.keys.toList()..sort();
  return {
    'v': 1,
    'theme': appearance.theme.name,
    'accent': _hex(appearance.accent.seed.toARGB32()),
    'accentDark': _hex(appearance.accent.darkPrimary.toARGB32()),
    'days': {for (final key in keys) key: days[key]},
  };
}

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
