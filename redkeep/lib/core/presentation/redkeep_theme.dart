import 'package:flutter/material.dart';

@immutable
class PaperColors extends ThemeExtension<PaperColors> {
  const PaperColors({required this.sheet, required this.edge});

  final Color sheet;
  final Color edge;

  @override
  PaperColors copyWith({Color? sheet, Color? edge}) =>
      PaperColors(sheet: sheet ?? this.sheet, edge: edge ?? this.edge);

  @override
  PaperColors lerp(PaperColors? other, double t) => other == null
      ? this
      : PaperColors(
          sheet: Color.lerp(sheet, other.sheet, t)!,
          edge: Color.lerp(edge, other.edge, t)!,
        );
}

abstract final class RedkeepTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF2E7D7) : const Color(0xFF29251F);
    final muted = dark ? const Color(0xFFC9BDAA) : const Color(0xFF5D5148);
    final background = dark ? const Color(0xFF1B1917) : const Color(0xFFF1E9DD);
    final paper = dark ? const Color(0xFF27231F) : const Color(0xFFFFF8EB);
    final accent = dark ? const Color(0xFFE8AAA2) : const Color(0xFF7B302F);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: dark ? const Color(0xFF381212) : Colors.white,
          surface: paper,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: dark ? const Color(0xFF9A8C78) : const Color(0xFF7B6B58),
        );
    final base = ThemeData(brightness: brightness, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      // Platform system fonts remain in use; no presentation assets are bundled.
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: ink),
        labelLarge: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        scrolledUnderElevation: 0,
      ),
      extensions: [PaperColors(sheet: paper, edge: scheme.outline)],
    );
  }
}
