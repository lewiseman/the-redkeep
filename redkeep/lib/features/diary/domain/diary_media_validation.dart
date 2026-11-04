import 'dart:convert';

import 'diary_ai_conversation.dart';
import 'diary_photo.dart';

void validateDiaryMedia(
  List<DiaryPhoto> photos,
  DiaryAiConversation? conversation,
) {
  if (photos.length > 100 ||
      utf8.encode(jsonEncode([for (final p in photos) p.toJson()])).length >
          1000000) {
    throw const FormatException('Photo story is too large.');
  }
  final ids = <String>{};
  for (final photo in photos) {
    if (!ids.add(photo.id) ||
        !RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(photo.id) ||
        !RegExp(r'^diary_photos/[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,5}$')
            .hasMatch(photo.path) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(photo.sha256)) {
      throw const FormatException('Invalid photo reference.');
    }
  }
  if (conversation != null &&
      (photos.isNotEmpty ||
          !conversation.hasUserTurn ||
          conversation.turns.length > 24 ||
          utf8.encode(jsonEncode(conversation.toJson())).length > 131072 ||
          conversation.turns.any(
            (turn) =>
                !{'user', 'assistant'}.contains(turn['speaker']) ||
                turn['text'] == null ||
                turn['text']!.trim().isEmpty,
          ))) {
    throw const FormatException('Invalid conversation.');
  }
}
