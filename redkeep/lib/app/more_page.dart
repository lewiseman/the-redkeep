import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import '../core/presentation/rendering_policy.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/local_artwork.dart';
import '../features/more/application/maestar_status.dart';
import '../features/more/presentation/more_index_entry.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/sync/application/sync_providers.dart';
import '../features/sync/presentation/backup_panel.dart';
import '../features/sync/presentation/sync_card.dart';
import '../features/sync/presentation/sync_material.dart';
import '../features/sync/presentation/tome_material.dart';
import 'main_tabs.dart';
import 'writing_shell.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});
  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _stackKey = GlobalKey();
  final _cardKey = GlobalKey();

  /// The journal opening: 0 is the card on the page, 1 the book lying open
  /// across the screen.
  late final _book = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    reverseDuration: const Duration(milliseconds: 720),
  );

  /// Whether the book is open, or opening. The animation may still be
  /// closing it after this turns false.
  bool _open = false;

  /// Where the card sat when the book left it, in this page's coordinates.
  Rect? _from;
  MainTabScope? _tabScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabScope = MainTabScope.maybeOf(context)
      ?..gate = _allowsTabSwipe
      ..back = _back;
  }

  @override
  void dispose() {
    if (_tabScope?.gate == _allowsTabSwipe) _tabScope!.gate = null;
    if (_tabScope?.back == _back) _tabScope!.back = null;
    _book.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _allowsTabSwipe(bool forward) => !_open && _book.isDismissed;

  bool _back() {
    if (!_open) return false;
    _close();
    return true;
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

  Rect? _cardRect() {
    final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    final page = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (card == null || page == null || !card.hasSize || !card.attached) {
      return null;
    }
    return card.localToGlobal(Offset.zero, ancestor: page) & card.size;
  }

  void _openBook() {
    if (_open) return;
    setState(() {
      _open = true;
      _from = _cardRect();
    });
    const BottomNavbarVisibilityNotification(hidden: true).dispatch(context);
    if (RenderingPolicyScope.of(context).animate) {
      _book.forward();
    } else {
      _book.value = 1;
    }
  }

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _from = _cardRect() ?? _from;
    });
    const BottomNavbarVisibilityNotification(hidden: false).dispatch(context);
    if (RenderingPolicyScope.of(context).animate) {
      _book.reverse();
    } else {
      _book.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maestar = ref.watch(maestarStatusProvider);
    final enabled = ref.watch(syncEnabledProvider);
    final ready = enabled && ref.watch(backupEngineProvider).hasValue;
    final signedIn = ready && ref.watch(syncAccountProvider) != null;
    if (_open && !signedIn) {
      // Signing out (or a reset) leaves nothing to show inside.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    final page = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MoreSurface.contentWidth),
          child: LayoutBuilder(
            builder: (context, constraints) => CustomScrollView(
              key: const PageStorageKey('more-scroll'),
              controller: _scroll,
              slivers: [
                if (ready)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _AccountHeader(
                      minHeight: SyncAccountCard.compactHeight(context) + 24,
                      maxHeight:
                          SyncAccountCard.expandedHeight(
                            context,
                            isSignedIn: signedIn,
                          ) +
                          44,
                      onExpand: _expand,
                      onOpen: _openBook,
                      cardKey: _cardKey,
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
    );

    return PopScope(
      // Inside the tab pager, the pager asks [_back] first.
      canPop: _tabScope != null || !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabScope == null) _close();
      },
      child: Scaffold(
        body: MoreSurface(
          child: Stack(
            key: _stackKey,
            fit: StackFit.expand,
            children: [
              // The page under the book is hidden from touch and from
              // assistive tech while the book is out.
              ListenableBuilder(
                listenable: _book,
                builder: (context, child) {
                  final covered = _open || !_book.isDismissed;
                  return IgnorePointer(
                    ignoring: covered,
                    child: ExcludeSemantics(
                      excluding: _book.isCompleted,
                      child: TickerMode(
                        enabled: !_book.isCompleted,
                        child: child!,
                      ),
                    ),
                  );
                },
                child: page,
              ),
              ListenableBuilder(
                listenable: _book,
                builder: (context, panel) {
                  if (!_open && _book.isDismissed) {
                    return const SizedBox.shrink();
                  }
                  return _OpenTome(
                    progress: _book.value,
                    from: _from,
                    interactive: _open,
                    panel: panel!,
                  );
                },
                child: signedIn
                    ? BackupPanel(onClose: _close)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The journal leaving the page: the card grows to fill the screen as a
/// closed tome, then its cover swings open on the spine to show the backup
/// page inside. Played backwards, the cover shuts and the tome settles back
/// into the card.
class _OpenTome extends ConsumerWidget {
  const _OpenTome({
    required this.progress,
    required this.from,
    required this.interactive,
    required this.panel,
  });

  final double progress;
  final Rect? from;
  final bool interactive;
  final Widget panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = RenderingPolicyScope.of(context);
    final tome = TomePalette.of(context);
    final palette = MorePalette.of(context);
    // The shell pads the body for its bar; the page needs only the system's.
    final padding = MediaQuery.viewPaddingOf(context);
    final name = ref.watch(onboardingControllerProvider).name?.trim();
    final title = name == null || name.isEmpty ? 'Your journal' : name;
    final email = ref.watch(syncAccountProvider)?.email;

    final t = progress;
    final grow = Curves.easeInOutCubic.transform((t / .55).clamp(0.0, 1.0));
    final swing = Curves.easeInOutCubic.transform(
      ((t - .42) / .5).clamp(0.0, 1.0),
    );
    final reveal = Curves.easeOut.transform(((t - .72) / .28).clamp(0.0, 1.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = Offset.zero & constraints.biggest;
        final start = from ?? full.deflate(24);
        final rect = Rect.lerp(start, full, grow)!;
        final thickness = lerpDouble(TomeBinding.thickness, 0, grow)!;
        final cover = Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width - thickness,
          rect.height - thickness,
        );
        final pageRect = Rect.fromLTRB(
          10,
          padding.top + 8,
          full.right - 10,
          full.bottom - padding.bottom - 10,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: IgnorePointer(
            ignoring: !interactive,
            child: Stack(
              children: [
                // The inside of the board, and the first page on it. The
                // page stays laid out under the cover so it is ready to show.
                Positioned.fromRect(
                  rect: cover,
                  child: Offstage(
                    offstage: swing <= 0,
                    child: CustomPaint(
                      painter: TomePainter(
                        palette: tome,
                        shadow: false,
                        thickness: 0,
                        bare: true,
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: pageRect,
                  child: Offstage(
                    offstage: swing <= 0,
                    child: ClipRect(
                      clipper: _Within(cover.shift(-pageRect.topLeft)),
                      child: _Page(
                        shade: 1 - swing,
                        child: Opacity(
                          opacity: reveal,
                          child: ExcludeSemantics(
                            excluding: reveal < 1,
                            child: RepaintBoundary(child: panel),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (swing < 1)
                  Positioned.fromRect(
                    rect: rect,
                    child: _Cover(
                      swing: swing,
                      grow: grow,
                      flat: policy.simplerEffects,
                      thickness: thickness,
                      title: title,
                      email: email,
                      initials: SyncAccountCard.initialsOf(title),
                      ink: palette.ink,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Within extends CustomClipper<Rect> {
  const _Within(this.rect);
  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_Within oldClipper) => rect != oldClipper.rect;
}

/// The first page: the app's paper, darkened into the binding on the left,
/// with the leaves behind it showing at the fore-edge.
class _Page extends StatelessWidget {
  const _Page({required this.shade, required this.child});

  /// How much of the swinging cover's shadow still falls on the page.
  final double shade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The page is its own world: vellum, sepia ink and a book face.
    final parchment = Parchment.of(context);
    return Theme(
      data: parchment.theme(Theme.of(context)),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: 'serif', color: parchment.ink),
        child: TomeLeaf(
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: .2 + shade * .4),
                          Colors.black.withValues(alpha: shade * .3),
                          Colors.black.withValues(alpha: 0),
                        ],
                        stops: const [0, .045, .14],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The front cover, swinging open about its spine.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.swing,
    required this.grow,
    required this.flat,
    required this.thickness,
    required this.title,
    required this.email,
    required this.initials,
    required this.ink,
  });

  final double swing;
  final double grow;
  final bool flat;
  final double thickness;
  final String title;
  final String? email;
  final String initials;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final tome = TomePalette.of(context);
    final medallion = lerpDouble(84, 128, grow)!;
    final face = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: TomePainter(
            palette: tome,
            shadow: !flat && grow < 1,
            thickness: thickness,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            TomeBinding.spine + 16,
            lerpDouble(24, 0, grow)!,
            thickness + 34,
            thickness,
          ),
          child: Align(
            alignment: Alignment(0, lerpDouble(-1, -.15, grow)!),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TomeMedallion(size: medallion, initials: initials),
                  SizedBox(height: lerpDouble(16, 28, grow)),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: tome.stamped(
                      fontSize: lerpDouble(22, 30, grow)!,
                      letterSpacing: lerpDouble(1.2, 2.4, grow)!,
                      color: Color.lerp(tome.onLeather, tome.gilt, .45),
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tome.onLeatherMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // The cover darkens as it turns away from the light.
        if (swing > 0)
          ColoredBox(color: Colors.black.withValues(alpha: swing * .55)),
      ],
    );
    if (flat) return Opacity(opacity: 1 - swing, child: face);
    // Past a right angle the cover is edge-on and gone.
    final angle = swing * math.pi / 2;
    return Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0011)
        ..rotateY(angle),
      child: RepaintBoundary(child: face),
    );
  }
}

class _AccountHeader extends SliverPersistentHeaderDelegate {
  const _AccountHeader({
    required this.minHeight,
    required this.maxHeight,
    required this.onExpand,
    required this.onOpen,
    required this.cardKey,
  });

  final double minHeight, maxHeight;
  final VoidCallback onExpand;
  final VoidCallback onOpen;
  final GlobalKey cardKey;

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
            20,
            lerpDouble(28, 12, progress)!,
            20,
            lerpDouble(16, 12, progress)!,
          ),
          child: SyncAccountCard(
            key: cardKey,
            collapseProgress: progress,
            onExpand: onExpand,
            onOpen: onOpen,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_AccountHeader oldDelegate) =>
      minHeight != oldDelegate.minHeight ||
      maxHeight != oldDelegate.maxHeight ||
      onExpand != oldDelegate.onExpand ||
      onOpen != oldDelegate.onOpen ||
      cardKey != oldDelegate.cardKey;
}
