import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/storage_providers.dart';
import '../../../core/storage/app_database.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/data/recall_schema.dart';
import '../../ai/domain/ai_provider.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../data/cloud_embedder.dart';
import '../data/recall_sources.dart';
import '../data/sqlite_recall_vectors.dart';
import '../domain/recall.dart';

final recallVectorsProvider = FutureProvider<RecallVectors>((ref) async {
  final cache = await getApplicationCacheDirectory();
  final vectors = SqliteRecallVectors(
    Directory('${cache.path}/redkeep-recall-v1'),
  );
  ref.onDispose(() => unawaited(vectors.close()));
  return vectors;
});
final recallSourcesProvider = Provider<RecallSources>(
  (ref) => RecallSources(ref.watch(appDatabaseProvider)),
);
final recallEmbedderProvider = Provider<RecallEmbedder>(
  CloudRecallEmbedder.new,
);
final recallControllerProvider =
    NotifierProvider<RecallController, RecallState>(RecallController.new);

/// Writing is indexed this long after the last change, or soon after the
/// person leaves an editor, so a note written in bursts is embedded once.
const recallQuietWindow = Duration(seconds: 45);
const recallFlushDelay = Duration(milliseconds: 1500);
final recallTimingProvider = Provider<({Duration quiet, Duration flush})>(
  (ref) => (quiet: recallQuietWindow, flush: recallFlushDelay),
);

class RecallState {
  const RecallState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.counts = const {},
    this.message,
    this.revision = 0,
  });
  final bool running;
  final int done, total, revision;
  final Map<String, int> counts;
  final String? message;
}

class RecallSearch {
  const RecallSearch(this.sources, {this.semantic = false, this.message});
  final List<RecallSource> sources;
  final bool semantic;
  final String? message;
}

/// One source waiting for vectors in this run.
class _Pending {
  _Pending(this.row, this.source, this.chunks, this.ids, this.oldIds);
  final RecallQueueRow row;
  final RecallSource source;
  final List<String> chunks, ids, oldIds;
  final vectors = <int, List<double>>{};
  bool stale = false;
}

class RecallController extends Notifier<RecallState> {
  int _epoch = 0;
  late int _dataGeneration;
  bool _foreground = true;
  bool _maintenanceFailed = false;

  /// Bad key or spending limit: wait for the settings or month to change.
  bool _blocked = false;
  bool _flushing = false;

  /// Set when a search finds the index may not match the current model.
  bool _verify = false;
  Future<void>? _run;
  Future<void> _maintenance = Future.value();
  Timer? _timer;
  String? _profile;
  Completer<void>? _abort;
  final _dimensions = <String, int>{};
  final _queries = <String, List<double>>{};
  ({Duration quiet, Duration flush}) get _timing =>
      ref.read(recallTimingProvider);
  bool _alive(int epoch) =>
      ref.mounted &&
      _foreground &&
      epoch == _epoch &&
      !ref.read(appDatabaseProvider).writingBlocked &&
      ref.read(appDatabaseProvider).writingGeneration == _dataGeneration;

  void _stopRequest() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  @override
  RecallState build() {
    ref.watch(writingSessionEpochProvider);
    final db = ref.read(appDatabaseProvider);
    _dataGeneration = db.writingGeneration;
    final subscription = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.notes,
            db.diaryEntries,
            db.flowThoughts,
          ]),
        )
        .listen(
          (_) => schedule(delay: _flushing ? _timing.flush : _timing.quiet),
        );
    ref.listen(aiCloudSettingsProvider, (previous, next) {
      final before = previous?.value, after = next.value;
      String? key(AiCloudSettings? s) => s == null
          ? null
          : '${s.presetId}:${s.baseUrl}:${s.token.hashCode}:${s.model(AiCapability.embeddings)}';
      if (key(before) == key(after) &&
          before?.monthlyLimitUsd == after?.monthlyLimitUsd) {
        return;
      }
      _epoch++;
      _stopRequest();
      _blocked = false;
      _queries.clear();
      schedule(delay: _timing.flush);
    });
    ref.listen(aiPreferencesProvider, (previous, next) {
      if (!next.hasValue) return;
      final old = previous?.value?.collections;
      final enabled = next.value!.collections;
      if (old != null && old.any((k) => !enabled.contains(k))) {
        _epoch++;
        _queries.clear();
        unawaited(rebuild());
      }
      if (next.value!.paused) {
        _epoch++;
        _stopRequest();
      }
      schedule(delay: _timing.flush);
    });
    ref.onDispose(() {
      _epoch++;
      _stopRequest();
      _timer?.cancel();
      unawaited(subscription.cancel());
    });
    return const RecallState();
  }

  void schedule({Duration? delay}) {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer(delay ?? _timing.quiet, () => unawaited(run()));
  }

  /// Called when the person leaves an editor: index what they wrote soon,
  /// instead of waiting out the quiet window.
  void flushSoon() {
    _flushing = true;
    schedule(delay: _timing.flush);
  }

  void foreground(bool value) {
    _foreground = value;
    if (!value) {
      _epoch++;
      _stopRequest();
      _timer?.cancel();
    } else {
      // A new month or a raised limit may have unblocked indexing.
      _blocked = false;
      schedule(delay: _timing.flush);
    }
  }

  Future<void> setEnabled(String kind, bool value) async {
    _epoch++;
    await ref.read(aiPreferencesRepositoryProvider).collection(kind, value);
    schedule(delay: _timing.flush);
  }

  Future<void> pause(bool value) async {
    _epoch++;
    await ref.read(aiPreferencesRepositoryProvider).pause(value);
    schedule(delay: _timing.flush);
  }

  Future<void> rebuild() async {
    _epoch++;
    _stopRequest();
    _blocked = false;
    final running = _run;
    _maintenance = _maintenance
        .then((_) async {
          await running;
          await _rebuild();
          _maintenanceFailed = false;
        })
        .catchError((Object _) {
          _maintenanceFailed = true;
          if (ref.mounted) {
            state = const RecallState(
              message: 'Could not clear the search index. Indexing is stopped; retry rebuilding.',
            );
          }
        });
    await _maintenance;
    if (!_maintenanceFailed) schedule(delay: Duration.zero);
  }

  Future<void> _rebuild() async {
    if (!ref.mounted || ref.read(appDatabaseProvider).writingBlocked) return;
    final vectors = await ref.read(recallVectorsProvider.future);
    await vectors.reset();
    if (!ref.mounted) return;
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      await db.delete(db.recallManifests).go();
      await db.delete(db.recallQueue).go();
      final prefs = await ref.read(aiPreferencesRepositoryProvider).read();
      for (final kind in prefs.collections) {
        await seedRecallQueue(db, kind: kind);
      }
      await ref.read(aiPreferencesRepositoryProvider).cleanupComplete();
    });
    _profile = null;
    _queries.clear();
    if (ref.mounted) state = RecallState(revision: state.revision + 1);
  }

  Future<void> run() async {
    final running = _run;
    if (running != null) {
      await running;
      if (ref.mounted) await run();
      return;
    }
    final pending = _runOnce();
    _run = pending;
    try {
      await pending;
    } finally {
      _run = null;
    }
  }

  /// The profile for [key], learning its vector size with one tiny request
  /// the first time a model is used in this session.
  Future<RecallProfile> _profileFor(String key, Future<void> abort) async {
    final known = _dimensions[key];
    if (known != null) return RecallProfile(key, known);
    final probe = await ref.read(recallEmbedderProvider).embed(const [
      'dimension check',
    ], abort: abort);
    return RecallProfile(key, _dimensions[key] = probe.single.length);
  }

  String _failureMessage(Object error) {
    if (error is! AiProviderFailure) {
      return 'Indexing paused after a storage problem. It retries after your next change.';
    }
    if (const {
      AiProviderFailureKind.badToken,
      AiProviderFailureKind.spendLimit,
      AiProviderFailureKind.notConfigured,
      AiProviderFailureKind.unsupported,
    }.contains(error.kind)) {
      _blocked = true;
    }
    return switch (error.kind) {
      AiProviderFailureKind.offline =>
        'Indexing waits for a connection. Search uses keywords meanwhile.',
      AiProviderFailureKind.rateLimited => 'The provider is rate limiting. Indexing retries after your next change.',
      _ => 'Indexing stopped: ${error.message}',
    };
  }

  Future<void> _runOnce() async {
    _flushing = false;
    await _maintenance;
    if (!ref.mounted || !_foreground || _maintenanceFailed) return;
    try {
      if (await ref.read(aiPreferencesRepositoryProvider).cleanupRequired()) {
        await _rebuild();
      }
    } catch (_) {
      _maintenanceFailed = true;
      if (ref.mounted) {
        state = const RecallState(
          message: 'Could not clear the search index. Indexing is stopped; retry rebuilding.',
        );
      }
      return;
    }
    if (!ref.mounted || !_foreground) return;
    final prefs = ref.read(aiPreferencesProvider).value;
    if (prefs == null ||
        prefs.paused ||
        prefs.collections.isEmpty ||
        _blocked ||
        ref.read(aiKeyStatusProvider) ||
        ref.read(appDatabaseProvider).writingBlocked) {
      return;
    }
    final epoch = ++_epoch;
    final abort = _abort = Completer<void>();
    final db = ref.read(appDatabaseProvider);
    final sources = ref.read(recallSourcesProvider);
    final embedder = ref.read(recallEmbedderProvider);
    var done = 0, total = 0;
    try {
      final key = await embedder.profileKey();
      if (!_alive(epoch)) return;
      if (key == null) {
        state = RecallState(
          counts: state.counts,
          revision: state.revision,
          message: 'Your AI provider has no embedding model, so search uses keywords.',
        );
        return;
      }
      final queue = (await db.select(db.recallQueue).get())
          .where((row) => prefs.collections.contains(row.kind))
          .toList();
      if (queue.isEmpty && !_verify) return;
      final profile = await _profileFor(key, abort.future);
      final vectors = await ref.read(recallVectorsProvider.future);
      if (!_alive(epoch)) return;
      final recreated = await vectors.open(profile);
      if (!_alive(epoch)) return;
      if (recreated || _profile != profile.id) {
        await db.transaction(() async {
          if (recreated) {
            await (db.delete(
              db.recallManifests,
            )..where((r) => r.profile.equals(profile.id))).go();
          }
          for (final kind in prefs.collections) {
            await seedRecallQueue(db, kind: kind);
          }
        });
        _profile = profile.id;
        _verify = false;
        queue
          ..clear()
          ..addAll(
            (await db.select(db.recallQueue).get()).where(
              (row) => prefs.collections.contains(row.kind),
            ),
          );
      }
      total = queue.length;
      state = RecallState(
        running: true,
        total: total,
        counts: state.counts,
        revision: state.revision,
      );

      Future<void> dequeue(RecallQueueRow row) async {
        await (db.delete(db.recallQueue)..where(
              (r) =>
                  r.kind.equals(row.kind) &
                  r.sourceId.equals(row.sourceId) &
                  r.generation.equals(row.generation),
            ))
            .go();
        done++;
        if (_alive(epoch)) {
          state = RecallState(
            running: true,
            done: done,
            total: total,
            counts: state.counts,
            revision: state.revision,
          );
        }
      }

      // Plan: drop removed writing, skip unchanged writing, and record every
      // intended chunk ID before any vector write.
      final pending = <_Pending>[];
      for (final row in queue) {
        if (!_alive(epoch)) return;
        final source = await sources.read(row.kind, row.sourceId);
        final previous =
            await (db.select(db.recallManifests)..where(
                  (m) =>
                      m.profile.equals(profile.id) &
                      m.kind.equals(row.kind) &
                      m.sourceId.equals(row.sourceId),
                ))
                .getSingleOrNull();
        final oldIds = previous == null
            ? <String>[]
            : (jsonDecode(previous.chunks) as List).cast<String>();
        if (source == null || source.text.trim().isEmpty) {
          await vectors.remove(oldIds);
          if (!_alive(epoch)) return;
          await (db.delete(db.recallManifests)..where(
                (m) =>
                    m.profile.equals(profile.id) &
                    m.kind.equals(row.kind) &
                    m.sourceId.equals(row.sourceId),
              ))
              .go();
          await dequeue(row);
        } else if (previous?.complete == true &&
            previous?.hash == source.hash &&
            previous?.revision == source.revision) {
          await dequeue(row);
        } else {
          final chunks = recallChunks(source.text);
          final ids = [
            for (var i = 0; i < chunks.length; i++)
              '${source.key}:${source.hash}:$i',
          ];
          await db
              .into(db.recallManifests)
              .insertOnConflictUpdate(
                RecallManifestsCompanion.insert(
                  profile: profile.id,
                  kind: source.kind,
                  sourceId: source.id,
                  hash: source.hash,
                  revision: source.revision,
                  chunks: jsonEncode({...oldIds, ...ids}.toList()),
                ),
              );
          pending.add(_Pending(row, source, chunks, ids, oldIds));
        }
      }

      Future<void> finish(_Pending item) async {
        if (item.stale || !await sources.current(item.source)) return;
        final source = item.source;
        for (var i = 0; i < item.chunks.length; i++) {
          if (!_alive(epoch)) return;
          await vectors.put(item.ids[i], item.vectors[i]!, item.chunks[i], {
            'kind': source.kind,
            'sourceId': source.id,
            'revision': source.revision,
            'hash': source.hash,
            'date': source.date,
            'chunk': i,
          });
        }
        if (!_alive(epoch)) return;
        await vectors.remove(item.oldIds.where((id) => !item.ids.contains(id)));
        if (!_alive(epoch)) return;
        await db
            .into(db.recallManifests)
            .insertOnConflictUpdate(
              RecallManifestsCompanion.insert(
                profile: profile.id,
                kind: source.kind,
                sourceId: source.id,
                hash: source.hash,
                revision: source.revision,
                chunks: jsonEncode(item.ids),
                complete: const Value(true),
              ),
            );
        await dequeue(item.row);
      }

      // Embed: chunks from many sources share each request.
      final work = [
        for (final item in pending)
          for (var i = 0; i < item.chunks.length; i++) (item, i),
      ];
      for (var start = 0; start < work.length;) {
        if (!_alive(epoch)) return;
        var end = start, bytes = 0;
        while (end < work.length && end - start < recallBatchInputs) {
          final (item, i) = work[end];
          final size = utf8.encode(item.chunks[i]).length;
          if (end > start && bytes + size > recallBatchBytes) break;
          bytes += size;
          end++;
        }
        final batch = work.sublist(start, end);
        final embedded = await embedder.embed([
          for (final (item, i) in batch) item.chunks[i],
        ], abort: abort.future);
        if (!_alive(epoch)) return;
        for (final (n, (item, i)) in batch.indexed) {
          if (embedded[n].length != profile.dimensions) {
            throw const AiProviderFailure(
              AiProviderFailureKind.invalidResponse,
            );
          }
          item.vectors[i] = embedded[n];
        }
        start = end;
        // Save each source as soon as all of its chunks have vectors.
        for (final item in {for (final (item, _) in batch) item}) {
          if (item.vectors.length == item.chunks.length) {
            await finish(item);
            if (!_alive(epoch)) return;
          }
        }
      }
      final manifest = await (db.select(
        db.recallManifests,
      )..where((m) => m.profile.equals(profile.id))).get();
      if (_alive(epoch)) {
        state = RecallState(
          done: done,
          total: total,
          counts: {
            for (final kind in prefs.collections)
              kind: manifest.where((m) => m.kind == kind && m.complete).length,
          },
          revision: state.revision + 1,
        );
      }
    } catch (error) {
      if (_alive(epoch)) {
        state = RecallState(
          done: done,
          total: total,
          counts: state.counts,
          revision: state.revision,
          message: _failureMessage(error),
        );
      }
    } finally {
      if (identical(_abort, abort)) _abort = null;
      if (ref.mounted && state.running) {
        state = RecallState(
          done: done,
          total: total,
          counts: state.counts,
          revision: state.revision,
          message: state.message,
        );
      }
    }
  }

  /// Embeds [query] once (cached) and returns matching sources. Call only
  /// for searches the person submitted.
  Future<RecallSearch> search(
    String query,
    String kind, {
    bool Function()? active,
  }) async {
    await _maintenance;
    final prefs = await ref.read(aiPreferencesRepositoryProvider).read();
    if (!_foreground ||
        _maintenanceFailed ||
        ref.read(appDatabaseProvider).writingBlocked ||
        !prefs.collections.contains(kind)) {
      return const RecallSearch(
        [],
        message: 'Keyword results · search by meaning is off for this kind.',
      );
    }
    if (utf8.encode(query).length > 4000) {
      return const RecallSearch(
        [],
        message: 'Keyword results · use a shorter query for search by meaning.',
      );
    }
    final embedder = ref.read(recallEmbedderProvider);
    final key = await embedder.profileKey();
    if (key == null) {
      return const RecallSearch(
        [],
        message: 'Keyword results · your AI provider has no embedding model.',
      );
    }
    final epoch = _epoch;
    bool alive() => ref.mounted && (active?.call() ?? true);
    final sources = ref.read(recallSourcesProvider);
    try {
      final cacheKey = '$key\n$query';
      var vector = _queries[cacheKey];
      if (vector == null) {
        vector = (await embedder.embed([query])).single;
        if (!alive()) return const RecallSearch([]);
        if (_queries.length >= 16) _queries.remove(_queries.keys.first);
        _queries[cacheKey] = vector;
      }
      _dimensions[key] ??= vector.length;
      final profile = RecallProfile(key, vector.length);
      final vectors = await ref.read(recallVectorsProvider.future);
      if (!alive()) return const RecallSearch([]);
      final recreated = await vectors.open(profile);
      if ((recreated || _profile != profile.id) && epoch == _epoch) {
        // Check the index against this model once, re-embedding only what
        // changed since it was last used.
        if (recreated) _profile = null;
        _verify = true;
        schedule(delay: _timing.flush);
      }
      if (recreated) {
        return const RecallSearch(
          [],
          message: 'Keyword results · building the meaning index.',
        );
      }
      final hits = await vectors.nearest(vector, kind);
      final found = <RecallSource>[];
      final seen = <String>{};
      for (final hit in hits) {
        if (!alive()) return const RecallSearch([]);
        final id = hit.metadata['sourceId'];
        if (id is! String || seen.contains(id)) continue;
        final source = await sources.read(kind, id);
        if (source == null ||
            source.revision != hit.metadata['revision'] ||
            source.hash != hit.metadata['hash']) {
          continue;
        }
        seen.add(id);
        found.add(source);
      }
      return RecallSearch(
        found,
        semantic: true,
        message: 'Keyword and meaning results',
      );
    } on AiProviderFailure catch (failure) {
      return RecallSearch(
        [],
        message: failure.kind == AiProviderFailureKind.offline
            ? 'Keyword results · you are offline.'
            : 'Keyword results · ${failure.message}',
      );
    } catch (_) {
      return const RecallSearch(
        [],
        message: 'Keyword results · search by meaning is unavailable just now.',
      );
    }
  }

  Future<void> stopForReset() async {
    _foreground = false;
    _epoch++;
    _stopRequest();
    _timer?.cancel();
    _queries.clear();
    await _run;
    await _maintenance;
  }

  void clearQueryCache() {
    _epoch++;
    _queries.clear();
  }
}
