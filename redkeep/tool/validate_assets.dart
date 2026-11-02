import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:redkeep/features/assets/data/asset_download_client.dart';
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
    if (asset.license != 'LicenseRef-Project-Generated' ||
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
    final header = await file
        .openRead(0, 33)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    final data = ByteData.sublistView(Uint8List.fromList(header));
    if (header.length != 33 ||
        header.take(8).join(',') != '137,80,78,71,13,10,26,10' ||
        String.fromCharCodes(header.sublist(12, 16)) != 'IHDR' ||
        data.getUint32(16) == 0 ||
        data.getUint32(20) == 0 ||
        data.getUint32(16) > 2048 ||
        data.getUint32(20) > 2048) {
      throw const FormatException('Expected a bounded PNG image.');
    }
    final decoded = image.decodePng(await file.readAsBytes());
    if (decoded == null || decoded.numFrames != 1) {
      throw const FormatException('Expected a decodable still PNG.');
    }
  }
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException(
      'Pack must contain only cataloged presentation media.',
    );
  }
  return 'Verified ${catalog.pack}: ${catalog.assets.length} PNGs, ${catalog.assets.fold(0, (sum, a) => sum + a.bytes)} bytes. No publication performed.';
}
