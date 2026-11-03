import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

export 'package:flutter/material.dart';

export 'diary_paper_colors.dart';

extension DiaryContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => colors.brightness == Brightness.dark;
}

abstract final class TimeFormat {
  static const month = 'MMMM';
  static const shortWeekday = 'EEE';
  static const shortWeekdayDate = 'EEE, d MMM y';
  static const localizedDate = 'yMMMd';
  static const localizedMonthDay = 'MMMd';
}

/// Civil date arithmetic deliberately avoids elapsed-time/DST calculations.
abstract final class TimeHelper {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String format(
    DateTime date, {
    required String pattern,
    String? locale,
    bool toLocal = false,
  }) => DateFormat(pattern, locale).format(toLocal ? date.toLocal() : date);
}
