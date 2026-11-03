import 'package:sync_wise/sync_wise.dart';

import '../../../core/storage/app_database.dart';

class DriftAccountResetData implements AccountResetLocalData {
  DriftAccountResetData(this.db);
  final AppDatabase db;
  @override
  Future<void> clear() async {
    await db.transaction(() async {
      await db.delete(db.noteTags).go();
      await db.delete(db.noteDrafts).go();
      await db.delete(db.notes).go();
      await db.delete(db.diaryDrafts).go();
      await db.delete(db.diaryEntries).go();
      await db.delete(db.diaryDays).go();
      await db.delete(db.flowDrafts).go();
      await db.delete(db.flowThoughts).go();
      await db.delete(db.syncOperations).go();
      await db.delete(db.syncRecords).go();
      await db.delete(db.syncValues).go();
    });
  }
}
