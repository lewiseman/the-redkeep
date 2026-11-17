import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/notes/data/drift_notes_repository.dart';
import 'package:redkeep/features/notes/domain/note_document.dart';
import 'package:redkeep/features/sync/legacy/legacy_documents.dart';
import 'package:redkeep/features/sync/legacy/legacy_import.dart';

const _note = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _entry = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _thought = 'cccccccccccccccccccccccccccccccc';
const _deleted = 'dddddddddddddddddddddddddddddddd';
const _photoEntry = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

Map<String, dynamic> note({String body = 'From the old sync'}) => {
  'schema': 1,
  'id': _note,
  'title': 'Garden',
  'body': body,
  'details': '{}',
  'pinned': 1,
  'tags': ['plants', 'home'],
  'created_at': 1,
  'updated_at': 2,
};

Map<String, dynamic> diaryDay() {
  const photo = DiaryPhoto(
    id: 'photo_test',
    path: 'diary_photos/test.png',
    sha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    caption: 'Garden',
  );
  return {
    'schema': 3,
    'id': '2026-11-03',
    'heading': 'A good day',
    'mood': null,
    'themes': <String>[],
    'entries': [
      {
        'id': _entry,
        'body': 'Walked',
        'photos': <Object>[],
        'created_at': 1,
        'updated_at': 1,
        'deleted_at': null,
      },
      {
        'id': _thought,
        'body': 'Quick',
        'photos': <Object>[],
        'created_at': 2,
        'updated_at': 2,
        'deleted_at': null,
        'kind': 'thought',
      },
      {
        'id': _deleted,
        'body': 'Gone',
        'photos': <Object>[],
        'created_at': 3,
        'updated_at': 3,
        'deleted_at': 4,
      },
      {
        'id': _photoEntry,
        'body': DiaryPhoto.composeContent([photo]),
        'photos': [photo.toJson()],
        'created_at': 5,
        'updated_at': 5,
        'deleted_at': null,
      },
    ],
  };
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('missing notes arrive with their tags and pin', () async {
    expect(await LegacyDocuments(db).insertMissing('note', note()), 1);
    final opened = await DriftNotesRepository(
      db,
      clock: DateTime.now,
    ).openDocument(_note);
    expect(opened.note!.text.body, 'From the old sync');
    expect(opened.note!.pinned, isTrue);
    final tags = await db.select(db.noteTags).get();
    expect(tags.map((t) => t.tag).toSet(), {'plants', 'home'});
  });

  test('local writing always wins: existing notes are never changed', () async {
    final repository = DriftNotesRepository(db, clock: DateTime.now);
    await repository.saveNote(
      id: _note,
      text: const PlainTextDocument(title: 'Mine', body: 'Newer words'),
      expectedRevision: 0,
      details: const NoteDetails(),
    );
    expect(
      await LegacyDocuments(db).insertMissing('note', note(body: 'Older')),
      0,
    );
    expect(
      (await repository.openDocument(_note)).note!.text.body,
      'Newer words',
    );
  });

  test('removed and trashed documents are not brought back', () async {
    final store = LegacyDocuments(db);
    expect(
      await store.insertMissing('note', {
        'schema': 1,
        'id': _note,
        'removed': true,
      }),
      0,
    );
    expect(await store.insertMissing('note', {...note(), 'deleted_at': 9}), 0);
    expect(await db.select(db.notes).get(), isEmpty);
  });

  test('diary days add missing entries, thoughts and photo stories', () async {
    final repository = DriftDiaryRepository(db, clock: DateTime.now);
    expect(await LegacyDocuments(db).insertMissing('diary', diaryDay()), 3);
    expect((await repository.openDocument(_entry)).entry!.text.body, 'Walked');
    expect((await repository.openDocument(_thought)).entry!.isThought, isTrue);
    expect((await repository.openDocument(_deleted)).entry, isNull);
    final story = (await repository.openDocument(_photoEntry)).entry!;
    expect(story.photos.single.path, 'diary_photos/test.png');
    final day = await db.select(db.diaryDays).getSingle();
    expect(day.heading, 'A good day');
    // A second import changes nothing.
    expect(await LegacyDocuments(db).insertMissing('diary', diaryDay()), 0);
  });

  test('documents this version cannot read are refused', () {
    for (final bad in [
      {...note(), 'schema': 2},
      {...note(), 'id': 'short'},
      {...note(), 'tags': 'x'},
    ]) {
      expect(
        () => LegacyDocuments.decode('note', bad),
        throwsFormatException,
        reason: '$bad',
      );
    }
    expect(
      () => LegacyDocuments.decode('diary', {...diaryDay(), 'schema': 2}),
      throwsFormatException,
    );
  });

  group('Drive', () {
    late Directory directory;
    setUp(
      () async =>
          directory = await Directory.systemTemp.createTemp('redkeep-legacy-'),
    );
    tearDown(() => directory.delete(recursive: true));

    /// Old sync files: a registry, a note stored twice (an interrupted
    /// upload), a malformed note and a foreign app's file.
    MockClient drive(List<String> requests) {
      Map<String, Object?> file(String id, Map<String, String> props, String time) =>
          {'id': id, 'createdTime': time, 'appProperties': props};
      const ns = {'redkeepNamespace': 'redkeep-v1'};
      final files = [
        file('registry', {...ns, 'type': 'sync_primary'}, '2026-01-01'),
        file('n-old', {...ns, 'type': 'note', 'docId': _note}, '2026-01-02'),
        file('n-new', {...ns, 'type': 'note', 'docId': _note}, '2026-01-03'),
        file('bad', {...ns, 'type': 'note', 'docId': 'b' * 32}, '2026-01-04'),
        file('other', {'redkeepNamespace': 'journal'}, '2026-01-05'),
      ];
      final media = <String, Object>{
        'registry': {
          'documents': {'note/$_note': 'n-new'},
        },
        'n-old': note(body: 'stale copy'),
        'n-new': note(body: 'canonical copy'),
        'bad': {'schema': 1, 'id': 'b' * 32},
      };
      return MockClient((request) async {
        requests.add(request.url.path);
        final id = request.url.pathSegments.last;
        if (request.url.queryParameters['alt'] == 'media') {
          return http.Response(jsonEncode(media[id]), 200);
        }
        return http.Response(jsonEncode({'files': files}), 200);
      });
    }

    test('imports the registry copy once and skips what it cannot read', () async {
      final requests = <String>[];
      final client = drive(requests);
      final import = LegacyImport(
        db: db,
        marker: await LegacyImport.markerFile(directory),
      );
      expect(await LegacyDriveReader(client).hasData(), isTrue);
      expect(await import.run(accountId: 'owner', client: client), 1);
      final opened = await DriftNotesRepository(
        db,
        clock: DateTime.now,
      ).openDocument(_note);
      expect(opened.note!.text.body, 'canonical copy');
      expect(requests.where((r) => r.endsWith('/other')), isEmpty);

      requests.clear();
      expect(await import.isDone('owner'), isTrue);
      expect(await import.run(accountId: 'owner', client: client), 0);
      expect(requests, isEmpty, reason: 'done once per account');
      expect(await import.isDone('someone-else'), isFalse);
    });
  });
}
