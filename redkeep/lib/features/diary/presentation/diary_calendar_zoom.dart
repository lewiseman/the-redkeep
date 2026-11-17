import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'diary_calendar_overview.dart';
import 'diary_style.dart';

/// Where a zoom began: the month under the fingers (if any), how far down
/// the stage that month's region starts, and the stage's own size.
typedef DiaryZoomFocus = ({
  DateTime? month,
  double top,
  Offset point,
  Size size,
});

/// One lens as drawn at a moment of the zoom.
typedef DiaryZoomLayer = ({int depth, double scale, double opacity});

/// Calendar depth runs continuously from the year (0) to days (3). Each
/// whole step is a lens; between two steps both neighbours are drawn, the
/// shallower one swelling and fading as the deeper one grows into place.
abstract final class DiaryZoom {
  static const deepest = 3;

  /// Spreading the fingers this much moves one lens deeper.
  static const pinchPerLevel = 1.75;

  /// How much the shallower lens has grown when the deeper one arrives.
  static const growth = 1.6;

  /// Finger travel along the dial for one lens.
  static const dialPerLevel = 28.0;

  static double pinch(double start, double scale) => scale <= 0
      ? start
      : rubber(start + math.log(scale) / math.log(pinchPerLevel));

  /// Past the year or days the zoom resists, then springs back.
  static double rubber(double z) {
    double resist(double over) => .3 * over / (over + .6);
    if (z < 0) return -resist(-z);
    if (z > deepest) return deepest + resist(z - deepest);
    return z;
  }

  /// The lens a released zoom settles on. A small push past the lens it
  /// started from commits; a quick flick carries on in its direction.
  static int settle(double z, {required double start, double velocity = 0}) {
    final int target;
    if (velocity.abs() > 1.5) {
      target = velocity > 0 ? z.ceil() : z.floor();
    } else if (z > start + .001) {
      target = z - z.floor() > .2 ? z.ceil() : z.floor();
    } else if (z < start - .001) {
      target = z.ceil() - z > .2 ? z.floor() : z.ceil();
    } else {
      target = z.round();
    }
    return target.clamp(0, deepest);
  }

  static List<DiaryZoomLayer> layers(double z) {
    if (z <= 0) return [(depth: 0, scale: 1 + z * .25, opacity: 1)];
    if (z >= deepest) {
      return [(depth: deepest, scale: 1 + (z - deepest) * .25, opacity: 1)];
    }
    final floor = z.floor();
    final t = z - floor;
    if (t < 1e-3) return [(depth: floor, scale: 1, opacity: 1)];
    if (t > 1 - 1e-3) return [(depth: floor + 1, scale: 1, opacity: 1)];
    return [
      (
        depth: floor,
        scale: 1 + (growth - 1) * t,
        opacity: 1 - Curves.easeIn.transform((t / .7).clamp(0.0, 1.0)),
      ),
      (
        depth: floor + 1,
        scale: 1 / growth + (1 - 1 / growth) * Curves.easeOut.transform(t),
        opacity: Curves.easeOut.transform(((t - .3) / .7).clamp(0.0, 1.0)),
      ),
    ];
  }
}

/// One year's calendar, drawn at the shared zoom. At rest it holds only the
/// settled lens. While zooming it holds the two lenses either side, each
/// behind its own repaint boundary, so a frame of the zoom only re-composites
/// two transformed layers and never rebuilds or repaints the calendars.
class DiaryCalendarZoomStage extends StatefulWidget {
  const DiaryCalendarZoomStage({
    super.key,
    required this.zoom,
    required this.origin,
    required this.builder,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onAttach,
  });

  final ValueListenable<double> zoom;

  /// Stage-local point the lenses grow from; null zooms about the centre.
  final ValueGetter<Offset?> origin;
  final Widget Function(DiaryCalendarLens lens) builder;
  final ValueChanged<DiaryZoomFocus> onStart;
  final void Function(double scale, Duration time) onUpdate;
  final VoidCallback onEnd;
  final void Function(DiaryCalendarZoomStageState stage, bool attached)
  onAttach;

  @override
  State<DiaryCalendarZoomStage> createState() => DiaryCalendarZoomStageState();
}

class DiaryCalendarZoomStageState extends State<DiaryCalendarZoomStage> {
  final _views = <int, Widget>{};
  bool _pinching = false;

  @override
  void initState() {
    super.initState();
    widget.onAttach(this, true);
  }

  @override
  void didUpdateWidget(DiaryCalendarZoomStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _views.clear();
  }

  @override
  void dispose() {
    widget.onAttach(this, false);
    super.dispose();
  }

  /// The month drawn under [point], found through the calendars' own
  /// [DiaryCalendarAnchor] marks.
  DiaryZoomFocus focusAt(Offset point) {
    final box = context.findRenderObject()! as RenderBox;
    final result = BoxHitTestResult();
    if (box.hasSize) box.hitTest(result, position: point);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData &&
          target.metaData is DiaryCalendarAnchor &&
          target.attached) {
        return (
          month: (target.metaData as DiaryCalendarAnchor).month,
          top: target.localToGlobal(Offset.zero, ancestor: box).dy,
          point: point,
          size: box.size,
        );
      }
    }
    return (month: null, top: 0, point: point, size: box.size);
  }

  Offset get center {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return Offset(box.size.width / 2, box.size.height * .35);
  }

  void _start(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _pinching = true;
    widget.onStart(focusAt(details.localFocalPoint));
  }

  void _update(ScaleUpdateDetails details) {
    if (!_pinching) return;
    widget.onUpdate(details.scale, details.sourceTimeStamp ?? Duration.zero);
  }

  void _end(ScaleEndDetails details) {
    if (!_pinching) return;
    _pinching = false;
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _PinchRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
              () => _PinchRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..onStart = _start
                ..onUpdate = _update
                ..onEnd = _end,
            ),
      },
      child: ClipRect(
        child: ValueListenableBuilder<double>(
          valueListenable: widget.zoom,
          builder: (context, z, _) => _layers(z),
        ),
      ),
    );
  }

  Widget _layers(double z) {
    final layers = DiaryZoom.layers(z);
    final settled = layers.length == 1 && layers.single.scale == 1;
    final origin = widget.origin();
    _views.removeWhere((depth, _) => !layers.any((l) => l.depth == depth));
    return Stack(
      fit: StackFit.expand,
      children: [
        // The wrappers stay the same at rest and in motion, so a lens keeps
        // its scroll position and state from one to the other.
        for (final layer in layers)
          KeyedSubtree(
            key: ValueKey('calendar-zoom-layer-${layer.depth}'),
            child: IgnorePointer(
              ignoring: !settled,
              child: Opacity(
                opacity: layer.opacity,
                child: Transform.scale(
                  scale: layer.scale,
                  alignment: origin == null
                      ? Alignment.center
                      : Alignment.topLeft,
                  origin: origin,
                  child: RepaintBoundary(
                    child: _views.putIfAbsent(
                      layer.depth,
                      () =>
                          widget.builder(DiaryCalendarLens.values[layer.depth]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A scale recognizer that claims the gesture the moment a second finger
/// lands, before a list or the year pages can read the pinch as a scroll.
/// One finger alone never starts a zoom, so scrolling and taps are untouched.
class _PinchRecognizer extends ScaleGestureRecognizer {
  _PinchRecognizer({super.debugOwner});

  final _down = <int>{};

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerDownEvent) {
      _down.add(event.pointer);
      if (_down.length >= 2) resolve(GestureDisposition.accepted);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _down.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _down.clear();
    super.didStopTrackingLastPointer(pointer);
  }
}

/// A small dial beside search: four notches from the year to days, and a
/// bead that rides the zoom as it happens. Tapping steps one lens out (from
/// the year it dives back to days); dragging along it scrubs the zoom.
class DiaryCalendarZoomDial extends StatelessWidget {
  const DiaryCalendarZoomDial({
    super.key,
    required this.zoom,
    required this.lens,
    required this.onStep,
    required this.onTap,
    required this.onScrubStart,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final ValueListenable<double> zoom;
  final DiaryCalendarLens lens;

  /// +1 zooms one lens deeper, -1 one lens out.
  final ValueChanged<int> onStep;
  final VoidCallback onTap, onScrubStart;
  final ValueChanged<double> onScrub, onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.8);
    final values = DiaryCalendarLens.values;
    final deeper = lens.depth < DiaryZoom.deepest
        ? values[lens.depth + 1]
        : null;
    final shallower = lens.depth > 0 ? values[lens.depth - 1] : null;
    return Semantics(
      key: const ValueKey('calendar-zoom-dial'),
      label: 'Calendar zoom',
      value: lens.label,
      increasedValue: deeper?.label,
      decreasedValue: shallower?.label,
      hint: '${lens.hint}. Pinch the calendar to zoom.',
      onIncrease: deeper == null ? null : () => onStep(1),
      onDecrease: shallower == null ? null : () => onStep(-1),
      onTap: onTap,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onHorizontalDragStart: (_) => onScrubStart(),
        onHorizontalDragUpdate: (details) => onScrub(details.delta.dx),
        onHorizontalDragEnd: (details) =>
            onScrubEnd(details.primaryVelocity ?? 0),
        onHorizontalDragCancel: () => onScrubEnd(0),
        child: Material(
          color: colors.surface.withValues(alpha: .7),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: zoom,
                      builder: (context, z, _) => Text(
                        values[z.round().clamp(0, DiaryZoom.deepest)].title,
                        textScaler: scaler,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .2,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 40,
                      height: 6,
                      child: CustomPaint(
                        painter: _DialPainter(
                          zoom: zoom,
                          ink: colors.primary,
                          faint: colors.onSurfaceVariant,
                        ),
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

class _DialPainter extends CustomPainter {
  _DialPainter({required this.zoom, required this.ink, required this.faint})
    : super(repaint: zoom);

  final ValueListenable<double> zoom;
  final Color ink, faint;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = (size.width - size.height) / DiaryZoom.deepest;
    final y = size.height / 2;
    final notch = Paint()..color = faint.withValues(alpha: .35);
    for (var i = 0; i <= DiaryZoom.deepest; i++) {
      canvas.drawCircle(Offset(size.height / 2 + i * gap, y), 1.6, notch);
    }
    // Between notches the bead stretches, like a drop pulled along a thread.
    final z = zoom.value;
    final stretch = math.sin((z - z.floorToDouble()) * math.pi).abs();
    final x = size.height / 2 + z.clamp(-.3, DiaryZoom.deepest + .3) * gap;
    final width = size.height + stretch * gap * .7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y),
          width: width,
          height: size.height,
        ),
        Radius.circular(size.height / 2),
      ),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      zoom != oldDelegate.zoom ||
      ink != oldDelegate.ink ||
      faint != oldDelegate.faint;
}
