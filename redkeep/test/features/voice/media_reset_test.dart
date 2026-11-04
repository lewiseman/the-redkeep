import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/diary/application/diary_media_providers.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/diary_photo_question_store.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/voice/data/voice_store.dart';

import '../../support/fake_ai.dart';

class RetryPhotoStore extends DiaryPhotoStore {
  RetryPhotoStore(AppDatabase db, Directory directory)
    : super(db: db, supportDirectory: () => Future.value(directory));
  bool fail = true;
  @override
  Future<void> clearAll() async {
    if (fail) {
      fail = false;
      throw const FileSystemException('Synthetic interrupted removal');
    }
    await super.clearAll();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reset retries interrupted cleanup, fences old writes and preserves pairing/preferences', () async {
    FlutterSecureStorage.setMockInitialValues({
      'redkeep.companion.trust': 'synthetic-pairing',
    });
    final root = await Directory.systemTemp.createTemp('redkeep-reset-media-');
    final db = AppDatabase(NativeDatabase.memory());
    final photo = RetryPhotoStore(db, root);
    final voice = VoiceStore(supportDirectory: () => Future.value(root));
    final vectors = MemoryVectors(), tasks = MemoryAiTasks();
    final scope = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        protectedAiTasksProvider.overrideWithValue(tasks),
        diaryPhotoStoreProvider.overrideWithValue(photo),
        diaryPhotoQuestionStoreProvider.overrideWithValue(
          DiaryPhotoQuestionStore(
            db,
            supportDirectory: () => Future.value(root),
          ),
        ),
        voiceStoreProvider.overrideWithValue(voice),
        recallVectorsProvider.overrideWith((ref) async => vectors),
      ],
    );
    addTearDown(() async {
      scope.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
    await repo.save(
      id: 'a' * 32,
      date: CivilDate(2026, 11, 4),
      text: const DiaryText(body: 'Saved words'),
      expectedRevision: 0,
    );
    await scope.read(aiPreferencesRepositoryProvider).questions(false);
    await photo.write('orphan-11111111', Uint8List.fromList([1, 2, 3]));
    await voice.save('note', {
      'id': 'capture-11111111',
      'created': DateTime.now().millisecondsSinceEpoch,
      'text': 'Sensitive transcript',
    });
    await File('${(await voice.directory()).path}/capture-11111111.pcm')
        .writeAsBytes([0, 0]);
    final reset = DriftAccountResetData(
      db,
      beforeClear: scope.read(aiResetProvider),
    );
    db.writingBlocked = true;
    db.writingGeneration++;
    await expectLater(reset.clear(), throwsA(isA<FileSystemException>()));
    expect((await repo.openDocument('a' * 32)).entry!.text.body, 'Saved words');
    await reset.clear();
    expect(await db.select(db.diaryEntries).get(), isEmpty);
    expect(await db.select(db.diaryMediaOps).get(), isEmpty);
    expect(await db.select(db.photoQuestionCache).get(), isEmpty);
    expect(await Directory('${root.path}/voice_sessions').exists(), isFalse);
    expect(await Directory('${root.path}/diary_photos').exists(), isFalse);
    expect(
      await VoiceStore.storage.read(key: 'redkeep.companion.trust'),
      'synthetic-pairing',
    );
    expect(
      (await scope.read(aiPreferencesRepositoryProvider).read()).dailyQuestions,
      isFalse,
    );
    await voice.save('note', {
      'created': DateTime.now().millisecondsSinceEpoch,
      'text': 'Late transcript',
    });
    expect(await VoiceStore.storage.read(key: 'redkeep.voice.note'), isNull);
    db.writingBlocked = false;
    await expectLater(
      repo.save(
        id: 'b' * 32,
        date: CivilDate(2026, 11, 4),
        text: const DiaryText(body: 'Late words'),
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    await expectLater(
      photo.write('late-11111111', Uint8List.fromList([4])),
      throwsStateError,
    );
    await expectLater(
      photo.delete(['diary_photos/late-11111111.png']),
      throwsStateError,
    );
  });
}
