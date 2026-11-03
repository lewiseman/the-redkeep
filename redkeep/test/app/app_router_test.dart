import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_onboarding_repository.dart';
import '../support/fake_required_assets.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'platform initial location is validated and preserved without a test router',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      tester.platformDispatcher.defaultRouteNameTestValue = '/settings';
      final router = await pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(find.text('Theme'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.defaultRouteNameTestValue =
          'https://bad:port/settings';
      await pumpApp(tester);
      expect(find.text('Page not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('injected initial destination recovers to home', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/missing?private=x');

    expect(router.routeInformationProvider.value.uri.path, '/unavailable');
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);

    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), '/');
    expect(find.byKey(const ValueKey('diary-active-paper')), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown navigation uses the same fallback and recovery', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/not-registered');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-active-paper')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed cold and warm platform routes use a safe fallback', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      initialLocation: '/startup?continue=%FF',
    );
    expect(find.text('Page not found'), findsOneWidget);
    for (final location in [
      '/unavailable?continue=%FF',
      '/startup?continue=%E0%A4',
      '/settings?text=%FF',
    ]) {
      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: Uri.parse(location)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/unavailable');
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-active-paper')), findsOneWidget);
  });

  test('provider scopes own independent routers and navigation state', () {
    final appearance = FakeAppearanceRepository();
    addTearDown(appearance.close);
    ProviderContainer scope() => ProviderContainer.test(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(appearance),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
        requiredAssetsProvider.overrideWith((_) async => FakeRequiredAssets()),
        releaseSplashProvider.overrideWithValue(() {}),
      ],
    );
    final first = scope();
    final second = scope();
    final firstRouter = first.read(appRouterProvider);
    final secondRouter = second.read(appRouterProvider);

    firstRouter.go('/missing');

    expect(firstRouter.routeInformationProvider.value.uri.path, '/missing');
    expect(secondRouter.routeInformationProvider.value.uri.path, '/');
    expect(first.read(appRouterProvider), same(firstRouter));
    expect(secondRouter, isNot(same(firstRouter)));
  });
}
