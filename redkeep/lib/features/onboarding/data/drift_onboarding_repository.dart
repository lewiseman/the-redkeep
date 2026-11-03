import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/onboarding_repository.dart';

class DriftOnboardingRepository implements OnboardingRepository {
  DriftOnboardingRepository(this._database);
  final AppDatabase _database;

  @override
  Future<String?> readName() async => normalizedOnboardingName(
    (await _database.select(_database.onboardingCompletion).getSingleOrNull())
        ?.name,
  );

  @override
  Future<bool> isComplete() async => await readName() != null;

  @override
  Future<void> complete(String name) async {
    final savedName = normalizedOnboardingName(name);
    if (savedName == null) throw ArgumentError('A name is required.');
    await _database
        .into(_database.onboardingCompletion)
        .insertOnConflictUpdate(
          OnboardingCompletionCompanion.insert(
            id: const Value(1),
            name: Value(savedName),
          ),
        );
  }
}
