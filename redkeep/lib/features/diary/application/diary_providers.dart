import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/drift_diary_repository.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import '../domain/diary_repository.dart';

final diaryClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final diaryIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
});
final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DriftDiaryRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(diaryClockProvider),
  ),
);
final diaryCalendarMoodsProvider =
    StreamProvider.autoDispose<Map<DiaryPeriod, DiaryMood>>(
      (ref) => ref.watch(diaryRepositoryProvider).watchMoods(),
      retry: (_, _) => null,
    );
final diaryCalendarHeadingsProvider =
    StreamProvider.autoDispose<Map<DiaryPeriod, String>>(
      (ref) => ref.watch(diaryRepositoryProvider).watchHeadings(),
      retry: (_, _) => null,
    );
final diaryEntriesProvider = StreamProvider.autoDispose
    .family<List<DiaryListing>, DiaryPeriod>(
      (ref, date) =>
          ref.watch(diaryRepositoryProvider).watchEntries(date: date),
      retry: (_, _) => null,
    );
final diarySearchProvider = StreamProvider.autoDispose
    .family<List<DiaryListing>, String>(
      (ref, search) =>
          ref.watch(diaryRepositoryProvider).watchEntries(search: search),
      retry: (_, _) => null,
    );

final diaryDayProvider = StreamProvider.autoDispose
    .family<DiaryDay, DiaryPeriod>(
      (ref, date) => ref.watch(diaryRepositoryProvider).watchDay(date),
      retry: (_, _) => null,
    );
final diaryDocumentProvider = StreamProvider.autoDispose
    .family<OpenDiaryEntry, String>(
      (ref, id) => ref.watch(diaryRepositoryProvider).watchDocument(id),
      retry: (_, _) => null,
    );

final diaryActionsProvider = NotifierProvider.autoDispose<DiaryActions, bool>(
  DiaryActions.new,
);

class DiaryActions extends Notifier<bool> {
  @override
  bool build() => false;
  Future<T> run<T>(Future<T> Function(DiaryRepository) action) async {
    if (state) throw StateError('An action is already pending');
    state = true;
    final keep = ref.keepAlive();
    try {
      return await action(ref.read(diaryRepositoryProvider));
    } finally {
      if (ref.mounted) state = false;
      keep.close();
    }
  }

  Future<String> create(DiaryPeriod date) => run((repository) async {
    final id = ref.read(diaryIdProvider)();
    ref.read(diaryNewIdsProvider.notifier).add(id);
    return id;
  });
}

/// Allocated new editors have no database row until there is writing to save.
final diaryNewIdsProvider = NotifierProvider<NewDiaryIds, Set<String>>(
  NewDiaryIds.new,
);

class NewDiaryIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void add(String id) => state = {...state, id};
  void remove(String id) => state = {...state}..remove(id);
}
