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

import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';

void main() {
  test('fresh schema matches the committed version 6 snapshot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(database, 6);
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
        await verifier.migrateAndValidate(database, 6);
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
        await verifier.migrateAndValidate(database, 6);
        expect(
          await DriftAppearanceRepository(database).watch().first,
          const AppearancePreferences(
            theme: AppTheme.dark,
            reduceMotion: true,
            simplerEffects: true,
          ),
        );
        expect(
          await DriftOnboardingRepository(database).isComplete(),
          complete,
        );
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
        await verifier.migrateAndValidate(database, 6);
        expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
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
          text: const PlainTextDocument(),
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
      await verifier.migrateAndValidate(database, 6);
      expect(
        (await DriftAppearanceRepository(database).watch().first),
        const AppearancePreferences(
          theme: AppTheme.dark,
          reduceMotion: true,
          simplerEffects: true,
        ),
      );
      expect(await DriftOnboardingRepository(database).isComplete(), isTrue);
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
        text: const PlainTextDocument(),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      expect(draft.draftRevision, greaterThan(31));
      expect(await database.select(database.diaryEntries).get(), isEmpty);
      expect(await database.select(database.diaryDrafts).get(), isEmpty);
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
      await verifier.migrateAndValidate(database, 6);
      for (final table in tables) {
        expect(
          (await database.customSelect('SELECT * FROM $table').get())
              .map((r) => r.data)
              .toList(),
          before[table],
          reason: table,
        );
      }
      expect(await database.select(database.flowThoughts).get(), isEmpty);
      expect(await database.select(database.flowDrafts).get(), isEmpty);
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
