import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';

import 'generated/schema.dart';

void main() {
  test('fresh schema matches the complete version 1 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 1);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 1);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 1);
  });

  test(
    'fresh install starts empty with default preferences and onboarding',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      expect(
        await DriftAppearanceRepository(database).watch().first,
        const AppearancePreferences(),
      );
      expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
      for (final table in database.allTables) {
        final row = await database
            .customSelect(
              'SELECT count(*) AS count FROM ${table.actualTableName}',
            )
            .getSingle();
        expect(row.read<int>('count'), 0, reason: table.actualTableName);
      }
    },
  );

  test(
    'version 1 reopens saved writing and drafts with working outbox triggers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'redkeep-schema-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File.fromUri(directory.uri.resolve('redkeep.sqlite'));
      final database = AppDatabase(NativeDatabase(file));
      const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final now = DateTime.utc(2026, 11, 5);
      const preferences = AppearancePreferences(
        theme: AppTheme.dark,
        accent: AppAccent.teal,
        reduceMotion: true,
        simplerEffects: true,
      );
      late int draftRevision;
      try {
        await DriftAppearanceRepository(database).save(preferences);
        await DriftOnboardingRepository(database).complete('  Léa 王  ');
        final repository = DriftNotesRepository(database, clock: () => now);
        final initial = await repository.putDraft(
          id: id,
          text: const PlainTextDocument(
            title: 'Saved',
            body: 'Exact words 👩🏽‍💻',
          ),
          baseRevision: 0,
          expectedDraftRevision: null,
        );
        expect(await database.select(database.syncRecords).get(), isEmpty);
        expect(await database.select(database.syncOperations).get(), isEmpty);
        expect(await database.select(database.recallQueue).get(), isEmpty);

        final saved = await repository.commitDraft(id, initial.draftRevision);
        final draft = await repository.putDraft(
          id: id,
          text: const PlainTextDocument(
            title: 'Draft',
            body: 'Unfinished words',
          ),
          baseRevision: saved.revision,
          expectedDraftRevision: null,
        );
        draftRevision = draft.draftRevision;
      } finally {
        await database.close();
      }

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(
        await DriftAppearanceRepository(reopened).watch().first,
        preferences,
      );
      expect(await DriftOnboardingRepository(reopened).readName(), 'Léa 王');
      final repository = DriftNotesRepository(reopened, clock: () => now);
      final restored = await repository.openDocument(id);
      expect(restored.note!.text.body, 'Exact words 👩🏽‍💻');
      expect(restored.note!.revision, 1);
      expect(restored.draft!.text.body, 'Unfinished words');
      expect(restored.draft!.draftRevision, draftRevision);
      expect(
        (await reopened.select(reopened.syncRecords).getSingle()).state,
        'pending',
      );
      expect(
        (await reopened.select(reopened.syncOperations).getSingle()).id,
        id,
      );
      expect(
        (await reopened.select(reopened.recallQueue).getSingle()).generation,
        1,
      );

      await repository.commitDraft(id, draftRevision);
      expect(
        (await repository.openDocument(id)).note!.text.body,
        'Unfinished words',
      );
      expect(
        (await reopened.select(reopened.recallQueue).getSingle()).generation,
        2,
      );
      expect(await reopened.select(reopened.noteDrafts).get(), isEmpty);
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 1);
    },
  );

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
          "INSERT INTO onboarding_completion (id, name) VALUES (2, 'Ada')",
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
