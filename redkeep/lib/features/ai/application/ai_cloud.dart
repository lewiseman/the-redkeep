import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../sync/application/sync_providers.dart' show networkServiceProvider;
import '../data/ai_provider_store.dart';
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

/// Every cloud call goes through here. A missing capability fails before
/// anything is sent.
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

  Future<T> _run<T>(Future<AiResult<T>> Function() call) async {
    try {
      return (await call()).value;
    } on AiProviderFailure catch (failure) {
      if (failure.kind == AiProviderFailureKind.badToken && ref.mounted) {
        ref.read(aiKeyStatusProvider.notifier).rejected();
      }
      rethrow;
    }
  }

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
      () => ref
          .read(aiCloudClientProvider)
          .chat(ready.settings, request, abort: abort),
    );
    return stripSurroundingCodeFence(text);
  }

  /// [chat] as it is written: yields the answer's text piece by piece.
  Stream<String> chatStream({
    required String system,
    required String user,
    required int outputTokens,
    double temperature = 0,
    Future<void>? abort,
    Duration? timeout,
  }) async* {
    final ready = await _ready(AiCapability.chat);
    final request = AiChatRequest(
      model: ready.model,
      system: system,
      user: user,
      outputTokens: outputTokens,
      temperature: temperature,
      timeout: timeout,
    );
    try {
      await for (final piece
          in ref
              .read(aiCloudClientProvider)
              .chatStream(ready.settings, request, abort: abort)) {
        if (piece.text.isNotEmpty) yield piece.text;
      }
    } on AiProviderFailure catch (failure) {
      if (failure.kind == AiProviderFailureKind.badToken && ref.mounted) {
        ref.read(aiKeyStatusProvider.notifier).rejected();
      }
      rethrow;
    }
  }

  /// One conversation turn with tools.
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
    return _run(
      () => ref
          .read(aiCloudClientProvider)
          .converse(ready.settings, request, abort: abort),
    );
  }

  Future<String> transcribe(
    Uint8List wav, {
    required double seconds,
    Future<void>? abort,
  }) async {
    final ready = await _ready(AiCapability.transcription);
    return _run(
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
