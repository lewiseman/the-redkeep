import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';

import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  test('fresh schema matches the committed version 2 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 2);
  });

  test('version 1 upgrade preserves every saved appearance choice', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    for (final theme in AppTheme.values) {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await old.customStatement(
        'INSERT INTO appearance_settings (id, theme, reduce_motion, simpler_effects) VALUES (1, ?, ?, ?)',
        [theme.name, 1, 1],
      );
      await old.close();
      final database = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(database, 2);
        expect(
          await DriftAppearanceRepository(database).watch().first,
          AppearancePreferences(
            theme: theme,
            reduceMotion: true,
            simplerEffects: true,
          ),
        );
        expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
        await DriftOnboardingRepository(database).complete();
        expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
      } finally {
        await database.close();
      }
    }
  });

  test(
    'schema rejects invalid theme values and non-singleton settings',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await expectLater(
        database.customStatement(
          "INSERT INTO appearance_settings (id, theme) VALUES (1, 'invalid')",
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO onboarding_completion (id) VALUES (2)',
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO appearance_settings (id) VALUES (2)',
        ),
        throwsA(isA<Exception>()),
      );
    },
  );
}
