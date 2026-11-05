import '../../flow/application/flow_ai.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../companion/application/companion_controller.dart';
import '../../diary/domain/civil_date.dart';
import '../../diary/domain/daily_question_contract.dart';
import '../../diary/domain/diary_ai_contract.dart';
import '../../diary/domain/diary_history_contract.dart';
import '../../diary/domain/diary_photo_question_contract.dart';
import '../../diary/presentation/diary_answer_page.dart';
import '../../flow/application/flow_providers.dart';
import '../../flow/domain/thought_reflection_contract.dart';
import '../../flow/presentation/flow_question_task.dart';
import '../../notes/presentation/note_ai_sheet.dart';
import '../application/ai_jobs.dart';
import '../domain/ai_job.dart';
import '../domain/ai_operation.dart';

final aiHistoryProvider = StreamProvider.autoDispose<List<AiJob>>(
  (ref) => ref.watch(aiJobStoreProvider).watchHistory(),
  retry: (_, _) => null,
);

String aiPhaseLabel(String phase) => switch (phase) {
  'submitting' => 'Acceptance unknown',
  'queued' || 'accepted' => 'Waiting',
  'running' => 'Running',
  'completed' => 'Completed',
  'failed' => 'Failed',
  'cancelled' => 'Cancelled',
  'interrupted' => 'Interrupted',
  'expired' => 'Expired',
  _ => 'Reconnect to check',
};

String _provider(WidgetRef ref, AiJob job) {
  if (job.provider == 'device') return 'This phone';
  final computers = ref.watch(companionControllerProvider).computers;
  return computers.where((c) => c.id == job.computerId).firstOrNull?.name ??
      'Original computer unavailable';
}

class AiHistoryPage extends ConsumerStatefulWidget {
  const AiHistoryPage({super.key});
  @override
  ConsumerState<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends ConsumerState<AiHistoryPage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) unawaited(ref.read(aiJobsProvider.notifier).restore());
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(aiHistoryProvider);
    final current = ref.watch(aiJobsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI task history'),
        actions: [
          IconButton(
            tooltip: 'Refresh task status',
            onPressed: () async {
              await ref.read(aiJobsProvider.notifier).restore();
              if (mounted) ref.invalidate(aiHistoryProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Task receipts stay here for seven days. Preview content is retained only for the current task, for up to 24 hours. Clearing a task removes its preview.',
                ),
                if (current.message case final message?) Text(message),
                ...history.when(
                  loading: () => [const LinearProgressIndicator()],
                  error: (_, _) => [
                    TextButton(
                      onPressed: () => ref.invalidate(aiHistoryProvider),
                      child: const Text('Could not load history. Retry'),
                    ),
                  ],
                  data: (jobs) => [
                    if (jobs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No AI tasks yet.'),
                      ),
                    for (final receipt in jobs)
                      Builder(
                        builder: (context) {
                          final job = current.job?.id == receipt.id
                              ? current.job!
                              : receipt;
                          final expired =
                              ref
                                  .read(aiClockProvider)()
                                  .millisecondsSinceEpoch >=
                              job.expires;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            title: Text(
                              '${job.operation.label} · ${aiPhaseLabel(expired && !job.terminal ? 'expired' : job.phase)}',
                            ),
                            subtitle: Text(
                              '${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(job.created))} · ${_provider(ref, job)}${job.ackPending ? '\nResult acknowledgement pending' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(
                              '/settings/brain/history/${job.id}',
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiHistoryTaskPage extends ConsumerStatefulWidget {
  const AiHistoryTaskPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AiHistoryTaskPage> createState() => _AiHistoryTaskPageState();
}

class _AiHistoryTaskPageState extends ConsumerState<AiHistoryTaskPage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) unawaited(ref.read(aiJobsProvider.notifier).restore());
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(aiJobsProvider);
    final receipts = ref.watch(aiHistoryProvider);
    final retained = task.job?.id == widget.id ? task.job : null;
    final receipt = receipts.value?.where((r) => r.id == widget.id).firstOrNull;
    final job = retained ?? receipt;
    final expired =
        job != null &&
        ref.read(aiClockProvider)().millisecondsSinceEpoch >= job.expires;
    // Delegate to the existing reviewed tools. Neither page generates on open.
    if (retained != null && !expired && retained.operation.isNote) {
      return NoteAiToolPage(tool: noteToolForJob(retained), id: retained.key);
    }
    if (retained?.operation == AiOperation.history && !expired) {
      try {
        return DiaryAnswerPage(
          question: DiaryHistorySelection.decode(retained!.source).question,
        );
      } catch (_) {
        /* Show a recoverable receipt rather than throwing on navigation. */
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(job?.operation.label ?? 'AI task')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (job == null)
                  Text(
                    receipts.isLoading
                        ? 'Loading task…'
                        : 'This task receipt is no longer available.',
                  )
                else ...[
                  Text(
                    aiPhaseLabel(
                      expired && !job.terminal ? 'expired' : job.phase,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(job.created))} · ${_provider(ref, job)}',
                  ),
                  if (job.ackPending) ...[
                    const Text(
                      'Result acknowledgement pending. Reconnect the original computer to finish removing its result.',
                    ),
                    TextButton(
                      onPressed: ref
                          .read(aiJobsProvider.notifier)
                          .retryAcknowledgements,
                      child: const Text('Retry acknowledgement'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (retained != null && !expired) ...[
                    if (task.message case final message?) Text(message),
                    if (retained.operation == AiOperation.thoughtQuestion)
                      FlowQuestionTask(job: retained)
                    else if (retained.text != null)
                      _TaskPreview(job: retained),
                    if (retained.operation == AiOperation.thoughtReflection &&
                        retained.phase == 'completed') ...[
                      if (ref.watch(reflectionMessagesProvider)[retained.key]
                          case final message?)
                        Text(message),
                      TextButton(
                        onPressed: ref.read(thoughtReflectionConsumerProvider),
                        child: const Text('Retry saving reflection'),
                      ),
                    ],
                    AiTaskControls(id: widget.id),
                  ] else ...[
                    Text(
                      expired ? 'This task’s preview has expired.' : 'This task was cleared. Its preview is no longer retained.',
                    ),
                    if (retained != null) AiTaskControls(id: widget.id),
                  ],
                  if (_sourceLocation(job) case final location?)
                    TextButton(
                      onPressed: () => context.push(location),
                      child: Text(
                        job.operation.isNote
                            ? 'Review note task'
                            : 'Open source',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _sourceLocation(AiJob job) {
  if (job.operation.isNote) return job.source.isEmpty ? null : '/notes/ai-task';
  if (job.operation == AiOperation.thoughtQuestion) {
    return job.source.isEmpty ? null : '/flow/search';
  }
  if (job.operation == AiOperation.thoughtReflection) {
    return thoughtLocation(job.key);
  }
  if (job.operation == AiOperation.diaryDetails ||
      job.operation == AiOperation.dailyQuestion) {
    final date = CivilDate.tryParse(job.key);
    return date == null
        ? null
        : job.operation == AiOperation.diaryDetails
        ? diaryTitleLocation(date)
        : diaryDayLocation(date);
  }
  try {
    final source = jsonDecode(job.source) as Map;
    final date = CivilDate.tryParse(source['date'] as String? ?? '');
    if (date == null) return null;
    final id = source['id'];
    return id is String
        ? '${diaryEntryLocation(date, id)}/conversation'
        : diaryDayLocation(date);
  } catch (_) {
    return null;
  }
}

class _TaskPreview extends ConsumerWidget {
  const _TaskPreview({required this.job});
  final AiJob job;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final text = job.text!;
      switch (job.operation) {
        case AiOperation.thoughtReflection:
          final source = ThoughtReflectionSource.decode(job.source);
          final thought = ref.watch(thoughtDocumentProvider(source.id));
          return thought.isLoading
              ? const Text('Checking this thought…')
              : source.matches(thought.value?.thought)
              ? SelectableText(parseThoughtReflection(text, source.body))
              : const Text(
                  'This thought changed. The reflection is out of date.',
                );
        case AiOperation.dailyQuestion:
          return SelectableText(
            DailyQuestion.parse(
              text,
              DailyQuestionSource.decode(job.source),
            ).text,
          );
        case AiOperation.diaryDetails:
          final output = DiarySuggestions.parse(
            text,
            DiarySuggestionSource.decode(job.source),
          );
          return SelectableText(
            [
              if (output.title != null) 'Title: ${output.title}',
              if (output.mood.mood != null) 'Mood: ${output.mood.mood!.label}',
              if (output.themes.isNotEmpty)
                'Themes: ${output.themes.map((t) => t.label).join(', ')}',
            ].join('\n'),
          );
        case AiOperation.photoQuestions:
          final output = DiaryPhotoQuestions.parse(text);
          return SelectableText(
            [
              output.observations,
              for (final group in output.groups) ...group,
            ].join('\n\n'),
          );
        default:
          return SelectableText(text);
      }
    } catch (_) {
      return const Text(
        'This retained preview could not be verified. Clear this task to ask again.',
      );
    }
  }
}

class AiTaskControls extends ConsumerWidget {
  const AiTaskControls({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiJobsProvider);
    final job = state.job;
    if (job == null || job.id != id) return const SizedBox.shrink();
    final jobs = ref.read(aiJobsProvider.notifier);
    Future<void> run(Future<void> Function() action) async {
      if (ref.read(aiJobsProvider).job?.id != id) return;
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update this task. Try again.'),
            ),
          );
        }
      }
    }

    return Wrap(
      spacing: 8,
      children: [
        if (!state.busy &&
            job.phase != 'completed' &&
            (!job.terminal || job.prompt.isNotEmpty))
          TextButton(
            onPressed: () => run(jobs.retry),
            child: Text(job.terminal ? 'Retry task' : 'Retrieve task'),
          ),
        if (!job.terminal)
          TextButton(
            onPressed: () => run(jobs.cancel),
            child: const Text('Cancel task'),
          ),
        if (job.terminal)
          TextButton(
            onPressed: () => run(() => jobs.clearIfCurrent(id)),
            child: const Text('Clear task'),
          ),
      ],
    );
  }
}
