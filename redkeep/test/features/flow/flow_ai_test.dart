import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_jobs.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
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
import '../../support/fake_brain.dart';
import '../../support/notes_ai_harness.dart' show NotesTransport, ReplyModel;

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
  late MemoryAiTasks protected;
  late NotesTransport remote;
  late FakeBrainAssignments assignments;
  late ProviderContainer scope;
  final models = <ReplyModel>[];
  CompanionState connection({bool compatible = true}) => CompanionState(
    phase: CompanionPhase.connected,
    computers: [syntheticComputer()],
    selectedId: 'computer-1',
    status: {
      'recovery': 1,
      'capabilities': [
        {
          'id': 'text',
          'implemented': true,
          'status': 'ready',
          'reflectionContract': compatible ? 1 : 0,
          'thoughtQuestionContract': compatible ? 1 : 0,
          'operations': ['reflect-thought', 'answer-thought-question'],
        },
      ],
    },
  );
  ProviderContainer createScope({
    bool connected = true,
    bool compatible = true,
  }) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      flowRepositoryProvider.overrideWithValue(flow),
      aiClockProvider.overrideWithValue(() => now),
      protectedAiTasksProvider.overrideWithValue(protected),
      companionTransportProvider.overrideWithValue(remote),
      companionControllerProvider.overrideWith(
        () => TestConnection(
          connected
              ? connection(compatible: compatible)
              : const CompanionState(phase: CompanionPhase.idle),
        ),
      ),
      syncEnabledProvider.overrideWithValue(false),
      syncCanEditProvider.overrideWithValue(false),
      brainAssignmentsProvider.overrideWithValue(assignments),
      brainModelFilesProvider.overrideWith((_) async => FakeBrainFiles()),
      brainModelLoaderProvider.overrideWithValue((_, settings) async {
        final model = ReplyModel(remote.output, settings);
        models.add(model);
        return model;
      }),
      recallVectorsProvider.overrideWith((_) async => MemoryVectors()),
      recallEmbedderProvider.overrideWithValue(FakeEmbedder()),
    ],
  );
  Future<Thought> save({String id = thoughtId, String body = thoughtText}) =>
      flow.save(id: id, body: body, expectedRevision: 0);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    flow = DriftFlowRepository(db, clock: () => now);
    reflections = DriftThoughtReflections(db, clock: () => now);
    protected = MemoryAiTasks();
    remote = NotesTransport()..output = reflectionText;
    assignments = FakeBrainAssignments();
    models.clear();
    scope = createScope();
  });
  tearDown(() async {
    await scope.read(aiJobsProvider.notifier).stopForReset();
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

  test('companion completion is saved locally before snapshot release, even without the Flow page', () async {
    final thought = await save();
    scope.read(thoughtReflectionConsumerProvider);
    await scope.read(flowAiProvider).reflect(thoughtId);
    await drain(
      () => protected.value == null && scope.read(aiJobsProvider).job == null,
    );
    expect(
      (await reflections.watch(thought).first).proposal!.text,
      reflectionText,
    );
    expect(remote.submissions.single['operation'], 'reflect-thought');
    expect(remote.submissions.single['prompt'], thoughtText);
    final receipt =
        (await scope.read(aiJobStoreProvider).watchHistory().first).single;
    expect(receipt.operation, AiOperation.thoughtReflection);
    expect(receipt.prompt, isEmpty);
    expect(receipt.source, isEmpty);
    expect(receipt.text, isNull);
  });

  test('restored completed reflections are consumed once; interrupted phone work never restarts itself', () async {
    final thought = await save();
    final source = ThoughtReflectionSource.fromThought(thought);
    protected.value = jsonEncode(
      AiJob(
        id: 'restored-result',
        operation: AiOperation.thoughtReflection,
        key: thoughtId,
        created: now.millisecondsSinceEpoch,
        provider: 'device',
        prompt: thoughtText,
        source: source.encode(),
        phase: 'completed',
        text: reflectionText,
      ).json(),
    );
    scope.read(thoughtReflectionConsumerProvider);
    await scope.read(aiJobsProvider.notifier).restore();
    await drain(() => protected.value == null);
    expect(await db.select(db.flowReflections).get(), hasLength(1));
    expect(models, isEmpty);
    protected.value = jsonEncode(
      AiJob(
        id: 'interrupted-task',
        operation: AiOperation.thoughtReflection,
        key: thoughtId,
        created: now.millisecondsSinceEpoch,
        provider: 'device',
        prompt: thoughtText,
        source: source.encode(),
        phase: 'running',
      ).json(),
    );
    scope.dispose();
    scope = createScope(connected: false);
    await scope.read(aiJobsProvider.notifier).restore();
    expect(scope.read(aiJobsProvider).job!.phase, 'interrupted');
    expect(models, isEmpty);
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

  test('a durable consumed receipt prevents a dismissed reflection reappearing after snapshot recovery', () async {
    final thought = await save();
    await scope.read(flowAiProvider).reflect(thoughtId);
    final job = scope.read(aiJobsProvider).job!;
    await reflections.propose(
      job.id,
      ThoughtReflectionSource.fromThought(thought),
      job.text!,
    );
    await reflections.remove(job.id);
    // Saving refreshed status must preserve the durable consumed marker.
    await scope.read(aiJobsProvider.notifier).restore();
    expect(
      (await db.select(db.aiJobReceipts).getSingle()).resultConsumed,
      isTrue,
    );
    scope.read(thoughtReflectionConsumerProvider);
    await drain(() => protected.value == null);
    expect(await db.select(db.flowReflections).get(), isEmpty);
  });

  test(
    'capture continues during generation and edits reject a late reflection',
    () async {
      await save();
      scope.read(thoughtReflectionConsumerProvider);
      remote.queued = true;
      final pending = scope.read(flowAiProvider).reflect(thoughtId);
      await drain(() => remote.submissions.isNotEmpty);
      await save(id: 'b' * 32, body: 'A new passing thought.');
      await flow.save(
        id: thoughtId,
        body: 'The original thought changed.',
        expectedRevision: 1,
      );
      remote.task!['state'] = 'completed';
      remote.task!['text'] = reflectionText;
      await pending;
      await drain(
        () => scope.read(reflectionMessagesProvider)[thoughtId] != null,
      );
      expect(await db.select(db.flowReflections).get(), isEmpty);
      final active = scope.read(aiJobsProvider).job!;
      await scope.read(aiJobsProvider.notifier).clearIfCurrent('an-older-task');
      expect(scope.read(aiJobsProvider).job!.id, active.id);
      expect(
        (await flow.openDocument('b' * 32)).thought!.body,
        'A new passing thought.',
      );
    },
  );

  test(
    'phone reflection uses its own assigned capability and migrated prompt',
    () async {
      await save();
      scope.dispose();
      scope = createScope(connected: false);
      assignments.values[BrainCapability.reflect] = qualifiedBrainModel.id;
      await scope.read(flowAiProvider).reflect(thoughtId);
      expect(scope.read(aiJobsProvider).job!.phase, 'completed');
      expect(
        models.single.settings.systemInstruction,
        contains('single plain sentence'),
      );
      expect(jsonDecode(models.single.prompt!), {'thought': thoughtText});
      expect(remote.submissions, isEmpty);
    },
  );

  test('Flow questions use bounded thought-only excerpts, validate citations and reject changed sources before submission', () async {
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
    remote.output = '{"status":"answered","answer":"You wrote to plant tulips by the garden fence.","citations":["s0"]}';
    await scope.read(flowAiProvider).ask(selection);
    final job = scope.read(aiJobsProvider).job!;
    expect(job.operation, AiOperation.thoughtQuestion);
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
    await scope.read(aiJobsProvider.notifier).clear();
    await flow.save(
      id: thoughtId,
      body: 'A changed garden.',
      expectedRevision: 1,
    );
    await scope.read(flowAiProvider).ask(selection);
    expect(remote.submissions, hasLength(1));
    expect(scope.read(aiJobsProvider).message, contains('changed'));
  });

  test('phone questions use writing capability; no matches, missing models, old companions and occupied slots send nothing', () async {
    await save(body: 'Garden tulips by the fence.');
    scope.dispose();
    scope = createScope(connected: false);
    assignments.values[BrainCapability.rewrite] = qualifiedBrainModel.id;
    remote.output = '{"status":"insufficient","answer":"Do not display this invented explanation","citations":[]}';
    final selection = await scope.read(flowAiProvider).select('garden');
    await scope.read(flowAiProvider).ask(selection);
    expect(scope.read(aiJobsProvider).job!.phase, 'completed');
    expect(models.single.settings.systemInstruction, contains('Flow'));
    expect(
      RecallQuestionAnswer.parse(
        scope.read(aiJobsProvider).job!.text!,
        selection,
      ).text,
      isNot(contains('invented')),
    );
    final existing = scope.read(aiJobsProvider).job!.id;
    await scope.read(flowAiProvider).reflect(thoughtId);
    expect(scope.read(aiJobsProvider).job!.id, existing);
    final empty = await scope.read(flowAiProvider).select('volcanoes');
    expect(() => scope.read(flowAiProvider).ask(empty), throwsFormatException);
    await scope.read(aiJobsProvider.notifier).clear();
    assignments.values.clear();
    await scope.read(flowAiProvider).reflect(thoughtId);
    expect(scope.read(aiJobsProvider).job, isNull);
    scope.dispose();
    scope = createScope(compatible: false);
    await scope.read(flowAiProvider).reflect(thoughtId);
    expect(scope.read(aiJobsProvider).message, contains('Update'));
    expect(remote.submissions, isEmpty);
  });
}
