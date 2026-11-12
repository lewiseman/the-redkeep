import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/storage_providers.dart';
import '../../sync/application/sync_providers.dart' show networkServiceProvider;
import '../data/ai_provider_store.dart';
import '../data/ai_spend_ledger.dart';
import '../data/cloud_ai_client.dart';
import '../domain/ai_conversation.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_provider_catalog.dart';

final aiClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final aiIdProvider = Provider<String Function()>(
  (ref) => () {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  },
);

/// Connectivity check before each call. A failing check never blocks a call.
final aiOnlineProvider = Provider<AiOnline>((ref) {
  final network = ref.watch(networkServiceProvider);
  return () async {
    try {
      return await network.isOnline();
    } catch (_) {
      return true;
    }
  };
});
final protectedAiProvidersProvider = Provider<ProtectedAiProviders>(
  (ref) => SecureAiProviders(),
);
final aiProviderStoreProvider = Provider<AiProviderStore>(
  (ref) => AiProviderStore(ref.watch(protectedAiProvidersProvider)),
);
final aiCloudClientProvider = Provider<AiCloudClient>((ref) {
  final transport = AiTransport(
    http.Client(),
    online: ref.watch(aiOnlineProvider),
  );
  ref.onDispose(transport.close);
  return CloudAiClient(transport);
});
final aiSpendLedgerProvider = Provider<AiSpendLedger>(
  (ref) => AiSpendLedger(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(aiClockProvider),
  ),
);
final aiMonthSpendProvider = StreamProvider<double>(
  (ref) => ref.watch(aiSpendLedgerProvider).watchSpent(),
);

/// The one cloud provider, or null before the person adds one.
final aiCloudSettingsProvider =
    AsyncNotifierProvider<AiCloudSettingsNotifier, AiCloudSettings?>(
      AiCloudSettingsNotifier.new,
    );

class AiCloudSettingsNotifier extends AsyncNotifier<AiCloudSettings?> {
  @override
  Future<AiCloudSettings?> build() => ref.read(aiProviderStoreProvider).read();

  Future<void> save(AiCloudSettings settings) async {
    parseAiProviderBaseUrl(settings.baseUrl);
    await ref.read(aiProviderStoreProvider).write(settings);
    ref.read(aiKeyStatusProvider.notifier).reset();
    state = AsyncData(settings);
  }

  Future<void> clear() async {
    await ref.read(aiProviderStoreProvider).clear();
    ref.read(aiKeyStatusProvider.notifier).reset();
    state = const AsyncData(null);
  }
}

/// Set when the provider rejects the key. Background work stops until the
/// settings change; requests the person makes still try and explain.
final aiKeyStatusProvider = NotifierProvider<AiKeyStatus, bool>(
  AiKeyStatus.new,
);

class AiKeyStatus extends Notifier<bool> {
  @override
  bool build() => false;
  void rejected() => state = true;
  void reset() => state = false;
}

/// What the configured provider can do right now. Empty until loaded.
final aiCapabilitiesProvider = Provider<Set<AiCapability>>((ref) {
  final settings = ref.watch(aiCloudSettingsProvider).value;
  return {
    if (settings != null)
      for (final capability in AiCapability.values)
        if (settings.supports(capability)) capability,
  };
});

final aiCloudProvider = Provider<AiCloud>(AiCloud.new);

/// Every cloud call goes through here: capability, spending limit, the call,
/// then usage. A missing capability fails before anything is sent.
class AiCloud {
  AiCloud(this.ref);
  final Ref ref;

  Future<({AiCloudSettings settings, String model})> _ready(
    AiCapability capability,
  ) async {
    final settings = await ref.read(aiCloudSettingsProvider.future);
    if (settings == null || !settings.configured) {
      throw const AiProviderFailure(AiProviderFailureKind.notConfigured);
    }
    if (!settings.supports(capability)) {
      throw const AiProviderFailure(AiProviderFailureKind.unsupported);
    }
    final model = settings.model(
      capability == AiCapability.vision ? AiCapability.chat : capability,
    )!;
    return (settings: settings, model: model);
  }

  /// The search index identity. Changing provider or model rebuilds it.
  Future<String?> embeddingProfile() async {
    final settings = await ref.read(aiCloudSettingsProvider.future);
    if (settings == null || !settings.supports(AiCapability.embeddings)) {
      return null;
    }
    return '${settings.presetId}:${settings.model(AiCapability.embeddings)}';
  }

  Future<T> _run<T>(
    AiCloudSettings settings,
    String model,
    double Function(AiPrice price) estimate,
    Future<AiResult<T>> Function() call,
  ) async {
    final price = settings.priceFor(model);
    await ref
        .read(aiSpendLedgerProvider)
        .check(settings.monthlyLimitUsd, estimate(price));
    try {
      final result = await call();
      await ref.read(aiSpendLedgerProvider).record(result.usage, price);
      return result.value;
    } on AiProviderFailure catch (failure) {
      if (failure.kind == AiProviderFailureKind.badToken && ref.mounted) {
        ref.read(aiKeyStatusProvider.notifier).rejected();
      }
      rethrow;
    }
  }

  static int _tokens(String text) => (utf8.encode(text).length / 3).ceil();

  Future<String> chat({
    required String system,
    required String user,
    required int outputTokens,
    double temperature = 0,
    double topP = 1,
    List<AiImageInput> images = const [],
    Future<void>? abort,
    Duration? timeout,
  }) async {
    final ready = await _ready(
      images.isEmpty ? AiCapability.chat : AiCapability.vision,
    );
    final request = AiChatRequest(
      model: ready.model,
      system: system,
      user: user,
      outputTokens: outputTokens,
      temperature: temperature,
      topP: topP,
      images: images,
      timeout: timeout,
    );
    final text = await _run(
      ready.settings,
      ready.model,
      (price) => AiUsage(
        inputTokens: _tokens(system) + _tokens(user) + images.length * 1600,
        outputTokens: outputTokens,
      ).cost(price),
      () => ref
          .read(aiCloudClientProvider)
          .chat(ready.settings, request, abort: abort),
    );
    return stripSurroundingCodeFence(text);
  }

  /// One conversation turn with tools. The estimate counts every earlier
  /// exchange, so long conversations stop before the limit, not after.
  Future<AiConverseReply> converse({
    required String system,
    required List<AiExchange> history,
    required String user,
    required List<AiToolSpec> tools,
    required int outputTokens,
    double temperature = .3,
    Future<void>? abort,
    Duration? timeout,
  }) async {
    final ready = await _ready(AiCapability.chat);
    final request = AiConverseRequest(
      model: ready.model,
      system: system,
      history: history,
      user: user,
      tools: tools,
      outputTokens: outputTokens,
      temperature: temperature,
      timeout: timeout,
    );
    final sent = StringBuffer(system)..write(user);
    for (final tool in tools) {
      sent
        ..write(tool.description)
        ..write(jsonEncode(tool.parameters));
    }
    for (final exchange in history) {
      sent
        ..write(exchange.user)
        ..write(exchange.reply);
      for (final call in exchange.calls) {
        sent.write(jsonEncode(call.arguments));
      }
      for (final result in exchange.results) {
        sent.write(result.content);
      }
    }
    return _run(
      ready.settings,
      ready.model,
      (price) => AiUsage(
        inputTokens: _tokens(sent.toString()),
        outputTokens: outputTokens,
      ).cost(price),
      () => ref
          .read(aiCloudClientProvider)
          .converse(ready.settings, request, abort: abort),
    );
  }

  Future<List<List<double>>> embed(
    List<String> inputs, {
    Future<void>? abort,
  }) async {
    final ready = await _ready(AiCapability.embeddings);
    return _run(
      ready.settings,
      ready.model,
      (price) => AiUsage(
        inputTokens: inputs.fold(0, (sum, text) => sum + _tokens(text)),
      ).cost(price),
      () => ref
          .read(aiCloudClientProvider)
          .embed(ready.settings, ready.model, inputs, abort: abort),
    );
  }

  Future<String> transcribe(
    Uint8List wav, {
    required double seconds,
    Future<void>? abort,
  }) async {
    final ready = await _ready(AiCapability.transcription);
    return _run(
      ready.settings,
      ready.model,
      (price) => AiUsage(seconds: seconds).cost(price),
      () => ref
          .read(aiCloudClientProvider)
          .transcribe(
            ready.settings,
            ready.model,
            wav,
            seconds: seconds,
            abort: abort,
          ),
    );
  }

  Future<Uint8List> generateImage(
    String prompt, {
    String size = '1024x1536',
    Future<void>? abort,
  }) async {
    final ready = await _ready(AiCapability.image);
    return _run(
      ready.settings,
      ready.model,
      (price) => const AiUsage(images: 1).cost(price),
      () => ref
          .read(aiCloudClientProvider)
          .generateImage(
            ready.settings,
            ready.model,
            prompt,
            size: size,
            abort: abort,
          ),
    );
  }

  Future<List<String>> listModels(
    AiCloudSettings settings, {
    Future<void>? abort,
  }) async {
    try {
      return await ref
          .read(aiCloudClientProvider)
          .listModels(settings, abort: abort);
    } on AiProviderFailure catch (failure) {
      if (failure.kind == AiProviderFailureKind.badToken && ref.mounted) {
        ref.read(aiKeyStatusProvider.notifier).rejected();
      }
      rethrow;
    }
  }

  /// Starting point for a new provider of this kind.
  static AiCloudSettings starter(String presetId) => AiCloudSettings.fromPreset(
    aiProviderPreset(presetId) ?? customAiProviderPreset,
  );
}
