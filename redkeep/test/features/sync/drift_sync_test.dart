import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
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
    final draft = await notes.putDraft(
      id: id,
      text: PlainTextDocument(body: body),
      baseRevision: opened.note?.revision ?? 0,
      expectedDraftRevision: opened.draft?.draftRevision,
    );
    return notes.commitDraft(id, draft.draftRevision);
  }
}

void main() {
  late Harness h;
  setUp(() {
    h = Harness(AppDatabase(NativeDatabase.memory()), MemoryDrive());
  });
  tearDown(() => h.close());
  test('committed writing queues atomically; drafts remain private and failed transactions roll back', () async {
    final draft = await h.notes.putDraft(
      id: noteId,
      text: const PlainTextDocument(body: 'private'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    expect(await h.db.select(h.db.syncRecords).get(), isEmpty);
    await expectLater(
      h.db.transaction(() async {
        await h.notes.commitDraft(noteId, draft.draftRevision);
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect(await h.db.select(h.db.syncRecords).get(), isEmpty);
    expect((await h.notes.openDocument(noteId)).draft!.text.body, 'private');
    await h.notes.commitDraft(noteId, draft.draftRevision);
    expect((await h.storage.pendingCreations).single.id, noteId);
    await h.engine.syncNow(manual: true);
    expect(h.drive.documents['note/$noteId']!.payload['body'], 'private');
    expect(await DriftSyncCollection(h.db, 'note').pendingIds, isEmpty);
  });
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
  test('remote changes invalidate editor revisions and preserve recovery drafts, tags and trash', () async {
    var saved = await h.saveNote(noteId, 'local');
    await h.notes.organize(
      noteId,
      saved.revision,
      pinned: true,
      tags: ['keep'],
    );
    saved = (await h.notes.openDocument(noteId)).note!;
    await h.engine.syncNow(manual: true);
    final draft = await h.notes.putDraft(
      id: noteId,
      text: const PlainTextDocument(body: 'unsaved'),
      baseRevision: saved.revision,
      expectedDraftRevision: null,
    );
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
    expect(opened.draft!.text.body, 'unsaved');
    expect(opened.note!.revision, greaterThan(saved.revision));
    await expectLater(
      h.notes.commitDraft(noteId, draft.draftRevision),
      throwsA(isA<NoteException>()),
    );
  });
  test('permanent removal keeps a durable cloud tombstone and cannot resurrect on sync', () async {
    final saved = await h.saveNote(noteId, 'remove');
    await h.engine.syncNow(manual: true);
    await h.notes.deleteNote(noteId, saved.revision);
    await h.notes.permanentlyDelete(
      noteId,
      saved.revision + 1,
      expectedDraftRevision: null,
    );
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
      final recovery = await h.notes.putDraft(
        id: noteId,
        text: const PlainTextDocument(body: 'kept before role changed'),
        baseRevision: saved.revision,
        expectedDraftRevision: null,
      );
      await expectLater(
        h.notes.commitDraft(noteId, recovery.draftRevision),
        throwsStateError,
      );
      expect(
        (await h.notes.openDocument(noteId)).draft!.text.body,
        'kept before role changed',
      );
      await h.saveNote('b' * 32, 'new secondary note');
      await h.engine.syncNow(manual: true);
      expect(
        h.drive.documents['note/${'b' * 32}']!.payload['body'],
        'new secondary note',
      );
      final past = await h.diary.putDraft(
        id: 'c' * 32,
        date: CivilDate(2026, 11, 2),
        text: const DiaryText(body: 'yesterday recovery'),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await expectLater(
        h.diary.commitDraft(past.id, past.draftRevision),
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
    final date = CivilDate(2026, 11, 3);
    final draft = await h.diary.putDraft(
      id: id,
      date: date,
      text: const DiaryText(body: 'mine'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    await h.diary.commitDraft(id, draft.draftRevision);
    await h.engine.syncNow(manual: true);
    await h.diary.renameDay(await h.diary.watchDay(date).first, 'My heading');
    final old = h.drive.documents['diary/${date.key}']!.payload;
    h.drive.seed('diary', date.key, {
      ...old,
      'entries': [
        ...(old['entries'] as List),
        {
          'id': 'e' * 32,
          'title': '',
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
    expect((payload['entries'] as List).length, 2);
  });
  test('secondary Diary append preserves remote headings, tombstones and existing IDs', () async {
    final date = CivilDate(2026, 11, 3);
    final oldId = 'd' * 32;
    final draft = await h.diary.putDraft(
      id: oldId,
      date: date,
      text: const DiaryText(body: 'old'),
      baseRevision: 0,
      expectedDraftRevision: null,
    );
    final old = await h.diary.commitDraft(oldId, draft.draftRevision);
    await h.diary.deleteEntry(oldId, old.revision);
    await h.diary.renameDay(await h.diary.watchDay(date).first, 'Keep heading');
    await h.engine.syncNow(manual: true);
    final secondary = Harness(
      AppDatabase(NativeDatabase.memory()),
      h.drive,
      device: 'secondary',
    );
    try {
      await secondary.engine.syncNow(manual: true);
      final newId = 'f' * 32;
      final draft = await secondary.diary.putDraft(
        id: newId,
        date: date,
        text: const DiaryText(body: 'new item'),
        baseRevision: 0,
        expectedDraftRevision: null,
      );
      await secondary.diary.commitDraft(newId, draft.draftRevision);
      await secondary.engine.syncNow(manual: true);
      final payload = h.drive.documents['diary/${date.key}']!.payload;
      expect(payload['heading'], 'Keep heading');
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
