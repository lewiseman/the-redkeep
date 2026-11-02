import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../domain/appearance_preferences.dart';

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

class AppearanceState {
  const AppearanceState({
    this.preferences = const AppearancePreferences(),
    this.loaded = false,
    this.loadError = false,
    this.saving = false,
    this.saveFailed = false,
  });

  final AppearancePreferences preferences;
  final bool loaded;
  final bool loadError;
  final bool saving;
  final bool saveFailed;

  bool get canEdit => loaded && !loadError && !saving;

  AppearanceState copyWith({
    AppearancePreferences? preferences,
    bool? loaded,
    bool? loadError,
    bool? saving,
    bool? saveFailed,
  }) => AppearanceState(
    preferences: preferences ?? this.preferences,
    loaded: loaded ?? this.loaded,
    loadError: loadError ?? this.loadError,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
  );
}

class AppearanceController extends Notifier<AppearanceState> {
  @override
  AppearanceState build() {
    final repository = ref.watch(appearanceRepositoryProvider);
    final subscription = repository.watch().listen(
      (preferences) {
        state = state.copyWith(
          preferences: preferences,
          loaded: true,
          loadError: false,
        );
      },
      onError: (Object error, StackTrace stack) {
        state = state.copyWith(loadError: true);
      },
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return const AppearanceState();
  }

  void retryLoading() => ref.invalidateSelf();

  Future<void> setTheme(AppTheme theme) =>
      _save(state.preferences.copyWith(theme: theme));

  Future<void> setReduceMotion(bool value) =>
      _save(state.preferences.copyWith(reduceMotion: value));

  Future<void> setSimplerEffects(bool value) =>
      _save(state.preferences.copyWith(simplerEffects: value));

  Future<void> _save(AppearancePreferences preferences) async {
    if (!state.canEdit) return;
    final repository = ref.read(appearanceRepositoryProvider);
    state = state.copyWith(saving: true, saveFailed: false);
    try {
      await repository.save(preferences);
      if (!ref.mounted) return;
      state = state.copyWith(preferences: preferences, saving: false);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(saving: false, saveFailed: true);
    }
  }
}
