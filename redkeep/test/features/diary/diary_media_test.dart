import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/diary_photo_stories.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';

const id = '11111111111111111111111111111111';
final date = CivilDate(2026, 11, 4);
final turn = DiaryAiConversation(
  turns: const [
    {'speaker': 'assistant', 'text': 'Assistant private words'},
    {'speaker': 'user', 'text': 'Original spoken words'},
  ],
  createdAt: DateTime.utc(2026, 11, 4),
);
void main() {
  late AppDatabase db;
  late DriftDiaryRepository repo;
  late Directory directory;
  late DiaryPhotoStore store;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 4));
    directory = await Directory.systemTemp.createTemp('redkeep-media-test-');
    store = DiaryPhotoStore(db: db, supportDirectory: () async => directory);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<DiaryEntry> photoStory({String? existing, int revision = 0}) =>
      DiaryPhotoStories(repo, store).save(
        dateString: date.key,
        newItemUuid: id,
        existingItemUuid: existing,
        expectedRevision: revision,
        photos: [
          (
            draft: DiaryPhotoDraft(
              id: 'photo-111111',
              bytes: Uint8List.fromList([1, 2, 3]),
              sourceExtension: '.png',
            ),
            caption: 'My caption',
            reflections: const [
              DiaryPhotoReflection(
                question: 'Private prompt',
                answer: 'My reflection',
              ),
            ],
            seen: 'AI observation',
          ),
        ],
      );
  test(
    'rich entries round trip; only reviewed words enter the text projection',
    () async {
      final entry = await photoStory();
      expect(entry.text.body, 'My caption\n\nMy reflection');
      expect(entry.photos.single.seen, 'AI observation');
      expect((await repo.watchEntries(search: 'observation').first), isEmpty);
      expect(
        (await repo.watchEntries(search: 'reflection').first).single.id,
        id,
      );
      expect(
        await store.read(
          entry.photos.single.path,
          expectedHash: entry.photos.single.sha256,
        ),
        [1, 2, 3],
      );
      expect(await db.select(db.diaryMediaOps).get(), isEmpty);
      await expectLater(
        repo.save(
          id: id,
          date: date,
          text: const DiaryText(body: 'overwrite'),
          expectedRevision: 1,
        ),
        throwsException,
      );
      expect(
        (await repo.openDocument(id)).entry!.photos.single.caption,
        'My caption',
      );
    },
  );
  test(
    'photo-only and turn-only entries are valid; text editing preserves turns',
    () async {
      final saved = await repo.saveConversation(
        id: id,
        date: date,
        conversation: turn,
        expectedRevision: 0,
      );
      expect(saved.text.isEmpty, isTrue);
      expect((await repo.watchEntries(search: 'spoken').first), isEmpty);
      final edited = await repo.save(
        id: id,
        date: date,
        text: const DiaryText(body: 'Reviewed draft'),
        expectedRevision: 1,
      );
      expect(edited.conversation!.turns, turn.turns);
      expect(
        (await repo.openDocument(id)).entry!.conversation!.turns,
        turn.turns,
      );
      await expectLater(
        repo.saveConversation(
          id: id,
          date: date,
          conversation: turn,
          body: 'stale',
          expectedRevision: 1,
        ),
        throwsException,
      );
      expect((await repo.openDocument(id)).entry!.text.body, 'Reviewed draft');
    },
  );
  test('failed save deletes staged copies; committed removal is journaled and retryable', () async {
    final entry = await photoStory();
    await expectLater(photoStory(existing: id, revision: 0), throwsException);
    expect(await store.read(entry.photos.single.path), [1, 2, 3]);
    await repo.deleteEntry(id, 1);
    expect(
      (await repo.openDocument(id)).entry!.photos.single.caption,
      'My caption',
    );
    expect(await repo.watchEntries(search: 'caption').first, isEmpty);
    expect(await db.select(db.diaryMediaOps).get(), isNotEmpty);
    await store.reconcile();
    expect(await store.read(entry.photos.single.path), isNull);
    expect(await db.select(db.diaryMediaOps).get(), isEmpty);
  });
  test(
    'interrupted staging recovers; invalid paths never touch gallery originals',
    () async {
      final path = await store.write(
        'orphan-111111',
        Uint8List.fromList([4, 5, 6]),
        owner: id,
      );
      final fresh = DiaryPhotoStore(
        db: db,
        supportDirectory: () async => directory,
      );
      await fresh.reconcile();
      expect(await fresh.read(path), isNull);
      final original = File('${directory.path}/gallery.png');
      await original.writeAsBytes([9]);
      await fresh.delete(['../gallery.png', original.path]);
      expect(await original.readAsBytes(), [9]);
      expect(await fresh.resolve('../gallery.png'), isNull);
      await expectLater(
        repo.savePhotoStory(
          id: id,
          date: date,
          photos: [
            DiaryPhoto(
              id: 'photo-111111',
              path: '../gallery.png',
              sha256: 'a' * 64,
            ),
          ],
          expectedRevision: 0,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'missing and corrupt copies retain captions; reset fences late writes',
    () async {
      final entry = await photoStory();
      await File('${directory.path}/${entry.photos.single.path}')
          .writeAsBytes([0]);
      expect(
        (await DiaryPhotoStories(repo, store).open(entry)).single.missing,
        isTrue,
      );
      expect(
        (await repo.openDocument(id)).entry!.photos.single.caption,
        'My caption',
      );
      await store.clearAll();
      await expectLater(
        store.write('late-111111', Uint8List.fromList([1])),
        throwsStateError,
      );
      expect(
        await Directory('${directory.path}/diary_photos').exists(),
        isFalse,
      );
    },
  );
  test(
    'diary sync v2 preserves metadata without media bytes; v1 normalizes',
    () async {
      final entry = await photoStory();
      final collection = DriftSyncCollection(db, 'diary');
      final document = (await collection.read(date.key))!;
      expect(document.payload['schema'], 2);
      final payload = document.payload;
      expect(jsonEncode(payload), isNot(contains('base64')));
      final other = AppDatabase(NativeDatabase.memory());
      try {
        await DriftSyncCollection(
          other,
          'diary',
        ).mergeRemote(collection.decode(payload), now: DateTime.now());
        final copy = await DriftDiaryRepository(
          other,
          clock: DateTime.now,
        ).openDocument(id);
        expect(
          copy.entry!.photos.single.toJson(),
          entry.photos.single.toJson(),
        );
        expect(copy.entry!.text.body, entry.text.body);
      } finally {
        await other.close();
      }
      final Map<String, dynamic> legacy = {
        ...payload,
        'schema': 1,
        'entries': [
          for (final e in payload['entries'] as List)
            {
              ...e as Map,
              'photos': [],
              'conversation': null,
              'body': 'Old words',
            },
        ],
      };
      expect(collection.decode(legacy).payload['schema'], 2);
      expect(
        () => collection.decode({...payload, 'schema': 3}),
        throwsFormatException,
      );
    },
  );
}
