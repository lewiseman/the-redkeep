import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../data/ai_preferences_repository.dart';
import '../domain/ai_preferences.dart';

final aiPreferencesRepositoryProvider = Provider<AiPreferencesRepository>(
  (ref) => AiPreferencesRepository(ref.watch(appDatabaseProvider)),
);
final aiPreferencesProvider = StreamProvider<AiPreferences>(
  (ref) => ref.watch(aiPreferencesRepositoryProvider).watch(),
  retry: (_, _) => null,
);
