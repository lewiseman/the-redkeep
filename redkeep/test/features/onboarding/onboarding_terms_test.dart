import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_controls.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_terms.dart';

import '../../support/fake_onboarding_repository.dart';
import '../../support/pump_app.dart';

void main() {
  Future<void> footer(
    WidgetTester tester,
    Future<bool> Function(Uri) open,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingLegalLinkLauncherProvider.overrideWithValue(open),
        ],
        child: const MaterialApp(home: Scaffold(body: OnboardingTerms())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'legacy inline Terms and Privacy links expose real tap actions and exact destinations',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final opened = <Uri>[];
        await footer(tester, (uri) async {
          opened.add(uri);
          return true;
        });
        tester.semantics.tap(find.semantics.byLabel('Terms'));
        await tester.pumpAndSettle();
        tester.semantics.tap(find.semantics.byLabel('Privacy policy'));
        await tester.pumpAndSettle();
        expect(opened.map((u) => u.toString()), [
          'https://journal.lewiseman.com/terms.html',
          'https://journal.lewiseman.com/privacy.html',
        ]);
        expect(
          find.text('Could not open this page. Please try again.'),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final throws in [false, true]) {
    testWidgets(
      'link ${throws ? 'exception' : 'failure'} shows the legacy safe message',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await footer(tester, (_) async {
            if (throws) throw StateError('private platform failure');
            return false;
          });
          tester.semantics.tap(find.semantics.byLabel('Terms'));
          await tester.pumpAndSettle();
          expect(
            find.text('Could not open this page. Please try again.'),
            findsOneWidget,
          );
          expect(find.textContaining('private platform'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('late external-link result after disposal is ignored', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final gate = Completer<bool>();
      await footer(tester, (_) => gate.future);
      tester.semantics.tap(find.semantics.byLabel('Terms'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'original footer and mascot occupy the legacy layout without added controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        onboarding: FakeOnboardingRepository(completed: false),
      );
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Back to chapters'), findsNothing);
      expect(find.textContaining('Chapter 1 of'), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-mascot')), findsOneWidget);
      expect(find.text('Tap a page or swipe to turn.'), findsOneWidget);
      final primary = tester.getRect(find.byType(OnboardingPrimaryButton));
      final terms = tester.getRect(
        find.byKey(const ValueKey('onboarding-terms')),
      );
      expect(primary.bottom, lessThan(terms.top));
      expect(terms.bottom, lessThanOrEqualTo(844 - 16));
      await tester.tap(find.text("Let's begin"));
      await tester.pumpAndSettle();
      final caption = tester.widget<Text>(
        find.text('Your story starts with you.'),
      );
      expect(caption.style!.fontFamily, 'Allura_regular');
      expect(find.text('Back to chapters'), findsNothing);
      tester.view.viewInsets = FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('onboarding-terms')), findsNothing);
      expect(find.text('Your story starts with you.'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
