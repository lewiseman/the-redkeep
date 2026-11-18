import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/notes/data/note_media_store.dart';

final _webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 1, 2, 3, //
]);

void main() {
  late AppDatabase db;
  late Directory directory;
  late List<({int longEdge, int quality, int length})> encoded;
  late NoteMediaStore store;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('redkeep-note-media-');
    encoded = [];
    store = NoteMediaStore(
      db,
      support: () async => directory,
      android: true,
      encoder: (bytes, {required longEdge, required quality}) async {
        encoded.add((
          longEdge: longEdge,
          quality: quality,
          length: bytes.length,
        ));
        return _webp;
      },
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<File> source(String name, Uint8List bytes) =>
      File('${directory.path}/$name').writeAsBytes(bytes);

  test('rejects a non-image file over 10 MB', () async {
    final file = await source('clip.mp4', Uint8List(10 * 1024 * 1024 + 1));
    await expectLater(
      store.importPath(file.path),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Choose a file smaller than 10 MB.',
        ),
      ),
    );
    expect(encoded, isEmpty);
  });

  test('copies a 9 MB non-image unchanged', () async {
    final bytes = Uint8List(9 * 1024 * 1024)..[0] = 0x25;
    final file = await source('report.pdf', bytes);
    final attachment = await store.importPath(file.path);
    expect(encoded, isEmpty);
    expect(attachment.name, 'report.pdf');
    expect(attachment.path, endsWith('.pdf'));
    final stored = await store.resolve(attachment.path);
    expect(sha256.convert(await stored!.readAsBytes()), sha256.convert(bytes));
  });

  test('sends photos through the compressor and stores WebP', () async {
    final png = Uint8List(12 * 1024 * 1024)
      ..setAll(0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    final file = await source('Beach.png', png);
    final attachment = await store.importPath(file.path);
    expect(encoded, [(longEdge: 1600, quality: 80, length: png.length)]);
    expect(attachment.type, 'image/webp');
    expect(attachment.name, 'Beach.webp');
    expect(attachment.path, endsWith('-${sha256.convert(_webp)}.webp'));
    expect(await (await store.resolve(attachment.path))!.readAsBytes(), _webp);
  });

  test('keeps GIFs untouched', () async {
    final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1]);
    final file = await source('wave.gif', gif);
    final attachment = await store.importPath(file.path);
    expect(encoded, isEmpty);
    expect(attachment.type, 'image/gif');
    expect(await (await store.resolve(attachment.path))!.readAsBytes(), gif);
  });
}
