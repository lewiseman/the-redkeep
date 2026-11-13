import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';

import 'generated/schema.dart';

void main() {
  test('fresh schema matches the complete version 8 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 8);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 8);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 8);
  });

  for (final from in [1, 2, 3, 4, 5, 6, 7]) {
    test('the upgrade from version $from matches the snapshot', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final database = AppDatabase(await verifier.startAt(from));
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 8);
    });
  }

  test('version 8 syncs watchlist titles, lists and taste, not the catalog or chats', () async {
    Future<Set<String>> triggers(AppDatabase database) async => (await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'sync_watch%'",
            )
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    final verifier = SchemaVerifier(GeneratedHelper());
    final upgraded = AppDatabase(await verifier.startAt(7));
    addTearDown(upgraded.close);
    await verifier.migrateAndValidate(upgraded, 8);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.customSelect('SELECT 1').get();
    final expected = {
      for (final table in ['watch_titles', 'watch_lists', 'watch_profiles'])
        for (final event in ['insert', 'update', 'delete'])
          'sync_${table}_$event',
    };
    expect(await triggers(upgraded), expected);
    expect(await triggers(fresh), expected);
  });

  test('versions 5 to 7 add local note websites and chats outside sync', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(await verifier.startAt(4));
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 7);
    final triggers =
        (await database
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'trigger'",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(triggers.where((t) => t.contains('note_websites')), isEmpty);
    expect(triggers.where((t) => t.contains('note_chat')), isEmpty);
    expect(await database.select(database.noteWebsites).get(), isEmpty);
    expect(await database.select(database.noteChatTurns).get(), isEmpty);
  });

  test('version 4 drops stored tasks, daily questions, voices, conversations and recovery copies', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(await verifier.startAt(3));
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 4);
    final tables =
        (await database
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(tables, contains('ai_usage_months'));
    expect(tables, isNot(contains('ai_job_receipts')));
    expect(tables, isNot(contains('daily_questions')));
    expect(tables, isNot(contains('note_ai_recoveries')));
    final prefs =
        (await database
                .customSelect('PRAGMA table_info(ai_preferences_table)')
                .get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(prefs, isNot(anyOf(contains('routes'), contains('reply_voice'))));
    final diary =
        (await database.customSelect('PRAGMA table_info(diary_entries)').get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(diary, isNot(contains('conversation')));
  });

  test('version 3 drops the old note drafts table', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-v2-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await old.customStatement(
      'CREATE TABLE note_drafts (id TEXT NOT NULL UNIQUE, body TEXT NOT NULL)',
    );
    await old.customStatement('PRAGMA user_version = 2');
    await old.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'note_drafts'",
        )
        .get();
    expect(tables, isEmpty);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 8);
  });

  test('upgrading a real version 1 file keeps preferences, writing and recall triggers', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.sqlite');
    // The snapshot has no triggers, so rebuild version 1 from a live database.
    final old = AppDatabase(NativeDatabase(file));
    await old
        .into(old.aiPreferencesTable)
        .insert(
          const AiPreferencesTableCompanion(
            id: Value(1),
            recallFlow: Value(false),
          ),
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
    expect(
      stored.collections,
      isNot(contains('thought')),
      reason: 'unrelated choices survive',
    );
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 8);
    final columns = await database
        .customSelect('PRAGMA table_info(ai_preferences_table)')
        .get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('recall_notes'));
    expect(names, isNot(contains('routes')));
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
    await repository.saveNote(
      id: 'a' * 32,
      text: const PlainTextDocument(title: 'Kept', body: 'Still writable'),
      expectedRevision: 0,
      details: const NoteDetails(),
    );
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
    'a saved database reopens writing with working outbox triggers',
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
      try {
        await DriftAppearanceRepository(database).save(preferences);
        await DriftOnboardingRepository(database).complete('  Léa 王  ');
        final repository = DriftNotesRepository(database, clock: () => now);
        expect(await database.select(database.syncRecords).get(), isEmpty);
        expect(await database.select(database.syncOperations).get(), isEmpty);
        expect(await database.select(database.recallQueue).get(), isEmpty);

        final saved = await repository.saveNote(
          id: id,
          text: const PlainTextDocument(
            title: 'Saved',
            body: 'Exact words 👩🏽‍💻',
          ),
          expectedRevision: 0,
          details: const NoteDetails(),
        );
        expect(saved.revision, 1);
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

      await repository.saveNote(
        id: id,
        text: const PlainTextDocument(title: 'Saved', body: 'Later words'),
        expectedRevision: 1,
        details: const NoteDetails(),
      );
      expect(
        (await repository.openDocument(id)).note!.text.body,
        'Later words',
      );
      expect(
        (await reopened.select(reopened.recallQueue).getSingle()).generation,
        2,
      );
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 8);
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
