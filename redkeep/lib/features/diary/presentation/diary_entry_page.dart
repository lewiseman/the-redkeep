import 'photos/diary_photo_story_strip.dart';
import '../application/diary_media_providers.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/diary_providers.dart';
import '../domain/diary_document.dart';
import 'diary_widgets.dart';
import 'diary_day_page.dart';

class DiaryEntryPage extends ConsumerWidget {
  const DiaryEntryPage({super.key, required this.address});
  final DiaryAddress address;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(diaryPhotoStoreProvider);
    return DiaryWritingFrame(
      title: 'Diary entry',
      child: ref
          .watch(diaryDocumentProvider(address.id))
          .when(
            loading: () => const Text('Loading entry…'),
            error: (_, _) => TextButton(
              onPressed: () =>
                  ref.invalidate(diaryDocumentProvider(address.id)),
              child: const Text('Could not load entry. Retry'),
            ),
            data: (opened) {
              final entry = opened.entry;
              final available = opened.available && entry!.date == address.date;
              return NotebookSurface(
                variant: address.date.weekday,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!available)
                      Text(
                        'Entry unavailable',
                        style: DiaryTypography.of(context).title,
                      ),
                    Text(
                      address.date.label(
                        Localizations.localeOf(context).toString(),
                      ),
                    ),
                    if (available) ...[
                      const SizedBox(height: 16),
                      if (entry.photos.isNotEmpty)
                        DiaryPhotoStoryStrip(
                          item: entry,
                          onOpen: () => context.push(
                            '${diaryEntryLocation(address.date, address.id)}/photos',
                          ),
                        ),
                      if (entry.text.body.isNotEmpty)
                        SelectableText(
                          entry.text.body,
                          style: DiaryTypography.of(context).body,
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: !ref.watch(syncCanEditProvider)
                            ? null
                            : entry.photos.isEmpty
                            ? () => context.push(
                                diaryEntryLocation(
                                  address.date,
                                  address.id,
                                  edit: true,
                                ),
                              )
                            : () => context.go(
                                '${diaryEntryLocation(address.date, address.id)}/photos?edit=1',
                              ),
                        child: const Text('Edit entry'),
                      ),
                      OutlinedButton(
                        onPressed:
                            !ref.watch(syncCanEditProvider) ||
                                ref.watch(diaryActionsProvider)
                            ? null
                            : () async {
                                final deleted = await deleteDiaryEntry(
                                  context,
                                  ref,
                                  id: entry.id,
                                  revision: entry.revision,
                                );
                                if (deleted && context.mounted) {
                                  openDiaryDay(context, address.date);
                                }
                              },
                        child: const Text('Delete entry'),
                      ),
                    ],
                    OutlinedButton(
                      onPressed: () => openDiaryDay(context, address.date),
                      child: Text('Return to ${address.date.kind.name}'),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

/// Confirms, then deletes a saved entry. Returns whether it was deleted.
Future<bool> deleteDiaryEntry(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required int revision,
}) async {
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
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref
        .read(diaryActionsProvider.notifier)
        .run((repo) => repo.deleteEntry(id, revision));
    return true;
  } catch (_) {
    if (context.mounted) {
      diaryMessage(
        context,
        'Entry could not be deleted. Reload the entry and retry.',
      );
    }
    ref.invalidate(diaryDocumentProvider(id));
    return false;
  }
}
