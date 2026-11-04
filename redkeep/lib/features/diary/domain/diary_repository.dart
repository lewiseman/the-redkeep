import 'civil_date.dart';
import 'diary_photo.dart';
import 'diary_ai_conversation.dart';
import 'diary_document.dart';

abstract interface class DiaryRepository {
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
    String search = '',
  });
  Stream<DiaryDay> watchDay(CivilDate date);
  Future<void> renameDay(DiaryDay day, String heading);
  Future<void> saveDay(DiaryDay day, {String? expectedEntries});
  Stream<OpenDiaryEntry> watchDocument(String id);
  Future<OpenDiaryEntry> openDocument(String id);
  Future<DiaryEntry> save({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int expectedRevision,
  });
  Future<DiaryEntry> savePhotoStory({
    required String id,
    required CivilDate date,
    required List<DiaryPhoto> photos,
    required int expectedRevision,
  });
  Future<DiaryEntry> saveConversation({
    required String id,
    required CivilDate date,
    required DiaryAiConversation conversation,
    required int expectedRevision,
    String? body,
  });
  Future<void> deleteEntry(String id, int expectedRevision);
}
