export '../../../../core/presentation/media_motion.dart';

export 'dart:typed_data';

export 'package:flutter/material.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../../../core/presentation/diary_typography.dart';
export '../diary_style.dart' show TimeHelper, TimeFormat;
export '../../domain/diary_document.dart';
export '../../domain/diary_photo.dart';
export '../../application/diary_media_providers.dart';

import 'package:flutter/material.dart';

import '../../domain/diary_document.dart';

typedef DiaryItem = DiaryEntry;

extension PhotoContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
}

extension PhotoEntryUi on DiaryEntry {
  String get itemUuid => id;
  String get content => text.body;
  List<String> get attachmentPaths => photos.map((p) => p.path).toList();
}
