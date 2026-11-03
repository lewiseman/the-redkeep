import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';
import 'package:redkeep/features/brain/application/brain_controller.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/maester/application/maester_controller.dart';
import 'package:redkeep/features/maester/domain/maester_source.dart';

import '../../support/fake_brain.dart';
import '../../support/fake_local_model.dart';

void main() {
  late ProviderContainer container;
  late FakeBrainAssignments assignments;
  late FakeBrainFiles files;
  late FakeModel model;
  late MaesterSource? source;
  late MaesterController controller;
  late MaesterContext context;
  late MaesterState Function() state;
  var valid = true;
  var accepted = 0;
  Completer<bool>? validation;

  MaesterSource sample({
    MaesterKind kind = MaesterKind.note,
    String id = 'first',
    int revision = 1,
    Object version = 0,
    String body = 'Mira planted a tree.',
    int start = 0,
    int? end,
    bool editing = true,
  }) => MaesterSource(
    kind: kind,
    id: id,
    revision: revision,
    version: version,
    body: body,
    start: start,
    end: end ?? body.length,
    editing: editing,
  );

  setUp(() {
    assignments = FakeBrainAssignments();
    for (final capability in BrainCapability.values) {
      assignments.values[capability] = qualifiedBrainModel.id;
    }
    files = FakeBrainFiles();
    model = FakeModel();
    source = sample();
    valid = true;
    accepted = 0;
    validation = null;
    context = MaesterContext(
      current: () => source,
      validate: (_) async => validation == null ? valid : validation!.future,
      accept: (_, stillCurrent) async {
        if (!stillCurrent()) return false;
        accepted++;
        return true;
      },
    );
    container = ProviderContainer(
      overrides: [
        brainAssignmentsProvider.overrideWithValue(assignments),
        brainModelFilesProvider.overrideWith((_) async => files),
        brainModelLoaderProvider.overrideWithValue((_, _) async => model),
      ],
    );
    final provider = maesterControllerProvider(context);
    container.listen(provider, (_, _) {});
    controller = container.read(provider.notifier);
    state = () => container.read(provider);
  });
  tearDown(() => container.dispose());

  test('contextual actions restrict read and edit capabilities; empty and long input never loads', () async {
    expect(sample(editing: false).actions, [BrainCapability.summarize]);
    expect(sample().actions, [
      BrainCapability.rewrite,
      BrainCapability.summarize,
    ]);
    expect(sample(kind: MaesterKind.diary).actions, [
      BrainCapability.summarize,
    ]);
    expect(sample(kind: MaesterKind.flow).actions, [BrainCapability.reflect]);
    source = sample(kind: MaesterKind.diary);
    await controller.run(BrainCapability.rewrite);
    expect(model.sessions, isEmpty);
    for (final body in ['', ' ' * 10, 'x' * 2001]) {
      source = sample(body: body);
      await controller.run(BrainCapability.rewrite);
      expect(state().failure, BrainFailure.input);
    }
    expect(files.checks, 0);
    source = sample(body: 'x' * 2001, start: 2, end: 10);
    await controller.run(BrainCapability.rewrite);
    expect(model.sessions.single.prompt, contains('<text>\nxxxxxxxx\n</text>'));
  });

  test('opening checks readiness without loading; absent/incompatible/missing assignments lead to setup', () async {
    expect(files.checks, 0);
    await controller.refresh();
    expect(state().ready.length, 3);
    expect(files.checks, 1);
    expect(model.sessions, isEmpty);
    assignments.values.clear();
    await controller.refresh();
    expect(state().ready, isEmpty);
    await controller.run(BrainCapability.rewrite);
    expect(state().failure, BrainFailure.unassigned);
    assignments.values[BrainCapability.rewrite] = 'unknown';
    await controller.refresh();
    expect(state().ready, isEmpty);
    assignments.values[BrainCapability.rewrite] = qualifiedBrainModel.id;
    for (final fileState in [
      ModelFileState.missing,
      ModelFileState.corrupt,
      ModelFileState.interrupted,
    ]) {
      files.state = fileState;
      await controller.refresh();
      expect(state().ready, isEmpty);
    }
    expect(model.sessions, isEmpty);
  });

  test('stream is incomplete until cleanup; cancel suppresses late output; explicit retry and acceptance only', () async {
    model.hold = true;
    final run = controller.run(BrainCapability.rewrite);
    await flush();
    expect(state().output, 'one');
    expect(state().proposal, isNull);
    expect(await controller.accept(), isFalse);
    await controller.cancel();
    await run;
    expect(state().failure, BrainFailure.cancelled);
    expect(state().output, isEmpty);
    expect(model.closed, 1);
    expect(accepted, 0);
    model.hold = false;
    await controller.run(BrainCapability.rewrite);
    expect(state().proposal!.output, 'one two');
    expect(model.closed, 2);
    expect(accepted, 0);
    expect(await controller.accept(), isTrue);
    expect(accepted, 1);
    expect(state().accepted, isTrue);
    expect(await controller.accept(), isFalse);
  });

  for (final failure in ['create', 'prompt', 'stream', 'modelClose']) {
    test(
      'safe failure $failure never exposes a replacement; retry is explicit',
      () async {
        model.failAt = failure;
        await controller.run(BrainCapability.rewrite);
        expect(state().proposal, isNull);
        expect(
          state().failure,
          failure == 'modelClose'
              ? BrainFailure.cleanup
              : BrainFailure.generation,
        );
        expect(accepted, 0);
        model.failAt = null;
        await controller.run(BrainCapability.rewrite);
        expect(state().proposal != null, failure != 'modelClose');
      },
    );
  }

  for (final change in [
    'id',
    'revision',
    'text',
    'selection',
    'undo',
    'deleted',
  ]) {
    test(
      '$change during streaming expires provenance and cancels native work',
      () async {
        model.hold = true;
        final run = controller.run(BrainCapability.rewrite);
        await flush();
        source = switch (change) {
          'id' => sample(id: 'second'),
          'revision' => sample(revision: 2),
          'text' => sample(body: 'Newer writing'),
          'selection' => sample(start: 1),
          'undo' => sample(version: 2),
          _ => null,
        };
        controller.sourceChanged();
        await run;
        expect(state().expired, isTrue);
        expect(state().output, isEmpty);
        expect(await controller.accept(), isFalse);
        expect(model.sessions.single.stopped, 1);
        expect(model.closed, 1);
        expect(accepted, 0);
      },
    );
  }

  test('authoritative source changes without a widget rebuild are checked on completion and acceptance', () async {
    model.hold = true;
    final run = controller.run(BrainCapability.rewrite);
    await flush();
    valid = false;
    await model.sessions.single.output.close();
    await run;
    expect(state().expired, isTrue);
    valid = true;
    model.hold = false;
    await controller.run(BrainCapability.rewrite);
    expect(state().proposal, isNotNull);
    valid = false;
    expect(await controller.accept(), isFalse);
    expect(accepted, 0);
  });

  test(
    'selection/screen change while validation awaits prevents acceptance',
    () async {
      await controller.run(BrainCapability.rewrite);
      validation = Completer<bool>();
      final accepting = controller.accept();
      source = sample(id: 'another');
      controller.sourceChanged();
      validation!.complete(true);
      expect(await accepting, isFalse);
      expect(accepted, 0);
      expect(state().expired, isTrue);
    },
  );

  test('background cancels pending validation with no native prompt and never resumes', () async {
    validation = Completer<bool>();
    final run = controller.run(BrainCapability.rewrite);
    await flush();
    controller.setForeground(false);
    validation!.complete(true);
    await run;
    controller.setForeground(true);
    await flush();
    expect(state().failure, BrainFailure.cancelled);
    expect(model.sessions, isEmpty);
  });

  test(
    'background cancels streaming and invalidates a completed proposal',
    () async {
      model.hold = true;
      final run = controller.run(BrainCapability.rewrite);
      await flush();
      controller.setForeground(false);
      await run;
      controller.setForeground(true);
      expect(model.closed, 1);
      model.hold = false;
      await controller.run(BrainCapability.rewrite);
      controller.setForeground(false);
      controller.setForeground(true);
      expect(await controller.accept(), isFalse);
      expect(accepted, 0);
    },
  );

  test(
    'scope disposal during native load closes late model without prompting',
    () async {
      final loading = Completer<LocalModel>();
      container.updateOverrides([
        brainAssignmentsProvider.overrideWithValue(assignments),
        brainModelFilesProvider.overrideWith((_) async => files),
        brainModelLoaderProvider.overrideWithValue((_, _) => loading.future),
      ]);
      final run = controller.run(BrainCapability.rewrite);
      await flush();
      container.dispose();
      container = ProviderContainer();
      loading.complete(model);
      await run;
      expect(model.sessions, isEmpty);
      expect(model.closed, 1);
    },
  );

  test(
    'a helper which finds Brain busy cannot cancel the other owner',
    () async {
      model.hold = true;
      final executor = await container.read(brainExecutorProvider.future);
      final external = executor.execute(
        model: qualifiedBrainModel,
        capability: BrainCapability.summarize,
        text: 'Separate synthetic text',
        onChunk: (_) {},
      );
      await flush();
      await controller.run(BrainCapability.rewrite);
      expect(state().failure, BrainFailure.busy);
      await controller.cancel();
      expect(model.sessions.single.stopped, 0);
      expect(executor.busy, isTrue);
      final finished = expectLater(external, throwsA(isA<BrainException>()));
      await executor.cancel();
      await finished;
    },
  );

  test('finishing validation cannot cancel a newer request owned by another caller', () async {
    model.hold = true;
    final run = controller.run(BrainCapability.rewrite);
    await flush();
    validation = Completer<bool>();
    await model.sessions.single.output.close();
    await flush();
    final executor = await container.read(brainExecutorProvider.future);
    expect(executor.busy, isFalse);
    expect(state().busy, isTrue);
    final otherOwner = Object();
    final external = executor.execute(
      owner: otherOwner,
      model: qualifiedBrainModel,
      capability: BrainCapability.summarize,
      text: 'Another request',
      onChunk: (_) {},
    );
    await flush();
    await controller.cancel();
    expect(executor.busy, isTrue);
    expect(model.sessions.last.stopped, 0);
    // A stale explicit owner cannot stop the new resource either.
    await executor.cancel(owner: Object());
    expect(model.sessions.last.stopped, 0);
    validation!.complete(true);
    await run;
    expect(state().proposal, isNull);
    final finished = expectLater(external, throwsA(isA<BrainException>()));
    await executor.cancel(owner: otherOwner);
    await finished;
  });

  test(
    'leaving previously used Brain settings cannot cancel active helper work',
    () async {
      final subscription = container.listen(brainControllerProvider, (_, _) {});
      await flush();
      final brain = container.read(brainControllerProvider.notifier);
      await brain.testAssignment(BrainCapability.rewrite);
      model.hold = true;
      final run = controller.run(BrainCapability.rewrite);
      await flush();
      brain.setForeground(false);
      await brain.cancel();
      subscription.close();
      await container.pump();
      expect(model.sessions.last.stopped, 0);
      expect(state().busy, isTrue);
      await controller.cancel();
      await run;
      expect(model.sessions.last.stopped, 1);
    },
  );

  test(
    'summary and optional reflection can never invoke replacement acceptance',
    () async {
      for (final kind in [
        MaesterKind.note,
        MaesterKind.diary,
        MaesterKind.flow,
      ]) {
        source = sample(kind: kind);
        await controller.run(
          kind == MaesterKind.flow
              ? BrainCapability.reflect
              : BrainCapability.summarize,
        );
        expect(state().proposal, isNotNull);
        expect(await controller.accept(), isFalse);
      }
      expect(accepted, 0);
    },
  );
}

Future<void> flush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
