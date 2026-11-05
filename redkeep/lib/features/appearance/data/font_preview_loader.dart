import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' show FontStyle, FontWeight;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts_lite.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'font_download_client.dart';

/// The only text a preview renders, so the only glyphs each subset contains.
/// Changing it requires a new [_cacheVersion].
const fontPreviewSample = 'A little room to breathe';
const _cacheVersion = 'v1';
const _requestTimeout = Duration(seconds: 8);

typedef FontRegistrar = Future<void> Function(String family, ByteData bytes);

Future<void> _registerFont(String family, ByteData bytes) =>
    (FontLoader(family)..addFont(Future.value(bytes))).load();

/// Loads a few-kilobyte subset of a font holding just [fontPreviewSample],
/// instead of the whole font file, for one row of the font picker.
///
/// Subsets are kept on disk and registered under a private family name, so
/// they can never be mistaken for the full font that a selection downloads.
class FontPreviewLoader {
  FontPreviewLoader({
    http.Client? client,
    Future<Directory> Function()? cacheDirectory,
    FontRegistrar registerFont = _registerFont,
    this.maxConcurrent = 4,
  }) : _client = FontDownloadClient(timeout: _requestTimeout, client: client),
       _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _register = registerFont;

  final FontDownloadClient _client;
  final Future<Directory> Function() _cacheDirectory;
  final FontRegistrar _register;
  final int maxConcurrent;

  final _ready = <String, String>{};
  final _unavailable = <String>{};
  final _requests = <String, Completer<String?>>{};
  final _waiters = <String, int>{};
  // Newest last: the rows the reader has just scrolled to load first.
  final _queue = ListQueue<String>();
  var _active = 0;

  /// The registered family for [family], if its preview has already loaded.
  String? readyFamily(String family) => _ready[family];

  /// Resolves to the family to render the preview with, or null if unavailable.
  Future<String?> load(String family) {
    if (_ready[family] case final ready?) return SynchronousFuture(ready);
    if (_unavailable.contains(family)) return SynchronousFuture(null);
    if (_requests[family] case final pending?) {
      _waiters[family] = (_waiters[family] ?? 0) + 1;
      return pending.future;
    }
    _waiters[family] = 1;
    final request = Completer<String?>();
    _requests[family] = request;
    _queue.addLast(family);
    _startNext();
    return request.future;
  }

  /// Withdraws one [load] call, for a row that has left the screen. A request
  /// that hasn't started is dropped once nothing else is waiting for it.
  void cancel(String family) {
    final waiters = (_waiters[family] ?? 0) - 1;
    if (waiters > 0) {
      _waiters[family] = waiters;
      return;
    }
    _waiters.remove(family);
    if (_queue.remove(family)) _requests.remove(family)?.complete(null);
  }

  void dispose() => _client.close();

  void _startNext() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      _active++;
      unawaited(_run(_queue.removeLast()));
    }
  }

  Future<void> _run(String family) async {
    String? result;
    try {
      final name = 'redkeep-preview-$family';
      await _loadBytesInto(name, family);
      _ready[family] = name;
      result = name;
    } on _PreviewNotOffered {
      _unavailable.add(family);
    } catch (_) {
      // Offline or interrupted: the row may try again when it next appears.
    } finally {
      _active--;
      _waiters.remove(family);
      _requests.remove(family)?.complete(result);
      _startNext();
    }
  }

  Future<void> _loadBytesInto(String name, String family) async {
    final file = await _cacheFile(family);
    final cached = await _read(file);
    if (cached != null) {
      try {
        return await _register(name, ByteData.sublistView(cached));
      } catch (_) {
        // A damaged cache entry shouldn't block a fresh download.
        await _delete(file);
      }
    }
    final bytes = await _download(family);
    await _register(name, ByteData.sublistView(bytes));
    await _write(file, bytes);
  }

  Future<Uint8List> _download(String family) async {
    final css = await _client.get(
      Uri.https('fonts.googleapis.com', '/css2', {
        'family': _apiFamily(family),
        'text': fontPreviewSample,
      }),
    );
    if (css.statusCode >= 400 && css.statusCode < 500) {
      throw const _PreviewNotOffered();
    }
    if (css.statusCode != 200) throw http.ClientException('Stylesheet failed');
    final url = _truetypeUrl.firstMatch(css.body)?.group(1);
    if (url == null) throw const _PreviewNotOffered();
    final font = await _client.get(Uri.parse(url));
    if (font.statusCode != 200) throw http.ClientException('Font failed');
    return font.bodyBytes;
  }

  Future<File?> _cacheFile(String family) async {
    try {
      final root = await _cacheDirectory();
      return File(
        p.join(
          root.path,
          'font_previews',
          _cacheVersion,
          '${Uri.encodeComponent(family)}.ttf',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // The disk cache only saves network use, so its failures are never fatal.
  Future<Uint8List?> _read(File? file) async {
    try {
      return await file?.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(File? file, Uint8List bytes) async {
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final partial = File('${file.path}.partial');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
    } catch (_) {}
  }

  Future<void> _delete(File? file) async {
    try {
      await file?.delete();
    } catch (_) {}
  }
}

class _PreviewNotOffered implements Exception {
  const _PreviewNotOffered();
}

// Dart's user agent receives TrueType, which is what FontLoader can read.
final _truetypeUrl = RegExp(
  r"url\((https://fonts\.gstatic\.com/[^)\s]+)\)\s*format\('truetype'\)",
);

/// The stylesheet API rejects a request for a weight the family doesn't have,
/// so name the upright style closest to regular (a few families have no 400,
/// or are italic only).
@visibleForTesting
String fontPreviewApiFamily(String family) => _apiFamily(family);

String _apiFamily(String family) {
  final variants = GoogleFontsLite.fontsMap[family]?.keys;
  if (variants == null || variants.isEmpty) return family;
  final best = variants.reduce((a, b) {
    int score(FontStyle style, FontWeight weight) =>
        (style == FontStyle.italic ? 10000 : 0) + (weight.value - 400).abs();
    return score(b.fontStyle, b.fontWeight) < score(a.fontStyle, a.fontWeight)
        ? b
        : a;
  });
  final weight = best.fontWeight.value;
  return best.fontStyle == FontStyle.italic
      ? '$family:ital,wght@1,$weight'
      : '$family:wght@$weight';
}
