import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v11.dart' as v11;

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';

import 'package:redkeep/features/onboarding/data/drift_onboarding_repository.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;
import 'generated/schema_v10.dart' as v10;

import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

void main() {
  test('version 12 adds empty media fields and retains writing, private drafts, AI choices and sync state', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(12);
    final old = v12.DatabaseAtV12(schema.newConnection());
    await old.customStatement(
      "INSERT INTO diary_entries(id,date_key,title,body,revision,created_at,updated_at) VALUES('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','2026-11-04','Saved title','Exact saved words 👩🏽‍💻',7,1,2)",
    );
    await old.customStatement(
      "INSERT INTO notes(id,title,body,revision,created_at,updated_at,pinned) VALUES('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','Note','Saved note',3,1,2,1)",
    );
    await old.customStatement(
      "INSERT INTO note_drafts(id,title,body,base_revision,updated_at) VALUES('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','Draft','Unfinished words',3,4)",
    );
    await old.customStatement(
      "INSERT INTO sync_values(key,value) VALUES('role','retained sync value')",
    );
    await old.customStatement(
      "INSERT INTO ai_preferences_table(id,mode,reply_voice) VALUES(1,'auto','{\"name\":\"offline voice\"}')",
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      final entry = await db.select(db.diaryEntries).getSingle();
      expect(entry.body, 'Exact saved words 👩🏽‍💻');
      expect(entry.revision, 7);
      expect(entry.photos, '[]');
      expect(entry.conversation, isNull);
      expect(
        (await db.select(db.noteDrafts).getSingle()).body,
        'Unfinished words',
      );
      expect(
        (await db.select(db.syncValues).getSingle()).value,
        'retained sync value',
      );
      expect((await db.select(db.aiPreferencesTable).getSingle()).mode, 'auto');
    } finally {
      await db.close();
    }
  });

  test('version 11 migration keeps writing and assignments and seeds a rebuildable outbox', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(11);
    final old = v11.DatabaseAtV11(schema.newConnection());
    await old.customStatement(
      "INSERT INTO notes(id,title,body,revision,created_at,updated_at,pinned) VALUES(?, 'Saved garden','Exact 👩🏽‍💻 中文',7,1,2,1)",
      ['a' * 32],
    );
    await old.customStatement(
      "INSERT INTO brain_assignments(capability,model_id,source) VALUES('rewrite','keep-model','device')",
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      expect((await db.select(db.notes).getSingle()).body, 'Exact 👩🏽‍💻 中文');
      expect(
        (await db.select(db.brainAssignmentsTable).getSingle()).modelId,
        'keep-model',
      );
      expect((await db.select(db.recallQueue).getSingle()).sourceId, 'a' * 32);
      expect(await db.select(db.recallManifests).get(), isEmpty);
      await db.customStatement(
        "INSERT INTO brain_assignments(capability,model_id,source) VALUES('diaryDetails','new-model','device')",
      );
    } finally {
      await db.close();
    }
  });

  test('version 10 upgrade adds empty day details and preserves titles, writing and sync state', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(10);
    final old = v10.DatabaseAtV10(schema.newConnection());
    await old.customStatement(
      "INSERT INTO diary_days(date_key,heading,revision) VALUES('2026-11-02','Keep my title',7)",
    );
    await old.customStatement(
      "INSERT INTO diary_entries(id,date_key,title,body,revision,created_at,updated_at) VALUES(?, '2026-11-02','Entry title','Exact 👩🏽‍💻 中文',3,1,2)",
      ['a' * 32],
    );
    await old.customStatement(
      "INSERT INTO sync_records(type,document_id,state) VALUES('diary','2026-11-02','synced')",
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      final day = await db.select(db.diaryDays).getSingle();
      expect(day.heading, 'Keep my title');
      expect(day.revision, 7);
      expect(day.mood, isNull);
      expect(day.themes, '[]');
      final entry = await db.select(db.diaryEntries).getSingle();
      expect(entry.title, 'Entry title');
      expect(entry.body, 'Exact 👩🏽‍💻 中文');
      expect(entry.revision, 3);
      expect((await db.select(db.syncRecords).getSingle()).state, 'synced');
    } finally {
      await db.close();
    }
  });

  test('version 9 upgrade adds legacy appearance defaults without changing saved choices or writing', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(9);
    final old = v9.DatabaseAtV9(schema.newConnection());
    await old.customStatement(
      "INSERT INTO appearance_settings(id,theme,reduce_motion,simpler_effects) VALUES(1,'dark',1,1)",
    );
    await old.customStatement(
      "INSERT INTO notes(id,title,body,revision,created_at,updated_at,pinned) VALUES(?, 'Saved','Keep this writing',2,1,2,1)",
      ['a' * 32],
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      expect(
        await DriftAppearanceRepository(db).watch().first,
        const AppearancePreferences(
          theme: AppTheme.dark,
          reduceMotion: true,
          simplerEffects: true,
        ),
      );
      expect((await db.select(db.notes).getSingle()).body, 'Keep this writing');
    } finally {
      await db.close();
    }
  });

  test('version 8 upgrade preserves writing and name and queues only committed writing', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(8);
    final old = v8.DatabaseAtV8(schema.newConnection());
    await old.customStatement(
      "INSERT INTO onboarding_completion(id,name) VALUES(1,'Lewis')",
    );
    await old.customStatement(
      "INSERT INTO notes(id,title,body,revision,created_at,updated_at,pinned) VALUES(?, 'Saved','Keep',2,1,2,1)",
      ['a' * 32],
    );
    await old.customStatement(
      "INSERT INTO note_drafts(id,title,body,base_revision,draft_revision,updated_at) VALUES(?, '', 'Private',0,42,1)",
      ['b' * 32],
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      expect(
        (await db.select(db.onboardingCompletion).getSingle()).name,
        'Lewis',
      );
      expect(
        (await db.select(db.syncRecords).getSingle()).documentId,
        'a' * 32,
      );
      expect((await db.select(db.syncOperations).getSingle()).id, 'a' * 32);
      expect((await db.select(db.noteDrafts).getSingle()).body, 'Private');
    } finally {
      await db.close();
    }
  });
  test('version 7 completion without a name returns to onboarding and preserves every table', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    await old.customStatement(
      'INSERT INTO onboarding_completion (id) VALUES (1)',
    );
    await old.customStatement(
      "INSERT INTO appearance_settings (id,theme) VALUES (1,'dark')",
    );
    await old.customStatement(
      "INSERT INTO notes (id,title,body,revision,created_at,updated_at,pinned) VALUES (?, 'Saved note','Keep this writing',3,1,2,1)",
      ['a' * 32],
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 13);
      expect(await DriftOnboardingRepository(db).isComplete(), false);
      expect((await db.select(db.onboardingCompletion).getSingle()).id, 1);
      expect((await db.select(db.notes).getSingle()).body, 'Keep this writing');
      expect(
        (await DriftAppearanceRepository(db).watch().first).theme,
        AppTheme.dark,
      );
      await DriftOnboardingRepository(db).complete('  Léa 王  ');
      expect(await DriftOnboardingRepository(db).readName(), 'Léa 王');
      expect(await DriftOnboardingRepository(db).isComplete(), true);
    } finally {
      await db.close();
    }
  });

  test('fresh schema matches the committed version 13 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 13);
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
        await verifier.migrateAndValidate(database, 13);
        expect(
          await DriftAppearanceRepository(database).watch().first,
          AppearancePreferences(
            theme: theme,
            reduceMotion: true,
            simplerEffects: true,
          ),
        );
        expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
        await DriftOnboardingRepository(database).complete('Test Writer');
        expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
      } finally {
        await database.close();
      }
    }
  });

  test('version 2 upgrade preserves settings and onboarding without seeding writing', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    for (final complete in [false, true]) {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await old.customStatement(
        "INSERT INTO appearance_settings (id, theme, reduce_motion, simpler_effects) VALUES (1, 'dark', 1, 1)",
      );
      if (complete) {
        await old.customStatement(
          'INSERT INTO onboarding_completion (id) VALUES (1)',
        );
      }
      await old.close();
      final database = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(database, 13);
        expect(
          await DriftAppearanceRepository(database).watch().first,
          const AppearancePreferences(
            theme: AppTheme.dark,
            reduceMotion: true,
            simplerEffects: true,
          ),
        );
        expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
        expect(await database.select(database.notes).get(), isEmpty);
        expect(await database.select(database.noteDrafts).get(), isEmpty);
      } finally {
        await database.close();
      }
    }
  });

  test(
    'version 3 preserves text, tombstones, revisions and draft tokens',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      final id = 'a' * 32;
      await old.customStatement(
        "INSERT INTO appearance_settings (id, theme) VALUES (1, 'dark')",
      );
      await old.customStatement(
        'INSERT INTO onboarding_completion (id) VALUES (1)',
      );
      for (final deleted in [false, true]) {
        final key = deleted ? 'b' * 32 : id;
        await old.customStatement(
          'INSERT INTO notes (id, title, body, revision, created_at, updated_at, deleted_at) VALUES (?, ?, ?, 7, 1, 2, ?)',
          [key, '保留', 'Exact 👩🏽‍💻 e\u0301', deleted ? 3 : null],
        );
        await old.customStatement(
          'INSERT INTO note_drafts (id, title, body, base_revision, draft_revision, updated_at) VALUES (?, ?, ?, 7, ?, 4)',
          [key, 'Draft', 'Unfinished', deleted ? 12 : 11],
        );
      }
      await old.close();
      final database = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(database, 13);
        expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
        expect(
          (await DriftAppearanceRepository(database).watch().first).theme,
          AppTheme.dark,
        );
        final repo = DriftNotesRepository(
          database,
          clock: () => DateTime.utc(2026),
        );
        for (final key in [id, 'b' * 32]) {
          final snapshot = await repo.openDocument(key);
          expect(snapshot.note!.text.body, 'Exact 👩🏽‍💻 e\u0301');
          expect(snapshot.note!.revision, 7);
          expect(snapshot.note!.pinned, isFalse);
          expect(snapshot.note!.tags, isEmpty);
          expect(snapshot.note!.deletedAt != null, key != id);
          expect(snapshot.draft!.baseRevision, 7);
          expect(snapshot.draft!.draftRevision, key == id ? 11 : 12);
        }
        final draft = await repo.putDraft(
          id: 'c' * 32,
          text: const PlainTextDocument(body: 'New writing'),
          baseRevision: 0,
          expectedDraftRevision: null,
        );
        expect(draft.draftRevision, greaterThan(12));
      } finally {
        await database.close();
      }
    },
  );

  test('populated version 4 upgrade preserves Notes organization and recovery without seeding Diary', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    final id = 'd' * 32;
    await old.customStatement(
      "INSERT INTO appearance_settings (id, theme, reduce_motion, simpler_effects) VALUES (1, 'dark', 1, 1)",
    );
    await old.customStatement(
      'INSERT INTO onboarding_completion (id) VALUES (1)',
    );
    for (final deleted in [false, true]) {
      final key = deleted ? 'e' * 32 : id;
      await old.customStatement(
        'INSERT INTO notes (id,title,body,revision,created_at,updated_at,pinned,deleted_at) VALUES (?, ?, ?, 8, 1, 2, 1, ?)',
        [key, '保留', 'Exact 👩🏽‍💻 e\u0301', deleted ? 3 : null],
      );
      await old.customStatement(
        "INSERT INTO note_tags (note_id, tag) VALUES (?, '工作')",
        [key],
      );
      await old.customStatement(
        'INSERT INTO note_drafts (id,title,body,base_revision,draft_revision,updated_at) VALUES (?, ?, ?, 8, ?, 4)',
        [key, 'Draft', 'Unfinished', deleted ? 31 : 30],
      );
    }
    await old.close();
    final database = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(database, 13);
      expect(
        (await DriftAppearanceRepository(database).watch().first),
        const AppearancePreferences(
          theme: AppTheme.dark,
          reduceMotion: true,
          simplerEffects: true,
        ),
      );
      expect(await DriftOnboardingRepository(database).isComplete(), isFalse);
      final repo = DriftNotesRepository(
        database,
        clock: () => DateTime.utc(2026),
      );
      for (final key in [id, 'e' * 32]) {
        final source = await repo.openDocument(key);
        expect(source.note!.text.body, 'Exact 👩🏽‍💻 e\u0301');
        expect(source.note!.revision, 8);
        expect(source.note!.pinned, isTrue);
        expect(source.note!.tags, ['工作']);
        expect(source.note!.createdAt.millisecondsSinceEpoch, 1);
        expect(source.note!.deletedAt != null, key != id);
        expect(source.draft!.draftRevision, key == id ? 30 : 31);
      }
      final draft = await repo.putDraft(
        id: 'f' * 32,
        text: const PlainTextDocument(body: 'New writing'),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      expect(draft.draftRevision, greaterThan(31));
      expect(await database.select(database.diaryEntries).get(), isEmpty);
      expect(await database.select(database.diaryDays).get(), isEmpty);
    } finally {
      await database.close();
    }
  });

  test('populated version 5 keeps every existing table and token; Flow starts empty', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    final id = 'e' * 32;
    await old.customStatement(
      "INSERT INTO appearance_settings (id, theme, reduce_motion, simpler_effects) VALUES (1, 'dark', 1, 1)",
    );
    await old.customStatement(
      'INSERT INTO onboarding_completion (id) VALUES (1)',
    );
    for (final deleted in [false, true]) {
      final key = deleted ? 'f' * 32 : id;
      await old.customStatement(
        'INSERT INTO notes (id, title, body, revision, created_at, updated_at, deleted_at, pinned) VALUES (?, ?, ?, 7, 1, 2, ?, 1)',
        [key, 'Note', 'Exact 👩🏽‍💻 e\u0301', deleted ? 3 : null],
      );
      await old.customStatement(
        'INSERT INTO note_tags (note_id, tag) VALUES (?, ?)',
        [key, 'travel'],
      );
      await old.customStatement(
        'INSERT INTO note_drafts (id, title, body, base_revision, draft_revision, updated_at) VALUES (?, ?, ?, 7, ?, 4)',
        [key, 'Draft', 'Notes recovery', deleted ? 72 : 71],
      );
      await old.customStatement(
        'INSERT INTO diary_entries (id, date_key, title, body, revision, created_at, updated_at, deleted_at) VALUES (?, ?, ?, ?, 9, 1, 2, ?)',
        [key, '2024-02-29', 'Day', 'Diary 👩🏽‍💻 中文', deleted ? 3 : null],
      );
      await old.customStatement(
        'INSERT INTO diary_drafts (id, date_key, title, body, base_revision, draft_revision, updated_at) VALUES (?, ?, ?, ?, 9, ?, 4)',
        [key, '2024-02-29', 'Draft day', 'Diary recovery', deleted ? 82 : 81],
      );
    }
    await old.customStatement(
      "INSERT INTO diary_days (date_key, heading, revision) VALUES ('2024-02-29', 'Heading', 3)",
    );
    const tables = [
      'appearance_settings',
      'onboarding_completion',
      'notes',
      'note_tags',
      'note_drafts',
      'diary_entries',
      'diary_drafts',
      'diary_days',
      'sqlite_sequence',
    ];
    final before = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      before[table] = (await old.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
    }
    await old.close();
    final database = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(database, 13);
      for (final table in tables) {
        expect(
          (await database.customSelect('SELECT * FROM $table').get())
              .map(
                (r) => table == 'onboarding_completion'
                    ? (Map<String, dynamic>.of(r.data)..remove('name'))
                    : table == 'appearance_settings'
                    ? (Map<String, dynamic>.of(r.data)
                        ..remove('accent')
                        ..remove('font_family')
                        ..remove('diary_title_font_family')
                        ..remove('diary_body_font_family'))
                    : table == 'diary_days'
                    ? (Map<String, dynamic>.of(r.data)
                        ..remove('mood')
                        ..remove('themes'))
                    : table == 'diary_entries'
                    ? (Map<String, dynamic>.of(r.data)
                        ..remove('photos')
                        ..remove('conversation'))
                    : r.data,
              )
              .toList(),
          before[table],
          reason: table,
        );
      }
      expect(await database.select(database.flowThoughts).get(), isEmpty);
      await database.customStatement(
        "INSERT INTO diary_drafts (id, date_key, title, body, base_revision, updated_at) VALUES ('new', '2024-02-29', '', '', 0, 5)",
      );
      expect(
        (await database
                .customSelect(
                  "SELECT draft_revision FROM diary_drafts WHERE id = 'new'",
                )
                .getSingle())
            .read<int>('draft_revision'),
        greaterThan(82),
      );
    } finally {
      await database.close();
    }
  });

  test(
    'populated v6 keeps all writing and recovery; Brain starts unassigned',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(6);
      final old = v6.DatabaseAtV6(schema.newConnection());
      await old.customStatement(
        "INSERT INTO appearance_settings (id, theme) VALUES (1, 'dark')",
      );
      await old.customStatement(
        'INSERT INTO onboarding_completion (id) VALUES (1)',
      );
      for (final deleted in [false, true]) {
        final id = deleted ? 'b' * 32 : 'a' * 32;
        await old.customStatement(
          'INSERT INTO notes (id,title,body,revision,created_at,updated_at,deleted_at,pinned) VALUES (?, ?, ?, 7, 1, 2, ?, 1)',
          [id, 'Note', 'Exact 👩🏽‍💻 中文', deleted ? 3 : null],
        );
        await old.customStatement(
          "INSERT INTO note_tags (note_id,tag) VALUES (?, 'travel')",
          [id],
        );
        await old.customStatement(
          'INSERT INTO note_drafts (id,title,body,base_revision,draft_revision,updated_at) VALUES (?, ?, ?, 7, ?, 4)',
          [id, 'Draft', 'Recovery', deleted ? 72 : 71],
        );
        await old.customStatement(
          'INSERT INTO diary_entries (id,date_key,title,body,revision,created_at,updated_at,deleted_at) VALUES (?, ?, ?, ?, 9, 1, 2, ?)',
          [id, '2024-02-29', 'Day', 'Diary 👩🏽‍💻', deleted ? 3 : null],
        );
        await old.customStatement(
          'INSERT INTO diary_drafts (id,date_key,title,body,base_revision,draft_revision,updated_at) VALUES (?, ?, ?, ?, 9, ?, 4)',
          [id, '2024-02-29', 'Draft', 'Recovery', deleted ? 82 : 81],
        );
        await old.customStatement(
          'INSERT INTO flow_thoughts (id,body,revision,created_at,updated_at,deleted_at) VALUES (?, ?, 11, 1, 2, ?)',
          [id, 'Flow 👩🏽‍💻', deleted ? 3 : null],
        );
        await old.customStatement(
          'INSERT INTO flow_drafts (id,body,capture,base_revision,draft_revision,updated_at) VALUES (?, ?, 0, 11, ?, 4)',
          [id, 'Flow recovery', deleted ? 92 : 91],
        );
      }
      await old.customStatement(
        "INSERT INTO diary_days (date_key,heading,revision) VALUES ('2024-02-29', 'Heading', 3)",
      );
      const tables = [
        'appearance_settings',
        'onboarding_completion',
        'notes',
        'note_tags',
        'note_drafts',
        'diary_entries',
        'diary_drafts',
        'diary_days',
        'flow_thoughts',
        'flow_drafts',
        'sqlite_sequence',
      ];
      final before = <String, List<Map<String, dynamic>>>{};
      for (final table in tables) {
        before[table] = (await old.customSelect('SELECT * FROM $table').get())
            .map((r) => r.data)
            .toList();
      }
      await old.close();
      final database = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(database, 13);
        for (final table in tables) {
          expect(
            (await database.customSelect('SELECT * FROM $table').get())
                .map(
                  (r) => table == 'onboarding_completion'
                      ? (Map<String, dynamic>.of(r.data)..remove('name'))
                      : table == 'appearance_settings'
                      ? (Map<String, dynamic>.of(r.data)
                          ..remove('accent')
                          ..remove('font_family')
                          ..remove('diary_title_font_family')
                          ..remove('diary_body_font_family'))
                      : table == 'diary_days'
                      ? (Map<String, dynamic>.of(r.data)
                          ..remove('mood')
                          ..remove('themes'))
                      : table == 'diary_entries'
                      ? (Map<String, dynamic>.of(r.data)
                          ..remove('photos')
                          ..remove('conversation'))
                      : r.data,
                )
                .toList(),
            before[table],
            reason: table,
          );
        }
        expect(
          await database.select(database.brainAssignmentsTable).get(),
          isEmpty,
        );
        await database.customStatement(
          "INSERT INTO flow_drafts (id,body,capture,base_revision,updated_at) VALUES ('new', 'new recovery', 1, 0, 5)",
        );
        expect(
          (await database
                  .customSelect(
                    "SELECT draft_revision FROM flow_drafts WHERE id = 'new'",
                  )
                  .getSingle())
              .read<int>('draft_revision'),
          greaterThan(92),
        );
      } finally {
        await database.close();
      }
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
