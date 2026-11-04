import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/diary/application/daily_question_controller.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

import '../../support/fake_ai.dart';
import '../ai/ai_jobs_test.dart' show JobTransport, until;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = CivilDate(2026, 11, 4);
  late AppDatabase db;
  late ProviderContainer scope;
  late JobTransport transport;
  late DateTime now;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.select(db.aiPreferencesTable).get();
    now = DateTime(2026, 11, 4, 12);
    transport = JobTransport()..output = '{"question":"What was one small thing you noticed?","source":"","evidence":""}';
    scope = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        diaryRepositoryProvider.overrideWithValue(
          DriftDiaryRepository(db, clock: () => now),
        ),
        diaryClockProvider.overrideWithValue(() => now),
        aiClockProvider.overrideWithValue(() => now),
        companionControllerProvider.overrideWith(
          () => TestConnection(readyComputer()),
        ),
        companionTransportProvider.overrideWithValue(transport),
        protectedAiTasksProvider.overrideWithValue(MemoryAiTasks()),
      ],
    );
    scope.listen(aiPreferencesProvider, (_, _) {});
    await scope.read(aiPreferencesProvider.future);
    scope.listen(dailyQuestionProvider(date), (_, _) {});
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });
  test('only the active diary generates, then cached questions and skip avoid duplicate automatic requests', () async {
    final controller = scope.read(dailyQuestionProvider(date).notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.submissions, 0);
    controller.activate(true);
    await until(() => scope.read(dailyQuestionProvider(date)).question != null);
    expect(transport.submissions, 1);
    expect(await db.select(db.dailyQuestions).get(), hasLength(1));
    await controller.refresh();
    controller.ensure();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.submissions, 1);
    await controller.skip();
    await controller.refresh();
    controller.ensure();
    expect(scope.read(dailyQuestionProvider(date)).question, isNull);
    expect(transport.submissions, 1);
    transport.output = '{"question":"Which moment would you like to remember?","source":"","evidence":""}';
    await controller.request();
    await until(() => scope.read(dailyQuestionProvider(date)).question != null);
    expect(transport.submissions, 2);
    await scope.read(aiPreferencesRepositoryProvider).questions(false);
    await until(() => scope.read(dailyQuestionProvider(date)).question == null);
    expect(await db.select(db.dailyQuestions).get(), isEmpty);
  });
  test('content edits invalidate a question even when entry IDs stay the same; midnight retires it', () async {
    final repo = scope.read(diaryRepositoryProvider);
    await repo.save(
      id: 'a' * 32,
      date: date,
      text: const DiaryText(body: 'I planted the garden.'),
      expectedRevision: 0,
    );
    final controller = scope.read(dailyQuestionProvider(date).notifier);
    controller.activate(true);
    await until(() => scope.read(dailyQuestionProvider(date)).question != null);
    controller.activate(false);
    await repo.save(
      id: 'a' * 32,
      date: date,
      text: const DiaryText(body: 'I walked in the park.'),
      expectedRevision: 1,
    );
    controller.activate(true);
    await until(() => transport.submissions == 2);
    // A repeated result is rejected, so the obsolete question must remain hidden.
    await until(() => scope.read(dailyQuestionProvider(date)).message != null);
    expect(scope.read(dailyQuestionProvider(date)).question, isNull);
    now = DateTime(2026, 11, 5, 0, 1);
    await controller.refresh();
    expect(scope.read(dailyQuestionProvider(date)).question, isNull);
  });
  test('a cached general question is retired when selected earlier writing changes', () async {
    final repo = scope.read(diaryRepositoryProvider);
    final yesterday = CivilDate(2026, 11, 3);
    await repo.save(
      id: 'b' * 32,
      date: yesterday,
      text: const DiaryText(body: 'A garden plan.'),
      expectedRevision: 0,
    );
    final controller = scope.read(dailyQuestionProvider(date).notifier);
    controller.activate(true);
    await until(() => scope.read(dailyQuestionProvider(date)).question != null);
    controller.activate(false);
    await repo.save(
      id: 'b' * 32,
      date: yesterday,
      text: const DiaryText(body: 'A changed plan.'),
      expectedRevision: 1,
    );
    controller.activate(true);
    await controller.refresh();
    expect(scope.read(dailyQuestionProvider(date)).question, isNull);
  });
}
