import 'dart:io';
import 'dart:ui' show FontStyle;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts_lite.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../appearance/data/font_download_client.dart';

/// Fetches a whole Google Font for embedding in a themed note website, whose
/// web view can't reach the network itself. Downloads are checked against the
/// checksum `google_fonts` pins and kept in the app's cache folder.
Future<Uint8List> loadWebsiteFont(
  String family,
  int weight, {
  http.Client? client,
  Future<Directory> Function()? cacheDirectory,
}) async {
  final font = GoogleFontsLite.fontsMap[family]?.entries
      .where(
        (entry) =>
            entry.key.fontWeight.value == weight &&
            entry.key.fontStyle == FontStyle.normal,
      )
      .firstOrNull
      ?.value;
  if (font == null) throw ArgumentError.value(family, 'family');

  bool matches(Uint8List bytes) =>
      bytes.length == font.expectedLength &&
      sha256.convert(bytes).toString() == font.expectedFileHash;

  final root = await (cacheDirectory ?? getApplicationCacheDirectory)();
  final file = File(
    p.join(root.path, 'website_fonts', '${font.expectedFileHash}.ttf'),
  );
  try {
    final cached = await file.readAsBytes();
    if (matches(cached)) return cached;
  } on FileSystemException {
    // Not cached yet.
  }

  final downloader = FontDownloadClient(
    timeout: const Duration(seconds: 15),
    client: client,
  );
  try {
    final response = await downloader.get(Uri.parse(font.url));
    if (response.statusCode != 200 || !matches(response.bodyBytes)) {
      throw http.ClientException(
        'Unexpected font response',
        Uri.parse(font.url),
      );
    }
    try {
      await file.parent.create(recursive: true);
      final partial = File('${file.path}.partial');
      await partial.writeAsBytes(response.bodyBytes, flush: true);
      await partial.rename(file.path);
    } on FileSystemException {
      // The cache only saves a later download.
    }
    return response.bodyBytes;
  } finally {
    downloader.close();
  }
}
