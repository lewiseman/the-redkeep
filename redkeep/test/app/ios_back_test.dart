import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';

import '../support/fake_appearance_repository.dart';
import '../support/pump_app.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'iOS edge swipe cancels and completes with reduced motion $reduced',
      (tester) async {
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(reduceMotion: reduced),
        );
        addTearDown(appearance.close);
        final router = await pumpApp(
          tester,
          initialLocation: '/settings',
          repository: appearance,
        );
        expect(router.canPop(), isTrue);
        final route =
            ModalRoute.of(tester.element(find.byType(AppearancePage)))!
                as PageRoute;
        expect(route.popGestureEnabled, isTrue);
        final cancel = await tester.startGesture(const Offset(5, 240));
        await cancel.moveBy(const Offset(80, 0));
        await tester.pump();
        expect(route.popGestureInProgress, isTrue);
        expect(
          tester.getTopLeft(find.byType(AppearancePage)).dx,
          reduced ? 0 : greaterThan(0),
        );
        await cancel.moveBy(const Offset(-75, 0));
        await cancel.up();
        await tester.pumpAndSettle();
        expect(find.byType(AppearancePage), findsOneWidget);
        expect(router.canPop(), isTrue);
        await tester.dragFrom(const Offset(5, 240), const Offset(700, 0));
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Redkeep'), findsOneWidget);
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
