import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/presentation/local_artwork.dart';
import '../bottom_navbar.dart';
import '../navigation_destination.dart';
import '../writing_shell.dart';

final startupArtworkLimitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 4),
);

// Decode the first screen's artwork behind the splash so it appears at once.
final startupArtworkProvider = FutureProvider<void>((ref) async {
  final location = validatedNavigationLocation(
    ref.watch(initialNavigationLocationProvider),
  );
  final destination =
      navigationRedirect(
        Uri.parse(location),
        startupReady: true,
        onboardingComplete: true,
      ) ??
      location;
  final isDiary = destination == '/' || destination == '/diary';
  if (!isDiary && !const {'/notes', '/more'}.contains(destination)) {
    return;
  }

  final images = [
    for (final key in [
      ...RedkeepBottomNavbar.visibleArtworkKeys(
        WritingShell.selectedTabFor(destination),
      ),
      if (destination == '/notes') 'notes.add',
      if (destination == '/more') 'more.appearance',
    ])
      localArtworkImage(key),
  ];
  await Future.wait(
    images.map((image) => _decode(ref, image)),
    eagerError: true,
  );
}, retry: (_, _) => null);

Future<void> _decode(Ref ref, ImageProvider provider) async {
  final decoded = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (image, _) {
      image.dispose();
      if (!decoded.isCompleted) decoded.complete();
    },
    onError: (error, stack) {
      if (!decoded.isCompleted) decoded.completeError(error, stack);
    },
  );
  final removeOnDispose = ref.onDispose(() {
    if (!decoded.isCompleted) decoded.complete();
  });
  stream.addListener(listener);
  try {
    // These are static images. Their first decoded frame is available even
    // while the native splash prevents Flutter from presenting a frame.
    await decoded.future;
  } finally {
    stream.removeListener(listener);
    removeOnDispose();
  }
}
