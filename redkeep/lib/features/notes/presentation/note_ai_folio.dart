import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../domain/note_colors.dart';
import '../domain/note_document.dart';
import 'note_ai_palette.dart';
import 'note_markdown_preview.dart';
import 'note_scene.dart';

/// A living miniature of the note the AI desk works on: its own artwork and
/// paper, where proposals are written in before they are kept.
class NoteFolio extends ConsumerWidget {
  const NoteFolio({
    super.key,
    required this.details,
    required this.child,
    this.status,
    this.inking = false,
    this.imageKey,
  });
  final NoteDetails details;
  final Widget child;

  /// A short word pinned to the folio, e.g. "Your note" or "Proposal".
  final String? status;

  /// The Maester is writing: an ink sweep passes over the page.
  final bool inking;

  /// Shows a different backdrop, e.g. a generated background preview.
  final String? imageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final note = NoteColors.fromBackground(
      theme.colorScheme,
      details.background,
    );
    final key =
        imageKey ?? details.background['image'] ?? details.background['asset'];
    final image = key is String
        ? ref.watch(noteBackgroundImageProvider(key)).value
        : null;
    final desk = theme.colorScheme.primary;
    final noteDark =
        ThemeData.estimateBrightnessForColor(note.background) ==
        Brightness.dark;
    final backdrop = Color.lerp(
      note.background,
      noteDark ? Colors.white : Colors.black,
      theme.brightness == Brightness.dark ? .1 : .08,
    )!;
    // Highlights inside the page must read on the note's own paper.
    final ink = noteAiLegible(desk, note.background, ratio: 3.2);
    final paper = Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: ink,
          onSurface: note.foreground,
          onSurfaceVariant: noteAiLegible(note.secondary, note.background),
          surface: note.background,
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: note.foreground,
          displayColor: note.foreground,
        ),
        iconTheme: theme.iconTheme.copyWith(color: note.foreground),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: ink,
          selectionColor: ink.withValues(alpha: .3),
          selectionHandleColor: ink,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: note.foreground),
        child: child,
      ),
    );
    return Semantics(
      container: true,
      label: status,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(color: backdrop),
          child: Stack(
            children: [
              Positioned.fill(
                child: image != null
                    ? Image(image: image, fit: BoxFit.cover)
                    : CustomPaint(painter: _DeskPainter(ink: desk)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 40, 14, 18),
                child: Stack(
                  children: [
                    // A second sheet peeks out beneath, like a stack of pages.
                    Positioned.fill(
                      child: Transform.translate(
                        offset: const Offset(6, 7),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              Colors.black.withValues(alpha: .12),
                              note.background,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: note.background,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .14),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: paper,
                    ),
                    if (inking)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _InkSweep(ink: ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (status != null)
                PositionedDirectional(
                  top: 10,
                  start: 14,
                  child: ExcludeSemantics(
                    child: _StatusPill(text: status!, ink: desk, pulse: inking),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.ink,
    required this.pulse,
  });
  final String text;
  final Color ink;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pulse ? Icons.edit_rounded : Icons.auto_awesome_rounded,
            size: 13,
            color: ink,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The note's title, tags and a few lines of its body as written on paper.
class NoteFolioPage extends StatelessWidget {
  const NoteFolioPage({
    super.key,
    required this.title,
    required this.body,
    this.tags = const [],
    this.newTags = const {},
    this.proposedTitle,
    this.bodyLines = 5,
    this.footer,
  });
  final String title, body;
  final List<String> tags;

  /// Tags that the proposal adds, drawn in fresh ink.
  final Set<String> newTags;

  /// A title that would replace [title]; the old one is struck through.
  final String? proposedTitle;
  final int? bodyLines;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.primary;
    final shownTitle = title.trim().isEmpty ? 'Untitled note' : title.trim();
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (proposedTitle != null) ...[
          Text(
            shownTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          NoteFreshInk(child: Text(proposedTitle!, style: titleStyle)),
        ] else
          Text(shownTitle, style: titleStyle),
        if (tags.isNotEmpty || newTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags) _FolioTag(tag, fresh: false),
              for (final tag in newTags)
                if (!tags.contains(tag)) _FolioTag(tag, fresh: true),
            ],
          ),
        ],
        if (body.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          NoteFolioText(body.trim(), lines: bodyLines),
        ],
        if (footer != null) ...[const SizedBox(height: 14), footer!],
        if (body.trim().isEmpty && footer == null) ...[
          const SizedBox(height: 14),
          Text(
            'An empty page, waiting for words.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: ink.withValues(alpha: .8),
            ),
          ),
        ],
      ],
    );
  }
}

class _FolioTag extends StatelessWidget {
  const _FolioTag(this.tag, {required this.fresh});
  final String tag;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.primary;
    final fg = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fresh ? ink.withValues(alpha: .14) : fg.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fresh ? ink.withValues(alpha: .6) : fg.withValues(alpha: .14),
        ),
      ),
      child: Text(
        fresh ? '+ $tag' : tag,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fresh ? ink : fg,
          fontWeight: fresh ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Note text exactly as the note shows it: formatted, never raw Markdown.
/// With [lines], it is cut to about that many lines and fades out.
class NoteFolioText extends StatefulWidget {
  const NoteFolioText(this.markdown, {super.key, this.lines});
  final String markdown;
  final int? lines;

  @override
  State<NoteFolioText> createState() => _NoteFolioTextState();
}

class _NoteFolioTextState extends State<NoteFolioText> {
  bool _cut = false;

  @override
  Widget build(BuildContext context) {
    final text = NoteMarkdownPreview(text: widget.markdown, selectable: false);
    final lines = widget.lines;
    if (lines == null) return text;
    final height = MediaQuery.textScalerOf(context).scale(16) * 1.6 * lines;
    final clipped = ClipRect(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) {
            final cut = n.metrics.maxScrollExtent > 0;
            if (cut != _cut) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _cut = cut);
              });
            }
            return true;
          },
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: text,
          ),
        ),
      ),
    );
    if (!_cut) return clipped;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [.6, 1],
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect),
      child: clipped,
    );
  }
}

/// The note split into its paragraphs; tap them to choose which ones a
/// writing tool works on. Nothing chosen means the whole note.
class NoteFolioPassages extends StatelessWidget {
  const NoteFolioPassages({
    super.key,
    required this.body,
    required this.selected,
    required this.onChanged,
  });
  final String body;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final blocks = noteBlocks(body);
    final ink = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Semantics(
            button: true,
            selected: selected.contains(i),
            label: 'Paragraph ${i + 1}',
            child: InkWell(
              key: ValueKey('notes-ai-passage-$i'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(
                selected.contains(i)
                    ? ({...selected}..remove(i))
                    : {...selected, i},
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 8, 4),
                decoration: BoxDecoration(
                  color: selected.contains(i)
                      ? ink.withValues(alpha: .1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: BorderDirectional(
                    start: BorderSide(
                      color: selected.contains(i)
                          ? ink
                          : ink.withValues(alpha: .12),
                      width: 3,
                    ),
                  ),
                ),
                child: IgnorePointer(
                  child: NoteFolioText(
                    body.substring(blocks[i].start, blocks[i].end),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The paragraphs (blank-line separated blocks) of a note body, as ranges
/// into it, so a chosen passage maps back to the exact Markdown source.
List<TextRange> noteBlocks(String body) {
  final blocks = <TextRange>[];
  var start = 0;
  void add(int end) {
    final text = body.substring(start, end);
    if (text.trim().isEmpty) return;
    final lead = text.length - text.trimLeft().length;
    final trail = text.length - text.trimRight().length;
    blocks.add(TextRange(start: start + lead, end: end - trail));
  }

  for (final gap in RegExp(r'\n[ \t]*\n').allMatches(body)) {
    add(gap.start);
    start = gap.end;
  }
  add(body.length);
  return blocks;
}

/// Words the Maester would add: marked by an ink rule in the margin.
class NoteFreshInk extends StatelessWidget {
  const NoteFreshInk({super.key, required this.child, this.label});
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 10),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .08),
        borderRadius: const BorderRadiusDirectional.horizontal(
          end: Radius.circular(10),
        ).resolve(Directionality.of(context)),
        border: BorderDirectional(start: BorderSide(color: ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 13, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }
}

/// Drag the quill across the page to wipe between the original passage and
/// the proposal. Screen readers adjust it like a slider.
class NoteFolioCompare extends StatelessWidget {
  const NoteFolioCompare({
    super.key,
    required this.before,
    required this.after,
    required this.split,
    required this.onChanged,
  });
  final String before, after;

  /// One shows the whole proposal, zero the whole original.
  final double split;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.primary;
    final labels = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    );
    return Semantics(
      slider: true,
      label: 'Compare original and proposal',
      value: split > .5 ? 'Showing proposal' : 'Showing original',
      increasedValue: 'Showing proposal',
      decreasedValue: 'Showing original',
      onIncrease: () => onChanged(1),
      onDecrease: () => onChanged(0),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            void drag(double dx) => onChanged((dx / width).clamp(0.0, 1.0));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => drag(d.localPosition.dx),
              onTapUp: (d) => drag(d.localPosition.dx),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'PROPOSAL',
                        style: labels?.copyWith(
                          color: ink.withValues(alpha: split > .05 ? 1 : .4),
                        ),
                      ),
                      Text(
                        'ORIGINAL',
                        style: labels?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: split < .95 ? 1 : .5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRect(
                        clipper: _SplitClipper(split, keepStart: false),
                        child: Opacity(
                          opacity: .75,
                          child: SizedBox(
                            width: double.infinity,
                            child: NoteFolioText(before),
                          ),
                        ),
                      ),
                      ClipRect(
                        clipper: _SplitClipper(split, keepStart: true),
                        child: SizedBox(
                          width: double.infinity,
                          child: NoteFolioText(after),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        bottom: -4,
                        left: split * width - 1,
                        width: 2,
                        child: ColoredBox(color: ink),
                      ),
                      Positioned(
                        top: 0,
                        left: (split * width - 18).clamp(-18, width - 18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.unfold_more_rounded,
                            size: 20,
                            color:
                                ThemeData.estimateBrightnessForColor(ink) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  const _SplitClipper(this.split, {required this.keepStart});
  final double split;
  final bool keepStart;

  @override
  Rect getClip(Size size) {
    final x = size.width * split;
    return keepStart
        ? Rect.fromLTRB(-8, -8, x, size.height + 8)
        : Rect.fromLTRB(x, -8, size.width + 8, size.height + 8);
  }

  @override
  bool shouldReclip(_SplitClipper old) =>
      old.split != split || old.keepStart != keepStart;
}

/// A band of wet ink sweeping down the page while the Maester writes. Still
/// with reduced motion or simpler effects.
class _InkSweep extends StatefulWidget {
  const _InkSweep({required this.ink});
  final Color ink;

  @override
  State<_InkSweep> createState() => _InkSweepState();
}

class _InkSweepState extends State<_InkSweep>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !(MediaQuery.disableAnimationsOf(context) ||
            RenderingPolicyScope.of(context).simplerEffects) &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = .45;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _SweepPainter(_motion, widget.ink),
      child: const SizedBox.expand(),
    ),
  );
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.motion, this.ink) : super(repaint: motion);
  final Animation<double> motion;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(motion.value);
    const band = 90.0;
    final y = -band + t * (size.height + band * 2);
    final rect = Rect.fromLTWH(0, y - band, size.width, band * 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ink.withValues(alpha: 0),
            ink.withValues(alpha: .16),
            ink.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(16, y),
      Offset(size.width - 16, y),
      Paint()
        ..color = ink.withValues(alpha: .4)
        ..strokeWidth = 1.2,
    );
    // A four-point star rides the leading edge, twinkling.
    final r = 6 + 2 * math.sin(motion.value * math.pi * 6);
    final c = Offset(size.width - 26, y);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + 1, c.dy - 1, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + 1, c.dy + 1, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - 1, c.dy + 1, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - 1, c.dy - 1, c.dx, c.dy - r)
        ..close(),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.ink != ink;
}

/// When a note has no artwork, the folio sits on a quiet desk: ruled
/// guide lines and a soft pool of the tool's ink in one corner.
class _DeskPainter extends CustomPainter {
  const _DeskPainter({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .08),
      size.shortestSide * .7,
      Paint()
        ..shader =
            RadialGradient(
              colors: [ink.withValues(alpha: .22), ink.withValues(alpha: 0)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * .92, size.height * .08),
                radius: size.shortestSide * .7,
              ),
            ),
    );
    final line = Paint()
      ..color = ink.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(_DeskPainter old) => old.ink != ink;
}
