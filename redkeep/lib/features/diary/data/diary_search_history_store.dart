import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// The person's latest diary searches, newest first, on this device only.
class DiarySearchHistoryStore {
  DiarySearchHistoryStore(this.db);
  final AppDatabase db;

  static const limit = 3;

  Stream<List<String>> watch() =>
      (db.select(db.diarySearchHistory)
            ..orderBy([(r) => OrderingTerm.desc(r.sequence)])
            ..limit(limit))
          .watch()
          .map((rows) => [for (final row in rows) row.query]);

  /// Moves [query] to the top, replacing a copy that differs only in case or
  /// spacing, and forgets anything past [limit].
  Future<void> record(String query) async {
    final value = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || db.writingBlocked) return;
    await db.transaction(() async {
      final key = value.toLowerCase();
      var next = 1;
      for (final row in await db.select(db.diarySearchHistory).get()) {
        if (row.sequence >= next) next = row.sequence + 1;
        if (row.query.toLowerCase() == key) await _remove(row.query);
      }
      await db
          .into(db.diarySearchHistory)
          .insert(
            DiarySearchHistoryCompanion.insert(query: value, sequence: next),
          );
      final older = await (db.select(
        db.diarySearchHistory,
      )..orderBy([(r) => OrderingTerm.desc(r.sequence)])).get();
      for (final row in older.skip(limit)) {
        await _remove(row.query);
      }
    });
  }

  Future<void> _remove(String query) => (db.delete(
    db.diarySearchHistory,
  )..where((r) => r.query.equals(query))).go();
}
