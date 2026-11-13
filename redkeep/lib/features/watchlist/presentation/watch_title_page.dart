import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/domain/ai_provider.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/discover_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/dating_profile.dart';
import '../domain/recommender/feature_space.dart';
import '../domain/watch_title.dart';
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
  });
  final WatchKey watchKey;

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
    final heading = title == null
        ? ''
        : title.year == null
        ? title.title
        : '${title.title}, ${title.year}';
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(
        context,
        title: heading,
        leading: onClose == null
            ? null
            : IconButton(
                tooltip: 'Close profile',
                onPressed: onClose,
                icon: const Icon(CupertinoIcons.chevron_down),
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
                  ),
                  if (deciding)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: DecisionRow(onDecide: onDecide),
                    ),
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
  });
  final CatalogTitle title;
  final WatchTitle? saved;
  final bool stale;
  final bool deciding;

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
    final body = TextStyle(color: palette.ink, fontSize: 15, height: 1.5);
    final vitals = profile.vitals;
    final lists = ref
        .watch(watchListsProvider)
        .value
        ?.where((l) => l.items.contains(title.key.id))
        .map((l) => l.name)
        .toList();

    Widget photo(int i) {
      final (path, size) = photos[i];
      return _Card(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: i == 0 ? 2 / 3 : 16 / 10,
              child: WatchPoster(
                path: path,
                size: size,
                radius: 16,
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
          style: body.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
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
            children: [
              for (final k in title.keywords.take(8))
                Chip(label: Text(k), visualDensity: VisualDensity.compact),
            ],
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
              for (final f in profile.greenFlags) _flag(f, Colors.green),
              for (final f in profile.redFlags) _flag(f, Colors.red),
            ],
          ),
        ),
    ];

    // Photos between sections, like a dating profile.
    final profileParts = <Widget>[];
    var s = 0;
    for (var i = 0; i < photos.length; i++) {
      profileParts.add(photo(i));
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
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 14,
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
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _flag(String label, Color color) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(Icons.flag, size: 16, color: color),
    label: Text(label),
    side: BorderSide(color: color.withValues(alpha: .5)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: MorePalette.of(context).paper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

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
                Icon(icon, size: 16, color: palette.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
          if (trailing != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final narrow = MediaQuery.textScalerOf(context).scale(14) > 21;
    final labelText = Text(
      label,
      style: TextStyle(color: palette.muted, fontSize: 13),
    );
    final valueText = Text(
      value,
      style: TextStyle(color: palette.ink, fontSize: 15),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, valueText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: palette.ink),
                const SizedBox(width: 10),
                SizedBox(width: 84, child: labelText),
                Expanded(child: valueText),
              ],
            ),
    );
  }
}

/// Like one part of a profile.
class _LikePill extends StatelessWidget {
  const _LikePill({required this.liked, required this.onTap});
  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: liked ? null : onTap,
    style: FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: WatchBrand.rose,
      disabledBackgroundColor: Colors.white,
      disabledForegroundColor: WatchBrand.rose,
      visualDensity: VisualDensity.compact,
    ),
    icon: Icon(liked ? Icons.favorite : Icons.favorite_border, size: 18),
    label: Text(liked ? 'Liked' : 'Like'),
  );
}

/// Ten stars; tapping the current rating clears it.
class _Rating extends ConsumerWidget {
  const _Rating({required this.title, required this.rating});
  final CatalogTitle title;
  final int? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
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
                        size: 26,
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
