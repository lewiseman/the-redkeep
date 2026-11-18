import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'watch_list_sheet.dart';
import 'watch_seasons.dart';
import 'watch_widgets.dart';

/// A film or show's own page, reached by its address: what it is, then the
/// reader's status, lists and episodes.
class WatchTitlePage extends ConsumerWidget {
  const WatchTitlePage({super.key, required this.watchKey});
  final WatchKey watchKey;

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
        // The name sits beside the poster, not up here.
        title: '',
        actions: [
          if (title != null)
            TextButton.icon(
              onPressed: () => showWatchListSheet(context, title),
              icon: Icon(
                saved?.status != null
                    ? Icons.bookmark
                    : Icons.bookmark_add_outlined,
                color: palette.accent,
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
            : _Details(title: title, saved: saved, stale: catalog.hasError),
      ),
    );
  }
}

/// "2h 7m", or "45m" for less than an hour.
String watchRuntime(int minutes) {
  final hours = minutes ~/ 60, rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.title,
    required this.saved,
    required this.stale,
  });
  final CatalogTitle title;
  final WatchTitle? saved;
  final bool stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MorePalette.of(context);
    final saved = this.saved;
    final tv = title.media == WatchMedia.tv;
    final type = DiaryTypography.of(context);
    final body = type.body.copyWith(
      color: palette.ink,
      fontSize: 15,
      height: 1.6,
    );
    final lists = ref
        .watch(watchListsProvider)
        .value
        ?.where((l) => l.items.contains(title.key.id))
        .map((l) => l.name)
        .toList();
    final runtime = title.runtime;
    final seasons = title.seasons.where((s) => s.number > 0).length;

    final name = Semantics(
      header: true,
      child: Text(
        title.title,
        style: type.title.copyWith(
          color: palette.ink,
          fontSize: 36,
          height: 1.05,
        ),
      ),
    );
    final summary = [
      ?title.year?.toString(),
      tv ? 'Series' : 'Film',
      if (runtime != null) tv ? '${runtime}m episodes' : watchRuntime(runtime),
    ].join(' · ');
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        name,
        const SizedBox(height: 6),
        Text(summary, style: body.copyWith(color: palette.muted, fontSize: 14)),
        if (title.tagline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            title.tagline,
            style: body.copyWith(
              color: palette.muted,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
    final poster = SizedBox(
      width: 120,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: WatchPoster(
          path: title.posterPath,
          radius: 6,
          media: title.media,
          semanticLabel: '${title.title} poster',
        ),
      ),
    );
    // Side by side, unless large text leaves the name too little room.
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 21;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [poster, const SizedBox(height: 16), heading],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                poster,
                const SizedBox(width: 16),
                Expanded(child: heading),
              ],
            ),
    );

    final facts = <Widget>[
      if (title.voteCount > 0)
        _Fact(
          Icons.star_outline,
          'TMDB rating',
          '${title.voteAverage.toStringAsFixed(1)}/10',
        ),
      if (tv && seasons > 0)
        _Fact(Icons.video_library_outlined, 'Seasons', '$seasons'),
      if (title.genres.isNotEmpty)
        _Fact(
          Icons.category_outlined,
          'Genre',
          title.genres.take(3).join(', '),
        ),
      if (title.language != null)
        _Fact(Icons.translate, 'Language', title.language!.toUpperCase()),
      if (title.director != null)
        _Fact(
          Icons.person_outline,
          tv ? 'Created by' : 'Directed by',
          title.director!,
        ),
      if (title.cast.isNotEmpty)
        _Fact(Icons.people_outline, 'Starring', title.cast.take(4).join(', ')),
      if (title.providers.isNotEmpty)
        _Fact(
          Icons.live_tv_outlined,
          'Streaming on',
          title.providers.join(', '),
        ),
    ];

    final parts = <Widget>[
      header,
      if (title.overview.isNotEmpty)
        _Section(
          icon: Icons.notes,
          label: 'About',
          child: Text(title.overview, style: body),
        ),
      if (facts.isNotEmpty)
        _Section(
          icon: Icons.info_outline,
          label: 'Details',
          child: Column(children: facts),
        ),
      if (stale)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Showing what was saved. TMDB could not be reached.',
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
      _Section(
        icon: Icons.bookmark_outline,
        label: 'Yours',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WatchStatusChips(title: title, status: saved?.status),
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
          'Film and show data from TMDB. This product uses the TMDB API but '
          'is not endorsed or certified by TMDB.',
          style: body.copyWith(color: palette.muted, fontSize: 11, height: 1.4),
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
      children: [
        for (final part in parts)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: part,
            ),
          ),
      ],
    );
  }
}

/// A section of the page: paper with a stitched margin, like a journal leaf.
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

/// A page with a handwritten heading.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
  });
  final IconData icon;
  final String label;
  final Widget child;

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
