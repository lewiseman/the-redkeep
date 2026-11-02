/// Local completion only. A failed or interrupted completion remains incomplete.
abstract interface class OnboardingRepository {
  Future<bool> isComplete();
  Future<void> complete();
}
