import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../domain/local_inference.dart';

/// Explicit opt-in only. Never called by main, bootstrap, or an app provider.
/// The package's process registry is contained here; model/session ownership
/// stays with the adapter. No active model or app writing database is used.
Future<LocalModel> openFlutterEdgeModel(
  String path,
  InferenceSettings settings,
) async {
  try {
    await edge.FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine(backendFallback: false)],
    );
    final installation = await edge.FlutterEdgeAi.installModel(
      modelType: edge.ModelType.qwen3,
      fileType: edge.ModelFileType.litertlm,
    ).fromFile(path).install(activate: false);
    final model = await edge.FlutterEdgeAi.openModel(
      installation.spec,
      maxTokens: settings.contextTokens,
      preferredBackend: switch (settings.backend) {
        InferenceBackend.cpu => edge.PreferredBackend.cpu,
        InferenceBackend.gpu => edge.PreferredBackend.gpu,
      },
    );
    return _FlutterEdgeModel(model, settings);
  } catch (_) {
    throw const InferenceException(InferenceFailure.load);
  }
}

class _FlutterEdgeModel implements LocalModel {
  _FlutterEdgeModel(this._model, this._settings);
  final edge.InferenceModel _model;
  final InferenceSettings _settings;

  @override
  InferenceBackend get backend => switch (_model.activeBackend) {
    edge.PreferredBackend.cpu => InferenceBackend.cpu,
    edge.PreferredBackend.gpu => InferenceBackend.gpu,
    _ => throw const InferenceException(InferenceFailure.load),
  };

  @override
  Future<LocalSession> createSession() async => _FlutterEdgeSession(
    await _model.createSession(
      temperature: _settings.temperature,
      randomSeed: _settings.seed,
      topK: _settings.topK,
      topP: _settings.topP,
      enableThinking: false,
      systemInstruction: 'Follow the instruction. Answer briefly.',
      maxOutputTokens: _settings.outputTokens,
    ),
  );

  @override
  Future<void> close() => _model.close();
}

class _FlutterEdgeSession implements LocalSession {
  _FlutterEdgeSession(this._session);
  final edge.InferenceModelSession _session;

  @override
  Future<void> addPrompt(String text) =>
      _session.addQueryChunk(edge.Message(text: text, isUser: true));
  @override
  Stream<String> stream() => _session.getResponseAsync();
  @override
  Future<void> stop() => _session.stopGeneration();
  @override
  Future<void> close() => _session.close();
}
