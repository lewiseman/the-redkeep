import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/diary/application/diary_photo_question_controller.dart';
import 'package:redkeep/features/diary/data/diary_photo_question_store.dart';
import 'package:redkeep/features/diary/domain/diary_photo_question_contract.dart';

import '../../support/fake_ai.dart';

class RunningPhoto extends AiJobs {
  int cancellations = 0;
  @override
  AiJobState build() => AiJobState(
    loaded: true,
    busy: true,
    job: AiJob(
      id: 'photo-task-111111',
      operation: AiOperation.photoQuestions,
      key: 'a' * 64,
      created: DateTime.now().millisecondsSinceEpoch,
      provider: 'companion',
      phase: 'running',
    ),
  );
  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Stop cancels an actively polling photo job; cache isolates captions, contracts and models', () async {
    final db = AppDatabase(NativeDatabase.memory()),
        root = await Directory.systemTemp.createTemp('redkeep-photo-question-');
    final cache = DiaryPhotoQuestionStore(
      db,
      supportDirectory: () => Future.value(root),
    );
    final scope = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        aiJobsProvider.overrideWith(RunningPhoto.new),
        diaryPhotoQuestionStoreProvider.overrideWithValue(cache),
        companionControllerProvider.overrideWith(() => TestConnection()),
      ],
    );
    addTearDown(() async {
      scope.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    final controller = scope.read(diaryPhotoQuestionProvider.notifier);
    await controller.stop();
    expect(
      (scope.read(aiJobsProvider.notifier) as RunningPhoto).cancellations,
      1,
    );
    final result = DiaryPhotoQuestions(
      observations: 'Orange paper',
      clear: true,
      groups: const [
        ['What happened?'],
        ['How did it feel?'],
        ['What did you notice?'],
      ],
    );
    final sha = 'a' * 64;
    await cache.write(
      diaryPhotoCacheKey(sha, 'First caption', 'model-a'),
      result,
    );
    expect(
      await cache.read(diaryPhotoCacheKey(sha, 'First caption', 'model-a')),
      isNotNull,
    );
    expect(
      await cache.read(diaryPhotoCacheKey(sha, 'Changed caption', 'model-a')),
      isNull,
    );
    expect(
      await cache.read(diaryPhotoCacheKey(sha, 'First caption', 'model-b')),
      isNull,
    );
    await controller.load([
      (photoSha: sha, photo: Uint8List(0), caption: 'First caption'),
    ]);
    expect(scope.read(diaryPhotoQuestionProvider).questions[sha], isNotNull);
    await controller.load([
      (photoSha: sha, photo: Uint8List(0), caption: 'Changed caption'),
    ]);
    expect(scope.read(diaryPhotoQuestionProvider).questions[sha], isNull);
    expect(
      diaryPhotoCacheKey(sha, 'First caption', 'model-a'),
      contains('v2-png1'),
    );
  });
}
