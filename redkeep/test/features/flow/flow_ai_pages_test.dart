import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/flow/data/drift_thought_reflections.dart';
import 'package:redkeep/features/flow/domain/thought_reflection_contract.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/fake_ai_provider.dart';
import '../../support/pump_app.dart';

const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const body = 'Plant tulips beside the garden fence.';
const answerText = 'You wrote to plant tulips beside the garden fence.';
const answer =
    '{"status":"answered","answer":"$answerText","citations":["s0"]}';

void main() {
  late AppDatabase db;
  late DriftFlowRepository flow;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    flow = DriftFlowRepository(db, clock: DateTime.now);
    await flow.save(id: id, body: body, expectedRevision: 0);
  });
  tearDown(() => db.close());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> settleQuestion(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  /// Presses the keyboard's search key.
  Future<void> submit(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settleQuestion(tester);
  }

  for (final simple in [false, true]) {
    testWidgets(
      'local reflection review and explicit Flow answers at 320px/3x; simple=$simple',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(
            theme: AppTheme.dark,
            reduceMotion: true,
            simplerEffects: simple,
          ),
        );
        addTearDown(appearance.close);
        final thought = (await flow.openDocument(id)).thought!;
        final reflections = DriftThoughtReflections(db, clock: DateTime.now);
        const reflection =
            'A place by the fence gives the tulips a spot in the garden.';
        await reflections.propose(
          'review-reflection',
          ThoughtReflectionSource.fromThought(thought),
          reflection,
        );
        final aiProvider = FakeAiProviderClient(answer);
        final router = await pumpApp(
          tester,
          initialLocation: '/flow/$id',
          database: db,
          flow: flow,
          aiEnabled: true,
          repository: appearance,
          aiProvider: aiProvider,
        );
        try {
          await tap(tester, find.text('Keep reflection'));
          expect(
            (await tester.runAsync(
              () => db.select(db.flowReflections).getSingle(),
            ))!.body,
            reflection,
          );
          router.go('/flow/search');
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('flow-search-field')),
            'Where are the tulips?',
          );
          await settleQuestion(tester);
          expect(find.byKey(const ValueKey('flow-ask-ai')), findsNothing);
          await submit(tester);
          expect(aiProvider.requests, isEmpty);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('flow-ask-ai')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.byKey(const ValueKey('flow-ask-ai')), findsOneWidget);
          await tap(tester, find.byKey(const ValueKey('flow-ask-ai')));
          for (
            var i = 0;
            i < 20 &&
                find
                    .byKey(const ValueKey('flow-answer-text'))
                    .evaluate()
                    .isEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('flow-answer-text')),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(answerText), findsOneWidget);
          expect(aiProvider.requests, hasLength(1));
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('flow-search-field')),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('flow-search-field')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('flow-search-field')),
            'Saturday',
          );
          await settleQuestion(tester);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('flow-answer-text')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('“Where are the tulips?”'), findsOneWidget);
          expect(find.text(answerText), findsOneWidget);
          expect(aiProvider.requests, hasLength(1));
          expect(find.byTooltip('AI task history'), findsNothing);
          expect(
            (await tester.runAsync(
              () => db.select(db.flowReflections).getSingle(),
            ))!.body,
            reflection,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'typing filters by keyword; only the search key embeds the query and offers AI',
    (tester) async {
      final embedder = FakeEmbedder();
      final aiProvider = FakeAiProviderClient(answer);
      await pumpApp(
        tester,
        initialLocation: '/flow/search',
        database: db,
        flow: flow,
        aiEnabled: true,
        aiProvider: aiProvider,
        embedder: embedder,
      );
      try {
        await tester.enterText(
          find.byKey(const ValueKey('flow-search-field')),
          'tulips',
        );
        await settleQuestion(tester);
        expect(find.text(body), findsOneWidget);
        expect(embedder.batches, isEmpty);
        expect(find.byKey(const ValueKey('flow-ask-ai')), findsNothing);

        await submit(tester);
        expect(embedder.batches.expand((b) => b), contains('tulips'));
        await tap(tester, find.byKey(const ValueKey('flow-ask-ai')));
        for (
          var i = 0;
          i < 20 &&
              find.byKey(const ValueKey('flow-answer-text')).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.text(answerText), findsOneWidget);

        await flow.save(
          id: id,
          body: 'Plant tulips near the house.',
          expectedRevision: 1,
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Thought edited since this answer'),
          findsOneWidget,
        );
        await flow.deleteThought(id, 2);
        await tester.pumpAndSettle();
        final label = find.textContaining('Thought deleted');
        expect(label, findsOneWidget);
        final tile = tester.widget<ListTile>(
          find.ancestor(of: label, matching: find.byType(ListTile)),
        );
        expect(tile.onTap, isNull);
        expect(aiProvider.requests, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    },
  );
}
