import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';

void main() {
  test(
    'completion rows require a non-empty name of at most 160 characters',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftOnboardingRepository(database);
      expect(await repository.readName(), isNull);
      await expectLater(
        database.customStatement(
          'INSERT INTO onboarding_completion(id) VALUES (1)',
        ),
        throwsA(isA<Exception>()),
      );
      for (final name in [null, '', '   ', 'a' * 161]) {
        await expectLater(
          database.customStatement(
            'INSERT INTO onboarding_completion(id, name) VALUES (1, ?)',
            [name],
          ),
          throwsA(isA<Exception>()),
        );
      }
      expect(await repository.isComplete(), isFalse);
      expect(
        await database.select(database.onboardingCompletion).get(),
        isEmpty,
      );
      await repository.complete('a' * 160);
      expect(await repository.readName(), 'a' * 160);
      expect(await repository.isComplete(), isTrue);
    },
  );

  test('invalid or failed first completion cannot grant entry', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftOnboardingRepository(database);
    for (final name in ['', '   ', '\n\t', 'a' * 161]) {
      await expectLater(repository.complete(name), throwsArgumentError);
    }
    expect(await repository.isComplete(), isFalse);
    expect(await database.select(database.onboardingCompletion).get(), isEmpty);
    await database.customStatement(
      "CREATE TRIGGER fail_name BEFORE INSERT ON onboarding_completion BEGIN SELECT RAISE(ABORT,'synthetic failure'); END;",
    );
    await expectLater(repository.complete('Ada'), throwsA(isA<Exception>()));
    expect(await repository.isComplete(), isFalse);
    expect(await database.select(database.onboardingCompletion).get(), isEmpty);
    await database.customStatement('DROP TRIGGER fail_name');
    await repository.complete('Ada');
    expect(await repository.readName(), 'Ada');
  });

  test('invalid or failed name updates preserve the completed name', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftOnboardingRepository(database);
    await repository.complete('Ada');
    await expectLater(repository.complete('   '), throwsArgumentError);
    for (final name in [null, '', '   ', 'a' * 161]) {
      await expectLater(
        database.customStatement(
          'UPDATE onboarding_completion SET name = ? WHERE id = 1',
          [name],
        ),
        throwsA(isA<Exception>()),
      );
    }
    await database.customStatement(
      "CREATE TRIGGER fail_name BEFORE UPDATE ON onboarding_completion BEGIN SELECT RAISE(ABORT,'synthetic failure'); END;",
    );
    await expectLater(repository.complete('Léa 王'), throwsA(isA<Exception>()));
    expect(await repository.isComplete(), isTrue);
    expect(await repository.readName(), 'Ada');
    expect(
      (await database.select(database.onboardingCompletion).getSingle()).id,
      1,
    );
    await database.customStatement('DROP TRIGGER fail_name');
    await repository.complete('  Léa 王  ');
    expect(await repository.readName(), 'Léa 王');
  });

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
      await DriftOnboardingRepository(database).complete('  Léa 王  ');
      await DriftOnboardingRepository(database).complete('Léa 王');
      expect(
        await database.select(database.onboardingCompletion).get(),
        hasLength(1),
      );
      await database.close();
      database = open();
      try {
        expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
        expect(await DriftOnboardingRepository(database).readName(), 'Léa 王');
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
