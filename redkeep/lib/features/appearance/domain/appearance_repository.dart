import 'appearance_preferences.dart';

abstract interface class AppearanceRepository {
  /// Emits the saved preferences, or defaults when no preferences exist yet.
  Stream<AppearancePreferences> watch();

  /// Completes only after the complete preference snapshot has committed.
  Future<void> save(AppearancePreferences preferences);
}
