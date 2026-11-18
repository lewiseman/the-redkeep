import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/media/compress_image.dart';

PhotoEncoder _returns(Uint8List out) =>
    (bytes, {required longEdge, required quality}) async => out;

final _webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
]);

void main() {
  test('encodes PNG and HEIC as WebP', () async {
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      ...List.filled(4, 0),
    ]);
    final heic = Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]);
    for (final source in [png, heic]) {
      final out = await compressPhoto(source, encoder: _returns(_webp));
      expect(out.bytes, _webp);
      expect(out.ext, '.webp');
      expect(out.mime, 'image/webp');
    }
  });

  test('keeps a JPEG that is already smaller than the WebP', () async {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 1]);
    final out = await compressPhoto(jpeg, encoder: _returns(_webp));
    expect(out.bytes, jpeg);
    expect(out.ext, '.jpg');
    expect(out.mime, 'image/jpeg');
  });

  test('leaves GIFs untouched and rejects unknown files', () async {
    var calls = 0;
    Future<Uint8List> count(
      Uint8List b, {
      required int longEdge,
      required int quality,
    }) async {
      calls++;
      return _webp;
    }

    final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    final out = await compressPhoto(gif, encoder: count);
    expect(out.bytes, gif);
    expect(out.mime, 'image/gif');
    await expectLater(
      compressPhoto(Uint8List.fromList([1, 2, 3, 4]), encoder: count),
      throwsFormatException,
    );
    expect(calls, 0);
  });
}
