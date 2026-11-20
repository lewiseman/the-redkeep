import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/diary_typography.dart';
import '../../../core/presentation/emoji_sphere/emoji_sphere.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../domain/diary_day_details.dart';

/// A question in the diary's hand, with an optional quiet action beside it.
class DiaryDetailsLabel extends StatelessWidget {
  const DiaryDetailsLabel({
    super.key,
    required this.text,
    this.trailing,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final Widget? trailing;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              textAlign: textAlign,
              style: DiaryTypography.of(context).title.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 25,
                height: 1.2,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The result of [showDiaryMoodPicker]: the mood to keep, null to clear it.
typedef DiaryMoodChoice = ({DiaryMood? mood});

/// Asks how a day felt on the emoji sphere, laid over the page itself:
/// solid paper behind the sphere that fades out toward the screen's edges.
/// Tapping the faded part, or going back, leaves the mood as it was.
/// Resolves to the new choice, or null when dismissed.
Future<DiaryMoodChoice?> showDiaryMoodPicker(
  BuildContext context, {
  DiaryMood? current,
}) {
  final animate = RenderingPolicyScope.of(context).animate;
  return showGeneralDialog<DiaryMoodChoice>(
    context: context,
    // Above the shell's floating bar.
    useRootNavigator: true,
    // The picker's own backdrop decides where a tap dismisses.
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: animate
        ? const Duration(milliseconds: 260)
        : Duration.zero,
    pageBuilder: (context, _, _) => _DiaryMoodPicker(current: current),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DiaryMoodPicker extends StatefulWidget {
  const _DiaryMoodPicker({required this.current});

  final DiaryMood? current;

  @override
  State<_DiaryMoodPicker> createState() => _DiaryMoodPickerState();
}

class _DiaryMoodPickerState extends State<_DiaryMoodPicker> {
  final _content = GlobalKey();
  late DiaryMood? _picked = widget.current;

  bool _closing = false;

  void _choose(DiaryMood? mood) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop((mood: mood));
  }

  /// Leaving keeps whatever sits in the lens; an untouched picker changes
  /// nothing.
  void _close() {
    if (_closing) return;
    if (_picked == widget.current) {
      _closing = true;
      Navigator.of(context).pop();
    } else {
      _choose(_picked);
    }
  }

  /// A tap no control took: outside the solid middle, it dismisses.
  void _tapped(TapUpDetails details) {
    final box = _content.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(details.globalPosition);
    final (across, down) = _MoodBackdropPainter.solid(box.size);
    final offset = local - box.size.center(Offset.zero);
    final reach =
        math.pow(offset.dx / across, 2) + math.pow(offset.dy / down, 2);
    if (reach > 1) _close();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    // The sphere gives up size before the words do, keyboard included.
    final room =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.vertical -
        media.textScaler.scale(220);
    return PopScope(
      // Back saves too, the same as a tap on the faded edge.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _tapped,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  key: const ValueKey('diary-mood-picker'),
                  // The backdrop reaches past the content to the screen edges.
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(24),
                  child: CustomPaint(
                    key: _content,
                    painter: _MoodBackdropPainter(
                      color: colors.surface,
                      fade: media.size.shortestSide * .38,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DiaryDetailsLabel(
                            text: 'How did it feel?',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: EmojiSphere(
                              selected: widget.current?.emoji,
                              favorites: [
                                for (final mood in DiaryMood.values) mood.emoji,
                              ],
                              maxDiameter: room.clamp(160.0, 340.0),
                              onChanged: (entry) => setState(
                                () =>
                                    _picked = DiaryMood.fromEmoji(entry.emoji),
                              ),
                              onConfirm: (entry) {
                                _picked = DiaryMood.fromEmoji(entry.emoji);
                                _close();
                              },
                              action: widget.current == null
                                  ? null
                                  : EmojiSphereAction(
                                      key: const ValueKey('diary-mood-clear'),
                                      label: 'Clear mood',
                                      icon: Icons.close_rounded,
                                      onPressed: () => _choose(null),
                                    ),
                            ),
                          ),
                        ],
                      ),
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

/// Solid paper in an oval around the picker, fading to nothing over [fade]
/// toward the screen's edges, so the page shows through all around.
class _MoodBackdropPainter extends CustomPainter {
  const _MoodBackdropPainter({required this.color, required this.fade});

  final Color color;
  final double fade;

  /// The solid oval's half-width and half-height around content of [size].
  static (double, double) solid(Size size) =>
      (size.width / 2 + 32, size.height / 2 + 48);

  @override
  void paint(Canvas canvas, Size size) {
    final (across, down) = solid(size);
    final outer = across + fade;
    final rect = Rect.fromCircle(center: Offset.zero, radius: outer);
    final edge = across / outer;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      // An oval: the solid part follows the content's own proportions.
      ..scale(1, (down + fade) / outer)
      ..drawCircle(
        Offset.zero,
        outer,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color,
              color,
              color.withValues(alpha: .6),
              color.withValues(alpha: 0),
            ],
            stops: [0, edge, edge + (1 - edge) * .4, 1],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MoodBackdropPainter old) =>
      old.color != color || old.fade != fade;
}
