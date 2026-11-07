import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/ai/data/ai_tables.dart';
import '../../features/ai/data/recall_schema.dart';

import '../../features/appearance/data/appearance_table.dart';
import '../../features/onboarding/data/onboarding_table.dart';
import '../../features/notes/data/notes_tables.dart';
import '../../features/diary/data/diary_tables.dart';
import '../../features/flow/data/flow_tables.dart';

import '../../features/sync/data/sync_tables.dart';
import '../../features/sync/data/sync_schema.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AiPreferencesTable,
    AiUsageMonths,
    RecallQueue,
    RecallManifests,
    AppearanceSettings,
    OnboardingCompletion,
    Notes,
    NoteTags,
    NoteMediaOps,
    NoteWebsites,
    DiaryEntries,
    DiaryDays,
    DiaryMediaOps,
    PhotoQuestionCache,
    FlowThoughts,
    FlowReflections,
    SyncOperations,
    SyncValues,
    SyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  // Reset changes this generation before disposing editors. Old repositories
  // cannot write after cleanup, even when an async continuation finishes late.
  int writingGeneration = 0;
  bool writingBlocked = false;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installFlowReflectionCleanup(this);
      await installSyncTriggers(this);
      await installRecallTriggers(this);
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
    },
  );

  Future<void> _dropColumn(String table, String column) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    if (columns.any((c) => c.read<String>('name') == column)) {
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
