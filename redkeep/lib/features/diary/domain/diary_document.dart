import 'civil_date.dart';
import 'diary_day_details.dart';

class DiaryText {
  const DiaryText({this.title = '', this.body = ''});
  final String title;
  final String body;
  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;
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

class OpenDiaryEntry {
  const OpenDiaryEntry({this.entry});
  final DiaryEntry? entry;
  bool get available => entry != null && entry!.deletedAt == null;
  CivilDate? get date => entry?.date;
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

/// Optional day details. Never contains entries or controls their dates.
class DiaryDay {
  const DiaryDay({
    required this.date,
    this.heading = '',
    this.mood,
    this.themes = const [],
    this.revision = 0,
  });
  final CivilDate date;
  final String heading;
  final DiaryMood? mood;
  final List<String> themes;
  final int revision;
}

typedef DiaryAddress = ({CivilDate date, String id});
String diaryTitle(String title) =>
    title.trim().isEmpty ? 'Untitled entry' : title;
bool isDiaryId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum DiaryFailure { unavailable, staleRevision, empty, invalidHeading }

class DiaryException implements Exception {
  const DiaryException(this.failure);
  final DiaryFailure failure;
}
