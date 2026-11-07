import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../recall/application/recall_search.dart';
import '../../recall/domain/recall.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../application/flow_ai.dart';
import 'flow_question_task.dart';

/// Excerpts for a submitted question. Only built after the person presses
/// search, because selecting excerpts embeds the question.
final flowQuestionSelectionProvider = FutureProvider.autoDispose
    .family<RecallQuestionSelection, String>((ref, question) async {
      ref.watch(flowSearchSourcesProvider);
      return ref.read(flowAiProvider).select(question);
    });

class FlowSearchPage extends ConsumerStatefulWidget {
  const FlowSearchPage({super.key});
  @override
  ConsumerState<FlowSearchPage> createState() => _FlowSearchPageState();
}

class _FlowSearchPageState extends ConsumerState<FlowSearchPage> {
  final _search = TextEditingController();

  /// What is typed: filters thoughts by keyword, with no AI request.
  String _query = '';

  /// What was submitted with the keyboard's search key: adds meaning results
  /// and the AI answer preview. Editing the text clears it.
  String _submitted = '';
  bool _asking = false;
  String? _message;
  static final _jobs = aiJobsProvider(flowSearchJobScope);

  void _submit(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _submitted = query;
      _message = null;
    });
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
    final meaning = enabled && _submitted.isNotEmpty
        ? ref.watch(recallSearchProvider((query: _submitted, kind: 'thought')))
        : null;
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
    final task = enabled ? ref.watch(_jobs) : null;
    final job = task?.job;
    final preview = enabled && _submitted.isNotEmpty && job == null
        ? ref.watch(flowQuestionSelectionProvider(_submitted))
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Search Flow')),
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
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Find a thought or ask a question',
                    helperText: enabled
                        ? 'Press search to look by meaning and ask AI'
                        : null,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value.trim();
                    if (_submitted.isNotEmpty && _query != _submitted) {
                      _submitted = '';
                    }
                    _message = null;
                  }),
                  onSubmitted: _submit,
                ),
                if (meaning?.value?.message case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(message),
                  ),
                if (_message ?? task?.message case final message?)
                  Text(message),
                if (job != null) ...[
                  const SizedBox(height: 20),
                  FlowQuestionTask(job: job),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!job.terminal)
                        TextButton(
                          onPressed: ref.read(_jobs.notifier).cancel,
                          child: const Text('Cancel question'),
                        ),
                      if (!task!.busy && job.phase != 'completed')
                        TextButton(
                          onPressed: ref.read(_jobs.notifier).retry,
                          child: const Text('Try again'),
                        ),
                      if (job.terminal)
                        TextButton(
                          onPressed: () =>
                              ref.read(_jobs.notifier).clearIfCurrent(job.id),
                          child: const Text('Clear answer'),
                        ),
                    ],
                  ),
                ],
                if (preview != null)
                  preview.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Finding excerpts for your question…'),
                    ),
                    error: (error, _) => Text(
                      error is FormatException ? error.message : 'Could not prepare AI excerpts. Search again to retry.',
                    ),
                    data: (selection) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'AI can answer using these thoughts. Excerpts go to your AI provider only when you ask.',
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
