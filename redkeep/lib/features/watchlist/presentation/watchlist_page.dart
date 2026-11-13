import 'package:flutter/material.dart';

import '../../assets/presentation/local_artwork.dart';
import '../../sync/presentation/sync_material.dart';

/// The Watchlist, opened from More.
class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final showArtwork = MediaQuery.textScalerOf(context).scale(14) <= 28;
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Watchlist',
          style: TextStyle(
            fontSize: 20,
            height: 1.2,
            letterSpacing: -.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MoreSurface.contentWidth,
              ),
              child: Column(
                children: [
                  if (showArtwork) ...[
                    const LocalArtwork(
                      assetKey: 'more.watchlist',
                      dimension: 168,
                      highResolution: true,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Nothing on your watchlist yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Films and shows you want to watch will gather here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
