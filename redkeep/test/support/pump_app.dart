import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';

import 'fake_appearance_repository.dart';
import 'fake_required_assets.dart';
import 'fake_onboarding_repository.dart';

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  FakeAppearanceRepository? repository,
  FakeOnboardingRepository? onboarding,
  FakeRequiredAssets? assets,
}) async {
  final preferences = repository ?? FakeAppearanceRepository();
  if (repository == null) addTearDown(preferences.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(preferences),
        onboardingRepositoryProvider.overrideWithValue(
          onboarding ?? FakeOnboardingRepository(),
        ),
        requiredAssetsProvider.overrideWith(
          (ref) async => assets ?? FakeRequiredAssets(),
        ),
        releaseSplashProvider.overrideWithValue(() {}),
        if (initialLocation != null)
          appRouterProvider.overrideWith((ref) {
            return createAppRouter(ref, initialLocation: initialLocation);
          }),
      ],
      child: const RedkeepApp(),
    ),
  );
  await tester.pumpAndSettle();
  return tester.container().read(appRouterProvider);
}
