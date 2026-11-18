import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cushion.dart' show paintGlass, CushionColors;
import '../../../core/presentation/rendering_policy.dart';

import '../application/notes_providers.dart';
import '../domain/note_counts.dart';
import '../domain/note_tag.dart';
import '../domain/notes_query.dart';

typedef NoteCollectionOption = ({String emoji, String name, String value});

/// What the notes page shows: every note, the pinned ones, one tag, or Trash.
/// Collections replace each other rather than stacking.
abstract final class NoteCollection {
  /// Values for the built-in collections. The NUL prefix keeps them from
  /// colliding with user tags of the same name.
  static const all = 'All';
  static const pinned = '\u0000pinned';
  static const trash = '\u0000trash';

  static bool isBuiltIn(String value) =>
      value == all || value == pinned || value == trash;

  static String of(NotesQuery query) =>
      query.trash ? trash : query.tag ?? (query.pinnedOnly ? pinned : all);

  static NoteCollectionOption option(String value) => switch (value) {
    all => (emoji: '🗂️', name: 'All notes', value: all),
    pinned => (emoji: '📌', name: 'Pinned', value: pinned),
    trash => (emoji: '🗑️', name: 'Trash', value: trash),
    _ => (
      emoji: NoteTag.tryParse(value)?.emoji ?? '🏷️',
      name: NoteTag.tryParse(value)?.name ?? value,
      value: value,
    ),
  };

  static String key(String value) => switch (value) {
    all => 'notes-all',
    pinned => 'notes-pinned',
    trash => 'notes-trash',
    _ => 'notes-tag-$value',
  };

  /// [options] in display order: Pinned, All, the user tags in their given
  /// order, then Trash last.
  static List<T> arrange<T extends NoteCollectionOption>(List<T> options) => [
    ...options.where((option) => option.value == pinned),
    ...options.where((option) => option.value == all),
    ...options.where((option) => !isBuiltIn(option.value)),
    ...options.where((option) => option.value == trash),
  ];
}

/// Opens the collections as a hand of note cards fanned up from the bottom
/// of the screen, along the arc the thumb already sweeps. Resolves to the
/// chosen collection, or null when dismissed.
Future<String?> showNoteCollectionSheet(BuildContext context) =>
    showGeneralDialog<String>(
      context: context,
      // Above the shell's floating bar.
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .72),
      transitionDuration: RenderingPolicyScope.of(context).animate
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      pageBuilder: (context, _, _) => const _CollectionHand(),
    );

/// Every collection as a card held in a fanned hand. Swipe sideways to turn
/// the fan; the card at its crown faces you. The current collection stands
/// raised. A chosen card rises out of the hand while the rest fall away.
class _CollectionHand extends ConsumerStatefulWidget {
  const _CollectionHand();

  @override
  ConsumerState<_CollectionHand> createState() => _CollectionHandState();
}

class _CollectionHandState extends ConsumerState<_CollectionHand>
    with TickerProviderStateMixin {
  /// Cards dealt from the bottom into the fan, once.
  late final _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// The fan turning to rest on a card after a swipe.
  late final _turn = AnimationController.unbounded(vsync: this);

  /// The chosen card leaving the hand.
  late final _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Which card sits at the crown, as a fractional index.
  double? _crown;
  String? _chosen;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RenderingPolicyScope.of(context).animate) {
      _deal.forward();
    } else {
      _deal.value = 1;
    }
    _turn.addListener(() => setState(() => _crown = _turn.value));
  }

  @override
  void dispose() {
    _deal.dispose();
    _turn.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details, _Fan fan, int count) {
    if (_chosen != null) return;
    _turn.stop();
    setState(() {
      _crown = ((_crown ?? 0) - details.delta.dx / fan.step).clamp(
        0.0,
        count - 1.0,
      );
    });
  }

  void _settle(DragEndDetails details, _Fan fan, int count) {
    if (_chosen != null) return;
    final from = _crown ?? 0;
    // A flick carries the fan on a few cards before it settles.
    final glide = -(details.primaryVelocity ?? 0) / fan.step * .18;
    final to = (from + glide).roundToDouble().clamp(0.0, count - 1.0);
    if (!RenderingPolicyScope.of(context).animate) {
      setState(() => _crown = to);
      return;
    }
    _turn.value = from;
    _turn.animateTo(
      to,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
    );
  }

  void _choose(String value) {
    if (_chosen != null) return;
    HapticFeedback.selectionClick();
    setState(() => _chosen = value);
    if (!RenderingPolicyScope.of(context).animate) {
      Navigator.pop(context, value);
      return;
    }
    _exit.forward().whenComplete(() {
      if (mounted) Navigator.pop(context, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(notesFilterProvider);
    final tags = ref.watch(noteTagsProvider);
    final counts = ref.watch(noteCountsProvider).value;
    final selected = NoteCollection.of(filter);
    final options = NoteCollection.arrange([
      NoteCollection.option(NoteCollection.pinned),
      NoteCollection.option(NoteCollection.all),
      for (final raw in {...?tags.value, ?filter.tag})
        NoteCollection.option(raw),
      NoteCollection.option(NoteCollection.trash),
    ]);
    final count = options.length;
    final crown =
        _crown ??
        options
            .indexWhere((option) => option.value == selected)
            .clamp(0, count - 1)
            .toDouble();
    final padding = MediaQuery.paddingOf(context);
    final white = Colors.white.withValues(alpha: .92);

    Widget? note;
    if (tags.hasError && (tags.value?.isEmpty ?? true)) {
      note = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Tags could not be loaded.',
              style: theme.textTheme.bodyMedium?.copyWith(color: white),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(noteTagsProvider),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Retry tags'),
          ),
        ],
      );
    } else if ((tags.value?.isEmpty ?? false) && filter.tag == null) {
      note = Text(
        'Tags you give a note gather here, so related notes are one tap away.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: white.withValues(alpha: .75),
          height: 1.4,
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fan = _Fan.of(context, constraints.biggest, padding);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tapping the dimmed page puts the hand away.
            onTap: _chosen == null ? () => Navigator.maybePop(context) : null,
            onHorizontalDragUpdate: (d) => _drag(d, fan, count),
            onHorizontalDragEnd: (d) => _settle(d, fan, count),
            child: Stack(
              children: [
                // Shade deepening towards the hand, so the title and cards
                // stand clear of the notes behind.
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: ReverseAnimation(_exit),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xb3000000)],
                            stops: [.2, .75],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: fan.titleBottom,
                  child: FadeTransition(
                    opacity: ReverseAnimation(_exit),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Show notes from',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.3,
                            ),
                          ),
                        ),
                        if (note != null) ...[const SizedBox(height: 10), note],
                      ],
                    ),
                  ),
                ),
                ..._cards(options, selected, crown, fan, counts),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _cards(
    List<NoteCollectionOption> options,
    String selected,
    double crown,
    _Fan fan,
    NoteCounts? counts,
  ) {
    final order = [for (var i = 0; i < options.length; i++) i]
      // Cards nearer the crown lie on top of their neighbours.
      ..sort((a, b) => (b - crown).abs().compareTo((a - crown).abs()));
    return [
      for (final i in order)
        if ((i - crown).abs() * fan.step < fan.reach)
          AnimatedBuilder(
            key: ValueKey('fan-${options[i].value}'),
            animation: Listenable.merge([_deal, _exit]),
            builder: (context, child) {
              final away = (i - crown).abs();
              // Dealt from the crown outwards.
              final dealt = Curves.easeOutCubic.transform(
                ((_deal.value - away * .06) / .7).clamp(0.0, 1.0),
              );
              final chosen = options[i].value == _chosen;
              final exit = Curves.easeInCubic.transform(_exit.value);
              final angle = (i - crown) * fan.angle * dealt;
              final raised = options[i].value == selected ? fan.raise : 0.0;
              final lift = chosen
                  ? fan.card.height * 1.1 * exit
                  : -fan.card.height * 1.4 * exit;
              final transform = Matrix4.identity()
                ..translateByDouble(fan.pivot.dx, fan.pivot.dy, 0, 1)
                ..rotateZ(angle)
                ..translateByDouble(
                  0,
                  -fan.radius - raised - lift + (1 - dealt) * fan.card.height,
                  0,
                  1,
                )
                ..scaleByDouble(
                  chosen ? 1 + .1 * exit : 1,
                  chosen ? 1 + .1 * exit : 1,
                  1,
                  1,
                )
                ..translateByDouble(
                  -fan.card.width / 2,
                  -fan.card.height / 2,
                  0,
                  1,
                );
              // The transform sits outermost so taps follow the card.
              return Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: transform,
                  child: Opacity(
                    opacity: chosen ? 1 - exit * .3 : (1 - exit) * dealt,
                    child: child,
                  ),
                ),
              );
            },
            child: _CollectionCard(
              option: options[i],
              count: counts == null ? null : _countIn(counts, options[i].value),
              size: fan.card,
              current: options[i].value == selected,
              enabled: _chosen == null,
              onTap: () => _choose(options[i].value),
            ),
          ),
    ];
  }
}

int _countIn(NoteCounts counts, String value) => switch (value) {
  NoteCollection.all => counts.all,
  NoteCollection.pinned => counts.pinned,
  NoteCollection.trash => counts.trash,
  _ => counts.tags[value] ?? 0,
};

/// The fan's geometry for this screen: a circle whose top arc the cards sit
/// on, centred below the screen so the hand rises from the bottom edge.
class _Fan {
  _Fan({
    required this.card,
    required this.pivot,
    required this.radius,
    required this.angle,
    required this.raise,
    required this.titleBottom,
    required this.reach,
  });

  factory _Fan.of(BuildContext context, Size screen, EdgeInsets padding) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width =
        (screen.width * .36).clamp(118.0, 164.0) * (scale > 1.3 ? 1.15 : 1);
    final card = Size(width, width * 1.38);
    final radius = math.max(screen.width * 1.25, 480.0);
    // The crown card's centre, above the home indicator.
    final crownY = screen.height - padding.bottom - 64 - card.height / 2;
    return _Fan(
      card: card,
      pivot: Offset(screen.width / 2, crownY + radius),
      radius: radius,
      // Neighbours overlap a little, like a held hand.
      angle: card.width * .88 / radius,
      raise: 22,
      titleBottom: padding.bottom + 64 + card.height + 22 + 44,
      reach: screen.width / 2 + card.width,
    );
  }

  final Size card;
  final Offset pivot;
  final double radius;

  /// Turn between neighbouring cards, in radians.
  final double angle;

  /// How far the current collection stands up out of the hand.
  final double raise;
  final double titleBottom;

  /// Cards further than this along the arc are off screen and not built.
  final double reach;

  /// Arc length between neighbouring cards: one card per this many pixels.
  double get step => angle * radius;
}

/// One collection as a note card: paper with a folded corner, its emoji
/// large, and its name. Tags carry a strip of washi tape in a colour of
/// their own, Pinned a glass pin, and Trash is greyer, worn paper.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.option,
    required this.count,
    required this.size,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final NoteCollectionOption option;

  /// Notes in this collection, once counted.
  final int? count;
  final Size size;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    final value = option.value;
    final kind = value == NoteCollection.pinned
        ? _Kind.pinned
        : value == NoteCollection.trash
        ? _Kind.trash
        : value == NoteCollection.all
        ? _Kind.all
        : _Kind.tag;
    final paper = switch (kind) {
      _Kind.trash => dark ? const Color(0xff3a3a37) : const Color(0xffdedbd2),
      _ => dark ? const Color(0xff4a473e) : const Color(0xfffffcf2),
    };
    final ink = dark ? const Color(0xfff1ece0) : const Color(0xff2b2a26);
    return Semantics(
      key: ValueKey(NoteCollection.key(value)),
      button: true,
      selected: current,
      label: count == null
          ? option.name
          : '${option.name}, $count ${count == 1 ? 'note' : 'notes'}',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _CardPainter(
              kind: kind,
              paper: paper,
              tape: _tapeFor(value, dark),
              accent: scheme.primary,
              current: current,
              dark: dark,
              simple: simple,
              glass: CushionColors.of(context),
            ),
            child: SizedBox.fromSize(
              size: size,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, size.height * .2, 12, 14),
                child: Column(
                  children: [
                    Text(
                      option.emoji,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: size.width * .3),
                    ),
                    const Spacer(),
                    Flexible(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: size.width - 24,
                          ),
                          child: Text(
                            option.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: kind == _Kind.trash
                                  ? ink.withValues(alpha: .7)
                                  : ink,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(height: 8),
                      _CountChip(
                        count: count!,
                        tint:
                            _tapeFor(value, dark) ??
                            (kind == _Kind.trash ? ink : scheme.primary),
                        ink: ink,
                        dark: dark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A washi colour of the tag's own, steady across launches.
  static Color? _tapeFor(String value, bool dark) {
    if (NoteCollection.isBuiltIn(value)) return null;
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return HSLColor.fromAHSL(
      .85,
      (hash % 360).toDouble(),
      dark ? .32 : .45,
      dark ? .55 : .72,
    ).toColor();
  }
}

/// The tally of notes, stamped under the name in the card's own colour.
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.tint,
    required this.ink,
    required this.dark,
  });

  final int count;
  final Color tint;
  final Color ink;
  final bool dark;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? .24 : .18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: .45), width: .8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 3, 10, 3),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$count',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: count == 1 ? ' note' : ' notes',
                style: TextStyle(color: ink.withValues(alpha: .7)),
              ),
            ],
          ),
          maxLines: 1,
          style: TextStyle(
            color: ink,
            fontSize: 11.5,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}

enum _Kind { all, pinned, tag, trash }

class _CardPainter extends CustomPainter {
  const _CardPainter({
    required this.kind,
    required this.paper,
    required this.tape,
    required this.accent,
    required this.current,
    required this.dark,
    required this.simple,
    required this.glass,
  });

  final _Kind kind;
  final Color paper;
  final Color? tape;
  final Color accent;
  final bool current;
  final bool dark;
  final bool simple;
  final CushionColors glass;

  static const _radius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fold = size.width * .2;
    final card = Path()
      ..moveTo(_radius, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - _radius)
      ..arcToPoint(
        Offset(size.width - _radius, size.height),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(0, _radius)
      ..arcToPoint(Offset(_radius, 0), radius: const Radius.circular(_radius))
      ..close();
    final rect = Offset.zero & size;

    if (!simple) {
      // A cut-paper shadow, crisp offsets and no blur.
      canvas.drawPath(
        card.shift(const Offset(0, 6)),
        Paint()..color = Colors.black.withValues(alpha: .18),
      );
      canvas.drawPath(
        card.shift(const Offset(0, 2)),
        Paint()..color = Colors.black.withValues(alpha: .22),
      );
    }
    canvas.drawPath(
      card,
      simple
          ? (Paint()..color = paper)
          : (Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(paper, Colors.white, dark ? .05 : .5)!,
                  paper,
                  Color.lerp(paper, Colors.black, dark ? .12 : .05)!,
                ],
              ).createShader(rect)),
    );
    if (current) {
      // The current collection glows with the accent at its edge.
      canvas.drawPath(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = accent.withValues(alpha: .85),
      );
    } else {
      canvas.drawPath(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = Colors.black.withValues(alpha: dark ? .4 : .12),
      );
    }

    // The folded corner, its underside catching shadow.
    final flap = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold * .78)
      ..quadraticBezierTo(
        size.width - fold,
        fold,
        size.width - fold * .78,
        fold,
      )
      ..lineTo(size.width, fold)
      ..close();
    canvas.drawPath(
      flap,
      Paint()..color = Color.lerp(paper, Colors.black, dark ? .25 : .12)!,
    );

    switch (kind) {
      case _Kind.tag:
        _tape(canvas, size);
      case _Kind.pinned:
        _pin(canvas, size);
      case _Kind.trash:
        _creases(canvas, size);
      case _Kind.all:
        break;
    }
  }

  /// A strip of washi tape across the top, slightly askew.
  void _tape(Canvas canvas, Size size) {
    final colour = tape;
    if (colour == null) return;
    canvas.save();
    canvas.translate(size.width * .42, 2);
    canvas.rotate(-.06);
    final strip = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .5,
      height: 18,
    );
    canvas.drawRect(strip, Paint()..color = colour);
    if (!simple) {
      // Torn ends and a faint weave.
      final weave = Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 1;
      for (var x = strip.left + 4; x < strip.right; x += 6) {
        canvas.drawLine(
          Offset(x, strip.top),
          Offset(x - 3, strip.bottom),
          weave,
        );
      }
    }
    canvas.restore();
  }

  /// A glass-headed pin through the top of the card.
  void _pin(Canvas canvas, Size size) {
    final head = Offset(size.width / 2 - 6, 16);
    canvas.drawLine(
      head.translate(2, 4),
      head.translate(7, 14),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: .35),
    );
    paintGlass(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: head, radius: 8),
        const Radius.circular(8),
      ),
      colors: glass,
      tint: const Color(0xffc9473c),
      fill: .9,
      lift: .8,
    );
  }

  /// Old creases across worn paper.
  void _creases(Canvas canvas, Size size) {
    if (simple) return;
    final crease = Paint()
      ..strokeWidth = .8
      ..color = Colors.black.withValues(alpha: dark ? .3 : .1);
    canvas.drawLine(
      Offset(0, size.height * .35),
      Offset(size.width, size.height * .5),
      crease,
    );
    canvas.drawLine(
      Offset(size.width * .3, size.height),
      Offset(size.width * .6, 0),
      crease,
    );
  }

  @override
  bool shouldRepaint(_CardPainter old) =>
      kind != old.kind ||
      paper != old.paper ||
      tape != old.tape ||
      accent != old.accent ||
      current != old.current ||
      dark != old.dark ||
      simple != old.simple ||
      glass != old.glass;
}
