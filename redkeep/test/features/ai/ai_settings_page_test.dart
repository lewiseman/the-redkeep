import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/ai/domain/ai_provider_catalog.dart';
import 'package:redkeep/features/ai/presentation/ai_settings_page.dart';
import 'package:redkeep/features/ai/presentation/maestar_chain_rows.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_terms.dart';

import '../../support/fake_ai_provider.dart';
import '../../support/pump_app.dart';

void main() {
  test('an address is recognised as its service, or as your own', () {
    expect(
      aiProviderPresetForAddress('https://api.groq.com/openai/v1').id,
      'groq',
    );
    expect(
      aiProviderPresetForAddress('https://api.openai.com/v1').id,
      'openai',
    );
    expect(
      aiProviderPresetForAddress('https://llm.home.example/v1'),
      customAiProviderPreset,
    );
    expect(aiProviderPresetForAddress('not a url'), customAiProviderPreset);
  });

  test('only models fit for a skill are offered first', () {
    expect(modelFitsSkill(AiCapability.chat, 'gpt-5-mini'), isTrue);
    expect(modelFitsSkill(AiCapability.chat, 'gpt-image-1'), isFalse);
    expect(modelFitsSkill(AiCapability.chat, 'text-embedding-3'), isFalse);
    expect(
      modelFitsSkill(AiCapability.transcription, 'gpt-4o-mini-transcribe'),
      isTrue,
    );
    expect(modelFitsSkill(AiCapability.transcription, 'gpt-5'), isFalse);
  });

  late FakeAiProviderClient client;
  late List<Uri> opened;

  Future<ProviderContainer> open(
    WidgetTester tester, {
    AiCloudSettings? saved = testAiSettings,
  }) async {
    client = FakeAiProviderClient()
      ..models = const ['test-model', 'better-model', 'gpt-image-1'];
    opened = [];
    await pumpApp(
      tester,
      initialLocation: '/settings/brain',
      aiSettings: saved,
      aiProvider: client,
      overrides: [
        onboardingLegalLinkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(AiSettingsPage)),
    );
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('ai-settings')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('there is no list of providers and no Save button', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Choose a provider'), findsNothing);
    expect(find.text('Google Gemini'), findsNothing);
    expect(find.text('Save'), findsNothing);
    await reveal(tester, find.text('Built by Lewis'));
    expect(find.text('Built by Lewis'), findsOneWidget);
  });

  testWidgets('keeping a key saves it at once, as the service it names', (
    tester,
  ) async {
    final container = await open(tester, saved: null);
    await reveal(tester, find.byKey(const ValueKey('ai-provider-key-row')));
    await tester.tap(find.byKey(const ValueKey('ai-provider-key-row')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ai-provider-url')),
      'https://api.groq.com/openai/v1',
    );
    await tester.pump();
    expect(find.text('Recognised: Groq'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('ai-provider-token')),
      'gsk-secret-1234',
    );
    await tester.tap(find.byKey(const ValueKey('ai-key-keep')));
    await tester.pumpAndSettle();

    final saved = container.read(aiCloudSettingsProvider).value!;
    expect(saved.presetId, 'groq');
    expect(saved.baseUrl, 'https://api.groq.com/openai/v1');
    expect(saved.token, 'gsk-secret-1234');
    expect(find.text('Accepted. 3 models to choose from.'), findsOneWidget);
  });

  testWidgets('choosing a model keeps it and closes the sheet', (tester) async {
    final container = await open(tester);
    final writing = find.byKey(const ValueKey('ai-model-row-chat'));
    await reveal(tester, writing);
    await tester.tap(writing);
    await tester.pumpAndSettle();

    expect(find.text('In use'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-model-option-gpt-image-1')),
      findsNothing,
      reason: 'cannot write',
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-model-option-better-model')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ModelSheet), findsNothing);
    expect(
      container.read(aiCloudSettingsProvider).value!.model(AiCapability.chat),
      'better-model',
    );
  });

  testWidgets('forgetting the key asks first, on the sheet', (tester) async {
    final container = await open(tester);
    await reveal(tester, find.byKey(const ValueKey('ai-provider-key-row')));
    await tester.tap(find.byKey(const ValueKey('ai-provider-key-row')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-key-forget')));
    await tester.pumpAndSettle();
    expect(container.read(aiCloudSettingsProvider).value, isNotNull);
    await tester.tap(find.byKey(const ValueKey('ai-key-forget-confirm')));
    await tester.pumpAndSettle();
    expect(container.read(aiCloudSettingsProvider).value, isNull);
  });

  testWidgets('the small print opens in the browser', (tester) async {
    await open(tester);
    await reveal(tester, find.text('Privacy'));
    await tester.tap(find.text('Terms of service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(opened.map((u) => u.path), ['/terms.html', '/privacy.html']);
  });
}
