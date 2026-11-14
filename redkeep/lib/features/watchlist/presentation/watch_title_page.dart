import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/domain/ai_provider.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/dating_profile.dart';
import '../domain/recommender/feature_space.dart';
import '../domain/watch_title.dart';
import '../domain/recommender/deck.dart';
import 'dating_widgets.dart';
import 'watch_list_sheet.dart';
import 'watch_seasons.dart';
import 'watch_widgets.dart';

/// A film or show's own page, reached by its address.
class WatchTitlePage extends StatelessWidget {
  const WatchTitlePage({super.key, required this.watchKey});
  final WatchKey watchKey;

  @override
  Widget build(BuildContext context) => WatchProfileView(watchKey: watchKey);
}

/// A film or show as a dating profile: photos between prompts, facts and
/// flags, then the reader's own status, rating, note, lists and episodes.
///
/// Expanded from a Discover card it has one way out, the chevron, and its
/// nope, watched and like decide that card.
class WatchProfileView extends ConsumerWidget {
  const WatchProfileView({
    super.key,
    required this.watchKey,
    this.onClose,
    this.onDecide,
    this.card,
  });
  final WatchKey watchKey;

  /// The Discover card it grew from, whose match and tags it shows.
  final DeckCard? card;

  /// Shown as a chevron in place of the back button.
  final VoidCallback? onClose;
  final void Function(SwipeChoice choice)? onDecide;

  bool get deciding => onDecide != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final catalog = ref.watch(catalogTitleProvider(watchKey));
    final saved = ref.watch(watchTitleProvider(watchKey.id)).value;
    // Without fresh details, what was saved is enough to act on.
    final title =
        catalog.value ?? (saved == null ? null : catalogFromWatchTitle(saved));
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(
        context,
        // The name sits under the first photo, not up here.
        title: '',
        leading: onClose == null
            ? null
            : IconButton(
                tooltip: 'Close profile',
                onPressed: onClose,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              ),
        actions: [
          if (title != null &&
              saved?.matchState != null &&
              ref.watch(aiCapabilitiesProvider).contains(AiCapability.chat))
            IconButton(
              tooltip: 'Chat',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => context.push(watchChatLocation(watchKey)),
            ),
          if (title != null)
            TextButton.icon(
              onPressed: () => showWatchListSheet(context, title),
              icon: Icon(
                saved?.status != null
                    ? Icons.bookmark
                    : Icons.bookmark_add_outlined,
                color: WatchBrand.rose,
              ),
              label: Text(saved?.status?.label ?? 'Add'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: title == null
            ? catalog.hasError
                  ? WatchMessage(
                      title: 'This title could not open',
                      body: catalog.error.toString(),
                      action: TextButton(
                        onPressed: () =>
                            ref.invalidate(catalogTitleProvider(watchKey)),
                        child: const Text('Try again'),
                      ),
                    )
                  : const WatchLoading()
            : Stack(
                children: [
                  _Profile(
                    title: title,
                    saved: saved,
                    stale: catalog.hasError,
                    deciding: deciding,
                    card: card,
                  ),
                  if (deciding) ...[
                    // The page fades out under the seals, so they never sit
                    // on top of words.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 128,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                palette.ground.withValues(alpha: 0),
                                palette.ground.withValues(alpha: .92),
                                palette.ground,
                              ],
                              stops: const [0, .55, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: DecisionRow(onDecide: onDecide),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Profile extends ConsumerStatefulWidget {
  const _Profile({
    required this.title,
    required this.saved,
    required this.stale,
    required this.deciding,
    this.card,
  });
  final CatalogTitle title;
  final WatchTitle? saved;
  final bool stale;
  final bool deciding;
  final DeckCard? card;

  @override
  ConsumerState<_Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<_Profile> {
  final _liked = <String>{};

  /// A like on one part of the profile teaches that facet of taste.
  Future<void> _like(String key, String facet, String what) async {
    if (_liked.contains(key)) return;
    setState(() => _liked.add(key));
    final vector = FeatureSpace.vector(widget.title);
    await runWatchAction(
      context,
      () => updateProfile(
        ref.read(watchlistRepositoryProvider),
        (p) => p.likeFacet(vector, facet),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Noted: you like $what'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  Widget? _likePill(String key, String facet, String what) => widget.deciding
      ? _LikePill(
          liked: _liked.contains(key),
          onTap: () => _like(key, facet, what),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final title = widget.title;
    final saved = widget.saved;
    final profile = DatingProfile.of(
      title,
      now: ref.watch(watchClockProvider)(),
    );
    final photos = title.photos;
    final tv = title.media == WatchMedia.tv;
    final body = DiaryTypography.of(context).body
        .copyWith(color: palette.ink, fontSize: 15, height: 1.6);
    final vitals = profile.vitals;
    final lists = ref
        .watch(watchListsProvider)
        .value
        ?.where((l) => l.items.contains(title.key.id))
        .map((l) => l.name)
        .toList();

    Widget photo(int i) {
      final (path, size) = photos[i];
      return _Snapshot(
        index: i,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: i == 0 ? 2 / 3 : 16 / 10,
              child: WatchPoster(
                path: path,
                size: size,
                radius: 2,
                media: title.media,
                semanticLabel: '${title.title}, photo ${i + 1}',
              ),
            ),
            if (_likePill(
                  'photo$i',
                  i == 0 ? 'genre' : 'tone',
                  i == 0 ? 'this poster' : 'this look',
                )
                case final pill?)
              Positioned(right: 10, bottom: 10, child: pill),
          ],
        ),
      );
    }

    final sections = <Widget>[
      _Section(
        icon: Icons.search,
        label: 'Looking for',
        trailing: _likePill('looking', 'tone', 'their vibe'),
        child: Text(
          profile.lookingFor,
          style: body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      _Section(
        icon: Icons.format_quote,
        label: 'About me',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.bio,
              style: body.copyWith(fontStyle: FontStyle.italic),
            ),
            if (title.overview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(title.overview, style: body),
            ],
          ],
        ),
      ),
      _Section(
        icon: Icons.label_outline,
        label: 'More about me',
        child: Column(
          children: [
            _Fact(Icons.theaters_outlined, 'I am', tv ? 'A series' : 'A film'),
            if (vitals.height != null)
              _Fact(Icons.straighten, 'Height', vitals.height!),
            if (vitals.age != null)
              _Fact(
                Icons.cake_outlined,
                'Age',
                vitals.age == 0 ? 'Brand new' : '${vitals.age} years old',
              ),
            if (vitals.rating != null)
              _Fact(Icons.star_outline, 'Rating', vitals.rating!),
            if (vitals.language != null)
              _Fact(Icons.translate, 'Speaks', vitals.language!),
            if (title.director != null)
              _Fact(Icons.family_restroom, 'Raised by', title.director!),
            if (vitals.livesOn != null)
              _Fact(
                Icons.home_outlined,
                'Lives on',
                vitals.livesOn!.join(', '),
              ),
            if (title.detailed && vitals.livesOn == null)
              _Fact(
                Icons.home_outlined,
                'Lives on',
                'Nowhere to stream in ${ref.watch(tmdbRegionProvider)}',
              ),
          ],
        ),
      ),
      if (title.cast.isNotEmpty)
        _Section(
          icon: Icons.people_outline,
          label: 'My friends',
          trailing: _likePill('cast', 'people', 'the cast'),
          child: Text(title.cast.take(5).join(', '), style: body),
        ),
      if (title.keywords.isNotEmpty)
        _Section(
          icon: Icons.interests_outlined,
          label: 'Interests',
          trailing: _likePill('interests', 'tone', 'their interests'),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final k in title.keywords.take(8)) _Tag(label: k)],
          ),
        ),
      if (profile.greenFlags.isNotEmpty || profile.redFlags.isNotEmpty)
        _Section(
          icon: Icons.flag_outlined,
          label: 'Flags',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in profile.greenFlags)
                _Tag(label: f, flag: const Color(0xFF2E7D4F)),
              for (final f in profile.redFlags)
                _Tag(label: f, flag: const Color(0xFFB3261E)),
            ],
          ),
        ),
    ];

    // The match and tags: the card's own when it came from the deck,
    // otherwise from taste once there is enough of it.
    final card = widget.card;
    final taste = ref.watch(watchProfileProvider).value;
    final enjoyment = card != null
        ? (card.showsMatch ? card.enjoyment : null)
        : taste == null || taste.coldStart
        ? null
        : taste.enjoyment(FeatureSpace.vector(title));
    final badges = titleBadges(
      title,
      thisYear: ref.watch(watchClockProvider)().year,
      enjoyment: enjoyment,
      slot: card?.slot,
    );
    final hand = DiaryTypography.of(context).title;
    // Full width, so the name and tags sit on the left, not centred.
    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title.title,
                    style: hand.copyWith(fontSize: 40, height: 1.05),
                  ),
                  if (title.year != null)
                    TextSpan(
                      text: '  ${title.year}',
                      style: DiaryTypography.of(context).body.copyWith(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: palette.muted,
                      ),
                    ),
                ],
              ),
              style: TextStyle(color: palette.ink),
            ),
          ),
          if (card != null) ...[
            const SizedBox(height: 4),
            Text(
              card.reason,
              style: body.copyWith(
                color: palette.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: badges),
          ],
        ],
      ),
    );

    // The first photo, the name and tags, then photos between sections,
    // like a dating profile.
    final profileParts = <Widget>[];
    var s = 0;
    if (photos.isEmpty) profileParts.add(header);
    for (var i = 0; i < photos.length; i++) {
      profileParts.add(photo(i));
      if (i == 0) profileParts.add(header);
      for (var k = 0; k < (i == 0 ? 2 : 1) && s < sections.length; k++) {
        profileParts.add(sections[s++]);
      }
    }
    profileParts.addAll(sections.skip(s));

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 4, 12, widget.deciding ? 120 : 40),
      children: [
        for (final part in profileParts)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: part,
            ),
          ),
        if (widget.stale)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Showing what was saved. TMDB could not be reached.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  icon: Icons.bookmark_outline,
                  label: 'You and ${title.title}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WatchStatusChips(title: title, status: saved?.status),
                      const SizedBox(height: 16),
                      _Rating(title: title, rating: saved?.rating),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lists == null || lists.isEmpty
                                  ? 'In none of your lists'
                                  : 'In ${lists.join(', ')}',
                              style: body.copyWith(
                                color: palette.muted,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showWatchListSheet(context, title),
                            child: const Text('Lists'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Note(
                        key: ValueKey(title.key),
                        title: title,
                        note: saved?.note ?? '',
                      ),
                    ],
                  ),
                ),
                if (tv && title.seasons.isNotEmpty)
                  _Section(
                    icon: Icons.video_library_outlined,
                    label: 'Episodes',
                    child: WatchSeasons(title: title, saved: saved),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Film and show data from TMDB. This product uses the '
                    'TMDB API but is not endorsed or certified by TMDB. '
                    'Profiles are written for fun from that data.',
                    style: body.copyWith(
                      color: palette.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A page of the profile: paper with a stitched margin, like a journal leaf.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.rule, width: .66),
          boxShadow: simple
              ? null
              : [
                  BoxShadow(
                    color: palette.ink.withValues(alpha: .06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: CustomPaint(
          painter: _MarginStitch(palette.accent.withValues(alpha: .35)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 14, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A running stitch down a page's left margin.
class _MarginStitch extends CustomPainter {
  const _MarginStitch(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const x = 15.0;
    final end = size.height - 12;
    for (var y = 12.0; y < end; y += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 5, end)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarginStitch old) => color != old.color;
}

/// A photo print taped into the journal; after the cover, each leans a
/// little left or right.
class _Snapshot extends StatelessWidget {
  const _Snapshot({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final angle = simple || index == 0 ? 0.0 : (index.isOdd ? -.012 : .01);
    final print = DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(palette.paper, Colors.white, .5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: palette.rule, width: .5),
        boxShadow: simple
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .14),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 22),
      child: Transform.rotate(
        angle: angle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            print,
            // Washi tape over the top edge.
            Positioned(
              top: -11,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: index.isOdd ? .05 : -.04,
                    child: Container(
                      width: 92,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          palette.cloth,
                          palette.accent,
                          .22,
                        )!.withValues(alpha: .72),
                        border: Border.symmetric(
                          vertical: BorderSide(
                            color: palette.paper.withValues(alpha: .6),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page with a handwritten heading.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Icon(icon, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: DiaryTypography.of(context).title.copyWith(
                      color: palette.accent,
                      fontSize: 27,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Divider(height: 1, thickness: .66, color: palette.rule),
          ),
          child,
          if (trailing != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }
}

/// A fact set out like a line in a book's contents: label, dotted leader,
/// value. Stacked instead at large text sizes.
class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final narrow = MediaQuery.textScalerOf(context).scale(14) > 21;
    final text = DiaryTypography.of(context).body;
    final labelText = Text(
      label,
      style: text.copyWith(
        color: palette.muted,
        fontSize: 14,
        height: 1.4,
        fontStyle: FontStyle.italic,
      ),
    );
    final valueText = Text(
      value,
      textAlign: narrow ? TextAlign.start : TextAlign.end,
      style: text.copyWith(color: palette.ink, fontSize: 15, height: 1.4),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, valueText],
            )
          : LayoutBuilder(
              // Values sit flush right; the leader fills the gap to them.
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(icon, size: 17, color: palette.muted),
                  const SizedBox(width: 8),
                  labelText,
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                      child: CustomPaint(
                        size: const Size.fromHeight(2),
                        painter: _Leader(palette.rule),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .58),
                    child: valueText,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Leader extends CustomPainter {
  const _Leader(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 1.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, size.height / 2), .9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Leader old) => color != old.color;
}

/// A paper label for an interest, or with a flag for green and red flags.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.flag});
  final String label;
  final Color? flag;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final flag = this.flag;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: flag == null
            ? palette.cloth
            : Color.lerp(palette.paper, flag, .07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: flag?.withValues(alpha: .45) ?? palette.rule,
          width: .8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null) ...[
              Icon(Icons.flag_rounded, size: 15, color: flag),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: DiaryTypography.of(context).body.copyWith(
                  color: flag ?? palette.ink,
                  fontSize: 13.5,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Like one part of a profile: a paper gift tag with an eyelet, a heart and
/// a handwritten "Like". Once liked it is inked in rose and the heart pops.
class _LikePill extends StatefulWidget {
  const _LikePill({required this.liked, required this.onTap});
  final bool liked;
  final VoidCallback onTap;

  @override
  State<_LikePill> createState() => _LikePillState();
}

class _LikePillState extends State<_LikePill>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(_LikePill old) {
    super.didUpdateWidget(old);
    if (widget.liked && !old.liked) {
      if (RenderingPolicyScope.of(context).reducedMotion) {
        _pop.value = 1;
      } else {
        _pop.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final policy = RenderingPolicyScope.of(context);
    final liked = widget.liked;
    final rose = Color.lerp(WatchBrand.rose, palette.ink, .22)!;
    final fill = liked ? rose : palette.paper;
    final ink = liked ? palette.paper : rose;
    final hand = DiaryTypography.of(context).title;
    final tag = CustomPaint(
      painter: _TagPainter(
        fill: fill,
        edge: rose.withValues(alpha: liked ? 1 : .6),
        eyelet: liked ? palette.paper : rose.withValues(alpha: .6),
        shadow: policy.simplerEffects ? null : Colors.black,
      ),
      child: Padding(
        // Room on the left for the notch and eyelet.
        padding: const EdgeInsets.fromLTRB(28, 6, 15, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: TweenSequence([
                TweenSequenceItem(
                  tween: Tween(begin: 1.0, end: 1.45),
                  weight: 40,
                ),
                TweenSequenceItem(
                  tween: Tween(begin: 1.45, end: 1.0),
                  weight: 60,
                ),
              ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut)),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: ink,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              liked ? 'Liked' : 'Like',
              style: hand.copyWith(color: ink, fontSize: 23, height: 1.15),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !liked,
      selected: liked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: liked ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: liked ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? .93 : 1,
          duration: policy.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 110),
          child: Transform.rotate(
            // Hung slightly askew, like a real tag.
            angle: policy.simplerEffects ? 0 : -.035,
            child: tag,
          ),
        ),
      ),
    );
  }
}

/// A gift tag: notched left end, rounded right, an eyelet punched near the
/// point.
class _TagPainter extends CustomPainter {
  const _TagPainter({
    required this.fill,
    required this.edge,
    required this.eyelet,
    required this.shadow,
  });
  final Color fill, edge, eyelet;
  final Color? shadow;

  Path _outline(Size size) {
    final h = size.height, w = size.width;
    const notch = 14.0, r = 7.0;
    return Path()
      ..moveTo(notch, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(notch, h)
      ..lineTo(0, h / 2)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _outline(size);
    final shadow = this.shadow;
    if (shadow != null) {
      canvas.drawShadow(outline, shadow.withValues(alpha: .4), 2, false);
    }
    canvas.drawPath(outline, Paint()..color = fill);
    canvas.drawPath(
      outline,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final hole = Offset(15, size.height / 2);
    canvas.drawCircle(
      hole,
      3.2,
      Paint()
        ..color = eyelet
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TagPainter old) =>
      fill != old.fill ||
      edge != old.edge ||
      eyelet != old.eyelet ||
      shadow != old.shadow;
}

/// Ten stars; tapping the current rating clears it.
class _Rating extends ConsumerWidget {
  const _Rating({required this.title, required this.rating});
  final CatalogTitle title;
  final int? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    // Ten stars on one line, shrinking to fit a narrow page.
    return LayoutBuilder(
      builder: (context, box) {
        final star = ((box.maxWidth - 84) / 10 - 4).clamp(16.0, 26.0);
        return Row(
          children: [
            Flexible(
              child: Wrap(
                children: [
                  for (var i = 1; i <= 10; i++)
                    Semantics(
                      button: true,
                      selected: rating == i,
                      label: '$i out of 10',
                      excludeSemantics: true,
                      child: InkResponse(
                        radius: 18,
                        onTap: () => runWatchAction(
                          context,
                          () => ref
                              .read(watchlistRepositoryProvider)
                              .setRating(title, rating == i ? null : i),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            (rating ?? 0) >= i
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: star,
                            color: (rating ?? 0) >= i
                                ? palette.accent
                                : palette.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rating == null ? 'Not rated' : '$rating/10',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}

/// Saved a moment after typing stops, and when leaving the page.
class _Note extends ConsumerStatefulWidget {
  const _Note({super.key, required this.title, required this.note});
  final CatalogTitle title;
  final String note;

  @override
  ConsumerState<_Note> createState() => _NoteState();
}

class _NoteState extends ConsumerState<_Note> {
  late final _controller = TextEditingController(text: widget.note);
  late final _repository = ref.read(watchlistRepositoryProvider);
  late String _saved = widget.note;
  Timer? _timer;

  @override
  void didUpdateWidget(_Note old) {
    super.didUpdateWidget(old);
    // Another device's note arrives only while nothing is unsaved here.
    if (widget.note != _saved && _controller.text == _saved) {
      _controller.text = _saved = widget.note;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    _timer?.cancel();
    final text = _controller.text;
    if (text == _saved) return;
    _saved = text;
    try {
      await _repository.setNote(widget.title, text);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(watchErrorText(error))));
      }
    }
  }

  @override
  void dispose() {
    unawaited(_save());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    minLines: 2,
    maxLines: 8,
    maxLength: 4000,
    textCapitalization: TextCapitalization.sentences,
    onChanged: (_) => _schedule(),
    decoration: const InputDecoration(
      hintText: 'Who recommended it, what you thought…',
      border: OutlineInputBorder(),
      counterText: '',
    ),
  );
}
