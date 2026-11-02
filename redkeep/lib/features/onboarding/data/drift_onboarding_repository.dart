import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/onboarding_repository.dart';

class DriftOnboardingRepository implements OnboardingRepository {
  DriftOnboardingRepository(this._database);
  final AppDatabase _database;

  @override
  Future<bool> isComplete() async =>
      await _database
          .select(_database.onboardingCompletion)
          .getSingleOrNull() !=
      null;

  @override
  Future<void> complete() async {
    await _database
        .into(_database.onboardingCompletion)
        .insertOnConflictUpdate(
          OnboardingCompletionCompanion.insert(id: const Value(1)),
        );
  }
}
