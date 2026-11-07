import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/data/ai_preferences_repository.dart';
import 'package:redkeep/features/ai/domain/ai_operation.dart';
import 'package:redkeep/features/ai/domain/ai_route.dart';

void main() {
  const other = AiRoute.provider('b', 'other-model');
  const main = AiRoute.provider('a', 'main-model');
  late AppDatabase db;
  late AiPreferencesRepository prefs;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = AiPreferencesRepository(db);
  });
  tearDown(() => db.close());

  test('preferences have one durable row and independent changes preserve each other', () async {
    expect((await prefs.read()).defaultRoute, const AiRoute.companion());
    await prefs.setDefaultRoute(main);
    await prefs.questions(false);
    await prefs.collection('note', false);
    await prefs.voice({
      'name': 'synthetic',
      'engine': 'synthetic',
      'locale': 'en-US',
    });
    await prefs.setTaskRoute(AiOperation.diaryDetails, other);
    await prefs.collection('note', true);
    final stored = await prefs.read();
    expect(await db.select(db.aiPreferencesTable).get(), hasLength(1));
    expect(stored.defaultRoute, main);
    expect(stored.dailyQuestions, false);
    expect(stored.collections, {'note', 'diary', 'thought'});
    expect(stored.voice?['name'], 'synthetic');
    expect(stored.routeFor(AiOperation.diaryDetails), other);
    expect(stored.routeFor(AiOperation.dailyQuestion), main);
    await prefs.setTaskRoute(AiOperation.diaryDetails, null);
    expect((await prefs.read()).routeFor(AiOperation.diaryDetails), main);
  });

  test('exactly the 13 phone tasks can use a provider', () async {
    expect(AiOperation.values.where((o) => o.supportsProvider), hasLength(13));
    await prefs.setDefaultRoute(main);
    final stored = await prefs.read();
    for (final operation in AiOperation.values) {
      expect(
        stored.routeFor(operation),
        operation.supportsProvider ? main : const AiRoute.companion(),
        reason: operation.name,
      );
    }
  });

  test('malformed or unknown stored routes read as the computer', () async {
    for (final raw in [
      'not json',
      '[]',
      '{"default":{"kind":"provider"},"tasks":{"noteRewrite":7,"gone":{"kind":"companion"}}}',
    ]) {
      await db
          .into(db.aiPreferencesTable)
          .insertOnConflictUpdate(
            AiPreferencesTableCompanion(id: const Value(1), routes: Value(raw)),
          );
      final stored = await prefs.read();
      expect(stored.defaultRoute, const AiRoute.companion(), reason: raw);
      expect(stored.overrides, isEmpty, reason: raw);
    }
  });

  test('daily opt-in follows the resolved provider and any change revokes it', () async {
    expect((await prefs.read()).dailyQuestionMayRunAutomatically, isTrue);
    await prefs.setDefaultRoute(main);
    expect((await prefs.read()).dailyQuestionMayRunAutomatically, isFalse);
    await prefs.setDailyQuestionOptIn('a');
    expect((await prefs.read()).dailyQuestionMayRunAutomatically, isTrue);
    // Changing another task's route leaves it alone.
    await prefs.setTaskRoute(AiOperation.noteRewrite, other);
    expect((await prefs.read()).dailyQuestionOptIn, 'a');
    await prefs.setTaskRoute(AiOperation.dailyQuestion, other);
    final moved = await prefs.read();
    expect(moved.dailyQuestionOptIn, isNull);
    expect(moved.dailyQuestionMayRunAutomatically, isFalse);
    await prefs.setTaskRoute(AiOperation.dailyQuestion, null);
    expect((await prefs.read()).dailyQuestionMayRunAutomatically, isFalse);
  });

  test('a group route moves only that group and can be undone', () async {
    const notes = [AiOperation.noteRewrite, AiOperation.noteTone];
    await prefs.setTaskRoute(AiOperation.diaryDetails, other);
    await prefs.setTaskRoutes(notes, main);
    var stored = await prefs.read();
    expect(stored.overrides[AiOperation.noteRewrite], main);
    expect(stored.overrides[AiOperation.noteTone], main);
    expect(stored.overrides[AiOperation.diaryDetails], other);
    await prefs.setTaskRoutes(notes, null);
    stored = await prefs.read();
    expect(stored.overrides.keys, [AiOperation.diaryDetails]);
  });

  test('removing a provider clears its routes and opt-in', () async {
    await prefs.setDefaultRoute(main);
    await prefs.setDailyQuestionOptIn('a');
    await prefs.setTaskRoute(AiOperation.noteRewrite, main);
    await prefs.setTaskRoute(AiOperation.noteTone, other);
    await prefs.removeProvider('a');
    final stored = await prefs.read();
    expect(stored.defaultRoute, const AiRoute.companion());
    expect(stored.overrides, {AiOperation.noteTone: other});
    expect(stored.dailyQuestionOptIn, isNull);
  });
}
