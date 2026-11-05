import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../sync/application/sync_providers.dart';
import '../application/flow_providers.dart';
import '../domain/thought.dart';
import 'flow_reflection.dart';
import 'flow_thought_card.dart';

class ThoughtReadPage extends ConsumerWidget {
  const ThoughtReadPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paper = flowThoughtColors(id, Theme.of(context).colorScheme);
    final quiet = TextStyle(color: paper.secondary, fontSize: 12, height: 1.4);
    final button = TextButton.styleFrom(foregroundColor: paper.foreground);
    final canEdit = ref.watch(syncCanEditProvider);
    return Scaffold(
      backgroundColor: paper.background,
      appBar: AppBar(
        backgroundColor: paper.background,
        foregroundColor: paper.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            (ThemeData.estimateBrightnessForColor(paper.background) ==
                        Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
        toolbarHeight: 64,
        leading: Center(
          child: IconButton(
            tooltip: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/flow'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: paper.foreground.withValues(alpha: .08),
              foregroundColor: paper.foreground,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: ref
                  .watch(thoughtDocumentProvider(id))
                  .when(
                    loading: () => Text('Loading thought…', style: quiet),
                    error: (_, _) => TextButton(
                      style: button,
                      onPressed: () =>
                          ref.invalidate(thoughtDocumentProvider(id)),
                      child: const Text('Could not load thought. Retry'),
                    ),
                    data: (opened) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (opened.available) ...[
                          Text(
                            'YOUR THOUGHT',
                            style: TextStyle(
                              color: paper.secondary,
                              fontSize: 10,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            DateFormat('EEEE, MMMM d · h:mm a')
                                .format(opened.thought!.createdAt.toLocal()),
                            style: quiet,
                          ),
                          const SizedBox(height: 24),
                          SelectableText(
                            opened.thought!.body,
                            style: TextStyle(
                              fontSize: 23,
                              height: 1.5,
                              letterSpacing: -.4,
                              color: paper.foreground,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (ref.watch(aiEnabledProvider))
                            FlowReflection(id: id, paper: paper),
                          const SizedBox(height: 24),
                          Text(
                            'Revision ${opened.thought!.revision} • saved on this device',
                            style: quiet,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                style: button,
                                onPressed: !canEdit
                                    ? null
                                    : () => context.go(
                                        thoughtLocation(id, edit: true),
                                      ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit thought'),
                              ),
                              TextButton.icon(
                                style: button,
                                onPressed: !canEdit
                                    ? null
                                    : () => _delete(
                                        context,
                                        ref,
                                        opened.thought!,
                                      ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Delete thought'),
                              ),
                            ],
                          ),
                        ] else
                          Text(
                            'Thought unavailable',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: paper.foreground),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            style: button,
                            onPressed: () => context.go('/flow'),
                            child: const Text('Return to Flow'),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Thought entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete this thought?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'The saved text will be removed. This cannot be undone.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep thought'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete committed thought'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(flowRepositoryProvider)
          .deleteThought(entry.id, entry.revision);
      if (context.mounted) context.go('/flow');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thought could not be deleted. Reload the thought and retry.',
            ),
          ),
        );
      }
      ref.invalidate(thoughtDocumentProvider(id));
    }
  }
}
