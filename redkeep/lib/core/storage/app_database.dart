import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/appearance/data/appearance_table.dart';
import '../../features/onboarding/data/onboarding_table.dart';
import '../../features/notes/data/notes_tables.dart';
import '../../features/diary/data/diary_tables.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

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
