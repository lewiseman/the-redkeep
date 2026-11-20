import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// What turning the emoji sphere feels like in the hand: a detent as each
/// emoji rolls under the lens, a click as one seats there, a thud when it
/// is chosen. The phone's motor is driven directly, so the ticks stay crisp
/// where the system's touch feedback is muted or faint; without a motor, or
/// where the plugin is unavailable (as in tests), system haptics stand in.
abstract final class SphereFeel {
  /// What the phone's motor can do, once known.
  static ({bool motor, bool strength})? _abilities;
  static DateTime _lastDetent = DateTime(0);

  /// Detents closer together than this blur into a buzz, so they're dropped.
  static const _detentGap = Duration(milliseconds: 40);

  /// Forgets the motor and the last detent, so each test starts afresh.
  @visibleForTesting
  static void reset() {
    _abilities = null;
    _lastDetent = DateTime(0);
  }

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
    final abilities = _abilities ??= await _ask();
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

  /// An emoji rolling under the lens while the sphere turns. [speed] is the
  /// turn in radians a second: the faster the spin, the lighter each tick,
  /// so a fling ripples rather than rattles.
  static void detent({double speed = 0}) {
    final now = DateTime.now();
    if (now.difference(_lastDetent) < _detentGap) return;
    _lastDetent = now;
    final fast = (speed / 12).clamp(0.0, 1.0);
    final strength = (120 - 70 * fast).round();
    unawaited(_buzz(8, strength, HapticFeedback.selectionClick));
  }

  /// The sphere coming to rest with an emoji seated in the lens.
  static void seat() => unawaited(_buzz(14, 170, HapticFeedback.lightImpact));

  /// The centre emoji chosen.
  static void choose() =>
      unawaited(_buzz(24, 230, HapticFeedback.mediumImpact));
}
