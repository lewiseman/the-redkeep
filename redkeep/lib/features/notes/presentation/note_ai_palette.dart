import 'package:flutter/material.dart';

/// WCAG contrast ratio between two opaque colors.
double noteAiContrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

/// Moves [color] toward black or white until it reads on [background].
Color noteAiLegible(Color color, Color background, {double ratio = 4.5}) {
  if (noteAiContrast(color, background) >= ratio) return color;
  final target = background.computeLuminance() > .3
      ? Colors.black
      : Colors.white;
  for (var t = .08; t < 1; t += .08) {
    final mixed = Color.lerp(color, target, t)!;
    if (noteAiContrast(mixed, background) >= ratio) return mixed;
  }
  return target;
}

/// The note the AI desk is working on. Its paper color quietly tints the
/// desk so the tools feel part of that note, whatever artwork it uses.
class NoteAiPaletteScope extends InheritedWidget {
  const NoteAiPaletteScope({
    super.key,
    required this.noteColor,
    required super.child,
  });
  final Color? noteColor;

  static Color? noteColorOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NoteAiPaletteScope>()
      ?.noteColor;

  @override
  bool updateShouldNotify(NoteAiPaletteScope oldWidget) =>
      noteColor != oldWidget.noteColor;
}

/// Colors for the AI desk, derived from the app brightness, the note's paper
/// and a tool's tint, with every text and ink color checked for contrast.
///
/// The note scene overrides `onSurface` and the text theme with the note's
/// own ink (light ink for bold artwork), so the desk never inherits those.
@immutable
class NoteAiPalette {
  const NoteAiPalette._({
    required this.brightness,
    required this.paper,
    required this.ink,
    required this.onInk,
    required this.text,
    required this.muted,
  });

  factory NoteAiPalette.resolve({
    required Brightness brightness,
    required Color tint,
    Color? noteColor,
  }) {
    final dark = brightness == Brightness.dark;
    final neutral = dark ? const Color(0xFF232522) : const Color(0xFFFAF8F2);
    var paper = neutral;
    if (noteColor != null) {
      final noteDark =
          ThemeData.estimateBrightnessForColor(noteColor) == Brightness.dark;
      // Pastel paper in a light theme (or deep paper in a dark one) tints the
      // desk generously; bold paper against the theme only whispers.
      paper = Color.lerp(neutral, noteColor, noteDark == dark ? .45 : .1)!;
    }
    final text = paper.computeLuminance() > .3
        ? const Color(0xFF2B2A27)
        : const Color(0xFFF1EDE4);
    final ink = noteAiLegible(
      dark ? Color.lerp(tint, Colors.white, .42)! : tint,
      paper,
    );
    final onInk =
        noteAiContrast(Colors.white, ink) >=
            noteAiContrast(const Color(0xFF1C1B19), ink)
        ? Colors.white
        : const Color(0xFF1C1B19);
    return NoteAiPalette._(
      brightness: brightness,
      paper: paper,
      ink: ink,
      onInk: onInk,
      text: text,
      muted: noteAiLegible(Color.lerp(text, paper, .32)!, paper),
    );
  }

  static NoteAiPalette of(BuildContext context, {Color? tint}) =>
      NoteAiPalette.resolve(
        brightness: Theme.of(context).brightness,
        tint: tint ?? const Color(0xFF75619B),
        noteColor: NoteAiPaletteScope.noteColorOf(context),
      );

  final Brightness brightness;
  final Color paper, ink, onInk, text, muted;

  Color wash(double amount) =>
      Color.alphaBlend(ink.withValues(alpha: amount), paper);

  ThemeData theme(ThemeData base) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    Color layer(double amount) =>
        Color.alphaBlend(text.withValues(alpha: amount), paper);
    final container = wash(.14);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      colorScheme: base.colorScheme.copyWith(
        primary: ink,
        onPrimary: onInk,
        primaryContainer: container,
        onPrimaryContainer: noteAiLegible(ink, container),
        secondary: ink,
        onSecondary: onInk,
        surface: paper,
        onSurface: text,
        onSurfaceVariant: muted,
        surfaceContainerLowest: paper,
        surfaceContainerLow: layer(.03),
        surfaceContainer: layer(.05),
        surfaceContainerHigh: layer(.08),
        surfaceContainerHighest: layer(.11),
        outline: Color.lerp(muted, paper, .35),
        outlineVariant: Color.lerp(muted, paper, .7),
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: base.iconTheme.copyWith(color: text),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: paper,
        selectedColor: wash(.16),
        labelStyle: base.textTheme.labelLarge?.copyWith(color: text),
        side: BorderSide(color: ink.withValues(alpha: .24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          disabledBackgroundColor: layer(.1),
          disabledForegroundColor: muted,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 50),
          shape: shape,
          side: BorderSide(color: ink.withValues(alpha: .35)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: text),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: wash(.035),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink.withValues(alpha: .3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink.withValues(alpha: .3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: .28),
        selectionHandleColor: ink,
      ),
    );
  }
}
