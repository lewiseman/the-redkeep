import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ai_provider.dart';

String aiUsageMonth(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}';

/// Estimated monthly spending, from each response's reported usage and the
/// saved prices. Costs are stored in millionths of a dollar.
class AiSpendLedger {
  AiSpendLedger(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  Future<double> spent([DateTime? at]) async {
    final row =
        await (db.select(db.aiUsageMonths)
              ..where((r) => r.month.equals(aiUsageMonth(at ?? clock()))))
            .getSingleOrNull();
    return (row?.costMicros ?? 0) / 1e6;
  }

  Stream<double> watchSpent() =>
      (db.select(db.aiUsageMonths)
            ..where((r) => r.month.equals(aiUsageMonth(clock()))))
          .watchSingleOrNull()
          .map((row) => (row?.costMicros ?? 0) / 1e6);

  /// Refuses a call whose worst case would pass the limit. Zero means none.
  Future<void> check(double limitUsd, double estimateUsd) async {
    if (limitUsd <= 0) return;
    if (await spent() + estimateUsd > limitUsd) {
      throw const AiProviderFailure(AiProviderFailureKind.spendLimit);
    }
  }

  Future<void> record(AiUsage usage, AiPrice price) async {
    final micros = (usage.cost(price) * 1e6).round();
    final month = aiUsageMonth(clock());
    await db.customStatement(
      'INSERT INTO ai_usage_months (month, cost_micros, input_tokens, output_tokens) '
      'VALUES (?, ?, ?, ?) ON CONFLICT(month) DO UPDATE SET '
      'cost_micros = cost_micros + excluded.cost_micros, '
      'input_tokens = input_tokens + excluded.input_tokens, '
      'output_tokens = output_tokens + excluded.output_tokens',
      [month, micros, usage.inputTokens, usage.outputTokens],
    );
    db.notifyUpdates({TableUpdate.onTable(db.aiUsageMonths)});
  }
}
