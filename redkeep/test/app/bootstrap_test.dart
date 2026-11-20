import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_controller.dart';
import 'package:redkeep/app/bootstrap/bootstrap_coordinator.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/bootstrap/startup_artwork.dart';
import 'package:redkeep/app/storage_providers.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_onboarding_repository.dart';

import 'package:redkeep/features/onboarding/application/onboarding_controller.dart';

void main() {
  late FakeAppearanceRepository appearance;
  late ProviderContainer container;
  var releases = 0;
  var checks = 0;

  BootstrapController start({
    Future<void> Function()? localChecks,
    Future<void> Function()? warmArtwork,
    Duration? limit,
    Duration? artworkLimit,
  }) {
    container = ProviderContainer(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(appearance),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
        releaseSplashProvider.overrideWithValue(() => releases++),
        startupArtworkProvider.overrideWith((_) async {
          await warmArtwork?.call();
        }),
        if (artworkLimit != null)
          startupArtworkLimitProvider.overrideWithValue(artworkLimit),
        if (limit != null) localCheckLimitProvider.overrideWithValue(limit),
        bootstrapCoordinatorProvider.overrideWithValue(
          BootstrapCoordinator(
            localChecks: () async {
              checks++;
              await localChecks?.call();
            },
          ),
        ),
      ],
    );
    container.read(bootstrapControllerProvider);
    return container.read(bootstrapControllerProvider.notifier);
  }

  BootstrapStage stage() => container.read(bootstrapControllerProvider).stage;

  setUp(() {
    appearance = FakeAppearanceRepository();
    releases = 0;
    checks = 0;
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
          releaseSplashProvider.overrideWithValue(() => releases++),
          startupArtworkProvider.overrideWith((_) async {}),
          localCheckLimitProvider.overrideWithValue(
            const Duration(milliseconds: 1),
          ),
        ],
      );
      final controller = container.read(bootstrapControllerProvider.notifier);
      await controller.check();
      expect(stage(), BootstrapStage.localError);
      expect(container.read(onboardingControllerProvider).complete, isNull);
      expect(releases, 1);
      await controller.check();
      expect(stage(), BootstrapStage.localError);
      gate.complete();
      await controller.check();
      expect(stage(), BootstrapStage.ready);
      expect(container.read(onboardingControllerProvider).complete, isFalse);
      expect(releases, 1);
    },
  );

  test(
    'startup uses only local checks and opens with bundled artwork',
    () async {
      final controller = start();
      await controller.check();
      expect(stage(), BootstrapStage.ready);
      expect(checks, 1);
      expect(releases, 1);
    },
  );

  test('artwork finishes warming before the native splash releases', () async {
    final warming = Completer<void>();
    final decoded = Completer<void>();
    final controller = start(
      warmArtwork: () {
        warming.complete();
        return decoded.future;
      },
    );
    final check = controller.check();
    await warming.future;
    expect(releases, 0);
    expect(stage(), BootstrapStage.checking);
    decoded.complete();
    await check;
    expect(releases, 1);
    expect(stage(), BootstrapStage.ready);
  });

  test('artwork warmup timeout still opens the app', () async {
    final decoded = Completer<void>();
    final controller = start(
      warmArtwork: () => decoded.future,
      artworkLimit: const Duration(milliseconds: 1),
    );
    await controller.check();
    expect(releases, 1);
    expect(stage(), BootstrapStage.ready);
    decoded.completeError(StateError('late decode failure'));
    await Future<void>.delayed(Duration.zero);
    expect(stage(), BootstrapStage.ready);
  });

  test('an artwork warmup error still opens the app', () async {
    final controller = start(
      warmArtwork: () async => throw StateError('decode failed'),
    );
    await controller.check();
    expect(stage(), BootstrapStage.ready);
    expect(releases, 1);
  });

  test('local failure releases splash and can recover', () async {
    var fail = true;
    final controller = start(
      localChecks: () async {
        if (fail) throw StateError('settings/database failed');
      },
    );
    await controller.check();
    expect(stage(), BootstrapStage.localError);
    expect(releases, 1);
    fail = false;
    await controller.check();
    expect(stage(), BootstrapStage.ready);
  });

  test('overall bound covers slow local checks and coalesces retry', () async {
    final gate = Completer<void>();
    final controller = start(
      localChecks: () => gate.future,
      limit: const Duration(milliseconds: 1),
    );
    await controller.check();
    expect(stage(), BootstrapStage.localError);
    expect(releases, 1);
    await controller.check();
    expect(checks, 1);
    gate.complete();
    await controller.check();
    expect(stage(), BootstrapStage.ready);
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
