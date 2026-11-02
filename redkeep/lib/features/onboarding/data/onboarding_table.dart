import 'package:drift/drift.dart';

/// The single row exists only after the user finishes onboarding.
@DataClassName('OnboardingCompletionRow')
class OnboardingCompletion extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
