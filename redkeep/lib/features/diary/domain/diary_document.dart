import 'civil_date.dart';
import 'diary_photo.dart';
import 'diary_ai_conversation.dart';
import 'diary_day_details.dart';

class DiaryText {
  const DiaryText({this.body = ''});
  final String body;
  bool get isEmpty => body.trim().isEmpty;
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
    this.conversation,
  });
  final String id;
  final CivilDate date;
  final DiaryText text;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<DiaryPhoto> photos;
  final DiaryAiConversation? conversation;
  bool get hasMedia => photos.isNotEmpty || conversation != null;
}

class OpenDiaryEntry {
  const OpenDiaryEntry({this.entry});
  final DiaryEntry? entry;
  bool get available => entry != null && entry!.deletedAt == null;
  CivilDate? get date => entry?.date;
}

/// Body-free list metadata; full documents load only when consumed.
class DiaryListing {
  const DiaryListing({required this.id, required this.date});
  final String id;
  final CivilDate date;
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
bool isDiaryId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

enum DiaryFailure { unavailable, staleRevision, empty, invalidHeading }

class DiaryException implements Exception {
  const DiaryException(this.failure);
  final DiaryFailure failure;
}
