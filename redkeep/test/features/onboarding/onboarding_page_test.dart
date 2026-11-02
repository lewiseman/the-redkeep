import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_controller.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_page.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_required_assets.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets(
    'first launch preserves settings through local checks, downloads, onboarding and failed save',
    (tester) async {
      final onboarding = FakeOnboardingRepository(completed: false)
        ..readGate = Completer<void>();
      final assets = FakeRequiredAssets()
        ..missing = ['test.one']
        ..downloadError = const AssetException(AssetFailure.network);
      final router = await pumpApp(
        tester,
        initialLocation: '/settings',
        onboarding: onboarding,
        assets: assets,
      );
      expect(find.text('Opening Redkeep'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/startup?continue=%2Fsettings',
      );
      expect(assets.downloads, 0);
      onboarding.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Download artwork'), findsOneWidget);
      await tester.tap(find.text('Download artwork'));
      await tester.pumpAndSettle();
      expect(find.text('Retry download'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      assets.downloadError = null;
      await tester.tap(find.text('Retry download'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/onboarding?continue=%2Fsettings',
      );
      expect(router.canPop(), isFalse);
      onboarding.failSave = true;
      await tester.tap(find.text('Enter Redkeep'));
      await tester.pumpAndSettle();
      expect(onboarding.completed, isFalse);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Synthetic private'), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      onboarding.failSave = false;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(onboarding.completed, isTrue);
      expect(find.byType(AppearancePage), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(router.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Redkeep'), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

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
      final pending = router.routeInformationProvider.value.uri.toString();
      await tester.pumpWidget(const SizedBox());
      router = await pumpApp(
        tester,
        initialLocation: pending,
        onboarding: onboarding,
      );
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(onboarding.saves, 0);
      onboarding.saveGate = Completer<void>();
      onboarding.failSave = true;
      await tester.tap(find.text('Enter Redkeep'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      onboarding.saveGate!.complete();
      await tester.pump();
      await pumpApp(tester, initialLocation: pending, onboarding: onboarding);
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(onboarding.completed, isFalse);
      onboarding.failSave = false;
      await tester.tap(find.text('Enter Redkeep'));
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
      expect(find.text('Retry local checks'), findsOneWidget);
      expect(find.textContaining('Synthetic private'), findsNothing);
      onboarding.failRead = false;
      await tester.tap(find.text('Retry local checks'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest incoming destination wins while gated; duplicates settle',
    (tester) async {
      final onboarding = FakeOnboardingRepository(completed: false);
      final assets = FakeRequiredAssets()..missing = ['test.one'];
      final router = await pumpApp(
        tester,
        onboarding: onboarding,
        assets: assets,
      );
      router.go('/settings');
      await tester.pumpAndSettle();
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      await tester.tap(find.text('Download artwork'));
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/',
      );
      await tester.tap(find.text('Enter Redkeep'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('Welcome to Redkeep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid pending destinations reach a safe fallback after onboarding',
    (tester) async {
      for (final location in [
        '/notes/private?text=secret',
        '/startup?continue=%FF',
        '/onboarding?continue=https%3A%2F%2Fevil.test',
        '/startup?continue=%2Fstartup',
      ]) {
        final onboarding = FakeOnboardingRepository(completed: false);
        await tester.pumpWidget(const SizedBox());
        final router = await pumpApp(
          tester,
          initialLocation: location,
          onboarding: onboarding,
        );
        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        expect(
          router.routeInformationProvider.value.uri.queryParameters['continue'],
          '/unavailable',
        );
        await tester.tap(find.text('Enter Redkeep'));
        await tester.pumpAndSettle();
        expect(find.text('Page not found'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/unavailable');
        await tester.tap(find.text('Return home'));
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Redkeep'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
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
        await tester.ensureVisible(find.text('Enter Redkeep'));
        await tester.tap(find.text('Enter Redkeep'));
        await tester.pumpAndSettle();
        onboarding.failSave = false;
        await tester.ensureVisible(find.text('Try again'));
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'artwork repair after normal navigation preserves the current route',
    (tester) async {
      final router = await pumpApp(tester);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      tester
          .container()
          .read(bootstrapControllerProvider.notifier)
          .artworkFailed();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['continue'],
        '/settings',
      );
      await tester.tap(find.text('Retry local checks'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      expect(router.canPop(), isTrue);
    },
  );
}
