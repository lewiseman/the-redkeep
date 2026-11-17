import 'package:drift/drift.dart';

/// Estimated cloud AI spending per calendar month (`YYYY-MM`).
@DataClassName('AiUsageMonthRow')
class AiUsageMonths extends Table {
  TextColumn get month => text()();
  IntColumn get costMicros => integer().withDefault(const Constant(0))();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {month};
}
