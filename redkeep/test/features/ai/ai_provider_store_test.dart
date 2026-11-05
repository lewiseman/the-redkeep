import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/application/ai_providers.dart';
import 'package:redkeep/features/ai/data/ai_provider_store.dart';
import 'package:redkeep/features/ai/data/legacy_phone_ai_cleanup.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';

import '../../support/fake_ai_provider.dart';

void main() {
  test(
    'connections round-trip with their token and clear completely',
    () async {
      final memory = MemoryAiProviders();
      final store = AiProviderStore(memory);
      await store.write(const [testAiProvider]);
      final read = (await store.read()).single;
      expect(read.token, testAiProvider.token);
      expect(read.baseUrl, testAiProvider.baseUrl);
      expect(read.format, testAiProvider.format);
      await store.clear();
      expect(memory.value, isNull);
      expect(await store.read(), isEmpty);
    },
  );

  test('damaged storage reads as no providers', () async {
    for (final raw in ['not json', '{}', '[1]', '[{"id":"x"}]']) {
      final store = AiProviderStore(MemoryAiProviders()..value = raw);
      expect(await store.read(), isEmpty, reason: raw);
    }
  });

  group('with a database', () {
    late AppDatabase db;
    late MemoryAiProviders memory;
    late ProviderContainer scope;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      memory = MemoryAiProviders(saved: const [testAiProvider]);
      scope = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          protectedAiProvidersProvider.overrideWithValue(memory),
        ],
      );
    });
    tearDown(() async {
      scope.dispose();
      await db.close();
    });

    test('tokens are never written to the database', () async {
      await scope
          .read(aiPreferencesRepositoryProvider)
          .setDefaultRoute(AiRoute.provider(testAiProvider.id, 'test-model'));
      final row = await db.select(db.aiPreferencesTable).getSingle();
      expect(row.routes, contains(testAiProvider.id));
      expect(row.routes, isNot(contains(testAiProvider.token)));
    });

    test('save rejects bad URLs before storing and replaces by ID', () async {
      final notifier = scope.read(aiProvidersProvider.notifier);
      await scope.read(aiProvidersProvider.future);
      await expectLater(
        notifier.save(
          testAiProvider.copyWith(baseUrl: 'http://insecure.example'),
        ),
        throwsA(isA<AiProviderFailure>()),
      );
      expect(
        (await scope.read(aiProvidersProvider.future)).single.baseUrl,
        testAiProvider.baseUrl,
      );
      await notifier.save(testAiProvider.copyWith(name: 'Renamed'));
      expect(
        (await scope.read(aiProvidersProvider.future)).single.name,
        'Renamed',
      );
    });

    test('removing a provider deletes its token and routes', () async {
      final prefs = scope.read(aiPreferencesRepositoryProvider);
      await prefs.setDefaultRoute(AiRoute.provider(testAiProvider.id, 'm'));
      await scope.read(aiProvidersProvider.future);
      await scope.read(aiProvidersProvider.notifier).remove(testAiProvider.id);
      expect(memory.value, isNot(contains(testAiProvider.token)));
      expect((await prefs.read()).defaultRoute, const AiRoute.companion());
    });

    test('account reset clears routes', () async {
      final prefs = scope.read(aiPreferencesRepositoryProvider);
      await prefs.setDefaultRoute(AiRoute.provider(testAiProvider.id, 'm'));
      await DriftAccountResetData(db).clear();
      expect((await prefs.read()).defaultRoute, const AiRoute.companion());
    });
  });

  test('legacy cleanup removes only the old model and its caches', () async {
    final root = await Directory.systemTemp.createTemp('redkeep-legacy-');
    addTearDown(() => root.delete(recursive: true));
    final model = File('${root.path}/brain-models/qwen.litertlm')
      ..createSync(recursive: true);
    final cache = File(
      '${root.path}/qwen3-06b-int8-722a0a54.litertlm_17_613722264.xnnpack_cache',
    )..createSync();
    final kept = File('${root.path}/note_media/photo.jpg')
      ..createSync(recursive: true);
    final similar = File(
      '${root.path}/other.litertlm_17_613722264.xnnpack_cache',
    )..createSync();
    await removeLegacyPhoneAiFiles(root);
    expect(model.existsSync(), isFalse);
    expect(cache.existsSync(), isFalse);
    expect(kept.existsSync(), isTrue);
    expect(similar.existsSync(), isTrue);
    await removeLegacyPhoneAiFiles(root); // Repeating on each launch is safe.
  });
}
