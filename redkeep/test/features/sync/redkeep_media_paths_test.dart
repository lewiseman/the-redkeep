import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/sync/data/redkeep_backup.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('backs up referenced diary photos and note attachments only', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE diary_entries (photos TEXT NOT NULL)');
    db.execute('CREATE TABLE notes (details TEXT NOT NULL)');
    db.execute('INSERT INTO diary_entries VALUES (?)', [
      jsonEncode([
        {'id': 'a', 'path': 'diary_photos/a-1.webp'},
        {'id': 'b', 'path': 'diary_photos/b-2.jpg'},
      ]),
    ]);
    db.execute('INSERT INTO diary_entries VALUES (?)', ['[]']);
    db.execute('INSERT INTO diary_entries VALUES (?)', ['not json']);
    db.execute('INSERT INTO notes VALUES (?)', [
      jsonEncode({
        'attachments': [
          {'path': 'note_media/1-x.webp', 'type': 'image/webp'},
          {'path': 'note_media/2-y.mp4', 'type': 'video/mp4'},
        ],
        // Generated per device: never synced.
        'background': {'image': 'note_media/n-z.png'},
      }),
    ]);
    db.execute('INSERT INTO notes VALUES (?)', ['{}']);

    expect(mediaPathsIn(db), {
      'diary_photos/a-1.webp',
      'diary_photos/b-2.jpg',
      'note_media/1-x.webp',
      'note_media/1-x.webp.scan.json',
      'note_media/2-y.mp4',
      'note_media/2-y.mp4.scan.json',
    });
  });

  test('a journal without media tables has nothing to back up', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect(mediaPathsIn(db), isEmpty);
  });
}
