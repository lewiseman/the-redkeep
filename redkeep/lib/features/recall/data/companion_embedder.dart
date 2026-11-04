import 'dart:async';
import 'dart:convert';

import '../../companion/data/companion_protocol.dart';
import '../domain/recall.dart';

class EmbedText {
  const EmbedText(this.id, this.text, {this.query = false});
  final String id, text;
  final bool query;
}

class EmbeddingBatch {
  EmbeddingBatch(this.vectors, this._finish);
  final Map<String, List<double>> vectors;
  final Future<void> Function() _finish;
  Future<void> finish() => _finish();
}

class CompanionEmbedder {
  CompanionEmbedder({
    required this.transport,
    required this.id,
    this.poll = const Duration(milliseconds: 180),
    this.timeout = const Duration(seconds: 60),
  });
  final CompanionTransport Function() transport;
  final String Function() id;
  final Duration poll, timeout;
  Future<EmbeddingBatch> embed(
    TrustedComputer computer,
    RecallProfile profile,
    List<EmbedText> items, {
    required bool Function() active,
  }) async {
    final prompt = jsonEncode({
      'model': profile.model,
      'items': [
        for (final i in items)
          {'id': i.id, 'kind': i.query ? 'query' : 'document', 'text': i.text},
      ],
    });
    if (items.isEmpty ||
        items.length > 8 ||
        utf8.encode(prompt).length > 24000 ||
        items.any(
          (i) => i.text.trim().isEmpty || utf8.encode(i.text).length > 4000,
        )) {
      throw const FormatException('Embedding batch exceeds companion limits');
    }
    final connection = transport();
    final client = CompanionClient(connection);
    final jobId = id();
    Future<void> finish() async {
      try {
        await client.authenticated(computer, 'POST', '/v1/jobs/$jobId/ack');
      } catch (_) {
        /* Results expire within an hour if the receipt cannot arrive. */
      } finally {
        connection.close();
      }
    }

    try {
      if (!active()) {
        throw const CompanionFailure('CANCELLED', 'Indexing paused.');
      }
      var job = await client.authenticated(
        computer,
        'POST',
        '/v1/jobs',
        body: {
          'id': jobId,
          'operation': 'embed',
          'prompt': prompt,
          'expires': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        },
      );
      final deadline = DateTime.now().add(timeout);
      while (['queued', 'running'].contains(job['state'])) {
        if (!active() || DateTime.now().isAfter(deadline)) {
          throw const CompanionFailure(
            'CANCELLED',
            'Embedding stopped. Retry when the computer is ready.',
          );
        }
        await Future<void>.delayed(poll);
        if (!active()) {
          throw const CompanionFailure('CANCELLED', 'Indexing paused.');
        }
        job = await client.authenticated(computer, 'GET', '/v1/jobs/$jobId');
      }
      if (!active()) {
        throw const CompanionFailure('CANCELLED', 'Indexing paused.');
      }
      if (job['id'] != jobId ||
          job['operation'] != 'embed' ||
          job['device'] != computer.deviceId ||
          job['state'] != 'completed') {
        throw const FormatException(
          'The computer could not produce this embedding batch',
        );
      }
      final output = jsonDecode(job['text'] as String) as Map;
      if (output['model'] != profile.model ||
          output['dimensions'] != profile.dimensions ||
          output['vectors'] is! List) {
        throw const FormatException('The embedding model changed');
      }
      final vectors = <String, List<double>>{};
      for (final value in output['vectors'] as List) {
        final key = value['id'] as String;
        if (vectors.containsKey(key)) {
          throw const FormatException('Duplicate embedding');
        }
        vectors[key] = decodeRecallVector(
          value['vector'] as String,
          profile.dimensions,
        );
      }
      if (vectors.length != items.length ||
          !items.every((i) => vectors.containsKey(i.id))) {
        throw const FormatException('Missing embedding');
      }
      return EmbeddingBatch(vectors, finish);
    } catch (_) {
      try {
        await client.authenticated(
          computer,
          'POST',
          '/v1/jobs/$jobId/cancel',
          body: {'operation': 'embed'},
        );
      } catch (_) {}
      await finish();
      rethrow;
    }
  }
}
