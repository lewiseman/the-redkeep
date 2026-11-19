import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// What stamping feels like in the hand. The phone's motor is driven
/// directly, so the thud and the clatter are felt even where the system's
/// touch feedback is muted or faint; without a motor, or where the plugin
/// is unavailable (as in tests), the system haptics stand in.
abstract final class StampFeel {
  static Future<({bool motor, bool strength})>? _abilities;

  static Future<({bool motor, bool strength})> _ask() async {
    try {
      final motor = await Vibration.hasVibrator();
      final strength = motor && await Vibration.hasAmplitudeControl();
      return (motor: motor, strength: strength);
    } on Object {
      return (motor: false, strength: false);
    }
  }

  static Future<void> _buzz(
    int milliseconds,
    int strength,
    void Function() fallback,
  ) async {
    final abilities = await (_abilities ??= _ask());
    if (!abilities.motor) {
      fallback();
      return;
    }
    try {
      await Vibration.vibrate(
        duration: milliseconds,
        amplitude: abilities.strength ? strength : -1,
      );
    } on Object {
      fallback();
    }
  }

  /// A stamp coming down hard.
  static void thud() => unawaited(_buzz(38, 255, HapticFeedback.heavyImpact));

  /// A stamp clattering as it settles in the rack.
  static void click() =>
      unawaited(_buzz(12, 90, HapticFeedback.selectionClick));

  /// A stamp lifted off the rack to be dragged.
  static void lift() =>
      unawaited(_buzz(16, 130, HapticFeedback.selectionClick));
}
