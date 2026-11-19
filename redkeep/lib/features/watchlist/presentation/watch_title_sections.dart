import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../sync/presentation/sync_material.dart';
import '../domain/catalog_title.dart';
import '../domain/watch_title.dart';
import 'watch_list_sheet.dart';
import 'watch_wall.dart';
import 'watch_widgets.dart';

/// A section's name, written by hand and centred on the page with a stroke
/// of the pen beneath; no card around it.
class TitleHeading extends StatelessWidget {
  const TitleHeading(this.label, {super.key, this.light = false});
  final String label;

  /// For headings set on something dark.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final colour = light ? const Color(0xfff3ead6) : palette.ink;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 30, 6, 12),
        child: Column(
          children: [
            Text(label, style: wallHand(context, size: 32, color: colour)),
            ExcludeSemantics(
              child: CustomPaint(
                size: const Size(84, 8),
                painter: _Stroke(light ? colour : palette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stroke extends CustomPainter {
  const _Stroke(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height * .7);
    path.quadraticBezierTo(
      size.width * .45,
      size.height * .1,
      size.width,
      size.height * .45,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(_Stroke old) => old.colour != colour;
}

/// The story, set straight on the page beside a large opening quote, with
/// its keywords stuck below as little strips of labelled washi tape.
class AboutNote extends StatelessWidget {
  const AboutNote({super.key, required this.overview, required this.keywords});
  final String overview;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final body = DiaryTypography.of(context).body
        .copyWith(color: palette.ink, fontSize: 16.5, height: 1.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overview.isNotEmpty)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -4,
                  top: -30,
                  child: ExcludeSemantics(
                    child: Text(
                      '“',
                      style: body.copyWith(
                        fontSize: 96,
                        height: 1,
                        color: palette.accent.withValues(alpha: .22),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 4),
                  child: Text(overview, style: body),
                ),
              ],
            ),
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 10,
              children: [
                for (final word in keywords)
                  _Washi(word: word, colors: cushion),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Washi extends StatelessWidget {
  const _Washi({required this.word, required this.colors});
  final String word;
  final CushionColors colors;

  @override
  Widget build(BuildContext context) {
    final seed = word.codeUnits.fold(5, (h, c) => (h * 31 + c) & 0xffff);
    final tape = HSLColor.fromAHSL(
      .78,
      (seed % 360).toDouble(),
      colors.dark ? .3 : .42,
      colors.dark ? .38 : .8,
    ).toColor();
    return Transform.rotate(
      angle: ((seed >> 3) % 9 - 4) / 100,
      child: ClipPath(
        clipper: const _TornEnds(),
        child: ColoredBox(
          color: tape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Text(
              word,
              style: TextStyle(
                color: colors.ink.withValues(alpha: .85),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tape torn at both ends, in little zig-zags.
class _TornEnds extends CustomClipper<Path> {
  const _TornEnds();

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(3, 0);
    path.lineTo(size.width - 3, 0);
    for (var y = 0.0; y < size.height; y += 4) {
      path.lineTo(size.width - ((y ~/ 4).isEven ? 0 : 3), y + 2);
    }
    path.lineTo(size.width - 3, size.height);
    path.lineTo(3, size.height);
    for (var y = size.height; y > 0; y -= 4) {
      path.lineTo((y ~/ 4).isEven ? 0 : 3, y - 2);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TornEnds old) => false;
}

/// Something you work with, like ticking episodes, sits on a stitched
/// cushion, as the stamp rack and dock do.
class TitleCushion extends StatelessWidget {
  const TitleCushion({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CushionPainter(colors: CushionColors.of(context), radius: 26),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: child,
    ),
  );
}

/// Who made it, as a film ends: a dark screen with each job set small and
/// spaced, and its names beneath, all centred.
class CreditsRoll extends StatelessWidget {
  const CreditsRoll({super.key, required this.title, required this.credits});
  final String title;

  /// Each job and its names, already joined.
  final List<(String, String)> credits;

  static const _screen = Color(0xff16140f);
  static const _cream = Color(0xfff3ead6);

  @override
  Widget build(BuildContext context) {
    final type = DiaryTypography.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _screen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: wallHand(context, size: 30, color: _cream),
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 1,
                color: _cream.withValues(alpha: .35),
              ),
            ),
            for (final (job, names) in credits) ...[
              const SizedBox(height: 22),
              Text(
                job,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x99f3ead6),
                  fontSize: 11.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                names,
                textAlign: TextAlign.center,
                style: type.body.copyWith(
                  color: _cream,
                  fontSize: 16.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The facts on a cinema ticket: an "Admit one" stub with the rating, a
/// perforated line to tear along, and the rest printed in two columns.
class DetailsTicket extends StatelessWidget {
  const DetailsTicket({
    super.key,
    required this.facts,
    this.rating,
    this.votes,
  });

  final List<(String, String)> facts;

  /// Out of ten, with how many voted; the stub shows it when there is one.
  final double? rating;
  final String? votes;

  static const _stub = 74.0;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final type = DiaryTypography.of(context);
    final rating = this.rating;
    final ink = palette.ink;
    return CustomPaint(
      painter: _TicketPainter(
        paper: Color.lerp(palette.paper, Colors.white, cushion.dark ? 0 : .55)!,
        edge: palette.rule,
        perforation: palette.muted.withValues(alpha: .5),
        shadow: cushion.simple ? null : cushion.shadow,
        tear: _stub,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _stub,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    'ADMIT ONE',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (rating != null) ...[
                    Icon(Icons.star_rounded, color: palette.accent, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: type.body.copyWith(
                        color: ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/10',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    if (votes != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          votes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: LayoutBuilder(
              builder: (context, box) {
                final wide =
                    box.maxWidth > 300 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                final cell = wide ? (box.maxWidth - 20) / 2 : box.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    for (final (label, value) in facts)
                      SizedBox(
                        width: cell,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10.5,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value,
                              style: type.body.copyWith(
                                color: ink,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter({
    required this.paper,
    required this.edge,
    required this.perforation,
    required this.shadow,
    required this.tear,
  });

  final Color paper, edge, perforation;
  final Color? shadow;

  /// How far down the perforation runs.
  final double tear;

  Path _shape(Size size) {
    const notch = 11.0;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );
    final bites = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, tear), radius: notch))
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, tear), radius: notch),
      );
    return Path.combine(PathOperation.difference, body, bites);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size);
    final shadow = this.shadow;
    if (shadow != null) {
      canvas.drawPath(
        shape.shift(const Offset(0, 5)),
        Paint()
          ..color = shadow.withValues(alpha: .08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawPath(shape, Paint()..color = paper);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = edge,
    );
    final dots = Paint()..color = perforation;
    for (var x = 20.0; x < size.width - 18; x += 9) {
      canvas.drawCircle(Offset(x, tear), 1.6, dots);
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.paper != paper ||
      old.edge != edge ||
      old.perforation != perforation ||
      old.shadow != shadow ||
      old.tear != tear;
}

/// Where to see it: services as glass chips under Stream, Rent and Buy,
/// all centred.
class WatchHere extends StatelessWidget {
  const WatchHere({super.key, required this.groups});

  final List<(String, List<String>)> groups;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    // Centred under the heading, the full width of the page.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, names) in groups) ...[
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 10.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in names)
                  CustomPaint(
                    painter: _ChipGlass(cushion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: cushion.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ChipGlass extends CustomPainter {
  const _ChipGlass(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) => paintGlass(
    canvas,
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ),
    colors: colors,
    tint: colors.tint,
    fill: .14,
    lift: .7,
  );

  @override
  bool shouldRepaint(_ChipGlass old) => old.colors != colors;
}

/// TMDB's suggestions as a little wall of their own: taped polaroids in a
/// row, each flying into its own page when opened.
class MoreLikeThisWall extends StatelessWidget {
  const MoreLikeThisWall({super.key, required this.titles});
  final List<CatalogTitle> titles;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    const width = 136.0;
    // Poster, frame, two handwritten lines and a line of year, with room
    // for the tilt and drop.
    final height = width * 1.5 + 34 + scale * (21 * 1.05 * 2 + 16) + 34;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: titles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final title = titles[i];
          return SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topCenter,
              child: WallPolaroid(
                key: ValueKey(title.key),
                title: WatchTitle(
                  id: title.key.id,
                  key: title.key,
                  title: title.title,
                  posterPath: title.posterPath,
                  year: title.year,
                  revision: 0,
                  createdAt: DateTime(2000),
                  updatedAt: DateTime(2000),
                ),
                onTap: () => context.push(watchTitleLocation(title.key)),
                onLongPress: () => showWatchListSheet(context, title),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Faces in glass rings, each named beneath; no card around them.
class CastRing extends StatelessWidget {
  const CastRing({super.key, required this.cast});
  final List<Credit> cast;

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final cushion = CushionColors.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    const face = 84.0;
    final width = 96 * scale.clamp(1.0, 1.4);
    final height = face + 12 + scale * (13 * 1.25 * 2 + 12 * 1.3 * 2) + 4;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final person = cast[i];
          return Semantics(
            label: [person.name, ?person.role].join(', as '),
            excludeSemantics: true,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  CustomPaint(
                    foregroundPainter: _Ring(cushion),
                    child: SizedBox.square(
                      dimension: face,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(child: _Face(path: person.profilePath)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    person.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (person.role != null)
                    Text(
                      person.role!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A person's TMDB portrait, or a quiet icon without one.
class _Face extends StatelessWidget {
  const _Face({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) => WatchPoster(
    path: path,
    size: 'w185',
    radius: 0,
    icon: Icons.person_outline,
  );
}

/// The ring of glass round a face.
class _Ring extends CustomPainter {
  const _Ring(this.colors);
  final CushionColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: colors.dark ? .35 : .95),
            colors.tint.withValues(alpha: .45),
            Colors.white.withValues(alpha: colors.dark ? .2 : .8),
            colors.tint.withValues(alpha: .3),
            Colors.white.withValues(alpha: colors.dark ? .35 : .95),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
    canvas.drawCircle(
      centre,
      r - .5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = colors.edge,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.colors != colors;
}
