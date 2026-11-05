import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/startup_handoff.dart';

class _From extends StatelessWidget {
  const _From();
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.bottomCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StartupHandoffLogo(child: SizedBox(width: 100, height: 100)),
        StartupHandoffExit(child: Text('Card')),
      ],
    ),
  );
}

class _To extends StatelessWidget {
  const _To();
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StartupHandoffLogo(child: SizedBox(width: 50, height: 50)),
        Text('Destination'),
      ],
    ),
  );
}

class _ToWithoutLogo extends StatelessWidget {
  const _ToWithoutLogo();
  @override
  Widget build(BuildContext context) => const Text('Destination');
}

Widget _app(Widget child, {bool animateIn = false, bool reduced = false}) =>
    MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: reduced,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: StartupHandoff(animateIn: animateIn, child: child),
      ),
    );

/// The moving logo is the only one painted outside a page's fade.
Rect _flyingLogo(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(Positioned), matching: find.byType(SizedBox))
      .first,
);

void main() {
  testWidgets('keeps the old page and moves the logo to the new one', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _From()));
    final start = tester.getRect(find.byType(SizedBox).first);

    await tester.pumpWidget(_app(const _To(), animateIn: true));
    expect(find.byType(_From), findsOneWidget);
    expect(find.byType(_To), findsOneWidget);
    expect(_flyingLogo(tester), start);

    await tester.pump(); // Measures the destination and starts the flight.
    await tester.pump(StartupHandoff.duration ~/ 2);
    // The old card has cleared before the new content is fully in.
    final card = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Card'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(card.opacity.value, 0);
    final middle = _flyingLogo(tester);
    expect(middle.top, lessThan(start.top));
    expect(middle.height, lessThan(start.height));

    await tester.pumpAndSettle();
    expect(find.byType(_From), findsNothing);
    expect(find.byType(Positioned), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
    expect(tester.getRect(find.byType(SizedBox).first).height, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion swaps pages at once', (tester) async {
    await tester.pumpWidget(_app(const _From(), reduced: true));
    await tester.pumpWidget(_app(const _To(), animateIn: true, reduced: true));
    expect(find.byType(_From), findsNothing);
    expect(find.byType(Positioned), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a destination without a logo still fades in', (tester) async {
    await tester.pumpWidget(_app(const _From()));
    await tester.pumpWidget(_app(const _ToWithoutLogo(), animateIn: true));
    await tester.pump();
    expect(find.byType(Positioned), findsNothing);
    expect(find.byType(_From), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(_From), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('going back to the old page plays no handoff', (tester) async {
    await tester.pumpWidget(_app(const _To(), animateIn: true));
    await tester.pumpWidget(_app(const _From()));
    expect(find.byType(_To), findsNothing);
    expect(find.byType(_From), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
