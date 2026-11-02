import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

void main() {
  test(
    'all OS and app combinations preserve device reduction and app intent',
    () {
      for (final os in [false, true]) {
        for (final motion in [false, true]) {
          for (final effects in [false, true]) {
            for (final active in [false, true]) {
              final policy = RenderingPolicy(
                osReducedMotion: os,
                preferences: AppearancePreferences(
                  reduceMotion: motion,
                  simplerEffects: effects,
                ),
                active: active,
              );
              expect(policy.reducedMotion, os || motion);
              expect(policy.simplerEffects, os || motion || effects);
              expect(policy.animate, active && !os && !motion);
              expect(
                policy.duration,
                policy.animate
                    ? RenderingPolicy.standardDuration
                    : Duration.zero,
              );
            }
          }
        }
      }
    },
  );

  testWidgets(
    'both platform flags react live; clearing them restores app policy',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        const MaterialApp(
          home: RenderingPolicyHost(
            preferences: AppearancePreferences(),
            child: _PolicyLabel(),
          ),
        ),
      );
      expect(find.text('standard'), findsOneWidget);
      for (final features in [
        FakeAccessibilityFeatures(reduceMotion: true),
        FakeAccessibilityFeatures(disableAnimations: true),
      ]) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = features;
        await tester.pump();
        expect(find.text('reduced'), findsOneWidget);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures();
        await tester.pump();
        expect(find.text('standard'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'inactive and offscreen tickers stop and resume without duplicate controllers',
    (tester) async {
      final probe = GlobalKey<_TickerProbeState>();
      Future<void> pump({bool visible = true}) => tester.pumpWidget(
        MaterialApp(
          home: RenderingPolicyHost(
            preferences: const AppearancePreferences(),
            child: TickerMode(
              enabled: visible,
              child: _TickerProbe(key: probe),
            ),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(probe.currentState!.ticks, greaterThan(0));
      for (final lifecycle in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
        await tester.pump();
        final stopped = probe.currentState!.ticks;
        await tester.pump(const Duration(milliseconds: 40));
        expect(probe.currentState!.ticks, stopped);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final resumed = probe.currentState!.ticks;
      await tester.pump(const Duration(milliseconds: 40));
      expect(probe.currentState!.ticks, greaterThan(resumed));
      await pump(visible: false);
      final offscreen = probe.currentState!.ticks;
      await tester.pump(const Duration(milliseconds: 40));
      expect(probe.currentState!.ticks, offscreen);
      await pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(probe.currentState!.ticks, greaterThan(offscreen));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}

class _PolicyLabel extends StatelessWidget {
  const _PolicyLabel();

  @override
  Widget build(BuildContext context) => Text(
    RenderingPolicyScope.of(context).reducedMotion ? 'reduced' : 'standard',
  );
}

class _TickerProbe extends StatefulWidget {
  const _TickerProbe({super.key});

  @override
  State<_TickerProbe> createState() => _TickerProbeState();
}

class _TickerProbeState extends State<_TickerProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() => ticks++)
          ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
