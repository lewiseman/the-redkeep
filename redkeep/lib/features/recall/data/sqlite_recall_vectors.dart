import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_edge_ai_rag/flutter_edge_ai_rag.dart';
import 'package:flutter_edge_ai_sqlite/flutter_edge_ai_sqlite.dart';

import '../domain/recall.dart';

/// The vector connection and KNN SQL live on their own isolate. No writing
/// database is opened here. Only this app-owned cache directory can be removed.
class SqliteRecallVectors implements RecallVectors {
  SqliteRecallVectors(this.root, {this.extensionPath});

  /// Host-test seam: production resolves the bundled native extension.
  final String? extensionPath;
  final Directory root;
  ReceivePort? _receive;
  SendPort? _send;
  Isolate? _worker;
  Future<void>? _starting;
  int _next = 0;
  final _pending = <int, Completer<Object?>>{};
  Future<void> _start() => _starting ??= () async {
    final ready = Completer<void>();
    _receive = ReceivePort();
    _receive!.listen((message) {
      if (message is SendPort) {
        _send = message;
        ready.complete();
      } else if (message is Map) {
        final call = _pending.remove(message['id']);
        if (message['error'] == true) {
          call?.completeError(
            StateError(
              'The local search index is unavailable. Keyword search still works.',
            ),
          );
        } else {
          call?.complete(message['value']);
        }
      }
    });
    _worker = await Isolate.spawn(_vectorWorker, (
      _receive!.sendPort,
      root.path,
      extensionPath,
    ));
    await ready.future;
  }();
  Future<Object?> _call(
    String command, [
    Map<String, dynamic> args = const {},
  ]) async {
    await _start();
    final id = _next++;
    final result = Completer<Object?>();
    _pending[id] = result;
    _send!.send({'id': id, 'command': command, ...args});
    return result.future;
  }

  @override
  Future<bool> open(RecallProfile profile) async =>
      await _call('open', {
        'profile': profile.id,
        'dimensions': profile.dimensions,
      }) ==
      true;
  @override
  Future<void> put(
    String id,
    List<double> vector,
    String content,
    Map<String, dynamic> metadata,
  ) async {
    await _call('put', {
      'key': id,
      'vector': vector,
      'content': content,
      'metadata': jsonEncode(metadata),
    });
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    await _call('remove', {'keys': ids.toList()});
  }

  @override
  Future<List<VectorHit>> nearest(
    List<double> query,
    String kind, {
    int limit = 80,
  }) async => [
    for (final value in (await _call('search', {
      'vector': query,
      'kind': kind,
      'limit': limit,
    })) as List)
      VectorHit(
        value['id'] as String,
        value['similarity'] as double,
        Map<String, dynamic>.from(
          jsonDecode(value['metadata'] as String) as Map,
        ),
      ),
  ];
  @override
  Future<void> reset() async {
    await _call('reset');
  }

  @override
  Future<void> close() async {
    if (_starting == null) return;
    await _call('close');
    _worker?.kill();
    _receive?.close();
    _worker = null;
    _receive = null;
    _send = null;
    _starting = null;
  }
}

Future<void> _vectorWorker((SendPort, String, String?) config) async {
  final (reply, path, extensionPath) = config;
  if (extensionPath != null) {
    SqliteVectorStore.debugOverrideDylibPath = extensionPath;
  }
  final root = Directory(path);
  final commands = ReceivePort();
  reply.send(commands.sendPort);
  final rag = FlutterEdgeAiRag(providers: const [SqliteVectorStoreProvider()]);
  RagIndex? index;
  String? current;
  await for (final message in commands) {
    final m = message as Map;
    Object? result;
    try {
      switch (m['command']) {
        case 'open':
          final profile = m['profile'] as String;
          if (profile == current && index != null) {
            result = false;
            break;
          }
          await index?.dispose();
          index = null;
          current = null;
          await root.create(recursive: true);
          final file = File('${root.path}/${recallHash(profile)}.sqlite');
          var recreated = !await file.exists();
          Future<RagIndex> open() => rag.openVectors(
            spec: VectorStoreSpec(
              providerId: SqliteVectorStoreProvider.providerId,
              location: file.path,
              filterSchema: FilterSchema(
                fields: [
                  FilterField(name: 'kind', type: FilterFieldType.string),
                ],
              ),
            ),
            profile: EmbeddingProfile(
              id: profile,
              dimension: m['dimensions'] as int,
            ),
          );
          try {
            index = await open();
          } catch (_) {
            for (final suffix in ['', '-wal', '-shm']) {
              final damaged = File('${file.path}$suffix');
              if (await damaged.exists()) await damaged.delete();
            }
            index = await open();
            recreated = true;
          }
          current = profile;
          result = recreated;
        case 'put':
          await index!.addVector(
            id: m['key'] as String,
            embedding: (m['vector'] as List).cast<double>(),
            content: m['content'] as String,
            metadata: m['metadata'] as String,
          );
          await index.flush();
        case 'remove':
          for (final id in m['keys'] as List) {
            await index!.remove(id: id as String);
          }
        case 'search':
          final hits = await index!.searchVector(
            embedding: (m['vector'] as List).cast<double>(),
            topK: m['limit'] as int,
            threshold: .42,
            filter: Filter(
              must: [FieldEquals(key: 'kind', value: m['kind'] as String)],
            ),
          );
          result = [
            for (final hit in hits)
              {
                'id': hit.id,
                'similarity': hit.similarity,
                'metadata': hit.metadata,
              },
          ];
        case 'reset':
          await index?.dispose();
          index = null;
          current = null;
          if (await root.exists()) await root.delete(recursive: true);
        case 'close':
          await index?.dispose();
          index = null;
          current = null;
        default:
          throw StateError('Unknown index command');
      }
      reply.send({'id': m['id'], 'value': result});
    } catch (_) {
      reply.send({'id': m['id'], 'error': true});
    }
  }
}
