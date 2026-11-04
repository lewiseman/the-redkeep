import '../../../../core/presentation/rendering_policy.dart';

import 'package:flutter/material.dart';

import '../../domain/website/website_themes.dart';

const websiteAccentColors = {
  'ink': Color(0xFF3B3F5C),
  'rose': Color(0xFFC2255C),
  'ocean': Color(0xFF1864AB),
  'forest': Color(0xFF2B8A3E),
  'sun': Color(0xFFD9480F),
  'plum': Color(0xFF862E9C),
};

/// A row of theme swatches. [auto] adds "Let it choose" as `auto`.
class WebsiteThemeSwatches extends StatelessWidget {
  const WebsiteThemeSwatches({
    super.key,
    required this.selected,
    required this.onSelected,
    this.auto = false,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String id, String label, Widget swatch) => Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        selected: id == selected,
        button: true,
        label: '$label theme',
        child: InkWell(
          key: ValueKey('website-theme-$id'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(id),
          child: Column(
            children: [
              AnimatedContainer(
                duration: RenderingPolicyScope.of(context).duration,
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    width: 2,
                    color: id == selected
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: swatch,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
    // Not a ListView: the sheet's own list is the page's one scroll view.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (auto)
            chip(
              'auto',
              'Let it choose',
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.auto_awesome, color: scheme.primary),
              ),
            ),
          for (final theme in websiteThemes)
            chip(
              theme.id,
              theme.name,
              ColoredBox(
                color: Color(theme.swatch.$1),
                child: Align(
                  alignment: const Alignment(-.5, .3),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      color: Color(theme.swatch.$2),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
