import 'diary_period.dart';
import 'diary_photo.dart';
import 'diary_day_details.dart';

class DiaryText {
  const DiaryText({this.body = ''});
  final String body;
  bool get isEmpty => body.trim().isEmpty;
}

/// What an entry is. A thought is a quick, text-only entry for today.
enum DiaryEntryKind {
  entry,
  thought;

  /// Unknown or missing kinds, such as from older devices, are ordinary entries.
  static DiaryEntryKind decode(Object? value) =>
      value == thought.name ? thought : entry;
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
    this.photos = const [],
    this.kind = DiaryEntryKind.entry,
  });
  final String id;
  final DiaryPeriod date;
  final DiaryText text;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<DiaryPhoto> photos;
  final DiaryEntryKind kind;
  bool get hasMedia => photos.isNotEmpty;
  bool get isThought => kind == DiaryEntryKind.thought;
}

class OpenDiaryEntry {
  const OpenDiaryEntry({this.entry});
  final DiaryEntry? entry;
  bool get available => entry != null && entry!.deletedAt == null;
  DiaryPeriod? get date => entry?.date;
}

/// Body-free list metadata; full documents load only when consumed.
class DiaryListing {
  const DiaryListing({required this.id, required this.date});
  final String id;
  final DiaryPeriod date;
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
  final DiaryPeriod date;
  final String heading;
  final DiaryMood? mood;
  final List<String> themes;
  final int revision;
}

typedef DiaryAddress = ({DiaryPeriod date, String id});
bool isDiaryId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum DiaryFailure { unavailable, staleRevision, empty, invalidHeading }

class DiaryException implements Exception {
  const DiaryException(this.failure);
  final DiaryFailure failure;
}
