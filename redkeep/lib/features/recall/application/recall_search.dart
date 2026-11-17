import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../app/storage_providers.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/application/ai_cloud.dart';
import 'recall_controller.dart';

final _writingRevisionProvider = StreamProvider.autoDispose<int>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  var revision = 0;
  yield revision;
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onAllTables([db.notes]),
  )) {
    yield ++revision;
  }
});

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
