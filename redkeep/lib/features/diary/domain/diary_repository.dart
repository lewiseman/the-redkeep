import 'civil_date.dart';
import 'diary_document.dart';

abstract interface class DiaryRepository {
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
    String search = '',
  });
  Stream<DiaryDay> watchDay(CivilDate date);
  Future<void> renameDay(DiaryDay day, String heading);
  Future<void> saveDay(DiaryDay day);
  Stream<OpenDiaryEntry> watchDocument(String id);
  Future<OpenDiaryEntry> openDocument(String id);
  Future<DiaryEntry> save({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int expectedRevision,
  });
  Future<void> deleteEntry(String id, int expectedRevision);
}
