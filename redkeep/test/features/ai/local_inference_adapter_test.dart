import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/local_inference_adapter.dart';
import 'package:redkeep/features/ai/domain/local_inference.dart';

import '../../support/fake_local_model.dart';

void main() {
  test('streams deltas, frees sessions, and repeats without history', () async {
    final model = FakeModel();
    final adapter = LocalInferenceAdapter(model);
    for (var i = 0; i < 3; i++) {
      final run = adapter.generate('synthetic $i');
      expect(await run.chunks.toList(), ['one', ' two']);
      await run.done;
      expect(run.failure, isNull);
    }
    expect(model.sessions.map((s) => s.prompt), [
      'synthetic 0',
      'synthetic 1',
      'synthetic 2',
    ]);
    expect(model.sessions.every((s) => s.closed == 1), isTrue);
    await adapter.close();
    await adapter.close();
    expect(model.closed, 1);
  });

  test('rejects overlap synchronously and keeps adapters isolated', () async {
    final one = LocalInferenceAdapter(FakeModel());
    final two = LocalInferenceAdapter(FakeModel());
    final run = one.generate('one');
    expect(
      () => one.generate('overlap'),
      throwsA(fails(InferenceFailure.busy)),
    );
    expect(await two.generate('two').chunks.toList(), isNotEmpty);
    expect(await run.chunks.toList(), isNotEmpty);
    await one.close();
    await two.close();
  });

  test(
    'cancel stops native work, ignores late data, then allows reuse',
    () async {
      final model = FakeModel()..hold = true;
      final adapter = LocalInferenceAdapter(model);
      final run = adapter.generate('list numbers');
      final seen = <String>[];
      final first = Completer<void>();
      final subscription = run.chunks.listen((s) {
        seen.add(s);
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      await run.cancel();
      await run.cancel();
      expect(seen, ['one']);
      expect(model.sessions.single.stopped, 1);
      expect(model.sessions.single.closed, 1);
      expect(run.cancelled, isTrue);
      await subscription.cancel();
      model.hold = false;
      expect(
        await adapter.generate('after cancel').chunks.toList(),
        isNotEmpty,
      );
      await adapter.close();
    },
  );

  test('subscription cancellation also stops and closes native work', () async {
    final model = FakeModel()..hold = true;
    final adapter = LocalInferenceAdapter(model);
    final run = adapter.generate('synthetic');
    final first = Completer<void>();
    final subscription = run.chunks.listen((_) => first.complete());
    await first.future;
    await subscription.cancel();
    await run.done;
    expect(model.sessions.single.stopped, 1);
    expect(model.sessions.single.closed, 1);
    await adapter.close();
  });

  test('close cancels a turn that was never subscribed', () async {
    final model = FakeModel();
    final adapter = LocalInferenceAdapter(model);
    final run = adapter.generate('never listened');
    await adapter.close();
    await run.done;
    expect(model.sessions, isEmpty);
    expect(model.closed, 1);
    expect(
      () => adapter.generate('late'),
      throwsA(fails(InferenceFailure.disposed)),
    );
  });

  test(
    'cancel during session creation closes it without sending text',
    () async {
      final model = FakeModel()..creation = Completer<LocalSession>();
      final adapter = LocalInferenceAdapter(model);
      final run = adapter.generate('never send');
      final consumed = run.chunks.toList();
      await Future<void>.delayed(Duration.zero);
      final cancellation = run.cancel();
      final session = FakeSession();
      model.creation!.complete(session);
      await cancellation;
      expect(await consumed, isEmpty);
      expect(session.prompt, isNull);
      expect(session.stopped, 1);
      expect(session.closed, 1);
      await adapter.close();
    },
  );

  test(
    'subscription cancelled during creation waits before model close',
    () async {
      final model = FakeModel()..creation = Completer<LocalSession>();
      final adapter = LocalInferenceAdapter(model);
      final run = adapter.generate('never send');
      final subscription = run.chunks.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      final cancellation = subscription.cancel();
      final closing = adapter.close();
      expect(model.closed, 0);
      final session = FakeSession();
      model.creation!.complete(session);
      await cancellation;
      await closing;
      expect(session.prompt, isNull);
      expect(session.closed, 1);
      expect(model.closed, 1);
    },
  );

  for (final stage in ['create', 'prompt', 'stream']) {
    test('$stage failure is safe and the next request can recover', () async {
      final model = FakeModel()..failAt = stage;
      final adapter = LocalInferenceAdapter(model);
      final run = adapter.generate('private-looking synthetic content');
      await expectLater(
        run.chunks,
        emitsError(fails(InferenceFailure.generation)),
      );
      await run.done;
      expect(model.sessions.every((s) => s.closed == 1), isTrue);
      model.failAt = null;
      expect(await adapter.generate('retry').chunks.toList(), isNotEmpty);
      await adapter.close();
    });
  }

  for (final stage in ['stop', 'close']) {
    test(
      '$stage failure prevents unsafe model reuse but releases weights',
      () async {
        final model = FakeModel()..failAt = stage;
        model.hold = stage == 'stop';
        final adapter = LocalInferenceAdapter(model);
        final run = adapter.generate('synthetic');
        final errors = <Object>[];
        final first = Completer<void>();
        run.chunks.listen((_) {
          if (!first.isCompleted) first.complete();
        }, onError: errors.add);
        await first.future;
        if (stage == 'stop') await run.cancel();
        await run.done;
        await Future<void>.delayed(Duration.zero);
        expect(errors.single, isA<InferenceException>());
        expect(
          () => adapter.generate('retry'),
          throwsA(fails(InferenceFailure.disposed)),
        );
        expect(model.sessions.single.closed, 1);
        await adapter.close();
        expect(model.closed, 1);
      },
    );
  }

  test('model close failure is explicit and close is idempotent', () async {
    final model = FakeModel()..failAt = 'modelClose';
    final adapter = LocalInferenceAdapter(model);
    await expectLater(
      adapter.close(),
      throwsA(fails(InferenceFailure.cleanup)),
    );
    await expectLater(
      adapter.close(),
      throwsA(fails(InferenceFailure.cleanup)),
    );
    expect(model.closed, 1);
  });

  test('invalid requests allocate no session', () async {
    final model = FakeModel();
    final adapter = LocalInferenceAdapter(model);
    expect(() => adapter.generate(' '), throwsArgumentError);
    expect(() => adapter.generate('a' * 4097), throwsArgumentError);
    expect(model.sessions, isEmpty);
    await adapter.close();
  });
}

Matcher fails(InferenceFailure failure) =>
    isA<InferenceException>().having((e) => e.failure, 'safe failure', failure);
