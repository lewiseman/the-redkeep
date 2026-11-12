import '../../../core/presentation/rendering_policy.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _NoteAction { pin, background, tags, scan, delete }

/// An anchored menu that dismisses before dispatching a note action.
class NoteActionsMenu extends StatelessWidget {
  const NoteActionsMenu({
    super.key,
    required this.isPinned,
    required this.onTogglePin,
    required this.onBackground,
    required this.onTags,
    required this.onScan,
    required this.onDelete,
    this.style,
  });

  final bool isPinned;
  final VoidCallback? onTogglePin;
  final VoidCallback? onBackground;
  final VoidCallback? onTags;

  /// Opens the scan page: a photographed page becomes words in the note.
  final VoidCallback? onScan;
  final VoidCallback? onDelete;

  /// Replaces the button's default surface style, e.g. to match a coloured bar.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final width = math.min(
      288.0,
      math.max(0.0, media.size.width - media.padding.horizontal - 32),
    );

    return PopupMenuButton<_NoteAction>(
      tooltip: 'Note actions',
      icon: const Icon(Icons.more_vert_rounded),
      style:
          style ??
          IconButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            minimumSize: const Size.square(48),
          ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      requestFocus: true,
      constraints: BoxConstraints.tightFor(width: width),
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: colors.shadow.withValues(alpha: .18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      menuPadding: const EdgeInsets.all(8),
      popUpAnimationStyle: AnimationStyle(
        duration: RenderingPolicyScope.of(context).duration,
        curve: Curves.easeOutCubic,
      ),
      onSelected: (action) {
        switch (action) {
          case _NoteAction.pin:
            onTogglePin?.call();
          case _NoteAction.background:
            onBackground?.call();
          case _NoteAction.tags:
            onTags?.call();
          case _NoteAction.scan:
            onScan?.call();
          case _NoteAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _NoteAction.pin,
          enabled: onTogglePin != null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ActionRow(
            icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            title: isPinned ? 'Unpin note' : 'Pin note',
            subtitle: isPinned
                ? 'Return to the collection'
                : 'Keep it at the top',
            highlighted: isPinned,
          ),
        ),
        PopupMenuItem(
          value: _NoteAction.background,
          enabled: onBackground != null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ActionRow(
            icon: Icons.palette_outlined,
            title: 'Background',
            subtitle: 'Color & artwork',
          ),
        ),
        PopupMenuItem<_NoteAction>(
          value: _NoteAction.tags,
          enabled: onTags != null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ActionRow(
            icon: Icons.sell_outlined,
            title: 'Edit tags',
            subtitle: 'Choose or create',
          ),
        ),
        PopupMenuItem<_NoteAction>(
          key: const ValueKey('note-action-scan'),
          value: _NoteAction.scan,
          enabled: onScan != null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ActionRow(
            icon: Icons.document_scanner_outlined,
            title: 'Scan a page',
            subtitle: 'Photo to written words',
          ),
        ),
        PopupMenuDivider(height: 16, color: colors.outlineVariant),
        PopupMenuItem(
          value: _NoteAction.delete,
          enabled: onDelete != null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ActionRow(
            icon: Icons.delete_outline_rounded,
            title: 'Delete note',
            subtitle: 'Move to Trash',
            destructive: true,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.highlighted = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool highlighted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final foreground = destructive
        ? colors.error
        : highlighted
        ? colors.primary
        : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: destructive
                          ? colors.error.withValues(alpha: .8)
                          : colors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
