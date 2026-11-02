import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/appearance/data/drift_appearance_repository.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

void main() {
  test(
    'defaults do not seed a row; committed saves emit to subscribers',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(database);
      final events = <AppearancePreferences>[];
      final subscription = repository.watch().listen(events.add);
      addTearDown(subscription.cancel);

      expect(await repository.watch().first, const AppearancePreferences());
      expect(await database.select(database.appearanceSettings).get(), isEmpty);
      const changed = AppearancePreferences(
        theme: AppTheme.dark,
        reduceMotion: true,
      );
      final observed = repository.watch().firstWhere(
        (value) => value == changed,
      );
      await repository.save(changed);
      expect(await observed, changed);
      expect(events, contains(changed));

      // The same primary store has one authoritative appearance row.
      await repository.save(const AppearancePreferences(simplerEffects: true));
      expect(
        await database.select(database.appearanceSettings).get(),
        hasLength(1),
      );
    },
  );

  test(
    'all preferences survive close/reopen on a background SQLite executor',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'redkeep-preferences-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File.fromUri(directory.uri.resolve('preferences.sqlite'));

      for (final theme in AppTheme.values) {
        final expected = AppearancePreferences(
          theme: theme,
          reduceMotion: theme != AppTheme.light,
          simplerEffects: theme != AppTheme.dark,
        );
        final first = AppDatabase(NativeDatabase.createInBackground(file));
        try {
          await DriftAppearanceRepository(first).save(expected);
        } finally {
          await first.close();
        }
        final reopened = AppDatabase(NativeDatabase.createInBackground(file));
        try {
          expect(
            await DriftAppearanceRepository(reopened).watch().first,
            expected,
          );
        } finally {
          await reopened.close();
        }
      }
    },
  );

  test('separate repositories and databases remain isolated', () async {
    final first = AppDatabase(NativeDatabase.memory());
    try {
      await DriftAppearanceRepository(first)
          .save(const AppearancePreferences(theme: AppTheme.dark));
    } finally {
      await first.close();
    }
    final second = AppDatabase(NativeDatabase.memory());
    try {
      expect(
        await DriftAppearanceRepository(second).watch().first,
        const AppearancePreferences(),
      );
    } finally {
      await second.close();
    }
  });
}
