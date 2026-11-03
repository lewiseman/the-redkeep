import 'package:flutter/material.dart';

@immutable
class DiaryPaperColors {
  const DiaryPaperColors({
    required this.background,
    required this.foreground,
    Color? secondary,
  }) : secondary = secondary ?? foreground;
  final Color background, foreground, secondary;
}

/// Original stationery palette, resolved locally without changing saved data.
enum DiaryPaperPreset {
  paper(Color(0xfff4f0e8), Color(0xff33312c)),
  sand(Color(0xfff3e4c8), Color(0xff3d3527)),
  sky(Color(0xffddecf5), Color(0xff293944)),
  rose(Color(0xfff4dee3), Color(0xff432e35)),
  sage(Color(0xffdfe8d7), Color(0xff2b3629)),
  lavender(Color(0xffebe1f3), Color(0xff382f45));

  const DiaryPaperPreset(this.light, this.dark);
  final Color light, dark;
  DiaryPaperColors resolveColors(ColorScheme colors) {
    final background = colors.brightness == Brightness.dark ? dark : light;
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? const Color(0xfff5f0eb)
        : const Color(0xff302d34);
    return DiaryPaperColors(
      background: background,
      foreground: foreground,
      secondary: Color.lerp(foreground, background, .2),
    );
  }
}
