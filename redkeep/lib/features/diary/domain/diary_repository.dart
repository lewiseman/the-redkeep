import 'civil_date.dart';
import 'diary_document.dart';

abstract interface class DiaryRepository {
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
    String search = '',
  });
  Stream<List<DiaryListing>> watchDrafts();
  Stream<DiaryDay> watchDay(CivilDate date);
  Future<void> renameDay(DiaryDay day, String heading);
  Stream<OpenDiaryEntry> watchDocument(String id);
  Future<OpenDiaryEntry> openDocument(String id);
  Future<DiaryDraft> putDraft({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int baseRevision,
    required int? expectedDraftRevision,
  });
  Future<DiaryEntry> commitDraft(String id, int expectedDraftRevision);

  /// Tombstones retain stale-write protection and independent recovery drafts.
  Future<void> deleteEntry(String id, int expectedRevision);
  Future<void> discardDraft(String id, int expectedDraftRevision);
}
