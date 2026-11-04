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
import '../../features/brain/data/brain_tables.dart';

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
    NoteDrafts,
    NoteTags,
    NoteAiRecoveries,
    NoteMediaOps,
    DiaryEntries,
    DiaryDays,
    DiaryMediaOps,
    PhotoQuestionCache,
    FlowThoughts,
    BrainAssignmentsTable,
    SyncOperations,
    SyncValues,
    SyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 14;

  // Reset changes this generation before disposing editors. Old repositories
  // cannot write after cleanup, even when an async continuation finishes late.
  int writingGeneration = 0;
  bool writingBlocked = false;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installSyncTriggers(this);
      await installRecallTriggers(this);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 14 && to >= 14) {
        if (from >= 3) {
          await migrator.addColumn(notes, notes.details);
          await migrator.addColumn(noteDrafts, noteDrafts.details);
        }
        await migrator.createTable(noteAiRecoveries);
        await migrator.createTable(noteMediaOps);
      }
      if (from < 13 && to >= 13) {
        if (from >= 5) {
          await migrator.addColumn(diaryEntries, diaryEntries.photos);
          await migrator.addColumn(diaryEntries, diaryEntries.conversation);
        }
        await migrator.createTable(diaryMediaOps);
        await migrator.createTable(photoQuestionCache);
      }
      if (from < 12 && to >= 12) {
        await migrator.createTable(aiPreferencesTable);
        await migrator.createTable(aiJobReceipts);
        await migrator.createTable(recallQueue);
        await migrator.createTable(recallManifests);
        await migrator.createTable(dailyQuestions);
      }
      if (from < 2 && to >= 2) {
        await migrator.createTable(onboardingCompletion);
      }
      if (from < 3 && to >= 3) {
        await migrator.createTable(notes);
        await migrator.createTable(noteDrafts);
      }
      if (from < 4 && to >= 4) {
        if (from >= 3) await migrator.addColumn(notes, notes.pinned);
        await migrator.createTable(noteTags);
      }
      if (from < 5 && to >= 5) {
        await migrator.createTable(diaryEntries);
        await migrator.createTable(diaryDays);
        await migrator.createIndex(diaryEntriesDayOrder);
      }
      if (from < 6 && to >= 6) {
        await migrator.createTable(flowThoughts);
        await migrator.createIndex(flowThoughtsOrder);
      }
      if (from < 7 && to >= 7) {
        await migrator.createTable(brainAssignmentsTable);
      }
      if (from < 9 && to >= 9) {
        await migrator.createTable(syncOperations);
        await migrator.createTable(syncValues);
        await migrator.createTable(syncRecords);
        await installSyncTriggers(this);
        await seedSyncRecords(this);
      }
      if (from < 10 && to >= 10) {
        await migrator.addColumn(appearanceSettings, appearanceSettings.accent);
        await migrator.addColumn(
          appearanceSettings,
          appearanceSettings.fontFamily,
        );
        await migrator.addColumn(
          appearanceSettings,
          appearanceSettings.diaryTitleFontFamily,
        );
        await migrator.addColumn(
          appearanceSettings,
          appearanceSettings.diaryBodyFontFamily,
        );
      }
      // Earlier upgrades create diary_days with the current columns already.
      if (from >= 5 && from < 11 && to >= 11) {
        await migrator.addColumn(diaryDays, diaryDays.mood);
        await migrator.addColumn(diaryDays, diaryDays.themes);
      }
      if (from < 12 && to >= 12) {
        if (from >= 7) {
          await customStatement(
            'ALTER TABLE brain_assignments RENAME TO brain_assignments_old',
          );
          await migrator.createTable(brainAssignmentsTable);
          await customStatement(
            'INSERT INTO brain_assignments SELECT * FROM brain_assignments_old',
          );
          await customStatement('DROP TABLE brain_assignments_old');
        }
        await installRecallTriggers(this);
        await seedRecallQueue(this);
      }
      // createTable above already uses the current columns for version 1.
      if (from >= 2 && from < 8 && to >= 8) {
        await migrator.addColumn(
          onboardingCompletion,
          onboardingCompletion.name,
        );
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
