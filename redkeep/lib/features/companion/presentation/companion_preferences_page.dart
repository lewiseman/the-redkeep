import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_preferences.dart';
import '../../recall/application/recall_controller.dart';
import 'ai_studio_material.dart';
import 'companion_hub_widgets.dart';

class CompanionPreferencesPage extends ConsumerWidget {
  const CompanionPreferencesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiPreferencesProvider);
    final prefs = settings.value;
    final index = ref.watch(recallControllerProvider);
    final controller = ref.read(recallControllerProvider.notifier);
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save this preference. Retry.'),
            ),
          );
        }
      }
    }

    return CompanionDetailLayout(
      title: 'Make it yours',
      children: [
        const CompanionDetailHeading(
          icon: Icons.tune,
          title: 'A little help, your way',
          description: 'Turn off anything you don’t want. These choices stay on this phone.',
        ),
        AiStudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const ValueKey('daily-questions-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily diary questions'),
                value: prefs?.dailyQuestions ?? true,
                onChanged: prefs == null
                    ? null
                    : (v) => change(
                        () => ref
                            .read(aiPreferencesRepositoryProvider)
                            .questions(v),
                      ),
              ),
              const Text(
                'While today’s diary is open, AI can ask a gentle question using up to four entries from today, eight from the previous week, and your last five questions, within the request limit. It goes only to the computer or provider you chose for this task, and a provider asks only when you tap unless you allow it to ask automatically. Turning this off clears this phone’s question history.',
              ),
            ],
          ),
        ),
        const AiStudioSectionHeading(label: 'Search by meaning'),
        const Text(
          'Find notes, diary entries and Flow thoughts by what they mean. Each enabled collection sends its complete saved text to your paired computer in small chunks. Embeddings stay in a separate, rebuildable database on this phone. Drafts and attachments are excluded. Search uses keywords while your computer is away.',
        ),
        const SizedBox(height: 12),
        for (final item in [
          ('note', 'Notes'),
          ('diary', 'Diary entries'),
          ('thought', 'Flow thoughts'),
        ])
          SwitchListTile(
            key: ValueKey('recall-${item.$1}'),
            contentPadding: EdgeInsets.zero,
            title: Text(item.$2),
            subtitle: Text(
              '${index.counts[item.$1] ?? 0} saved sources indexed',
            ),
            value: prefs?.collections.contains(item.$1) ?? true,
            onChanged: prefs == null
                ? null
                : (v) => change(() => controller.setEnabled(item.$1, v)),
          ),
        if (index.running) ...[
          LinearProgressIndicator(
            value: index.total == 0 ? null : index.done / index.total,
          ),
          Text('Indexing ${index.done} of ${index.total}…'),
        ],
        if (prefs?.paused == true) const Text('Indexing is paused.'),
        if (index.message != null) Text(index.message!),
        if (!index.running && index.message == null && prefs != null)
          const Text('Up to date.'),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: prefs == null
                  ? null
                  : () => change(() => controller.pause(!prefs.paused)),
              child: Text(
                prefs?.paused == true ? 'Resume indexing' : 'Pause indexing',
              ),
            ),
            TextButton(
              onPressed: index.running ? null : () => change(controller.run),
              child: const Text('Retry indexing'),
            ),
            TextButton(
              onPressed: index.running
                  ? null
                  : () => change(controller.rebuild),
              child: const Text('Rebuild search index'),
            ),
          ],
        ),
        const Text(
          'Turning a collection off removes its vectors. Your writing stays saved. Indexing runs only while Redkeep is open and the companion is connected.',
        ),
      ],
    );
  }
}
