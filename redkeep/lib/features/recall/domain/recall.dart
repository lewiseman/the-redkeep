import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String recallHash(String text) => sha256.convert(utf8.encode(text)).toString();

/// One embedding model's index. The vector file and manifests follow [id],
/// so changing provider or model starts a fresh index.
class RecallProfile {
  const RecallProfile(this.key, this.dimensions);

  /// `provider:model`.
  final String key;
  final int dimensions;
  String get id => 'redkeep-cloud-v1:$key:dim-$dimensions:chunks-utf8-4000-v1';
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
