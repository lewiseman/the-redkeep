import 'package:redkeep/features/diary/application/diary_providers.dart';

import '../support/empty_diary_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/bootstrap/bootstrap_coordinator.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_required_assets.dart';
import '../support/fake_onboarding_repository.dart';

import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeRequiredAssets assets, {
    Future<void> Function()? checks,
    AppTheme theme = AppTheme.system,
  }) async {
    final appearance = FakeAppearanceRepository(
      AppearancePreferences(theme: theme, reduceMotion: true),
    );
    addTearDown(appearance.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryRepositoryProvider.overrideWithValue(EmptyDiaryRepository()),
          appearanceRepositoryProvider.overrideWithValue(appearance),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
          requiredAssetsProvider.overrideWith((_) async => assets),
          bootstrapCoordinatorProvider.overrideWith(
            (ref) => BootstrapCoordinator(
              localChecks: () async {
                await checks?.call();
                await ref.read(onboardingControllerProvider.notifier).load();
              },
              loadAssets: () async => assets,
            ),
          ),
          releaseSplashProvider.overrideWithValue(() {}),
          appRouterProvider.overrideWith((ref) {
            return createAppRouter(ref, initialLocation: '/settings');
          }),
        ],
        child: const RedkeepApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'missing required artwork blocks a direct destination; retry restores it',
    (tester) async {
      final assets = FakeRequiredAssets()
        ..missing = ['test.one']
        ..downloadError = const AssetException(AssetFailure.network);
      await pump(tester, assets);
      expect(find.text('Prepare your artwork'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);
      expect(find.textContaining('Skip'), findsNothing);
      await tester.tap(find.text('Download artwork'));
      await tester.pumpAndSettle();
      expect(find.text('Retry download'), findsOneWidget);
      assets.downloadError = null;
      await tester.tap(find.text('Retry download'));
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
    },
  );

  testWidgets(
    'resolver failure closes entry and repair restores the direct route',
    (tester) async {
      final assets = _UnavailableArtwork();
      await pump(tester, assets);
      await tester.pumpAndSettle();
      expect(find.text('Redkeep could not open'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);
      assets.available = true;
      await tester.tap(find.text('Retry local checks'));
      await tester.pumpAndSettle();
      expect(assets.verifyAll, isTrue);
      expect(find.text('Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
        final assets = FakeRequiredAssets()..missing = ['test.one'];
        await pump(
          tester,
          assets,
          theme: theme,
          checks: () async {
            if (fail) throw StateError('synthetic private error never shown');
          },
        );
        expect(find.text('Redkeep could not open'), findsOneWidget);
        expect(find.textContaining('synthetic private error'), findsNothing);
        await tester.ensureVisible(find.text('Retry local checks'));
        fail = false;
        await tester.tap(find.text('Retry local checks'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Download artwork'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'download progress persists on the Flutter screen with reduced motion',
    (tester) async {
      final gate = Completer<void>();
      final assets = _SlowAssets(gate);
      await pump(tester, assets);
      await tester.tap(find.text('Download artwork'));
      await tester.pump();
      expect(find.text('1 of 2 bytes'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      expect(find.text('Theme'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
    },
  );
}

class _SlowAssets extends FakeRequiredAssets {
  _SlowAssets(this.gate) {
    missing = ['test.one'];
  }
  final Completer<void> gate;
  @override
  Future<void> download(void Function(AssetProgress) onProgress) async {
    onProgress(const AssetProgress(1, 2));
    await gate.future;
    missing = [];
  }
}

class _UnavailableArtwork extends FakeRequiredAssets {
  bool available = false;
  @override
  Future<Uri> resolve(String key) {
    if (!available) throw const AssetException(AssetFailure.integrity);
    return super.resolve(key);
  }
}
