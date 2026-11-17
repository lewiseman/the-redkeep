import '../../../core/storage/app_database.dart';

/// Called inside each local write transaction. Account reset and restore
/// replace the database underneath open editors; they block writing and bump
/// the generation so a late write from an old editor fails instead of
/// landing in the wrong data.
Future<void> checkWritingSession(AppDatabase db, int generation) async {
  if (db.writingBlocked || db.writingGeneration != generation) {
    throw StateError(
      'Your journal was reset or restored while this page was open. Reopen the page.',
    );
  }
}
