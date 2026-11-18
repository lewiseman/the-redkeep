import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';

/// Hands the size of the bottom pill a note page is leaving (the reading
/// dock or the writing tools) to the pill that replaces it.
class NoteBottomMorphScope extends InheritedWidget {
  const NoteBottomMorphScope({
    super.key,
    required this.measure,
    required this.take,
    required super.child,
  });

  /// Marks the current pill's contents so the page can measure them.
  final GlobalKey measure;

  /// The size to grow from, once: later pills simply fade in.
  final Size? Function() take;

  static NoteBottomMorphScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NoteBottomMorphScope>();

  @override
  bool updateShouldNotify(NoteBottomMorphScope oldWidget) =>
      measure != oldWidget.measure;
}

/// The contents of a note page's bottom pill. Switching between reading and
/// writing reshapes one pill into the other: it resizes from the previous
/// contents' size while the new buttons fade in.
class NoteBottomMorph extends StatefulWidget {
  const NoteBottomMorph({super.key, required this.child});
  final Widget child;

  static const duration = Duration(milliseconds: 320);

  @override
  State<NoteBottomMorph> createState() => _NoteBottomMorphState();
}

class _NoteBottomMorphState extends State<NoteBottomMorph> {
  bool _started = false;
  Size? _from;
  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _animate = RenderingPolicyScope.of(context).animate;
    _from = NoteBottomMorphScope.maybeOf(context)?.take();
    if (_from != null && _animate) {
      // Lay out once at the old size, then resize to the new contents.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _from = null);
      });
    } else {
      _from = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final contents = KeyedSubtree(
      key: NoteBottomMorphScope.maybeOf(context)?.measure,
      child: widget.child,
    );
    if (!_animate) return contents;
    return AnimatedSize(
      duration: NoteBottomMorph.duration,
      curve: Curves.easeOutCubic,
      child: from != null
          ? SizedBox.fromSize(size: from)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: NoteBottomMorph.duration,
              curve: const Interval(.15, 1, curve: Curves.easeOut),
              child: contents,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
            ),
    );
  }
}
