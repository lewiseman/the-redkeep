import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../recall/application/recall_controller.dart';
import '../../recall/domain/recall.dart';
import '../application/diary_providers.dart';
import '../domain/civil_date.dart';
import '../domain/diary_history_contract.dart';
import '../domain/diary_history_day.dart';

class DiaryAnswerPage extends ConsumerStatefulWidget {
  const DiaryAnswerPage({super.key, required this.question});
  final String question;
  @override
  ConsumerState<DiaryAnswerPage> createState() => _DiaryAnswerPageState();
}

class _DiaryAnswerPageState extends ConsumerState<DiaryAnswerPage> {
  DiaryHistorySelection? _selection;
  String? _message;
  bool _loading = true, _sending = false;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_load);
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(diaryRepositoryProvider);
      final listings = await repository.watchEntries().first;
      final opened = await Future.wait(
        listings.map((l) => repository.openDocument(l.id)),
      );
      final grouped = <String, List<DiaryEntry>>{};
      for (final item in opened) {
        if (item.available) {
          grouped.putIfAbsent(item.entry!.date.key, () => []).add(item.entry!);
        }
      }
      final days = [
        for (final e in grouped.entries)
          DiaryHistoryDay(
            e.key,
            e.value,
            dayTitle:
                (await repository.watchDay(CivilDate.tryParse(e.key)!).first)
                    .heading,
          ),
      ];
      final today = ref.read(diaryClockProvider)();
      var selection = DiaryHistorySelection.select(
        question: widget.question,
        today: today,
        days: days,
      );
      if (mounted) setState(() => _selection = selection);
      final meaning = await ref
          .read(recallControllerProvider.notifier)
          .search(widget.question, 'diary', active: () => mounted);
      if (meaning.semantic && meaning.sources.isNotEmpty) {
        final eligible = meaning.sources.where(
          (s) =>
              selection.scope == null ||
              selection.scope!.contains(civil(s.date)),
        );
        selection = DiaryHistorySelection.select(
          question: widget.question,
          today: today,
          days: days,
          ranked: {
            ...eligible.map((s) => s.id),
            ...selection.sources.map((s) => s.uuid),
          }.toList(),
        );
      }
      if (mounted) {
        setState(() => _selection = selection);
        await ref.read(aiJobsProvider.notifier).restore();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not prepare diary excerpts. Your writing is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ask() async {
    final selection = _selection;
    if (selection == null || !selection.sendable || _sending) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    await ref
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.history,
          'history:${recallHash(selection.question)}',
          selection.request(),
          selection.encode(),
        );
    if (mounted) {
      setState(() {
        _sending = false;
        _message = ref.read(aiJobsProvider).message;
      });
    }
  }

  Widget _source(DiaryHistorySource source) => Consumer(
    builder: (context, ref, _) {
      final opened = ref.watch(diaryDocumentProvider(source.uuid));
      final entry = opened.value?.entry;
      final deleted =
          opened.hasValue && (entry == null || entry.deletedAt != null);
      final changed = entry != null && itemVersion(entry) != source.version;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(source.date),
        subtitle: Text(
          '${source.text}${deleted
              ? '\nEntry deleted'
              : changed
              ? '\nEntry edited since this answer'
              : ''}',
        ),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: deleted
            ? null
            : () => context.go(
                diaryEntryLocation(
                  entry?.date ?? CivilDate.tryParse(source.date)!,
                  source.uuid,
                ),
              ),
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final task = ref.watch(aiJobsProvider);
    final job = task.job;
    final ours =
        job?.operation == AiOperation.history &&
        job?.key == 'history:${recallHash(widget.question)}';
    DiaryHistoryAnswer? answer;
    DiaryHistorySelection? source;
    if (ours && job!.phase == 'completed' && job.text != null) {
      try {
        source = DiaryHistorySelection.decode(job.source);
        answer = DiaryHistoryAnswer.parse(job.text!, source);
      } catch (_) {
        _message = 'The answer did not pass its source checks. Your entries are unchanged.';
      }
    }
    final selection = source ?? _selection;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask your past')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '“${widget.question}”',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (_message ?? task.message case final message?) Text(message),
                if (answer != null) ...[
                  Text(
                    answer.answered ? answer.text : 'These excerpts did not contain enough information to answer your question.',
                    key: const ValueKey('diary-answer-text'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Based only on the cited entries. Their dates show when you wrote, which may differ from when something happened.',
                  ),
                  for (final citation in answer.citations) _source(citation),
                ] else if (selection != null) ...[
                  Text(selection.scope?.label ?? 'All diary history'),
                  const SizedBox(height: 12),
                  Text(
                    selection.sendable
                        ? 'Review these excerpts before sending them with your question to your paired computer.'
                        : 'No matching entries were found. Nothing was sent.',
                  ),
                  for (final item in selection.sources) _source(item),
                ],
                if (job == null && selection?.sendable == true)
                  FilledButton(
                    onPressed: _loading || _sending ? null : _ask,
                    child: Text(
                      _sending ? 'Asking…' : 'Ask using these excerpts',
                    ),
                  ),
                if (job != null) ...[
                  if (!ours)
                    const Text(
                      'Another AI task is waiting. Finish or clear it in Grand Maestar.',
                    ),
                  if (ours && !job.terminal)
                    TextButton(
                      onPressed: ref.read(aiJobsProvider.notifier).cancel,
                      child: const Text('Cancel task'),
                    ),
                  if (ours && !task.busy && !job.terminal)
                    TextButton(
                      onPressed: ref.read(aiJobsProvider.notifier).retry,
                      child: const Text('Retrieve task'),
                    ),
                  if (ours && job.terminal)
                    TextButton(
                      onPressed: ref.read(aiJobsProvider.notifier).clear,
                      child: const Text('Clear answer'),
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
