import 'package:drift/drift.dart';

@DataClassName('OnboardingCompletionRow')
class OnboardingCompletion extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().customConstraint(
    'NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 160)',
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
