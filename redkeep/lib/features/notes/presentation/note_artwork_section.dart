import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../data/note_media_store.dart';
import 'note_scene.dart';

/// The artwork half of the background sheet: one canvas showing what the note
/// will wear, and ways to choose a picture for it, from the stock photo
/// library or the reader's own photos. Nothing reaches the note until the
/// sheet's own Apply.
class NoteArtworkSection extends ConsumerStatefulWidget {
  const NoteArtworkSection({
    super.key,
    required this.id,
    required this.imageKey,
    required this.paper,
    required this.onImage,
    required this.onRemove,
  });

  final String id;

  /// The chosen image (stock, photo or older artwork), if any.
  final String? imageKey;

  /// The chosen paper color, shown behind and around the artwork.
  final Color paper;
  final ValueChanged<String> onImage;
  final VoidCallback onRemove;

  @override
  ConsumerState<NoteArtworkSection> createState() => _NoteArtworkSectionState();
}

class _NoteArtworkSectionState extends ConsumerState<NoteArtworkSection> {
  bool _picking = false;
  String? _error;

  Future<void> _browse() async {
    setState(() => _error = null);
    final path = await context.push<String>(
      noteBackgroundSearchLocation(widget.id),
    );
    if (path != null && mounted) widget.onImage(path);
  }

  Future<void> _photo() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await ref.read(noteMediaStoreProvider).pickPhoto(widget.id);
      if (photo != null && mounted) widget.onImage(photo.path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your photos could not be opened. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Artwork',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _Canvas(
          imageKey: widget.imageKey,
          paper: widget.paper,
          onRemove: widget.onRemove,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ArtChip(
              key: const ValueKey('note-artwork-browse'),
              icon: Icons.image_search_rounded,
              label: 'Browse photos',
              tint: theme.colorScheme.tertiary,
              onTap: _browse,
            ),
            _ArtChip(
              icon: Icons.photo_library_outlined,
              label: 'Your photo',
              tint: theme.colorScheme.primary,
              onTap: _picking ? null : _photo,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The note as a small upright page (the artwork's 2:3 shape), with what is
/// happening to it and what can be done beside it.
class _Canvas extends ConsumerWidget {
  const _Canvas({
    required this.imageKey,
    required this.paper,
    required this.onRemove,
  });

  final String? imageKey;
  final Color paper;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policy = context
        .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
        ?.policy;
    final duration = policy?.duration ?? Duration.zero;
    final simple = policy?.simplerEffects ?? false;
    final ink = ThemeData.estimateBrightnessForColor(paper) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final key = imageKey;
    final loaded = key == null
        ? null
        : ref.watch(noteBackgroundImageProvider(key));
    final image = loaded?.value;
    final missing =
        loaded != null && (loaded.hasError || loaded.hasValue && image == null);

    final Widget page;
    if (image != null) {
      page = Image(
        key: ValueKey(key),
        image: image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      // A few faint lines of writing, so the paper reads as a note page.
      page = Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in const [.7, 1.0, .9, 1.0, .6])
              FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final (title, detail) = key == null
        ? ('No artwork yet', 'Browse photos, or use one of your own.')
        : missing
        ? ('Image unavailable', 'Choose another.')
        : ('Artwork ready', 'Apply to set it behind your note.');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: duration,
          width: 104,
          height: 156,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .6),
            ),
            boxShadow: simple
                ? null
                : [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: .12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: AnimatedSwitcher(duration: duration, child: page),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (key != null)
                  TextButton.icon(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Remove artwork'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded pill with a tinted badge.
class _ArtChip extends StatelessWidget {
  const _ArtChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Lift the hue in dark mode so the badge stays legible.
    final hue = scheme.brightness == Brightness.dark
        ? Color.lerp(tint, Colors.white, .35)!
        : tint;
    return Semantics(
      button: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .5 : 1,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: hue),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
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
