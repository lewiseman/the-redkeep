import 'package:redkeep/features/appearance/application/appearance_typography.dart';

import '../support/fake_appearance_fonts.dart';

import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';

import '../support/empty_diary_repository.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/bootstrap/bootstrap_coordinator.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/bootstrap/startup_artwork.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_onboarding_repository.dart';

import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? checks,
    AppTheme theme = AppTheme.system,
  }) async {
    final appearance = FakeAppearanceRepository(
      AppearancePreferences(theme: theme, reduceMotion: true),
    );
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(appearance.close);
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceFontLoaderProvider.overrideWithValue(
            fakeAppearanceFontLoader,
          ),
          syncEnabledProvider.overrideWithValue(false),
          appDatabaseProvider.overrideWithValue(database),
          diaryRepositoryProvider.overrideWithValue(EmptyDiaryRepository()),
          appearanceRepositoryProvider.overrideWithValue(appearance),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
          bootstrapCoordinatorProvider.overrideWith(
            (ref) => BootstrapCoordinator(
              localChecks: () async {
                await checks?.call();
                await ref.read(onboardingControllerProvider.notifier).load();
              },
            ),
          ),
          releaseSplashProvider.overrideWithValue(() {}),
          initialNavigationLocationProvider.overrideWithValue('/settings'),
          startupArtworkProvider.overrideWith((_) async {}),
        ],
        child: const RedkeepApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('a direct destination opens without a setup page', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Getting things ready'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'a local failure blocks a direct destination; retry restores it',
    (tester) async {
      var fail = true;
      await pump(
        tester,
        checks: () async {
          if (fail) throw StateError('settings/database failed');
        },
      );
      expect(find.text("Redkeep couldn't open"), findsOneWidget);
      for (final entry in {
        'startup-background': 'assets/branding/ink-paper.webp',
        'startup-logo': 'assets/branding/grand_maestar.png',
      }.entries) {
        final image = tester.widget<Image>(find.byKey(ValueKey(entry.key)));
        expect(
          ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
          entry.value,
        );
      }
      expect(find.text('Theme'), findsNothing);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      expect(
        tester
            .container()
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/settings',
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      '$theme error/retry is usable with narrow screen, large text and insets',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
        tester.view.viewInsets = FakeViewPadding(bottom: 180);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        var fail = true;
        await pump(
          tester,
          theme: theme,
          checks: () async {
            if (fail) throw StateError('synthetic private error never shown');
          },
        );
        expect(find.text("Redkeep couldn't open"), findsOneWidget);
        expect(find.textContaining('synthetic private error'), findsNothing);
        await tester.ensureVisible(find.text('Try again'));
        fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text("Redkeep couldn't open"), findsNothing);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }
}
