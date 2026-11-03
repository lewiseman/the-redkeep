import 'dart:convert';

import '../../diary/domain/civil_date.dart';
import '../../diary/domain/diary_day_details.dart';

import 'package:drift/drift.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../core/storage/app_database.dart';

/// Redkeep wire schema 1. Local editor revisions and recovery drafts are private.
class DriftSyncCollection implements SyncCollection {
  DriftSyncCollection(this.db, this.type);
  final AppDatabase db;
  @override
  final String type;
  @override
  String get label => switch (type) {
    'note' => 'notes',
    'diary' => 'diary',
    _ => 'thoughts',
  };
  @override
  bool get requiresRemoteForCreation => type == 'diary';
  @override
  Future<List<String>> get allIds async =>
      (await (db.select(
            db.syncRecords,
          )..where((r) => r.type.equals(type))).get())
          .map((r) => r.documentId)
          .toList();
  @override
  Future<List<String>> get pendingIds async =>
      (await (db.select(db.syncRecords)
                ..where((r) => r.type.equals(type) & r.state.equals('pending')))
              .get())
          .map((r) => r.documentId)
          .toList();
  Future<SyncRecord?> _record(String id) =>
      (db.select(db.syncRecords)
            ..where((r) => r.type.equals(type) & r.documentId.equals(id)))
          .getSingleOrNull();
  @override
  Future<SyncDocument?> read(String id) async => db.transaction(() async {
    final record = await _record(id);
    if (record == null) return null;
    final payload = <String, dynamic>{'schema': 1, 'id': id};
    if (record.removed) {
      payload['removed'] = true;
    } else if (type == 'diary') {
      final day = await (db.select(
        db.diaryDays,
      )..where((r) => r.dateKey.equals(id))).getSingleOrNull();
      final entries =
          await (db.select(db.diaryEntries)
                ..where((r) => r.dateKey.equals(id))
                ..orderBy([(r) => OrderingTerm.asc(r.id)]))
              .get();
      payload['heading'] = day?.heading ?? '';
      payload['mood'] = day?.mood;
      payload['themes'] = day == null ? <String>[] : jsonDecode(day.themes);
      payload['entries'] = entries
          .map(
            (e) => {
              'id': e.id,
              'title': e.title,
              'body': e.body,
              'created_at': e.createdAt,
              'updated_at': e.updatedAt,
              'deleted_at': e.deletedAt,
            },
          )
          .toList();
    } else {
      final table = type == 'note' ? 'notes' : 'flow_thoughts';
      final rows = await db
          .customSelect(
            'SELECT * FROM $table WHERE id = ?',
            variables: [Variable(id)],
          )
          .get();
      if (rows.isEmpty) return null;
      final data = Map<String, dynamic>.from(rows.single.data)
        ..remove('revision');
      payload.addAll(data);
      if (type == 'note') {
        final tags =
            await (db.select(db.noteTags)
                  ..where((r) => r.noteId.equals(id))
                  ..orderBy([(r) => OrderingTerm.asc(r.tag)]))
                .get();
        payload['tags'] = tags.map((r) => r.tag).toList();
      }
    }
    return SyncDocument(
      id: id,
      payload: payload,
      status: record.state == 'synced'
          ? SyncStatus.synced
          : record.state == 'localOnly'
          ? SyncStatus.localOnly
          : SyncStatus.pendingUpload,
    );
  });
  @override
  SyncDocument decode(Map<String, dynamic> payload) {
    final id = payload['id'];
    if (payload['schema'] != 1 ||
        id is! String ||
        (type == 'diary'
            ? CivilDate.tryParse(id) == null
            : !RegExp(r'^[a-f0-9]{32}$').hasMatch(id))) {
      throw const FormatException('Unsupported Redkeep document.');
    }
    if (type == 'diary' && payload['removed'] == true) {
      throw const FormatException('Diary days use entry tombstones.');
    }
    if (payload['removed'] != true) {
      if (type == 'diary') {
        if (payload['heading'] is! String ||
            (payload['heading'] as String).length > 160 ||
            payload['entries'] is! List) {
          throw const FormatException('Invalid diary day.');
        }
        if ((payload['mood'] != null &&
                (payload['mood'] is! String ||
                    DiaryMood.tryParse(payload['mood'] as String) == null)) ||
            (payload['themes'] != null &&
                (payload['themes'] is! List ||
                    (payload['themes'] as List).any(
                      (theme) => theme is! String,
                    )))) {
          throw const FormatException('Invalid diary day details.');
        }
        final themes = normalizeDiaryThemes(
          (payload['themes'] as List? ?? const []).cast<String>(),
        );
        payload = {...payload, 'mood': payload['mood'], 'themes': themes};
        final ids = <String>{};
        for (final item in payload['entries'] as List) {
          if (item is! Map<String, dynamic> ||
              item['id'] is! String ||
              !RegExp(r'^[a-f0-9]{32}$').hasMatch(item['id']) ||
              !ids.add(item['id'])) {
            throw const FormatException('Invalid diary entry.');
          }
          _validateText(item, title: true);
        }
      } else {
        _validateText(payload, title: type == 'note');
        if (type == 'note' &&
            (payload['pinned'] != 0 && payload['pinned'] != 1 ||
                payload['tags'] is! List ||
                (payload['tags'] as List).any(
                  (t) => t is! String || t.isEmpty || t.length > 40,
                ))) {
          throw const FormatException('Invalid note metadata.');
        }
      }
    }
    return SyncDocument(id: id, payload: payload);
  }

  void _validateText(Map<String, dynamic> p, {required bool title}) {
    if (p['body'] is! String ||
        (title && p['title'] is! String) ||
        p['created_at'] is! int ||
        p['updated_at'] is! int ||
        (p['deleted_at'] != null && p['deleted_at'] is! int)) {
      throw const FormatException('Invalid writing payload.');
    }
  }

  @override
  Future<bool> mergeRemote(
    SyncDocument document, {
    required DateTime now,
  }) => db.transaction(() async {
    document = decode(document.payload);
    final local = await read(document.id);
    // Dirty/local-only snapshots win. The engine uses the remote as a guarded
    // baseline and uploads the latest local snapshot without acknowledging it.
    if (local != null && local.status != SyncStatus.synced) {
      if (type == 'diary' && document.payload['removed'] != true) {
        // A primary edit owns its fields, while unseen secondary additions must
        // survive the full round trip. Never upload a day that drops those IDs.
        final ids = (local.payload['entries'] as List)
            .map((e) => e['id'])
            .toSet();
        for (final item
            in (document.payload['entries'] as List)
                .cast<Map<String, dynamic>>()) {
          if (!ids.contains(item['id'])) {
            await _putDiaryEntry(document.id, item);
            await (db.delete(db.syncOperations)..where(
                  (r) =>
                      r.type.equals(type) & r.id.equals(item['id'] as String),
                ))
                .go();
          }
        }
      }
      return false;
    }
    if (local != null &&
        canonicalJson(local.payload) == canonicalJson(document.payload)) {
      return false;
    }
    final p = document.payload;
    if (p['removed'] == true) {
      if (type == 'note') {
        await (db.delete(
          db.noteTags,
        )..where((r) => r.noteId.equals(document.id))).go();
        await (db.delete(
          db.notes,
        )..where((r) => r.id.equals(document.id))).go();
      } else if (type == 'thought') {
        await (db.delete(
          db.flowThoughts,
        )..where((r) => r.id.equals(document.id))).go();
      } else {
        throw const FormatException('Diary days use entry tombstones.');
      }
    } else if (type == 'diary') {
      final old = await (db.select(
        db.diaryDays,
      )..where((r) => r.dateKey.equals(document.id))).getSingleOrNull();
      await db
          .into(db.diaryDays)
          .insertOnConflictUpdate(
            DiaryDaysCompanion.insert(
              dateKey: document.id,
              heading: p['heading'] as String,
              mood: Value(p['mood'] as String?),
              themes: Value(jsonEncode(p['themes'])),
              revision: (old?.revision ?? 0) + 1,
            ),
          );
      for (final item in (p['entries'] as List).cast<Map<String, dynamic>>()) {
        await _putDiaryEntry(document.id, item);
      }
    } else if (type == 'note') {
      final old = await (db.select(
        db.notes,
      )..where((r) => r.id.equals(document.id))).getSingleOrNull();
      await db
          .into(db.notes)
          .insertOnConflictUpdate(
            NotesCompanion.insert(
              id: document.id,
              title: p['title'] as String,
              body: p['body'] as String,
              revision: (old?.revision ?? 0) + 1,
              createdAt: p['created_at'] as int,
              updatedAt: p['updated_at'] as int,
              pinned: Value(p['pinned'] == 1),
              deletedAt: Value(p['deleted_at'] as int?),
            ),
          );
      await (db.delete(
        db.noteTags,
      )..where((r) => r.noteId.equals(document.id))).go();
      for (final tag in (p['tags'] as List).cast<String>().toSet()) {
        await db
            .into(db.noteTags)
            .insert(NoteTagsCompanion.insert(noteId: document.id, tag: tag));
      }
    } else {
      final old = await (db.select(
        db.flowThoughts,
      )..where((r) => r.id.equals(document.id))).getSingleOrNull();
      await db
          .into(db.flowThoughts)
          .insertOnConflictUpdate(
            FlowThoughtsCompanion.insert(
              id: document.id,
              body: p['body'] as String,
              revision: (old?.revision ?? 0) + 1,
              createdAt: p['created_at'] as int,
              updatedAt: p['updated_at'] as int,
              deletedAt: Value(p['deleted_at'] as int?),
            ),
          );
    }
    await db
        .into(db.syncRecords)
        .insertOnConflictUpdate(
          SyncRecordsCompanion.insert(
            type: type,
            documentId: document.id,
            state: const Value('synced'),
            removed: Value(p['removed'] == true),
          ),
        );
    await (db.delete(
          db.syncOperations,
        )..where((r) => r.type.equals(type) & r.documentId.equals(document.id)))
        .go();
    return false;
  });
  Future<void> _putDiaryEntry(String date, Map<String, dynamic> item) async {
    final old = await (db.select(
      db.diaryEntries,
    )..where((r) => r.id.equals(item['id'] as String))).getSingleOrNull();
    if (old != null && old.dateKey != date) {
      throw const FormatException('Diary entry belongs to another day.');
    }
    await db
        .into(db.diaryEntries)
        .insertOnConflictUpdate(
          DiaryEntriesCompanion.insert(
            id: item['id'] as String,
            dateKey: date,
            title: item['title'] as String,
            body: item['body'] as String,
            revision: (old?.revision ?? 0) + 1,
            createdAt: item['created_at'] as int,
            updatedAt: item['updated_at'] as int,
            deletedAt: Value(item['deleted_at'] as int?),
          ),
        );
  }

  @override
  SyncDocument appendCreations(
    SyncDocument? remote,
    List<PendingCreation> operations,
  ) {
    if (type != 'diary') return remote ?? decode(operations.single.payload);
    final p =
        remote?.payload ??
        {
          'schema': 1,
          'id': operations.first.documentId,
          'heading': '',
          'entries': <Map<String, dynamic>>[],
        };
    final entries = (p['entries'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
    final ids = entries.map((e) => e['id']).toSet();
    for (final op in operations) {
      final entry = (op.payload['entry'] as Map).cast<String, dynamic>();
      if (ids.add(entry['id'])) entries.add(entry);
    }
    entries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return decode({...p, 'entries': entries});
  }

  @override
  List<SyncDocument> migrateLegacy(
    List<RemoteDocument> documents,
    String primaryDeviceId,
  ) => throw const FormatException('Journal imports are not supported.');
  @override
  Future<void> markPending(String id) async {
    await (db.update(db.syncRecords)
          ..where((r) => r.type.equals(type) & r.documentId.equals(id)))
        .write(const SyncRecordsCompanion(state: Value('pending')));
  }

  @override
  Future<void> acknowledgeUpload(SyncDocument document) =>
      db.transaction(() async {
        final latest = await read(document.id);
        if (latest == null ||
            canonicalJson(latest.payload) != canonicalJson(document.payload)) {
          return;
        }
        await (db.update(db.syncRecords)..where(
              (r) => r.type.equals(type) & r.documentId.equals(document.id),
            ))
            .write(const SyncRecordsCompanion(state: Value('synced')));
        await (db.delete(db.syncOperations)..where(
              (r) => r.type.equals(type) & r.documentId.equals(document.id),
            ))
            .go();
      });
  @override
  Future<void> acknowledgeCreations(
    List<PendingCreation> operations,
    SyncDocument uploaded,
  ) => db.transaction(() async {
    for (final op in operations) {
      await (db.delete(
        db.syncOperations,
      )..where((r) => r.type.equals(type) & r.id.equals(op.id))).go();
    }
    // Only acknowledge an exact snapshot: an edit made during upload stays local.
    await acknowledgeUpload(uploaded);
  });
  @override
  Future<void> restrictToSecondary() async {
    await (db.update(db.syncRecords)
          ..where((r) => r.type.equals(type) & r.state.equals('pending')))
        .write(const SyncRecordsCompanion(state: Value('localOnly')));
  }
}
