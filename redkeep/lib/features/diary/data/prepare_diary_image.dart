import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../companion/data/companion_protocol.dart';

const noteImageSourceBytes = 40 * 1024 * 1024;
const noteImageUploadBytes = 2560 * 1024;
const _sides = [1280, 1024, 896, 768];
Future<Uint8List> prepareImageBytes(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > noteImageSourceBytes) {
    throw const CompanionFailure(
      'INVALID_IMAGE',
      'This image is empty or larger than 40 MB. Nothing was sent.',
    );
  }
  if (!_looksLikeImage(bytes)) {
    throw const CompanionFailure(
      'INVALID_IMAGE',
      'This file is not a supported image (JPEG, PNG, WebP, GIF or HEIC). Nothing was sent.',
    );
  }
  for (final side in _sides) {
    final png = await _encode(bytes, side);
    if (png.length <= noteImageUploadBytes) return png;
  }
  throw const CompanionFailure(
    'INVALID_IMAGE',
    'This image is too detailed to send within the size limit. Nothing was sent.',
  );
}

bool _looksLikeImage(Uint8List b) {
  bool starts(List<int> sig, [int offset = 0]) =>
      b.length >= offset + sig.length &&
      [for (var i = 0; i < sig.length; i++) b[offset + i] == sig[i]]
          .every((x) => x);
  return starts([0xff, 0xd8, 0xff]) ||
      starts([0x89, 0x50, 0x4e, 0x47]) ||
      starts([0x47, 0x49, 0x46, 0x38]) ||
      (starts([0x52, 0x49, 0x46, 0x46]) &&
          starts([0x57, 0x45, 0x42, 0x50], 8)) ||
      starts([0x66, 0x74, 0x79, 0x70], 4);
}

Future<Uint8List> _encode(Uint8List bytes, int side) async {
  final ui.ImmutableBuffer buffer;
  final ui.ImageDescriptor descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    throw const CompanionFailure(
      'INVALID_IMAGE',
      'This image could not be decoded on this phone. Nothing was sent.',
    );
  }
  final scale =
      side /
      (descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height);
  final codec = await descriptor.instantiateCodec(
    targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
    targetHeight: scale < 1 ? (descriptor.height * scale).round() : null,
  );
  try {
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (data == null) throw const FormatException();
    return data.buffer.asUint8List();
  } catch (_) {
    throw const CompanionFailure(
      'INVALID_IMAGE',
      'This image could not be prepared on this phone. Nothing was sent.',
    );
  } finally {
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}
