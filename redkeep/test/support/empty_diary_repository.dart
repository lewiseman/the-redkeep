import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_repository.dart';

/// Keeps shell tests independent of application-owned storage. Writing tests
/// explicitly inject a disposable real repository instead.
class EmptyDiaryRepository implements DiaryRepository {
  @override
  Stream<Set<DiaryPeriod>> watchSavedPeriods() => Stream.value(const {});
  @override
  Stream<List<DiaryListing>> watchEntries({
    DiaryPeriod? date,
    String search = '',
  }) => Stream.value(const []);
  @override
  Stream<DiaryDay> watchDay(DiaryPeriod date) =>
      Stream.value(DiaryDay(date: date));
  @override
  Stream<OpenDiaryEntry> watchDocument(String id) =>
      Stream.value(const OpenDiaryEntry());
  @override
  Future<OpenDiaryEntry> openDocument(String id) async =>
      const OpenDiaryEntry();
  @override
  Future<void> renameDay(DiaryDay day, String heading) async =>
      throw StateError('Inject writing repository');
  @override
  Future<void> saveDay(DiaryDay day, {String? expectedEntries}) async =>
      throw StateError('Inject writing repository');
  @override
  Future<DiaryEntry> save({
    required String id,
    required DiaryPeriod date,
    required DiaryText text,
    required int expectedRevision,
  }) async => throw StateError('Inject writing repository');
  @override
  Future<DiaryEntry> savePhotoStory({
    required String id,
    required DiaryPeriod date,
    required List<DiaryPhoto> photos,
    required int expectedRevision,
  }) => Future.error(StateError('Inject writing repository'));
  @override
  Future<DiaryEntry> saveConversation({
    required String id,
    required DiaryPeriod date,
    required DiaryAiConversation conversation,
    required int expectedRevision,
    String? body,
  }) => Future.error(StateError('Inject writing repository'));
  @override
  Future<void> deleteEntry(String id, int expectedRevision) async =>
      throw StateError('Inject writing repository');
}
