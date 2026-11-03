import 'dart:async';

import 'package:redkeep/features/onboarding/domain/onboarding_repository.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = true});
  bool completed;
  String? savedName;
  bool failRead = false;
  bool failSave = false;
  Completer<void>? readGate;
  Completer<void>? saveGate;
  int saves = 0;

  @override
  Future<String?> readName() async {
    await readGate?.future;
    if (failRead) throw StateError('Synthetic private onboarding read error');
    return completed ? savedName ?? 'Test Writer' : null;
  }

  @override
  Future<bool> isComplete() async => await readName() != null;

  @override
  Future<void> complete(String name) async {
    saves++;
    await saveGate?.future;
    if (failSave) throw StateError('Synthetic private onboarding save error');
    savedName = name;
    completed = true;
  }
}
