import 'dart:async';

import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/domain/appearance_repository.dart';

class FakeAppearanceRepository implements AppearanceRepository {
  FakeAppearanceRepository([this.value = const AppearancePreferences()]);

  AppearancePreferences value;
  final _changes = StreamController<AppearancePreferences>.broadcast();
  bool failRead = false;
  bool failSave = false;
  Completer<void>? saveGate;
  int saveCount = 0;

  @override
  Stream<AppearancePreferences> watch() async* {
    if (failRead) throw StateError('Synthetic read failure');
    yield value;
    yield* _changes.stream;
  }

  void emit(AppearancePreferences preferences) {
    value = preferences;
    _changes.add(preferences);
  }

  @override
  Future<void> save(AppearancePreferences preferences) async {
    saveCount++;
    await saveGate?.future;
    if (failSave) throw StateError('Synthetic save failure');
    emit(preferences);
  }

  Future<void> close() => _changes.close();
}
