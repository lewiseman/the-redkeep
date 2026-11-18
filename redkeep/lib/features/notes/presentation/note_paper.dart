import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import 'note_scene.dart';

import 'note_paper_surface.dart';

export 'note_paper_surface.dart' show NotePaperSurface;

/// Lets the page move the paper's scroll without replacing the scroll view.
class NotePaperController extends ChangeNotifier {
  /// Scrolls to the note's end, e.g. to show words an AI tool just added.
  void revealEnd() => notifyListeners();
}

/// The note's paper: one flat sheet filling the page, scrolling with its
/// writing. Reading and editing share it, so switching keeps its position.
class NotePaper extends StatefulWidget {
  const NotePaper({
    super.key,
    required this.color,
    required this.children,
    this.controller,
    this.bottomPadding = 0,
  });

  final Color color;
  final List<Widget> children;
  final NotePaperController? controller;

  /// Extra room below the content, e.g. for tools floating over the paper.
  final double bottomPadding;

  @override
  State<NotePaper> createState() => _NotePaperState();
}

class _NotePaperState extends State<NotePaper> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_revealEnd);
  }

  @override
  void didUpdateWidget(covariant NotePaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_revealEnd);
      widget.controller?.addListener(_revealEnd);
    }
  }

  void _revealEnd() {
    // Let the new writing lay out its extent first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (!RenderingPolicyScope.of(context).animate) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_revealEnd);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4;
    final side = compact ? 16.0 : 24.0;
    return Stack(
      key: const ValueKey('note-paper-content'),
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: NotePaperOpacity.of(context),
          child: NotePaperSurface(color: widget.color),
        ),
        CustomScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                side,
                12,
                side,
                32 +
                    widget.bottomPadding +
                    MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverMainAxisGroup(slivers: widget.children),
            ),
          ],
        ),
      ],
    );
  }
}
