import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

import 'dart:async';

import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_repository.dart';

/// Failure/commit gates wrap a disposable repository, never user storage.
class ControlledDiaryRepository implements DiaryRepository {
  ControlledDiaryRepository(this.inner);
  final DiaryRepository inner;
  bool failCommit = false;
  bool failRead = false;
  Completer<void>? commitGate;
  int commits = 0;

  @override
  Stream<Set<DiaryPeriod>> watchSavedPeriods() => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchSavedPeriods();

  @override
  Future<DiaryEntry> save({
    required String id,
    required DiaryPeriod date,
    required DiaryText text,
    required int expectedRevision,
  }) async {
    commits++;
    await commitGate?.future;
    if (failCommit) throw StateError('synthetic save failure');
    return inner.save(
      id: id,
      date: date,
      text: text,
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<OpenDiaryEntry> openDocument(String id) async {
    if (failRead) throw StateError('synthetic read failure');
    return inner.openDocument(id);
  }

  @override
  Stream<OpenDiaryEntry> watchDocument(String id) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDocument(id);
  @override
  Stream<List<DiaryListing>> watchEntries({
    DiaryPeriod? date,
    String search = '',
  }) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchEntries(date: date, search: search);
  @override
  Future<DiaryEntry> savePhotoStory({
    required String id,
    required DiaryPeriod date,
    required List<DiaryPhoto> photos,
    required int expectedRevision,
  }) => inner.savePhotoStory(
    id: id,
    date: date,
    photos: photos,
    expectedRevision: expectedRevision,
  );
  @override
  Future<DiaryEntry> saveConversation({
    required String id,
    required DiaryPeriod date,
    required DiaryAiConversation conversation,
    required int expectedRevision,
    String? body,
  }) => inner.saveConversation(
    id: id,
    date: date,
    conversation: conversation,
    expectedRevision: expectedRevision,
    body: body,
  );
  @override
  Future<void> deleteEntry(String id, int expectedRevision) =>
      inner.deleteEntry(id, expectedRevision);
  @override
  Stream<DiaryDay> watchDay(DiaryPeriod date) => failRead
      ? Stream.error(StateError('synthetic read failure'))
      : inner.watchDay(date);
  @override
  Future<void> renameDay(DiaryDay day, String heading) =>
      inner.renameDay(day, heading);
  @override
  Future<void> saveDay(DiaryDay day, {String? expectedEntries}) =>
      inner.saveDay(day, expectedEntries: expectedEntries);
}
