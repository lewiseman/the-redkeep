import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation_destination.dart';
import '../../application/notes_providers.dart';

/// A quiet marker that a website was made from an older version of the
/// note's text. It never covers the website.
class NoteWebsiteOutdatedPill extends StatelessWidget {
  const NoteWebsiteOutdatedPill({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onPressed != null,
      label: 'Website outdated. The note text changed since it was made.',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('note-website-outdated'),
        color: scheme.tertiaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 16,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Outdated',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onTertiaryContainer),
                    ),
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

/// On the note's text: a way back to its website, if it has one.
class NoteWebsiteCard extends ConsumerWidget {
  const NoteWebsiteCard({super.key, required this.noteId, required this.body});
  final String noteId, body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final website = ref.watch(noteWebsiteProvider(noteId)).value;
    // Shown plainly: the paper lays this out inside its own slivers.
    return website == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              key: const ValueKey('note-website-card'),
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(noteWebsiteLocation(noteId)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Website',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (website.isOutdatedFor(body))
                              const NoteWebsiteOutdatedPill(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Open',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
