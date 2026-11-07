import 'dart:convert';

import 'diary_photo.dart';

void validateDiaryMedia(List<DiaryPhoto> photos) {
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
}
