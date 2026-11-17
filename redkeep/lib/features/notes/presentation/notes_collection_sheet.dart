import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notes_providers.dart';
import '../domain/note_tag.dart';
import '../domain/notes_query.dart';

typedef NoteCollectionOption = ({String emoji, String name, String value});

/// What the notes page shows: every note, the pinned ones, one tag, or Trash.
/// Collections replace each other rather than stacking.
abstract final class NoteCollection {
  /// Values for the built-in collections. The NUL prefix keeps them from
  /// colliding with user tags of the same name.
  static const all = 'All';
  static const pinned = '\u0000pinned';
  static const trash = '\u0000trash';

  static bool isBuiltIn(String value) =>
      value == all || value == pinned || value == trash;

  static String of(NotesQuery query) =>
      query.trash ? trash : query.tag ?? (query.pinnedOnly ? pinned : all);

  static NoteCollectionOption option(String value) => switch (value) {
    all => (emoji: '🗂️', name: 'All notes', value: all),
    pinned => (emoji: '📌', name: 'Pinned', value: pinned),
    trash => (emoji: '🗑️', name: 'Trash', value: trash),
    _ => (
      emoji: NoteTag.tryParse(value)?.emoji ?? '🏷️',
      name: NoteTag.tryParse(value)?.name ?? value,
      value: value,
    ),
  };

  static String key(String value) => switch (value) {
    all => 'notes-all',
    pinned => 'notes-pinned',
    trash => 'notes-trash',
    _ => 'notes-tag-$value',
  };

  /// [options] in display order: Pinned, All, the user tags in their given
  /// order, then Trash last.
  static List<T> arrange<T extends NoteCollectionOption>(List<T> options) => [
    ...options.where((option) => option.value == pinned),
    ...options.where((option) => option.value == all),
    ...options.where((option) => !isBuiltIn(option.value)),
    ...options.where((option) => option.value == trash),
  ];
}

/// Opens the collection picker from the bottom of the screen, where the thumb
/// already is. Resolves to the chosen collection, or null when dismissed.
Future<String?> showNoteCollectionSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      // Above the shell's floating bar, which would cover the last row.
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _NoteCollectionSheet(),
    );

class _NoteCollectionSheet extends ConsumerWidget {
  const _NoteCollectionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(notesFilterProvider);
    final tags = ref.watch(noteTagsProvider);
    final selected = NoteCollection.of(filter);
    final userTags = [
      for (final raw in {...?tags.value, ?filter.tag})
        NoteCollection.option(raw),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stacked = scale > 1.3 || MediaQuery.sizeOf(context).width < 340;

    Widget tile(String value) => NoteCollectionTile(
      option: NoteCollection.option(value),
      selected: selected == value,
      onTap: () => Navigator.pop(context, value),
    );

    Widget pair(Widget a, Widget b) => stacked
        ? Column(children: [a, const SizedBox(height: 10), b])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Text(
                'Show notes from',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            pair(tile(NoteCollection.all), tile(NoteCollection.pinned)),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(
                'Tags',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: .4,
                ),
              ),
            ),
            if (tags.hasError && userTags.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tags could not be loaded.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(noteTagsProvider),
                    child: const Text('Retry tags'),
                  ),
                ],
              )
            else if (userTags.isEmpty && !tags.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Tags you give a note gather here, so related notes are '
                  'one tap away.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              )
            else
              for (var i = 0; i < userTags.length; i += stacked ? 1 : 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: stacked
                      ? tile(userTags[i].value)
                      : pair(
                          tile(userTags[i].value),
                          i + 1 < userTags.length
                              ? tile(userTags[i + 1].value)
                              : const SizedBox.shrink(),
                        ),
                ),
            const SizedBox(height: 14),
            tile(NoteCollection.trash),
          ],
        ),
      ),
    );
  }
}

/// A large, thumb-sized target for one collection.
class NoteCollectionTile extends StatelessWidget {
  const NoteCollectionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final NoteCollectionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      key: ValueKey(NoteCollection.key(option.value)),
      button: true,
      selected: selected,
      label: option.name,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected
                ? colors.primary.withValues(alpha: .7)
                : colors.outlineVariant.withValues(alpha: .5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(option.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
