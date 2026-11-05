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
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/application/ai_providers.dart';
import 'package:redkeep/features/ai/domain/ai_preferences.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/diary/application/diary_ai_sources.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_ai_provider.dart';

const dayOutput =
    '{"title":"Garden morning","mood":{"value":"calm","evidence":"felt calm"},"themes":[{"label":"Gardening","evidence":"planting the garden"}]}';

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
  late FakeAiProviderClient aiProvider;
  final date = DiaryPeriod(2026, 11, 4);
  ProviderContainer container({bool connected = true}) => ProviderContainer(
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
      protectedAiProvidersProvider.overrideWithValue(
        MemoryAiProviders(saved: const [testAiProvider]),
      ),
      aiProviderClientProvider.overrideWithValue(aiProvider),
    ],
  );
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    diary = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 4));
    protected = MemoryAiTasks();
    remote = JobTransport();
    aiProvider = FakeAiProviderClient(dayOutput);
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
  Future<void> routeToProvider() => scope
      .read(aiPreferencesRepositoryProvider)
      .setDefaultRoute(AiRoute.provider(testAiProvider.id, 'test-model'));
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
    'computer-only operations never go to a provider when disconnected',
    () async {
      scope.dispose();
      scope = container(connected: false);
      await routeToProvider();
      await scope
          .read(aiJobsProvider.notifier)
          .start(AiOperation.history, 'history:test', '{}', '{}');
      expect(scope.read(aiJobsProvider).job, isNull);
      expect(remote.submissions, 0);
      expect(aiProvider.requests, isEmpty);
      expect(
        scope.read(aiJobsProvider).message,
        contains('needs your computer'),
      );
    },
  );

  group('resolveAiRoute never falls back', () {
    const onProvider = AiPreferences(
      defaultRoute: AiRoute.provider('provider-test', 'default-model'),
      overrides: {
        AiOperation.noteRewrite: AiRoute.provider('provider-test', 'rewriter'),
        AiOperation.noteSummary: AiRoute.companion(),
      },
    );
    ({AiRoute route, AiProviderConnection? provider}) resolve(
      AiOperation operation, {
      AiPreferences preferences = onProvider,
      bool connected = true,
      List<AiProviderConnection> providers = const [testAiProvider],
    }) => resolveAiRoute(
      operation: operation,
      preferences: preferences,
      connected: connected,
      providers: providers,
    );

    test('a task override wins over the default', () {
      expect(resolve(AiOperation.noteRewrite).route.model, 'rewriter');
      expect(resolve(AiOperation.noteExpand).route.model, 'default-model');
      expect(resolve(AiOperation.noteSummary).route.isCompanion, isTrue);
    });
    test('computer-only tasks ignore provider routing', () {
      expect(resolve(AiOperation.noteScan).provider, isNull);
      expect(
        () => resolve(AiOperation.noteScan, connected: false),
        throwsA(isA<CompanionFailure>()),
      );
    });
    test('a connected computer never replaces a removed provider', () {
      expect(
        () => resolve(AiOperation.noteExpand, providers: const []),
        throwsA(isA<CompanionFailure>()),
      );
    });
    test('a provider never replaces a disconnected computer', () {
      expect(
        () => resolve(AiOperation.noteSummary, connected: false),
        throwsA(isA<CompanionFailure>()),
      );
    });
  });
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
  test('a provider task sends its settings and previews the result', () async {
    await routeToProvider();
    aiProvider.reply = '```json\n$dayOutput\n```';
    await start();
    final job = scope.read(aiJobsProvider).job!;
    expect(job.phase, 'completed');
    expect(job.provider, 'provider');
    expect(job.providerName, testAiProvider.name);
    expect(job.modelId, 'test-model');
    expect(job.text, dayOutput);
    expect(remote.submissions, 0);
    final request = aiProvider.requests.single;
    expect(request.outputTokens, 320);
    expect(request.system, contains('JSON schema'));
    expect(request.temperature, 0);
    final metadata = (await db.select(db.aiJobReceipts).getSingle()).metadata;
    expect(metadata, isNot(contains('garden')));
    expect(metadata, isNot(contains(testAiProvider.token)));
    expect(protected.value, isNot(contains(testAiProvider.token)));
  });
  test('an invalid provider answer never reaches the preview', () async {
    await routeToProvider();
    aiProvider.reply = 'not json';
    await start();
    expect(scope.read(aiJobsProvider).job?.phase, isNot('completed'));
    expect(scope.read(aiJobsProvider).job?.text, isNull);
  });
  test('provider failures show their own message and no token', () async {
    await routeToProvider();
    aiProvider.failure = const AiProviderFailure(
      AiProviderFailureKind.rateLimited,
    );
    await start();
    final message = scope.read(aiJobsProvider).message!;
    expect(message, contains('rate limit'));
    expect(message, isNot(contains(testAiProvider.token)));
  });
  test('cancelling aborts the provider request and fences its result', () async {
    await routeToProvider();
    aiProvider.gate = Completer<void>();
    final running = start();
    await until(() => aiProvider.requests.isNotEmpty);
    await scope.read(aiJobsProvider.notifier).cancel();
    await running;
    expect(aiProvider.aborted, isTrue);
    expect(scope.read(aiJobsProvider).job!.phase, 'cancelled');
    expect(scope.read(aiJobsProvider).job!.text, isNull);
  });
  test('leaving the app aborts the provider request', () async {
    await routeToProvider();
    aiProvider.gate = Completer<void>();
    final running = start();
    await until(() => aiProvider.requests.isNotEmpty);
    scope.read(aiJobsProvider.notifier).foreground(false);
    await running;
    expect(aiProvider.aborted, isTrue);
  });
  test('interrupted provider work is never resent without an explicit retry', () async {
    await routeToProvider();
    await start();
    final job = scope.read(aiJobsProvider).job!;
    protected.value = jsonEncode(job.copy(phase: 'running').json());
    scope.dispose();
    aiProvider.requests.clear();
    scope = container(connected: false);
    await scope.read(aiJobsProvider.notifier).restore();
    expect(scope.read(aiJobsProvider).job!.phase, 'interrupted');
    expect(aiProvider.requests, isEmpty);
    await scope.read(aiJobsProvider.notifier).retry();
    expect(scope.read(aiJobsProvider).job!.phase, 'completed');
    expect(aiProvider.requests, hasLength(1));
  });
  test('a saved task from the removed phone backend still restores', () async {
    await routeToProvider();
    await start();
    final saved = scope.read(aiJobsProvider).job!.copy(phase: 'running').json();
    protected.value = jsonEncode({...saved, 'provider': 'device'});
    scope.dispose();
    scope = container(connected: false);
    await scope.read(aiJobsProvider.notifier).restore();
    expect(scope.read(aiJobsProvider).loaded, isTrue);
    expect(scope.read(aiJobsProvider).job!.phase, 'interrupted');
    expect(scope.read(aiJobsProvider).job!.destinationLabel, 'Phone');
  });

  test('connected computer without writing readiness reports failure without sending or falling back', () async {
    (scope.read(companionControllerProvider.notifier) as TestConnection).set(
      readyComputer(writingStatus: 'unloaded'),
    );
    await start();
    expect(remote.submissions, 0);
    expect(aiProvider.requests, isEmpty);
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
