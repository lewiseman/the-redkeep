import 'package:redkeep/features/diary/domain/diary_photo.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/sync/data/drift_sync_store.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../../packages/sync_wise/test/support/memory_backend.dart';

final now = DateTime(2026, 11, 3, 12);
final noteId = 'a' * 32;

class Harness {
  Harness(this.db, this.drive, {this.device = 'primary'}) {
    storage = DriftSyncStateStore(db, deviceId: device, now: () => now);
    backend = MemoryBackend(drive);
    notes = DriftNotesRepository(db, clock: () => now);
    diary = DriftDiaryRepository(db, clock: () => now);
    flow = DriftFlowRepository(db, clock: () => now);
    provider = NotifierProvider<SyncEngine, SyncEngineState>(
      () => SyncEngine(
        (ref) => SyncEngineConfig(
          backend: backend,
          deviceId: device,
          deviceName: device,
          network: network,
          storage: storage,
          collections: [
            for (final type in ['note', 'diary', 'thought'])
              DriftSyncCollection(db, type),
          ],
        ),
      ),
    );
    container = ProviderContainer();
  }
  final AppDatabase db;
  final MemoryDrive drive;
  final String device;
  final network = TestNetwork();
  late final DriftSyncStateStore storage;
  late final MemoryBackend backend;
  late final DriftNotesRepository notes;
  late final DriftDiaryRepository diary;
  late final DriftFlowRepository flow;
  late final NotifierProvider<SyncEngine, SyncEngineState> provider;
  late final ProviderContainer container;
  SyncEngine get engine => container.read(provider.notifier);
  Future<void> close() async {
    container.dispose();
    backend.dispose();
    await db.close();
  }

  Future<NoteDocument> saveNote(String id, String body) async {
    final opened = await notes.openDocument(id);
    return notes.saveNote(
      id: id,
      text: PlainTextDocument(body: body),
      expectedRevision: opened.note?.revision ?? 0,
      details: opened.note?.details ?? const NoteDetails(),
    );
  }
}

void main() {
  late Harness h;
  setUp(() {
    h = Harness(AppDatabase(NativeDatabase.memory()), MemoryDrive());
  });
  tearDown(() => h.close());
  test('rich diary v2 survives secondary additions, primary edits and tombstones', () async {
    await h.engine.syncNow(manual: true);
    final date = DiaryPeriod(2026, 11, 3), photoId = 'c' * 32;
    const photo = DiaryPhoto(
      id: 'photo-11111111',
      path: 'diary_photos/photo-11111111.png',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      caption: 'My photo caption',
      seen: 'Labelled AI observation',
    );
    await h.diary.savePhotoStory(
      id: photoId,
      date: date,
      photos: const [photo],
      expectedRevision: 0,
    );
    await h.engine.syncNow(manual: true);
    final other = Harness(
      AppDatabase(NativeDatabase.memory()),
      h.drive,
      device: 'secondary',
    );
    addTearDown(other.close);
    await other.engine.syncNow(manual: true);
    expect(
      h.drive.documents['diary/${date.key}'],
      isNotNull,
      reason: h.container.read(h.provider).lastError,
    );
    expect(other.container.read(other.provider).lastError, isNull);
    // Seed an existing cached story; secondary sync itself remains append-only.
    final cached = DriftSyncCollection(other.db, 'diary');
    await cached.mergeRemote(
      cached.decode(h.drive.documents['diary/${date.key}']!.payload),
      now: now,
    );
    final received = (await other.diary.openDocument(photoId)).entry!;
    expect(received.photos.single.toJson(), photo.toJson());
    await expectLater(
      other.diary.savePhotoStory(
        id: photoId,
        date: date,
        photos: const [photo],
        expectedRevision: received.revision,
      ),
      throwsStateError,
    );
    final saved = (await h.diary.openDocument(photoId)).entry!;
    await h.diary.deleteEntry(photoId, saved.revision);
    await h.engine.syncNow(manual: true);
    await other.engine.syncNow(manual: true);
    final removed = (await h.diary.openDocument(photoId)).entry!;
    expect(removed.deletedAt, isNotNull);
    expect(removed.photos.single.toJson(), photo.toJson());
    await h.engine.syncNow(manual: true);
    final payload = h.drive.documents['diary/${date.key}']!.payload;
    final remotePhoto = (payload['entries'] as List).firstWhere(
      (e) => e['id'] == photoId,
    );
    expect(remotePhoto['photos'], [photo.toJson()]);
    await cached.mergeRemote(cached.decode(payload), now: now);
    expect(
      (await other.diary.openDocument(photoId)).entry!.photos.single.toJson(),
      photo.toJson(),
    );
    expect(h.drive.documents['diary/${date.key}']!.payload['schema'], 3);
  });

  test(
    'saved writing queues atomically and failed transactions roll back',
    () async {
      Future<NoteDocument> save() => h.notes.saveNote(
        id: noteId,
        text: const PlainTextDocument(body: 'private'),
        expectedRevision: 0,
        details: const NoteDetails(),
      );
      await expectLater(
        h.db.transaction(() async {
          await save();
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await h.db.select(h.db.syncRecords).get(), isEmpty);
      expect((await h.notes.openDocument(noteId)).note, isNull);
      await save();
      expect((await h.storage.pendingCreations).single.id, noteId);
      await h.engine.syncNow(manual: true);
      expect(h.drive.documents['note/$noteId']!.payload['body'], 'private');
      expect(await DriftSyncCollection(h.db, 'note').pendingIds, isEmpty);
    },
  );
  test('edits during upload remain pending and exact acknowledgement cannot erase them', () async {
    await h.saveNote(noteId, 'first');
    final entered = Completer<void>(), release = Completer<void>();
    h.drive.beforeUpload = (_, _) async {
      entered.complete();
      await release.future;
    };
    final syncing = h.engine.syncNow(manual: true);
    await entered.future;
    await h.saveNote(noteId, 'newer');
    release.complete();
    await syncing;
    expect(await DriftSyncCollection(h.db, 'note').pendingIds, [noteId]);
    expect(h.drive.documents['note/$noteId']!.payload['body'], 'first');
    h.drive.beforeUpload = null;
    await h.engine.syncNow(manual: true);
    expect(h.drive.documents['note/$noteId']!.payload['body'], 'newer');
  });
  test(
    'remote changes invalidate editor revisions and preserve tags and trash',
    () async {
      var saved = await h.saveNote(noteId, 'local');
      await h.notes.organize(
        noteId,
        saved.revision,
        pinned: true,
        tags: ['keep'],
      );
      saved = (await h.notes.openDocument(noteId)).note!;
      await h.engine.syncNow(manual: true);
      final payload = {
        ...h.drive.documents['note/$noteId']!.payload,
        'body': 'remote',
        'deleted_at': 123,
      };
      h.drive.seed('note', noteId, payload);
      await h.engine.syncNow(manual: true);
      final opened = await h.notes.openDocument(noteId);
      expect(opened.note!.text.body, 'remote');
      expect(opened.note!.tags, ['keep']);
      expect(opened.note!.pinned, true);
      expect(opened.note!.revision, greaterThan(saved.revision));
      await expectLater(
        h.notes.saveNote(
          id: noteId,
          text: const PlainTextDocument(body: 'unsaved'),
          expectedRevision: saved.revision,
          details: const NoteDetails(),
        ),
        throwsA(isA<NoteException>()),
      );
    },
  );
  test('permanent removal keeps a durable cloud tombstone and cannot resurrect on sync', () async {
    final saved = await h.saveNote(noteId, 'remove');
    await h.engine.syncNow(manual: true);
    await h.notes.deleteNote(noteId, saved.revision);
    await h.notes.permanentlyDelete(noteId, saved.revision + 1);
    await h.engine.syncNow(manual: true);
    await h.engine.syncNow(manual: true);
    expect(h.drive.documents['note/$noteId']!.payload['removed'], true);
    expect((await h.notes.openDocument(noteId)).note, isNull);
  });
  test(
    'secondary is add-only in repositories; primary reclaim restores editing',
    () async {
      await h.saveNote(noteId, 'before role');
      h.drive.primary = const PrimaryDevice(
        deviceId: 'other',
        deviceName: 'Other',
        fileId: 'registry',
      );
      await h.engine.syncNow(manual: true);
      final saved = (await h.notes.openDocument(noteId)).note!;
      await expectLater(
        h.notes.deleteNote(noteId, saved.revision),
        throwsStateError,
      );
      await expectLater(
        h.notes.saveNote(
          id: noteId,
          text: const PlainTextDocument(body: 'edit after role changed'),
          expectedRevision: saved.revision,
          details: const NoteDetails(),
        ),
        throwsStateError,
      );
      expect(
        (await h.notes.openDocument(noteId)).note!.text.body,
        'before role',
      );
      await h.saveNote('b' * 32, 'new secondary note');
      await h.engine.syncNow(manual: true);
      expect(
        h.drive.documents['note/${'b' * 32}']!.payload['body'],
        'new secondary note',
      );
      await expectLater(
        h.diary.save(
          id: 'c' * 32,
          date: DiaryPeriod(2026, 11, 2),
          text: const DiaryText(body: 'yesterday'),
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      await h.engine.reclaimPrimary();
      await h.saveNote(noteId, 'primary again');
      expect(
        (await h.notes.openDocument(noteId)).note!.text.body,
        'primary again',
      );
    },
  );
  test('dirty primary diary merges unseen secondary additions without losing headings or tombstones', () async {
    final id = 'd' * 32;
    final date = DiaryPeriod(2026, 11, 3);
    await h.diary.save(
      id: id,
      date: date,
      text: const DiaryText(body: 'mine'),
      expectedRevision: 0,
    );
    await h.engine.syncNow(manual: true);
    await h.diary.saveDay(
      DiaryDay(
        date: date,
        heading: 'My heading',
        mood: DiaryMood.excited,
        themes: const ['Work'],
      ),
    );
    final old = h.drive.documents['diary/${date.key}']!.payload;
    h.drive.seed('diary', date.key, {
      ...old,
      'entries': [
        ...(old['entries'] as List),
        {
          'id': 'e' * 32,
          'body': 'secondary',
          'created_at': 1,
          'updated_at': 1,
          'deleted_at': null,
        },
      ],
    });
    await h.engine.syncNow(manual: true);
    final payload = h.drive.documents['diary/${date.key}']!.payload;
    expect(payload['heading'], 'My heading');
    expect(payload['mood'], 'excited');
    expect(payload['themes'], ['Work']);
    expect((payload['entries'] as List).length, 2);
    expect(
      (payload['entries'] as List).every(
        (item) => !(item as Map).containsKey('title'),
      ),
      isTrue,
    );
    expect(
      (await h.diary.openDocument('e' * 32)).entry!.text.body,
      'secondary',
    );
  });
  test('secondary Diary append preserves remote headings, tombstones and existing IDs', () async {
    final date = DiaryPeriod(2026, 11, 3);
    final oldId = 'd' * 32;
    final old = await h.diary.save(
      id: oldId,
      date: date,
      text: const DiaryText(body: 'old'),
      expectedRevision: 0,
    );
    await h.diary.deleteEntry(oldId, old.revision);
    await h.diary.saveDay(
      DiaryDay(
        date: date,
        heading: 'Keep heading',
        mood: DiaryMood.calm,
        themes: const ['Family', '工作'],
      ),
    );
    await h.engine.syncNow(manual: true);
    final secondary = Harness(
      AppDatabase(NativeDatabase.memory()),
      h.drive,
      device: 'secondary',
    );
    try {
      await secondary.engine.syncNow(manual: true);
      await expectLater(
        secondary.diary.saveDay(DiaryDay(date: date, mood: DiaryMood.low)),
        throwsStateError,
      );
      final newId = 'f' * 32;
      await secondary.diary.save(
        id: newId,
        date: date,
        text: const DiaryText(body: 'new item'),
        expectedRevision: 0,
      );
      await secondary.engine.syncNow(manual: true);
      final payload = h.drive.documents['diary/${date.key}']!.payload;
      expect(payload['heading'], 'Keep heading');
      expect(payload['mood'], 'calm');
      expect(payload['themes'], ['Family', '工作']);
      expect((payload['entries'] as List).length, 2);
      expect(
        (payload['entries'] as List).firstWhere(
          (e) => e['id'] == oldId,
        )['deleted_at'],
        isNotNull,
      );
      await h.engine.syncNow(manual: true);
      expect((await h.diary.openDocument(newId)).entry!.text.body, 'new item');
    } finally {
      await secondary.close();
    }
  });
  test('period day payloads default to empty details and malformed metadata is rejected', () async {
    final collection = DriftSyncCollection(h.db, 'diary');
    final date = DiaryPeriod(2026, 11, 2);
    final legacy = <String, dynamic>{
      'schema': 3,
      'id': date.key,
      'heading': 'Old title',
      'entries': <Map<String, dynamic>>[],
    };
    final decoded = collection.decode(legacy);
    expect(decoded.payload['mood'], isNull);
    expect(decoded.payload['themes'], isEmpty);
    await collection.mergeRemote(
      SyncDocument(id: date.key, payload: legacy),
      now: now,
    );
    final first = await h.diary.watchDay(date).first;
    expect(first.heading, 'Old title');
    expect(first.mood, isNull);
    expect(first.themes, isEmpty);
    await collection.mergeRemote(
      SyncDocument(id: date.key, payload: legacy),
      now: now,
    );
    expect((await h.diary.watchDay(date).first).revision, first.revision);
    await collection.mergeRemote(
      collection.decode({
        ...legacy,
        'mood': 'calm',
        'themes': ['Family', '工作'],
      }),
      now: now,
    );
    final details = await h.diary.watchDay(date).first;
    expect(details.mood, DiaryMood.calm);
    expect(details.themes, ['Family', '工作']);
    final serialized = (await collection.read(date.key))!.payload;
    expect(serialized['mood'], 'calm');
    expect(serialized['themes'], ['Family', '工作']);
    await collection.mergeRemote(
      collection.decode({...serialized, 'mood': null, 'themes': <String>[]}),
      now: now,
    );
    final cleared = await h.diary.watchDay(date).first;
    expect(cleared.mood, isNull);
    expect(cleared.themes, isEmpty);
    // Any single emoji syncs as itself; presets keep their names.
    await collection.mergeRemote(
      collection.decode({...legacy, 'mood': '🧑🏽‍💻'}),
      now: now,
    );
    expect((await h.diary.watchDay(date).first).mood?.emoji, '🧑🏽‍💻');
    expect((await collection.read(date.key))!.payload['mood'], '🧑🏽‍💻');
    for (final invalid in [
      {...legacy, 'mood': 'unknown'},
      {...legacy, 'mood': '😊 good'},
      {...legacy, 'mood': '😊😊'},
      {...legacy, 'mood': 1},
      {...legacy, 'themes': 'Work'},
      {
        ...legacy,
        'themes': [1],
      },
      {
        ...legacy,
        'themes': ['One', 'Two', 'Three', 'Four'],
      },
      {
        ...legacy,
        'themes': ['x' * 41],
      },
    ]) {
      expect(() => collection.decode(invalid), throwsFormatException);
    }
  });
  test(
    'changing accounts cannot upload local writing to the new account',
    () async {
      await h.saveNote(noteId, 'bound');
      await h.engine.syncNow(manual: true);
      await h.saveNote(noteId, 'private change');
      h.backend.auth.user = const SyncAccount(
        id: 'other',
        email: 'other@example.test',
      );
      await h.engine.syncNow(manual: true);
      expect(h.container.read(h.provider).status, EngineSyncState.error);
      expect(h.drive.documents['note/$noteId']!.payload['body'], 'bound');
      expect(await DriftSyncCollection(h.db, 'note').pendingIds, [noteId]);
    },
  );
  test('reset cleanup keeps preferences/name/models untouched and rejects late repository writes', () async {
    await h.saveNote(noteId, 'erase');
    await h.db.customStatement(
      "INSERT INTO onboarding_completion(id,name) VALUES(1,'Lewis')",
    );
    await h.db.customStatement(
      "INSERT INTO appearance_settings(id,theme) VALUES(1,'dark')",
    );
    h.db.writingBlocked = true;
    h.db.writingGeneration++;
    await DriftAccountResetData(h.db).clear();
    h.db.writingBlocked = false;
    await expectLater(h.saveNote(noteId, 'late'), throwsStateError);
    expect(
      (await h.db.select(h.db.onboardingCompletion).getSingle()).name,
      'Lewis',
    );
    expect(
      (await h.db.select(h.db.appearanceSettings).getSingle()).theme,
      'dark',
    );
    expect(await h.db.select(h.db.notes).get(), isEmpty);
    expect(await h.db.select(h.db.syncRecords).get(), isEmpty);
  });
  test(
    'offline outbox and role survive background database close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('redkeep-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/writing.sqlite');
      final first = Harness(
        AppDatabase(NativeDatabase.createInBackground(file)),
        MemoryDrive(),
      );
      await first.saveNote(noteId, 'offline');
      first.network.online = false;
      await first.engine.syncNow();
      await first.close();
      final second = Harness(
        AppDatabase(NativeDatabase.createInBackground(file)),
        MemoryDrive(),
      );
      try {
        await second.engine.syncNow(manual: true);
        expect(
          second.drive.documents['note/$noteId']!.payload['body'],
          'offline',
        );
      } finally {
        await second.close();
      }
    },
  );
}
