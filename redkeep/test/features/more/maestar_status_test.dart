import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/application/ai_providers.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/more/application/maestar_status.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_ai_provider.dart';

void main() {
  Future<({String label, bool ready})> status({
    AiRoute route = const AiRoute.companion(),
    CompanionState connection = const CompanionState(
      phase: CompanionPhase.idle,
    ),
    bool enabled = true,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        aiEnabledProvider.overrideWithValue(enabled),
        companionControllerProvider.overrideWith(
          () => TestConnection(connection),
        ),
        protectedAiProvidersProvider.overrideWithValue(
          MemoryAiProviders(saved: const [testAiProvider]),
        ),
      ],
    );
    await container
        .read(aiPreferencesRepositoryProvider)
        .setDefaultRoute(route);
    container.listen(aiPreferencesProvider, (_, _) {});
    container.listen(aiProvidersProvider, (_, _) {});
    final sub = container.listen(maestarStatusProvider, (_, _) {});
    await container.read(aiPreferencesProvider.future);
    await container.read(aiProvidersProvider.future);
    await pumpEventQueue();
    return sub.read();
  }

  test('AI disabled reads as needing setup', () async {
    expect(await status(enabled: false), (label: 'Set up AI', ready: false));
  });
  test('no computer and no provider asks for one', () async {
    expect(await status(), (
      label: 'Connect a computer or add a provider',
      ready: false,
    ));
  });
  test('a provider default shows the provider and model', () async {
    expect(
      await status(route: AiRoute.provider(testAiProvider.id, 'test-model')),
      (label: 'Test AI · test-model', ready: true),
    );
  });
  test('a removed provider default asks for another', () async {
    expect(await status(route: const AiRoute.provider('gone', 'model')), (
      label: 'Choose a provider',
      ready: false,
    ));
  });
  test('a connected computer reports writing readiness', () async {
    expect(await status(connection: readyComputer()), (
      label: 'Computer connected · Writing ready',
      ready: true,
    ));
    expect(await status(connection: readyComputer(writingStatus: 'unloaded')), (
      label: 'Computer connected · Check models',
      ready: false,
    ));
  });
}
