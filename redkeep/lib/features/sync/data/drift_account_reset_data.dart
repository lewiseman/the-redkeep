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
      await db.delete(db.noteMediaOps).go();
      await db.delete(db.noteTags).go();
      await db.delete(db.noteChatTurns).go();
      await db.delete(db.notes).go();
      await db.delete(db.diaryEntries).go();
      await db.delete(db.diaryMediaOps).go();
      await db.delete(db.diaryDays).go();
      await db.delete(db.diarySearchHistory).go();
      await db.delete(db.watchTitles).go();
      await db.delete(db.watchLists).go();
      await db.delete(db.watchCatalog).go();
      await db.delete(db.aiUsageMonths).go();
      // The provider and its key are wiped by aiResetProvider.
    });
  }
}
