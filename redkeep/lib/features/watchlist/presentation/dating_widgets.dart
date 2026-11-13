import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';

import '../domain/catalog_title.dart';
import '../domain/explore.dart';
import '../domain/recommender/deck.dart';
import '../domain/watch_title.dart';

/// Discover's dating-app colours, kept to the deck, profiles and matches.
abstract final class WatchBrand {
  static const rose = Color(0xFFFF4F79);
  static const wine = Color(0xFF5A0F24);
  static const like = Color(0xFF2BD99F);
  static const nope = Color(0xFFFF5864);
  static const watched = Color(0xFF3CA4FF);
  static const gold = Color(0xFFFFC542);

  /// Serif display face for big moments ("It's a Match").
  static const serif = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: ['Georgia', 'Noto Serif'],
    fontWeight: FontWeight.w700,
  );

  static Color of(SwipeChoice choice) => switch (choice) {
    SwipeChoice.nope => nope,
    SwipeChoice.like => like,
    SwipeChoice.watched => watched,
  };

  static String stamp(SwipeChoice choice) => switch (choice) {
    SwipeChoice.nope => 'NOPE',
    SwipeChoice.like => 'LIKE',
    SwipeChoice.watched => 'WATCHED',
  };
}

/// Round nope / watched / like buttons, on cards and profiles.
class DecisionButton extends StatelessWidget {
  const DecisionButton({
    super.key,
    required this.choice,
    required this.onPressed,
    this.size = 60,
  });

  final SwipeChoice choice;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip) = switch (choice) {
      SwipeChoice.nope => (Icons.close, 'Nope'),
      SwipeChoice.like => (Icons.favorite, 'Like'),
      SwipeChoice.watched => (Icons.visibility, 'Already watched'),
    };
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: size * .48,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xCC1B1B1F),
          foregroundColor: WatchBrand.of(choice),
          disabledBackgroundColor: const Color(0x661B1B1F),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

/// Nope, Watched and Like, centred, Watched smaller between them.
class DecisionRow extends StatelessWidget {
  const DecisionRow({super.key, required this.onDecide});
  final void Function(SwipeChoice choice)? onDecide;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      DecisionButton(
        choice: SwipeChoice.nope,
        onPressed: onDecide == null ? null : () => onDecide!(SwipeChoice.nope),
      ),
      const SizedBox(width: 18),
      DecisionButton(
        choice: SwipeChoice.watched,
        size: 46,
        onPressed: onDecide == null
            ? null
            : () => onDecide!(SwipeChoice.watched),
      ),
      const SizedBox(width: 18),
      DecisionButton(
        choice: SwipeChoice.like,
        onPressed: onDecide == null ? null : () => onDecide!(SwipeChoice.like),
      ),
    ],
  );
}

/// LIKE, NOPE or WATCHED, fading in as a card is dragged.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({super.key, required this.choice, required this.opacity});
  final SwipeChoice choice;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    final color = WatchBrand.of(choice);
    final (alignment, angle) = switch (choice) {
      SwipeChoice.like => (Alignment.topLeft, -.3),
      SwipeChoice.nope => (Alignment.topRight, .3),
      SwipeChoice.watched => (Alignment.center, 0.0),
    };
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    WatchBrand.stamp(choice),
                    style: TextStyle(
                      color: color,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
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

class CardBadge extends StatelessWidget {
  const CardBadge(
    this.label, {
    super.key,
    this.color = Colors.black54,
    this.dot,
    this.dark = false,
  });
  final String label;
  final Color color;
  final Color? dot;
  final bool dark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: dot != null ? Colors.white : color,
      borderRadius: BorderRadius.circular(20),
      // White tags need an edge on a light page.
      border: dot != null ? Border.all(color: Colors.black12) : null,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dot != null || dark ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A title's tags: how well it suits the reader, what kind of find it is,
/// where it streams and whether it is new. [enjoyment] is null while taste
/// is still being learned; [slot] is known only on the deck.
List<Widget> titleBadges(
  CatalogTitle title, {
  required int thisYear,
  double? enjoyment,
  DeckSlot? slot,
}) {
  final gem = isHiddenGem(title);
  final outOfLeague =
      enjoyment != null && desirability(title) >= .78 && enjoyment < .5;
  return [
    if (enjoyment != null)
      CardBadge(
        '${(enjoyment * 100).round().clamp(1, 99)}% match',
        color: WatchBrand.rose,
      ),
    if (gem) const CardBadge('Hidden gem', color: Colors.teal),
    if (outOfLeague)
      const CardBadge('Out of your league', color: Colors.deepPurple),
    if (slot == DeckSlot.wildcard && !gem && !outOfLeague)
      const CardBadge('Wildcard', color: WatchBrand.gold, dark: true),
    if (title.media == WatchMedia.tv) const CardBadge('Series'),
    if (title.providers.isNotEmpty)
      CardBadge('On ${title.providers.first}', dot: WatchBrand.like),
    if ((title.year ?? 0) >= thisYear - 1)
      const CardBadge('New', dot: WatchBrand.gold),
  ];
}

/// Opens a card's profile, and shows how well it matches: a ring that fills
/// to the score around a chevron and the percentage. Before taste is
/// learned there is no score, only a quiet dashed ring.
class MatchProfileButton extends StatefulWidget {
  const MatchProfileButton({
    super.key,
    required this.percent,
    required this.onPressed,
  });

  /// 1 to 99, or null while Discover is still learning.
  final int? percent;
  final VoidCallback onPressed;

  @override
  State<MatchProfileButton> createState() => _MatchProfileButtonState();
}

class _MatchProfileButtonState extends State<MatchProfileButton>
    with SingleTickerProviderStateMixin {
  late final _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Each card's ring sweeps in once; still with reduced motion.
    if (RenderingPolicyScope.of(context).animate) {
      _fill.forward();
    } else {
      _fill.value = 1;
    }
  }

  @override
  void didUpdateWidget(MatchProfileButton old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent && _fill.isCompleted) _fill.value = 1;
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.percent;
    final policy = RenderingPolicyScope.of(context);
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.4,
    );
    final size = 62.0 * scale;
    final glow = percent != null && percent >= 80 && !policy.simplerEffects;
    return Tooltip(
      message: 'View profile',
      child: Semantics(
        button: true,
        label: percent == null
            ? 'View profile'
            : 'View profile, $percent% match',
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC1B1B1F),
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: WatchBrand.rose.withValues(alpha: .35),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onPressed,
                child: AnimatedBuilder(
                  animation: _fill,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_fill.value);
                    final shown = percent == null
                        ? null
                        : (percent * t).round();
                    return CustomPaint(
                      painter: _MatchRing(
                        fraction: percent == null ? null : percent / 100 * t,
                      ),
                      // Even margins inside the ring; the pair is drawn at
                      // its own size and only shrinks for very large text.
                      child: Center(
                        child: SizedBox.square(
                          dimension: size * .62,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The glyph's box is mostly air: clip it to
                                // the chevron so the pair centres by eye.
                                SizedBox(
                                  width: 20,
                                  height: shown == null ? 20 : 10,
                                  child: OverflowBox(
                                    maxWidth: 28,
                                    maxHeight: 28,
                                    child: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: Colors.white,
                                      size: shown == null ? 28 : 24,
                                    ),
                                  ),
                                ),
                                if (shown != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '$shown%',
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                          applyHeightToFirstAscent: false,
                                          applyHeightToLastDescent: false,
                                        ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.2,
                                      // Digits keep their width as it counts.
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchRing extends CustomPainter {
  const _MatchRing({required this.fraction});

  /// 0 to 1, or null for the dashed, unscored ring.
  final double? fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1.5);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white24;
    final fraction = this.fraction;
    if (fraction == null) {
      // Twelve short dashes: a score still to come.
      const dashes = 12;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(
          rect,
          -math.pi / 2 + i * 2 * math.pi / dashes,
          2 * math.pi / dashes * .45,
          false,
          track..strokeCap = StrokeCap.round,
        );
      }
      return;
    }
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (fraction <= 0) return;
    final sweep = 2 * math.pi * fraction;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: const [WatchBrand.rose, WatchBrand.gold],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_MatchRing old) => old.fraction != fraction;
}

/// A title's year as a small frosted chip, above its name on a card.
class YearChip extends StatelessWidget {
  const YearChip({super.key, required this.year});
  final int year;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: .35)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        '$year',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}
