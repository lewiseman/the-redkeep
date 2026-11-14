import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'watch_widgets.dart';

/// Status and lists for one title, updating live.
Future<void> showWatchListSheet(BuildContext context, CatalogTitle title) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (_) => WatchListSheet(title: title),
  );
}

class WatchListSheet extends ConsumerWidget {
  const WatchListSheet({super.key, required this.title});
  final CatalogTitle title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final saved = ref.watch(watchTitleProvider(title.key.id)).value;
    final lists = ref.watch(watchListsProvider).value ?? const [];
    final repository = ref.read(watchlistRepositoryProvider);
    final heading = TextStyle(
      color: palette.muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          title.title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text('Status', style: heading),
        const SizedBox(height: 8),
        WatchStatusChips(title: title, status: saved?.status),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Your lists', style: heading)),
            TextButton.icon(
              onPressed: () async {
                final name = await askListName(context);
                if (name == null || !context.mounted) return;
                await runWatchAction(
                  context,
                  () => repository.createList(name, first: title),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New list'),
            ),
          ],
        ),
        if (lists.isEmpty)
          Text(
            'Lists you make, like “Date night” or “With the kids”, appear here.',
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.4),
          ),
        for (final list in lists)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: list.items.contains(title.key.id),
            title: Text(list.name),
            onChanged: (member) => runWatchAction(
              context,
              () => repository.setInList(list.id, title, member ?? false),
            ),
          ),
        if (saved != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await runWatchAction(
                  context,
                  () => repository.removeTitle(saved.id),
                );
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove from Watchlist'),
            ),
          ),
        ],
      ],
    );
  }
}

/// One status at a time; choosing the current one clears it. A liked title
/// moved to a status leaves Likes.
class WatchStatusChips extends ConsumerWidget {
  const WatchStatusChips({super.key, required this.title, this.status});
  final CatalogTitle title;
  final WatchStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final s in WatchStatus.values)
        ChoiceChip(
          label: Text(s.action),
          selected: status == s,
          onSelected: (selected) => runWatchAction(
            context,
            () => ref
                .read(watchNightsProvider)
                .setStatus(title, selected ? s : null),
          ),
        ),
    ],
  );
}
