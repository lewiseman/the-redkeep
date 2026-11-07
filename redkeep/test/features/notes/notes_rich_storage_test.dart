import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:redkeep/features/notes/data/note_media_store.dart';
import 'package:redkeep/features/ai/data/ai_provider_store.dart';

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:redkeep/features/sync/data/drift_account_reset_data.dart';
import 'package:sync_wise/sync_wise.dart';

import '../../support/notes_ai_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotesAiHarness h;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    h = await NotesAiHarness.create();
  });
  tearDown(() => h.close());

  test('complete notes and prior content survive database reopen', () async {
    final path = '${h.directory.path}/writing.sqlite';
    var database = AppDatabase(NativeDatabase(File(path)));
    var repository = DriftNotesRepository(database, clock: DateTime.now);
    var saved = await repository.saveNote(
      id: notesTestId,
      text: const PlainTextDocument(body: 'Saved words'),
      expectedRevision: 0,
      details: const NoteDetails(
        background: {'type': 'sage'},
        tags: ['travel'],
      ),
    );
    saved = await repository.applyProposal(
      saved.id,
      saved.revision,
      text: const PlainTextDocument(body: 'Reviewed words'),
      details: saved.details,
    );
    await database.close();
    database = AppDatabase(NativeDatabase(File(path)));
    repository = DriftNotesRepository(database, clock: DateTime.now);
    try {
      final opened = await repository.openDocument(notesTestId);
      expect(opened.note!.text.body, 'Reviewed words');
      expect(opened.note!.details.background['type'], 'sage');
      expect(opened.note!.tags, ['travel']);
    } finally {
      await database.close();
    }
  });

  test('lost camera photo keeps its note address and is copied only once before reopening', () async {
    final source = File('${h.directory.path}/picked.png');
    await source.writeAsBytes(h.remote.generated);
    await SecureAiProviders.storage.write(
      key: NoteMediaStore.pickerKey,
      value: jsonEncode({
        'id': notesTestId,
        'created': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    var retrieved = 0;
    final store = NoteMediaStore(
      h.db,
      support: () async => h.directory,
      android: true,
      retrieve: () async {
        retrieved++;
        return LostDataResponse(files: [XFile(source.path)]);
      },
    );
    expect(await store.recoverPhoto('b' * 32), isNull);
    expect(retrieved, 0);
    final pending = (await store.pendingPhoto())!;
    expect(pending.id, notesTestId);
    expect(await store.resolve(pending.attachment.path), isNotNull);
    expect(
      (await store.pendingPhoto())!.attachment.path,
      pending.attachment.path,
    );
    expect(retrieved, 1);
    expect(
      (await store.recoverPhoto(notesTestId))!.path,
      pending.attachment.path,
    );
    expect(
      await SecureAiProviders.storage.read(key: NoteMediaStore.pickerKey),
      isNull,
    );
  });

  test(
    'reset fences a camera result still arriving from the old session',
    () async {
      await SecureAiProviders.storage.write(
        key: NoteMediaStore.pickerKey,
        value: jsonEncode({
          'id': notesTestId,
          'created': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final gate = Completer<LostDataResponse>();
      var retrieved = false;
      final store = NoteMediaStore(
        h.db,
        support: () async => h.directory,
        android: true,
        retrieve: () {
          retrieved = true;
          return gate.future;
        },
      );
      final recovery = store.pendingPhoto();
      for (var i = 0; i < 100 && !retrieved; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(retrieved, isTrue);
      h.db.writingBlocked = true;
      h.db.writingGeneration++;
      await store.clearAll();
      gate.complete(
        LostDataResponse(files: [XFile('${h.directory.path}/old.png')]),
      );
      await expectLater(recovery, throwsStateError);
      expect(
        await SecureAiProviders.storage.read(key: NoteMediaStore.pickerKey),
        isNull,
      );
    },
  );

  test('attachment-only draft commits and complete metadata survives plain-text edits', () async {
    final path = await h.media.write(h.remote.generated);
    final details = NoteDetails(
      tags: ['travel'],
      background: const {'type': 'sage'},
      attachments: [
        NoteAttachment(path: path, type: 'image/png', name: 'Page.png'),
      ],
    );
    var saved = await h.save(title: '', body: '', details: details);
    expect(saved.text.isEmpty, isTrue);
    expect(saved.details.attachments.single.path, path);
    saved = await h.save(title: 'A page', body: 'New writing');
    expect(saved.details.attachments.single.path, path);
    expect(saved.tags, ['travel']);
    expect(saved.details.background, {'type': 'sage'});
  });

  test(
    'collection excludes large website/body payloads but keeps card metadata',
    () async {
      await h.save(
        body: 'x' * 100000,
        details: NoteDetails(
          website: '<html>${'w' * 100000}</html>',
          background: const {'type': 'rose'},
        ),
      );
      var entry = (await h.repository.watchCollection().first).single;
      expect(entry.excerpt.length, 600);
      expect(entry.details.website, isEmpty);
      expect(entry.details.background['type'], 'rose');
      await h.repository.saveNote(
        id: notesTestId,
        text: const PlainTextDocument(body: 'Edited writing'),
        expectedRevision: 1,
        details: const NoteDetails(
          background: {'type': 'sage'},
          tags: ['work'],
        ),
      );
      entry = (await h.repository.watchCollection().first).single;
      expect(entry.excerpt, 'Edited writing');
      expect(entry.details.background['type'], 'sage');
    },
  );

  test('accepted proposals are atomic and refuse stale revisions', () async {
    var note = await h.save();
    for (var i = 0; i < 12; i++) {
      note = await h.repository.applyProposal(
        note.id,
        note.revision,
        text: PlainTextDocument(title: note.text.title, body: 'Reviewed $i'),
        details: note.details,
      );
    }
    expect(note.text.body, 'Reviewed 11');
    await h.save(body: 'Manual change after proposal');
    final current = (await h.repository.openDocument(note.id)).note!;
    await expectLater(
      h.repository.applyProposal(
        note.id,
        current.revision - 1,
        text: const PlainTextDocument(body: 'Do not overwrite'),
        details: current.details,
      ),
      throwsA(isA<NoteException>()),
    );
    expect(
      (await h.repository.openDocument(note.id)).note!.text.body,
      'Manual change after proposal',
    );
  });

  test('note details round-trip through sync without media bytes', () async {
    final path = await h.media.write(h.remote.generated);
    final saved = await h.save(
      details: NoteDetails(
        attachments: [NoteAttachment(path: path, type: 'image/png')],
        background: const {'type': 'sage'},
        website: '<html><body>Garden</body></html>',
      ),
    );
    await h.repository.applyProposal(
      saved.id,
      saved.revision,
      text: const PlainTextDocument(title: 'Garden', body: 'Accepted'),
      details: saved.details,
    );
    final local = DriftSyncCollection(h.db, 'note');
    final wire = (await local.read(notesTestId))!;
    expect(wire.payload.toString(), isNot(contains('a-task')));
    expect(wire.payload.containsKey('recovery'), isFalse);
    final peer = AppDatabase(NativeDatabase.memory());
    addTearDown(peer.close);
    final collection = DriftSyncCollection(peer, 'note');
    await collection.mergeRemote(
      collection.decode(wire.payload),
      now: DateTime.now(),
    );
    final repository = DriftNotesRepository(peer, clock: DateTime.now);
    final imported = (await repository.openDocument(notesTestId)).note!;
    expect(imported.details.attachments.single.path, path);
    expect(imported.details.website, contains('Garden'));
    final legacy = Map<String, dynamic>.from(wire.payload)..remove('details');
    legacy['body'] = 'Edited by an older peer';
    await collection.mergeRemote(
      SyncDocument(id: notesTestId, payload: legacy),
      now: DateTime.now(),
    );
    expect(
      (await repository.openDocument(notesTestId))
          .note!
          .details
          .attachments
          .single
          .path,
      path,
    );
  });

  test('media corruption and path escapes are refused; cleanup retains referenced files', () async {
    final path = await h.media.write(h.remote.generated);
    await h.save(
      details: NoteDetails(
        attachments: [NoteAttachment(path: path, type: 'image/png')],
      ),
    );
    await (h.db.update(h.db.noteMediaOps))
        .write(const NoteMediaOpsCompanion(created: Value(0)));
    await h.media.reconcile();
    expect(await h.media.resolve(path), isNotNull);
    expect(await h.media.resolve('../private.txt'), isNull);
    final file = await h.media.file(path);
    await file.writeAsBytes([1, 2, 3]);
    expect(await h.media.resolve(path), isNull);
    await h.save(details: const NoteDetails());
    await h.media.reconcile();
    expect(await file.exists(), isFalse);
  });

  test('account reset removes metadata and app-owned media', () async {
    final path = await h.media.write(h.remote.generated);
    final saved = await h.save(
      details: NoteDetails(
        attachments: [NoteAttachment(path: path, type: 'image/png')],
      ),
    );
    await h.repository.applyProposal(
      saved.id,
      saved.revision,
      text: const PlainTextDocument(body: 'Reviewed'),
      details: saved.details,
    );
    h.db.writingBlocked = true;
    h.db.writingGeneration++;
    await DriftAccountResetData(h.db, beforeClear: h.media.clearAll).clear();
    expect(await h.db.select(h.db.notes).get(), isEmpty);
    expect(await h.db.select(h.db.noteMediaOps).get(), isEmpty);
    expect(await Directory('${h.directory.path}/note_media').exists(), isFalse);
    await expectLater(h.media.write(h.remote.generated), throwsStateError);
  });
}
