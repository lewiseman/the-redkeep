import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_page.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/pump_app.dart';
import '../../support/onboarding_navigation.dart';

Future<void> enterRedkeep(WidgetTester tester) async {
  if (find.text("Let's begin").evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text("Let's begin"));
    await tester.tap(find.text("Let's begin"));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), 'Test Writer');
  await tester.pump();
  await tester.ensureVisible(find.text('Save'));
  await tester.tap(find.text('Save'));
}

void main() {
  testWidgets(
    'interruption leaves onboarding incomplete; root back can exit and relaunch resumes',
    (tester) async {
      final onboarding = FakeOnboardingRepository(completed: false);
      var router = await pumpApp(
        tester,
        initialLocation: '/settings',
        onboarding: onboarding,
      );
      expect(await tester.binding.handlePopRoute(), isFalse);
      expect(onboarding.completed, isFalse);
      await tester.ensureVisible(find.text("Let's begin"));
      await tester.tap(find.text("Let's begin"));
      await tester.pumpAndSettle();
      expect(onboarding.saves, 0);
      final pending = router.routeInformationProvider.value.uri.toString();
      await tester.pumpWidget(const SizedBox());
      router = await pumpApp(
        tester,
        initialLocation: pending,
        onboarding: onboarding,
      );
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(chapterPosition(1), findsOneWidget);
      expect(onboarding.saves, 0);
      onboarding.saveGate = Completer<void>();
      onboarding.failSave = true;
      await enterRedkeep(tester);
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      onboarding.saveGate!.complete();
      await tester.pump();
      await pumpApp(tester, initialLocation: pending, onboarding: onboarding);
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(onboarding.completed, isFalse);
      onboarding.failSave = false;
      await enterRedkeep(tester);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      router = await pumpApp(
        tester,
        initialLocation: pending,
        onboarding: onboarding,
      );
      expect(find.byType(OnboardingPage), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding read failure uses startup retry and preserves destination',
    (tester) async {
      final onboarding = FakeOnboardingRepository(completed: false)
        ..failRead = true;
      final router = await pumpApp(
        tester,
        initialLocation: '/settings',
        onboarding: onboarding,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Synthetic private'), findsNothing);
      onboarding.failRead = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      '$theme onboarding works at 320px, 3x text, safe areas, keyboard and reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
        tester.view.viewInsets = FakeViewPadding(bottom: 180);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(theme: theme),
        );
        addTearDown(appearance.close);
        final onboarding = FakeOnboardingRepository(completed: false)
          ..failSave = true;
        final router = await pumpApp(
          tester,
          repository: appearance,
          onboarding: onboarding,
        );
        final context = tester.element(find.byType(OnboardingPage));
        final route = ModalRoute.of(context)!;
        expect(route.animation!.value, 1);
        expect((route as PageRoute).transitionDuration, Duration.zero);
        expect(
          Theme.of(context).brightness,
          theme == AppTheme.dark ? Brightness.dark : Brightness.light,
        );
        await enterRedkeep(tester);
        await tester.pumpAndSettle();
        onboarding.failSave = false;
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
