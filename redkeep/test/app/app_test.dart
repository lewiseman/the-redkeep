import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('app scope composes a diary-first shell', (tester) async {
    await pumpApp(tester);

    expect(find.text('Redkeep'), findsOneWidget);
    expect(find.text('My diary'), findsOneWidget);
    expect(
      find.text('A notebook for each day. Your words stay on this device.'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final location in ['/', '/unavailable']) {
    testWidgets('layout remains usable at large text on $location', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
      tester.view.viewInsets = FakeViewPadding(bottom: 180);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: true,
            reduceMotion: true,
          );
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final router = await pumpApp(tester, initialLocation: location);
      expect(tester.takeException(), isNull);

      if (location == '/') {
        await tester.scrollUntilVisible(
          find.text('My diary'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('My diary'), findsOneWidget);
      } else {
        final returnHome = find.text('Return home');
        await tester.ensureVisible(returnHome);
        await tester.tap(returnHome);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        await tester.scrollUntilVisible(
          find.text('My diary'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('My diary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
