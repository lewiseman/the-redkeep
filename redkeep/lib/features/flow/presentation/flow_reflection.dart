import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../assets/presentation/local_artwork.dart';
import '../application/flow_ai.dart';
import '../domain/thought_reflection_contract.dart';
import 'flow_thought_card.dart';

class FlowReflection extends ConsumerStatefulWidget {
  const FlowReflection({super.key, required this.id, required this.paper});
  final String id;
  final FlowThoughtPaper paper;
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
    final consumer = thoughtReflectionConsumerProvider(widget.id);
    final jobs = aiJobsProvider(flowReflectionScope(widget.id));
    ref.watch(consumer);
    final reflections = ref.watch(thoughtReflectionsProvider(widget.id));
    final saveMessage = ref.watch(reflectionMessagesProvider)[widget.id];
    final jobState = ref.watch(jobs);
    final job = jobState.job;
    final ours =
        job?.operation == AiOperation.thoughtReflection &&
        job?.key == widget.id;
    final repo = ref.read(thoughtReflectionsRepositoryProvider);
    final kept = reflections.value?.kept,
        proposal = reflections.value?.proposal;
    final paper = widget.paper;
    final caption = TextStyle(
      color: paper.secondary,
      fontSize: 10,
      letterSpacing: 1.8,
    );
    final quiet = TextStyle(color: paper.secondary, fontSize: 12, height: 1.4);
    final line = TextStyle(
      color: paper.foreground,
      fontSize: 16,
      height: 1.45,
      fontStyle: FontStyle.italic,
    );
    final button = TextButton.styleFrom(
      foregroundColor: paper.foreground,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return DefaultTextStyle.merge(
      style: quiet,
      child: TextButtonTheme(
        data: TextButtonThemeData(style: button),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: widget.paper.secondary.withValues(alpha: .2)),
            const SizedBox(height: 8),
            if (reflections.hasError)
              const Text(
                'Could not load reflections. Reopen this thought to retry.',
              ),
            if (kept != null) ...[
              const SizedBox(height: 12),
              Text('YOUR KEPT REFLECTION', style: caption),
              const SizedBox(height: 10),
              SelectableText(kept.text, style: line),
              TextButton(
                onPressed: _working
                    ? null
                    : () => _run(() => repo.remove(kept.taskId)),
                child: const Text('Remove reflection'),
              ),
            ],
            if (proposal != null) ...[
              const SizedBox(height: 12),
              Text('SUGGESTED REFLECTION · NOT KEPT YET', style: caption),
              const SizedBox(height: 10),
              SelectableText(proposal.text, style: line),
              if (kept != null)
                const Text('Keeping this replaces your kept reflection.'),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
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
                  onPressed: _working ? null : () => _run(ref.read(consumer)),
                  child: const Text('Retry saving reflection'),
                ),
              if (!job.terminal)
                TextButton(
                  onPressed: () => _run(ref.read(jobs.notifier).cancel),
                  child: const Text('Cancel reflection'),
                ),
              if (!jobState.busy && job.phase != 'completed')
                TextButton(
                  onPressed: () => _run(ref.read(jobs.notifier).retry),
                  child: const Text('Retry reflection'),
                ),
              if (job.terminal)
                TextButton(
                  onPressed: () => _run(
                    () => ref.read(jobs.notifier).clearIfCurrent(job.id),
                  ),
                  child: const Text('Clear reflection task'),
                ),
            ] else
              Center(
                child: TextButton(
                  key: const ValueKey('flow-reflect'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _working
                      ? null
                      : () => _run(
                          () => ref.read(flowAiProvider).reflect(widget.id),
                        ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LocalArtwork(
                        assetKey: 'flow.reflect',
                        dimension: 72,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _working
                            ? 'Reflecting…'
                            : kept == null
                            ? 'Reflect on this'
                            : 'Reflect again',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
