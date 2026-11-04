import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/brain/data/drift_brain_assignments.dart';
import 'package:redkeep/features/brain/domain/brain.dart';

void main() {
  test('all assignments persist through background close/reopen and clear independently', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brain-assignments-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.sqlite');
    var database = AppDatabase(NativeDatabase.createInBackground(file));
    var repository = DriftBrainAssignments(database);
    expect(await repository.read(), isEmpty);
    for (final capability in BrainCapability.values) {
      await repository.assign(capability, qualifiedBrainModel.id);
    }
    await database.close();
    database = AppDatabase(NativeDatabase.createInBackground(file));
    addTearDown(database.close);
    repository = DriftBrainAssignments(database);
    final saved = await repository.read();
    expect(
      saved.map((a) => a.capability).toSet(),
      BrainCapability.values.toSet(),
    );
    expect(
      saved.every(
        (a) => a.source == 'device' && a.modelId == qualifiedBrainModel.id,
      ),
      isTrue,
    );
    await repository.assign(BrainCapability.rewrite, 'retired-model');
    await repository.assign(BrainCapability.reflect, null);
    expect(
      {for (final a in await repository.read()) a.capability: a.modelId},
      {
        BrainCapability.rewrite: 'retired-model',
        BrainCapability.summarize: qualifiedBrainModel.id,
        BrainCapability.diaryDetails: qualifiedBrainModel.id,
        BrainCapability.dailyQuestion: qualifiedBrainModel.id,
      },
    );
  });

  test('database rejects invalid capabilities/sources and failed saves preserve assignment', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftBrainAssignments(database);
    await repository.assign(BrainCapability.rewrite, qualifiedBrainModel.id);
    for (final sql in [
      "INSERT INTO brain_assignments VALUES ('embed', 'x', 'device')",
      "INSERT INTO brain_assignments VALUES ('summarize', 'x', 'api')",
      "INSERT INTO brain_assignments VALUES ('reflect', '', 'device')",
    ]) {
      await expectLater(
        database.customStatement(sql),
        throwsA(isA<Exception>()),
      );
    }
    await database.customStatement(
      "CREATE TRIGGER fail_brain BEFORE UPDATE ON brain_assignments BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
    );
    await expectLater(
      repository.assign(BrainCapability.rewrite, 'another'),
      throwsA(isA<Exception>()),
    );
    expect((await repository.read()).single.modelId, qualifiedBrainModel.id);
  });
}
