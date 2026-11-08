import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_ai_contract.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/presentation/diary_day_details_widgets.dart';

void main() {
  group('emoji validation', () {
    test('accepts exactly one emoji, including multi-codepoint sequences', () {
      for (final emoji in [
        '😊',
        '🥲',
        '❤️',
        '👍🏽',
        '✌🏿',
        '🧑🏽‍💻',
        '👩‍❤️‍💋‍👨',
        '👨‍👩‍👧‍👦',
        '🏳️‍🌈',
        '😵‍💫',
        '🇯🇵',
        '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
        '#️⃣',
      ]) {
        expect(isSingleEmoji(emoji), isTrue, reason: emoji);
        expect(DiaryMood.fromEmoji(emoji)?.emoji, emoji, reason: emoji);
      }
    });

    test('rejects text, several emoji and text-style symbols', () {
      for (final garbage in [
        '',
        ' ',
        'happy!',
        'a',
        '1',
        '©',
        '♀',
        '🏽',
        '😊😊',
        '😊 ',
        '😊 good',
        'x😊',
        '🇯',
        '‍😊',
        '😊‍',
        '<script>',
      ]) {
        expect(isSingleEmoji(garbage), isFalse, reason: garbage);
      }
      expect(DiaryMood.fromEmoji('😊😊'), isNull);
    });

    test('presets keep stored names; other emoji store themselves', () {
      expect(DiaryMood.tryParse('calm'), DiaryMood.calm);
      expect(DiaryMood.tryParse('😌'), DiaryMood.calm);
      expect(DiaryMood.calm.name, 'calm');
      expect(DiaryMood.calm.display, '😌 Calm');
      final custom = DiaryMood.fromEmoji('🥳')!;
      expect(custom.isPreset, isFalse);
      expect(custom.name, '🥳');
      expect(custom.display, '🥳');
      expect(DiaryMood.tryParse(custom.name), custom);
      expect(DiaryMood.tryParse('unknown'), isNull);
    });
  });

  group('AI mood parsing', () {
    final date = DiaryPeriod(2026, 11, 4);
    final source = DiarySuggestionSource.fromEntries(date, [
      DiaryEntry(
        id: 'a',
        date: date,
        text: const DiaryText(body: 'Finally shipped the app and celebrated.'),
        revision: 1,
        createdAt: DateTime.utc(2026, 11, 4),
        updatedAt: DateTime.utc(2026, 11, 4),
      ),
    ]);
    DiarySuggestions parse(Object? value, {String evidence = 'celebrated'}) =>
        DiarySuggestions.parse(
          jsonEncode({
            'title': '',
            'mood': {'value': value, 'evidence': evidence},
            'themes': [],
          }),
          source,
        );

    test('accepts any single emoji, including ZWJ and skin tones', () {
      for (final emoji in ['🥳', '🧑🏽‍💻', '🙌🏾', '😮‍💨']) {
        final result = parse(emoji);
        expect(result.mood.mood?.emoji, emoji);
        expect(result.mood.evidence, 'celebrated');
        expect(result.rejectedFields, isEmpty);
      }
      expect(parse(' 😊 ').mood.mood, DiaryMood.happy);
    });

    test('still reads contract 1 mood words', () {
      expect(parse('excited').mood.mood, DiaryMood.excited);
      expect(parse('mixed').mood.value, 'mixed');
      expect(parse('mixed').mood.mood, isNull);
      expect(parse('unclear', evidence: '').mood.mood, isNull);
    });

    test('an empty value means no mood and is not a rejection', () {
      final result = parse('', evidence: '');
      expect(result.mood.mood, isNull);
      expect(result.mood.evidence, '');
      expect(result.rejectedFields, isEmpty);
      expect(result.dropped, 0);
    });

    test('garbage or ungrounded moods are dropped, other fields survive', () {
      for (final garbage in ['🥳🥳', '🥳 yay', 'joyful', 'x' * 40]) {
        final result = parse(garbage);
        expect(result.mood.mood, isNull, reason: garbage);
        expect(result.rejectedFields, {'mood'}, reason: garbage);
        expect(result.dropped, 1);
      }
      expect(parse('🥳', evidence: 'won the lottery').mood.mood, isNull);
      expect(() => parse(1), throwsFormatException);
    });
  });

  group('storage', () {
    late AppDatabase db;
    late DriftDiaryRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftDiaryRepository(db, clock: () => DateTime.utc(2026, 11, 2));
    });
    tearDown(() => db.close());

    test(
      'custom emoji round-trip and existing preset rows still read',
      () async {
        final custom = DiaryPeriod(2026, 11, 2);
        await repo.saveDay(
          DiaryDay(date: custom, mood: DiaryMood.fromEmoji('👩‍❤️‍👨')),
        );
        expect((await repo.watchDay(custom).first).mood?.emoji, '👩‍❤️‍👨');

        // A row written by an earlier version keeps its preset name.
        final legacy = DiaryPeriod(2026, 11, 1);
        await db
            .into(db.diaryDays)
            .insert(
              DiaryDaysCompanion.insert(
                periodKey: legacy.key,
                heading: '',
                mood: const Value('tired'),
                revision: 1,
              ),
            );
        expect((await repo.watchDay(legacy).first).mood, DiaryMood.tired);
        expect(await repo.watchMoods().first, {
          legacy: DiaryMood.tired,
          custom: DiaryMood.fromEmoji('👩‍❤️‍👨'),
        });
        final row = await (db.select(
          db.diaryDays,
        )..where((r) => r.periodKey.equals(custom.key))).getSingle();
        expect(row.mood, '👩‍❤️‍👨');
      },
    );
  });

  group('picker', () {
    Future<List<DiaryMood?>> pump(
      WidgetTester tester, {
      DiaryMood? selected,
    }) async {
      final changes = <DiaryMood?>[];
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => RenderingPolicyScope(
            policy: RenderingPolicy(
              osReducedMotion: true,
              preferences: const AppearancePreferences(),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => DiaryMoodPicker(
                  selected: selected,
                  onChanged: (mood) => setState(() {
                    changes.add(mood);
                    selected = mood;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('presets stay one tap; Other opens the full picker', (
      tester,
    ) async {
      final changes = await pump(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('diary-day-mood-calm')));
      await tester.pump();
      expect(changes.last, DiaryMood.calm);

      await tester.tap(find.byKey(const ValueKey('diary-day-mood-other')));
      await tester.pumpAndSettle();
      expect(find.text('Pick any emoji'), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-emoji-picker')), findsOneWidget);
      // Smileys open first; the second smiley is not a preset.
      await tester.tap(find.text('😃').first);
      await tester.pumpAndSettle();
      expect(find.text('Pick any emoji'), findsNothing);
      expect(changes.last?.emoji, '😃');
      expect(changes.last?.isPreset, isFalse);
      // The chosen emoji now sits circled in the Other slot.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('diary-day-mood-other')),
          matching: find.text('😃'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('closing the picker keeps the current mood', (tester) async {
      final changes = await pump(tester, selected: DiaryMood.fromEmoji('🥳'));
      await tester.tap(find.byKey(const ValueKey('diary-day-mood-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('🥳'), findsOneWidget);
    });

    testWidgets('large text wraps all six choices without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('diary-day-mood-other')),
        findsOneWidget,
      );
    });
  });
}
