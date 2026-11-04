import 'package:flutter/widgets.dart';

import 'rendering_policy.dart';

/// Media screens share the app's saved policy and OS accessibility setting.
/// A standalone preview can omit the app policy scope.
bool mediaMotionDisabled(BuildContext context) {
  final policy = context
      .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()
      ?.policy;
  return MediaQuery.disableAnimationsOf(context) ||
      policy?.reducedMotion == true ||
      policy?.simplerEffects == true;
}
