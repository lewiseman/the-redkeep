import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../assets/presentation/local_artwork.dart';

class NoteAddButton extends StatefulWidget {
  const NoteAddButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<NoteAddButton> createState() => NoteAddButtonState();
}

class NoteAddButtonState extends State<NoteAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final policy = RenderingPolicyScope.of(context);
    final reducedMotion = !policy.animate;
    final simple = policy.simplerEffects;
    return Tooltip(
      message: 'Create note',
      excludeFromSemantics: true,
      child: Semantics(
        label: 'Create note',
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) {
              if (_pressed == pressed) return;
              setState(() => _pressed = pressed);
            },
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: .14),
            child: SizedBox.square(
              dimension: 72,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? .94 : 1,
                  duration: reducedMotion
                      ? Duration.zero
                      : Duration(milliseconds: _pressed ? 70 : 140),
                  curve: Curves.easeOutCubic,
                  // A blurred, darkened copy of the artwork sits just below
                  // it, so the button reads as lifted off the page.
                  child: Stack(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 3),
                        child: ImageFiltered(
                          enabled: !simple,
                          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.shadow
                                  .withValues(alpha: simple ? .08 : .16),
                              BlendMode.srcIn,
                            ),
                            child: const LocalArtwork(
                              assetKey: 'notes.add',
                              dimension: 64,
                            ),
                          ),
                        ),
                      ),
                      const LocalArtwork(assetKey: 'notes.add', dimension: 64),
                    ],
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

class NoteFirstCard extends StatelessWidget {
  const NoteFirstCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_note_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              'Every idea\nstarts somewhere.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontSize: 18,
                height: 1.25,
                letterSpacing: -.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'A list, a plan, a passing thought. Make a little space for it.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your first note',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.north_east_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
