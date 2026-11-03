import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/appearance/domain/appearance_preferences.dart';
import 'diary_typography.dart';

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

  static ThemeData forAppearance(
    Brightness brightness,
    AppAccent accent, {
    TextTheme? fonts,
    DiaryTypography diary = const DiaryTypography(),
  }) {
    final base = _build(brightness, accent);
    final colors = base.colorScheme;
    return base.copyWith(
      textTheme: fonts?.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      primaryTextTheme: fonts?.apply(
        bodyColor: colors.onPrimary,
        displayColor: colors.onPrimary,
      ),
      extensions: [
        ...base.extensions.values.where(
          (extension) => extension is! DiaryTypography,
        ),
        diary.copyWith(
          title: diary.title.copyWith(color: colors.onSurface),
          body: diary.body.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }

  static ThemeData _build(
    Brightness brightness, [
    AppAccent accent = AppAccent.indigo,
  ]) {
    final dark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
    );
    final primary = dark ? accent.darkPrimary : accent.seed;
    final scheme = generated.copyWith(
      primary: primary,
      primaryContainer: Color.alphaBlend(
        primary.withValues(alpha: dark ? .18 : .10),
        generated.surface,
      ),
      onPrimaryContainer: generated.onSurface,
    );
    final ink = scheme.onSurface;
    final background = scheme.surface;
    final paper = scheme.surface;
    final base = ThemeData(brightness: brightness, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      extensions: [
        PaperColors(sheet: paper, edge: scheme.outline),
        const DiaryTypography(),
      ],
    );
  }
}
