import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String recallHash(String text) => sha256.convert(utf8.encode(text)).toString();

class RecallProfile {
  const RecallProfile(this.model, this.artifact, this.quantization);
  final String model, artifact, quantization;
  int get dimensions => 1024;
  String get id =>
      'journal-embed-v1:$artifact:$quantization:dim-$dimensions:llamacpp-last-l2:document-raw-v1:qwen-query-v1:chunks-utf8-4000-v1:filters-v1';
  static const models = [
    RecallProfile(
      'qwen3-embedding-0.6b-q8_0@370f27d7550e0def9b39c1f16d3fbaa13aa67728',
      '06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439',
      'q8_0',
    ),
    RecallProfile(
      'qwen3-embedding-0.6b-f16@370f27d7550e0def9b39c1f16d3fbaa13aa67728',
      '421a27e58d165478cc7acb984a688c2aa41404968b0203e7cd743ece44c54340',
      'f16',
    ),
  ];
  static RecallProfile? fromStatus(Map<String, dynamic>? status) {
    for (final c in (status?['capabilities'] as List? ?? []).whereType<Map>()) {
      if (c['id'] == 'embedding' &&
          c['implemented'] == true &&
          ['ready', 'busy'].contains(c['status']) &&
          c['dimensions'] == 1024 &&
          c['operations'] is List &&
          (c['operations'] as List).contains('embed')) {
        return models.where((m) => m.model == c['model']).firstOrNull;
      }
    }
    return null;
  }
}

class RecallSource {
  RecallSource({
    required this.kind,
    required this.id,
    required this.text,
    required this.title,
    required this.date,
    required this.revision,
  });
  final String kind, id, text, title, date;
  final int revision;
  String get key => '$kind:$id';
  String get hash => recallHash(text);
}

/// All source text is covered, without splitting Unicode scalars. Prefer a
/// paragraph/word boundary in the final quarter of each bounded chunk.
List<String> recallChunks(String text, {int maxBytes = 4000}) {
  if (maxBytes < 4) throw ArgumentError.value(maxBytes);
  final runes = text.runes.toList();
  final out = <String>[];
  var start = 0;
  while (start < runes.length) {
    var end = start, bytes = 0, boundary = -1;
    while (end < runes.length) {
      final rune = runes[end];
      final size = rune <= 0x7f
          ? 1
          : rune <= 0x7ff
          ? 2
          : rune <= 0xffff
          ? 3
          : 4;
      if (bytes + size > maxBytes) break;
      bytes += size;
      end++;
      if (bytes >= maxBytes * .75 && (rune == 10 || rune == 32 || rune == 9)) {
        boundary = end;
      }
    }
    if (end < runes.length && boundary > start) end = boundary;
    final chunk = String.fromCharCodes(runes.sublist(start, end));
    if (chunk.trim().isNotEmpty) out.add(chunk);
    start = end;
  }
  return out;
}

List<double> decodeRecallVector(String encoded, int dimensions) {
  final bytes = base64Decode(encoded);
  if (bytes.length != dimensions * 4) {
    throw const FormatException('Invalid embedding dimensions');
  }
  final data = ByteData.sublistView(bytes);
  final result = List<double>.generate(
    dimensions,
    (i) => data.getFloat32(i * 4, Endian.little),
  );
  if (result.any((v) => !v.isFinite) || !result.any((v) => v != 0)) {
    throw const FormatException('Invalid embedding values');
  }
  return result;
}

class VectorHit {
  const VectorHit(this.id, this.similarity, this.metadata);
  final String id;
  final double similarity;
  final Map<String, dynamic> metadata;
}

abstract interface class RecallVectors {
  /// True when a missing or corrupt derived index was recreated.
  Future<bool> open(RecallProfile profile);
  Future<void> put(
    String id,
    List<double> vector,
    String content,
    Map<String, dynamic> metadata,
  );
  Future<void> remove(Iterable<String> ids);
  Future<List<VectorHit>> nearest(
    List<double> query,
    String kind, {
    int limit = 80,
  });
  Future<void> reset();
  Future<void> close();
}

/// Weighted reciprocal-rank fusion, preserving the old keyword preference.
List<T> fuseRecall<T>(
  List<T> keywords,
  List<T> semantic,
  String Function(T) id,
) {
  final values = <String, T>{};
  final scores = <String, double>{};
  for (final (list, weight) in [(keywords, 1.2), (semantic, 1.0)]) {
    for (final (i, item) in list.indexed) {
      final key = id(item);
      values.putIfAbsent(key, () => item);
      scores[key] = (scores[key] ?? 0) + weight / (60 + i + 1);
    }
  }
  final keys = values.keys.toList()
    ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
  return [for (final key in keys) values[key]!];
}
