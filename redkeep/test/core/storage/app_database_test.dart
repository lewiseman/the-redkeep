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
  test('fresh schema matches the complete version 15 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 15);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 15);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 15);
  });

  for (final from in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]) {
    test('the upgrade from version $from matches the snapshot', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final database = AppDatabase(await verifier.startAt(from));
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 15);
    });
  }

  test('version 15 drops note websites and keeps their notes', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(14);
    final id = 'a' * 32;
    for (final statement in [
      "INSERT INTO notes (id, title, body, details, revision, created_at, updated_at) VALUES ('$id', 'Kept', 'Words', '{}', 1, 1, 1)",
      "INSERT INTO note_websites (note_id, html, source_hash, made_at) VALUES ('$id', '<html></html>', 'h', 1)",
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    addTearDown(old.close);
    await verifier.migrateAndValidate(old, 15);

    final gone = await old
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'note_websites'",
        )
        .get();
    expect(gone, isEmpty);
    final note = await old.select(old.notes).getSingle();
    expect((note.title, note.body), ('Kept', 'Words'));
  });

  test('version 14 drops Discover and keeps what the reader saved', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(13);
    String id(String c) => c * 32;
    String title(
      String c,
      String status,
      String swipe, {
      String note = '',
      String episodes = '[]',
    }) =>
        "INSERT INTO watch_titles (id, media_key, title, status, note, "
        "episodes, swipe, revision, created_at, updated_at) VALUES "
        "('${id(c)}', 'movie:${c.codeUnitAt(0)}', '$c', $status, '$note', "
        "'$episodes', $swipe, 1, 1, 1)";
    for (final statement in [
      title('a', 'NULL', "'like'"), // Liked only: dropped.
      title('b', 'NULL', "'nope'"), // Passed only: dropped.
      title('c', "'planned'", "'like'"), // Liked, then planned: kept.
      title('d', 'NULL', "'like'", episodes: '["s1e1"]'), // Ticked: kept.
      title('g', 'NULL', "'like'", note: 'Ask Sam'), // Notes go: dropped.
      title('e', 'NULL', "'like'"), // In a list: kept.
      "INSERT INTO watch_lists (id, name, items, revision, created_at, updated_at) VALUES ('${id('f')}', 'Later', '[\"${id('e')}\"]', 1, 1, 1)",
      "INSERT INTO watch_profiles (id, state, revision, created_at, updated_at) VALUES ('${id('9')}', '{}', 1, 1, 1)",
      "INSERT INTO watch_chat_turns VALUES ('${id('8')}', '${id('a')}', 1, 1, 'Hi')",
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    addTearDown(old.close);
    await verifier.migrateAndValidate(old, 15);

    final kept = await old.select(old.watchTitles).get();
    expect(kept.map((t) => t.title).toSet(), {'c', 'd', 'e'});
    expect(kept.firstWhere((t) => t.title == 'c').status, 'planned');
    final gone = await old
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name IN "
          "('watch_profiles', 'watch_chat_turns')",
        )
        .get();
    expect(gone, isEmpty);
  });

  test('version 13 drops the sync outbox, sync state and triggers but keeps writing', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(12);
    for (final statement in [
      "INSERT INTO notes (id, title, body, details, revision, created_at, updated_at) VALUES ('${'a' * 32}', 'Kept', 'Words', '{}', 1, 1, 1)",
      "INSERT INTO sync_records (type, document_id) VALUES ('note', '${'a' * 32}')",
      "INSERT INTO sync_values VALUES ('role', '{}')",
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    addTearDown(old.close);
    await verifier.migrateAndValidate(old, 15);
    final leftovers = await old
        .customSelect("SELECT name FROM sqlite_master WHERE name LIKE 'sync_%'")
        .get();
    expect(leftovers, isEmpty);
    final note = await old.select(old.notes).getSingle();
    expect((note.title, note.body), ('Kept', 'Words'));
    // Writing still works without the old triggers.
    await old.customStatement(
      "UPDATE notes SET body = 'Later' WHERE id = '${'a' * 32}'",
    );
  });

  test('version 7 adds local note chats outside sync', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(await verifier.startAt(4));
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 15);
    final names =
        (await database
                .customSelect('SELECT name, type FROM sqlite_master')
                .get())
            .map((r) => (r.read<String>('name'), r.read<String>('type')));
    // No website table, and no sync triggers on the chat.
    expect(names.where((n) => n.$1 == 'note_websites'), isEmpty);
    expect(
      names.where((n) => n.$2 == 'trigger' && n.$1.contains('note_chat')),
      isEmpty,
    );
    expect(await database.select(database.noteChatTurns).get(), isEmpty);
  });

  test('version 4 drops stored tasks, daily questions, voices, conversations and recovery copies', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(await verifier.startAt(3));
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 15);
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
    expect(version.read<int>('user_version'), 15);
  });

  test('version 9 removes Flow and keeps diary entries as ordinary entries', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(8);
    // Raw SQL before opening: version 8 tables are not in the current database.
    for (final statement in [
      "INSERT INTO flow_thoughts VALUES ('${'a' * 32}', 'A thought', 1, 1, 1, NULL)",
      "INSERT INTO diary_entries (id, period_key, body, revision, created_at, updated_at) VALUES ('${'b' * 32}', '2026-11-03', 'Kept', 1, 1, 1)",
      "INSERT INTO sync_operations VALUES ('thought', '${'a' * 32}', '${'a' * 32}')",
      "INSERT INTO sync_records (type, document_id) VALUES ('thought', '${'a' * 32}')",
      "INSERT INTO sync_records (type, document_id) VALUES ('diary', '2026-11-03')",
      "INSERT INTO recall_queue (kind, source_id) VALUES ('thought', '${'a' * 32}')",
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(old, 15);

    final tables = await old
        .customSelect("SELECT name FROM sqlite_master WHERE name LIKE 'flow_%'")
        .get();
    expect(tables, isEmpty);
    final entry = await old.select(old.diaryEntries).getSingle();
    expect((entry.body, entry.kind), ('Kept', 'entry'));
    await old.close();
  });

  test('version 10 removes the diary from AI search and photo questions', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(9);
    // Raw SQL before opening: the snapshot has no triggers and keeps version 9
    // tables and columns the current database no longer has.
    for (final statement in [
      'INSERT INTO ai_preferences_table (id, recall_diary) VALUES (1, 1)',
      "INSERT INTO photo_question_cache VALUES ('k', '{}', 1)",
      "INSERT INTO recall_queue (kind, source_id) VALUES ('diary', '${'a' * 32}')",
      "INSERT INTO recall_queue (kind, source_id) VALUES ('note', '${'b' * 32}')",
      "INSERT INTO recall_manifests (profile, kind, source_id, hash, revision, chunks) VALUES ('p', 'diary', '${'a' * 32}', 'h', 1, '[]')",
      "INSERT INTO recall_manifests (profile, kind, source_id, hash, revision, chunks) VALUES ('p', 'note', '${'b' * 32}', 'h', 1, '[]')",
      '''CREATE TRIGGER recall_diary_entries_insert AFTER INSERT ON diary_entries
        BEGIN
          INSERT INTO recall_queue(kind, source_id, generation)
          VALUES ('diary', NEW.id, 1)
          ON CONFLICT(kind, source_id) DO UPDATE SET generation = generation + 1;
        END''',
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    addTearDown(old.close);
    await verifier.migrateAndValidate(old, 15);

    final dropped = await old
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'photo_question_cache' "
          "OR name LIKE 'recall_diary_entries_%'",
        )
        .get();
    expect(dropped, isEmpty);

    await old.customStatement(
      "INSERT INTO diary_entries (id, period_key, body, revision, created_at, updated_at) VALUES ('${'c' * 32}', '2026-11-03', 'Private', 1, 1, 1)",
    );
    expect(await old.select(old.diaryEntries).get(), hasLength(1));
  });

  test('version 12 removes AI note search and its stored index', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(11);
    // Raw SQL before opening: the snapshot has no triggers and keeps the
    // version 11 index tables the current database no longer has.
    for (final statement in [
      'INSERT INTO ai_preferences_table (id, recall_paused) VALUES (1, 1)',
      "INSERT INTO recall_queue (kind, source_id) VALUES ('note', '${'b' * 32}')",
      "INSERT INTO recall_manifests (profile, kind, source_id, hash, revision, chunks) VALUES ('p', 'note', '${'b' * 32}', 'h', 1, '[]')",
      for (final event in ['INSERT', 'UPDATE', 'DELETE'])
        '''CREATE TRIGGER recall_notes_${event.toLowerCase()} AFTER $event ON notes
        BEGIN
          INSERT INTO recall_queue(kind, source_id, generation)
          VALUES ('note', ${event == 'DELETE' ? 'OLD' : 'NEW'}.id, 1)
          ON CONFLICT(kind, source_id) DO UPDATE SET generation = generation + 1;
        END''',
    ]) {
      schema.rawDatabase.execute(statement);
    }
    final old = AppDatabase(schema.newConnection());
    addTearDown(old.close);
    await verifier.migrateAndValidate(old, 15);

    final left = await old
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name LIKE 'recall_%' "
          "OR name = 'ai_preferences_table'",
        )
        .get();
    expect(left, isEmpty);

    final repository = DriftNotesRepository(
      old,
      clock: () => DateTime.utc(2026, 11, 17),
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
  });

  test('upgrading a real version 1 file keeps writing and removes AI preferences', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app.sqlite');
    // The snapshot has no triggers, so rebuild version 1 from a live database
    // plus the version 1 AI preferences and search index triggers.
    final old = AppDatabase(NativeDatabase(file));
    await old.customStatement(
      'CREATE TABLE ai_preferences_table (id INTEGER NOT NULL DEFAULT 1 '
      'PRIMARY KEY, recall_notes INTEGER NOT NULL DEFAULT 1, '
      'recall_paused INTEGER NOT NULL DEFAULT 0, '
      'recall_cleanup_required INTEGER NOT NULL DEFAULT 0)',
    );
    await old.customStatement(
      'INSERT INTO ai_preferences_table (id, recall_paused) VALUES (1, 1)',
    );
    await old.customStatement(
      'CREATE TABLE recall_queue (kind TEXT NOT NULL, source_id TEXT NOT NULL, '
      'generation INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (kind, source_id))',
    );
    await old.customStatement(
      'CREATE TABLE recall_manifests (profile TEXT NOT NULL, kind TEXT NOT NULL, '
      'source_id TEXT NOT NULL, hash TEXT NOT NULL, revision INTEGER NOT NULL, '
      'chunks TEXT NOT NULL, complete INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY (profile, kind, source_id))',
    );
    await old.customStatement(
      '''CREATE TRIGGER recall_notes_insert AFTER INSERT ON notes
        BEGIN
          INSERT INTO recall_queue(kind, source_id, generation)
          VALUES ('note', NEW.id, 1)
          ON CONFLICT(kind, source_id) DO UPDATE SET generation = generation + 1;
        END''',
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
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 15);
    final retired = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'brain_assignments' "
          "OR name = 'ai_preferences_table' OR name LIKE 'recall_%'",
        )
        .get();
    expect(retired, isEmpty);

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

  test('a saved database reopens writing intact', () async {
    final directory = await Directory.systemTemp.createTemp('redkeep-schema-');
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

    await repository.saveNote(
      id: id,
      text: const PlainTextDocument(title: 'Saved', body: 'Later words'),
      expectedRevision: 1,
      details: const NoteDetails(),
    );
    expect((await repository.openDocument(id)).note!.text.body, 'Later words');
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 15);
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
