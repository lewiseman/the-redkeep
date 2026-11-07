import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/more/application/maestar_status.dart';

import '../../support/fake_ai_provider.dart';

void main() {
  Future<({String label, bool ready})> status({
    AiCloudSettings? settings,
    bool enabled = true,
    bool rejected = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        aiEnabledProvider.overrideWithValue(enabled),
        protectedAiProvidersProvider.overrideWithValue(
          MemoryAiProviders(saved: settings),
        ),
      ],
    );
    final sub = container.listen(maestarStatusProvider, (_, _) {});
    await container.read(aiCloudSettingsProvider.future);
    if (rejected) container.read(aiKeyStatusProvider.notifier).rejected();
    await pumpEventQueue();
    return sub.read();
  }

  test('AI disabled reads as needing setup', () async {
    expect(await status(enabled: false), (label: 'Set up AI', ready: false));
  });
  test('no provider asks for one', () async {
    expect(await status(), (label: 'Add an AI provider', ready: false));
  });
  test('a provider shows its name and writing model', () async {
    expect(await status(settings: testAiSettings), (
      label: 'OpenAI · test-model',
      ready: true,
    ));
  });
  test('a rejected key asks to check it', () async {
    expect(await status(settings: testAiSettings, rejected: true), (
      label: 'OpenAI · Check your key',
      ready: false,
    ));
  });
  test('a provider without a writing model asks for one', () async {
    expect(
      await status(
        settings: testAiSettings.copyWith(
          models: {AiCapability.embeddings: 'e'},
        ),
      ),
      (label: 'OpenAI · Choose a model', ready: false),
    );
  });
}
