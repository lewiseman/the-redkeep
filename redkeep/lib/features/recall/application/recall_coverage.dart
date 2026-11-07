import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';

/// The kinds of writing search by meaning can cover, in display order.
const recallKinds = ['note', 'diary', 'thought'];

/// How much of one kind of writing is in the search index.
class RecallCoverage {
  const RecallCoverage({this.saved = 0, this.waiting = 0});

  /// Saved, undeleted sources of this kind.
  final int saved;

  /// Saved sources still waiting in the queue to be indexed.
  final int waiting;

  int get indexed => (saved - waiting).clamp(0, saved);
  double get fraction => saved == 0 ? 1 : indexed / saved;
}

/// Live, local counts only: no AI request or network call starts here.
final recallCoverageProvider =
    StreamProvider.autoDispose<Map<String, RecallCoverage>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      final parts = [
        for (final (kind, table) in [
          ('note', 'notes'),
          ('diary', 'diary_entries'),
          ('thought', 'flow_thoughts'),
        ])
          '''SELECT '$kind' AS kind,
            (SELECT COUNT(*) FROM $table WHERE deleted_at IS NULL) AS saved,
            (SELECT COUNT(*) FROM recall_queue q JOIN $table s
              ON s.id = q.source_id
              WHERE q.kind = '$kind' AND s.deleted_at IS NULL) AS waiting''',
      ];
      return db
          .customSelect(
            parts.join('\nUNION ALL\n'),
            readsFrom: {
              db.notes,
              db.diaryEntries,
              db.flowThoughts,
              db.recallQueue,
            },
          )
          .watch()
          .map(
            (rows) => {
              for (final row in rows)
                row.read<String>('kind'): RecallCoverage(
                  saved: row.read<int>('saved'),
                  waiting: row.read<int>('waiting'),
                ),
            },
          );
    });
