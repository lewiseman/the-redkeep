import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/cushion.dart';
import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';

/// The Watchlist's host, as drawn for its More pocket.
const watchlistArtworkKey = 'more.watchlist';

/// Tyrion, who keeps the Watchlist. He lifts out of his pocket on More and
/// flies to the wall when it opens, and back again when it closes.
class WatchlistMascot extends StatelessWidget {
  const WatchlistMascot({super.key, required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: RenderingPolicyScope.of(context).animate,
    child: Hero(
      tag: watchlistArtworkKey,
      // Up and over in an arc, as if lifted out of the pocket.
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      // Redrawn at every size in flight, so he never looks soft or clipped.
      flightShuttleBuilder: (_, _, _, _, _) => LayoutBuilder(
        builder: (context, constraints) => LocalArtwork(
          assetKey: watchlistArtworkKey,
          dimension: constraints.biggest.shortestSide,
          highResolution: true,
        ),
      ),
      child: LocalArtwork(
        assetKey: watchlistArtworkKey,
        dimension: dimension,
        highResolution: true,
      ),
    ),
  );
}

/// Where the bubble's speaker is: beside it, or above it.
enum SpeakerSide { left, right, above }

/// A paper speech bubble in handwriting, its tail curling out of one side
/// to the speaker's mouth. It pops out from the tail as the words are said.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.speaker = SpeakerSide.right,
    this.tailHeight = .5,
    this.tailFromEnd = 60,
    this.stretch = false,
    this.onTap,
    this.semanticLabel,
  });

  final String text;
  final SpeakerSide speaker;

  /// Where the tail leaves the side, as a fraction of the bubble's height.
  final double tailHeight;

  /// With the speaker above: how far in from the right edge the tail
  /// rises, to sit under the speaker.
  final double tailFromEnd;

  /// Fills the width it is given rather than hugging its words.
  final bool stretch;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Room at the side (or top) for the tail.
  static const tail = 34.0;

  @override
  Widget build(BuildContext context) {
    final cushion = CushionColors.of(context);
    final policy = RenderingPolicyScope.of(context);
    final right = speaker == SpeakerSide.right;
    final above = speaker == SpeakerSide.above;
    final hand = DiaryTypography.of(context).title
        .copyWith(fontSize: 22, height: 1.12, color: cushion.ink);
    Widget bubble = CustomPaint(
      painter: _BubblePainter(cushion, speaker, tailHeight, tailFromEnd),
      child: Padding(
        padding: above
            ? const EdgeInsets.fromLTRB(18, 14 + tail, 18, 14)
            : EdgeInsets.fromLTRB(
                right ? 16 : 16 + tail,
                12,
                right ? 14 + tail : 14,
                14,
              ),
        child: AnimatedSwitcher(
          duration: policy.duration * 2,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          child: Text(text, key: ValueKey(text), style: hand),
        ),
      ),
    );
    if (stretch) bubble = SizedBox(width: double.infinity, child: bubble);
    final origin = above
        ? const Alignment(.75, -1)
        : Alignment(right ? 1 : -1, tailHeight * 2 - 1);
    if (policy.animate) {
      bubble = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: const Interval(.3, 1, curve: Curves.elasticOut),
        child: bubble,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .55 + .45 * t,
            alignment: origin,
            child: child,
          ),
        ),
      );
    }
    final onTap = this.onTap;
    if (onTap == null) {
      return Semantics(label: semanticLabel ?? text, child: bubble);
    }
    return Semantics(
      button: true,
      label: semanticLabel ?? text,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Springy(depth: .05, alignment: origin, child: bubble),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(
    this.colors,
    this.speaker,
    this.tailHeight,
    this.tailFromEnd,
  );
  final CushionColors colors;
  final SpeakerSide speaker;
  final double tailHeight, tailFromEnd;

  @override
  void paint(Canvas canvas, Size size) {
    const t = SpeechBubble.tail;
    final right = speaker == SpeakerSide.right;
    final above = speaker == SpeakerSide.above;
    final RRect body;
    final Path tailPath;
    if (above) {
      body = RRect.fromLTRBR(
        0,
        t,
        size.width,
        size.height,
        const Radius.circular(20),
      );
      // A curled tail rising from the top edge to the speaker overhead.
      final x = (size.width - tailFromEnd).clamp(30.0, size.width - 30);
      tailPath = Path()
        ..moveTo(x - 15, t + 8)
        ..quadraticBezierTo(x - 9, t * .45, x - 2, 0)
        ..quadraticBezierTo(x + 6, t * .5, x + 13, t + 8)
        ..close();
    } else {
      body = RRect.fromLTRBR(
        right ? 0 : t,
        0,
        right ? size.width - t : size.width,
        size.height,
        const Radius.circular(20),
      );
      // A curled tail from the side to a point at the speaker's mouth.
      final y = (size.height * tailHeight).clamp(18.0, size.height - 18);
      final edge = right ? body.right : body.left;
      final tip = Offset(right ? size.width : 0, y - 4);
      final out = right ? 1.0 : -1.0;
      tailPath = Path()
        ..moveTo(edge - out * 8, y - 12)
        ..quadraticBezierTo(edge + out * t * .45, y - 10, tip.dx, tip.dy)
        ..quadraticBezierTo(edge + out * t * .3, y + 4, edge - out * 8, y + 10)
        ..close();
    }
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tailPath,
    );
    final c = colors;
    if (!c.simple) {
      canvas.drawPath(
        shape.shift(const Offset(0, 3)),
        Paint()..color = c.shadow.withValues(alpha: c.dark ? .3 : .08),
      );
    }
    canvas.drawPath(
      shape,
      Paint()
        ..color = Color.lerp(
          c.paper,
          c.dark ? c.paper : Colors.white,
          c.dark ? 0 : .6,
        )!,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.edge.withValues(alpha: c.dark ? .85 : .75),
    );
    if (!c.simple) {
      paintStitches(canvas, Path()..addRRect(body.deflate(6)), c);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.colors != colors ||
      old.speaker != speaker ||
      old.tailHeight != tailHeight ||
      old.tailFromEnd != tailFromEnd;
}
