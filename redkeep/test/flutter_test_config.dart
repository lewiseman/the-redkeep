import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts_lite.dart';

/// Load the consumed Google Font from its reference copy, never the network,
/// device font cache or application bundle. Other assets use the real manifest.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const fontPath = 'test-fonts/Allura-Regular.ttf';
  const codec = StandardMessageCodec();
  final bytes = ByteData.sublistView(
    File('../assets/reference/fonts/Allura-Regular.ttf').readAsBytesSync(),
  );
  GoogleFontsLite.config.allowRuntimeFetching = false;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final name = const StringCodec().decodeMessage(message);
    if (name == fontPath) return bytes;
    if (name == 'AssetManifest.bin') {
      return codec.encodeMessage({
        fontPath: [
          {'asset': fontPath},
        ],
      });
    }
    return messenger.delegate.send('flutter/assets', message);
  });
  try {
    GoogleFontsLite.getFont('Allura');
    await GoogleFontsLite.pendingFonts();
  } finally {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.clear();
  }
  // Resolve the real manifest outside widget fake-async zones. Otherwise an
  // unfinished first asset lookup can retain a future from an earlier test.
  await AssetManifest.loadFromAssetBundle(rootBundle);
  await testMain();
}
