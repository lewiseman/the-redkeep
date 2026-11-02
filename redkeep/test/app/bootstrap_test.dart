import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_controller.dart';
import 'package:redkeep/app/bootstrap/bootstrap_coordinator.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_required_assets.dart';
import '../support/fake_onboarding_repository.dart';

import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';

void main() {
  late FakeRequiredAssets assets;
  late FakeAppearanceRepository appearance;
  late ProviderContainer container;
  var releases = 0;

  BootstrapController start({
    Future<void> Function()? localChecks,
    Future<RequiredAssets> Function()? loadAssets,
    Duration? limit,
  }) {
    container = ProviderContainer(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(appearance),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
        releaseSplashProvider.overrideWithValue(() => releases++),
        if (limit != null) localCheckLimitProvider.overrideWithValue(limit),
        bootstrapCoordinatorProvider.overrideWithValue(
          BootstrapCoordinator(
            localChecks: localChecks ?? () async {},
            loadAssets: loadAssets ?? () async => assets,
          ),
        ),
      ],
    );
    container.read(bootstrapControllerProvider);
    return container.read(bootstrapControllerProvider.notifier);
  }

  setUp(() {
    assets = FakeRequiredAssets();
    appearance = FakeAppearanceRepository();
    releases = 0;
  });
  tearDown(() async {
    container.dispose();
    await appearance.close();
  });

  test(
    'onboarding local read shares the aggregate timeout and coalesced retry',
    () async {
      final gate = Completer<void>();
      final onboarding = FakeOnboardingRepository(completed: false)
        ..readGate = gate;
      container = ProviderContainer(
        overrides: [
          appearanceRepositoryProvider.overrideWithValue(appearance),
          onboardingRepositoryProvider.overrideWithValue(onboarding),
          requiredAssetsProvider.overrideWith((_) async => assets),
          releaseSplashProvider.overrideWithValue(() => releases++),
          localCheckLimitProvider.overrideWithValue(
            const Duration(milliseconds: 1),
          ),
        ],
      );
      final controller = container.read(bootstrapControllerProvider.notifier);
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.localError,
      );
      expect(container.read(onboardingControllerProvider).complete, isNull);
      expect(releases, 1);
      expect(assets.checks, 0);
      await controller.check();
      expect(assets.checks, 0);
      gate.complete();
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.ready,
      );
      expect(container.read(onboardingControllerProvider).complete, isFalse);
      expect(assets.checks, 1);
      expect(releases, 1);
    },
  );

  test(
    'composed bootstrap retries a failed asset-store initialization explicitly',
    () async {
      var fail = true;
      var attempts = 0;
      container = ProviderContainer(
        overrides: [
          appearanceRepositoryProvider.overrideWithValue(appearance),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
          releaseSplashProvider.overrideWithValue(() => releases++),
          requiredAssetsProvider.overrideWith((_) async {
            attempts++;
            if (fail) throw const AssetException(AssetFailure.storage);
            return assets;
          }),
        ],
      );
      container.read(bootstrapControllerProvider);
      final controller = container.read(bootstrapControllerProvider.notifier);
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.localError,
      );
      expect(attempts, 1);
      expect(releases, 1);
      fail = false;
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.ready,
      );
      expect(attempts, 2);
    },
  );

  test('fresh offline stays gated; splash releases before any network; retry keeps progress', () async {
    assets.missing = ['test.one'];
    assets.downloadError = const AssetException(AssetFailure.network);
    assets.onDownload = () => expect(releases, 1);
    final controller = start();
    await controller.check();
    expect(
      container.read(bootstrapControllerProvider).stage,
      BootstrapStage.download,
    );
    expect(assets.downloads, 0);
    expect(releases, 1);
    final stages = <BootstrapState>[];
    final subscription = container.listen(
      bootstrapControllerProvider,
      (_, next) => stages.add(next),
    );
    await controller.download();
    expect(
      container.read(bootstrapControllerProvider).failure,
      AssetFailure.network,
    );
    expect(stages.any((s) => s.progress?.completedBytes == 1), isTrue);
    assets.downloadError = null;
    await controller.download();
    expect(
      container.read(bootstrapControllerProvider).stage,
      BootstrapStage.ready,
    );
    expect(releases, 1);
    subscription.close();
  });

  test(
    'complete offline startup uses only local checks and releases splash',
    () async {
      final controller = start();
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.ready,
      );
      expect(assets.downloads, 0);
      expect(assets.checks, 1);
      expect(releases, 1);
      controller.artworkFailed();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.localError,
      );
      assets.missing = ['test.one'];
      await controller.repair();
      expect(assets.verifyAll, isTrue);
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.download,
      );
    },
  );

  for (final error in [
    StateError('settings/database failed'),
    const AssetException(AssetFailure.catalog),
    const AssetException(AssetFailure.storage),
  ]) {
    test('local failure releases splash and can recover: $error', () async {
      var fail = true;
      final controller = start(
        localChecks: () async {
          if (fail) throw error;
        },
      );
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.localError,
      );
      expect(assets.downloads, 0);
      expect(releases, 1);
      fail = false;
      await controller.check();
      expect(
        container.read(bootstrapControllerProvider).stage,
        BootstrapStage.ready,
      );
    });
  }

  test('overall bound covers slow storage/catalog initialization and coalesces retry', () async {
    final gate = Completer<RequiredAssets>();
    var starts = 0;
    final controller = start(
      loadAssets: () {
        starts++;
        return gate.future;
      },
      limit: const Duration(milliseconds: 1),
    );
    await controller.check();
    expect(
      container.read(bootstrapControllerProvider).stage,
      BootstrapStage.localError,
    );
    expect(releases, 1);
    await controller.check();
    expect(starts, 1);
    gate.complete(assets);
    await controller.check();
    expect(
      container.read(bootstrapControllerProvider).stage,
      BootstrapStage.ready,
    );
    expect(assets.checks, 1);
  });

  test(
    'disposal during startup releases splash and ignores late work',
    () async {
      final gate = Completer<void>();
      final controller = start(localChecks: () => gate.future);
      final check = controller.check();
      container.dispose();
      expect(releases, 1);
      gate.complete();
      await check;
      expect(releases, 1);
    },
  );
}
