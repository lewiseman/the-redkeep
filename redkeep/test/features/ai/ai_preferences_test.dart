import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';

void main() {
  late AppDatabase db;
  late AiPreferencesRepository prefs;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = AiPreferencesRepository(db);
  });
  tearDown(() => db.close());

  test('preferences have one durable row and independent changes preserve each other', () async {
    expect((await prefs.read()).collections, {'note', 'diary', 'thought'});
    await prefs.collection('note', false);
    await prefs.pause(true);
    var stored = await prefs.read();
    expect(await db.select(db.aiPreferencesTable).get(), hasLength(1));
    expect(stored.collections, {'diary', 'thought'});
    expect(stored.paused, isTrue);
    await prefs.collection('note', true);
    stored = await prefs.read();
    expect(stored.collections, {'note', 'diary', 'thought'});
    expect(stored.paused, isTrue);
  });
}
