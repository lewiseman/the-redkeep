import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../recall/application/recall_controller.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../../sync/application/sync_providers.dart';
import '../data/drift_thought_reflections.dart';
import '../domain/thought_reflection.dart';
import '../domain/thought_reflection_contract.dart';
import 'flow_providers.dart';

final thoughtReflectionsRepositoryProvider = Provider(
  (ref) => DriftThoughtReflections(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(aiClockProvider),
  ),
);
final thoughtReflectionsProvider = StreamProvider.autoDispose
    .family<ThoughtReflections, String>((ref, id) {
      final opened = ref.watch(thoughtDocumentProvider(id));
      final thought = opened.value?.thought;
      if (thought == null || !opened.value!.available) {
        return Stream.value(const ThoughtReflections());
      }
      return ref.watch(thoughtReflectionsRepositoryProvider).watch(thought);
    });
final reflectionMessagesProvider =
    NotifierProvider<ReflectionMessages, Map<String, String>>(
      ReflectionMessages.new,
    );

class ReflectionMessages extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    ref.watch(writingSessionEpochProvider);
    return const {};
  }

  void set(String id, String? message) => state = {
    for (final entry in state.entries)
      if (entry.key != id) entry.key: entry.value,
    id: ?message,
  };
}

final flowAiProvider = Provider((ref) => FlowAi(ref));

class FlowAi {
  FlowAi(this.ref);
  final Ref ref;

  Future<void> reflect(String id) async {
    ref.read(reflectionMessagesProvider.notifier).set(id, null);
    final thought = (await ref.read(flowRepositoryProvider).openDocument(id))
        .thought;
    if (thought == null || thought.deletedAt != null) {
      throw const FormatException('This thought is unavailable.');
    }
    final source = ThoughtReflectionSource.fromThought(thought);
    await ref
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.thoughtReflection,
          id,
          thought.body,
          source.encode(),
        );
  }

  Future<RecallQuestionSelection> select(String question) async {
    final repo = ref.read(flowRepositoryProvider);
    final generation = ref.read(appDatabaseProvider).writingGeneration;
    final items = await Future.wait(
      (await repo.watchThoughts().first).map((t) => repo.openDocument(t.id)),
    );
    final today = ref.read(aiClockProvider)();
    final thoughts = RecallItem.thoughts([
      for (final item in items)
        if (item.available) item.thought!,
    ]);
    // Validate before spending time on semantic retrieval.
    var selection = RecallQuestionSelection.select(
      kind: RecallKind.thought,
      question: question,
      today: today,
      items: thoughts,
    );
    final semantic = await ref
        .read(recallControllerProvider.notifier)
        .search(question, 'thought', active: () => ref.mounted);
    if (!ref.mounted ||
        ref.read(appDatabaseProvider).writingGeneration != generation ||
        ref.read(appDatabaseProvider).writingBlocked) {
      throw StateError('The writing session ended.');
    }
    if (semantic.semantic && semantic.sources.isNotEmpty) {
      selection = RecallQuestionSelection.select(
        kind: RecallKind.thought,
        question: question,
        today: today,
        items: thoughts,
        ranked: {
          ...semantic.sources.map((s) => s.id),
          ...selection.sources.map((s) => s.uuid),
        }.toList(),
      );
    }
    return selection;
  }

  Future<void> ask(RecallQuestionSelection selection) async {
    if (selection.kind != RecallKind.thought || !selection.sendable) {
      throw const FormatException(
        'No thoughts match this question. Nothing was sent.',
      );
    }
    await ref
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.thoughtQuestion,
          'thought-search',
          selection.request(),
          selection.encode(),
        );
  }
}

/// Mounted by the app lifecycle, so results are saved even after leaving Flow.
final thoughtReflectionConsumerProvider = Provider((ref) {
  ref.watch(writingSessionEpochProvider);
  final store = ref.watch(thoughtReflectionsRepositoryProvider);
  String? consuming;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  Future<void> consume() async {
    final snapshot = ref.read(aiJobsProvider);
    final job = snapshot.job;
    if (disposed ||
        job == null ||
        job.operation != AiOperation.thoughtReflection ||
        job.phase != 'completed' ||
        job.text == null ||
        consuming != null) {
      return;
    }
    consuming = job.id;
    try {
      await store.propose(
        job.id,
        ThoughtReflectionSource.decode(job.source),
        job.text!,
      );
      if (!disposed && ref.read(aiJobsProvider).job?.id == job.id) {
        ref.read(reflectionMessagesProvider.notifier).set(job.key, null);
        await ref.read(aiJobsProvider.notifier).clearIfCurrent(job.id);
      }
    } catch (error) {
      if (!disposed) {
        ref
            .read(reflectionMessagesProvider.notifier)
            .set(
              job.key,
              error is ThoughtReflectionRejected ? error.message : 'This reflection could not be saved. Retry saving it, or clear the task.',
            );
      }
      // Keep the protected result for explicit recovery; never clear a failed write.
    } finally {
      consuming = null;
    }
  }

  ref.listen(
    aiJobsProvider,
    (_, next) => scheduleMicrotask(() {
      if (!disposed) unawaited(consume());
    }),
    fireImmediately: true,
  );
  unawaited(store.prune().catchError((_) {}));
  return consume;
});
