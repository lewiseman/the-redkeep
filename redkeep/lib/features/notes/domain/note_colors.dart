import 'dart:math';

import 'package:flutter/material.dart';

/// The resolved colors of a note in the current theme.
@immutable
class NoteColors {
  const NoteColors({
    required this.background,
    required this.foreground,
    Color? secondary,
  }) : secondary = secondary ?? foreground;

  final Color background;
  final Color foreground;
  final Color secondary;

  static const plain = NoteColorPreset.plain;

  /// Every catalog entry is available to the picker and random selection.
  static const presets = NoteColorPreset.values;

  /// Missing or unrecognized types use the neutral background.
  static NoteColorPreset presetForType(Object? type) =>
      presets.firstWhere((preset) => preset.type == type, orElse: () => plain);

  static NoteColors fromBackground(
    ColorScheme colors,
    Map<String, dynamic> background,
  ) => presetForType(background['type']).resolveColors(colors);

  static NoteColorPreset randomPreset(int seed) =>
      presets[Random(seed).nextInt(presets.length)];
}

/// One catalog for saved identifiers, picker labels, and light/dark paper.
/// Named colors stay recognizable when the app's accent changes.
enum NoteColorPreset {
  paper('paper', 'Paper', 'Soft', Color(0xfff4f0e8), Color(0xff33312c)),
  sand('sand', 'Sand', 'Warm', Color(0xfff3e4c8), Color(0xff3d3527)),
  indigo('indigo', 'Indigo', 'Calm', Color(0xffe4e6f6), Color(0xff2d3048)),
  sage('sage', 'Sage', 'Earthy', Color(0xffdfe8d7), Color(0xff2b3629)),
  mint('mint', 'Mint', 'Fresh', Color(0xffd9ede5), Color(0xff263a32)),
  sky('sky', 'Sky', 'Airy', Color(0xffddecf5), Color(0xff293944)),
  rose('rose', 'Rose', 'Gentle', Color(0xfff4dee3), Color(0xff432e35)),
  lavender(
    'lavender',
    'Lavender',
    'Quiet',
    Color(0xffebe1f3),
    Color(0xff382f45),
  ),
  peach('peach', 'Peach', 'Cozy', Color(0xfff8e1d2), Color(0xff453329)),
  clay('clay', 'Clay', 'Grounded', Color(0xffefdcd3), Color(0xff423029)),
  cobalt('cobalt', 'Cobalt', 'Bold', Color(0xff244bb8), Color(0xff213f91)),
  emerald('emerald', 'Emerald', 'Rich', Color(0xff12623e), Color(0xff124e36)),
  crimson('crimson', 'Crimson', 'Vivid', Color(0xffa01f38), Color(0xff7d2337)),
  violet('violet', 'Violet', 'Deep', Color(0xff713bb0), Color(0xff4e2a7c)),
  amber('amber', 'Amber', 'Golden', Color(0xffebb33b), Color(0xff62430f)),
  plain(null, 'Plain', 'Minimal');

  const NoteColorPreset(
    this.type,
    this.label,
    this.description, [
    this._lightBackground,
    this._darkBackground,
  ]);

  /// Persist this value rather than the enum name or index.
  final String? type;
  final String label;
  final String description;
  final Color? _lightBackground;
  final Color? _darkBackground;

  NoteColors resolveColors(ColorScheme colors) {
    if (this == plain) {
      return NoteColors(
        background: colors.surfaceContainerHigh,
        foreground: colors.onSurface,
        secondary: colors.onSurfaceVariant,
      );
    }
    final dark = colors.brightness == Brightness.dark;
    final background = (dark ? _darkBackground : _lightBackground)!;
    // Bold paper can need light ink even when the app uses a light theme.
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? const Color(0xfff5f0eb)
        : const Color(0xff302d34);
    return NoteColors(
      background: background,
      foreground: foreground,
      secondary: Color.lerp(foreground, background, .2),
    );
  }

  /// The note's color for an action sitting on a neutral [surface], e.g.
  /// the reading dock's Edit button: the preset's light or dark tone,
  /// whichever stands out more, deepened when neither does. Plain notes use
  /// the app's [primary].
  ///
  /// The app's accent would clash with colored paper (green on crimson).
  Color accentOn(Color surface, {required Color primary}) {
    if (this == plain) return primary;
    final light = _lightBackground!, dark = _darkBackground!;
    final tone = _contrast(light, surface) >= _contrast(dark, surface)
        ? light
        : dark;
    // Mid tones (cobalt on a dark dock) move away from the surface until the
    // button reads as a button.
    final away = surface.computeLuminance() > .5 ? Colors.black : Colors.white;
    for (var step = 0; step <= 10; step++) {
      final mixed = Color.lerp(tone, away, step / 10)!;
      if (_contrast(mixed, surface) >= 3) return mixed;
    }
    return away;
  }

  static double _contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (max(x, y) + .05) / (min(x, y) + .05);
  }

  Map<String, dynamic> toBackground() => {'type': type};
}
