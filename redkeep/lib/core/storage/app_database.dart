import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/ai/data/ai_tables.dart';

import '../../features/appearance/data/appearance_table.dart';
import '../../features/onboarding/data/onboarding_table.dart';
import '../../features/notes/data/notes_tables.dart';
import '../../features/diary/data/diary_tables.dart';
import '../../features/watchlist/data/watchlist_tables.dart';

import '../../features/sync/data/sync_tables.dart';
import '../../features/sync/data/sync_schema.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AiUsageMonths,
    AppearanceSettings,
    OnboardingCompletion,
    Notes,
    NoteTags,
    NoteMediaOps,
    NoteWebsites,
    NoteChatTurns,
    DiaryEntries,
    DiaryDays,
    DiaryMediaOps,
    DiarySearchHistory,
    WatchCatalog,
    WatchTitles,
    WatchLists,
    WatchProfiles,
    WatchChatTurns,
    SyncOperations,
    SyncValues,
    SyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 12;

  // Reset changes this generation before disposing editors. Old repositories
  // cannot write after cleanup, even when an async continuation finishes late.
  int writingGeneration = 0;
  bool writingBlocked = false;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installSyncTriggers(this);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Phone AI is gone. Old Phone and Auto choices fall back to the
        // computer, the default for an empty `routes`.
        await customStatement('DROP TABLE IF EXISTS brain_assignments');
        await customStatement(
          "ALTER TABLE ai_preferences_table ADD COLUMN routes TEXT NOT NULL DEFAULT '{}'",
        );
        await customStatement(
          'ALTER TABLE ai_preferences_table DROP COLUMN mode',
        );
        await customStatement(
          'ALTER TABLE ai_preferences_table DROP COLUMN overrides',
        );
      }
      if (from < 3) {
        // Notes no longer have drafts.
        await customStatement('DROP TABLE IF EXISTS note_drafts');
      }
      if (from < 4) {
        // One cloud provider: no stored tasks, routes, daily questions,
        // reply voices, diary conversations or note recovery copies.
        await customStatement('DROP TABLE IF EXISTS ai_job_receipts');
        await customStatement('DROP TABLE IF EXISTS daily_questions');
        await customStatement('DROP TABLE IF EXISTS note_ai_recoveries');
        for (final column in ['routes', 'daily_questions', 'reply_voice']) {
          await _dropColumn('ai_preferences_table', column);
        }
        await _dropColumn('diary_entries', 'conversation');
        await migrator.createTable(aiUsageMonths);
      }
      if (from < 5) {
        // Note websites live beside notes, outside their synced details.
        await migrator.createTable(noteWebsites);
      } else if (from < 6) {
        // Pages remember their own state and their previous version.
        await migrator.addColumn(noteWebsites, noteWebsites.state);
        await migrator.addColumn(noteWebsites, noteWebsites.previousHtml);
        await migrator.addColumn(noteWebsites, noteWebsites.previousSourceHash);
        await migrator.addColumn(noteWebsites, noteWebsites.syncChecks);
      }
      if (from < 7) {
        // Each note's Maester conversation, kept on this device only.
        await migrator.createTable(noteChatTurns);
      }
      if (from < 8) {
        // The Watchlist: synced titles, lists and taste, plus a local catalog
        // and conversations.
        await migrator.createTable(watchCatalog);
        await migrator.createTable(watchTitles);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS watch_titles_order '
          'ON watch_titles (updated_at DESC, id DESC)',
        );
        await migrator.createTable(watchLists);
        await migrator.createTable(watchProfiles);
        await migrator.createTable(watchChatTurns);
        await installSyncTriggers(this, only: watchlistSyncTables);
      }
      if (from < 9) {
        // Flow is gone; its tables take their triggers and index with them.
        // Quick thoughts now live in the diary as entries of kind 'thought'.
        await customStatement('DROP TABLE IF EXISTS flow_reflections');
        await customStatement('DROP TABLE IF EXISTS flow_thoughts');
        await customStatement(
          "DELETE FROM sync_operations WHERE type = 'thought'",
        );
        await customStatement(
          "DELETE FROM sync_records WHERE type = 'thought'",
        );
        if (!await _hasColumn('diary_entries', 'kind')) {
          await migrator.addColumn(diaryEntries, diaryEntries.kind);
        }
      }
      if (from < 10) {
        // The diary has no AI: no suggestions, photo questions, answers or
        // search by meaning. The search index itself goes in version 12.
        await customStatement('DROP TABLE IF EXISTS photo_question_cache');
        for (final event in ['insert', 'update', 'delete']) {
          await customStatement(
            'DROP TRIGGER IF EXISTS recall_diary_entries_$event',
          );
        }
      }
      if (from < 11) {
        // The diary search page shows the latest searches, kept locally.
        await migrator.createTable(diarySearchHistory);
      }
      if (from < 12) {
        // Notes have no AI search: no index, triggers or search preferences.
        // Notes are found by ordinary keyword search. Earlier versions also
        // indexed Flow thoughts and the diary; their entries go with it.
        for (final event in ['insert', 'update', 'delete']) {
          await customStatement('DROP TRIGGER IF EXISTS recall_notes_$event');
        }
        await customStatement('DROP TABLE IF EXISTS recall_queue');
        await customStatement('DROP TABLE IF EXISTS recall_manifests');
        await customStatement('DROP TABLE IF EXISTS ai_preferences_table');
      }
    },
  );

  Future<bool> _hasColumn(String table, String column) async =>
      (await customSelect(
        'PRAGMA table_info($table)',
      ).get()).any((c) => c.read<String>('name') == column);

  Future<void> _dropColumn(String table, String column) async {
    if (await _hasColumn(table, column)) {
      await customStatement('ALTER TABLE $table DROP COLUMN $column');
    }
  }
}

/// Lazy path lookup; SQLite work runs on Drift's managed background isolate.
AppDatabase openAppDatabase() => AppDatabase(
  LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return NativeDatabase.createInBackground(
      File.fromUri(directory.uri.resolve('redkeep.sqlite')),
    );
  }),
);
