import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../core/presentation/rendering_policy.dart';
import '../features/assets/presentation/local_artwork.dart';

const _destinations = [
  (
    label: 'Diary',
    image: 'navigation.diary.inactive',
    selectedImage: 'navigation.diary.active',
  ),
  (
    label: 'Notes',
    image: 'navigation.notes.inactive',
    selectedImage: 'navigation.notes.active',
  ),
  (
    label: 'More',
    image: 'navigation.more.inactive',
    selectedImage: 'navigation.more.active',
  ),
];

/// A compact, stuffed paper capsule. Resting tabs show only their artwork;
/// the active tab opens into a glassy gel chip with its name beside the icon,
/// and the gel flows from tab to tab when the selection changes.
///
/// Painting and layout are split for speed. The body (shadows, grain,
/// stitching) keeps one size, so it is painted once into its own layer and
/// only redraws when the theme changes. During a tab change the slots move by
/// relayout and the chip by repaint, with no rebuilds, blurs or backdrop
/// sampling.
class RedkeepBottomNavbar extends StatefulWidget {
  const RedkeepBottomNavbar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Space around the floating capsule; content shows through it.
  static const _margin = EdgeInsets.fromLTRB(14, 0, 14, 10);

  static Iterable<String> visibleArtworkKeys(int selectedIndex) sync* {
    for (var index = 0; index < _destinations.length; index++) {
      final destination = _destinations[index];
      yield index == selectedIndex
          ? destination.selectedImage
          : destination.image;
    }
  }

  @override
  State<RedkeepBottomNavbar> createState() => _RedkeepBottomNavbarState();
}

/// Sizes for the bar at the current text scale. Every resting tab is an
/// icon-sized slot and the active one is wide enough for the longest name, so
/// the bar keeps one width whichever tab is selected.
@immutable
class _NavMetrics {
  const _NavMetrics({required this.labelWidth, required this.height});

  static const icon = 44.0;
  static const slotPadding = 14.0;
  static const labelGap = 8.0;
  static const verticalPadding = 12.0;
  static const barPadding = 4.0;
  static const beadGap = 2.0;

  static int get count => _destinations.length;

  final double labelWidth;
  final double height;

  double get restingWidth => icon + 2 * slotPadding;
  double get activeWidth => restingWidth + labelGap + labelWidth;
  double get width => 2 * barPadding + restingWidth * (count - 1) + activeWidth;

  static TextStyle labelStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.copyWith(
        fontSize: 14,
        height: 1.2,
        letterSpacing: .2,
        fontWeight: FontWeight.w700,
      );

  /// Measures the names as they will be drawn, then trims the chip to fit
  /// narrow screens; a trimmed name ends in an ellipsis.
  static _NavMetrics of(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    var labelWidth = 0.0;
    var lineHeight = 0.0;
    for (final destination in _destinations) {
      final painter = TextPainter(
        text: TextSpan(text: destination.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width.ceilToDouble());
      lineHeight = math.max(lineHeight, painter.height);
      painter.dispose();
    }
    final available =
        MediaQuery.sizeOf(context).width -
        RedkeepBottomNavbar._margin.horizontal -
        MediaQuery.paddingOf(context).horizontal;
    final room =
        available -
        2 * barPadding -
        (icon + 2 * slotPadding) * count -
        labelGap;
    return _NavMetrics(
      labelWidth: labelWidth.clamp(0, math.max(0, room)).toDouble(),
      height: math.max(icon, lineHeight) + 2 * verticalPadding,
    );
  }

  List<double> widthsFor(int selected) => [
    for (var index = 0; index < count; index++)
      index == selected ? activeWidth : restingWidth,
  ];

  /// A slot's start edge, measured from the bar's start in reading order.
  static double slotStart(List<double> widths, int index) {
    var start = barPadding;
    for (var i = 0; i < index; i++) {
      start += widths[i];
    }
    return start;
  }

  static (double, double) beadFor(List<double> widths, int index) {
    final start = slotStart(widths, index);
    return (start + beadGap, start + widths[index] - beadGap);
  }

  @override
  bool operator ==(Object other) =>
      other is _NavMetrics &&
      other.labelWidth == labelWidth &&
      other.height == height;

  @override
  int get hashCode => Object.hash(labelWidth, height);
}

/// The gel's motion. Its leading end races ahead and its trailing end catches
/// up with a small rebound, so the chip stretches like a drop and settles with
/// a wobble, while the slots underneath ease open and closed.
abstract final class _Liquid {
  static const _lead = Interval(0, .6, curve: Curves.easeOutCubic);
  static const _trail = Interval(.12, 1, curve: Cubic(.45, 0, .25, 1.3));
  static const _slots = Curves.easeInOutCubic;

  static (double, double) bead(
    (double, double) from,
    (double, double) to,
    double t,
  ) {
    final lead = _lead.transform(t);
    final trail = _trail.transform(t);
    final forward = to.$1 + to.$2 >= from.$1 + from.$2;
    return (
      ui.lerpDouble(from.$1, to.$1, forward ? trail : lead)!,
      ui.lerpDouble(from.$2, to.$2, forward ? lead : trail)!,
    );
  }

  static double settled(double from, double to, double t) =>
      ui.lerpDouble(from, to, _slots.transform(t))!;

  static List<double> widths(List<double> from, List<double> to, double t) => [
    for (var index = 0; index < to.length; index++)
      settled(from[index], to[index], t),
  ];
}

class _RedkeepBottomNavbarState extends State<RedkeepBottomNavbar>
    with TickerProviderStateMixin {
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  late final _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  );

  _NavMetrics? _metrics;
  List<double> _fromWidths = const [];
  List<double> _toWidths = const [];
  (double, double) _fromBead = (0, 0);
  (double, double) _toBead = (0, 0);
  int? _pressedIndex;
  bool _reduced = false;

  @override
  void didUpdateWidget(RedkeepBottomNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final metrics = _metrics;
    if (metrics == null || oldWidget.selectedIndex == widget.selectedIndex) {
      return;
    }
    // Start from wherever the gel is now, so quick taps stay continuous.
    final t = _move.value;
    _fromWidths = _Liquid.widths(_fromWidths, _toWidths, t);
    _fromBead = _Liquid.bead(_fromBead, _toBead, t);
    _toWidths = metrics.widthsFor(widget.selectedIndex);
    _toBead = _NavMetrics.beadFor(_toWidths, widget.selectedIndex);
    if (RenderingPolicyScope.of(context).reducedMotion) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _squish.dispose();
    super.dispose();
  }

  /// Text scale or screen width changed: lay out afresh without animating.
  void _settle(_NavMetrics metrics) {
    _metrics = metrics;
    _toWidths = metrics.widthsFor(widget.selectedIndex);
    _fromWidths = _toWidths;
    _toBead = _NavMetrics.beadFor(_toWidths, widget.selectedIndex);
    _fromBead = _toBead;
    if (_move.isAnimating || _move.value != 1) _move.value = 1;
  }

  void _select(int index) {
    if (index == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  void _pressed(int index, bool pressed) {
    if (pressed) {
      setState(() => _pressedIndex = index);
      if (_reduced) {
        _squish.value = 1;
      } else {
        _squish.forward();
      }
    } else if (_pressedIndex == index) {
      if (_reduced) {
        _squish.value = 0;
      } else {
        _squish.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    _reduced = policy.reducedMotion;
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final textDirection = Directionality.of(context);
    final labelStyle = _NavMetrics.labelStyle(context);
    final metrics = _NavMetrics.of(context, labelStyle);
    if (metrics != _metrics) _settle(metrics);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: RedkeepBottomNavbar._margin,
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: metrics.width,
            height: metrics.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        isComplex: true,
                        painter: _CushionPainter(
                          paper: colors.surfaceContainerLow,
                          ink: colors.onSurface,
                          edge: colors.outlineVariant,
                          shadow: colors.shadow,
                          dark: dark,
                          simple: policy.simplerEffects,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _BeadPainter(
                          move: _move,
                          squish: _squish,
                          fromBead: _fromBead,
                          toBead: _toBead,
                          fromWidths: _fromWidths,
                          toWidths: _toWidths,
                          selectedIndex: widget.selectedIndex,
                          pressedIndex: _pressedIndex,
                          textDirection: textDirection,
                          accent: colors.primary,
                          paper: colors.surfaceContainerLow,
                          ink: colors.onSurface,
                          shadow: colors.shadow,
                          dark: dark,
                          simple: policy.simplerEffects,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomMultiChildLayout(
                    delegate: _SlotLayout(
                      move: _move,
                      fromWidths: _fromWidths,
                      toWidths: _toWidths,
                      textDirection: textDirection,
                    ),
                    children: [
                      for (var index = 0; index < _destinations.length; index++)
                        LayoutId(
                          id: index,
                          child: _NavigationDestination(
                            label: _destinations[index].label,
                            image: _destinations[index].image,
                            selectedImage: _destinations[index].selectedImage,
                            selected: index == widget.selectedIndex,
                            labelStyle: labelStyle.copyWith(
                              color: colors.primary,
                            ),
                            labelWidth: metrics.labelWidth,
                            onSelected: () => _select(index),
                            onPressed: (pressed) => _pressed(index, pressed),
                          ),
                        ),
                    ],
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

/// Places the slots side by side at their in-between widths for the current
/// frame. Only layout runs while the chip opens; nothing rebuilds.
class _SlotLayout extends MultiChildLayoutDelegate {
  _SlotLayout({
    required this.move,
    required this.fromWidths,
    required this.toWidths,
    required this.textDirection,
  }) : super(relayout: move);

  final Animation<double> move;
  final List<double> fromWidths;
  final List<double> toWidths;
  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    final widths = _Liquid.widths(fromWidths, toWidths, move.value);
    var start = _NavMetrics.barPadding;
    for (var index = 0; index < widths.length; index++) {
      final width = widths[index];
      layoutChild(index, BoxConstraints.tight(Size(width, size.height)));
      positionChild(
        index,
        Offset(
          textDirection == TextDirection.rtl
              ? size.width - start - width
              : start,
          0,
        ),
      );
      start += width;
    }
  }

  @override
  bool shouldRelayout(_SlotLayout oldDelegate) =>
      move != oldDelegate.move ||
      fromWidths != oldDelegate.fromWidths ||
      toWidths != oldDelegate.toWidths ||
      textDirection != oldDelegate.textDirection;
}

class _NavigationDestination extends StatefulWidget {
  const _NavigationDestination({
    required this.label,
    required this.image,
    required this.selectedImage,
    required this.selected,
    required this.labelStyle,
    required this.labelWidth,
    required this.onSelected,
    required this.onPressed,
  });

  final String label;
  final String image;
  final String selectedImage;
  final bool selected;
  final TextStyle labelStyle;
  final double labelWidth;
  final VoidCallback onSelected;
  final ValueChanged<bool> onPressed;

  @override
  State<_NavigationDestination> createState() => _NavigationDestinationState();
}

class _NavigationDestinationState extends State<_NavigationDestination> {
  bool _pressed = false;

  void _highlight(bool pressed) {
    widget.onPressed(pressed);
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = RenderingPolicyScope.of(context).reducedMotion;
    final labelColor = widget.labelStyle.color!;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: '${widget.label} tab',
      onTap: widget.onSelected,
      excludeSemantics: true,
      child: InkWell(
        excludeFromSemantics: true,
        enableFeedback: false,
        customBorder: const StadiumBorder(),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHighlightChanged: _highlight,
        onTap: widget.onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _NavMetrics.slotPadding,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: _NavMetrics.icon,
                child: AnimatedScale(
                  scale: _pressed ? .9 : 1,
                  duration: reduced
                      ? Duration.zero
                      : Duration(milliseconds: _pressed ? 70 : 160),
                  curve: Curves.easeOutCubic,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: widget.selected ? 1 : 0),
                    duration: reduced
                        ? Duration.zero
                        : Duration(milliseconds: widget.selected ? 420 : 200),
                    curve: widget.selected
                        ? Curves.easeOutBack
                        : Curves.easeOutCubic,
                    // A sticker being pressed down: a small tilt that rights
                    // itself, and a pop as the chip opens.
                    builder: (context, selection, child) => Transform.rotate(
                      angle:
                          (widget.selected ? -.16 : .1) *
                          math.sin(math.pi * selection.clamp(0, 1)),
                      child: Transform.scale(
                        scale: .9 + .14 * selection,
                        child: child,
                      ),
                    ),
                    // Mount both states ahead of selection to keep the
                    // artwork available throughout the pop and crossfade.
                    child: AnimatedCrossFade(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      firstCurve: Curves.easeOutCubic,
                      secondCurve: Curves.easeOutCubic,
                      crossFadeState: widget.selected
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: LocalArtwork(
                        assetKey: widget.image,
                        dimension: _NavMetrics.icon,
                      ),
                      secondChild: LocalArtwork(
                        assetKey: widget.selectedImage,
                        dimension: _NavMetrics.icon,
                      ),
                    ),
                  ),
                ),
              ),
              // The name sits under the slot's edge and is uncovered as the
              // chip opens, fading in behind it.
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: 0,
                    maxWidth: _NavMetrics.labelGap + widget.labelWidth,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: _NavMetrics.labelGap,
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: widget.selected ? 1 : 0),
                        duration: reduced
                            ? Duration.zero
                            : Duration(
                                milliseconds: widget.selected ? 520 : 140,
                              ),
                        curve: widget.selected
                            ? const Interval(.55, 1, curve: Curves.easeOut)
                            : Curves.easeIn,
                        builder: (context, reveal, _) => Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: widget.labelStyle.copyWith(
                            color: labelColor.withValues(
                              alpha: labelColor.a * reveal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeadPainter extends CustomPainter {
  _BeadPainter({
    required this.move,
    required this.squish,
    required this.fromBead,
    required this.toBead,
    required this.fromWidths,
    required this.toWidths,
    required this.selectedIndex,
    required this.pressedIndex,
    required this.textDirection,
    required this.accent,
    required this.paper,
    required this.ink,
    required this.shadow,
    required this.dark,
    required this.simple,
  }) : super(repaint: Listenable.merge([move, squish]));

  final Animation<double> move;
  final Animation<double> squish;
  final (double, double) fromBead;
  final (double, double) toBead;
  final List<double> fromWidths;
  final List<double> toWidths;
  final int selectedIndex;
  final int? pressedIndex;
  final TextDirection textDirection;
  final Color accent;
  final Color paper;
  final Color ink;
  final Color shadow;
  final bool dark;
  final bool simple;

  static const _inset = 5.0;

  /// Reading-order edges to canvas edges, mirrored for right-to-left.
  (double, double) _visual(double start, double end, double width) =>
      textDirection == TextDirection.rtl
      ? (width - end, width - start)
      : (start, end);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 2 * _inset || toWidths.isEmpty) {
      return;
    }
    final t = move.value;
    final depth = squish.value;

    final pressed = pressedIndex;
    if (pressed != null && pressed != selectedIndex && depth > 0) {
      _paintDent(canvas, size, pressed, t, depth);
    }

    final (start, end) = _Liquid.bead(fromBead, toBead, t);
    var (left, right) = _visual(
      math.max(start, _NavMetrics.barPadding),
      math.min(end, size.width - _NavMetrics.barPadding),
      size.width,
    );
    // Stretched gel thins out and compressed gel swells, as a drop would.
    final nominal = _Liquid.settled(
      fromBead.$2 - fromBead.$1,
      toBead.$2 - toBead.$1,
      t,
    );
    final stretch = nominal <= 0
        ? 0.0
        : (((end - start) - nominal) / nominal).clamp(-.35, 1.0);
    final squishing = pressed == selectedIndex ? depth : 0.0;
    left -= 3 * squishing;
    right += 3 * squishing;
    final inset = math.min(
      math.max(2.0, _inset + 5 * stretch + 2.5 * squishing),
      size.height / 2 - 4,
    );
    final top = inset + squishing;
    final bottom = size.height - inset + squishing * .5;
    if (right <= left || bottom <= top) return;
    final bead = RRect.fromLTRBR(
      left,
      top,
      right,
      bottom,
      Radius.circular((bottom - top) / 2),
    );

    final body = Color.alphaBlend(
      accent.withValues(alpha: dark ? .24 : .14),
      paper,
    );
    if (simple) {
      canvas.drawRRect(bead, Paint()..color = body);
      canvas.drawRRect(
        bead,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: .35),
      );
      return;
    }

    // Crisp, stacked offsets read as a cut-paper shadow with no blur.
    final lift = 1 - squishing;
    canvas.drawRRect(
      bead.shift(Offset(0, 1 + 2.5 * lift)),
      Paint()..color = shadow.withValues(alpha: dark ? .22 : .05),
    );
    canvas.drawRRect(
      bead.shift(Offset(0, .5 + 1 * lift)),
      Paint()..color = shadow.withValues(alpha: dark ? .38 : .1),
    );

    // Pillow loft: light pools high on the cushion, the hem falls into shade.
    final rect = bead.outerRect;
    canvas.drawRRect(
      bead,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.9),
          radius: 1.2,
          colors: [
            Color.lerp(body, Colors.white, dark ? .14 : .62)!,
            body,
            Color.lerp(body, Colors.black, dark ? .22 : .07)!,
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );

    // Liquid-glass specular band across the crown.
    final band = RRect.fromLTRBR(
      rect.left + rect.height * .32,
      rect.top + 2,
      rect.right - rect.height * .32,
      rect.top + rect.height * .4,
      Radius.circular(rect.height * .2),
    );
    if (band.width > 0) {
      canvas.drawRRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? .2 : .7),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(band.outerRect),
      );
    }

    // Glass rim: a bright lip above and accent light refracted at the base.
    canvas.drawRRect(
      bead.deflate(.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? .32 : .95),
            Colors.white.withValues(alpha: 0),
            accent.withValues(alpha: 0),
            Color.lerp(
              accent,
              Colors.white,
              dark ? .35 : 0,
            )!.withValues(alpha: dark ? .6 : .42),
          ],
          stops: const [0, .42, .62, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      bead,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = accent.withValues(alpha: dark ? .4 : .26),
    );
  }

  /// A resting tab under a finger presses a soft dimple into the paper.
  void _paintDent(Canvas canvas, Size size, int index, double t, double depth) {
    final widths = _Liquid.widths(fromWidths, toWidths, t);
    final start = _NavMetrics.slotStart(widths, index) + 4;
    final (left, right) = _visual(start, start + widths[index] - 8, size.width);
    final top = _inset + 2;
    final bottom = size.height - _inset - 2;
    final dent = RRect.fromLTRBR(
      left,
      top,
      right,
      bottom,
      Radius.circular((bottom - top) / 2),
    );
    canvas.drawRRect(
      dent,
      Paint()..color = ink.withValues(alpha: (dark ? .07 : .045) * depth),
    );
    if (simple) return;
    canvas.drawRRect(
      dent.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shadow.withValues(alpha: (dark ? .45 : .14) * depth),
            shadow.withValues(alpha: 0),
            Colors.white.withValues(alpha: (dark ? .06 : .55) * depth),
          ],
          stops: const [0, .5, 1],
        ).createShader(dent.outerRect),
    );
  }

  @override
  bool shouldRepaint(covariant _BeadPainter old) =>
      move != old.move ||
      squish != old.squish ||
      fromBead != old.fromBead ||
      toBead != old.toBead ||
      fromWidths != old.fromWidths ||
      toWidths != old.toWidths ||
      selectedIndex != old.selectedIndex ||
      pressedIndex != old.pressedIndex ||
      textDirection != old.textDirection ||
      accent != old.accent ||
      paper != old.paper ||
      ink != old.ink ||
      shadow != old.shadow ||
      dark != old.dark ||
      simple != old.simple;
}

/// The capsule's body: a paper pillow, lofted in the middle, stitched around
/// its hem, with a glassy lip. Painted once per theme into a cached layer.
class _CushionPainter extends CustomPainter {
  const _CushionPainter({
    required this.paper,
    required this.ink,
    required this.edge,
    required this.shadow,
    required this.dark,
    required this.simple,
  });

  final Color paper;
  final Color ink;
  final Color edge;
  final Color shadow;
  final bool dark;
  final bool simple;

  static const _stitchInset = 7.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final body = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );

    if (simple) {
      canvas.drawRRect(body, Paint()..color = paper);
      _paintHairline(canvas, body);
      return;
    }

    // Two shadows: a wide, soft settle and a tight contact line.
    canvas.drawRRect(
      body.shift(const Offset(0, 9)).deflate(4),
      Paint()
        ..color = shadow.withValues(alpha: dark ? .5 : .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1.5)),
      Paint()
        ..color = shadow.withValues(alpha: dark ? .45 : .1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Puffed body: brighter crown, shaded hem.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(paper, Colors.white, dark ? .06 : .6)!,
            paper,
            Color.lerp(paper, Colors.black, dark ? .2 : .05)!,
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(body);
    _paintLoft(canvas, size);
    _paintGrain(canvas, size);
    canvas.restore();

    _paintStitches(canvas, body.deflate(_stitchInset));

    // Glassy lip: a bright top edge fading out, with bounce light underneath.
    canvas.drawRRect(
      body.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? .2 : .95),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: dark ? .05 : .4),
          ],
          stops: const [0, .38, .78, 1],
        ).createShader(rect),
    );
    _paintHairline(canvas, body);
  }

  void _paintHairline(Canvas canvas, RRect body) {
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = edge.withValues(alpha: dark ? .9 : .75),
    );
  }

  /// An elliptical pool of light, the high point of the cushion.
  void _paintLoft(Canvas canvas, Size size) {
    final radius = size.height;
    canvas.save();
    canvas.translate(size.width / 2, size.height * .1);
    canvas.scale(size.width * .55 / radius, 1);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: dark ? .05 : .38),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  /// Paper tooth: specks and short fibres from a fixed seed, so the grain is
  /// identical on every repaint. Two draw calls in all.
  void _paintGrain(Canvas canvas, Size size) {
    final random = math.Random(19);
    final specks = (size.width * size.height / 60).clamp(0, 1200).round();
    final points = Float32List(specks * 2);
    for (var i = 0; i < specks; i++) {
      points[i * 2] = random.nextDouble() * size.width;
      points[i * 2 + 1] = random.nextDouble() * size.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: dark ? .05 : .04),
    );

    final fibres = Path();
    final count = (size.width / 7).round();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final angle = (random.nextDouble() - .5) * 1.2;
      final length = 3 + random.nextDouble() * 7;
      fibres
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + math.cos(angle) * length * .5,
          y + math.sin(angle) * length * .5 + (random.nextDouble() - .5) * 2,
          x + math.cos(angle) * length,
          y + math.sin(angle) * length,
        );
    }
    canvas.drawPath(
      fibres,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55
        ..color = ink.withValues(alpha: dark ? .07 : .055),
    );
  }

  /// A running stitch around the hem, with a light catch on each thread.
  void _paintStitches(Canvas canvas, RRect hem) {
    if (hem.width <= 0 || hem.height <= 0) return;
    final outline = Path()..addRRect(hem);
    final stitches = Path();
    const dash = 4.5;
    const gap = 3.5;
    for (final metric in outline.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        stitches.addPath(
          metric.extractPath(distance, distance + dash),
          Offset.zero,
        );
      }
    }
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;
    canvas.drawPath(
      stitches.shift(const Offset(0, .8)),
      thread..color = Colors.white.withValues(alpha: dark ? .05 : .7),
    );
    canvas.drawPath(
      stitches,
      thread..color = edge.withValues(alpha: dark ? .75 : .9),
    );
  }

  @override
  bool shouldRepaint(covariant _CushionPainter old) =>
      paper != old.paper ||
      ink != old.ink ||
      edge != old.edge ||
      shadow != old.shadow ||
      dark != old.dark ||
      simple != old.simple;
}
