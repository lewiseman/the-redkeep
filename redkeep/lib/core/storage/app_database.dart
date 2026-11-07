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
    AiJobReceipts,
    RecallQueue,
    RecallManifests,
    DailyQuestions,
    AppearanceSettings,
    OnboardingCompletion,
    Notes,
    NoteTags,
    NoteAiRecoveries,
    NoteMediaOps,
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
  int get schemaVersion => 3;

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
        await migrator.addColumn(aiPreferencesTable, aiPreferencesTable.routes);
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
    },
  );
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
