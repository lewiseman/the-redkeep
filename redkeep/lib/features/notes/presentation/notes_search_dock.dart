import 'package:flutter/material.dart';

import 'notes_collection_sheet.dart';

/// The notes page's controls, kept in the thumb's reach just above the
/// navigation bar: which collection is showing, the search field scoped to
/// it, and a trailing action that creates a note, or asks the notes once
/// there is a question typed.
///
/// Only this widget rebuilds while typing; the collection behind it updates
/// from the debounced filter.
class NotesSearchDock extends StatelessWidget {
  const NotesSearchDock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.collection,
    required this.onCollections,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onAsk,
    required this.addButton,
  });

  static const height = 72.0;

  final TextEditingController controller;
  final FocusNode focusNode;
  final NoteCollectionOption collection;
  final VoidCallback onCollections;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  /// Opens "Ask your notes" with the typed text; null where asking is not
  /// offered (Trash).
  final ValueChanged<String>? onAsk;
  final Widget addButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trash = collection.value == NoteCollection.trash;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final narrow = MediaQuery.sizeOf(context).width < 360 || scale > 1.3;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final text = controller.text.trim();
        final asking = onAsk != null && text.isNotEmpty;
        // While typing, the field gets the room; the scope keeps its emoji.
        final compactScope = narrow || focusNode.hasFocus;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surfaceContainerHigh,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: focusNode.hasFocus
                          ? colors.primary.withValues(alpha: .8)
                          : colors.outlineVariant.withValues(alpha: .6),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      _ScopeButton(
                        collection: collection,
                        compact: compactScope,
                        onTap: onCollections,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('notes-search'),
                          controller: controller,
                          focusNode: focusNode,
                          maxLength: 256,
                          textInputAction: TextInputAction.search,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                          ),
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          onTapOutside: (_) => focusNode.unfocus(),
                          decoration: InputDecoration(
                            hintText: trash ? 'Search Trash' : 'Search notes',
                            hintStyle: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 15,
                            ),
                            counterText: '',
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      if (controller.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClear,
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.onSurfaceVariant,
                            size: 20,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 16, left: 4),
                          child: Icon(
                            Icons.search_rounded,
                            color: colors.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: height,
              child: Center(
                child: asking
                    ? _AskButton(onPressed: () => onAsk!(text))
                    : addButton,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The collection the search is scoped to. Tapping it opens the full list of
/// collections and tags as large targets.
class _ScopeButton extends StatelessWidget {
  const _ScopeButton({
    required this.collection,
    required this.compact,
    required this.onTap,
  });

  final NoteCollectionOption collection;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filtered = collection.value != NoteCollection.all;
    // Built-in names are short; a tag shows its emoji here and its full name
    // in the page header, so the field keeps room to type.
    final label = NoteCollection.isBuiltIn(collection.value) && !compact
        ? collection.value == NoteCollection.all
              ? 'All'
              : collection.name
        : null;
    return Semantics(
      button: true,
      label: 'Collections, showing ${collection.name}',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Collections',
        excludeFromSemantics: true,
        child: Material(
          key: const ValueKey('notes-collections'),
          color: filtered
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: label == null ? 10 : 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      collection.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (label != null) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: filtered
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: filtered
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
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
}

class _AskButton extends StatelessWidget {
  const _AskButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filled(
      key: const ValueKey('notes-ask'),
      tooltip: 'Ask your notes',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(56),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 24),
    );
  }
}
