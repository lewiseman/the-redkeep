import 'package:flutter/material.dart';

import 'note_ai_palette.dart';

export 'note_ai_palette.dart';

/// One visual language from the note toolbox through to the reviewed result.
enum NoteAiTool {
  search(
    'AI note search',
    'Ask a question and get an answer from your notes.',
    'AI note search',
    'Ask about your notes',
    Color(0xFF527C9C),
  ),
  thoughtSearch(
    'Flow AI search',
    'Ask a question and get an answer from your thoughts.',
    'Flow AI search',
    'Ask about your thoughts',
    Color(0xFF6A7FA8),
  ),
  template(
    'Starting template',
    'Choose a template for your note.',
    'Start a note',
    'Choose a template',
    Color(0xFFB5683F),
  ),
  writing(
    'Writing help',
    'Choose how you want to improve your note.',
    'Improve writing',
    'Organize or edit',
    Color(0xFF75619B),
  ),
  metadata(
    'Title ideas',
    'Pick a title that says what this note is about.',
    'Name it',
    'Title ideas',
    Color(0xFFB5683F),
  ),
  image(
    'Ask about an image',
    'Choose a photo. Ask or read what is in it.',
    'Explore a photo',
    'See details, read text',
    Color(0xFF527C9C),
  ),
  scan(
    'Scan a page',
    'Take a photo. Check the words. Add them.',
    'Read a page',
    'Photo to written words',
    Color(0xFF527C9C),
  ),
  background(
    'Generate a background',
    'Choose a preset or describe a background.',
    'Add a backdrop',
    'Generate a background',
    Color(0xFF9C6887),
  ),
  presentation(
    'Website',
    'Turn this note into an interactive page. Your text stays as it is.',
    'Style this note',
    'Make it a website',
    Color(0xFF75619B),
  );

  const NoteAiTool(
    this.title,
    this.description,
    this.label,
    this.caption,
    this.tint,
  );
  final String title, description, label, caption;
  final Color tint;

  /// This tool's ink on the current desk paper, always legible.
  Color ink(BuildContext context) => NoteAiPalette.of(context, tint: tint).ink;

  /// The words used when a kept result lands back on the note.
  String get landed => switch (this) {
    template => 'Template added to your note',
    writing => 'Your note was rewritten',
    metadata => 'Title updated',
    image => 'Added to the end of your note',
    scan => 'Page added to the end of your note',
    background => 'New background set',
    presentation => 'Website ready',
    search || thoughtSearch => 'Done',
  };
}

/// The desk paper: the app paper quietly tinted by the open note.
Color noteAiPaper(BuildContext context) => NoteAiPalette.of(context).paper;

/// Illustrated choices retain their meaning without depending on color alone.
class NoteAiArt extends StatelessWidget {
  const NoteAiArt({super.key, required this.tool, this.size = 64});
  final NoteAiTool tool;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ToolPainter(tool, tool.ink(context), noteAiPaper(context)),
      ),
    ),
  );
}

class _ToolPainter extends CustomPainter {
  const _ToolPainter(this.tool, this.ink, this.paper);
  final NoteAiTool tool;
  final Color ink, paper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = ink.withValues(alpha: .12);
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), stroke);
    void sheet(double x, double y, double w, double h, {bool tinted = false}) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect.shift(const Offset(3, 4)), fill);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = tinted
              ? Color.alphaBlend(ink.withValues(alpha: .08), paper)
              : paper,
      );
      canvas.drawRRect(rect, stroke);
    }

    void lines(double x, double y, double w, int count) {
      for (var i = 0; i < count; i++) {
        line(x, y + i * 7, x + w * (i == count - 1 ? .65 : 1), y + i * 7);
      }
    }

    void sparkle(double x, double y) {
      final path = Path()
        ..moveTo(x, y - 6)
        ..quadraticBezierTo(x + 1, y - 1, x + 6, y)
        ..quadraticBezierTo(x + 1, y + 1, x, y + 6)
        ..quadraticBezierTo(x - 1, y + 1, x - 6, y)
        ..quadraticBezierTo(x - 1, y - 1, x, y - 6)
        ..close();
      canvas.drawPath(path, Paint()..color = ink);
    }

    switch (tool) {
      case NoteAiTool.writing:
        sheet(13, 16, 43, 49);
        lines(21, 29, 25, 3);
        canvas.save();
        canvas.translate(53, 41);
        canvas.rotate(.62);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -23, 8, 35),
            const Radius.circular(2),
          ),
          Paint()..color = ink,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-4, 14)
            ..lineTo(0, 22)
            ..lineTo(4, 14)
            ..close(),
          Paint()..color = ink,
        );
        canvas.restore();
        sparkle(64, 15);
      case NoteAiTool.metadata:
        sheet(11, 13, 48, 48);
        final titlePaint = Paint()
          ..color = ink
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(20, 26), const Offset(47, 26), titlePaint);
        lines(20, 38, 25, 2);
        final tag = Path()
          ..moveTo(37, 51)
          ..lineTo(58, 51)
          ..lineTo(70, 61)
          ..lineTo(58, 71)
          ..lineTo(37, 71)
          ..close();
        canvas.drawPath(tag, Paint()..color = paper);
        canvas.drawPath(tag, stroke);
        canvas.drawCircle(const Offset(59, 61), 2.5, Paint()..color = ink);
      case NoteAiTool.image:
      case NoteAiTool.background:
        sheet(10, 18, 53, 43, tinted: true);
        canvas.drawCircle(
          const Offset(47, 30),
          5,
          Paint()..color = ink.withValues(alpha: .6),
        );
        final hills = Path()
          ..moveTo(15, 54)
          ..lineTo(29, 36)
          ..lineTo(41, 48)
          ..lineTo(49, 42)
          ..lineTo(59, 54);
        canvas.drawPath(hills, stroke);
        if (tool == NoteAiTool.image) {
          canvas.drawCircle(const Offset(59, 57), 11, Paint()..color = paper);
          canvas.drawCircle(const Offset(59, 57), 11, stroke);
          line(67, 65, 74, 72);
        } else {
          sparkle(66, 16);
          sparkle(65, 66);
        }
      case NoteAiTool.scan:
        sheet(22, 14, 36, 51);
        lines(29, 29, 22, 4);
        line(10, 27, 10, 10);
        line(10, 10, 27, 10);
        line(53, 10, 70, 10);
        line(70, 10, 70, 27);
        line(10, 53, 10, 70);
        line(10, 70, 27, 70);
        line(53, 70, 70, 70);
        line(70, 70, 70, 53);
        canvas.drawRect(const Rect.fromLTWH(6, 37, 68, 7), fill);
        line(6, 40, 74, 40);
      case NoteAiTool.presentation:
        sheet(9, 15, 61, 49);
        line(9, 25, 70, 25);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(16 + i * 6, 20), 1.5, Paint()..color = ink);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 32, 22, 24),
            const Radius.circular(2),
          ),
          fill,
        );
        lines(44, 34, 18, 3);
        sparkle(64, 63);
      case NoteAiTool.search || NoteAiTool.thoughtSearch:
        sheet(12, 11, 39, 50);
        sheet(18, 17, 39, 50, tinted: true);
        lines(25, 30, 23, 3);
        canvas.drawCircle(const Offset(58, 51), 12, Paint()..color = paper);
        canvas.drawCircle(const Offset(58, 51), 12, stroke);
        line(67, 60, 75, 68);
        sparkle(66, 13);
      case NoteAiTool.template:
        sheet(14, 12, 49, 57);
        line(23, 25, 49, 25);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(23, 35 + i * 9, 4, 4),
              const Radius.circular(1),
            ),
            stroke,
          );
          line(33, 37 + i * 9, 53, 37 + i * 9);
        }
        sparkle(65, 16);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToolPainter oldDelegate) =>
      oldDelegate.tool != tool ||
      oldDelegate.ink != ink ||
      oldDelegate.paper != paper;
}

class NoteAiToolCard extends StatelessWidget {
  const NoteAiToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.horizontal = false,
  });
  final NoteAiTool tool;
  final VoidCallback? onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final ink = tool.ink(context);
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tool.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          tool.caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: onTap != null,
      label: '${tool.label}. ${tool.caption}',
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Material(
          color: Color.alphaBlend(
            ink.withValues(alpha: .07),
            noteAiPaper(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ink.withValues(alpha: .18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: horizontal
                  ? Row(
                      children: [
                        NoteAiArt(tool: tool, size: 52),
                        const SizedBox(width: 12),
                        Expanded(child: text),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: ink),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            NoteAiArt(tool: tool, size: 52),
                            const Spacer(),
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 18,
                              color: ink,
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        text,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-page tool (AI note search) or, when [embedded], the body of one
/// tool inside the note's AI desk, which supplies the scrolling and header.
class NoteAiScaffold extends StatelessWidget {
  const NoteAiScaffold({
    super.key,
    required this.tool,
    required this.children,
    this.listKey,
    this.header,
    this.loading,
    this.embedded = false,
  });
  final NoteAiTool tool;
  final List<Widget> children;
  final Key? listKey;
  final Widget? header;
  final Widget? loading;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = NoteAiPalette.of(context, tint: tool.tint).theme(base);
    if (embedded) {
      return Theme(
        data: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [?loading, ...children],
        ),
      );
    }
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const BackButton(),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tool.title,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    key: listKey,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (loading != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight > 32
                                ? constraints.maxHeight - 32
                                : 0,
                          ),
                          child: Center(child: loading),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        header ??
                            Row(
                              children: [
                                NoteAiArt(
                                  tool: tool,
                                  size: largeText ? 48 : 56,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tool.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.35,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        const SizedBox(height: 24),
                        ...children,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteAiDetails extends StatelessWidget {
  const NoteAiDetails(this.text, {super.key, required this.title});
  final String text, title;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    leading: const Icon(Icons.info_outline_rounded, size: 19),
    title: Text(title, style: Theme.of(context).textTheme.bodySmall),
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ),
    ],
  );
}

class NoteAiPreview extends StatelessWidget {
  const NoteAiPreview({
    super.key,
    required this.child,
    this.label = 'Your preview',
  });
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 12),
        Text(
          'Check the details before you keep them.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// Wrapping choices never squeeze or truncate labels at large text sizes.
class NoteAiChoices<T> extends StatelessWidget {
  const NoteAiChoices({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.icons = const {},
  });
  final Map<T, String> choices;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Map<T, IconData> icons;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices.entries)
          Semantics(
            button: true,
            selected: selected == choice.key,
            child: ChoiceChip(
              label: Text(choice.value),
              avatar: selected == choice.key
                  ? const Icon(Icons.check_rounded, size: 19)
                  : icons[choice.key] == null
                  ? null
                  : Icon(icons[choice.key], size: 19),
              selectedColor: Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: .14),
                noteAiPaper(context),
              ),
              backgroundColor: noteAiPaper(context),
              selected: selected == choice.key,
              onSelected: onChanged == null
                  ? null
                  : (_) => onChanged!(choice.key),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: selected == choice.key ? .7 : .2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Concrete starting points let a person choose a picture before typing.
/// Starting points for a website brief: a label, the brief, an icon and a
/// tint.
const noteWebsiteIdeas = [
  (
    'Guide',
    'A clear guide with a table of contents and collapsible sections',
    Icons.menu_book_outlined,
    Color(0xFF75619B),
  ),
  (
    'Timeline',
    'An interactive timeline of what happened, in order',
    Icons.timeline_rounded,
    Color(0xFF527C9C),
  ),
  (
    'Cook mode',
    'A recipe app: adjustable servings, step-by-step cook mode and timers',
    Icons.restaurant_outlined,
    Color(0xFFB5683F),
  ),
  (
    'Workout timer',
    'An interval timer that runs through the routine, with sounds and progress',
    Icons.fitness_center_rounded,
    Color(0xFF527C9C),
  ),
  (
    'Calculator',
    'A working budget calculator with totals, splits and a chart',
    Icons.calculate_outlined,
    Color(0xFF75619B),
  ),
  (
    'Packing list',
    'A tickable list grouped sensibly, with progress that is remembered',
    Icons.checklist_rounded,
    Color(0xFF44766B),
  ),
  (
    'Dashboard',
    'A dashboard with charts of the numbers in the note',
    Icons.insights_rounded,
    Color(0xFFB5683F),
  ),
  (
    'Magazine',
    'An elegant magazine-style story with bold headings',
    Icons.auto_stories_outlined,
    Color(0xFF9C6887),
  ),
];

class NoteAiBackdropIdeas extends StatelessWidget {
  const NoteAiBackdropIdeas({
    super.key,
    required this.value,
    required this.onChanged,
    this.ideas = _backdrops,
  });
  final String value;
  final ValueChanged<String>? onChanged;

  /// A label, the text it fills in, an icon and a tint.
  final List<(String, String, IconData, Color)> ideas;

  static const _backdrops = [
    (
      'Ocean',
      'Soft ocean waves and sea glass, calm and minimal',
      Icons.waves_rounded,
      Color(0xFF527C9C),
    ),
    (
      'Leaves',
      'Soft green leaves on warm paper, calm and minimal',
      Icons.spa_outlined,
      Color(0xFF44766B),
    ),
    (
      'Sunset',
      'A warm peach sunset with soft clouds, calm and minimal',
      Icons.wb_twilight_rounded,
      Color(0xFFB5683F),
    ),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final idea in ideas)
          ChoiceChip(
            selectedColor: Color.alphaBlend(
              Theme.of(context).colorScheme.primary.withValues(alpha: .14),
              noteAiPaper(context),
            ),
            backgroundColor: noteAiPaper(context),
            selected: value == idea.$2,
            label: Text(idea.$1),
            avatar: Icon(
              value == idea.$2 ? Icons.check_rounded : idea.$3,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color.lerp(idea.$4, Colors.white, .4)
                  : idea.$4,
              size: 24,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: onChanged == null ? null : (_) => onChanged!(idea.$2),
          ),
      ],
    ),
  );
}
