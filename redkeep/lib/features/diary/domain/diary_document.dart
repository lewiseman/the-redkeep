import 'civil_date.dart';

class DiaryText {
  const DiaryText({this.title = '', this.body = ''});
  final String title;
  final String body;
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  final String id;
  final CivilDate date;
  final DiaryText text;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class DiaryDraft {
  const DiaryDraft({
    required this.id,
    required this.date,
    required this.text,
    required this.baseRevision,
    required this.draftRevision,
    required this.updatedAt,
  });
  final String id;
  final CivilDate date;
  final DiaryText text;
  final int baseRevision;
  final int draftRevision;
  final DateTime updatedAt;
}

class OpenDiaryEntry {
  const OpenDiaryEntry({this.entry, this.draft});
  final DiaryEntry? entry;
  final DiaryDraft? draft;
  bool get available => entry != null && entry!.deletedAt == null;
  CivilDate? get date => entry?.date ?? draft?.date;
}

/// Body-free list metadata; full documents load only when consumed.
class DiaryListing {
  const DiaryListing({
    required this.id,
    required this.date,
    required this.title,
  });
  final String id;
  final CivilDate date;
  final String title;
}

/// Optional notebook heading. Never contains entries or controls their dates.
class DiaryDay {
  const DiaryDay({required this.date, this.heading = '', this.revision = 0});
  final CivilDate date;
  final String heading;
  final int revision;
}

typedef DiaryAddress = ({CivilDate date, String id});
String diaryTitle(String title) =>
    title.trim().isEmpty ? 'Untitled entry' : title;
bool isDiaryId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum DiaryFailure { unavailable, staleRevision, draftChanged, invalidHeading }

class DiaryException implements Exception {
  const DiaryException(this.failure);
  final DiaryFailure failure;
}
