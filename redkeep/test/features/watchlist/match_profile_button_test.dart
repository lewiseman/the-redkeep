import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/watchlist/presentation/dating_widgets.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int? percent,
    bool reduce = false,
    VoidCallback? onPressed,
  }) => tester.pumpWidget(
    MaterialApp(
      home: RenderingPolicyScope(
        policy: RenderingPolicy(
          osReducedMotion: false,
          preferences: AppearancePreferences(reduceMotion: reduce),
        ),
        child: Center(
          child: MatchProfileButton(
            percent: percent,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('the ring counts up to the match and opens the profile', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, percent: 87, onPressed: () => opened++);
    await tester.pump(const Duration(milliseconds: 200));
    final early = tester.widget<Text>(find.textContaining('%')).data!;
    expect(int.parse(early.replaceAll('%', '')), lessThan(87));
    await tester.pumpAndSettle();
    expect(find.text('87%'), findsOneWidget);
    expect(find.bySemanticsLabel('View profile, 87% match'), findsOneWidget);

    await tester.tap(find.byTooltip('View profile'));
    expect(opened, 1);
  });

  testWidgets('with reduced motion the score is there at once', (tester) async {
    await pump(tester, percent: 64, reduce: true);
    expect(find.text('64%'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('while taste is learned there is no score, only the way in', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
    expect(find.bySemanticsLabel('View profile'), findsOneWidget);
  });
}
