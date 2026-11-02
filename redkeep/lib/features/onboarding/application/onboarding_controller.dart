import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingState {
  const OnboardingState({
    this.complete,
    this.saving = false,
    this.saveFailed = false,
  });
  final bool? complete;
  final bool saving;
  final bool saveFailed;
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    ref.watch(onboardingRepositoryProvider);
    return const OnboardingState();
  }

  /// Called only by the bounded bootstrap coordinator. Errors use its retry UI.
  Future<void> load() async {
    final complete = await ref.read(onboardingRepositoryProvider).isComplete();
    if (ref.mounted) state = OnboardingState(complete: complete);
  }

  Future<void> complete() async {
    if (state.complete != false || state.saving) return;
    state = const OnboardingState(complete: false, saving: true);
    try {
      await ref.read(onboardingRepositoryProvider).complete();
      if (ref.mounted) state = const OnboardingState(complete: true);
    } catch (_) {
      if (ref.mounted) {
        state = const OnboardingState(complete: false, saveFailed: true);
      }
    }
  }
}
