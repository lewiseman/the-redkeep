import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/ai/application/ai_preferences.dart';
import 'package:redkeep/features/ai/domain/ai_preferences.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/daily_question_controller.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/daily_question_contract.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/presentation/daily_diary_prompt.dart';
import 'package:redkeep/features/diary/presentation/diary_day_page.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_curl.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_prompt.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/fake_required_assets.dart';
import '../../support/warm_diary_faces.dart';

const initialQuestion = DailyQuestionView(
  question: DailyQuestion(text: 'Which moment would you like to remember?'),
  message: 'A hint beneath the question.',
);

class _QuestionController extends DailyQuestionController {
  _QuestionController(super.date);
  final activations = <bool>[];
  int requests = 0;
  @override
  DailyQuestionView build() => initialQuestion;
  @override
  void activate(bool value) => activations.add(value);
  @override
  Future<void> request({bool automatic = false}) async => requests++;
  void show(DailyQuestionView value) => state = value;
}

void main() {
  final today = DiaryPeriod(2026, 11, 2);

  for (final period in [
    DiaryPeriod.week(today.start),
    DiaryPeriod.month(today.year, today.month),
    DiaryPeriod.year(today.year),
  ]) {
    testWidgets(
      '${period.kind.name} live and preview prompts offer plain writing without questions',
      (tester) async {
        var builds = 0;
        final writes = <String?>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiEnabledProvider.overrideWithValue(true),
              aiPreferencesProvider.overrideWith(
                (ref) => Stream.value(const AiPreferences()),
              ),
              diaryClockProvider.overrideWithValue(
                () => DateTime(2026, 11, 2, 12),
              ),
              dailyQuestionProvider(period).overrideWith(() {
                builds++;
                return _QuestionController(period);
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    for (final active in [true, false])
                      DailyDiaryPrompt(
                        date: period,
                        active: active,
                        onWrite: writes.add,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(builds, 0);
        expect(find.byType(DiaryWritingPrompt), findsNWidgets(2));
        expect(
          tester
              .widgetList<DiaryWritingPrompt>(find.byType(DiaryWritingPrompt))
              .map((prompt) => prompt.text),
          everyElement(isNull),
        );
        expect(find.text(initialQuestion.question!.text), findsNothing);
        await tester.tap(find.byType(DiaryWritingPrompt).first);
        expect(writes, [null]);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final (hasEntries, textScale) in [
    (false, 1.0),
    (true, 1.0),
    (true, 3.0),
  ]) {
    testWidgets(
      'today question stays on the folding paper; entries=$hasEntries, text=$textScale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase(NativeDatabase.memory());
        final repository = DriftDiaryRepository(
          db,
          clock: () => DateTime(2026, 11, 2),
        );
        if (hasEntries) {
          await repository.saveConversation(
            id: 'a' * 32,
            date: today,
            conversation: DiaryAiConversation(
              turns: const [
                {'speaker': 'user', 'text': 'A short saved entry.'},
              ],
              createdAt: DateTime(2026, 11, 2),
            ),
            body: 'A short saved entry.',
            expectedRevision: 0,
          );
        }
        final questions = <_QuestionController>[];
        final router = GoRouter(
          initialLocation: '/diary/${today.key}',
          routes: [
            GoRoute(
              path: '/diary/:date',
              pageBuilder: (context, state) => NoTransitionPage(
                key: const ValueKey('diary-day'),
                // Today is the reader's default day.
                child: const Scaffold(body: DiaryDayPage()),
              ),
              routes: [
                GoRoute(
                  path: 'entries/:id/edit',
                  builder: (context, state) => Scaffold(
                    body: Text(
                      'Editor: ${state.extra}',
                      key: const ValueKey('editor-question'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                diaryRepositoryProvider.overrideWithValue(repository),
                diaryClockProvider.overrideWithValue(
                  () => DateTime(2026, 11, 2, 12),
                ),
                syncCanEditProvider.overrideWithValue(true),
                aiEnabledProvider.overrideWithValue(true),
                aiPreferencesProvider.overrideWith(
                  (ref) => Stream.value(const AiPreferences()),
                ),
                requiredAssetsProvider.overrideWith(
                  (ref) async => FakeRequiredAssets(),
                ),
                dailyQuestionProvider(today).overrideWith(() {
                  final controller = _QuestionController(today);
                  questions.add(controller);
                  return controller;
                }),
              ],
              child: MaterialApp.router(
                theme: RedkeepTheme.light,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: RenderingPolicyHost(
                    preferences: const AppearancePreferences(),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await warmDiaryFaces(tester);
          final controller = questions.single;
          final face = find.byKey(ValueKey('diary-face-${today.key}'));
          final live = find.byKey(const ValueKey('diary-live-content'));
          void expectMatchingPrompts(String question) {
            for (final surface in [live, face]) {
              expect(
                find.descendant(of: surface, matching: find.text(question)),
                findsOneWidget,
              );
              // Only the question: its hint and old controls stay off the page.
              expect(
                find.descendant(of: surface, matching: find.byType(TextButton)),
                findsNothing,
              );
              expect(
                find.descendant(
                  of: surface,
                  matching: find.text(initialQuestion.message!),
                ),
                findsNothing,
              );
              expect(
                find.descendant(
                  of: surface,
                  matching: find.text('A general question to help you start.'),
                ),
                findsNothing,
              );
              if (hasEntries) {
                final conversation = tester.widget<RawChip>(
                  find.descendant(of: surface, matching: find.byType(RawChip)),
                );
                expect(conversation.isEnabled, isTrue);
              }
            }
          }

          expectMatchingPrompts(initialQuestion.question!.text);
          final curl = tester.renderObject<RenderDiaryCurl>(
            find.descendant(of: face, matching: find.byType(DiaryPaperCurl)),
          );
          final captures = (
            curl.debugFrontCaptures,
            curl.debugBackCaptures,
            curl.debugShadowCaptures,
          );
          final paper = find.byKey(const ValueKey('diary-active-paper'));
          final gesture = await tester.startGesture(
            tester.getRect(paper).center,
          );
          await gesture.moveBy(const Offset(24, 0));
          for (var frame = 0; frame < 30; frame++) {
            await gesture.moveBy(const Offset(3, 0));
            await tester.pump(const Duration(milliseconds: 24));
            expectMatchingPrompts(initialQuestion.question!.text);
            expect((
              curl.debugFrontCaptures,
              curl.debugBackCaptures,
              curl.debugShadowCaptures,
            ), captures);
          }
          expect(curl.debugUsesCurl, isTrue);
          expect(controller.activations, isNotEmpty);
          expect(controller.activations, everyElement(isTrue));
          expect(controller.requests, 0);
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(
            tester.widget<DiaryScene>(find.byType(DiaryScene)).day.date,
            today,
          );
          const replacement = DailyQuestionView(
            question: DailyQuestion(text: 'What surprised you today?'),
          );
          controller.show(replacement);
          await tester.pumpAndSettle();
          await warmDiaryFaces(tester);
          expectMatchingPrompts(replacement.question!.text);
          expect(curl.debugFrontCaptures, captures.$1 + 1);
          expect(controller.activations, everyElement(isTrue));
          expect(controller.requests, 0);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.descendant(
              of: live,
              matching: find.byType(DiaryWritingPrompt),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: live,
              matching: find.byType(DiaryWritingPrompt),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('editor-question')))
                .data,
            'Editor: ${replacement.question!.text}',
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          router.dispose();
          await db.close();
        }
      },
    );
  }

  testWidgets(
    'a static prompt mirrors state without owning question activation',
    (tester) async {
      final controller = _QuestionController(today);
      final showPreview = ValueNotifier(true);
      addTearDown(showPreview.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiEnabledProvider.overrideWithValue(true),
            aiPreferencesProvider.overrideWith(
              (ref) => Stream.value(const AiPreferences()),
            ),
            diaryClockProvider.overrideWithValue(
              () => DateTime(2026, 11, 2, 12),
            ),
            dailyQuestionProvider(today).overrideWith(() => controller),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: showPreview,
              child: DailyDiaryPrompt(
                key: const ValueKey('live'),
                date: today,
                onWrite: (_) {},
                active: true,
              ),
              builder: (context, visible, child) => Column(
                children: [
                  child!,
                  if (visible)
                    DailyDiaryPrompt(
                      key: const ValueKey('preview'),
                      date: today,
                      onWrite: (_) {},
                      active: false,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(initialQuestion.question!.text), findsNWidgets(2));
      final activations = List<bool>.of(controller.activations);
      showPreview.value = false;
      await tester.pumpAndSettle();
      expect(controller.activations, activations);
      expect(controller.activations, everyElement(isTrue));
      showPreview.value = true;
      await tester.pumpAndSettle();
      expect(find.text(initialQuestion.question!.text), findsNWidgets(2));
      expect(controller.activations, activations);
      // Not ready yet, or unavailable: only the blank writing lines remain.
      for (final state in const [
        DailyQuestionView(busy: true, message: 'Asking for a question.'),
        DailyQuestionView(message: 'Questions are temporarily unavailable.'),
      ]) {
        controller.show(state);
        await tester.pumpAndSettle();
        expect(find.byType(DiaryWritingPrompt), findsNWidgets(2));
        expect(find.byType(TextButton), findsNothing);
        expect(find.text(state.message!), findsNothing);
        expect(
          find.byKey(const ValueKey('diary-prompt-question')),
          findsNothing,
        );
      }
      expect(controller.activations, everyElement(isTrue));
      expect(controller.requests, 0);
      await tester.pumpWidget(const SizedBox());
      expect(controller.activations.last, isFalse);
    },
  );
}
