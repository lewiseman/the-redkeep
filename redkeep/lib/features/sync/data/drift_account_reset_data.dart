import 'package:sync_wise/sync_wise.dart';

import '../../../core/storage/app_database.dart';

class DriftAccountResetData implements AccountResetLocalData {
  DriftAccountResetData(this.db, {this.beforeClear});
  final Future<void> Function()? beforeClear;
  final AppDatabase db;
  @override
  Future<void> clear() async {
    await beforeClear?.call();
    await db.transaction(() async {
      await db.delete(db.noteAiRecoveries).go();
      await db.delete(db.noteMediaOps).go();
      await db.delete(db.noteTags).go();
      await db.delete(db.noteDrafts).go();
      await db.delete(db.notes).go();
      await db.delete(db.diaryEntries).go();
      await db.delete(db.diaryMediaOps).go();
      await db.delete(db.photoQuestionCache).go();
      await db.delete(db.diaryDays).go();
      await db.delete(db.flowThoughts).go();
      await db.delete(db.syncOperations).go();
      await db.delete(db.syncRecords).go();
      await db.delete(db.syncValues).go();
      await db.delete(db.aiJobReceipts).go();
      await db.delete(db.dailyQuestions).go();
      await db.delete(db.recallQueue).go();
      await db.delete(db.recallManifests).go();
    });
  }
}
