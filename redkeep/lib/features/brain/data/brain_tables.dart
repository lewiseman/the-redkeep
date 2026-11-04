import 'package:drift/drift.dart';

@DataClassName('BrainAssignmentRow')
class BrainAssignmentsTable extends Table {
  @override
  String get tableName => 'brain_assignments';
  TextColumn get capability => text()();
  TextColumn get modelId => text()();
  TextColumn get source => text().withDefault(const Constant('device'))();
  @override
  Set<Column<Object>> get primaryKey => {capability};
  @override
  List<String> get customConstraints => [
    "CHECK (capability IN ('rewrite', 'summarize', 'reflect', 'diaryDetails', 'dailyQuestion'))",
    "CHECK (source = 'device')",
    'CHECK (length(model_id) BETWEEN 1 AND 100)',
  ];
}
