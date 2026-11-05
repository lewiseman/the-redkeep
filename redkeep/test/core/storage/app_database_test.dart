import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';

import 'generated/schema.dart';

void main() {
  test('fresh schema matches the complete version 2 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 2);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 2);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);
  });

  test('the version 2 upgrade matches the snapshot', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(await verifier.startAt(1));
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 2);
  });

  test('upgrading a real version 1 file keeps preferences, writing and recall triggers', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.sqlite');
    // The snapshot has no triggers, so rebuild version 1 from a live database.
    final old = AppDatabase(NativeDatabase(file));
    await old.into(old.aiPreferencesTable).insert(
      const AiPreferencesTableCompanion(
        id: Value(1),
        dailyQuestions: Value(false),
      ),
    );
    await old.customStatement(
      'ALTER TABLE ai_preferences_table DROP COLUMN routes',
    );
    await old.customStatement(
      "ALTER TABLE ai_preferences_table ADD COLUMN mode TEXT NOT NULL DEFAULT 'device'",
    );
    await old.customStatement(
      "ALTER TABLE ai_preferences_table ADD COLUMN overrides TEXT NOT NULL DEFAULT '{\"noteRewrite\":\"device\"}'",
    );
    await old.customStatement(
      'CREATE TABLE brain_assignments (capability TEXT PRIMARY KEY, model_id TEXT NOT NULL)',
    );
    await old.customStatement('PRAGMA user_version = 1');
    await old.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final prefs = AiPreferencesRepository(database);
    final stored = await prefs.read();
    expect(stored.defaultRoute, const AiRoute.companion());
    expect(stored.overrides, isEmpty);
    expect(stored.dailyQuestions, isFalse, reason: 'unrelated choices survive');
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);
    final columns = await database
        .customSelect('PRAGMA table_info(ai_preferences_table)')
        .get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names, containsAll(['routes', 'recall_notes']));
    expect(names, isNot(contains('mode')));
    expect(names, isNot(contains('overrides')));
    final brain = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'brain_assignments'",
        )
        .get();
    expect(brain, isEmpty);

    final repository = DriftNotesRepository(
      database,
      clock: () => DateTime.utc(2026, 11, 5),
    );
    final draft = await repository.putDraft(
      id: 'a' * 32,
      text: const PlainTextDocument(title: 'Kept', body: 'Still writable'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await repository.commitDraft('a' * 32, draft.draftRevision);
    expect(
      (await repository.openDocument('a' * 32)).note!.text.body,
      'Still writable',
    );
    expect(await database.select(database.recallQueue).get(), hasLength(1));
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
    'a saved database reopens writing and drafts with working outbox triggers',
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
      expect(version.read<int>('user_version'), 2);
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
