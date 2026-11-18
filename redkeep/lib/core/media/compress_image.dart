import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/diary/data/prepare_diary_image.dart';

const photoLongEdge = 1600;
const photoQuality = 80;
const photoSourceBytes = 40 * 1024 * 1024;

typedef CompressedPhoto = ({Uint8List bytes, String ext, String mime});

/// Encodes [bytes] as WebP with its long edge at most [longEdge], EXIF
/// orientation applied and metadata stripped. Injectable so tests stay offline.
typedef PhotoEncoder = Future<Uint8List> Function(
  Uint8List bytes, {
  required int longEdge,
  required int quality,
});

/// The encoder used for new attachments; tests override it with a fake.
final photoEncoderProvider = Provider<PhotoEncoder>((ref) => encodeWebp);

/// Shrinks a newly attached photo before it is stored or backed up.
/// GIFs are kept as they are. Throws [FormatException] for unknown formats.
Future<CompressedPhoto> compressPhoto(
  Uint8List bytes, {
  PhotoEncoder? encoder,
}) async {
  if (bytes.isEmpty || bytes.length > photoSourceBytes) {
    throw const FormatException('Choose a photo smaller than 40 MB.');
  }
  final signature = imageSignature(bytes);
  if (signature == null) {
    throw const FormatException(
      'This file is not a supported image (JPEG, PNG, WebP, GIF or HEIC).',
    );
  }
  if (signature == ImageSignature.gif) {
    return (bytes: bytes, ext: '.gif', mime: 'image/gif');
  }
  final Uint8List encoded;
  try {
    encoded = await (encoder ?? encodeWebp)(
      bytes,
      longEdge: photoLongEdge,
      quality: photoQuality,
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('This photo could not be prepared.');
  }
  if (encoded.isEmpty) {
    throw const FormatException('This photo could not be prepared.');
  }
  if (encoded.length >= bytes.length) {
    if (signature == ImageSignature.jpeg) {
      return (bytes: bytes, ext: '.jpg', mime: 'image/jpeg');
    }
    if (signature == ImageSignature.webp) {
      return (bytes: bytes, ext: '.webp', mime: 'image/webp');
    }
  }
  return (bytes: encoded, ext: '.webp', mime: 'image/webp');
}

/// Native WebP encoder. The plugin scales by the smaller of width/minWidth and
/// height/minHeight, so both minimums are set from the short edge; this caps
/// the long edge whichever way EXIF turns the picture.
Future<Uint8List> encodeWebp(
  Uint8List bytes, {
  required int longEdge,
  required int quality,
}) async {
  final size = await _size(bytes);
  var min = longEdge;
  if (size != null) {
    final long = math.max(size.width, size.height);
    final short = math.min(size.width, size.height);
    min = long <= longEdge
        ? short
        : math.max(1, (short * longEdge / long).floor());
  }
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: min,
    minHeight: min,
    quality: quality,
    format: CompressFormat.webp,
    autoCorrectionAngle: true,
    keepExif: false,
  );
}

Future<({int width, int height})?> _size(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (width: descriptor.width, height: descriptor.height);
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
