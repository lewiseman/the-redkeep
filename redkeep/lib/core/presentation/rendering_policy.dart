import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                for (final platform in TargetPlatform.values)
                  platform: _PolicyTransitions(policy, platform),
              },
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Keep framework gesture handling on Material routes. Under reduced motion,
/// iOS still gets its edge-swipe detector with stationary route animations.
class _PolicyTransitions extends PageTransitionsBuilder {
  const _PolicyTransitions(this.policy, this.platform);
  final RenderingPolicy policy;
  final TargetPlatform platform;

  @override
  Duration get transitionDuration => policy.duration;
  @override
  Duration get reverseTransitionDuration => policy.duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        route,
        context,
        policy.animate ? animation : const AlwaysStoppedAnimation(1),
        policy.animate ? secondaryAnimation : const AlwaysStoppedAnimation(0),
        child,
      );
    }
    if (!policy.animate) return child;
    if (platform == TargetPlatform.android) {
      return const PredictiveBackPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(opacity: animation, child: child);
  }
}
