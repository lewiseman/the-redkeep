import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/notes/presentation/note_tag_chips.dart';

Widget _host(Color ink, List<String> tags) => MaterialApp(
  home: Scaffold(
    body: DefaultTextStyle(
      style: TextStyle(color: ink),
      child: NoteTagChips(tags: tags),
    ),
  ),
);

void main() {
  testWidgets('shows emoji and name apart, without the stored #', (
    tester,
  ) async {
    await tester.pumpWidget(_host(Colors.black, ['🛠️#programming']));
    expect(find.text('🛠️'), findsOneWidget);
    expect(find.text('programming'), findsOneWidget);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('keeps a legacy plain tag readable', (tester) async {
    await tester.pumpWidget(_host(Colors.black, ['work']));
    expect(find.text('work'), findsOneWidget);
  });

  for (final ink in [Colors.white, Colors.black]) {
    testWidgets('tints chip and label from the note ink $ink', (tester) async {
      await tester.pumpWidget(_host(ink, ['🛠️#programming']));
      final label = tester.widget<Text>(find.text('programming'));
      expect(label.style?.color, ink.withValues(alpha: .9));
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('programming'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final shape = box.decoration as ShapeDecoration;
      expect(shape.color, ink.withValues(alpha: .12));
    });
  }

  testWidgets('long tags ellipsize on narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _host(Colors.white, ['📚#${'very long tag name ' * 6}']),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
