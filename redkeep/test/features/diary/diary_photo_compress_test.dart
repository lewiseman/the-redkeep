import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/diary_photo_stories.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

final _webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 9, //
]);

void main() {
  test('picked photo drafts hash and store the compressed bytes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final directory = await Directory.systemTemp.createTemp('redkeep-diary-');
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      ...List.filled(64, 7),
    ]);
    final draft = await DiaryPhotoDraft.compressed(
      png,
      encoder: (bytes, {required longEdge, required quality}) async => _webp,
    );
    final hash = sha256.convert(_webp).toString();
    expect(draft.bytes, _webp);
    expect(draft.sha256, hash);
    expect(draft.sourceExtension, '.webp');

    final store = DiaryPhotoStore(
      db: db,
      supportDirectory: () async => directory,
    );
    final entry =
        await DiaryPhotoStories(
          DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 4)),
          store,
        ).save(
          dateString: DiaryPeriod(2026, 11, 4).key,
          newItemUuid: '2' * 32,
          photos: [
            (draft: draft, caption: '', reflections: const [], seen: ''),
          ],
        );
    final photo = entry.photos.single;
    expect(photo.sha256, hash);
    expect(photo.path, endsWith('-$hash.webp'));
    expect(await store.read(photo.path, expectedHash: hash), _webp);
  });
}
