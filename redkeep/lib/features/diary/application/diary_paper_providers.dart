import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diary_period.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_document.dart';
import 'diary_providers.dart';

/// A presentation snapshot shared by live paper and non-interactive sheets.
class DiaryPaperDay {
  const DiaryPaperDay({
    required this.date,
    this.heading = '',
    this.mood,
    this.themes = const [],
    this.entries = const [],
    this.loading = false,
    this.failed = false,
  });
  final DiaryPeriod date;
  final String heading;
  final DiaryMood? mood;
  final List<String> themes;
  final List<DiaryEntry> entries;
  final bool loading, failed;
  DateTime get calendarDate => DateTime(date.year, date.month, date.day);
  String get dateString => date.key;
}

final diaryPaperDayProvider = Provider.autoDispose
    .family<DiaryPaperDay, DiaryPeriod>((ref, date) {
      final day = ref.watch(diaryDayProvider(date));
      final listings = ref.watch(diaryEntriesProvider(date));
      final documents = [
        for (final listing in listings.value ?? <DiaryListing>[])
          ref.watch(diaryDocumentProvider(listing.id)),
      ];
      return DiaryPaperDay(
        date: date,
        heading: day.value?.heading ?? '',
        mood: day.value?.mood,
        themes: day.value?.themes ?? const [],
        entries: [
          for (final document in documents)
            if (document.value case final opened?)
              if (opened.available && opened.entry!.date == date) opened.entry!,
        ],
        loading:
            day.isLoading ||
            listings.isLoading ||
            documents.any((d) => d.isLoading),
        failed:
            day.hasError ||
            listings.hasError ||
            documents.any((d) => d.hasError),
      );
    });

final diaryCalendarDatesProvider = StreamProvider.autoDispose<Set<DiaryPeriod>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchSavedPeriods(),
  retry: (_, _) => null,
);
