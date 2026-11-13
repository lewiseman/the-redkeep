import 'package:flutter/material.dart';

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
