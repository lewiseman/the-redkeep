import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/appearance/data/appearance_table.dart';
import '../../features/onboarding/data/onboarding_table.dart';
import '../../features/notes/data/notes_tables.dart';
import '../../features/diary/data/diary_tables.dart';
import '../../features/flow/data/flow_tables.dart';
import '../../features/brain/data/brain_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppearanceSettings,
    OnboardingCompletion,
    Notes,
    NoteDrafts,
    NoteTags,
    DiaryEntries,
    DiaryDrafts,
    DiaryDays,
    FlowThoughts,
    FlowDrafts,
    BrainAssignmentsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
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
        await migrator.createTable(diaryDrafts);
        await migrator.createTable(diaryDays);
        await migrator.createIndex(diaryEntriesDayOrder);
      }
      if (from < 6 && to >= 6) {
        await migrator.createTable(flowThoughts);
        await migrator.createTable(flowDrafts);
        await migrator.createIndex(flowThoughtsOrder);
        await migrator.createIndex(flowSingleCapture);
      }
      if (from < 7 && to >= 7) {
        await migrator.createTable(brainAssignmentsTable);
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
