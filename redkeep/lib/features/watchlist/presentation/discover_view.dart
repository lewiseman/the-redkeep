import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/recommender/deck.dart';
import '../domain/watch_title.dart';
import 'dating_widgets.dart';
import 'match_overlay.dart';
import 'night_planner.dart';
import 'watch_chat_page.dart';
import 'watch_widgets.dart';

/// A card asking to grow into its full profile.
class ProfileRequest {
  const ProfileRequest({
    required this.key,
    required this.from,
    required this.photoPath,
    required this.photoSize,
    required this.decide,
    this.card,
  });
  final WatchKey key;

  /// The card itself, for its match and tags on the profile.
  final DeckCard? card;

  /// Where the card is on screen, in global coordinates.
  final Rect from;

  /// The photo the card was showing, to fade from.
  final String? photoPath;
  final String photoSize;

  /// Decides the card from the profile.
  final void Function(SwipeChoice choice) decide;
}

/// One card at a time: left for nope, right to like, up if already watched.
class DiscoverView extends ConsumerWidget {
  const DiscoverView({super.key, this.onOpenProfile});

  /// Expands a card into its profile. Without it, the profile opens as a page.
  final void Function(ProfileRequest request)? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverProvider);
    final controller = ref.read(discoverProvider.notifier);
    ref.listen(discoverProvider.select((s) => s.match), (_, match) {
      if (match != null) celebrateMatch(context, ref, match);
    });
    return switch (state.phase) {
      DiscoverPhase.loading => const WatchLoading(),
      DiscoverPhase.filling => WatchMessage(
        title: 'Finding films and shows',
        body: '${(state.progress * 100).round()}% of the first deck',
      ),
      DiscoverPhase.needsKey => WatchMessage(
        title: 'Discover needs TMDB',
        body: const WatchlistSetupException().toString(),
      ),
      DiscoverPhase.failed => WatchMessage(
        title: 'Discover could not start',
        body: state.error ?? '',
        action: TextButton(
          onPressed: controller.retry,
          child: const Text('Try again'),
        ),
      ),
      DiscoverPhase.empty => WatchMessage(
        title: 'You’ve seen everyone',
        body: 'Loosen your dealbreakers to meet more films and shows.',
        action: TextButton(
          onPressed: () => context.push(watchPreferencesLocation),
          child: const Text('Dealbreakers'),
        ),
      ),
      DiscoverPhase.ready => _Deck(state: state, onOpenProfile: onOpenProfile),
    };
  }
}

class _Deck extends ConsumerWidget {
  const _Deck({required this.state, this.onOpenProfile});
  final DiscoverState state;
  final void Function(ProfileRequest request)? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(discoverProvider.notifier);
    Future<void> swipe(SwipeChoice choice) async {
      await runWatchAction(context, () => controller.swipe(choice));
      if (choice == SwipeChoice.watched && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Marked as watched in your Library.')),
          );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Column(
            children: [
              Expanded(
                child: state.cards.isEmpty
                    ? const WatchLoading()
                    : SwipeDeck(
                        key: ValueKey(state.cards.first.title.key),
                        cards: state.cards,
                        onSwipe: swipe,
                        onOpenProfile: onOpenProfile,
                        onRewind: state.canUndo
                            ? () => runWatchAction(context, controller.undo)
                            : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top card follows a drag: right likes, left passes, up marks it
/// watched. With reduced motion the card's buttons decide, in place.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.cards,
    required this.onSwipe,
    this.onRewind,
    this.onOpenProfile,
  });
  final List<DeckCard> cards;
  final Future<void> Function(SwipeChoice choice) onSwipe;
  final VoidCallback? onRewind;
  final void Function(ProfileRequest request)? onOpenProfile;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero, _to = Offset.zero;
  bool _busy = false;
  Size _size = Size.zero;

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  SwipeChoice? _choiceFor(Offset offset) =>
      offset.dy < -_size.height * .18 && offset.dy.abs() > offset.dx.abs()
      ? SwipeChoice.watched
      : offset.dx > _size.width * .28
      ? SwipeChoice.like
      : offset.dx < -_size.width * .28
      ? SwipeChoice.nope
      : null;

  Offset _exit(SwipeChoice choice, Offset from) => switch (choice) {
    SwipeChoice.like => Offset(_size.width * 1.5, from.dy),
    SwipeChoice.nope => Offset(-_size.width * 1.5, from.dy),
    SwipeChoice.watched => Offset(from.dx, -_size.height * 1.5),
  };

  /// Flies the card out (or back to centre), then decides.
  Future<void> _settle(SwipeChoice? choice, {required bool animate}) async {
    if (_busy) return;
    _busy = true;
    if (animate) {
      _from = _drag;
      _to = choice == null ? Offset.zero : _exit(choice, _drag);
      await _fly.forward(from: 0);
      if (!mounted) return;
    }
    if (choice != null) await widget.onSwipe(choice);
    if (mounted) {
      setState(() {
        _drag = Offset.zero;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final animate = policy.animate;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final top = widget.cards.first;
        final next = widget.cards.length > 1 ? widget.cards[1] : null;
        return AnimatedBuilder(
          animation: _fly,
          builder: (context, _) {
            final offset = _busy && animate
                ? Offset.lerp(_from, _to, Curves.easeOut.transform(_fly.value))!
                : _drag;
            final card = TinderCard(
              key: ValueKey(top.title.key),
              card: top,
              drag: offset,
              size: _size,
              onDecide: (choice) => _settle(choice, animate: animate),
              onRewind: widget.onRewind,
              onOpenProfile: widget.onOpenProfile,
              upNext: next,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                if (next != null && !policy.simplerEffects)
                  Transform.scale(
                    scale: .95,
                    child: ExcludeSemantics(
                      child: TinderCard(
                        key: ValueKey(next.title.key),
                        card: next,
                        background: true,
                      ),
                    ),
                  ),
                if (!animate)
                  card
                else
                  GestureDetector(
                    onPanUpdate: _busy
                        ? null
                        : (d) => setState(() => _drag += d.delta),
                    onPanEnd: _busy
                        ? null
                        : (_) => _settle(_choiceFor(_drag), animate: true),
                    child: Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: policy.simplerEffects
                            ? 0
                            : offset.dx / max(1, _size.width) * pi / 14,
                        child: card,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A full-bleed dating card. Tap the left or right of the photo to flip
/// through photos, and the arrow for the whole profile.
class TinderCard extends ConsumerStatefulWidget {
  const TinderCard({
    super.key,
    required this.card,
    this.drag = Offset.zero,
    this.size = Size.zero,
    this.onDecide,
    this.onRewind,
    this.onOpenProfile,
    this.upNext,
    this.background = false,
  });

  final DeckCard card;
  final Offset drag;
  final Size size;
  final void Function(SwipeChoice choice)? onDecide;
  final VoidCallback? onRewind;
  final void Function(ProfileRequest request)? onOpenProfile;

  /// The card after this one, whose first photos load ahead of time.
  final DeckCard? upNext;

  /// The card waiting underneath: nothing fetched, no controls.
  final bool background;

  @override
  ConsumerState<TinderCard> createState() => _TinderCardState();
}

class _TinderCardState extends ConsumerState<TinderCard> {
  int _photo = 0;
  (String, String)? _shown;

  /// The photo shown survives leaving Discover and coming back.
  String get _photoId => 'discover-photo-${widget.card.title.key}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.background) return;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _photoId);
    if (saved is int) _photo = saved;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    // Details bring more photos and a fuller profile. The top card asks for
    // the next card's too, so it arrives ready.
    final title =
        ref.watch(catalogTitleProvider(card.title.key)).value ?? card.title;
    final photos = title.photos;
    final index = photos.isEmpty ? 0 : _photo.clamp(0, photos.length - 1);
    final photo = _shown = photos.isEmpty ? null : photos[index];
    final upNext = widget.upNext;
    if (!widget.background) {
      final nextTitle = upNext == null
          ? null
          : ref.watch(catalogTitleProvider(upNext.title.key)).value ??
                upNext.title;
      final ahead = photosToPreload(
        current: photos,
        index: index,
        upNext: nextTitle?.photos ?? const [],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) preloadWatchPhotos(context, ref, ahead);
      });
    }
    final drag = widget.drag;
    final width = max(1.0, widget.size.width);
    final height = max(1.0, widget.size.height);
    void flip(int delta) {
      final next = (index + delta).clamp(0, max(0, photos.length - 1)).toInt();
      if (next == index) return;
      setState(() => _photo = next);
      PageStorage.maybeOf(
        context,
      )?.writeState(context, next, identifier: _photoId);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          WatchPoster(
            path: photo?.$1,
            size: photo?.$2 ?? 'w780',
            radius: 0,
            media: title.media,
            semanticLabel:
                '${title.title}, photo ${index + 1} of ${max(1, photos.length)}',
          ),
          if (!widget.background && photos.length > 1)
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Previous photo',
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => flip(-1),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Next photo',
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => flip(1),
                    ),
                  ),
                ),
              ],
            ),
          if (photos.length > 1)
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == index ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!widget.background && widget.onRewind != null)
            Positioned(
              top: 18,
              right: 10,
              child: IconButton(
                tooltip: 'Rewind',
                onPressed: widget.onRewind,
                style: IconButton.styleFrom(backgroundColor: Colors.black26),
                icon: const Icon(Icons.replay, color: Colors.white),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  stops: [0, .35, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (title.year != null)
                                TextSpan(
                                  text: '  ${title.year}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (!widget.background)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: MatchProfileButton(
                            percent: card.showsMatch ? card.matchPercent : null,
                            onPressed: _openProfile,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  if (!widget.background) ...[
                    const SizedBox(height: 14),
                    DecisionRow(onDecide: widget.onDecide),
                  ],
                ],
              ),
            ),
          ),
          for (final (choice, opacity) in [
            (SwipeChoice.like, drag.dx / (width * .28)),
            (SwipeChoice.nope, -drag.dx / (width * .28)),
            (SwipeChoice.watched, -drag.dy / (height * .18)),
          ])
            SwipeStamp(choice: choice, opacity: opacity.clamp(0, 1).toDouble()),
        ],
      ),
    );
  }

  /// The whole profile, grown from this card, with its own nope, watched
  /// and like.
  void _openProfile() {
    final open = widget.onOpenProfile;
    final box = context.findRenderObject() as RenderBox?;
    final decide = widget.onDecide;
    if (open == null || box == null || !box.hasSize || decide == null) {
      context.push(watchTitleLocation(widget.card.title.key));
      return;
    }
    open(
      ProfileRequest(
        key: widget.card.title.key,
        from: box.localToGlobal(Offset.zero) & box.size,
        photoPath: _shown?.$1,
        photoSize: _shown?.$2 ?? 'w780',
        decide: decide,
        card: widget.card,
      ),
    );
  }
}

/// Shows the match screen and acts on what the reader chose.
Future<void> celebrateMatch(
  BuildContext context,
  WidgetRef ref,
  DeckCard card,
) async {
  final controller = ref.read(discoverProvider.notifier);
  final repository = ref.read(watchlistRepositoryProvider);
  // "Your type": a title they loved, or the last other one they liked.
  final titles = await repository.titles();
  final type =
      titles.where((t) => t.outcome == NightOutcome.loved).firstOrNull ??
      titles
          .where((t) => t.swipe == SwipeChoice.like && t.key != card.title.key)
          .firstOrNull;
  final yourType = type == null
      ? null
      : await repository.cachedTitle(type.key) ?? catalogFromWatchTitle(type);
  if (!context.mounted) return;
  final title =
      ref.read(catalogTitleProvider(card.title.key)).value ?? card.title;
  final choice = await showWatchMatch(
    context,
    ref,
    title: title,
    yourType: yourType,
  );
  controller.dismissMatch();
  if (!context.mounted) return;
  await actOnMatch(context, ref, title, choice);
}

/// Opens the chat with the message, plans a night, or keeps swiping.
Future<void> actOnMatch(
  BuildContext context,
  WidgetRef ref,
  CatalogTitle title,
  MatchChoice? choice,
) async {
  switch (choice) {
    case MatchSendMessage(:final text):
      await context.push(
        watchChatLocation(title.key),
        extra: WatchChatOpening(text),
      );
    case MatchPlanNight():
      final saved = await ref
          .read(watchlistRepositoryProvider)
          .title(title.key.id);
      if (saved == null || !context.mounted) return;
      await planNightFlow(context, ref, saved);
    case MatchKeepSwiping() || null:
      break;
  }
}
