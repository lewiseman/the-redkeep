import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../domain/onboarding_repository.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingState {
  const OnboardingState({
    this.complete,
    this.saving = false,
    this.saveFailed = false,
    this.name,
    this.nameInvalid = false,
  });
  final bool? complete;
  final bool saving;
  final bool saveFailed;
  final String? name;
  final bool nameInvalid;
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    ref.watch(onboardingRepositoryProvider);
    return const OnboardingState();
  }

  /// Called only by the bounded bootstrap coordinator. Errors use its retry UI.
  Future<void> load() async {
    if (state.saving) return;
    final name = await ref.read(onboardingRepositoryProvider).readName();
    if (ref.mounted && !state.saving) {
      state = OnboardingState(complete: name != null, name: name);
    }
  }

  Future<void> complete(String value) async {
    if (state.complete != false || state.saving) return;
    final name = normalizedOnboardingName(value);
    if (name == null) {
      state = const OnboardingState(complete: false, nameInvalid: true);
      return;
    }
    state = const OnboardingState(complete: false, saving: true);
    try {
      await ref.read(onboardingRepositoryProvider).complete(name);
      if (ref.mounted) state = OnboardingState(complete: true, name: name);
    } catch (_) {
      if (ref.mounted) {
        state = const OnboardingState(complete: false, saveFailed: true);
      }
    }
  }
}
