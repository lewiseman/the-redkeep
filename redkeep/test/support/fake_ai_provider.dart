import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:redkeep/features/ai/data/ai_provider_store.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

/// A configured provider with every capability and no spending limit.
const testAiSettings = AiCloudSettings(
  presetId: 'openai',
  baseUrl: 'https://ai.example/v1',
  token: 'secret-token',
  models: {
    AiCapability.chat: 'test-model',
    AiCapability.embeddings: 'test-embed',
    AiCapability.transcription: 'test-transcribe',
    AiCapability.image: 'test-image',
  },
  monthlyLimitUsd: 0,
);

class MemoryAiProviders implements ProtectedAiProviders {
  MemoryAiProviders({AiCloudSettings? saved})
    : value = saved == null ? null : jsonEncode(saved.toJson());
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

/// Offline stand-in for the cloud provider. Records every request.
class FakeAiProviderClient implements AiCloudClient {
  FakeAiProviderClient([this.reply = '']);
  String reply;

  /// Answers for the next chats, in order, before [reply].
  final replies = <String>[];
  AiProviderFailure? failure;
  Completer<void>? gate;
  bool aborted = false;
  List<String> models = const ['test-model'];
  final requests = <AiChatRequest>[];
  final embedded = <List<String>>[];
  final transcribed = <Uint8List>[];
  final images = <String>[];
  String transcript = 'Spoken words';
  Uint8List? image;
  AiUsage usage = const AiUsage(inputTokens: 10, outputTokens: 5);

  Future<void> _wait(Future<void>? abort) async {
    final gate = this.gate;
    if (gate != null) {
      await Future.any([gate.future, ?abort]);
      if (!gate.isCompleted) {
        aborted = true;
        throw const AiProviderFailure(AiProviderFailureKind.cancelled);
      }
    }
    if (failure != null) throw failure!;
  }

  @override
  Future<AiResult<String>> chat(
    AiCloudSettings settings,
    AiChatRequest request, {
    Future<void>? abort,
  }) async {
    requests.add(request);
    await _wait(abort);
    return AiResult(replies.isEmpty ? reply : replies.removeAt(0), usage);
  }

  @override
  Future<AiResult<List<List<double>>>> embed(
    AiCloudSettings settings,
    String model,
    List<String> inputs, {
    Future<void>? abort,
  }) async {
    embedded.add(inputs);
    await _wait(abort);
    return AiResult([
      for (final _ in inputs) [1.0, 0, 0, 0],
    ], AiUsage(inputTokens: inputs.length));
  }

  @override
  Future<AiResult<String>> transcribe(
    AiCloudSettings settings,
    String model,
    Uint8List audio, {
    String filename = 'speech.wav',
    String mime = 'audio/wav',
    double seconds = 0,
    Future<void>? abort,
  }) async {
    transcribed.add(audio);
    await _wait(abort);
    return AiResult(transcript, AiUsage(seconds: seconds));
  }

  @override
  Future<AiResult<Uint8List>> generateImage(
    AiCloudSettings settings,
    String model,
    String prompt, {
    String size = '1024x1536',
    Future<void>? abort,
  }) async {
    images.add(prompt);
    await _wait(abort);
    return AiResult(image ?? Uint8List(0), const AiUsage(images: 1));
  }

  @override
  Future<List<String>> listModels(
    AiCloudSettings settings, {
    Future<void>? abort,
  }) async {
    await _wait(abort);
    return models;
  }
}
