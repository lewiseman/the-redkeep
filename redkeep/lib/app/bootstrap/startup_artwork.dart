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

// Keep the first screen's verified providers alive through the splash and any
// onboarding so the widgets can use their results without a second lookup.
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
      ref.watch(localArtworkFileProvider(key).future).then(localArtworkImage),
  ];
  await Future.wait(
    images.map((image) async {
      final provider = await image;
      if (ref.mounted) await _decode(ref, provider);
    }),
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
