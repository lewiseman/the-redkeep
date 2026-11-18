import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/watchlist/presentation/watch_widgets.dart';

void main() {
  Future<void> pumpShimmer(WidgetTester tester, {required bool reduce}) =>
      tester.pumpWidget(
        MaterialApp(
          home: RenderingPolicyScope(
            policy: RenderingPolicy(
              osReducedMotion: false,
              preferences: AppearancePreferences(reduceMotion: reduce),
            ),
            child: const SizedBox(
              width: 200,
              height: 300,
              child: WatchShimmer(),
            ),
          ),
        ),
      );

  testWidgets('loading images shimmer, and stay still with reduced motion', (
    tester,
  ) async {
    await pumpShimmer(tester, reduce: false);
    expect(tester.hasRunningAnimations, isTrue);
    final gradient = find.descendant(
      of: find.byType(WatchShimmer),
      matching: find.byType(DecoratedBox),
    );
    expect(gradient, findsOneWidget);
    Matrix4? sweep() =>
        ((tester.widget<DecoratedBox>(gradient).decoration as BoxDecoration)
                .gradient!
                .transform!)
            .transform(const Rect.fromLTWH(0, 0, 200, 300));
    final before = sweep();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sweep(), isNot(before), reason: 'the light moves');

    await pumpShimmer(tester, reduce: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(
        of: find.byType(WatchShimmer),
        matching: find.byType(ColoredBox),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
