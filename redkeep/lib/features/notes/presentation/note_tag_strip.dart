import '../../../core/presentation/rendering_policy.dart';

import 'package:flutter/material.dart';

/// A horizontally scrolling row of collection chips, ordered Pinned, All,
/// user tags, then Trash.
class NoteTagStrip extends StatefulWidget {
  const NoteTagStrip({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
  });

  /// Values for the built-in collections. The NUL prefix keeps them from
  /// colliding with user tags of the same name.
  static const all = 'All';
  static const pinned = '\u0000pinned';
  static const trash = '\u0000trash';

  final List<({String emoji, String name, String value})> tags;

  /// [tags] in display order: Pinned, All, the user tags in their given
  /// order, then Trash last.
  static List<T> arrange<T extends ({String emoji, String name, String value})>(
    List<T> tags,
  ) {
    const builtIn = {pinned, all, trash};
    return [
      ...tags.where((tag) => tag.value == pinned),
      ...tags.where((tag) => tag.value == all),
      ...tags.where((tag) => !builtIn.contains(tag.value)),
      ...tags.where((tag) => tag.value == trash),
    ];
  }

  final String selectedTag;
  final ValueChanged<String> onSelected;

  @override
  State<NoteTagStrip> createState() => _NoteTagStripState();
}

class _NoteTagStripState extends State<NoteTagStrip> {
  final _scroll = ScrollController();
  static const _fadeWidth = 48.0;
  final _fade = ValueNotifier<({double left, double right})>((
    left: 0,
    right: 0,
  ));

  @override
  void dispose() {
    _scroll.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _updateTagFade(ScrollMetrics metrics) {
    final before = (metrics.extentBefore / _fadeWidth).clamp(0.0, 1.0);
    final after = (metrics.extentAfter / _fadeWidth).clamp(0.0, 1.0);
    _fade.value = metrics.axisDirection == AxisDirection.right
        ? (left: before, right: after)
        : (left: after, right: before);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _updateTagFade(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _updateTagFade(notification.metrics);
          return false;
        },
        child: ValueListenableBuilder<({double left, double right})>(
          valueListenable: _fade,
          builder: (context, fade, child) =>
              RenderingPolicyScope.of(context).simplerEffects
              ? child!
              : ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    final width = bounds.width > 0
                        ? (_fadeWidth / bounds.width).clamp(0.0, .5)
                        : 0.0;
                    const ramp = [0.0, .25, .5, .75, 1.0];
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        for (final t in ramp)
                          Colors.black.withValues(
                            alpha:
                                1 -
                                fade.left * (1 - Curves.easeInOut.transform(t)),
                          ),
                        for (final t in ramp.reversed)
                          Colors.black.withValues(
                            alpha:
                                1 -
                                fade.right *
                                    (1 - Curves.easeInOut.transform(t)),
                          ),
                      ],
                      stops: [
                        for (final t in ramp) t * width,
                        for (final t in ramp.reversed) 1 - t * width,
                      ],
                    ).createShader(bounds);
                  },
                  child: child,
                ),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(
              left: 17,
              top: 4,
              right: 17,
              bottom: 6,
            ),
            child: Row(
              children: [
                for (final tag in NoteTagStrip.arrange(widget.tags))
                  Padding(
                    key: ValueKey(switch (tag.value) {
                      NoteTagStrip.all => 'notes-all',
                      NoteTagStrip.pinned => 'notes-pinned',
                      NoteTagStrip.trash => 'notes-trash',
                      _ => 'notes-tag-${tag.value}',
                    }),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      selected: widget.selectedTag == tag.value,
                      showCheckmark: false,
                      avatar: Text(tag.emoji),
                      label: Text(tag.name),
                      labelStyle: TextStyle(
                        color: widget.selectedTag == tag.value
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: widget.selectedTag == tag.value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      backgroundColor: Colors.transparent,
                      selectedColor: colors.primary,
                      side: BorderSide(
                        color: widget.selectedTag == tag.value
                            ? colors.primary.withValues(alpha: .5)
                            : colors.outlineVariant,
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      onSelected: (_) => widget.onSelected(tag.value),
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
