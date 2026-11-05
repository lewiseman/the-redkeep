import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import '../domain/diary_photo.dart';
import '../domain/diary_repository.dart';
import 'diary_photo_store.dart';

class DiaryPhotoDraft {
  DiaryPhotoDraft({
    String? id,
    this.path,
    required this.bytes,
    this.sha256 = '',
    this.sourceExtension = '',
  }) : id = id ?? const Uuid().v4();
  final String id;
  final String? path;
  final Uint8List bytes;
  final String sha256, sourceExtension;
  bool get missing => bytes.isEmpty;
}

class DiaryPhotoStories {
  DiaryPhotoStories(this.repository, this.store);
  final DiaryRepository repository;
  final DiaryPhotoStore store;
  Future<DiaryEntry> save({
    required String dateString,
    required List<
      ({
        DiaryPhotoDraft draft,
        String caption,
        List<DiaryPhotoReflection> reflections,
        String seen,
      })
    >
    photos,
    String? existingItemUuid,
    String? newItemUuid,
    int? expectedRevision,
  }) async {
    final id =
        existingItemUuid ??
        newItemUuid ??
        const Uuid().v4().replaceAll('-', '');
    final written = <String>[];
    var committed = false;
    try {
      final saved = <DiaryPhoto>[];
      for (final photo in photos) {
        var path = photo.draft.path;
        if (path == null) {
          path = await store.write(
            photo.draft.id,
            photo.draft.bytes,
            extension: photo.draft.sourceExtension,
            owner: id,
          );
          written.add(path);
        }
        saved.add(
          DiaryPhoto(
            id: photo.draft.id,
            path: path,
            sha256: photo.draft.sha256.isNotEmpty
                ? photo.draft.sha256
                : await DiaryPhotoStore.digest(photo.draft.bytes),
            caption: photo.caption.trim(),
            reflections: photo.reflections
                .where((r) => r.answer.trim().isNotEmpty)
                .toList(),
            seen: photo.seen.trim(),
          ),
        );
      }
      final entry = await repository.savePhotoStory(
        id: id,
        date: DiaryPeriod.tryParse(dateString)!,
        photos: saved,
        expectedRevision: expectedRevision ?? 0,
      );
      committed = true;
      store.releaseStaged(written);
      // Cleanup is retryable and must never turn a committed save into rollback.
      try {
        await store.reconcile();
      } catch (_) {
        /* durable journal retries */
      }
      return entry;
    } catch (_) {
      store.releaseStaged(written);
      if (!committed) {
        try {
          await store.delete(written);
        } catch (_) {
          /* journal */
        }
      }
      rethrow;
    }
  }

  Future<List<DiaryPhotoDraft>> open(DiaryEntry item) async => [
    for (final photo in item.photos)
      DiaryPhotoDraft(
        id: photo.id,
        path: photo.path,
        bytes:
            await store.read(photo.path, expectedHash: photo.sha256) ??
            Uint8List(0),
        sha256: photo.sha256,
        sourceExtension: p.extension(photo.path),
      ),
  ];
}
