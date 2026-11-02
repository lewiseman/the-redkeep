import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/presentation/paper_surface.dart';
import '../../../app/navigation_destination.dart';
import '../application/flow_providers.dart';
import '../domain/thought.dart';

class ThoughtReadPage extends ConsumerWidget {
  const ThoughtReadPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
    child: ref
        .watch(thoughtDocumentProvider(id))
        .when(
          loading: () => const Text('Loading thought…'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(thoughtDocumentProvider(id)),
            child: const Text('Could not load thought. Retry'),
          ),
          data: (opened) {
            final entry = opened.thought;
            final available = opened.available;
            return PaperSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    available ? 'Thought' : 'Thought unavailable',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (available) ...[
                    Text('Revision ${entry!.revision} • saved on this device'),
                    const SizedBox(height: 16),
                    SelectableText(entry.body),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          context.go(thoughtLocation(id, edit: true)),
                      child: const Text('Edit thought'),
                    ),
                    OutlinedButton(
                      onPressed: () => _delete(context, ref, entry),
                      child: const Text('Delete thought'),
                    ),
                  ],
                  if (opened.draft != null && !opened.draft!.capture) ...[
                    const Text(
                      'Separate unfinished writing is kept as a recovery draft.',
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          context.go(thoughtLocation(id, edit: true)),
                      child: const Text('Recover draft'),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: () => context.go('/flow'),
                    child: const Text('Return to Flow'),
                  ),
                ],
              ),
            );
          },
        ),
  );

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
                'The committed text will be removed. This cannot be undone. Any separate recovery draft is kept.',
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
