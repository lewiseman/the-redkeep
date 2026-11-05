import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../app/storage_providers.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../../companion/application/companion_controller.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/domain/diary_document.dart';
import '../../diary/domain/diary_period.dart';
import '../../notes/application/notes_providers.dart';
import '../../notes/domain/note_collection_entry.dart';
import '../../notes/domain/notes_query.dart';
import '../../flow/application/flow_providers.dart';
import '../domain/recall.dart';
import 'recall_controller.dart';

final _writingRevisionProvider = StreamProvider.autoDispose<int>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  var revision = 0;
  yield revision;
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onAllTables([
      db.notes,
      db.noteDrafts,
      db.diaryEntries,
      db.flowThoughts,
    ]),
  )) {
    yield ++revision;
  }
});

List<RecallSource> currentRecallSources(AsyncValue<RecallSearch> result) =>
    result.isLoading ? const [] : result.value?.sources ?? const [];

typedef RecallQuery = ({String query, String kind});
final recallSearchProvider = FutureProvider.autoDispose
    .family<RecallSearch, RecallQuery>((ref, request) async {
      if (!ref.watch(aiEnabledProvider) || request.query.trim().isEmpty) {
        return const RecallSearch([]);
      }
      ref.watch(aiPreferencesProvider);
      ref.watch(_writingRevisionProvider);
      ref.watch(aiForegroundProvider);
      ref.watch(
        companionControllerProvider.select(
          (c) => (c.phase, RecallProfile.fromStatus(c.status)?.id),
        ),
      );
      ref.watch(recallControllerProvider.select((s) => s.revision));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!ref.mounted) return const RecallSearch([]);
      return ref
          .read(recallControllerProvider.notifier)
          .search(
            request.query.trim(),
            request.kind,
            active: () => ref.mounted,
          );
    });
final _eligibleNotesProvider =
    StreamProvider.autoDispose<List<NoteCollectionEntry>>((ref) {
      final filter = ref.watch(notesFilterProvider);
      return ref
          .watch(notesRepositoryProvider)
          .watchCollection(
            query: NotesQuery(tag: filter.tag, pinnedOnly: filter.pinnedOnly),
          );
    }, retry: (_, _) => null);
final notesHybridCollectionProvider =
    Provider.autoDispose<AsyncValue<List<NoteCollectionEntry>>>((ref) {
      final keywords = ref.watch(notesCollectionProvider);
      final filter = ref.watch(notesFilterProvider);
      if (!ref.watch(aiEnabledProvider) ||
          filter.search.trim().isEmpty ||
          filter.trash ||
          ref.watch(notesDraftsOnlyProvider)) {
        return keywords;
      }
      final matches = currentRecallSources(
        ref.watch(recallSearchProvider((query: filter.search, kind: 'note'))),
      );
      final candidates =
          ref.watch(_eligibleNotesProvider).value ??
          const <NoteCollectionEntry>[];
      if (!keywords.hasValue || keywords.hasError) return keywords;
      final byId = {
        for (final note in candidates)
          if (!note.isDraft && !note.sourceUnavailable) note.id: note,
      };
      return AsyncData(
        fuseRecall(keywords.value!, [
          for (final source in matches) ?byId[source.id],
        ], (note) => note.id),
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
final flowSearchSourcesProvider =
    FutureProvider.autoDispose<List<RecallSource>>((ref) async {
      final listings = await ref.watch(thoughtsProvider.future);
      final repository = ref.watch(flowRepositoryProvider);
      final opened = await Future.wait(
        listings.map((thought) => repository.openDocument(thought.id)),
      );
      return [
        for (final value in opened)
          if (value.available)
            RecallSource(
              kind: 'thought',
              id: value.thought!.id,
              title: '',
              text: value.thought!.body,
              date: DiaryPeriod.fromComponents(
                value.thought!.createdAt.toLocal(),
              ).key,
              revision: value.thought!.revision,
            ),
      ];
    }, retry: (_, _) => null);
