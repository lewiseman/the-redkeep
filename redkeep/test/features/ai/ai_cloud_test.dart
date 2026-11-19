import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/fake_ai_provider.dart';

void main() {
  late AppDatabase db;
  late FakeAiProviderClient fake;
  late DateTime now;

  ProviderContainer scope([AiCloudSettings? settings = testAiSettings]) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncEnabledProvider.overrideWithValue(false),
        aiClockProvider.overrideWithValue(() => now),
        protectedAiProvidersProvider.overrideWithValue(
          MemoryAiProviders(saved: settings),
        ),
        aiCloudClientProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fake = FakeAiProviderClient('Hello');
    now = DateTime(2026, 11, 7);
  });
  tearDown(() => db.close());

  test('no spending limit ever holds back a request', () async {
    final saved = AiCloudSettings.tryParse({
      ...testAiSettings.toJson(),
      'monthlyLimitUsd': 1,
    });
    final container = scope(saved);
    fake.usage = const AiUsage(inputTokens: 1000000, outputTokens: 1000000);
    final cloud = container.read(aiCloudProvider);
    for (var i = 0; i < 3; i++) {
      await cloud.chat(system: 's', user: 'u', outputTokens: 100000);
    }
    expect(fake.requests, hasLength(3));
  });

  test('a capability the provider lacks never sends a request', () async {
    final container = scope(
      testAiSettings.copyWith(models: {AiCapability.chat: 'test-model'}),
    );
    final cloud = container.read(aiCloudProvider);
    await expectLater(
      cloud.transcribe(Uint8List(4), seconds: 1),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.unsupported,
        ),
      ),
    );
    expect(fake.transcribed, isEmpty);
    expect(
      container.read(aiCapabilitiesProvider),
      isNot(contains(AiCapability.transcription)),
    );
  });

  test(
    'a rejected key is remembered until the settings are saved again',
    () async {
      final container = scope();
      fake.failure = const AiProviderFailure(AiProviderFailureKind.badToken);
      await expectLater(
        container
            .read(aiCloudProvider)
            .chat(system: 's', user: 'u', outputTokens: 10),
        throwsA(isA<AiProviderFailure>()),
      );
      expect(container.read(aiKeyStatusProvider), isTrue);
      await container
          .read(aiCloudSettingsProvider.notifier)
          .save(testAiSettings.copyWith(token: 'new-token'));
      expect(container.read(aiKeyStatusProvider), isFalse);
    },
  );

  test('without a provider nothing is sent', () async {
    final container = scope(null);
    await expectLater(
      container
          .read(aiCloudProvider)
          .chat(system: 's', user: 'u', outputTokens: 10),
      throwsA(
        isA<AiProviderFailure>().having(
          (f) => f.kind,
          'kind',
          AiProviderFailureKind.notConfigured,
        ),
      ),
    );
    expect(fake.requests, isEmpty);
  });
}
