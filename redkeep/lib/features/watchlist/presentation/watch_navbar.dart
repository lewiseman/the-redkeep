import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';

typedef WatchNavDestination = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  int badge,
});

/// The Watchlist's sections as the foot of a book: a paper strip stitched
/// along its spine edge, with a cloth ribbon marking the open section.
class WatchNavbar extends StatelessWidget {
  const WatchNavbar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<WatchNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _maxContentWidth = 560.0;
  static const _sidePadding = 12.0;
  static const ribbonWidth = 22.0;
  static const ribbonDepth = 14.0;

  void _select(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final simple = policy.simplerEffects;
    final duration = policy.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final compact = MediaQuery.textScalerOf(context).scale(14) > 24;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        gradient: simple
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.cloth, palette.paper],
              ),
        border: Border(top: BorderSide(color: palette.rule, width: .66)),
        boxShadow: simple
            ? null
            : [
                BoxShadow(
                  color: palette.ink.withValues(alpha: .06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
              child: Stack(
                children: [
                  // The binding's stitches, then the ribbon over them.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: selectedIndex.toDouble()),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        builder: (context, position, _) => CustomPaint(
                          painter: _BindingPainter(
                            position: position,
                            count: destinations.length,
                            stitch: palette.rule,
                            ribbon: palette.accent,
                            shade: simple ? null : palette.ink,
                            textDirection: Directionality.of(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Expanded(
                          child: _Destination(
                            destination: destinations[i],
                            selected: i == selectedIndex,
                            showLabel: !compact || i == selectedIndex,
                            onSelected: () => _select(i),
                          ),
                        ),
                    ],
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

class _Destination extends StatefulWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onSelected,
  });

  final WatchNavDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onSelected;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final reduced = RenderingPolicyScope.of(context).reducedMotion;
    final d = widget.destination;
    final color = widget.selected ? palette.ink : palette.muted;
    final badge = d.badge;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: badge > 0 ? '${d.label} tab, $badge waiting' : '${d.label} tab',
      onTap: widget.onSelected,
      excludeSemantics: true,
      child: InkWell(
        excludeFromSemantics: true,
        enableFeedback: false,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHighlightChanged: (pressed) {
          if (_pressed != pressed) setState(() => _pressed = pressed);
        },
        onTap: widget.onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            4,
            WatchNavbar.ribbonDepth + 6,
            4,
            4,
          ),
          child: AnimatedScale(
            scale: _pressed ? .94 : 1,
            duration: reduced
                ? Duration.zero
                : Duration(milliseconds: _pressed ? 70 : 140),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  // Beside the icon, clear of the ribbon above it.
                  offset: const Offset(8, 4),
                  child: Icon(
                    widget.selected ? d.selectedIcon : d.icon,
                    color: color,
                    size: 24,
                  ),
                ),
                if (widget.showLabel) ...[
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    style: DiaryTypography.of(context).body.copyWith(
                      color: color,
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontStyle: widget.selected
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    child: Text(
                      d.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stitches along the top edge and a ribbon bookmark hanging from it.
class _BindingPainter extends CustomPainter {
  const _BindingPainter({
    required this.position,
    required this.count,
    required this.stitch,
    required this.ribbon,
    required this.shade,
    required this.textDirection,
  });

  final double position;
  final int count;
  final Color stitch;
  final Color ribbon;

  /// Null under simpler effects: no shadow under the ribbon.
  final Color? shade;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0 || size.width <= 0) return;
    // Running stitch, a little below the edge.
    final thread = Paint()
      ..color = stitch
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const y = 5.0;
    for (var x = 2.0; x < size.width - 2; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 4.5, y), thread);
    }

    final item = size.width / count;
    final visual = textDirection == TextDirection.rtl
        ? count - 1 - position
        : position;
    final center = item * (visual + .5);
    const w = WatchNavbar.ribbonWidth;
    const depth = WatchNavbar.ribbonDepth;
    final path = Path()
      ..moveTo(center - w / 2, 0)
      ..lineTo(center + w / 2, 0)
      ..lineTo(center + w / 2, depth)
      ..lineTo(center, depth - 5)
      ..lineTo(center - w / 2, depth)
      ..close();
    final shade = this.shade;
    if (shade != null) {
      canvas.drawShadow(path, shade.withValues(alpha: .5), 1.5, false);
    }
    canvas.drawPath(path, Paint()..color = ribbon);
    // A fold catching the light along the ribbon's edges.
    canvas.drawLine(
      Offset(center - w / 2 + 2.5, 0),
      Offset(center - w / 2 + 2.5, depth - 2),
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BindingPainter old) =>
      position != old.position ||
      count != old.count ||
      stitch != old.stitch ||
      ribbon != old.ribbon ||
      shade != old.shade ||
      textDirection != old.textDirection;
}
