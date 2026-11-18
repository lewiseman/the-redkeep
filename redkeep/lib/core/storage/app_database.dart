import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sync_wise/sync_wise.dart' show BackupConfig, RestoreRecovery;

import '../../features/ai/data/ai_tables.dart';

import '../../features/appearance/data/appearance_table.dart';
import '../../features/onboarding/data/onboarding_table.dart';
import '../../features/notes/data/notes_tables.dart';
import '../../features/diary/data/diary_tables.dart';
import '../../features/watchlist/data/watchlist_tables.dart';

import '../../features/sync/data/backup_identity.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AiUsageMonths,
    AppearanceSettings,
    OnboardingCompletion,
    Notes,
    NoteTags,
    NoteMediaOps,
    DiaryEntries,
    DiaryDays,
    DiaryMediaOps,
    DiarySearchHistory,
    WatchCatalog,
    WatchTitles,
    WatchLists,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Also recorded with each backup; newer backups are refused on restore.
  static const currentSchemaVersion = 16;

  @override
  int get schemaVersion => currentSchemaVersion;

  // Reset and restore change this generation before disposing editors. Old
  // repositories cannot write afterwards, even when an async continuation
  // finishes late.
  int writingGeneration = 0;
  bool writingBlocked = false;

  /// Closes the SQLite connection so a restore can replace the file.
  ///
  /// Unlike [close], this does not wait for query streams to finish: Riverpod
  /// pauses streams nobody watches, and a paused stream never finishes, so
  /// [close] would wait forever while the restore screen hides every page.
  /// Those streams belong to providers rebuilt on the restored database.
  Future<void> closeConnection() => executor.close();

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
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
      // Version 7 added each note's Maester conversation; version 16 drops
      // it again.
      if (from < 8) {
        // The Watchlist: titles and lists, plus a local catalog. Its taste
        // profile and title conversations were removed in version 14.
        await migrator.createTable(watchCatalog);
        await migrator.createTable(watchTitles);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS watch_titles_order '
          'ON watch_titles (updated_at DESC, id DESC)',
        );
        await migrator.createTable(watchLists);
      }
      if (from < 9) {
        // Flow is gone; its tables take their triggers and index with them.
        // Quick thoughts now live in the diary as entries of kind 'thought'.
        await customStatement('DROP TABLE IF EXISTS flow_reflections');
        await customStatement('DROP TABLE IF EXISTS flow_thoughts');
        for (final table in ['sync_operations', 'sync_records']) {
          // Dropped again in version 13; absent when created after it.
          if (await _hasTable(table)) {
            await customStatement("DELETE FROM $table WHERE type = 'thought'");
          }
        }
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
      if (from < 13) {
        // Per-document sync is replaced by whole-database backups: no outbox,
        // sync state or device roles. Writing itself is untouched.
        for (final table in _formerlySyncedTables) {
          for (final event in ['insert', 'update', 'delete']) {
            await customStatement(
              'DROP TRIGGER IF EXISTS sync_${table}_$event',
            );
          }
        }
        for (final table in [
          'sync_operations',
          'sync_values',
          'sync_records',
        ]) {
          await customStatement('DROP TABLE IF EXISTS $table');
        }
      }
      if (from < 14) {
        // The Watchlist is plain lists: no Discover taste, matches, nights,
        // title conversations, ratings or notes. Titles only swiped in
        // Discover go with them; anything with episodes ticked or in a list
        // stays.
        await customStatement('DROP TABLE IF EXISTS watch_profiles');
        await customStatement('DROP TABLE IF EXISTS watch_chat_turns');
        if (await _hasColumn('watch_titles', 'swipe')) {
          final listed = <String>{};
          for (final row in await customSelect(
            'SELECT items FROM watch_lists WHERE deleted_at IS NULL',
          ).get()) {
            final items = jsonDecode(row.read<String>('items'));
            if (items is List) listed.addAll(items.whereType<String>());
          }
          final swiped = await customSelect(
            'SELECT id FROM watch_titles WHERE status IS NULL '
            "AND swipe IS NOT NULL AND episodes = '[]'",
          ).get();
          for (final row in swiped) {
            final id = row.read<String>('id');
            if (listed.contains(id)) continue;
            await customStatement('DELETE FROM watch_titles WHERE id = ?', [
              id,
            ]);
          }
        }
        for (final column in [
          'swipe',
          'match_state',
          'matched_at',
          'expires_at',
          'night_at',
          'outcome',
          'checked_in_at',
          'rating',
          'note',
        ]) {
          await _dropColumn('watch_titles', column);
        }
      }
      if (from < 15) {
        // Note websites are gone.
        await customStatement('DROP TABLE IF EXISTS note_websites');
      }
      if (from < 16) {
        // The Maester keeps no conversations: each request stands alone.
        await customStatement('DROP TABLE IF EXISTS note_chat_turns');
      }
    },
  );

  static const _formerlySyncedTables = [
    'notes',
    'diary_entries',
    'diary_days',
    'note_tags',
    'watch_titles',
    'watch_lists',
    'watch_profiles',
  ];

  Future<bool> _hasTable(String table) async => (await customSelect(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
    variables: [Variable(table)],
  ).get()).isNotEmpty;

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

/// The live database file, also read by backups from background isolates.
Future<File> appDatabaseFile() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return File.fromUri(directory.uri.resolve('redkeep.sqlite'));
}

/// Lazy path lookup; SQLite work runs on Drift's managed background isolate.
/// A restore interrupted by a crash is finished before the file is opened.
AppDatabase openAppDatabase() => AppDatabase(
  LazyDatabase(() async {
    final file = await appDatabaseFile();
    await RestoreRecovery.finish(
      stateDirectory: await BackupConfig.defaultStateDirectory(backupAppId),
      databasePath: file.path,
    );
    return NativeDatabase.createInBackground(file);
  }),
);
