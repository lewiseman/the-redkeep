import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/domain/ai_job.dart';
import '../../recall/domain/recall_question_contract.dart';
import '../application/flow_providers.dart';

/// Uses the captured question, never the currently edited search field.
class FlowQuestionTask extends StatelessWidget {
  const FlowQuestionTask({super.key, required this.job});
  final AiJob job;
  @override
  Widget build(BuildContext context) {
    try {
      final source = RecallQuestionSelection.decode(job.source);
      final answer = job.phase == 'completed' && job.text != null
          ? RecallQuestionAnswer.parse(job.text!, source)
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '“${source.question}”',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(source.coverage),
          if (answer != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              answer.text,
              key: const ValueKey('flow-answer-text'),
            ),
            if (answer.answered)
              const Text(
                'Based only on these thoughts. Dates show when you wrote them.',
              ),
            for (final citation in answer.citations)
              FlowQuestionSource(source: citation),
          ] else
            Text('Flow question: ${job.phase}'),
        ],
      );
    } catch (_) {
      return const Text(
        'This answer could not be verified. Clear the task to ask again.',
      );
    }
  }
}

class FlowQuestionSource extends ConsumerWidget {
  const FlowQuestionSource({super.key, required this.source});
  final RecallQuestionSource source;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(thoughtDocumentProvider(source.uuid));
    final current = opened.value?.thought;
    final deleted =
        opened.hasValue && (current == null || current.deletedAt != null);
    final changed =
        current != null &&
        !deleted &&
        RecallItem.thought(current)!.version != source.version;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(source.date),
      subtitle: Text(
        '${source.text}${deleted
            ? '\nThought deleted'
            : changed
            ? '\nThought edited since this answer'
            : ''}',
      ),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: opened.isLoading || opened.hasError || deleted
          ? null
          : () => context.push(thoughtLocation(source.uuid)),
    );
  }
}
