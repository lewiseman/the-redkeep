import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../app/storage_providers.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/application/ai_cloud.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/domain/diary_document.dart';
import '../../diary/domain/diary_period.dart';
import '../domain/recall.dart';
import 'recall_controller.dart';

final _writingRevisionProvider = StreamProvider.autoDispose<int>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  var revision = 0;
  yield revision;
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onAllTables([db.notes, db.diaryEntries]),
  )) {
    yield ++revision;
  }
});

List<RecallSource> currentRecallSources(AsyncValue<RecallSearch> result) =>
    result.isLoading ? const [] : result.value?.sources ?? const [];

/// One submitted search. Each call embeds the query, so callers pass only
/// queries the person submitted, never text while it is being typed.
typedef RecallQuery = ({String query, String kind});
final recallSearchProvider = FutureProvider.autoDispose
    .family<RecallSearch, RecallQuery>((ref, request) async {
      if (!ref.watch(aiEnabledProvider) || request.query.trim().isEmpty) {
        return const RecallSearch([]);
      }
      ref.watch(aiPreferencesProvider);
      ref.watch(_writingRevisionProvider);
      ref.watch(aiForegroundProvider);
      ref.watch(aiCloudSettingsProvider);
      ref.watch(recallControllerProvider.select((s) => s.revision));
      // Only submitted searches reach here, so there is no typing delay.
      return ref
          .read(recallControllerProvider.notifier)
          .search(
            request.query.trim(),
            request.kind,
            active: () => ref.mounted,
          );
    });
final diaryHybridSearchProvider = Provider.autoDispose
    .family<AsyncValue<List<DiaryListing>>, String>((ref, query) {
      final keywords = ref.watch(diarySearchProvider(query));
      if (!ref.watch(aiEnabledProvider) || query.trim().isEmpty) {
        return keywords;
      }
      final matches = currentRecallSources(
        ref.watch(recallSearchProvider((query: query, kind: 'diary'))),
      );
      if (!keywords.hasValue || keywords.hasError) return keywords;
      final semantic = [
        for (final source in matches)
          if (DiaryPeriod.tryParse(source.date) case final date?)
            DiaryListing(id: source.id, date: date),
      ];
      return AsyncData(
        fuseRecall(keywords.value!, semantic, (entry) => entry.id),
      );
    });
