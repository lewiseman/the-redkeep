import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diary_period.dart';

/// A fresh search selection also reopens the beginning of the current day.
class DiaryDaySelection {}

/// The day shown by the diary reader at `/diary`. Days are reader state rather
/// than routes, so turning a page never swaps the reader's Navigator page.
class DiaryReaderDay {
  const DiaryReaderDay([this.date, this.selection]);

  /// Null follows today.
  final DiaryPeriod? date;
  final DiaryDaySelection? selection;
}

final diaryReaderDayProvider =
    NotifierProvider<DiaryReaderDayController, DiaryReaderDay>(
      DiaryReaderDayController.new,
    );

class DiaryReaderDayController extends Notifier<DiaryReaderDay> {
  @override
  DiaryReaderDay build() => const DiaryReaderDay();

  void show(DiaryPeriod date, {DiaryDaySelection? selection}) =>
      state = DiaryReaderDay(date, selection);

  void showToday() => state = const DiaryReaderDay();
}
