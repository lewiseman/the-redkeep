import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/diary/application/diary_ai_sources.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_brain.dart';

const dayOutput =
    '{"title":"Garden morning","mood":{"value":"calm","evidence":"felt calm"},"themes":[{"label":"Gardening","evidence":"planting the garden"}]}';

class JsonModel implements LocalModel {
  JsonModel(this.text);
  final String text;
  int closed = 0;
  @override
  InferenceBackend get backend => InferenceBackend.cpu;
  @override
  Future<LocalSession> createSession() async => _JsonSession(text);
  @override
  Future<void> close() async {
    closed++;
  }
}

class _JsonSession implements LocalSession {
  _JsonSession(this.text);
  final String text;
  @override
  Future<void> addPrompt(String text) async {}
  @override
  Stream<String> stream() => Stream.value(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> close() async {}
}

class JobTransport implements CompanionTransport {
  int submissions = 0, reads = 0, acknowledgements = 0, cancels = 0;
  bool queued = false, failAck = false;
  Completer<void>? submitGate;
  Map<String, dynamic>? task;
  String output = dayOutput;
  @override
  Future<Map<String, dynamic>> request(
    Uri endpoint,
    String pin,
    String method,
    String route, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (route == '/v1/challenge') return {'nonce': 'a' * 43};
    if (route == '/v1/jobs' && method == 'POST') {
      submissions++;
      task = {
        'id': body!['id'],
        'operation': body['operation'],
        'device': 'b' * 32,
        'state': queued ? 'queued' : 'completed',
        if (!queued) 'text': output,
      };
      await submitGate?.future;
      return Map.of(task!);
    }
    if (route.endsWith('/ack')) {
      acknowledgements++;
      if (failAck) throw const CompanionFailure('UNAVAILABLE', 'synthetic');
      return {'ok': true};
    }
    if (route.endsWith('/cancel')) {
      cancels++;
      task?['state'] = 'cancelled';
      return {'ok': true};
    }
    if (method == 'GET' && route.startsWith('/v1/jobs/')) {
      reads++;
      return Map.of(task!);
    }
    throw StateError('Unexpected synthetic route');
  }

  @override
  void close() {}
}

Future<void> until(bool Function() predicate) async {
  for (var i = 0; i < 150 && !predicate(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late DriftDiaryRepository diary;
  late ProviderContainer scope;
  late MemoryAiTasks protected;
  late JobTransport remote;
  late FakeBrainAssignments assignments;
  final date = CivilDate(2026, 11, 4);
  ProviderContainer container({
    bool connected = true,
    List<InferenceSettings>? settings,
  }) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      diaryRepositoryProvider.overrideWithValue(diary),
      aiClockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 12)),
      protectedAiTasksProvider.overrideWithValue(protected),
      companionTransportProvider.overrideWithValue(remote),
      companionControllerProvider.overrideWith(
        () => TestConnection(
          connected
              ? readyComputer()
              : const CompanionState(phase: CompanionPhase.idle),
        ),
      ),
      brainAssignmentsProvider.overrideWithValue(assignments),
      brainModelFilesProvider.overrideWith((ref) async => FakeBrainFiles()),
      brainModelLoaderProvider.overrideWithValue((_, value) async {
        settings?.add(value);
        return JsonModel(dayOutput);
      }),
    ],
  );
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    diary = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 4));
    protected = MemoryAiTasks();
    remote = JobTransport();
    assignments = FakeBrainAssignments();
    await diary.save(
      id: 'a' * 32,
      date: date,
      text: const DiaryText(body: 'I felt calm while planting the garden.'),
      expectedRevision: 0,
    );
    scope = container();
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });
  Future<void> start() async {
    final source = await scope.read(diaryAiSourcesProvider).day(date);
    await scope
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.diaryDetails,
          date.key,
          source.request(),
          source.encode(),
        );
  }

  test('computer conversation uses the larger contract and persists typed original turns', () async {
    final connection =
        scope.read(companionControllerProvider.notifier) as TestConnection;
    final ready = readyComputer();
    final caps = ready.status!['capabilities'] as List;
    (caps.first as Map)['operations'] = ['diary.conversation'];
    connection.set(ready);
    final turns = [
      {'speaker': 'user', 'text': 'I walked by the river. ' * 140},
    ];
    final entry = await diary.saveConversation(
      id: 'c' * 32,
      date: date,
      conversation: DiaryAiConversation(
        turns: turns,
        createdAt: DateTime(2026, 11, 4),
      ),
      expectedRevision: 0,
    );
    remote.output = 'I walked by the river.';
    final prompt = jsonEncode({'action': 'draft', 'turns': turns});
    expect(utf8.encode(prompt).length, greaterThan(2000));
    final owner = Object();
    final lease = scope.read(voiceActiveProvider.notifier);
    lease.acquire(owner, () async {});
    await scope
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.conversation,
          entry.id,
          prompt,
          jsonEncode({
            'id': entry.id,
            'revision': entry.revision,
            'turns': turns,
          }),
          voiceOwner: owner,
        );
    expect(scope.read(voiceActiveProvider), isTrue);
    expect(remote.submissions, 1);
    expect(scope.read(aiJobsProvider).job!.phase, 'completed');
    expect(scope.read(aiJobsProvider).job!.operation, AiOperation.conversation);
    expect((await diary.openDocument(entry.id)).entry!.text.body, isEmpty);
    await scope.read(aiJobsProvider.notifier).clear();
    await scope
        .read(aiJobsProvider.notifier)
        .start(AiOperation.history, 'history:blocked', '{}', '{}');
    expect(remote.submissions, 1);
    expect(
      scope.read(aiJobsProvider).message,
      contains('Finish the voice session'),
    );
    lease.release(owner);
  });
  test(
    'computer-only operations never choose a phone model when disconnected',
    () async {
      scope.dispose();
      scope = container(connected: false);
      await scope
          .read(aiJobsProvider.notifier)
          .start(AiOperation.history, 'history:test', '{}', '{}');
      expect(scope.read(aiJobsProvider).job, isNull);
      expect(remote.submissions, 0);
      expect(
        scope.read(aiJobsProvider).message,
        contains('needs your computer'),
      );
    },
  );

  test(
    'Auto chooses once; explicit unavailable destinations do not fall back',
    () {
      expect(
        chooseAiDestination(
          mode: AiMode.auto,
          connected: true,
          deviceReady: true,
        ),
        AiMode.companion,
      );
      expect(
        chooseAiDestination(
          mode: AiMode.auto,
          connected: false,
          deviceReady: true,
        ),
        AiMode.device,
      );
      expect(
        () => chooseAiDestination(
          mode: AiMode.companion,
          connected: false,
          deviceReady: true,
        ),
        throwsA(isA<CompanionFailure>()),
      );
      expect(
        () => chooseAiDestination(
          mode: AiMode.device,
          connected: true,
          deviceReady: false,
        ),
        throwsA(isA<CompanionFailure>()),
      );
    },
  );
  test('companion results are protected before acknowledgement; receipts contain no writing', () async {
    await start();
    final job = scope.read(aiJobsProvider).job!;
    expect(job.phase, 'completed');
    expect(job.provider, 'companion');
    expect(remote.submissions, 1);
    expect(remote.acknowledgements, 1);
    expect(job.ackPending, isFalse);
    final metadata = (await db.select(db.aiJobReceipts).getSingle()).metadata;
    expect(metadata, isNot(contains('garden')));
    expect(metadata, isNot(contains('prompt')));
    expect(protected.value, contains('planting the garden'));
    await scope.read(aiJobsProvider.notifier).clear();
    expect(protected.value, isNull);
    expect(
      (await diary.openDocument('a' * 32)).entry!.text.body,
      contains('planting the garden'),
    );
  });
  test(
    'Auto uses assigned phone model away, with operation settings and cleanup',
    () async {
      scope.dispose();
      final settings = <InferenceSettings>[];
      assignments.values[BrainCapability.diaryDetails] = qualifiedBrainModel.id;
      scope = container(connected: false, settings: settings);
      await start();
      expect(scope.read(aiJobsProvider).job!.phase, 'completed');
      expect(scope.read(aiJobsProvider).job!.provider, 'device');
      expect(remote.submissions, 0);
      expect(settings.single.outputTokens, 320);
      expect(settings.single.systemInstruction, contains('JSON schema'));
      expect(settings.single.temperature, 0);
    },
  );
  test('interrupted phone work is restored without generation and requires an explicit retry', () async {
    scope.dispose();
    assignments.values[BrainCapability.diaryDetails] = qualifiedBrainModel.id;
    scope = container(connected: false);
    await start();
    final job = scope.read(aiJobsProvider).job!;
    protected.value = jsonEncode(job.copy(phase: 'running').json());
    scope.dispose();
    final settings = <InferenceSettings>[];
    scope = container(connected: false, settings: settings);
    await scope.read(aiJobsProvider.notifier).restore();
    expect(scope.read(aiJobsProvider).job!.phase, 'interrupted');
    expect(settings, isEmpty);
    await scope.read(aiJobsProvider.notifier).retry();
    expect(scope.read(aiJobsProvider).job!.phase, 'completed');
    expect(settings, hasLength(1));
  });

  test('connected computer without writing readiness reports failure without sending or falling back', () async {
    (scope.read(companionControllerProvider.notifier) as TestConnection).set(
      readyComputer(writingStatus: 'unloaded'),
    );
    assignments.values[BrainCapability.diaryDetails] = qualifiedBrainModel.id;
    await start();
    expect(remote.submissions, 0);
    expect(
      scope.read(aiJobsProvider).message,
      contains('Load a writing model'),
    );
  });
  test('accepted task survives restart and is retrieved without a second submission', () async {
    remote.queued = true;
    final running = start();
    await until(() => scope.read(aiJobsProvider).job?.accepted == true);
    scope.read(aiJobsProvider.notifier).foreground(false);
    await running;
    scope.dispose();
    remote.task!.addAll({'state': 'completed', 'text': dayOutput});
    scope = container();
    await scope.read(aiJobsProvider.notifier).restore();
    expect(scope.read(aiJobsProvider).job?.phase, 'completed');
    expect(remote.submissions, 1);
    expect(remote.reads, greaterThanOrEqualTo(1));
  });
  test(
    'cancel during delayed submission fences its late completed response',
    () async {
      remote.submitGate = Completer<void>();
      final running = start();
      await until(() => remote.submissions == 1);
      await scope.read(aiJobsProvider.notifier).cancel();
      remote.submitGate!.complete();
      await running;
      expect(scope.read(aiJobsProvider).job!.phase, 'cancelled');
      expect(remote.cancels, 1);
    },
  );
  test('failed acknowledgement remains recoverable and source changes invalidate a new request', () async {
    remote.failAck = true;
    await start();
    expect(scope.read(aiJobsProvider).job!.ackPending, isTrue);
    await scope.read(aiJobsProvider.notifier).clear();
    expect(
      await scope.read(aiJobStoreProvider).pendingAcknowledgements(),
      hasLength(1),
    );
    remote.failAck = false;
    await scope.read(aiJobsProvider.notifier).restore();
    expect(
      await scope.read(aiJobStoreProvider).pendingAcknowledgements(),
      isEmpty,
    );
    final source = await scope.read(diaryAiSourcesProvider).day(date);
    await diary.save(
      id: 'a' * 32,
      date: date,
      text: const DiaryText(body: 'Changed'),
      expectedRevision: 1,
    );
    await scope
        .read(aiJobsProvider.notifier)
        .start(
          AiOperation.diaryDetails,
          date.key,
          source.request(),
          source.encode(),
        );
    expect(remote.submissions, 1);
    expect(scope.read(aiJobsProvider).message, contains('entries changed'));
  });
  test('protected storage failure prevents submission', () async {
    protected.fail = true;
    await start();
    expect(remote.submissions, 0);
    expect(scope.read(aiJobsProvider).loaded, isFalse);
  });
}
