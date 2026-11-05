import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:redkeep/features/assets/data/verify_asset_image.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

/// Optional offline check of app catalog entries against the website artwork.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/validate_assets.dart <catalog> <website-art-directory>',
    );
    exitCode = 64;
    return;
  }
  try {
    stdout.writeln(await validateAssetSources(args[0], args[1]));
  } catch (error) {
    stderr.writeln(
      error is AssetException ? 'Invalid asset catalog or location.' : error,
    );
    exitCode = 1;
  }
}

Future<String> validateAssetSources(
  String catalogPath,
  String sourcePath,
) async {
  final catalog = AssetCatalog.parse(await File(catalogPath).readAsString());
  final root = Directory(await Directory(sourcePath).resolveSymbolicLinks());
  for (final asset in catalog.assets) {
    if (asset.provenance != 'tool/assets/PROVENANCE.md' ||
        !await File(asset.provenance).exists()) {
      throw const FormatException('Missing reviewed provenance.');
    }
    var directory = root;
    final parts = asset.sourcePath.split('/');
    for (final part in parts.take(parts.length - 1)) {
      directory = Directory.fromUri(directory.uri.resolve('$part/'));
      if (await FileSystemEntity.type(
            directory.path.replaceFirst(RegExp(r'[/\\]+$'), ''),
            followLinks: false,
          ) !=
          FileSystemEntityType.directory) {
        throw const FormatException('Expected a local artwork directory.');
      }
    }
    final file = File.fromUri(directory.uri.resolve(parts.last));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Expected a regular local artwork file.');
    }
    if (await file.length() != asset.bytes ||
        (await sha256.bind(file.openRead()).first).toString() != asset.sha256) {
      throw const FormatException(
        'Size/hash does not match the pinned catalog.',
      );
    }
    try {
      verifyAssetImageBytes(await file.readAsBytes(), asset.path);
    } on AssetException {
      throw const FormatException(
        'Expected a bounded, decodable still PNG/WebP/JPEG matching its extension.',
      );
    }
  }
  return 'Verified ${catalog.pack}: ${catalog.assets.length} images (PNG/WebP/JPEG), ${catalog.assets.fold(0, (sum, a) => sum + a.bytes)} bytes. No publication performed.';
}
