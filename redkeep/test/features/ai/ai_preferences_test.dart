import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';

void main() {
  test('preferences have one durable row and independent changes preserve each other', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = AiPreferencesRepository(db);
    expect((await prefs.read()).mode, AiMode.auto);
    await prefs.mode(AiMode.device);
    await prefs.questions(false);
    await prefs.collection('note', false);
    await prefs.voice({
      'name': 'synthetic',
      'engine': 'synthetic',
      'locale': 'en-US',
    });
    await prefs.override(AiOperation.diaryDetails, AiMode.companion);
    await prefs.collection('note', true);
    final stored = await prefs.read();
    expect(await db.select(db.aiPreferencesTable).get(), hasLength(1));
    expect(stored.mode, AiMode.device);
    expect(stored.dailyQuestions, false);
    expect(stored.collections, {'note', 'diary', 'thought'});
    expect(stored.voice?['name'], 'synthetic');
    expect(stored.modeFor(AiOperation.diaryDetails), AiMode.companion);
    expect(stored.modeFor(AiOperation.dailyQuestion), AiMode.device);
    await prefs.override(AiOperation.diaryDetails, AiMode.auto);
    expect(
      (await prefs.read()).modeFor(AiOperation.diaryDetails),
      AiMode.device,
    );
  });
}
