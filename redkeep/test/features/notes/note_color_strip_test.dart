import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/domain/note_colors.dart';
import 'package:redkeep/features/notes/presentation/note_color_strip.dart';

void main() {
  testWidgets('shows every preset in one row and reports the tapped one', (
    tester,
  ) async {
    var selected = NoteColorPreset.sage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NoteColorStrip(
              selected: selected,
              onSelected: (preset) => setState(() => selected = preset),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sage · Earthy'), findsOneWidget);
    expect(find.bySemanticsLabel('Sage, Earthy'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Rose, Gentle'));
    await tester.pumpAndSettle();

    expect(selected, NoteColorPreset.rose);
    expect(find.text('Rose · Gentle'), findsOneWidget);
    // The strip stays a single swatch row high.
    expect(tester.getSize(find.byType(ListView)).height, lessThan(60));
  });
}
