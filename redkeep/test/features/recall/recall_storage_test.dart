import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_wise/sync_wise.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/sync/data/drift_sync_collection.dart';
import 'package:redkeep/features/recall/domain/recall.dart';
import 'package:redkeep/features/recall/data/sqlite_recall_vectors.dart';
import 'package:redkeep/features/recall/data/recall_sources.dart';

void main() {
  test(
    'diary recall uses entry bodies while titles belong to the day',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final diary = DriftDiaryRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 4),
      );
      final date = DiaryPeriod(2026, 11, 4);
      final id = 'd' * 32;
      await diary.saveDay(DiaryDay(date: date, heading: 'A quiet day'));
      await diary.save(
        id: id,
        date: date,
        text: const DiaryText(body: 'Coffee by the window 🌿'),
        expectedRevision: 0,
      );
      final sources = RecallSources(db);
      final source = (await sources.all('diary')).single;
      expect(source.title, isEmpty);
      expect(source.text, 'Coffee by the window 🌿');
      expect(source.date, date.key);
      expect((await sources.read('diary', id))!.text, source.text);
    },
  );
  test('UTF-8 chunks cover all long writing without broken Unicode', () {
    final text = 'A garden 🌿 中文\n' * 1600;
    final chunks = recallChunks(text);
    expect(chunks.length, greaterThan(8));
    expect(chunks.join(), text);
    expect(chunks.every((c) => utf8.encode(c).length <= 4000), isTrue);
    expect(chunks.any((c) => c.contains('\uFFFD')), isFalse);
    expect(recallChunks('  '), isEmpty);
  });
  test('writing and outbox commit together; drafts, rollback and disabled collections do not leak', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final notes = DriftNotesRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 4),
    );
    final id = 'a' * 32;
    expect(await db.select(db.recallQueue).get(), isEmpty);
    await notes.saveNote(
      id: id,
      text: const PlainTextDocument(title: 'Private draft', body: 'Garden'),
      expectedRevision: 0,
      details: const NoteDetails(),
    );
    final row = await db.select(db.recallQueue).getSingle();
    expect((row.kind, row.sourceId), ('note', id));
    await expectLater(
      db.transaction(() async {
        await db.customStatement('UPDATE notes SET body = ? WHERE id = ?', [
          'Rollback',
          id,
        ]);
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect(
      (await db.select(db.recallQueue).getSingle()).generation,
      row.generation,
    );
    await notes.deleteNote(id, 1);
    expect(
      (await db.select(db.recallQueue).getSingle()).generation,
      greaterThan(row.generation),
    );
    await AiPreferencesRepository(db).collection('note', false);
    expect(await db.select(db.recallQueue).get(), isEmpty);
    await notes.restoreNote(id, 2);
    expect(await db.select(db.recallQueue).get(), isEmpty);
    await AiPreferencesRepository(db).collection('note', true);
    expect((await db.select(db.recallQueue).getSingle()).sourceId, id);
  });
  test(
    'sync imports enqueue derived indexing in the same primary transaction',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final collection = DriftSyncCollection(db, 'thought');
      final id = 'b' * 32;
      await collection.mergeRemote(
        SyncDocument(
          id: id,
          payload: {
            'schema': 1,
            'id': id,
            'body': 'A remotely saved garden thought',
            'created_at': 1,
            'updated_at': 2,
            'deleted_at': null,
          },
          status: SyncStatus.synced,
        ),
        now: DateTime.utc(2026, 11, 4),
      );
      final queued = await db.select(db.recallQueue).getSingle();
      expect((queued.kind, queued.sourceId), ('thought', id));
    },
  );
  test('real separate SQLite store applies cosine similarity and isolates profiles', () async {
    final root = await Directory.systemTemp.createTemp('redkeep-vector-test-');
    final extension =
        Directory('.dart_tool/hooks_runner/shared/flutter_edge_ai_sqlite/build')
            .listSync(recursive: true)
            .whereType<File>()
            .firstWhere(
              (f) => f.path.endsWith(
                Platform.isMacOS
                    ? 'libvec0.dylib'
                    : Platform.isWindows
                    ? 'vec0.dll'
                    : 'libvec0.so',
              ),
            );
    final vectors = SqliteRecallVectors(
      root,
      extensionPath: extension.absolute.path,
    );
    addTearDown(() async {
      await vectors.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    List<double> vector(double x, double y) => [
      x,
      y,
      ...List.filled(1022, 0.0),
    ];
    const profile = RecallProfile('openai:test-embed', 1024);
    expect(await vectors.open(profile), isTrue);
    await vectors.put('one', vector(1, 0), 'garden', {
      'kind': 'note',
      'sourceId': 'one',
      'hash': 'h',
      'revision': 1,
    });
    await vectors.put('related', vector(.5, .8660254), 'park', {
      'kind': 'note',
      'sourceId': 'two',
      'hash': 'h',
      'revision': 1,
    });
    await vectors.put('unrelated', vector(0, 1), 'invoice', {
      'kind': 'note',
      'sourceId': 'three',
      'hash': 'h',
      'revision': 1,
    });
    final matches = await vectors.nearest(vector(1, 0), 'note');
    expect(matches.map((h) => h.id), ['one', 'related']);
    expect(matches.first.similarity, closeTo(1, .0001));
    expect(matches.last.similarity, closeTo(.5, .0001));
    expect(await vectors.nearest(vector(1, 0), 'diary'), isEmpty);
    expect(
      await vectors.open(const RecallProfile('openai:other-embed', 1024)),
      isTrue,
    );
    expect(await vectors.nearest(vector(1, 0), 'note'), isEmpty);
    await vectors.open(profile);
    expect((await vectors.nearest(vector(1, 0), 'note')).length, 2);
    await vectors.reset();
    expect(await vectors.open(profile), isTrue);
    expect(await vectors.nearest(vector(1, 0), 'note'), isEmpty);
    await vectors.close();
    final file = File('${root.path}/${recallHash(profile.id)}.sqlite');
    await file.writeAsString('Synthetic corrupt derived index');
    expect(await vectors.open(profile), isTrue);
    expect(await vectors.nearest(vector(1, 0), 'note'), isEmpty);
    await vectors.close();
    await file.delete();
    expect(await vectors.open(profile), isTrue);
    expect(await vectors.nearest(vector(1, 0), 'note'), isEmpty);
  });
}
