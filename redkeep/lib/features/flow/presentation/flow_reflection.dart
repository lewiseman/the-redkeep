import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../application/flow_ai.dart';
import '../domain/thought_reflection_contract.dart';

class FlowReflection extends ConsumerStatefulWidget {
  const FlowReflection({super.key, required this.id});
  final String id;
  @override
  ConsumerState<FlowReflection> createState() => _FlowReflectionState();
}

class _FlowReflectionState extends ConsumerState<FlowReflection> {
  String? _message;
  bool _working = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is ThoughtReflectionRejected
              ? error.message
              : 'Could not save this reflection. Your thought is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(thoughtReflectionConsumerProvider);
    final reflections = ref.watch(thoughtReflectionsProvider(widget.id));
    final saveMessage = ref.watch(reflectionMessagesProvider)[widget.id];
    final jobState = ref.watch(aiJobsProvider);
    final job = jobState.job;
    final ours =
        job?.operation == AiOperation.thoughtReflection &&
        job?.key == widget.id;
    final repo = ref.read(thoughtReflectionsRepositoryProvider);
    final kept = reflections.value?.kept,
        proposal = reflections.value?.proposal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          'A little reflection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'An optional line about this thought. Kept only on this device.',
        ),
        if (reflections.hasError)
          const Text(
            'Could not load reflections. Reopen this thought to retry.',
          ),
        if (kept != null) ...[
          const SizedBox(height: 12),
          const Text('Your kept reflection'),
          SelectableText(kept.text),
          TextButton(
            onPressed: _working
                ? null
                : () => _run(() => repo.remove(kept.taskId)),
            child: const Text('Remove reflection'),
          ),
        ],
        if (proposal != null) ...[
          const SizedBox(height: 12),
          const Text('Suggested reflection · not kept yet'),
          SelectableText(proposal.text),
          if (kept != null)
            const Text('Keeping this replaces your kept reflection.'),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _working
                    ? null
                    : () => _run(() => repo.keep(proposal)),
                child: const Text('Keep reflection'),
              ),
              TextButton(
                onPressed: _working
                    ? null
                    : () => _run(() => repo.remove(proposal.taskId)),
                child: const Text('Dismiss reflection'),
              ),
            ],
          ),
        ],
        if (_message ??
                saveMessage ??
                (ours || job == null ? jobState.message : null)
            case final message?)
          Text(message),
        if (ours) ...[
          Text('Reflection: ${job!.phase}'),
          if (job.phase == 'completed' && saveMessage != null)
            TextButton(
              onPressed: _working
                  ? null
                  : () => _run(ref.read(thoughtReflectionConsumerProvider)),
              child: const Text('Retry saving reflection'),
            ),
          if (!job.terminal)
            TextButton(
              onPressed: () => _run(ref.read(aiJobsProvider.notifier).cancel),
              child: const Text('Cancel reflection'),
            ),
          if (!jobState.busy && job.phase != 'completed')
            TextButton(
              onPressed: () => _run(ref.read(aiJobsProvider.notifier).retry),
              child: const Text('Retry reflection'),
            ),
          if (job.terminal)
            TextButton(
              onPressed: () => _run(
                () => ref.read(aiJobsProvider.notifier).clearIfCurrent(job.id),
              ),
              child: const Text('Clear reflection task'),
            ),
        ] else if (job != null)
          const Text(
            'Another AI task is open. Finish or clear it before asking for a reflection.',
          )
        else
          OutlinedButton(
            key: const ValueKey('flow-reflect'),
            onPressed: _working
                ? null
                : () => _run(() => ref.read(flowAiProvider).reflect(widget.id)),
            child: Text(
              _working
                  ? 'Reflecting…'
                  : kept == null
                  ? 'Reflect on this thought'
                  : 'Ask for another reflection',
            ),
          ),
        TextButton(
          onPressed: () => context.push('/settings/brain/history'),
          child: const Text('AI task history'),
        ),
      ],
    );
  }
}
