import 'dart:async';

import 'package:redkeep/features/onboarding/domain/onboarding_repository.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = true});
  bool completed;
  bool failRead = false;
  bool failSave = false;
  Completer<void>? readGate;
  Completer<void>? saveGate;
  int saves = 0;

  @override
  Future<bool> isComplete() async {
    await readGate?.future;
    if (failRead) throw StateError('Synthetic private onboarding read error');
    return completed;
  }

  @override
  Future<void> complete() async {
    saves++;
    await saveGate?.future;
    if (failSave) throw StateError('Synthetic private onboarding save error');
    completed = true;
  }
}
