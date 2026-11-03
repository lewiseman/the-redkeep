import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/data/verify_asset_image.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

/// Read-only pre-publication verification using the runtime catalog parser.
Future<void> main(List<String> args) async {
  if (args.length != 2 && args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/validate_assets.dart <catalog> <pack-directory> [https-base-url/]',
    );
    exitCode = 64;
    return;
  }
  try {
    stdout.writeln(
      await validateAssetPack(
        args[0],
        args[1],
        releaseBase: args.length == 3 ? args[2] : null,
      ),
    );
  } catch (error) {
    stderr.writeln(
      error is AssetException ? 'Invalid asset catalog or location.' : error,
    );
    exitCode = 1;
  }
}

Future<String> validateAssetPack(
  String catalogPath,
  String packPath, {
  String? releaseBase,
}) async {
  final catalog = AssetCatalog.parse(await File(catalogPath).readAsString());
  final root = Directory(await Directory(packPath).resolveSymbolicLinks());
  if (releaseBase != null) {
    final base = Uri.parse(releaseBase);
    AssetLocation(releaseBase);
    if (base.scheme != 'https' ||
        base.host == 'localhost' ||
        InternetAddress.tryParse(base.host) != null ||
        base.host == 'example.com' ||
        base.host.endsWith('.example') ||
        base.host.endsWith('.invalid') ||
        base.host.endsWith('.test')) {
      throw const FormatException('A real public HTTPS base is required.');
    }
  }
  final actual = <String>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is Link) {
      throw const FormatException('Links are not publishable.');
    }
    if (entity is File) actual.add(entity.path);
  }
  final expected = <String>{};
  for (final asset in catalog.assets) {
    if (!{
          'LicenseRef-Project-Generated',
          'LicenseRef-Project-Supplied',
        }.contains(asset.license) ||
        asset.provenance != 'tool/assets/PROVENANCE.md' ||
        !await File(asset.provenance).exists()) {
      throw const FormatException('Missing reviewed license/provenance.');
    }
    final file = File.fromUri(root.uri.resolve(asset.path));
    expected.add(file.path);
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
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException(
      'Pack must contain only cataloged presentation media.',
    );
  }
  return 'Verified ${catalog.pack}: ${catalog.assets.length} images (PNG/WebP/JPEG), ${catalog.assets.fold(0, (sum, a) => sum + a.bytes)} bytes. No publication performed.';
}
