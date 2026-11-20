import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/application/onboarding_controller.dart';
import '../storage_providers.dart';
import 'bootstrap_coordinator.dart';

final bootstrapCoordinatorProvider = Provider<BootstrapCoordinator>((ref) {
  final preferences = ref.watch(appearanceRepositoryProvider);
  return BootstrapCoordinator(
    // Opens the background database and checks saved preferences.
    localChecks: () async {
      await preferences.watch().first;
      await ref.read(onboardingControllerProvider.notifier).load();
    },
  );
});

final releaseSplashProvider = Provider<void Function()>(
  (ref) => FlutterNativeSplash.remove,
);

final localCheckLimitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);
