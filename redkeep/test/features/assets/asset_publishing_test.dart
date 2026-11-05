import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/validate_assets.dart';

void main() {
  const catalogPath = 'assets/catalog/presentation-v1.json';
  const sourcePath = '../website/public/art';

  test(
    'app catalog matches the website artwork without a separate pack',
    () async {
      expect(
        await validateAssetSources(catalogPath, sourcePath),
        contains('24 images (PNG/WebP/JPEG), 5986951 bytes'),
      );
    },
  );

  test('unrelated website files are allowed; missing, corrupt and linked app files fail', () async {
    final root = await Directory.systemTemp.createTemp('redkeep-sources-');
    addTearDown(() => root.delete(recursive: true));
    final json = jsonDecode(await File(catalogPath).readAsString()) as Map;
    for (final row in json['assets'] as List) {
      final source = row['sourcePath'] as String;
      final target = File.fromUri(root.uri.resolve(source));
      await target.parent.create(recursive: true);
      await File('$sourcePath/$source').copy(target.path);
    }
    await File.fromUri(root.uri.resolve('unrelated.txt'))
        .writeAsString('website-only');
    expect(
      await validateAssetSources(catalogPath, root.path),
      contains('Verified'),
    );
    final image = File.fromUri(root.uri.resolve('theme_light.png'));
    final original = await image.readAsBytes();
    await image.delete();
    await expectLater(
      validateAssetSources(catalogPath, root.path),
      throwsFormatException,
    );
    await image.writeAsBytes([0]);
    await expectLater(
      validateAssetSources(catalogPath, root.path),
      throwsFormatException,
    );
    await image.delete();
    await Link(image.path)
        .create(File('$sourcePath/theme_light.png').absolute.path);
    await expectLater(
      validateAssetSources(catalogPath, root.path),
      throwsFormatException,
    );
    await Link(image.path).delete();
    await image.writeAsBytes(original);
    expect(
      await validateAssetSources(catalogPath, root.path),
      contains('Verified'),
    );
  });

  test('matching size/hash cannot qualify unusable image bytes', () async {
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
    await File.fromUri(root.uri.resolve(row['sourcePath'] as String))
        .writeAsBytes(bytes);
    await expectLater(
      validateAssetSources(catalog.path, root.path),
      throwsFormatException,
    );
  });
}
