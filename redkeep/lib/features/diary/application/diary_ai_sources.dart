import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import '../domain/diary_ai_contract.dart';
import '../domain/daily_question_contract.dart';
import '../domain/diary_repository.dart';
import 'diary_providers.dart';

final diaryAiSourcesProvider = Provider<DiaryAiSources>(
  (ref) => DiaryAiSources(ref.watch(diaryRepositoryProvider)),
);

class DiaryAiSources {
  DiaryAiSources(this.repository);
  final DiaryRepository repository;
  Future<List<DiaryEntry>> entries(DiaryPeriod date) async {
    final listings = await repository.watchEntries(date: date).first;
    final opened = await Future.wait(
      listings.map((l) => repository.openDocument(l.id)),
    );
    return [
      for (final item in opened)
        if (item.available && item.entry!.date == date) item.entry!,
    ];
  }

  Future<DiarySuggestionSource> day(DiaryPeriod date) async =>
      DiarySuggestionSource.fromEntries(date, await entries(date));
  Future<bool> current(DiarySuggestionSource source) async =>
      (await day(DiaryPeriod.tryParse(source.date)!)).encode() ==
      source.encode();
  Future<DailyQuestionSource> question(
    DiaryPeriod today,
    List<String> avoid,
  ) async {
    final days = <String, List<DiaryEntry>>{};
    for (var ago = 0; ago <= (today.isDay ? 7 : 0); ago++) {
      final date = ago == 0 ? today : today.shift(-ago);
      if (date != null) days[date.key] = await entries(date);
    }
    return DailyQuestionSource.select(
      today: today.key,
      day: (date) => days[date] ?? const [],
      avoid: avoid,
    );
  }

  Future<bool> questionCurrent(DailyQuestionSource source) async {
    final date = DiaryPeriod.tryParse(source.date)!;
    if ((await day(date)).fingerprint != source.basis) return false;
    for (final entry in [...source.today, ...source.prior]) {
      final opened = await repository.openDocument(entry.uuid);
      if (!opened.available ||
          opened.entry!.revision != entry.revision ||
          opened.entry!.date.key != entry.date ||
          entryQuestionText(opened.entry!) != entry.text) {
        return false;
      }
    }
    return true;
  }
}
