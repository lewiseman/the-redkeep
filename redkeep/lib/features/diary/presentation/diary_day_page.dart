import '../../sync/application/sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/diary_providers.dart';
import '../domain/civil_date.dart';
import '../domain/diary_document.dart';
import 'diary_widgets.dart';

class DiaryDayPage extends ConsumerWidget {
  const DiaryDayPage({super.key, required this.date});
  final CivilDate date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(diaryActionsProvider);
    final day = ref.watch(diaryDayProvider(date));
    return DiaryFrame(
      slivers: [
        diaryBlock(
          NotebookSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  date.key,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                day.when(
                  loading: () => const Text('Loading day heading…'),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(diaryDayProvider(date)),
                    child: const Text('Retry day heading'),
                  ),
                  data: (value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (value.heading.isNotEmpty)
                        Text(
                          value.heading,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      TextButton(
                        onPressed: busy || !ref.watch(syncCanEditProvider)
                            ? null
                            : () => _rename(context, ref, value),
                        child: const Text('Name this day'),
                      ),
                    ],
                  ),
                ),
                const Text('Diary day • plain text • on this device'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed:
                          busy ||
                              (!ref.watch(syncCanEditProvider) &&
                                  date !=
                                      CivilDate.fromComponents(
                                        ref.read(diaryClockProvider)(),
                                      ))
                          ? null
                          : () async {
                              try {
                                final id = await ref
                                    .read(diaryActionsProvider.notifier)
                                    .create(date);
                                if (context.mounted) {
                                  context.go(
                                    diaryEntryLocation(date, id, edit: true),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  diaryMessage(
                                    context,
                                    'Could not create a draft. Check device storage and retry.',
                                  );
                                }
                              }
                            },
                      child: const Text('Write an entry'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(diaryCalendarLocation(date)),
                      child: const Text('Calendar for this month'),
                    ),
                    OutlinedButton(
                      onPressed: date.shift(-1) == null
                          ? null
                          : () => context.go(diaryDayLocation(date.shift(-1)!)),
                      child: const Text('Previous day'),
                    ),
                    OutlinedButton(
                      onPressed: date.shift(1) == null
                          ? null
                          : () => context.go(diaryDayLocation(date.shift(1)!)),
                      child: const Text('Next day'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ref
            .watch(diaryEntriesProvider(date))
            .when(
              loading: () => diaryBlock(const Text('Loading entries…')),
              error: (_, _) => diaryBlock(
                TextButton(
                  onPressed: () => ref.invalidate(diaryEntriesProvider(date)),
                  child: const Text('Could not load entries. Retry'),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? diaryBlock(
                      const Text(
                        'No entries for this day. Write whenever you are ready.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: _DayEntry(listing: entries[index]),
                      ),
                    ),
            ),
      ],
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    DiaryDay day,
  ) async {
    final controller = TextEditingController(text: day.heading);
    final heading = await showDialog<String>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => DiaryDialog(
        children: [
          Text(
            'Name this day',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          TextField(
            controller: controller,
            maxLength: 160,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Day heading'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save heading'),
          ),
        ],
      ),
    );
    // Dialog route disposal follows its returned future.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (heading == null) return;
    try {
      await ref
          .read(diaryActionsProvider.notifier)
          .run((repo) => repo.renameDay(day, heading));
    } catch (_) {
      if (context.mounted) {
        diaryMessage(
          context,
          'Heading could not be saved. Reload the day and retry.',
        );
      }
    }
  }
}

class _DayEntry extends ConsumerWidget {
  const _DayEntry({required this.listing});
  final DiaryListing listing;
  @override
  Widget build(BuildContext context, WidgetRef ref) => NotebookSurface(
    child: ref
        .watch(diaryDocumentProvider(listing.id))
        .when(
          loading: () => const Text('Loading entry…'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(diaryDocumentProvider(listing.id)),
            child: const Text('Retry entry'),
          ),
          data: (opened) {
            final entry = opened.entry;
            if (!opened.available || entry!.date != listing.date) {
              return const Text('Entry unavailable.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  diaryTitle(entry.text.title),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                // Full text is available in the focused reader; day layout stays bounded.
                Text(
                  entry.text.body,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                ),
                TextButton(
                  onPressed: () =>
                      context.go(diaryEntryLocation(entry.date, entry.id)),
                  child: const Text('Read full entry'),
                ),
              ],
            );
          },
        ),
  );
}
