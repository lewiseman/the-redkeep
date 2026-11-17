import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/diary/data/diary_search_history_store.dart';

void main() {
  late AppDatabase db;
  late DiarySearchHistoryStore history;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    history = DiarySearchHistoryStore(db);
  });
  tearDown(() => db.close());

  test('keeps the last three searches, newest first', () async {
    for (final query in ['walk', 'coffee', 'rain', 'tea']) {
      await history.record(query);
    }
    expect(await history.watch().first, ['tea', 'rain', 'coffee']);
    expect(await db.select(db.diarySearchHistory).get(), hasLength(3));
  });

  test('a repeated search moves up instead of appearing twice', () async {
    for (final query in ['walk', 'coffee', 'rain']) {
      await history.record(query);
    }
    await history.record('  Walk  ');
    expect(await history.watch().first, ['Walk', 'rain', 'coffee']);
  });

  test('spacing is tidied and blank searches are ignored', () async {
    await history.record('  morning \n coffee ');
    await history.record('   ');
    expect(await history.watch().first, ['morning coffee']);
  });

  test('nothing is written while writing is blocked', () async {
    db.writingBlocked = true;
    await history.record('walk');
    expect(await history.watch().first, isEmpty);
  });
}
