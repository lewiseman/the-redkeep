import 'dart:async';
import 'dart:convert';

import 'package:redkeep/features/ai/data/ai_provider_store.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';

const testAiProvider = AiProviderConnection(
  id: 'provider-test',
  presetId: 'openai',
  name: 'Test AI',
  format: AiProviderFormat.openAiCompatible,
  baseUrl: 'https://ai.example/v1',
  token: 'secret-token',
);

class MemoryAiProviders implements ProtectedAiProviders {
  MemoryAiProviders({List<AiProviderConnection> saved = const []})
    : value = saved.isEmpty
          ? null
          : jsonEncode([for (final p in saved) p.toJson()]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

class FakeAiProviderClient implements AiProviderClient {
  FakeAiProviderClient([this.reply = '']);
  String reply;
  AiProviderFailure? failure;
  Completer<void>? gate;
  bool aborted = false;
  List<String> models = const ['test-model'];
  final requests = <AiCompletionRequest>[];

  @override
  Future<String> complete(
    AiProviderConnection connection,
    AiCompletionRequest request, {
    Future<void>? abort,
  }) async {
    requests.add(request);
    final gate = this.gate;
    if (gate != null) {
      await Future.any([gate.future, ?abort]);
      if (!gate.isCompleted) {
        aborted = true;
        throw const AiProviderFailure(AiProviderFailureKind.cancelled);
      }
    }
    if (failure != null) throw failure!;
    return reply;
  }

  @override
  Future<List<String>> listModels(
    AiProviderConnection connection, {
    Future<void>? abort,
  }) async {
    if (failure != null) throw failure!;
    return models;
  }
}
