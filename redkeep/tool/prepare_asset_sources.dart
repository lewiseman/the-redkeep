import 'dart:convert';
import 'dart:io';

import 'package:redkeep/features/assets/data/asset_download_client.dart';
import 'package:redkeep/features/assets/domain/asset_catalog.dart';

/// Local build preparation only. Never prints URLs, reads runtime repository
/// files from the app, or changes the directory fallback/unrelated env values.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/prepare_asset_sources.dart <source-list.json> <env.json>',
    );
    exitCode = 64;
    return;
  }
  try {
    final count = await prepareAssetSources(args[0], args[1]);
    stdout.writeln(
      'Prepared $count cataloged source URLs. No requests performed.',
    );
  } catch (_) {
    stderr.writeln(
      'Could not prepare asset sources. Check the local JSON, catalog keys and complete HTTPS URLs.',
    );
    exitCode = 1;
  }
}

Future<int> prepareAssetSources(
  String sourcePath,
  String envPath, {
  String catalogPath = 'assets/catalog/presentation-v1.json',
}) async {
  final catalog = AssetCatalog.parse(await File(catalogPath).readAsString());
  final input =
      jsonDecode(await File(sourcePath).readAsString()) as Map<String, dynamic>;
  // Retire old overrides for bundled artwork; keep all other validation strict.
  final known = catalog.assets.map((a) => a.key).toSet();
  if (input.keys.any(
    (k) => !known.contains(k) && !bundledArtworkKeys.contains(k),
  )) {
    throw const FormatException();
  }
  final sources = {
    for (final entry in input.entries)
      if (known.contains(entry.key) && entry.value != '')
        entry.key: entry.value,
  };
  final encoded = jsonEncode(sources);
  AssetLocation('', catalog: catalog, sourceUrlsJson: encoded);
  final env = File(envPath);
  final values = jsonDecode(await env.readAsString()) as Map<String, dynamic>;
  values['ASSET_SOURCE_URLS_JSON'] = encoded;
  final pending = File('$envPath.pending');
  try {
    await pending.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(values)}\n',
      flush: true,
    );
    await pending.rename(env.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
  return sources.length;
}
