import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'diary_maester_button.dart';
import '../../../app/app_shell.dart';
import '../../../app/navigation_destination.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_widgets.dart';

class DiaryEntryPage extends ConsumerWidget {
  const DiaryEntryPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
    floatingActionButton: DiaryMaesterButton(address: address),
    child: ref
        .watch(diaryDocumentProvider(address.id))
        .when(
          loading: () => const Text('Loading entry…'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(diaryDocumentProvider(address.id)),
            child: const Text('Could not load entry. Retry'),
          ),
          data: (opened) {
            final entry = opened.entry;
            final available = opened.available && entry!.date == address.date;
            return NotebookSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    available
                        ? diaryTitle(entry.text.title)
                        : 'Entry unavailable',
                    style: DiaryTypography.of(context).title,
                  ),
                  Text(address.date.key),
                  if (available) ...[
                    Text('Revision ${entry.revision} • saved on this device'),
                    const SizedBox(height: 16),
                    SelectableText(
                      entry.text.body,
                      style: DiaryTypography.of(context).body,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: !ref.watch(syncCanEditProvider)
                          ? null
                          : () => context.go(
                              diaryEntryLocation(
                                address.date,
                                address.id,
                                edit: true,
                              ),
                            ),
                      child: const Text('Edit entry'),
                    ),
                    OutlinedButton(
                      onPressed:
                          !ref.watch(syncCanEditProvider) ||
                              ref.watch(diaryActionsProvider)
                          ? null
                          : () => _delete(context, ref, entry),
                      child: const Text('Delete entry'),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: () => context.go(diaryDayLocation(address.date)),
                    child: const Text('Return to day'),
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
    DiaryEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => DiaryDialog(
        children: [
          Text(
            'Delete this entry?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text('The saved text will be removed. This cannot be undone.'),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep entry'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete committed entry'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(diaryActionsProvider.notifier)
          .run((repo) => repo.deleteEntry(entry.id, entry.revision));
      if (context.mounted) context.go(diaryDayLocation(address.date));
    } catch (_) {
      if (context.mounted) {
        diaryMessage(
          context,
          'Entry could not be deleted. Reload the entry and retry.',
        );
      }
      ref.invalidate(diaryDocumentProvider(address.id));
    }
  }
}
