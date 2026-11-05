import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/domain/ai_job.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_ai_contract.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';

import '../../support/fake_ai.dart';
import '../../support/pump_app.dart';
import '../ai/ai_jobs_test.dart' show dayOutput;

void main() {
  final date = DiaryPeriod(2026, 11, 4);
  late AppDatabase db;
  late DriftDiaryRepository diary;
  late MemoryAiTasks tasks;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    diary = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 4));
    final entry = await diary.save(
      id: 'a' * 32,
      date: date,
      text: const DiaryText(body: 'I felt calm while planting the garden.'),
      expectedRevision: 0,
    );
    final source = DiarySuggestionSource.fromEntries(date, [entry]);
    tasks = MemoryAiTasks()
      ..value = jsonEncode(
        AiJob(
          id: 'synthetic-job',
          operation: AiOperation.diaryDetails,
          key: date.key,
          created: DateTime.now().millisecondsSinceEpoch,
          provider: 'device',
          source: source.encode(),
          prompt: source.request(),
          phase: 'completed',
          text: dayOutput,
        ).json(),
      );
  });
  tearDown(() => db.close());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await pumpApp(
      tester,
      initialLocation: '/diary/${date.key}/title',
      aiEnabled: true,
      database: db,
      diary: diary,
      tasks: tasks,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tap(tester, find.byKey(const ValueKey('diary-day-ai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('diary-ai-title')), findsOneWidget);
  }

  testWidgets(
    'review accepts fields individually, preserves manual edits and only Save day writes them',
    (tester) async {
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('diary-ai-title')));
      await tap(tester, find.byKey(const ValueKey('diary-ai-mood')));
      await tap(tester, find.byKey(const ValueKey('diary-ai-apply')));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('diary-day-title-field')),
            )
            .controller!
            .text,
        'Garden morning',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('diary-day-themes-field')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => diary.watchDay(date).first))!.heading,
        isEmpty,
      );
      final suggested = find.text('Suggested by the Grand Maestar');
      expect(suggested, findsNWidgets(2));
      await tester.enterText(
        find.byKey(const ValueKey('diary-day-title-field')),
        'My own title',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(suggested, findsOneWidget, reason: 'Edited by hand, so not his.');
      await tap(tester, find.text('Save day'));
      final saved = (await tester.runAsync(() => diary.watchDay(date).first))!;
      expect(saved.heading, 'My own title');
      expect(saved.mood?.name, 'calm');
      expect(saved.themes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('the sheet speaks plainly and shows its evidence and portrait', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Here\'s what I found'), findsOneWidget);
    expect(find.text('“felt calm”'), findsOneWidget);
    expect(find.textContaining('AI task:'), findsNothing);
    final portrait = tester.widget<Image>(
      find.byKey(const ValueKey('diary-ai-maestar')),
    );
    final source = (portrait.image as ResizeImage).imageProvider as AssetImage;
    expect(source.assetName, 'assets/branding/grand_maestar.png');
    expect(find.text('Tick what to keep'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('diary-ai-title')));
    expect(find.text('Use what I ticked'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('diary-ai-title')));
    expect(find.text('Tick what to keep'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('a failed task explains itself without technical words', (
    tester,
  ) async {
    final old = AiJob.fromJson(
      jsonDecode(tasks.value!) as Map<String, dynamic>,
    );
    tasks.value = jsonEncode(old.copy(phase: 'failed').json());
    await pumpApp(
      tester,
      initialLocation: '/diary/${date.key}/title',
      aiEnabled: true,
      database: db,
      diary: diary,
      tasks: tasks,
    );
    await tap(tester, find.byKey(const ValueKey('diary-day-ai')));
    expect(find.text('I couldn’t finish'), findsOneWidget);
    expect(find.textContaining('Your details are unchanged.'), findsOneWidget);
    expect(find.text('Generate again'), findsOneWidget);
    expect(find.textContaining('failed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('the sheet stays usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('diary-ai-title')));
    await tap(tester, find.byKey(const ValueKey('diary-ai-apply')));
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('diary-day-title-field')),
          )
          .controller!
          .text,
      'Garden morning',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('closing the sheet does not raise the keyboard again', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: '/diary/${date.key}/title',
      aiEnabled: true,
      database: db,
      diary: diary,
      tasks: tasks,
    );
    await tester.pump(const Duration(milliseconds: 100));
    final themes = find.byKey(const ValueKey('diary-day-themes-field'));
    await tester.showKeyboard(themes);
    await tester.pumpAndSettle();
    bool focused() => tester
        .state<EditableTextState>(
          find.descendant(of: themes, matching: find.byType(EditableText)),
        )
        .widget
        .focusNode
        .hasFocus;
    expect(focused(), isTrue);
    await tap(tester, find.byKey(const ValueKey('diary-day-ai')));
    await tap(tester, find.text('Close'));
    expect(focused(), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('a source change rejects acceptance without changing the form', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('diary-ai-title')));
    await tester.runAsync(
      () => diary.save(
        id: 'a' * 32,
        date: date,
        text: const DiaryText(body: 'I went walking instead.'),
        expectedRevision: 1,
      ),
    );
    await tap(tester, find.byKey(const ValueKey('diary-ai-apply')));
    expect(find.textContaining('out of date'), findsOneWidget);
    expect(
      (await tester.runAsync(() => diary.watchDay(date).first))!.heading,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'computer suggestions for a brief good day expose all three review fields',
    (tester) async {
      final entry = await diary.save(
        id: 'a' * 32,
        date: date,
        text: const DiaryText(body: 'today was a good day'),
        expectedRevision: 1,
      );
      final source = DiarySuggestionSource.fromEntries(date, [entry]);
      tasks.value = jsonEncode(
        AiJob(
          id: 'computer-good-day',
          operation: AiOperation.diaryDetails,
          key: date.key,
          created: DateTime.now().millisecondsSinceEpoch,
          provider: 'companion',
          source: source.encode(),
          prompt: source.request(),
          accepted: true,
          phase: 'completed',
          text: jsonEncode({
            'title': 'A happy day',
            'mood': {'value': 'happy', 'evidence': 'a good day'},
            'themes': [
              {'label': 'Positivity', 'evidence': 'a good day'},
            ],
          }),
        ).json(),
      );
      await open(tester);
      expect(find.byKey(const ValueKey('diary-ai-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-ai-mood')), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-ai-themes')), findsOneWidget);
      expect(find.textContaining('left out'), findsNothing);
      expect(find.text('Generate again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'empty computer fields have explicit explanations instead of disappearing',
    (tester) async {
      final old = AiJob.fromJson(
        jsonDecode(tasks.value!) as Map<String, dynamic>,
      );
      tasks.value = jsonEncode(
        old
            .copy(
              text: jsonEncode({
                'title': '',
                'mood': {'value': 'calm', 'evidence': 'felt calm'},
                'themes': [],
              }),
            )
            .json(),
      );
      await pumpApp(
        tester,
        initialLocation: '/diary/${date.key}/title',
        aiEnabled: true,
        database: db,
        diary: diary,
        tasks: tasks,
      );
      await tap(tester, find.byKey(const ValueKey('diary-day-ai')));
      expect(find.text('Title: No title was suggested.'), findsOneWidget);
      expect(find.text('Themes: No themes were suggested.'), findsOneWidget);
      expect(find.textContaining('left out'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'a rejected title explains the single omission while preserving the mood',
    (tester) async {
      final old = AiJob.fromJson(
        jsonDecode(tasks.value!) as Map<String, dynamic>,
      );
      tasks.value = jsonEncode(
        old
            .copy(
              text: jsonEncode({
                'title': 'Winning the lottery',
                'mood': {'value': 'calm', 'evidence': 'felt calm'},
                'themes': [],
              }),
            )
            .json(),
      );
      await pumpApp(
        tester,
        initialLocation: '/diary/${date.key}/title',
        aiEnabled: true,
        database: db,
        diary: diary,
        tasks: tasks,
      );
      await tap(tester, find.byKey(const ValueKey('diary-day-ai')));
      expect(
        find.text(
          'Title: The suggestion could not be matched to this day’s writing.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('diary-ai-mood')), findsOneWidget);
      expect(
        find.text(
          '1 suggestion was left out after checking against your saved writing.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
