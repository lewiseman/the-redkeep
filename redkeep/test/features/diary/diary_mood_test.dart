import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_day_details.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

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
}
