import 'dart:convert';
import 'dart:ui' as ui;

import 'package:html/parser.dart' as html;

import '../../domain/note_details.dart';
import '../../domain/website/website_contract.dart';
import '../../data/note_media_store.dart';

/// The note's photos, in the order a website numbers them.
List<NoteAttachment> websitePhotos(List<NoteAttachment> attachments) =>
    attachments.where((a) => a.isImage).take(websiteMaxPhotos).toList();

const _photoSide = 1200;
const _passThroughBytes = 700 * 1024;

/// A photo as a data URI: small JPEG/PNG/WebP files as they are, anything
/// else downscaled to PNG. Null when the file is missing or unreadable.
Future<String?> _photoUri(NoteAttachment photo, NoteMediaStore store) async {
  try {
    final file = await store.resolve(photo.path);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    const direct = {'image/jpeg', 'image/png', 'image/webp'};
    if (direct.contains(photo.type) && bytes.length <= _passThroughBytes) {
      return 'data:${photo.type};base64,${base64Encode(bytes)}';
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final scale = longest > _photoSide ? _photoSide / longest : 1.0;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round(),
      targetHeight: (descriptor.height * scale).round(),
    );
    try {
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data == null
          ? null
          : 'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}';
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  } catch (_) {
    return null;
  }
}

final _cache = <String, String>{};
void clearNoteWebsiteCache() => _cache.clear();

/// Fills a sanitized page's `data-photo` placeholders with [photos].
/// Placeholders without a photo on this device are removed. Nothing here is stored or synced.
Future<String> withWebsiteAssets(
  String safe,
  List<NoteAttachment> photos, {
  required NoteMediaStore store,
}) async {
  // Most pages have no photos; skip parsing a large page for nothing.
  if (!safe.contains('data-photo')) return safe;
  final document = html.parse(safe);
  final placeholders = document.querySelectorAll('img[data-photo]');
  if (placeholders.isEmpty) return safe;
  final key = Object.hashAll([safe, for (final p in photos) p.path]).toString();
  if (_cache[key] case final cached?) return cached;

  final uris = <int, String?>{};
  for (final img in placeholders) {
    final index = int.tryParse(img.attributes['data-photo'] ?? '');
    final uri = index == null || index < 0 || index >= photos.length
        ? null
        : uris[index] ??= await _photoUri(photos[index], store);
    if (uri == null) {
      final parent = img.parent;
      (parent?.localName == 'figure' ? parent! : img).remove();
    } else {
      img.attributes['src'] = uri;
    }
  }
  final result = '<!doctype html>\n${document.documentElement!.outerHtml}';
  if (_cache.length >= 4) _cache.remove(_cache.keys.first);
  return _cache[key] = result;
}
