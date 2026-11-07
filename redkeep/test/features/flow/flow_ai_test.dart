import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/flow/application/flow_ai.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/flow/data/drift_thought_reflections.dart';
import 'package:redkeep/features/flow/domain/thought.dart';
import 'package:redkeep/features/flow/domain/thought_reflection_contract.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';
import 'package:redkeep/features/recall/domain/recall_question_contract.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_ai_provider.dart';

const thoughtId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const thoughtText =
    'I keep putting off calling my sister, even though I want to catch up.';
const reflectionText =
    'Wanting to catch up can sit alongside putting the call off.';
final now = DateTime(2026, 11, 5, 12);

Future<void> drain(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late DriftFlowRepository flow;
  late DriftThoughtReflections reflections;
  late FakeAiProviderClient aiProvider;
  late ProviderContainer scope;
  ProviderContainer createScope({AiCloudSettings? settings = testAiSettings}) =>
      ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          flowRepositoryProvider.overrideWithValue(flow),
          aiClockProvider.overrideWithValue(() => now),
          syncEnabledProvider.overrideWithValue(false),
          syncCanEditProvider.overrideWithValue(false),
          protectedAiProvidersProvider.overrideWithValue(
            MemoryAiProviders(saved: settings),
          ),
          aiCloudClientProvider.overrideWithValue(aiProvider),
          recallVectorsProvider.overrideWith((_) async => MemoryVectors()),
          recallEmbedderProvider.overrideWithValue(FakeEmbedder()),
        ],
      );
  Future<Thought> save({String id = thoughtId, String body = thoughtText}) =>
      flow.save(id: id, body: body, expectedRevision: 0);

  /// Stands in for the open thought page.
  ProviderSubscription<Object?> openThought() =>
      scope.listen(thoughtReflectionConsumerProvider(thoughtId), (_, _) {});
  AiJobState reflection() =>
      scope.read(aiJobsProvider(flowReflectionScope(thoughtId)));
  AiJobState question() => scope.read(aiJobsProvider(flowSearchJobScope));
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    flow = DriftFlowRepository(db, clock: () => now);
    reflections = DriftThoughtReflections(db, clock: () => now);
    aiProvider = FakeAiProviderClient(reflectionText);
    scope = createScope();
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });

  test('reflection contract accepts one line and rejects repetition, instructions and introduced sensitive claims', () {
    expect(parseThoughtReflection(reflectionText, thoughtText), reflectionText);
    for (final text in [
      thoughtText,
      'You should call your sister.',
      'This is a sign of depression.',
      'You always avoid your whole life.',
    ]) {
      expect(
        () => parseThoughtReflection(text, thoughtText),
        throwsA(isA<ThoughtReflectionRejected>()),
      );
    }
    for (final text in ['', 'a\nb', 'x' * 201, '\ud800', 'bad\u0000line']) {
      expect(
        () => parseThoughtReflection(text, thoughtText),
        throwsFormatException,
      );
    }
  });

  test('proposals are idempotent, preserve kept lines until Keep, and never dirty writing or recall', () async {
    final thought = await save();
    final source = ThoughtReflectionSource.fromThought(thought);
    final syncBefore = await db.select(db.syncOperations).get();
    final recallBefore = await db.select(db.recallQueue).get();
    await reflections.propose('reflection-1', source, reflectionText);
    await reflections.propose('reflection-1', source, reflectionText);
    var view = await reflections.watch(thought).first;
    await reflections.keep(view.proposal!);
    await reflections.propose(
      'reflection-2',
      source,
      'The call can matter even while it feels easy to postpone.',
    );
    view = await reflections.watch(thought).first;
    expect(view.kept!.text, reflectionText);
    await reflections.remove(view.proposal!.taskId);
    expect((await reflections.watch(thought).first).kept!.text, reflectionText);
    await reflections.propose(
      'reflection-3',
      source,
      'Putting off the call does not erase your wish to catch up.',
    );
    await reflections.keep((await reflections.watch(thought).first).proposal!);
    expect(await db.select(db.flowReflections).get(), hasLength(1));
    expect((await flow.openDocument(thoughtId)).thought!.body, thoughtText);
    expect(await db.select(db.syncOperations).get(), syncBefore);
    expect(await db.select(db.recallQueue).get(), recallBefore);
  });

  test('edited and deleted sources cannot keep stale reflections, including same revision and timestamp replacements', () async {
    final thought = await save();
    final source = ThoughtReflectionSource.fromThought(thought);
    await reflections.propose('reflection-1', source, reflectionText);
    final proposal = (await reflections.watch(thought).first).proposal!;
    await db.customUpdate(
      'UPDATE flow_thoughts SET body = ? WHERE id = ?',
      variables: [const Variable('Changed by sync'), const Variable(thoughtId)],
      updates: {db.flowThoughts},
    );
    expect(
      () => reflections.keep(proposal),
      throwsA(isA<ThoughtReflectionRejected>()),
    );
    final replaced = (await flow.openDocument(thoughtId)).thought!;
    expect((await reflections.watch(replaced).first).proposal, isNull);
    await flow.deleteThought(thoughtId, replaced.revision);
    expect(await db.select(db.flowReflections).get(), isEmpty);
  });

  test('unkept proposals expire, kept lines survive pruning, reset fences late writes', () async {
    final thought = await save();
    final source = ThoughtReflectionSource.fromThought(thought);
    final old = DriftThoughtReflections(
      db,
      clock: () => now.subtract(const Duration(days: 8)),
    );
    await old.propose('reflection-old', source, reflectionText);
    expect((await reflections.watch(thought).first).proposal, isNull);
    await old.keep((await old.watch(thought).first).proposal!);
    await reflections.prune();
    expect((await reflections.watch(thought).first).kept, isNotNull);
    db.writingGeneration++;
    await DriftAccountResetData(db).clear();
    expect(await db.select(db.flowReflections).get(), isEmpty);
    expect(
      () => reflections.propose('late-result', source, reflectionText),
      throwsStateError,
    );
  });

  test('secondary devices can keep local reflections while thought editing remains blocked', () async {
    final thought = await save();
    final values = DriftSyncKeyValueStore(db);
    await values.write('deviceId', 'this-phone');
    await values.write('role', jsonEncode({'device_id': 'other-primary'}));
    await reflections.propose(
      'secondary-result',
      ThoughtReflectionSource.fromThought(thought),
      reflectionText,
    );
    await reflections.keep((await reflections.watch(thought).first).proposal!);
    expect((await reflections.watch(thought).first).kept!.text, reflectionText);
    await expectLater(
      flow.save(id: thoughtId, body: 'Cannot edit', expectedRevision: 1),
      throwsStateError,
    );
  });

  test(
    'a finished reflection is saved while its thought page is open',
    () async {
      final thought = await save();
      openThought();
      await scope.read(flowAiProvider).reflect(thoughtId);
      await drain(() => reflection().job == null);
      expect(
        (await reflections.watch(thought).first).proposal!.text,
        reflectionText,
      );
      final request = aiProvider.requests.single;
      expect(request.system, contains('single plain sentence'));
      expect(jsonDecode(request.user), {'thought': thoughtText});
    },
  );

  test(
    'leaving the thought page aborts the reflection and saves nothing',
    () async {
      await save();
      final page = openThought();
      aiProvider.gate = Completer<void>();
      unawaited(scope.read(flowAiProvider).reflect(thoughtId));
      await drain(() => aiProvider.requests.isNotEmpty);
      page.close();
      await pumpEventQueue();
      expect(aiProvider.aborted, isTrue);
      aiProvider.gate!.complete();
      await pumpEventQueue();
      expect(await db.select(db.flowReflections).get(), isEmpty);
    },
  );

  test(
    'capture continues during generation and edits reject a late reflection',
    () async {
      await save();
      openThought();
      aiProvider.gate = Completer<void>();
      final pending = scope.read(flowAiProvider).reflect(thoughtId);
      await drain(() => aiProvider.requests.isNotEmpty);
      await save(id: 'b' * 32, body: 'A new passing thought.');
      await flow.save(
        id: thoughtId,
        body: 'The original thought changed.',
        expectedRevision: 1,
      );
      aiProvider.gate!.complete();
      await pending;
      await drain(
        () => scope.read(reflectionMessagesProvider)[thoughtId] != null,
      );
      expect(await db.select(db.flowReflections).get(), isEmpty);
      final active = reflection().job!;
      await scope
          .read(aiJobsProvider(flowReflectionScope(thoughtId)).notifier)
          .clearIfCurrent('an-older-task');
      expect(reflection().job!.id, active.id);
      expect(
        (await flow.openDocument('b' * 32)).thought!.body,
        'A new passing thought.',
      );
    },
  );

  test('Flow questions use bounded thought-only excerpts, validate citations and reject changed sources before submission', () async {
    scope.listen(aiJobsProvider(flowSearchJobScope), (_, _) {});
    await save(body: 'Plant tulips by the garden fence.');
    await save(id: 'b' * 32, body: 'Buy bread on Saturday.');
    final selection = await scope
        .read(flowAiProvider)
        .select('Where should the tulips go?');
    expect(selection.kind, RecallKind.thought);
    expect(selection.sources.map((s) => s.uuid), [thoughtId]);
    expect(utf8.encode(selection.request()).length, lessThanOrEqualTo(2000));
    expect(
      (jsonDecode(selection.request())['sources'] as List).first.containsKey(
        'title',
      ),
      isFalse,
    );
    aiProvider.reply = '{"status":"answered","answer":"You wrote to plant tulips by the garden fence.","citations":["s0"]}';
    await scope.read(flowAiProvider).ask(selection);
    final job = question().job!;
    expect(job.operation, AiOperation.thoughtQuestion);
    expect(aiProvider.requests.single.system, contains('Flow'));
    expect(
      RecallQuestionAnswer.parse(job.text!, selection).citations.single.uuid,
      thoughtId,
    );
    expect(
      () => RecallQuestionAnswer.parse(
        '{"status":"answered","answer":"Unsupported","citations":["s7"]}',
        selection,
      ),
      throwsA(isA<RecallAnswerRejected>()),
    );
    await scope.read(aiJobsProvider(flowSearchJobScope).notifier).clear();
    await flow.save(
      id: thoughtId,
      body: 'A changed garden.',
      expectedRevision: 1,
    );
    await scope.read(flowAiProvider).ask(selection);
    expect(aiProvider.requests, hasLength(1));
    expect(question().message, contains('changed'));
    final empty = await scope.read(flowAiProvider).select('volcanoes');
    expect(() => scope.read(flowAiProvider).ask(empty), throwsFormatException);
  });

  test('without a provider nothing is sent', () async {
    await save();
    scope.dispose();
    scope = createScope(settings: null);
    openThought();
    await scope.read(flowAiProvider).reflect(thoughtId);
    expect(reflection().message, contains('Grand Maestar'));
    expect(aiProvider.requests, isEmpty);
  });
}
