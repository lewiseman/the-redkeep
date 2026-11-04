import '../../../core/storage/app_database.dart';

/// Runs inside every authoritative write, including sync imports. Drafts never
/// enter the outbox. Generation distinguishes writes even when revisions agree.
Future<void> installRecallTriggers(AppDatabase db) async {
  for (final spec in [
    ('notes', 'note', 'recall_notes'),
    ('diary_entries', 'diary', 'recall_diary'),
    ('flow_thoughts', 'thought', 'recall_flow'),
  ]) {
    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      final row = event == 'DELETE' ? 'OLD' : 'NEW';
      await db.customStatement(
        '''CREATE TRIGGER recall_${spec.$1}_${event.toLowerCase()}
        AFTER $event ON ${spec.$1}
        WHEN COALESCE((SELECT ${spec.$3} FROM ai_preferences_table WHERE id = 1), 1) = 1
        BEGIN
          INSERT INTO recall_queue(kind, source_id, generation)
          VALUES ('${spec.$2}', $row.id, 1)
          ON CONFLICT(kind, source_id) DO UPDATE SET generation = generation + 1;
        END''',
      );
    }
  }
}

Future<void> seedRecallQueue(AppDatabase db, {String? kind}) async {
  for (final spec in [
    ('notes', 'note'),
    ('diary_entries', 'diary'),
    ('flow_thoughts', 'thought'),
  ]) {
    if (kind != null && kind != spec.$2) continue;
    await db.customStatement(
      '''INSERT INTO recall_queue(kind, source_id, generation)
      SELECT '${spec.$2}', id, 1 FROM ${spec.$1} WHERE deleted_at IS NULL
      ON CONFLICT(kind, source_id) DO UPDATE SET generation = generation + 1''',
    );
  }
}
