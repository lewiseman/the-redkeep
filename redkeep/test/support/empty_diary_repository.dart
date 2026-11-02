import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_repository.dart';

/// Keeps shell tests independent of application-owned storage. Writing tests
/// explicitly inject a disposable real repository instead.
class EmptyDiaryRepository implements DiaryRepository {
  @override
  Stream<List<DiaryListing>> watchDrafts() => Stream.value(const []);
  @override
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
    String search = '',
  }) => Stream.value(const []);
  @override
  Stream<DiaryDay> watchDay(CivilDate date) =>
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
  Future<DiaryDraft> putDraft({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async => throw StateError('Inject writing repository');
  @override
  Future<DiaryEntry> commitDraft(String id, int expectedDraftRevision) async =>
      throw StateError('Inject writing repository');
  @override
  Future<void> deleteEntry(String id, int expectedRevision) async =>
      throw StateError('Inject writing repository');
  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) async =>
      throw StateError('Inject writing repository');
}
