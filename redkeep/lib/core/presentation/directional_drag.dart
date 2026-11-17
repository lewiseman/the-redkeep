import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Whether a horizontal drag that has travelled [dx] (negative is leftward)
/// past the touch slop may be claimed.
typedef HorizontalDragGate = bool Function(double dx);

/// A horizontal drag that steps aside for directions it may not take.
///
/// It decides on the very move that would win the arena: refused, it leaves
/// the arena before winning, so another horizontal recognizer (such as an
/// enclosing pager) can claim the same finger.
class GatedHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  GatedHorizontalDragGestureRecognizer({super.debugOwner});

  HorizontalDragGate? allow;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    )) {
      return false;
    }
    final allow = this.allow;
    if (allow == null || allow(globalDistanceMoved)) return true;
    resolve(GestureDisposition.rejected);
    return false;
  }
}

/// [GestureDetector]'s horizontal drag, with a direction [allow] gate.
class DirectionalHorizontalDrag extends StatelessWidget {
  const DirectionalHorizontalDrag({
    super.key,
    this.allow,
    this.behavior,
    this.onDown,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    required this.child,
  });

  final HorizontalDragGate? allow;
  final HitTestBehavior? behavior;
  final GestureDragDownCallback? onDown;
  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final GestureDragCancelCallback? onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active =
        onDown != null ||
        onStart != null ||
        onUpdate != null ||
        onEnd != null ||
        onCancel != null;
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    return RawGestureDetector(
      behavior: behavior,
      gestures: {
        // Its own type, so the default semantics add no scroll actions:
        // users reach the same moves through explicit semantics actions.
        if (active)
          GatedHorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                GatedHorizontalDragGestureRecognizer
              >(
                () => GatedHorizontalDragGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer
                  ..allow = allow
                  ..onDown = onDown
                  ..onStart = onStart
                  ..onUpdate = onUpdate
                  ..onEnd = onEnd
                  ..onCancel = onCancel
                  ..gestureSettings = settings,
              ),
      },
      child: child,
    );
  }
}
