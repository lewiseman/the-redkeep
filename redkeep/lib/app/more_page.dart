import 'dart:ui' show lerpDouble;

import '../core/presentation/rendering_policy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/local_artwork.dart';
import '../features/more/application/maestar_status.dart';
import '../features/more/presentation/more_index_entry.dart';
import '../features/sync/application/sync_providers.dart';
import '../features/sync/presentation/sync_card.dart';
import '../features/sync/presentation/sync_material.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});
  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _expand() {
    if (RenderingPolicyScope.of(context).reducedMotion) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maestar = ref.watch(maestarStatusProvider);
    final enabled = ref.watch(syncEnabledProvider);
    final ready = enabled && ref.watch(syncConfigurationProvider).hasValue;
    final signedIn = ready && ref.watch(syncAccountProvider) != null;
    return Scaffold(
      body: MoreSurface(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MoreSurface.contentWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => CustomScrollView(
                  key: const PageStorageKey('more-scroll'),
                  controller: _scroll,
                  slivers: [
                    if (ready)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _AccountHeader(
                          minHeight:
                              SyncAccountCard.compactHeight(context) + 24,
                          maxHeight:
                              SyncAccountCard.expandedHeight(
                                context,
                                isSignedIn: signedIn,
                              ) +
                              44,
                          onExpand: _expand,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: ready
                              ? (constraints.maxHeight -
                                        SyncAccountCard.compactHeight(context) -
                                        24)
                                    .clamp(240.0, double.infinity)
                              : 0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 4, 28, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MoreIndexEntry(
                                title: 'Watchlist',
                                description: 'Films and shows to watch',
                                artworkBuilder: (dimension) => LocalArtwork(
                                  assetKey: 'more.watchlist',
                                  dimension: dimension,
                                  highResolution: true,
                                ),
                                onTap: () => context.push('/watchlist'),
                              ),
                              MoreIndexEntry(
                                title: 'Appearance',
                                description: 'Colors, theme and fonts',
                                artworkBuilder: (dimension) => LocalArtwork(
                                  assetKey: 'more.appearance',
                                  dimension: dimension,
                                ),
                                onTap: () => context.push('/settings'),
                              ),
                              MoreIndexEntry(
                                title: 'Grand Maestar',
                                status: maestar.label,
                                ready: maestar.ready,
                                showDivider: false,
                                artworkBuilder: (dimension) => Image.asset(
                                  'assets/branding/grand_maestar.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  excludeFromSemantics: true,
                                  cacheHeight:
                                      (dimension *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .ceil(),
                                ),
                                onTap: () => context.push('/settings/brain'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends SliverPersistentHeaderDelegate {
  const _AccountHeader({
    required this.minHeight,
    required this.maxHeight,
    required this.onExpand,
  });

  final double minHeight, maxHeight;
  final VoidCallback onExpand;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    // Fill the sliver's exact allocation. Shrink-wrapping fractional padding
    // can otherwise make paintExtent a fraction smaller than layoutExtent.
    return SizedBox.expand(
      child: MoreSurface(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            lerpDouble(28, 12, progress)!,
            28,
            lerpDouble(16, 12, progress)!,
          ),
          child: SyncAccountCard(
            collapseProgress: progress,
            onExpand: onExpand,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_AccountHeader oldDelegate) =>
      minHeight != oldDelegate.minHeight ||
      maxHeight != oldDelegate.maxHeight ||
      onExpand != oldDelegate.onExpand;
}
