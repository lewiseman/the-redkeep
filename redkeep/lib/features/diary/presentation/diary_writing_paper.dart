import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_period.dart';
import 'diary_artwork.dart';
import 'diary_paper_stamp.dart';
import 'diary_writing_prompt.dart';
import 'photos/diary_ink_action.dart';

/// Space between the top of the page body and the edge of the paper.
const diaryWritingSheetGap = 14.0;

/// The widest the sheet grows, so writing keeps the day sheet's line lengths.
const diaryWritingSheetMaxWidth = 640.0;

/// The diary's sky and a pinned sheet of paper, behind the writing.
///
/// This sits on its own layer and ignores the keyboard: the sheet runs past the
/// bottom of the screen, so it is painted once rather than on every keystroke,
/// caret blink or frame of the keyboard moving.
class DiaryWritingBackdrop extends StatelessWidget {
  const DiaryWritingBackdrop({
    super.key,
    required this.variant,
    required this.pinned,
  });

  final int variant;

  /// Whether this is today's page, as the diary's date tabs mark it.
  final bool pinned;

  static const _pinSize = 30.0;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    final sheetTop = MediaQuery.paddingOf(context).top + diaryWritingSheetGap;
    final width = MediaQuery.sizeOf(context).width;
    final artworkWidth = width.clamp(0.0, 700.0);
    final inset = ((width - diaryWritingSheetMaxWidth) / 2).clamp(6.0, width);
    final band = sheetTop + 48;
    return RepaintBoundary(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (!simple)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: band,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          // The same crop of the sky as the day page.
                          top: 60 - artworkWidth * .41,
                          left: (width - artworkWidth) / 2,
                          width: artworkWidth,
                          child: DiaryArtwork(
                            assetKey: 'diary.header',
                            width: artworkWidth,
                            color: colors.primary,
                            colorBlendMode: BlendMode.color,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0, .7, 1],
                                colors: [
                                  colors.surface.withValues(alpha: .5),
                                  colors.surface.withValues(alpha: .68),
                                  colors.surface,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: sheetTop,
                left: inset,
                right: inset,
                bottom: -40,
                child: CustomPaint(
                  key: const ValueKey('diary-writing-sheet'),
                  painter: DiaryPaperStamp(
                    paper: colors.surface,
                    ink: colors.onSurface,
                    shadowColor: colors.shadow,
                    variant: variant,
                    edgeScale: simple ? 0 : .8,
                    shadow: !simple,
                  ),
                ),
              ),
              if (!simple && pinned)
                Positioned(
                  top: sheetTop - _pinSize / 2,
                  left: 0,
                  right: 0,
                  height: _pinSize,
                  child: const Center(
                    child: DiaryArtwork(
                      assetKey: 'diary.calendar.pin',
                      width: _pinSize,
                      height: _pinSize,
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

/// Pen-drawn rules that the writing sits on, scrolling with the text.
///
/// [strut] must be the strut of the field above, so that every line of text,
/// whatever its font or emoji, lands on a rule.
class DiaryRuledLines extends StatefulWidget {
  const DiaryRuledLines({
    super.key,
    required this.scroll,
    required this.style,
    required this.strut,
    required this.top,
    required this.inset,
  });

  final ScrollController scroll;
  final TextStyle style;
  final StrutStyle strut;

  /// The field's top content padding.
  final double top;
  final double inset;

  @override
  State<DiaryRuledLines> createState() => _DiaryRuledLinesState();
}

class _DiaryRuledLinesState extends State<DiaryRuledLines> {
  late final _strokes = DiaryRuleStrokes(widget.inset);

  // The controller also notifies when the text grows. This only changes when
  // the page really moves, so typing never repaints the rules.
  final _offset = ValueNotifier<double>(0);

  Object? _lineKey;
  double _baseline = 0, _lineHeight = 0;

  void _follow() =>
      _offset.value = widget.scroll.hasClients ? widget.scroll.offset : 0;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_follow);
  }

  @override
  void didUpdateWidget(DiaryRuledLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll == widget.scroll) return;
    oldWidget.scroll.removeListener(_follow);
    widget.scroll.addListener(_follow);
    _follow();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_follow);
    _offset.dispose();
    _strokes.clear();
    super.dispose();
  }

  /// The page rebuilds on every keystroke, so measure only when the type does.
  void _measure(BuildContext context, TextScaler scaler) {
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final key = (widget.style, widget.strut, scaler, direction, locale);
    if (_lineKey == key) return;
    _lineKey = key;
    final probe = TextPainter(
      text: TextSpan(text: 'x', style: widget.style),
      strutStyle: widget.strut,
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout();
    final line = probe.computeLineMetrics().first;
    _baseline = line.baseline;
    _lineHeight = line.height;
    probe.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    _measure(context, scaler);
    // No LayoutBuilder here: a rebuild would lay out again, and any layout
    // forces a paint. The painter gets its width from the size it is given.
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('diary-writing-rules'),
        size: Size.infinite,
        painter: DiaryRulesPainter(
          offset: _offset,
          strokes: _strokes,
          firstRule: widget.top + _baseline + scaler.scale(6),
          spacing: _lineHeight,
          color: colors.onSurfaceVariant.withValues(
            alpha: colors.brightness == Brightness.dark ? .34 : .26,
          ),
        ),
      ),
    );
  }
}

/// A short cycle of strokes that repeat down the page. Baked once per width;
/// scrolling only translates them.
class DiaryRuleStrokes {
  DiaryRuleStrokes(this.inset);

  static const _cycle = 12;

  final double inset;
  double? _width;
  List<Path> _paths = const [];

  List<Path> forWidth(double width) {
    if (_width == width) return _paths;
    _width = width;
    return _paths = [
      for (var index = 0; index < _cycle; index++)
        diaryPenStroke(inset, width - inset - (index.isOdd ? 3 : 0), 0, index),
    ];
  }

  void clear() {
    _width = null;
    _paths = const [];
  }
}

@visibleForTesting
class DiaryRulesPainter extends CustomPainter {
  DiaryRulesPainter({
    required this.offset,
    required this.strokes,
    required this.firstRule,
    required this.spacing,
    required this.color,
  }) : super(repaint: offset);

  final ValueListenable<double> offset;
  final DiaryRuleStrokes strokes;
  final double firstRule, spacing;
  final Color color;

  static int _debugPaints = 0;

  /// How many times the rules have been painted, in debug builds.
  @visibleForTesting
  static int get debugPaints => _debugPaints;

  /// The rule positions visible in a box this tall, in paint order.
  @visibleForTesting
  Iterable<double> visibleRules(double height) sync* {
    if (spacing <= 0) return;
    final scrolled = offset.value;
    final first = ((scrolled - firstRule) / spacing).ceil();
    for (var index = first < 0 ? 0 : first; ; index++) {
      final y = firstRule + index * spacing - scrolled;
      if (y > height) return;
      yield y;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    assert(() {
      _debugPaints++;
      return true;
    }());
    final paths = strokes.forWidth(size.width);
    final pen = Paint()..color = color;
    final scrolled = offset.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final y in visibleRules(size.height)) {
      // The index comes from the rule's place on the page, not on screen, so
      // each rule keeps its own wobble while it scrolls.
      final index = ((y + scrolled - firstRule) / spacing).round();
      canvas.save();
      canvas.translate(0, y);
      canvas.drawPath(paths[index % paths.length], pen);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryRulesPainter oldDelegate) =>
      offset != oldDelegate.offset ||
      strokes != oldDelegate.strokes ||
      firstRule != oldDelegate.firstRule ||
      spacing != oldDelegate.spacing ||
      color != oldDelegate.color;
}

/// Holds a page's content to the sheet and above the keyboard. Only this
/// padding follows the keyboard, so its movement doesn't rebuild the page.
class DiaryWritingArea extends StatelessWidget {
  const DiaryWritingArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final inset = ((width - diaryWritingSheetMaxWidth) / 2).clamp(6.0, width);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset,
        padding.top + diaryWritingSheetGap,
        inset,
        math.max(MediaQuery.viewInsetsOf(context).bottom, padding.bottom),
      ),
      child: child,
    );
  }
}

/// A page's one primary action, on a scrap of the diary's paper.
class DiaryPaperSaveButton extends StatelessWidget {
  const DiaryPaperSaveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Flexible with a scaled label: at large text on a narrow screen the whole
    // word stays readable and the app bar's other actions stay on screen.
    return Flexible(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: DiaryPaperStamp(
              paper: colors.surface,
              ink: colors.onSurface,
              shadowColor: colors.shadow,
              edgeScale: .25,
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                disabledForegroundColor: colors.onSurfaceVariant.withValues(
                  alpha: .6,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: onPressed,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The prominent choice: a torn slip of paper soaked in the app's ink, labelled
/// by hand. Without a callback it dries to plain paper.
class DiaryInkSlip extends StatelessWidget {
  const DiaryInkSlip({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return DiaryInkAction(
      label: label,
      onPressed: onPressed,
      child: CustomPaint(
        painter: DiaryPaperStamp(
          paper: enabled ? colors.primary : colors.surfaceContainerHigh,
          ink: enabled ? colors.onPrimary : colors.onSurface,
          shadowColor: colors.shadow,
          variant: 1,
          edgeScale: simple ? 0 : .4,
          shadow: !simple && enabled,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.6,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: DiaryTypography.of(context).title.copyWith(
                    color: enabled ? colors.onPrimary : colors.onSurfaceVariant,
                    fontSize: 23,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stroke of the same pen as the page's rules.
class DiaryPenLine extends StatelessWidget {
  const DiaryPenLine({
    super.key,
    required this.color,
    this.reach = 1,
    this.stroke = 3,
  });

  final Color color;

  /// How much of the available width the stroke crosses.
  final double reach;

  /// Picks the stroke's wobble.
  final int stroke;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 6,
      child: CustomPaint(
        painter: _PenLinePainter(color: color, reach: reach, stroke: stroke),
      ),
    ),
  );
}

class _PenLinePainter extends CustomPainter {
  const _PenLinePainter({
    required this.color,
    required this.reach,
    required this.stroke,
  });

  final Color color;
  final double reach;
  final int stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      diaryPenStroke(0, size.width * reach, size.height / 2, stroke),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PenLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      reach != oldDelegate.reach ||
      stroke != oldDelegate.stroke;
}

/// The date at the top of a page: the weekday and day, with the year only when
/// it isn't this one. Longer periods use their own label.
String diaryPageDate(DiaryPeriod date, DateTime now, String locale) {
  if (!date.isDay) return date.label(locale);
  return (now.year == date.year
          ? DateFormat.MMMMEEEEd(locale)
          : DateFormat.yMMMMEEEEd(locale))
      .format(date.calendarDate);
}
