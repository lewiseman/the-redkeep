import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../domain/asset_catalog.dart';

/// Used by both publishing and persistent installation. Dimensions are checked
/// before allocating pixels. No animated or extension-mismatched media is valid.
void verifyAssetImageBytes(Uint8List bytes, String path) {
  try {
    final image.Decoder decoder;
    if (path.endsWith('.png')) {
      decoder = image.PngDecoder(maxPixels: 2048 * 2048);
    } else if (path.endsWith('.webp')) {
      decoder = image.WebPDecoder()..maxPixels = 2048 * 2048;
    } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      decoder = image.JpegDecoder(maxPixels: 2048 * 2048);
    } else {
      throw const FormatException();
    }
    if (!decoder.isValidFile(bytes)) throw const FormatException();
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width > 2048 ||
        info.height > 2048 ||
        (info is image.WebPInfo ? info.hasAnimation : info.numFrames != 1)) {
      throw const FormatException();
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null ||
        decoded.width != info.width ||
        decoded.height != info.height ||
        decoded.numFrames != 1) {
      throw const FormatException();
    }
  } catch (_) {
    throw const AssetException(AssetFailure.integrity);
  }
}

/// Cold/suspicious files decode off the UI isolate; unchanged verified ledger
/// entries avoid repeating this work on ordinary offline launches.
Future<void> verifyAssetImageFile(File file, String path) => Isolate.run(() {
  verifyAssetImageBytes(file.readAsBytesSync(), path);
});
