import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';

void main() {
  test(
    'incomplete and completed launches survive background database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'redkeep-onboarding-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File.fromUri(directory.uri.resolve('synthetic.sqlite'));
      AppDatabase open() =>
          AppDatabase(NativeDatabase.createInBackground(file));
      var database = open();
      expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
      expect(
        await database.select(database.onboardingCompletion).get(),
        isEmpty,
      );
      await DriftAppearanceRepository(database)
          .save(const AppearancePreferences(theme: AppTheme.dark));
      await database.close();
      database = open();
      expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
      await DriftOnboardingRepository(database).complete();
      await DriftOnboardingRepository(database).complete();
      expect(
        await database.select(database.onboardingCompletion).get(),
        hasLength(1),
      );
      await database.close();
      database = open();
      try {
        expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
        expect(
          await DriftAppearanceRepository(database).watch().first,
          const AppearancePreferences(theme: AppTheme.dark),
        );
      } finally {
        await database.close();
      }
    },
  );
}
