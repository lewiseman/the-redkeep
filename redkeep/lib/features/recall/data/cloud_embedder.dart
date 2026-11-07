import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_cloud.dart';

/// Turns text into vectors with the configured provider's embedding model.
abstract interface class RecallEmbedder {
  /// `provider:model`, or null when the provider has no embeddings.
  Future<String?> profileKey();

  /// One request for every input, in order.
  Future<List<List<double>>> embed(List<String> inputs, {Future<void>? abort});
}

class CloudRecallEmbedder implements RecallEmbedder {
  CloudRecallEmbedder(this.ref);
  final Ref ref;

  @override
  Future<String?> profileKey() => ref.read(aiCloudProvider).embeddingProfile();

  @override
  Future<List<List<double>>> embed(
    List<String> inputs, {
    Future<void>? abort,
  }) => ref.read(aiCloudProvider).embed(inputs, abort: abort);
}

/// Cloud embedding APIs accept many inputs per call; these bounds keep each
/// request well inside common provider limits.
const recallBatchInputs = 96;
const recallBatchBytes = 200 * 1024;
