import '../../../core/presentation/rendering_policy.dart';

import 'package:flutter/material.dart';

/// Places All in the middle of the strip with the other chips alternating to
/// its right and left, centers the selected chip on initial load, then
/// preserves manual scrolling.
class NoteTagStrip extends StatefulWidget {
  const NoteTagStrip({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
    this.isLoading = false,
  });

  /// Values for the built-in collections. The NUL prefix keeps them from
  /// colliding with user tags of the same name.
  static const all = 'All';
  static const pinned = '\u0000pinned';
  static const trash = '\u0000trash';

  final List<({String emoji, String name, String value})> tags;

  /// [tags] in display order: All in the middle, the rest alternating right,
  /// left, right… outward from it so the earliest chips sit nearest All.
  static List<T> arrange<T extends ({String emoji, String name, String value})>(
    List<T> tags,
  ) {
    final left = <T>[];
    final right = <T>[];
    final others = tags.where((tag) => tag.value != all).toList();
    for (final (index, tag) in others.indexed) {
      (index.isEven ? right : left).add(tag);
    }
    return [
      ...left.reversed,
      ...tags.where((tag) => tag.value == all),
      ...right,
    ];
  }

  final String selectedTag;
  final ValueChanged<String> onSelected;
  final bool isLoading;

  @override
  State<NoteTagStrip> createState() => _NoteTagStripState();
}

class _NoteTagStripState extends State<NoteTagStrip> {
  final _scroll = ScrollController();
  final _selectedTagKey = GlobalKey();
  bool _initialTagCentered = false;
  bool _tagCenterScheduled = false;
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

  void _centerInitialTag() {
    if (_initialTagCentered || _tagCenterScheduled) return;
    _tagCenterScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tagCenterScheduled = false;
      if (!mounted || _initialTagCentered || !_scroll.hasClients) return;
      final target = _selectedTagKey.currentContext?.findRenderObject();
      if (target == null || !target.attached) return;
      _initialTagCentered = true;
      _scroll.position.ensureVisible(target, alignment: .5);
    });
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
    if (!widget.isLoading) _centerInitialTag();
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _updateTagFade(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _initialTagCentered = true;
            }
            _updateTagFade(notification.metrics);
          }
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 17,
                top: 4,
                right: 17,
                bottom: 6,
              ),
              // When every chip fits, keep the row centered on screen.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (constraints.maxWidth - 34).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          key: widget.selectedTag == tag.value
                              ? _selectedTagKey
                              : null,
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
                          onSelected: (_) {
                            _initialTagCentered = true;
                            widget.onSelected(tag.value);
                          },
                        ),
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
