import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/onboarding/presentation/onboarding_terms.dart';

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
    'inline Terms and Privacy links open the exact Redkeep destinations',
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
          'https://redkeep.lewiseman.com/terms.html',
          'https://redkeep.lewiseman.com/privacy.html',
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
      'link ${throws ? 'exception' : 'failure'} shows a safe message',
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
}
