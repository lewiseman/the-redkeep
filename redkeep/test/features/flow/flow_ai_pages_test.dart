import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/flow/data/drift_flow_repository.dart';
import 'package:redkeep/features/flow/data/drift_thought_reflections.dart';
import 'package:redkeep/features/flow/domain/thought_reflection_contract.dart';
import 'package:redkeep/features/recall/domain/recall_question_contract.dart';

import '../../support/fake_ai.dart';
import '../../support/fake_appearance_repository.dart';
import '../../support/fake_brain.dart';
import '../../support/notes_ai_harness.dart' show ReplyModel;
import '../../support/pump_app.dart';

const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const body = 'Plant tulips beside the garden fence.';
const answerText = 'You wrote to plant tulips beside the garden fence.';
const answer =
    '{"status":"answered","answer":"$answerText","citations":["s0"]}';

void main() {
  late AppDatabase db;
  late DriftFlowRepository flow;
  late MemoryAiTasks tasks;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    flow = DriftFlowRepository(db, clock: DateTime.now);
    tasks = MemoryAiTasks();
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

  for (final simple in [false, true]) {
    testWidgets(
      'local reflection review, explicit Flow answers and shared history at 320px/3x; simple=$simple',
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
        final assignments = FakeBrainAssignments()
          ..values[BrainCapability.rewrite] = qualifiedBrainModel.id;
        var generations = 0;
        final router = await pumpApp(
          tester,
          initialLocation: '/flow/$id',
          database: db,
          flow: flow,
          tasks: tasks,
          aiEnabled: true,
          repository: appearance,
          brainAssignments: assignments,
          brainLoader: (_, settings) async {
            generations++;
            return ReplyModel(answer, settings);
          },
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
          expect(generations, 0);
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
          expect(generations, 1);
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
          expect(generations, 1);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('AI task history'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/settings/brain/history');
          await tap(tester, find.textContaining('Flow question ·'));
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('flow-answer-text')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(answerText), findsOneWidget);
          expect(generations, 1);
          await tap(tester, find.text('Clear task'));
          expect(
            find.textContaining('preview is no longer retained'),
            findsOneWidget,
          );
          expect(find.text(answerText), findsNothing);
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
    'search restores its protected question, marks edited citations, and disables deleted sources without generation',
    (tester) async {
      final thought = (await flow.openDocument(id)).thought!;
      final selection = RecallQuestionSelection.select(
        kind: RecallKind.thought,
        question: 'Where are the tulips?',
        today: DateTime.now(),
        items: RecallItem.thoughts([thought]),
      );
      tasks.value = jsonEncode(
        AiJob(
          id: 'restored-question',
          operation: AiOperation.thoughtQuestion,
          key: 'thought-search',
          created: DateTime.now().millisecondsSinceEpoch,
          provider: 'device',
          prompt: selection.request(),
          source: selection.encode(),
          phase: 'completed',
          text: answer,
        ).json(),
      );
      await pumpApp(
        tester,
        initialLocation: '/flow/search',
        database: db,
        flow: flow,
        aiEnabled: true,
        tasks: tasks,
      );
      try {
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('flow-search-field')),
              )
              .controller!
              .text,
          'Where are the tulips?',
        );
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
        expect(find.text(answerText), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
    },
  );
}
