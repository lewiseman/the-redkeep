import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/validate_assets.dart';

void main() {
  const catalogPath = 'assets/catalog/presentation-v1.json';
  const packPath = 'tool/assets/pack';

  test('reviewed local pack decodes, matches pinned metadata, and contains no extras', () async {
    expect(
      await validateAssetPack(catalogPath, packPath),
      contains('12 images (PNG/WebP/JPEG), 2658676 bytes'),
    );
    for (final base in [
      '',
      'http://localhost:8765/',
      'https://example.com/',
      'https://127.0.0.1/',
    ]) {
      await expectLater(
        validateAssetPack(catalogPath, packPath, releaseBase: base),
        throwsA(isA<Exception>()),
      );
    }
  });

  test(
    'publishing rejects extra files, corrupt payloads and symlinks',
    () async {
      final root = await Directory.systemTemp.createTemp('redkeep-publish-');
      addTearDown(() => root.delete(recursive: true));
      final pack = Directory.fromUri(root.uri.resolve('pack/'));
      final source = Directory(packPath);
      await for (final entity in source.list(recursive: true)) {
        if (entity is File) {
          final target = File.fromUri(
            pack.uri.resolve(
              entity.absolute.uri.path.substring(
                source.absolute.uri.path.length,
              ),
            ),
          );
          await target.parent.create(recursive: true);
          await entity.copy(target.path);
        }
      }
      final extra = File.fromUri(pack.uri.resolve('unassigned.wav'));
      await extra.writeAsBytes([0]);
      await expectLater(
        validateAssetPack(catalogPath, pack.path),
        throwsFormatException,
      );
      await extra.delete();
      final image = File.fromUri(
        pack.uri.resolve('appearance/theme-light-v1.png'),
      );
      final original = await image.readAsBytes();
      await image.writeAsBytes([0]);
      await expectLater(
        validateAssetPack(catalogPath, pack.path),
        throwsFormatException,
      );
      await image.delete();
      await Link(image.path).create(
        File('tool/assets/pack/appearance/theme-light-v1.png').absolute.path,
      );
      await expectLater(
        validateAssetPack(catalogPath, pack.path),
        throwsFormatException,
      );
      await Link(image.path).delete();
      await image.writeAsBytes(original);
      expect(
        await validateAssetPack(catalogPath, pack.path),
        contains('Verified'),
      );
    },
  );

  test(
    'publishing rejects unusable PNG bytes even with matching size/hash',
    () async {
      final root = await Directory.systemTemp.createTemp('redkeep-bad-image-');
      addTearDown(() => root.delete(recursive: true));
      final json = jsonDecode(
        await File(catalogPath).readAsString(),
      ) as Map<String, dynamic>;
      final row = (json['assets'] as List).first;
      final bytes = List<int>.filled(64, 0);
      row['bytes'] = bytes.length;
      row['sha256'] = sha256.convert(bytes).toString();
      json['assets'] = [row];
      final catalog = File.fromUri(root.uri.resolve('bad.json'));
      await catalog.writeAsString(jsonEncode(json));
      final pack = Directory.fromUri(root.uri.resolve('pack/'));
      final image = File.fromUri(pack.uri.resolve(row['path'] as String));
      await image.parent.create(recursive: true);
      await image.writeAsBytes(bytes);
      await expectLater(
        validateAssetPack(catalog.path, pack.path),
        throwsFormatException,
      );
    },
  );
}
