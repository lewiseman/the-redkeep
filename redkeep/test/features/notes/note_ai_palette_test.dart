import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/note_colors.dart';
import 'package:redkeep/features/notes/presentation/note_ai_widgets.dart';
import 'package:redkeep/features/notes/presentation/note_scene.dart';

void main() {
  test('paper over the wash keeps the writing readable for every color', () {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF8C4A2F),
        brightness: brightness,
      );
      for (final preset in NoteColorPreset.values) {
        final colors = preset.resolveColors(scheme);
        final opacity = notePaperOpacity(
          paper: colors.background,
          ink: colors.foreground,
          behind: scheme.surface,
        );
        final seen = Color.alphaBlend(
          colors.background.withValues(alpha: opacity),
          scheme.surface,
        );
        final where = '${preset.name}/${brightness.name}';
        expect(opacity, inInclusiveRange(.78, 1), reason: where);
        expect(
          noteAiContrast(colors.foreground, seen),
          greaterThanOrEqualTo(
            // Solid paper can do no better than its own pairing.
            opacity == 1
                ? noteAiContrast(colors.foreground, colors.background)
                : 7,
          ),
          reason: where,
        );
      }
    }
    // Bold crimson turns almost solid; it was washed out at 78%.
    expect(
      notePaperOpacity(
        paper: const Color(0xffa01f38),
        ink: const Color(0xfff5f0eb),
        behind: const Color(0xfffbf8f0),
      ),
      greaterThan(.85),
    );
  });

  test('the Edit accent stands out on the dock for every note color', () {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF8C4A2F),
        brightness: brightness,
      );
      for (final preset in NoteColorPreset.values) {
        final accent = preset.accentOn(scheme.surface, primary: scheme.primary);
        if (preset != NoteColorPreset.plain) {
          expect(
            noteAiContrast(accent, scheme.surface),
            greaterThanOrEqualTo(3),
            reason: '${preset.name}/${brightness.name}',
          );
        }
      }
    }
    // Pastel paper uses its deep tone, never a pale button on a pale dock.
    expect(
      NoteColorPreset.rose.accentOn(
        const Color(0xfffbf8f0),
        primary: Colors.green,
      ),
      const Color(0xff432e35),
    );
  });

  test('every note color and tool keeps the AI desk legible', () {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF8C4A2F),
        brightness: brightness,
      );
      for (final preset in NoteColorPreset.values) {
        final noteColor = preset.resolveColors(scheme).background;
        for (final tool in NoteAiTool.values) {
          final palette = NoteAiPalette.resolve(
            brightness: brightness,
            tint: tool.tint,
            noteColor: noteColor,
          );
          final where = '${preset.name}/${tool.name}/${brightness.name}';
          expect(
            noteAiContrast(palette.text, palette.paper),
            greaterThanOrEqualTo(4.5),
            reason: 'text $where',
          );
          expect(
            noteAiContrast(palette.muted, palette.paper),
            greaterThanOrEqualTo(4.5),
            reason: 'muted $where',
          );
          expect(
            noteAiContrast(palette.ink, palette.paper),
            greaterThanOrEqualTo(4.5),
            reason: 'ink $where',
          );
          expect(
            noteAiContrast(palette.onInk, palette.ink),
            greaterThanOrEqualTo(3),
            reason: 'button $where',
          );
        }
      }
    }
  });

  test(
    'a note page keeps menus, buttons and warnings legible on any paper',
    () {
      for (final brightness in Brightness.values) {
        final base = ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C4A2F),
          brightness: brightness,
        );
        for (final preset in NoteColorPreset.values) {
          final colors = preset.resolveColors(base);
          final scheme = noteSceneScheme(base, colors);
          final where = '${preset.name}/${brightness.name}';
          for (final background in [
            scheme.surface,
            scheme.surfaceContainerLow,
          ]) {
            for (final (name, color) in [
              ('onSurface', scheme.onSurface),
              ('onSurfaceVariant', scheme.onSurfaceVariant),
              ('primary', scheme.primary),
              ('error', scheme.error),
            ]) {
              expect(
                noteAiContrast(color, background),
                greaterThanOrEqualTo(4.5),
                reason: '$name $where',
              );
            }
          }
          expect(
            noteAiContrast(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(3),
            reason: 'onPrimary $where',
          );
          // Papers resolved inside the scene keep the scene's own color.
          expect(
            preset.resolveColors(scheme).background,
            colors.background,
            reason: 'paper $where',
          );
        }
      }
    },
  );

  test('legible ink leaves readable colors alone and repairs faint ones', () {
    const paper = Color(0xFFFAF8F2);
    const strong = Color(0xFF2D3048);
    expect(noteAiLegible(strong, paper), strong);
    final repaired = noteAiLegible(const Color(0xFFF5F0EB), paper);
    expect(noteAiContrast(repaired, paper), greaterThanOrEqualTo(4.5));
  });
}
