/// A committed, nonblank local name determines whether onboarding is complete.
abstract interface class OnboardingRepository {
  Future<String?> readName();
  Future<bool> isComplete();
  Future<void> complete(String name);
}

String? normalizedOnboardingName(String? value) {
  final name = value?.trim();
  return name == null || name.isEmpty || name.length > 160 ? null : name;
}
