import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/features/diary/application/diary_reader_day.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

/// Diary days are reader state at `/diary`, not addresses.
void goDiaryDay(WidgetTester tester, GoRouter router, DiaryPeriod date) {
  tester.container().read(diaryReaderDayProvider.notifier).show(date);
  router.go('/diary');
}

void expectDiaryDay(WidgetTester tester, GoRouter router, DiaryPeriod date) {
  expect(router.routeInformationProvider.value.uri.path, '/diary');
  final today = DateTime(2026, 11, 2);
  expect(
    tester.container().read(diaryReaderDayProvider).date ??
        DiaryPeriod.fromComponents(today),
    date,
  );
}
