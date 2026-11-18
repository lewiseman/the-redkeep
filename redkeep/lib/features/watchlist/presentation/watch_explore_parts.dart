import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watchlist_providers.dart';
import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import '../domain/watch_title.dart';
import 'watch_list_sheet.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// The search bead that flies from the wall's dock to the search page.
const searchBeadTag = 'watch-search-bead';

/// Clears the search dock at the foot of the page.
const searchDockClearance = 104.0;

/// Pins a title to the wall as Planned, with a way to take it back down.
Future<void> pinToWall(
  BuildContext context,
  WidgetRef ref,
  CatalogTitle title, {
  bool aboveDock = false,
}) async {
  final repository = ref.read(watchlistRepositoryProvider);
  HapticFeedback.mediumImpact();
  final messenger = ScaffoldMessenger.of(context);
  final pinned = await runWatchAction(
    context,
    () => repository.setStatus(title, WatchStatus.planned),
  );
  if (pinned == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: aboveDock
            ? const EdgeInsets.fromLTRB(16, 0, 16, searchDockClearance - 8)
            : null,
        content: Text('Pinned ${title.title} to your wall'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository
              .removeTitle(pinned.id)
              .then<void>(
                (_) {},
                onError: (Object error) => messenger.showSnackBar(
                  SnackBar(content: Text(watchErrorText(error))),
                ),
              ),
        ),
      ),
    );
}

/// A round glass bead that sinks under the finger.
class GlassBead extends StatelessWidget {
  const GlassBead({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 48,
    this.fill = .92,
    this.tint,
    this.iconSize = 24,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  /// How much of the tint fills the glass: 1 a solid swatch.
  final double fill;
  final Color? tint;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final tint = this.tint ?? cushion.tint;
    final body = Color.lerp(cushion.paper, tint, fill)!;
    final ink = ThemeData.estimateBrightnessForColor(body) == Brightness.dark
        ? Colors.white
        : cushion.ink;
    final onTap = this.onTap;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Springy(
            depth: .12,
            child: CustomPaint(
              size: Size.square(size),
              painter: _BeadPainter(cushion, tint, fill),
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, color: ink, size: iconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeadPainter extends CustomPainter {
  const _BeadPainter(this.colors, this.tint, this.fill);
  final CushionColors colors;
  final Color tint;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    ),
    colors: colors,
    tint: tint,
    fill: fill,
    lift: .8,
  );

  @override
  bool shouldRepaint(_BeadPainter old) =>
      old.colors != colors || old.tint != tint || old.fill != fill;
}

/// The handwritten heading of a stretch of the explore page.
class ExploreHeading extends StatelessWidget {
  const ExploreHeading(this.text, {super.key, this.note});

  final String text;

  /// A small aside after the heading, in print.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final note = this.note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text),
              if (note != null)
                TextSpan(
                  text: '   $note',
                  style: TextStyle(
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    fontSize: 12.5,
                    color: palette.muted,
                    letterSpacing: .2,
                  ),
                ),
            ],
          ),
          style: wallHand(context, size: 30),
        ),
      ),
    );
  }
}

/// A mood's colour of paper, ink and icon.
@immutable
class MoodStyle {
  const MoodStyle(this.hue, this.emoji);
  final Color hue;

  /// Printed on the ticket's stub.
  final String emoji;

  static MoodStyle of(Mood mood) => switch (mood.id) {
    'cozy' => const MoodStyle(Color(0xffd69a52), '🍿'),
    'scare' => const MoodStyle(Color(0xff7a5a8e), '👻'),
    'cry' => const MoodStyle(Color(0xff5b86b6), '🥲'),
    'laugh' => const MoodStyle(Color(0xffd9b23c), '😂'),
    'mind' => const MoodStyle(Color(0xff4b9a92), '🤯'),
    'rush' => const MoodStyle(Color(0xffc9583f), '🔥'),
    'short' => const MoodStyle(Color(0xff73a05a), '⏱️'),
    'classic' => const MoodStyle(Color(0xff9c7a55), '🎞️'),
    _ => const MoodStyle(Color(0xff8a8a7a), '🎬'),
  };
}

/// A mood as a cinema ticket: punched notches, a perforated stub with the
/// mood's emoji stamped on it, and the mood in handwriting.
class MoodTicket extends StatelessWidget {
  const MoodTicket({super.key, required this.mood, required this.onTap});

  final Mood mood;
  final VoidCallback onTap;

  static const stub = 54.0;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final style = MoodStyle.of(mood);
    final seed = wallSeed(mood.id);
    final paper = Color.lerp(
      cushion.paper,
      style.hue,
      cushion.dark ? .34 : .26,
    )!;
    final mark = Color.lerp(style.hue, cushion.ink, cushion.dark ? 0 : .35)!;
    return Semantics(
      button: true,
      label: mood.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Transform.rotate(
          angle: ((seed % 7) - 3) / 140,
          child: Springy(
            depth: .05,
            child: CustomPaint(
              painter: _TicketPainter(paper: paper, ink: mark, colors: cushion),
              child: Row(
                children: [
                  SizedBox(
                    width: stub,
                    // Stamped on the stub, a little askew, clear of the
                    // punched notch.
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Center(
                        child: Transform.rotate(
                          angle: ((seed >> 3) % 9 - 4) / 40,
                          child: Text(
                            style.emoji,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(fontSize: 24, height: 1.1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
                      child: Text(
                        mood.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: wallHand(context, size: 22, color: cushion.ink),
                      ),
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

class _TicketPainter extends CustomPainter {
  const _TicketPainter({
    required this.paper,
    required this.ink,
    required this.colors,
  });

  final Color paper, ink;
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const notch = 8.0;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)),
      );
    final y = size.height / 2;
    final bites = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: notch))
      // Punched where the stub tears off.
      ..addOval(
        Rect.fromCircle(center: const Offset(MoodTicket.stub, 0), radius: 5),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(MoodTicket.stub, size.height),
          radius: 5,
        ),
      );
    final shape = Path.combine(PathOperation.difference, body, bites);
    if (!colors.simple) {
      canvas.drawPath(
        shape.shift(const Offset(0, 3)),
        Paint()..color = colors.shadow.withValues(alpha: colors.dark ? .4 : .1),
      );
    }
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(paper, Colors.white, colors.dark ? .05 : .3)!,
            paper,
          ],
        ).createShader(Offset.zero & size),
    );
    // The perforation.
    final dots = Paint()..color = ink.withValues(alpha: .45);
    for (var d = 9.0; d < size.height - 8; d += 6) {
      canvas.drawCircle(Offset(MoodTicket.stub, d), 1, dots);
    }
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = ink.withValues(alpha: .3),
    );
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.paper != paper || old.ink != ink || old.colors != colors;
}

/// A photo lying loose on the table, waiting to be pinned up. It lies at
/// a casual angle with a glass push-pin by its corner; pinning it slaps a
/// strip of washi tape across its top and straightens it.
class LoosePolaroid extends StatefulWidget {
  const LoosePolaroid({
    super.key,
    required this.title,
    required this.pinned,
    required this.onTap,
    required this.onPin,
    this.onLongPress,
    required this.width,
    this.caption = 20,
    this.lean = 1,
  });

  final CatalogTitle title;

  /// The photo's width, to place the pin at the poster's corner.
  final double width;

  /// On the wall already.
  final bool pinned;
  final VoidCallback onTap;

  /// Pins it, or when pinned already, opens its status and lists.
  final VoidCallback onPin;
  final VoidCallback? onLongPress;
  final double caption;

  /// How far it may lean, where 1 is the usual casual tilt.
  final double lean;

  @override
  State<LoosePolaroid> createState() => _LoosePolaroidState();
}

class _LoosePolaroidState extends State<LoosePolaroid>
    with SingleTickerProviderStateMixin {
  /// Where the poster ends, down the photo.
  static double _poster(double width) => 7 + (width - 14) * 1.5;

  late final _slap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: widget.pinned ? 1 : 0,
  );

  @override
  void didUpdateWidget(LoosePolaroid old) {
    super.didUpdateWidget(old);
    if (old.pinned == widget.pinned) return;
    if (!RenderingPolicyScope.of(context).animate) {
      _slap.value = widget.pinned ? 1 : 0;
    } else if (widget.pinned) {
      _slap.forward(from: 0);
    } else {
      _slap.reverse();
    }
  }

  @override
  void dispose() {
    _slap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final title = widget.title;
    final seed = wallSeed(title.key.id);
    final loose = ((seed % 97) / 96 - .5) * .13 * widget.lean;
    final kind = title.media == WatchMedia.tv ? 'Series' : 'Film';
    final frame = Color.lerp(
      palette.paper,
      Colors.white,
      cushion.dark ? 0 : .5,
    )!;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: frame,
        borderRadius: BorderRadius.circular(3),
        border: cushion.simple ? Border.all(color: palette.rule) : null,
        boxShadow: cushion.simple
            ? null
            : [
                BoxShadow(
                  color: cushion.shadow.withValues(
                    alpha: cushion.dark ? .45 : .18,
                  ),
                  blurRadius: 12,
                  offset: const Offset(3, 8),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: WatchPoster(
                path: title.posterPath,
                media: title.media,
                radius: 2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: wallHand(context, size: widget.caption),
            ),
            const SizedBox(height: 2),
            Text(
              title.year == null ? kind : '${title.year} · $kind',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: [
        title.title,
        ?title.year?.toString(),
        kind,
        if (widget.pinned) 'on your wall',
      ].join(', '),
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      customSemanticsActions: {
        CustomSemanticsAction(
          label: widget.pinned ? 'Status and lists' : 'Pin to your wall',
        ): widget.onPin,
      },
      child: AnimatedBuilder(
        animation: _slap,
        builder: (context, child) {
          final s = _slap.value;
          // Straightens as the tape goes on.
          return Transform.rotate(
            angle: loose * (1 - .7 * Curves.easeOut.transform(s)),
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      widget.onLongPress!();
                    },
              child: Springy(depth: .03, child: card),
            ),
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _slap,
                    builder: (context, child) {
                      final s = _slap.value;
                      if (s == 0) return const SizedBox(height: 20);
                      final scale =
                          1 + .9 * (1 - Curves.easeOutBack.transform(s));
                      return Opacity(
                        opacity: math.min(1, s * 2.5),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: WashiTape(seed: seed, colors: cushion),
                  ),
                ),
              ),
            ),
            // At the poster's lower corner, half over the frame.
            Positioned(
              right: -10,
              top: _poster(widget.width) - 24,
              child: GlassBead(
                size: 44,
                iconSize: 20,
                fill: widget.pinned ? .92 : .14,
                icon: widget.pinned
                    ? Icons.check_rounded
                    : Icons.push_pin_outlined,
                label: widget.pinned ? 'On your wall' : 'Pin to your wall',
                onTap: widget.onPin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the reader has saved, by title id, kept live for pin marks.
final savedTitleIdsProvider = Provider.autoDispose<Set<String>>(
  (ref) => {
    for (final t in ref.watch(watchTitlesProvider).value ?? const []) t.id,
  },
);

/// A loose polaroid wired to the wall: tap opens it, the pin pins it (or,
/// once pinned, opens its status and lists).
class ExplorePolaroid extends ConsumerWidget {
  const ExplorePolaroid({
    super.key,
    required this.title,
    required this.onOpen,
    this.caption = 20,
    this.lean = 1,
    this.aboveDock = false,
  });

  final CatalogTitle title;
  final VoidCallback onOpen;

  /// The page has the search dock at its foot to keep the snack clear of.
  final bool aboveDock;
  final double caption;
  final double lean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(savedTitleIdsProvider).contains(title.key.id);
    return LayoutBuilder(
      builder: (context, box) => LoosePolaroid(
        width: box.maxWidth,
        title: title,
        pinned: pinned,
        caption: caption,
        lean: lean,
        onTap: onOpen,
        onLongPress: () => showWatchListSheet(context, title),
        onPin: pinned
            ? () => showWatchListSheet(context, title)
            : () => pinToWall(context, ref, title, aboveDock: aboveDock),
      ),
    );
  }
}

/// The page's ground behind the status bar, thinning smoothly below it, so
/// what scrolls up slips away rather than running under the clock.
class StatusFade extends StatelessWidget {
  const StatusFade({super.key});

  static const reach = 34.0;

  @override
  Widget build(BuildContext context) {
    final ground = MorePalette.of(context).ground;
    final top = MediaQuery.paddingOf(context).top;
    final height = top + reach;
    final solid = height == 0 ? 0.0 : top * .7 / height;
    final stops = [for (var i = 0; i <= 16; i++) i / 16];
    double alpha(double y) {
      if (y <= solid) return 1;
      final u = ((y - solid) / (1 - solid)).clamp(0.0, 1.0);
      return 1 - u * u * u * (u * (u * 6 - 15) + 10);
    }

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: stops,
              colors: [
                for (final y in stops) ground.withValues(alpha: alpha(y)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
