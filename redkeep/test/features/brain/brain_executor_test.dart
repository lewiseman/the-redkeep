import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';
import 'package:redkeep/features/brain/application/brain_executor.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

import '../../support/fake_brain.dart';
import '../../support/fake_local_model.dart';

void main() {
  late FakeBrainFiles files;
  late List<FakeModel> models;
  late BrainExecutor executor;
  setUp(() {
    files = FakeBrainFiles();
    models = [];
    executor = BrainExecutor(
      files: files,
      loadModel: (_, _) async {
        final model = FakeModel();
        models.add(model);
        return model;
      },
    );
  });
  tearDown(() => executor.dispose());
  Future<void> run({
    BrainCapability capability = BrainCapability.rewrite,
    String text = 'Synthetic writing',
    void Function(String)? onChunk,
  }) => executor.execute(
    model: qualifiedBrainModel,
    capability: capability,
    text: text,
    onChunk: onChunk ?? (_) {},
  );

  test('each capability verifies files, uses bounded isolated session, and releases weights', () async {
    expect(models, isEmpty);
    for (final capability in BrainCapability.values) {
      final chunks = <String>[];
      await run(capability: capability, onChunk: chunks.add);
      expect(chunks.join(), 'one two');
      expect(
        models.last.sessions.single.prompt,
        contains(capability.instruction),
      );
      expect(
        models.last.sessions.single.prompt,
        contains('<text>\nSynthetic writing\n</text>'),
      );
      expect(models.last.sessions.single.closed, 1);
      expect(models.last.closed, 1);
      expect(executor.busy, isFalse);
    }
    expect(files.checks, 3);
  });

  test(
    'unsupported capability and invalid input allocate no native resource',
    () async {
      const incompatible = BrainModel(
        id: 'other',
        label: 'Other',
        bytes: 1,
        sha256: '',
        url: '',
        capabilities: {},
      );
      expect(
        () => executor.execute(
          model: incompatible,
          capability: BrainCapability.rewrite,
          text: 'Synthetic',
          onChunk: (_) {},
        ),
        throwsA(fails(BrainFailure.incompatible)),
      );
      for (final text in [' ', 'a' * 2001]) {
        expect(() => run(text: text), throwsA(fails(BrainFailure.input)));
      }
      expect(models, isEmpty);
      expect(files.checks, 0);
    },
  );

  for (final state in [
    ModelFileState.missing,
    ModelFileState.corrupt,
    ModelFileState.interrupted,
  ]) {
    test('$state files prevent native load', () async {
      files.state = state;
      await expectLater(
        run(),
        throwsA(
          fails(
            state == ModelFileState.corrupt
                ? BrainFailure.integrity
                : BrainFailure.missing,
          ),
        ),
      );
      expect(models, isEmpty);
    });
  }

  test(
    'resource load failure is safe, releases slot and permits explicit retry',
    () async {
      var attempts = 0;
      executor = BrainExecutor(
        files: files,
        loadModel: (_, _) async {
          if (++attempts == 1) throw StateError('/private/path OOM text');
          return FakeModel();
        },
      );
      await expectLater(run(), throwsA(fails(BrainFailure.load)));
      expect(executor.busy, isFalse);
      await run();
      expect(attempts, 2);
    },
  );

  for (final disposal in [false, true]) {
    test(
      '${disposal ? 'dispose' : 'cancel'} during loading waits then closes late model without prompting',
      () async {
        final loading = Completer<LocalModel>();
        final began = Completer<void>();
        executor = BrainExecutor(
          files: files,
          loadModel: (_, _) {
            began.complete();
            return loading.future;
          },
        );
        final running = expectLater(
          run(),
          throwsA(fails(BrainFailure.cancelled)),
        );
        await began.future;
        final stopping = disposal ? executor.dispose() : executor.cancel();
        expect(
          () => run(),
          throwsA(fails(disposal ? BrainFailure.disposed : BrainFailure.busy)),
        );
        final late = FakeModel();
        loading.complete(late);
        await stopping;
        await running;
        expect(late.sessions, isEmpty);
        expect(late.closed, 1);
      },
    );
  }

  test('cancel after first delta suppresses late output, cleans up, and permits new request', () async {
    final model = FakeModel()..hold = true;
    executor = BrainExecutor(files: files, loadModel: (_, _) async => model);
    final first = Completer<void>();
    final chunks = <String>[];
    final running = expectLater(
      run(
        onChunk: (s) {
          chunks.add(s);
          first.complete();
        },
      ),
      throwsA(fails(BrainFailure.cancelled)),
    );
    await first.future;
    await executor.cancel();
    await running;
    expect(chunks, ['one']);
    expect(model.sessions.single.stopped, 1);
    expect(model.sessions.single.closed, 1);
    expect(model.closed, 1);
    model.hold = false;
    await run();
  });

  for (final stage in [
    'create',
    'prompt',
    'stream',
    'close',
    'stop',
    'modelClose',
  ]) {
    test(
      '$stage failure reports useful category and closes weights; unsafe cleanup prevents reload',
      () async {
        final model = FakeModel()..failAt = stage;
        model.hold = stage == 'stop';
        var loads = 0;
        executor = BrainExecutor(
          files: files,
          loadModel: (_, _) async {
            loads++;
            return model;
          },
        );
        final first = Completer<void>();
        final failedCleanup = ['close', 'stop', 'modelClose'].contains(stage);
        final running = expectLater(
          run(
            onChunk: (_) {
              if (!first.isCompleted) first.complete();
            },
          ),
          throwsA(
            fails(
              failedCleanup ? BrainFailure.cleanup : BrainFailure.generation,
            ),
          ),
        );
        if (stage == 'stop') {
          await first.future;
          await executor.cancel();
        }
        await running;
        expect(model.closed, 1);
        if (failedCleanup) {
          expect(() => run(), throwsA(fails(BrainFailure.cleanup)));
          expect(loads, 1);
        }
      },
    );
  }

  testWidgets('generation deadline stops native work and closes model', (
    tester,
  ) async {
    final model = FakeModel()..hold = true;
    executor = BrainExecutor(
      files: files,
      loadModel: (_, _) async => model,
      requestTimeout: const Duration(milliseconds: 10),
    );
    final running = expectLater(run(), throwsA(fails(BrainFailure.timeout)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await running;
    expect(model.closed, 1);
    expect(model.sessions.single.stopped, 1);
  });
}

Matcher fails(BrainFailure failure) =>
    isA<BrainException>().having((e) => e.failure, 'safe failure', failure);
