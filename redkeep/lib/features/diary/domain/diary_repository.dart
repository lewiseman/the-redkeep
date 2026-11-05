import 'diary_period.dart';
import 'diary_photo.dart';
import 'diary_ai_conversation.dart';
import 'diary_day_details.dart';
import 'diary_document.dart';

abstract interface class DiaryRepository {
  Stream<Set<DiaryPeriod>> watchSavedPeriods();

  /// Every saved mood in one stream, so calendars never open a query per day.
  Stream<Map<DiaryPeriod, DiaryMood>> watchMoods();

  /// Every non-empty page title, for calendar overviews.
  Stream<Map<DiaryPeriod, String>> watchHeadings();
  Stream<List<DiaryListing>> watchEntries({
    DiaryPeriod? date,
    String search = '',
  });
  Stream<DiaryDay> watchDay(DiaryPeriod date);
  Future<void> renameDay(DiaryDay day, String heading);
  Future<void> saveDay(DiaryDay day, {String? expectedEntries});
  Stream<OpenDiaryEntry> watchDocument(String id);
  Future<OpenDiaryEntry> openDocument(String id);
  Future<DiaryEntry> save({
    required String id,
    required DiaryPeriod date,
    required DiaryText text,
    required int expectedRevision,
  });
  Future<DiaryEntry> savePhotoStory({
    required String id,
    required DiaryPeriod date,
    required List<DiaryPhoto> photos,
    required int expectedRevision,
  });
  Future<DiaryEntry> saveConversation({
    required String id,
    required DiaryPeriod date,
    required DiaryAiConversation conversation,
    required int expectedRevision,
    String? body,
  });
  Future<void> deleteEntry(String id, int expectedRevision);
}
