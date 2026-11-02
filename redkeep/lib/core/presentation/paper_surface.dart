import 'package:flutter/material.dart';

import 'redkeep_theme.dart';
import 'rendering_policy.dart';

class PaperSurface extends StatelessWidget {
  const PaperSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PaperColors>()!;
    final simple = RenderingPolicyScope.of(context).simplerEffects;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sheet,
        border: Border.all(color: colors.edge),
        borderRadius: BorderRadius.circular(12),
        boxShadow: simple
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x18000000),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
