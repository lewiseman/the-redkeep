import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../ai/domain/ai_operation.dart';
import '../../recall/application/recall_search.dart';
import '../../recall/domain/recall.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../application/flow_ai.dart';
import 'flow_question_task.dart';

final flowQuestionSelectionProvider = FutureProvider.autoDispose
    .family<RecallQuestionSelection, String>((ref, question) async {
      ref.watch(flowSearchSourcesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!ref.mounted) throw StateError('Search changed');
      return ref.read(flowAiProvider).select(question);
    });

class FlowSearchPage extends ConsumerStatefulWidget {
  const FlowSearchPage({super.key});
  @override
  ConsumerState<FlowSearchPage> createState() => _FlowSearchPageState();
}

class _FlowSearchPageState extends ConsumerState<FlowSearchPage> {
  final _search = TextEditingController();
  String _query = '';
  bool _edited = false, _asking = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      if (!mounted || !ref.read(aiEnabledProvider)) return;
      await ref.read(aiJobsProvider.notifier).restore();
      if (mounted) _restoreQuestion();
    });
  }

  void _restoreQuestion() {
    final job = ref.read(aiJobsProvider).job;
    if (_edited || job?.operation != AiOperation.thoughtQuestion) return;
    try {
      final source = RecallQuestionSelection.decode(job!.source);
      if (_query == source.question) return;
      setState(() {
        _search.text = source.question;
        _query = source.question;
      });
    } catch (_) {
      /* A malformed snapshot is recoverable through history. */
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _ask(RecallQuestionSelection selection) async {
    if (_asking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _message = null;
    });
    try {
      await ref.read(flowAiProvider).ask(selection);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException
              ? error.message
              : 'Could not ask about these thoughts. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(aiEnabledProvider);
    final sources = ref.watch(flowSearchSourcesProvider);
    final meaning = _query.isEmpty
        ? null
        : ref.watch(recallSearchProvider((query: _query, kind: 'thought')));
    final terms = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final keywords = [
      for (final source in sources.value ?? const <RecallSource>[])
        if (terms.every(source.text.toLowerCase().contains)) source,
    ];
    final current = {
      for (final s in sources.value ?? const <RecallSource>[]) s.id: s,
    };
    final matches = fuseRecall(keywords, [
      for (final source
          in meaning == null
              ? const <RecallSource>[]
              : currentRecallSources(meaning))
        if (current[source.id] case final live?)
          if (live.hash == source.hash && live.revision == source.revision)
            live,
    ], (source) => source.id);
    final task = enabled ? ref.watch(aiJobsProvider) : null;
    final job = task?.job;
    final ours = job?.operation == AiOperation.thoughtQuestion;
    final expired =
        job != null &&
        ref.read(aiClockProvider)().millisecondsSinceEpoch >= job.expires;
    final preview = enabled && _query.isNotEmpty && job == null
        ? ref.watch(flowQuestionSelectionProvider(_query))
        : null;
    if (enabled) {
      ref.listen(
        aiJobsProvider,
        (_, _) => scheduleMicrotask(() {
          if (mounted) _restoreQuestion();
        }),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Flow'),
        actions: [
          if (enabled)
            IconButton(
              tooltip: 'AI task history',
              onPressed: () => context.push('/settings/brain/history'),
              icon: const Icon(Icons.history_rounded),
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
                TextField(
                  key: const ValueKey('flow-search-field'),
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Find a thought or ask a question',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _edited = true;
                    _query = value.trim();
                    _message = null;
                  }),
                ),
                if (meaning?.value?.message case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(message),
                  ),
                if (_message ?? task?.message case final message?)
                  Text(message),
                if (ours && !expired) ...[
                  const SizedBox(height: 20),
                  FlowQuestionTask(job: job!),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!job.terminal)
                        TextButton(
                          onPressed: ref.read(aiJobsProvider.notifier).cancel,
                          child: const Text('Cancel question'),
                        ),
                      if (!task!.busy && job.phase != 'completed')
                        TextButton(
                          onPressed: ref.read(aiJobsProvider.notifier).retry,
                          child: const Text('Retrieve / retry question'),
                        ),
                      if (job.terminal)
                        TextButton(
                          onPressed: () => ref
                              .read(aiJobsProvider.notifier)
                              .clearIfCurrent(job.id),
                          child: const Text('Clear answer'),
                        ),
                    ],
                  ),
                ] else if (job != null) ...[
                  Text(
                    expired
                        ? 'This task’s preview has expired. Clear it in AI task history to ask again.'
                        : 'Another AI task is open. Finish or clear it before asking about your thoughts.',
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings/brain/history'),
                    child: const Text('Open AI task history'),
                  ),
                ],
                if (preview != null)
                  preview.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Finding excerpts for your question…'),
                    ),
                    error: (error, _) => Text(
                      error is FormatException ? error.message : 'Could not prepare AI excerpts. Edit the question to retry.',
                    ),
                    data: (selection) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'AI can answer using these thoughts. Excerpts go to your chosen phone model or paired computer only when you ask.',
                        ),
                        Text(
                          '${selection.searched} thoughts searched · ${selection.sources.length} excerpts selected${selection.scope == null ? '' : ' · ${selection.scope!.label}'}',
                        ),
                        if (selection.sources.isNotEmpty)
                          ExpansionTile(
                            title: const Text('Review selected excerpts'),
                            children: [
                              for (final source in selection.sources)
                                FlowQuestionSource(source: source),
                            ],
                          ),
                        FilledButton(
                          key: const ValueKey('flow-ask-ai'),
                          onPressed: _asking || !selection.sendable
                              ? null
                              : () => _ask(selection),
                          child: Text(_asking ? 'Asking…' : 'Ask AI'),
                        ),
                        if (!selection.sendable)
                          const Text(
                            'No thoughts match this question. Add a topic or a time; nothing was sent.',
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Matching thoughts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (sources.isLoading)
                  const LinearProgressIndicator()
                else if (sources.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(flowSearchSourcesProvider),
                    child: const Text('Could not search thoughts. Retry'),
                  )
                else if (matches.isEmpty)
                  const Text('No matching thoughts.')
                else
                  for (final thought in matches)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      title: Text(
                        thought.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(thought.date),
                      onTap: () => context.push(thoughtLocation(thought.id)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
