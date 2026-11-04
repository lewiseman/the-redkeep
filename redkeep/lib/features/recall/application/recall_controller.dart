import '../../../core/storage/app_database.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/storage_providers.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/data/recall_schema.dart';
import '../../companion/application/companion_controller.dart';
import '../../companion/data/companion_protocol.dart';
import '../../sync/application/sync_providers.dart'
    show writingSessionEpochProvider;
import '../data/companion_embedder.dart';
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
final recallTransportFactoryProvider = Provider<CompanionTransport Function()>(
  (ref) => PinnedCompanionTransport.new,
);
final recallEmbedderProvider = Provider<CompanionEmbedder>(
  (ref) => CompanionEmbedder(
    transport: ref.watch(recallTransportFactoryProvider),
    id: ref.watch(aiIdProvider),
  ),
);
final recallControllerProvider =
    NotifierProvider<RecallController, RecallState>(RecallController.new);

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

class RecallController extends Notifier<RecallState> {
  int _epoch = 0;
  late int _dataGeneration;
  bool _foreground = true;
  bool _maintenanceFailed = false;
  Future<void>? _run;
  Future<void> _maintenance = Future.value();
  Timer? _timer;
  String? _profile;
  final _queries = <String, List<double>>{};
  bool _alive(int epoch) =>
      ref.mounted &&
      _foreground &&
      epoch == _epoch &&
      !ref.read(appDatabaseProvider).writingBlocked &&
      ref.read(appDatabaseProvider).writingGeneration == _dataGeneration;
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
        .listen((_) => schedule(delay: const Duration(seconds: 2)));
    ref.listen(companionControllerProvider, (previous, next) {
      final before = RecallProfile.fromStatus(previous?.status)?.id;
      final after = RecallProfile.fromStatus(next.status)?.id;
      if (before != after) {
        _epoch++;
        _queries.clear();
      }
      schedule();
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
      if (next.value!.paused) _epoch++;
      schedule();
    });
    ref.onDispose(() {
      _epoch++;
      _timer?.cancel();
      unawaited(subscription.cancel());
    });
    return const RecallState();
  }

  void schedule({Duration delay = const Duration(milliseconds: 650)}) {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer(delay, () => unawaited(run()));
  }

  void foreground(bool value) {
    _foreground = value;
    if (!value) {
      _epoch++;
      _timer?.cancel();
    } else {
      schedule();
    }
  }

  Future<void> setEnabled(String kind, bool value) async {
    _epoch++;
    await ref.read(aiPreferencesRepositoryProvider).collection(kind, value);
    schedule();
  }

  Future<void> pause(bool value) async {
    _epoch++;
    await ref.read(aiPreferencesRepositoryProvider).pause(value);
    schedule();
  }

  Future<void> rebuild() async {
    _epoch++;
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

  Future<void> _runOnce() async {
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
    final connection = ref.read(companionControllerProvider);
    final profile = RecallProfile.fromStatus(connection.status);
    if (prefs == null ||
        prefs.paused ||
        prefs.collections.isEmpty ||
        ref.read(appDatabaseProvider).writingBlocked) {
      return;
    }
    if (connection.phase != CompanionPhase.connected || profile == null) {
      state = RecallState(
        counts: state.counts,
        revision: state.revision,
        message: 'Waiting for your computer and its embedding model. Search uses keywords.',
      );
      return;
    }
    if (ref.read(aiJobsProvider).busy) {
      schedule(delay: const Duration(seconds: 2));
      return;
    }
    final epoch = ++_epoch;
    final db = ref.read(appDatabaseProvider);
    final sources = ref.read(recallSourcesProvider);
    var done = 0, total = 0;
    try {
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
      }
      final queue = await db.select(db.recallQueue).get();
      total = queue.where((row) => prefs.collections.contains(row.kind)).length;
      state = RecallState(
        running: true,
        total: total,
        counts: state.counts,
        revision: state.revision,
      );
      for (final row in queue) {
        if (!_alive(epoch)) return;
        if (!prefs.collections.contains(row.kind)) continue;
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
        } else if (previous?.complete != true ||
            previous?.hash != source.hash ||
            previous?.revision != source.revision) {
          final chunks = recallChunks(source.text);
          final ids = [
            for (var i = 0; i < chunks.length; i++)
              '${source.key}:${source.hash}:$i',
          ];
          // Record every intended ID before any vector write. A crash or source
          // deletion can then erase partial rows as well as completed chunks.
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
          for (var start = 0; start < chunks.length;) {
            if (!_alive(epoch)) return;
            final batch = <EmbedText>[];
            var cursor = start;
            while (cursor < chunks.length && batch.length < 8) {
              final next = [...batch, EmbedText('e$cursor', chunks[cursor])];
              final encoded = jsonEncode({
                'model': profile.model,
                'items': [
                  for (final i in next)
                    {'id': i.id, 'kind': 'document', 'text': i.text},
                ],
              });
              if (utf8.encode(encoded).length > 24000) break;
              batch.add(next.last);
              cursor++;
            }
            final embedded = await ref
                .read(recallEmbedderProvider)
                .embed(
                  connection.selected!,
                  profile,
                  batch,
                  active: () => _alive(epoch),
                );
            try {
              if (!_alive(epoch) || !await sources.current(source)) break;
              for (var i = start; i < cursor; i++) {
                if (!_alive(epoch)) break;
                await vectors.put(ids[i], embedded.vectors['e$i']!, chunks[i], {
                  'kind': source.kind,
                  'sourceId': source.id,
                  'revision': source.revision,
                  'hash': source.hash,
                  'date': source.date,
                  'chunk': i,
                });
              }
            } finally {
              await embedded.finish();
            }
            start = cursor;
          }
          if (!_alive(epoch)) return;
          if (!await sources.current(source)) continue;
          await vectors.remove(oldIds.where((id) => !ids.contains(id)));
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
                  chunks: jsonEncode(ids),
                  complete: const Value(true),
                ),
              );
        }
        if (!_alive(epoch)) return;
        await (db.delete(db.recallQueue)..where(
              (r) =>
                  r.kind.equals(row.kind) &
                  r.sourceId.equals(row.sourceId) &
                  r.generation.equals(row.generation),
            ))
            .go();
        done++;
        state = RecallState(
          running: true,
          done: done,
          total: total,
          counts: state.counts,
          revision: state.revision,
        );
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
    } catch (_) {
      if (_alive(epoch)) {
        state = RecallState(
          done: done,
          total: total,
          counts: state.counts,
          revision: state.revision,
          message: 'Indexing paused after a connection or storage problem. Retry when your computer is ready.',
        );
      }
    } finally {
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

  Future<RecallSearch> search(
    String query,
    String kind, {
    bool Function()? active,
  }) async {
    await _maintenance;
    final prefs = await ref.read(aiPreferencesRepositoryProvider).read();
    final connection = ref.read(companionControllerProvider);
    final profile = RecallProfile.fromStatus(connection.status);
    if (!_foreground ||
        _maintenanceFailed ||
        ref.read(appDatabaseProvider).writingBlocked ||
        !prefs.collections.contains(kind) ||
        connection.phase != CompanionPhase.connected ||
        profile == null) {
      return const RecallSearch(
        [],
        message: 'Keyword results · connect your computer and enable search by meaning to include related writing.',
      );
    }
    if (utf8.encode(query).length > 4000) {
      return const RecallSearch(
        [],
        message: 'Keyword results · use a shorter query for search by meaning.',
      );
    }
    final epoch = _epoch;
    bool alive() => _alive(epoch) && (active?.call() ?? true);
    final sources = ref.read(recallSourcesProvider);
    try {
      final vectors = await ref.read(recallVectorsProvider.future);
      if (!alive()) return const RecallSearch([]);
      if (await vectors.open(profile)) {
        _profile = null;
        schedule();
        return const RecallSearch(
          [],
          message: 'Keyword results · rebuilding the local meaning index.',
        );
      }
      final cacheKey = '${profile.id}\n$query';
      var vector = _queries[cacheKey];
      if (vector == null) {
        final batch = await ref.read(recallEmbedderProvider).embed(
          connection.selected!,
          profile,
          [EmbedText('query', query, query: true)],
          active: alive,
        );
        try {
          vector = batch.vectors['query']!;
        } finally {
          await batch.finish();
        }
        if (!alive()) return const RecallSearch([]);
        if (_queries.length >= 16) _queries.remove(_queries.keys.first);
        _queries[cacheKey] = vector;
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
