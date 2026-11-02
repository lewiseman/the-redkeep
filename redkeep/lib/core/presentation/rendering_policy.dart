import 'package:flutter/material.dart';

import '../../features/appearance/domain/appearance_preferences.dart';

class RenderingPolicy {
  RenderingPolicy({
    required this.osReducedMotion,
    required AppearancePreferences preferences,
    this.active = true,
  }) : reducedMotion = osReducedMotion || preferences.reduceMotion,
       simplerEffects =
           osReducedMotion ||
           preferences.reduceMotion ||
           preferences.simplerEffects;

  static const standardDuration = Duration(milliseconds: 180);

  final bool osReducedMotion;
  final bool reducedMotion;
  final bool simplerEffects;
  final bool active;

  bool get animate => active && !reducedMotion;
  Duration get duration => animate ? standardDuration : Duration.zero;
}

class RenderingPolicyScope extends InheritedWidget {
  const RenderingPolicyScope({
    super.key,
    required this.policy,
    required super.child,
  });

  final RenderingPolicy policy;

  static RenderingPolicy of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RenderingPolicyScope>()!
      .policy;

  @override
  bool updateShouldNotify(RenderingPolicyScope oldWidget) =>
      policy.osReducedMotion != oldWidget.policy.osReducedMotion ||
      policy.reducedMotion != oldWidget.policy.reducedMotion ||
      policy.simplerEffects != oldWidget.policy.simplerEffects ||
      policy.active != oldWidget.policy.active;
}

/// Observes both Android disableAnimations and iOS reduceMotion, including live
/// changes. Navigator's route TickerModes continue to suppress offscreen routes.
class RenderingPolicyHost extends StatefulWidget {
  const RenderingPolicyHost({
    super.key,
    required this.preferences,
    required this.child,
  });

  final AppearancePreferences preferences;
  final Widget child;

  @override
  State<RenderingPolicyHost> createState() => _RenderingPolicyHostState();
}

class _RenderingPolicyHostState extends State<RenderingPolicyHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final binding = WidgetsBinding.instance;
    final accessibility = binding.platformDispatcher.accessibilityFeatures;
    final lifecycle = binding.lifecycleState;
    final policy = RenderingPolicy(
      osReducedMotion:
          accessibility.disableAnimations || accessibility.reduceMotion,
      preferences: widget.preferences,
      active: lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
    return RenderingPolicyScope(
      policy: policy,
      child: TickerMode(
        enabled: policy.active,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: policy.reducedMotion ? NoSplash.splashFactory : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
