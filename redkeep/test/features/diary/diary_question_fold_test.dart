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
import 'package:redkeep/features/diary/domain/civil_date.dart';
import 'package:redkeep/features/diary/domain/daily_question_contract.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/presentation/daily_diary_prompt.dart';
import 'package:redkeep/features/diary/presentation/diary_day_page.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_curl.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
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
  final today = CivilDate(2026, 11, 2);

  for (final (hasEntries, textScale) in [
    (false, 1.0),
    (true, 1.0),
    (true, 3.0),
  ]) {
    testWidgets(
      'today question and controls stay on the folding paper; entries=$hasEntries, text=$textScale',
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
                child: Scaffold(
                  body: DiaryDayPage(
                    date: CivilDate.tryParse(state.pathParameters['date']!),
                  ),
                ),
              ),
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
          final face = find.byKey(
            ValueKey('diary-face-${DateTime(2026, 11, 2).toIso8601String()}'),
          );
          final live = find.byKey(const ValueKey('diary-live-content'));
          void expectMatchingPrompts(String question, String message) {
            for (final surface in [live, face]) {
              for (final text in [
                question,
                message,
                'A general question to help you start.',
                'Another question',
                'Skip',
              ]) {
                expect(
                  find.descendant(of: surface, matching: find.text(text)),
                  findsOneWidget,
                );
              }
              if (hasEntries) {
                final conversation = tester.widget<RawChip>(
                  find.descendant(of: surface, matching: find.byType(RawChip)),
                );
                expect(conversation.isEnabled, isTrue);
              }
            }
          }

          expectMatchingPrompts(
            initialQuestion.question!.text,
            initialQuestion.message!,
          );
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
            expectMatchingPrompts(
              initialQuestion.question!.text,
              initialQuestion.message!,
            );
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
            message: 'An updated hint.',
          );
          controller.show(replacement);
          await tester.pumpAndSettle();
          await warmDiaryFaces(tester);
          expectMatchingPrompts(
            replacement.question!.text,
            replacement.message!,
          );
          expect(curl.debugFrontCaptures, captures.$1 + 1);
          expect(controller.activations, everyElement(isTrue));
          expect(controller.requests, 0);
          expect(tester.takeException(), isNull);
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
                onWrite: () {},
                active: true,
              ),
              builder: (context, visible, child) => Column(
                children: [
                  child!,
                  if (visible)
                    DailyDiaryPrompt(
                      key: const ValueKey('preview'),
                      date: today,
                      onWrite: () {},
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
      controller.show(
        const DailyQuestionView(busy: true, message: 'Asking for a question.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsNWidgets(2));
      expect(find.text('Asking for a question.'), findsNWidgets(2));
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      controller.show(
        const DailyQuestionView(
          message: 'Questions are temporarily unavailable.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ask for a question'), findsNWidgets(2));
      expect(
        find.text('Questions are temporarily unavailable.'),
        findsNWidgets(2),
      );
      expect(controller.activations, everyElement(isTrue));
      expect(controller.requests, 0);
      await tester.pumpWidget(const SizedBox());
      expect(controller.activations.last, isFalse);
    },
  );
}
