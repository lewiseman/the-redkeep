import 'package:drift/drift.dart';

/// Older completion-only rows retain a null name until the user supplies it.
@DataClassName('OnboardingCompletionRow')
class OnboardingCompletion extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable().customConstraint(
    'CHECK (name IS NULL OR length(trim(name)) BETWEEN 1 AND 160)',
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
