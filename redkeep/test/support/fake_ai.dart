import 'dart:async';

import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/recall/data/cloud_embedder.dart';
import 'package:redkeep/features/recall/domain/recall.dart';

class MemoryVectors implements RecallVectors {
  final rows = <String, Map<String, dynamic>>{};
  String? profile;
  int resets = 0;
  bool failReset = false;
  int puts = 0;
  int? failPutAt;
  @override
  Future<bool> open(RecallProfile profile) async {
    final fresh = this.profile != profile.id;
    if (fresh) rows.clear();
    this.profile = profile.id;
    return fresh;
  }

  @override
  Future<void> put(
    String id,
    List<double> vector,
    String content,
    Map<String, dynamic> metadata,
  ) async {
    puts++;
    if (puts == failPutAt) {
      throw StateError('Synthetic interrupted vector write');
    }
    rows[id] = {...metadata, 'content': content};
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    for (final id in ids) {
      rows.remove(id);
    }
  }

  @override
  Future<List<VectorHit>> nearest(
    List<double> query,
    String kind, {
    int limit = 80,
  }) async => [
    for (final e in rows.entries)
      if (e.value['kind'] == kind) VectorHit(e.key, .9, e.value),
  ].take(limit).toList();
  @override
  Future<void> reset() async {
    resets++;
    if (failReset) throw StateError('Synthetic unavailable cache');
    rows.clear();
    profile = null;
  }

  @override
  Future<void> close() async {}
}

/// Offline embedder: every text becomes the same small vector.
class FakeEmbedder implements RecallEmbedder {
  FakeEmbedder({this.key = 'openai:test-embed'});

  /// Null when the provider has no embedding model.
  String? key;
  final batches = <List<String>>[];
  Completer<void>? gate;
  AiProviderFailure? failure;

  /// Requests other than the one-word dimension check.
  List<List<String>> get documentBatches => [
    for (final batch in batches)
      if (!(batch.length == 1 && batch.single == 'dimension check')) batch,
  ];

  @override
  Future<String?> profileKey() async => key;

  @override
  Future<List<List<double>>> embed(
    List<String> inputs, {
    Future<void>? abort,
  }) async {
    batches.add(inputs);
    final probe = inputs.length == 1 && inputs.single == 'dimension check';
    if (!probe) await gate?.future;
    if (failure != null) throw failure!;
    return [
      for (final _ in inputs) [1.0, 0, 0, 0],
    ];
  }
}
