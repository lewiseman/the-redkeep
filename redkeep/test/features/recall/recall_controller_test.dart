import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer scope;
  late MemoryVectors vectors;
  late FakeEmbedder embedder;
  late DriftNotesRepository notes;
  const never = (quiet: Duration(hours: 1), flush: Duration(hours: 1));
  Future<ProviderContainer> start({
    ({Duration quiet, Duration flush}) timing = never,
  }) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        protectedAiProvidersProvider.overrideWithValue(
          MemoryAiProviders(saved: testAiSettings),
        ),
        recallTimingProvider.overrideWithValue(timing),
        recallVectorsProvider.overrideWith((ref) async => vectors),
        recallEmbedderProvider.overrideWithValue(embedder),
      ],
    );
    container.listen(aiPreferencesProvider, (_, _) {});
    container.listen(recallControllerProvider, (_, _) {});
    await container.read(aiPreferencesProvider.future);
    await container.read(aiCloudSettingsProvider.future);
    return container;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notes = DriftNotesRepository(db, clock: () => DateTime.utc(2026, 11, 4));
    vectors = MemoryVectors();
    embedder = FakeEmbedder();
    await db.select(db.aiPreferencesTable).get();
    scope = await start();
  });
  tearDown(() async {
    scope.dispose();
    await db.close();
  });
  Future<void> save(
    String body, {
    int revision = 0,
    String id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  }) async {
    await notes.saveNote(
      id: id,
      text: PlainTextDocument(title: 'Garden', body: body),
      expectedRevision: revision,
      details: const NoteDetails(),
    );
  }

  test('chunks from several notes share one embedding request', () async {
    await save('Garden writing');
    await save('Kitchen writing', id: 'b' * 32);
    await save('Travel writing', id: 'c' * 32);
    await scope.read(recallControllerProvider.notifier).run();
    expect(embedder.documentBatches, hasLength(1));
    expect(embedder.documentBatches.single, hasLength(3));
    expect(await db.select(db.recallQueue).get(), isEmpty);
    expect(vectors.rows, hasLength(3));
  });

  test(
    'writing waits for the quiet window; leaving an editor indexes sooner',
    () async {
      scope.dispose();
      scope = await start(
        timing: (
          quiet: const Duration(milliseconds: 400),
          flush: const Duration(milliseconds: 10),
        ),
      );
      await save('First burst');
      await save('Second burst', revision: 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(embedder.documentBatches, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(embedder.documentBatches, hasLength(1));

      await save('Third burst', revision: 2);
      scope.read(recallControllerProvider.notifier).flushSoon();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(embedder.documentBatches, hasLength(2));
      expect(embedder.documentBatches.last.single, contains('Third burst'));
    },
  );

  test(
    'a provider without embeddings sends nothing and search uses keywords',
    () async {
      embedder.key = null;
      await save('Garden writing');
      final controller = scope.read(recallControllerProvider.notifier);
      await controller.run();
      expect(embedder.batches, isEmpty);
      expect(
        scope.read(recallControllerProvider).message,
        contains('keywords'),
      );
      final result = await controller.search('garden', 'note');
      expect(result.semantic, isFalse);
      expect(embedder.batches, isEmpty);
    },
  );

  test('a rejected key stops indexing until the settings change', () async {
    await save('Garden writing');
    embedder.failure = const AiProviderFailure(AiProviderFailureKind.badToken);
    final controller = scope.read(recallControllerProvider.notifier);
    await controller.run();
    expect(
      scope.read(recallControllerProvider).message,
      contains('Indexing stopped'),
    );
    final sent = embedder.batches.length;
    await controller.run();
    expect(embedder.batches, hasLength(sent));
    embedder.failure = null;
    await scope
        .read(aiCloudSettingsProvider.notifier)
        .save(testAiSettings.copyWith(token: 'new-token'));
    await controller.run();
    expect(await db.select(db.recallQueue).get(), isEmpty);
  });

  test('offline indexing waits and keeps the queue', () async {
    await save('Garden writing');
    embedder.failure = const AiProviderFailure(AiProviderFailureKind.offline);
    final controller = scope.read(recallControllerProvider.notifier);
    await controller.run();
    expect(
      scope.read(recallControllerProvider).message,
      contains('connection'),
    );
    expect(await db.select(db.recallQueue).get(), hasLength(1));
    embedder.failure = null;
    await controller.run();
    expect(await db.select(db.recallQueue).get(), isEmpty);
  });

  test(
    'full long text is indexed and retrieved sources are revalidated',
    () async {
      await save('Planting 🌿 中文\n' * 2600);
      final controller = scope.read(recallControllerProvider.notifier);
      await controller.run();
      expect(embedder.documentBatches.expand((b) => b).length, greaterThan(8));
      expect(
        vectors.rows.values.map((r) => r['content'] as String).join(),
        startsWith('Garden'),
      );
      expect(await db.select(db.recallQueue).get(), isEmpty);
      expect((await controller.search('plants', 'note')).sources, hasLength(1));
      await save('Newer unrelated writing', revision: 1);
      expect((await controller.search('plants', 'note')).sources, isEmpty);
    },
  );
  test('edits during embedding leave new outbox work and cannot install stale manifests', () async {
    await save('Original garden writing');
    embedder.gate = Completer<void>();
    final controller = scope.read(recallControllerProvider.notifier);
    final running = controller.run();
    for (var i = 0; i < 100 && embedder.documentBatches.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await save('Edited garden writing', revision: 1);
    embedder.gate!.complete();
    await running;
    expect(
      (await db.select(db.recallManifests).get()).where((m) => m.complete),
      isEmpty,
    );
    expect(await db.select(db.recallQueue).get(), hasLength(1));
    embedder.gate = null;
    await controller.run();
    expect(await db.select(db.recallQueue).get(), isEmpty);
    expect((await db.select(db.recallManifests).getSingle()).revision, 2);
  });
  test('backgrounding fences late embeddings and keyword fallback remains available', () async {
    await save('Garden writing');
    embedder.gate = Completer<void>();
    final controller = scope.read(recallControllerProvider.notifier);
    final running = controller.run();
    for (var i = 0; i < 100 && embedder.documentBatches.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    controller.foreground(false);
    embedder.gate!.complete();
    await running;
    expect(vectors.rows, isEmpty);
    expect(await db.select(db.recallQueue).get(), hasLength(1));
    expect((await controller.search('garden', 'note')).semantic, isFalse);
  });
  test('opt-out erases vectors; failed cleanup stops indexing until an explicit rebuild succeeds', () async {
    await save('Garden writing');
    final controller = scope.read(recallControllerProvider.notifier);
    await controller.run();
    expect(vectors.rows, isNotEmpty);
    vectors.failReset = true;
    await controller.setEnabled('note', false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await controller.run();
    expect((await controller.search('garden', 'note')).sources, isEmpty);
    expect(
      scope.read(recallControllerProvider).message,
      contains('Could not clear'),
    );
    vectors.failReset = false;
    await controller.rebuild();
    expect(vectors.rows, isEmpty);
    expect(await db.select(db.recallManifests).get(), isEmpty);
    await controller.setEnabled('note', true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await controller.run();
    expect(vectors.rows, isNotEmpty);
  });
  test(
    'rebuild during an embedding run drains the old run without deadlocking',
    () async {
      await save('Garden writing');
      embedder.gate = Completer<void>();
      final controller = scope.read(recallControllerProvider.notifier);
      final running = controller.run();
      for (var i = 0; i < 100 && embedder.documentBatches.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final rebuilding = controller.rebuild();
      embedder.gate!.complete();
      await running;
      await rebuilding;
      embedder.gate = null;
      await controller.run();
      expect(await db.select(db.recallQueue).get(), isEmpty);
      expect(vectors.rows, isNotEmpty);
    },
  );
  test(
    'deleting writing after an interrupted vector write removes partial chunks',
    () async {
      await save('Garden writing 🌿\n' * 1400);
      vectors.failPutAt = 2;
      final controller = scope.read(recallControllerProvider.notifier);
      await controller.run();
      expect(vectors.rows, hasLength(1));
      expect((await db.select(db.recallManifests).getSingle()).complete, false);
      await notes.deleteNote('a' * 32, 1);
      vectors.failPutAt = null;
      await controller.run();
      expect(vectors.rows, isEmpty);
      expect(await db.select(db.recallQueue).get(), isEmpty);
    },
  );
  test('an opt-out interrupted before cleanup is completed on the next coordinator start', () async {
    await save('Garden writing');
    final controller = scope.read(recallControllerProvider.notifier);
    await controller.run();
    controller.foreground(false);
    await scope.read(aiPreferencesRepositoryProvider).collection('note', false);
    scope.dispose();
    scope = await start();
    await scope.read(recallControllerProvider.notifier).run();
    expect(vectors.rows, isEmpty);
    expect(
      await scope.read(aiPreferencesRepositoryProvider).cleanupRequired(),
      false,
    );
  });
}
