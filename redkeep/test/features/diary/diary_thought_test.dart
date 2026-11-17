import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/application/diary_editor_controller.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:sync_wise/sync_wise.dart';

const id = '11111111111111111111111111111111';
const other = '22222222222222222222222222222222';

void main() {
  final date = DiaryPeriod(2026, 11, 2);
  late AppDatabase db;
  late DriftDiaryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 2));
  });
  tearDown(() => db.close());

  test(
    'thoughts are stored, keep their kind when edited and stay text only',
    () async {
      await repo.save(
        id: id,
        date: date,
        text: const DiaryText(body: 'Quick'),
        expectedRevision: 0,
        kind: DiaryEntryKind.thought,
      );
      expect((await repo.openDocument(id)).entry!.isThought, isTrue);
      final edited = await repo.save(
        id: id,
        date: date,
        text: const DiaryText(body: 'Quick, edited'),
        expectedRevision: 1,
      );
      expect(edited.isThought, isTrue);
      expect((await repo.openDocument(id)).entry!.isThought, isTrue);
      await expectLater(
        repo.savePhotoStory(
          id: id,
          date: date,
          photos: [
            DiaryPhoto(
              id: 'photo_test',
              path: 'diary_photos/test.png',
              sha256: 'a' * 64,
            ),
          ],
          expectedRevision: 2,
        ),
        throwsA(isA<DiaryException>()),
      );
      await repo.save(
        id: other,
        date: date,
        text: const DiaryText(body: 'An ordinary entry'),
        expectedRevision: 0,
      );
      expect(
        (await repo.openDocument(other)).entry!.kind,
        DiaryEntryKind.entry,
      );
    },
  );

  test(
    'sync carries a thought\'s kind; entries without one stay ordinary',
    () async {
      await repo.save(
        id: id,
        date: date,
        text: const DiaryText(body: 'Quick'),
        expectedRevision: 0,
        kind: DiaryEntryKind.thought,
      );
      await repo.save(
        id: other,
        date: date,
        text: const DiaryText(body: 'Plain'),
        expectedRevision: 0,
      );
      final local = (await DriftSyncCollection(db, 'diary').read(date.key))!;
      final entries = (local.payload['entries'] as List)
          .cast<Map<String, dynamic>>();
      expect(entries.firstWhere((e) => e['id'] == id)['kind'], 'thought');
      expect(
        entries.firstWhere((e) => e['id'] == other).containsKey('kind'),
        isFalse,
      );

      final remote = AppDatabase(NativeDatabase.memory());
      addTearDown(remote.close);
      await DriftSyncCollection(remote, 'diary').mergeRemote(
        SyncDocument(
          id: date.key,
          payload: local.payload,
          status: SyncStatus.synced,
        ),
        now: DateTime.utc(2026, 11, 2),
      );
      final copies = DriftDiaryRepository(
        remote,
        clock: () => DateTime.utc(2026, 11, 2),
      );
      expect((await copies.openDocument(id)).entry!.isThought, isTrue);
      expect((await copies.openDocument(other)).entry!.isThought, isFalse);
      expect(DiaryEntryKind.decode(null), DiaryEntryKind.entry);
      expect(DiaryEntryKind.decode('something-new'), DiaryEntryKind.entry);
    },
  );

  test(
    'the editor saves new writing as a thought, never an existing entry',
    () async {
      final scope = ProviderContainer(
        overrides: [diaryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(scope.dispose);
      scope.read(diaryNewIdsProvider.notifier).add(id);
      final provider = diaryEditorProvider((date: date, id: id));
      scope.listen(provider, (_, _) {});
      await scope.read(provider.future);
      final editor = scope.read(provider.notifier);
      expect(await editor.saveAsThought(), isFalse, reason: 'nothing written');
      editor.edit(const DiaryText(body: 'A thought'));
      expect(await editor.saveAsThought(), isTrue);
      expect((await repo.openDocument(id)).entry!.isThought, isTrue);
      editor.edit(const DiaryText(body: 'A thought, again'));
      expect(await editor.saveAsThought(), isFalse);
    },
  );
}
