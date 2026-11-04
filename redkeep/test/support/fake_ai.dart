import 'dart:async';
import 'dart:convert';

import 'package:redkeep/features/ai/data/ai_job_store.dart';
import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/companion/data/companion_protocol.dart';
import 'package:redkeep/features/recall/domain/recall.dart';
import 'package:redkeep/features/recall/data/companion_embedder.dart';

class MemoryAiTasks implements ProtectedAiTasks {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw StateError('locked');
    return value;
  }

  @override
  Future<void> write(String? value) async {
    if (fail) throw StateError('locked');
    this.value = value;
  }
}

class TestConnection extends CompanionController {
  TestConnection([
    this.initial = const CompanionState(phase: CompanionPhase.idle),
  ]);
  final CompanionState initial;
  @override
  CompanionState build() => initial;
  void set(CompanionState value) => state = value;
}

TrustedComputer syntheticComputer({String id = 'computer-1'}) =>
    TrustedComputer(
      id: id,
      name: 'Synthetic computer',
      pin: 'a' * 64,
      endpoint: Uri.parse('https://127.0.0.1:47921'),
      seed: base64Encode(List.filled(32, 1)),
      publicKey: base64Encode(List.filled(32, 2)),
      deviceId: 'b' * 32,
    );
CompanionState readyComputer({
  String id = 'computer-1',
  String writingStatus = 'ready',
}) => CompanionState(
  phase: CompanionPhase.connected,
  computers: [syntheticComputer(id: id)],
  selectedId: id,
  status: {
    'v': 1,
    'recovery': 1,
    'capabilities': [
      {
        'id': 'text',
        'implemented': true,
        'status': writingStatus,
        'reason': 'Synthetic writing model',
        'diaryContract': 1,
        'questionContract': 1,
        'operations': ['suggest-diary-day', 'ask-diary-question'],
      },
      {
        'id': 'embedding',
        'implemented': true,
        'status': 'ready',
        'reason': 'Synthetic embedder',
        'model': RecallProfile.models.first.model,
        'dimensions': 1024,
        'operations': ['embed'],
      },
    ],
  },
);

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

class FakeEmbedder extends CompanionEmbedder {
  FakeEmbedder()
    : super(
        transport: () => throw StateError('No network'),
        id: () => 'synthetic',
      );
  final batches = <List<EmbedText>>[];
  int acknowledgements = 0;
  Completer<void>? gate;
  @override
  Future<EmbeddingBatch> embed(
    TrustedComputer computer,
    RecallProfile profile,
    List<EmbedText> items, {
    required bool Function() active,
  }) async {
    batches.add(items);
    await gate?.future;
    return EmbeddingBatch(
      {
        for (final item in items) item.id: [1, ...List.filled(1023, 0.0)],
      },
      () async {
        acknowledgements++;
      },
    );
  }
}
