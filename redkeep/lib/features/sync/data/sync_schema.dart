import '../../../core/storage/app_database.dart';

/// Triggers run in the same SQLite transaction as each authoritative write,
/// including tag changes and permanent removal. Drafts never enter the outbox.
Future<void> installSyncTriggers(AppDatabase db) async {
  for (final spec in [
    ('notes', 'note', 'id'),
    ('flow_thoughts', 'thought', 'id'),
    ('diary_entries', 'diary', 'period_key'),
    ('diary_days', 'diary', 'period_key'),
    ('note_tags', 'note', 'note_id'),
  ]) {
    final (table, type, field) = spec;
    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      final row = event == 'DELETE' ? 'OLD' : 'NEW';
      final removed = table == 'notes' || table == 'flow_thoughts'
          ? (event == 'DELETE' ? 1 : 0)
          : 0;
      final creation =
          event == 'INSERT' && table != 'diary_days' && table != 'note_tags'
          ? "INSERT OR IGNORE INTO sync_operations(type, id, document_id) VALUES ('$type', NEW.id, NEW.$field);"
          : '';
      await db.customStatement('''
        CREATE TRIGGER sync_${table}_${event.toLowerCase()}
        AFTER $event ON $table BEGIN
          $creation
          INSERT INTO sync_records(type, document_id, state, removed)
          VALUES ('$type', $row.$field, 'pending', $removed)
          ON CONFLICT(type, document_id) DO UPDATE SET state = 'pending', removed = $removed;
        END
      ''');
    }
  }
}

Future<void> seedSyncRecords(AppDatabase db) async {
  for (final spec in [
    ('notes', 'note', 'id'),
    ('flow_thoughts', 'thought', 'id'),
    ('diary_entries', 'diary', 'period_key'),
  ]) {
    await db.customStatement(
      "INSERT OR IGNORE INTO sync_operations(type, id, document_id) SELECT '${spec.$2}', id, ${spec.$3} FROM ${spec.$1} WHERE deleted_at IS NULL",
    );
  }
  for (final spec in [
    ('notes', 'note', 'id'),
    ('flow_thoughts', 'thought', 'id'),
    ('diary_entries', 'diary', 'period_key'),
    ('diary_days', 'diary', 'period_key'),
  ]) {
    await db.customStatement(
      "INSERT OR IGNORE INTO sync_records(type, document_id, state, removed) SELECT '${spec.$2}', ${spec.$3}, 'pending', 0 FROM ${spec.$1}",
    );
  }
}
