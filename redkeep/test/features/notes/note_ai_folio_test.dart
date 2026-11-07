import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/presentation/note_ai_folio.dart';

void main() {
  test('paragraphs map back to their exact Markdown source', () {
    const body = '## Plan\n\n- seeds\n- soil\n  \n\nWater **daily**.\n';
    final blocks = noteBlocks(body);
    expect(
      [for (final b in blocks) body.substring(b.start, b.end)],
      ['## Plan', '- seeds\n- soil', 'Water **daily**.'],
    );
    expect(noteBlocks('   \n\n  '), isEmpty);
  });

  testWidgets('previews show formatted note text, not Markdown symbols', (
    tester,
  ) async {
    final chosen = <Set<int>>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NoteFolioPassages(
              body: '## Plan\n\nWater **daily**.',
              selected: const {},
              onChanged: chosen.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('daily', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notes-ai-passage-1')));
    expect(chosen.single, {1});
    expect(tester.takeException(), isNull);
  });
}
