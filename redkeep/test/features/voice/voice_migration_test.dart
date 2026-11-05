import 'dart:async';
import 'dart:convert';

import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/voice/application/diary_voice_session.dart';
import 'package:redkeep/features/voice/application/diary_conversation_draft.dart';
import 'package:redkeep/features/voice/data/voice_store.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';

import '../../support/pump_app.dart';
import '../../support/fake_ai.dart';

class MemoryVoice extends VoiceStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> load(String target) async => rows[target];
  @override
  Future<void> save(String target, Map<String, dynamic> value) async {
    rows[target] = value;
  }

  @override
  Future<void> clear(String target) async {
    rows.remove(target);
  }

  @override
  Future<void> consumed(String target) => clear(target);
  @override
  Future<void> deleteAudio(String id) async {}
}

class ReviewedCapture extends VoiceCapture {
  ReviewedCapture()
    : super(
        target: 'flow',
        computer: () => throw StateError('No writing computer is consulted'),
        store: MemoryVoice(),
      );
  int discarded = 0;
  @override
  Future<void> restore() async {
    id = 'b' * 32;
    previousIds = ['a' * 32];
    text = 'A spoken thought';
    phase = CapturePhase.review;
    update();
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> discard({bool notifyComputer = true}) async {
    discarded++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reset waits for background suspension and still clears the microphone owner', () async {
    final scope = ProviderContainer.test();
    final lease = scope.read(voiceActiveProvider.notifier),
        owner = Object(),
        stop = Completer<void>();
    lease.acquire(owner, () => stop.future);
    final suspended = lease.suspend(), reset = lease.stopAll();
    stop.complete();
    await Future.wait([suspended, reset]);
    expect(scope.read(voiceActiveProvider), isFalse);
    lease.acquire(Object(), () async {});
  });
  test(
    'background suspension retains ownership without restarting capture',
    () async {
      final scope = ProviderContainer.test();
      final lease = scope.read(voiceActiveProvider.notifier), owner = Object();
      var stops = 0;
      lease.acquire(owner, () async {
        stops++;
      });
      await lease.suspend();
      expect(stops, 1);
      expect(scope.read(voiceActiveProvider), isTrue);
      expect(() => lease.acquire(Object(), () async {}), throwsStateError);
      lease.release(owner);
      expect(scope.read(voiceActiveProvider), isFalse);
    },
  );
  test(
    'microphone owners remain exclusive while an interrupted session drains',
    () async {
      final scope = ProviderContainer.test();
      final lease = scope.read(voiceActiveProvider.notifier);
      final first = Object(), second = Object(), stopped = Completer<void>();
      lease.acquire(first, () => stopped.future);
      expect(() => lease.acquire(second, () async {}), throwsStateError);
      final stopping = lease.stopAll();
      expect(() => lease.acquire(first, () async {}), throwsStateError);
      stopped.complete();
      await stopping;
      lease.acquire(second, () async {});
      expect(scope.read(voiceActiveProvider), isTrue);
      lease.release(second);
      expect(scope.read(voiceActiveProvider), isFalse);
    },
  );
  test('speech capture readiness works with no writing model; Phone mode is explicit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final computer = syntheticComputer();
    final scope = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        companionControllerProvider.overrideWith(
          () => TestConnection(
            CompanionState(
              phase: CompanionPhase.connected,
              computers: [computer],
              selectedId: computer.id,
              status: {
                'capabilities': [
                  {
                    'id': 'transcription',
                    'implemented': true,
                    'status': 'ready',
                    'live': 1,
                    'sampleRate': 16000,
                    'channels': 1,
                    'format': 's16le',
                  },
                ],
              },
            ),
          ),
        ),
      ],
    );
    scope.listen(aiPreferencesProvider, (_, _) {});
    await scope.read(aiPreferencesProvider.future);
    expect(scope.read(voiceComputerProvider)().id, computer.id);
    expect(
      () => scope.read(voiceComputerProvider)(conversation: true),
      throwsA(isA<CompanionFailure>()),
    );
    await scope.read(aiPreferencesRepositoryProvider).mode(AiMode.device);
    await pumpEventQueue();
    await scope.read(aiPreferencesProvider.future);
    expect(
      () => scope.read(voiceComputerProvider)(),
      throwsA(isA<CompanionFailure>()),
    );
  });
  test('primary retains each user turn; Finish save conflict preserves turns and words', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
    final store = MemoryVoice();
    final scope = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        diaryRepositoryProvider.overrideWithValue(repo),
        voiceStoreProvider.overrideWithValue(store),
      ],
    );
    final p = diaryVoiceSessionProvider(DiaryPeriod(2026, 11, 4));
    scope.listen(p, (_, _) {});
    final session = scope.read(p);
    await session.initialize();
    await session.conversation.append('user', 'Original words');
    expect(await session.commit(), isTrue);
    final saved = (await repo.openDocument(session.conversation.id)).entry!;
    expect(saved.conversation!.turns.last['text'], 'Original words');
    expect(await session.commit(content: 'Reviewed words'), isTrue);
    final edited = (await repo.openDocument(saved.id)).entry!;
    await repo.save(
      id: edited.id,
      date: edited.date,
      text: const DiaryText(body: 'Manual edit'),
      expectedRevision: edited.revision,
    );
    expect(await session.commit(content: 'Late generated words'), isFalse);
    expect((await repo.openDocument(saved.id)).entry!.text.body, 'Manual edit');
    expect(store.rows['diary']!['conversation'], isNotNull);
  });
  test(
    'secondary buffers turns then appends once, using current role inside save',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kv = DriftSyncKeyValueStore(db);
      await kv.write('deviceId', 'secondary');
      await kv.write('role', '{"device_id":"primary"}');
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
      final store = MemoryVoice();
      final scope = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          diaryRepositoryProvider.overrideWithValue(repo),
          voiceStoreProvider.overrideWithValue(store),
        ],
      );
      final p = diaryVoiceSessionProvider(DiaryPeriod(2026, 11, 4));
      scope.listen(p, (_, _) {});
      final session = scope.read(p);
      await session.initialize();
      expect(session.primary, isFalse);
      await session.conversation.append('user', 'Secondary words');
      expect(await session.commit(), isFalse);
      expect((await repo.openDocument(session.conversation.id)).entry, isNull);
      expect(await session.commit(closing: true), isTrue);
      expect(await session.commit(closing: true), isTrue);
      expect(
        (await repo.openDocument(session.conversation.id)).entry!.revision,
        1,
      );
      await expectLater(
        repo.saveConversation(
          id: session.conversation.id,
          date: DiaryPeriod(2026, 11, 4),
          conversation: session.record,
          expectedRevision: 1,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Finish protects generated words before clearing accepted work',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final kv = DriftSyncKeyValueStore(db);
      await kv.write('deviceId', 'secondary');
      await kv.write('role', '{"device_id":"primary"}');
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
      final store = MemoryVoice(), tasks = MemoryAiTasks();
      final scope = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          diaryRepositoryProvider.overrideWithValue(repo),
          voiceStoreProvider.overrideWithValue(store),
          protectedAiTasksProvider.overrideWithValue(tasks),
          companionControllerProvider.overrideWith(() => TestConnection()),
        ],
      );
      final date = DiaryPeriod(2026, 11, 4);
      final provider = diaryVoiceSessionProvider(date);
      scope.listen(provider, (_, _) {});
      final session = scope.read(provider);
      await session.initialize();
      await session.conversation.append('user', 'I enjoyed walking home.');
      tasks.value = jsonEncode(
        AiJob(
          id: 'accepted-draft-11111111',
          operation: AiOperation.conversation,
          key: session.conversation.id,
          created: DateTime.now().millisecondsSinceEpoch,
          provider: 'companion',
          phase: 'completed',
          text: 'I enjoyed my walk home today.',
          source: jsonEncode({
            'id': session.conversation.id,
            'date': date.key,
            'revision': 0,
            'new': true,
            'turns': session.conversation.turns,
          }),
        ).json(),
      );
      await session.conversation.request('draft');
      expect(session.conversation.message, isEmpty);
      expect(scope.read(aiJobsProvider).job, isNull);
      final retained = store.rows['diary-review-${session.conversation.id}']!;
      expect(retained['draft'], 'I enjoyed my walk home today.');
      expect(await session.commit(closing: true), isTrue);
      final entry = (await repo.openDocument(session.conversation.id)).entry!;
      expect(entry.text.body, isEmpty);
      expect(
        conversationDraftRevision(
          entry,
          retained['source'] as Map<String, dynamic>,
        ),
        1,
      );
    },
  );
  testWidgets(
    'Flow saves reviewed text once and preserves the composer draft without any AI text task',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftFlowRepository(db, clock: () => DateTime(2026, 11, 4));
      final capture = ReviewedCapture();
      final router = await pumpApp(
        tester,
        initialLocation: '/flow',
        database: db,
        flow: repo,
        voiceCapture: (_) => capture,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('flow-body')),
        'Composer stays here',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-microphone')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save thought'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save thought'));
      await tester.pumpAndSettle();
      expect(capture.discarded, 1);
      expect(
        (await repo.openDocument('a' * 32)).thought!.body,
        'A spoken thought',
      );
      expect((await repo.openDocument('b' * 32)).available, isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('flow-body')))
            .controller!
            .text,
        'Composer stays here',
      );
      final scope = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('flow-body'))),
      );
      expect(scope.read(aiJobsProvider).job, isNull);
      expect(router.routeInformationProvider.value.uri.path, '/flow');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
}
