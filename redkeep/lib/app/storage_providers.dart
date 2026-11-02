import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/app_database.dart';
import '../features/onboarding/data/drift_onboarding_repository.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import '../features/appearance/data/drift_appearance_repository.dart';
import '../features/appearance/domain/appearance_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => DriftOnboardingRepository(ref.watch(appDatabaseProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = openAppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => DriftAppearanceRepository(ref.watch(appDatabaseProvider)),
);
