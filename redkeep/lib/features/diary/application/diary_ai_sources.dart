import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/diary_period.dart';
import '../domain/diary_document.dart';
import '../domain/diary_ai_contract.dart';
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
}
