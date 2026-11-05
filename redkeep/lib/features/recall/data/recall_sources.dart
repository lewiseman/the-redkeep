import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/recall.dart';

class RecallSources {
  RecallSources(this.db);
  final AppDatabase db;
  Future<List<RecallSource>> all(String kind) async {
    final table = switch (kind) {
      'note' => 'notes',
      'diary' => 'diary_entries',
      'thought' => 'flow_thoughts',
      _ => throw ArgumentError.value(kind),
    };
    final rows = await db
        .customSelect('SELECT * FROM $table WHERE deleted_at IS NULL')
        .get();
    return [for (final row in rows) _source(kind, row)];
  }

  Future<RecallSource?> read(String kind, String id) async {
    final table = switch (kind) {
      'note' => 'notes',
      'diary' => 'diary_entries',
      'thought' => 'flow_thoughts',
      _ => throw ArgumentError.value(kind),
    };
    final row = await db
        .customSelect(
          'SELECT * FROM $table WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _source(kind, row);
  }

  RecallSource _source(String kind, QueryRow row) {
    final title = kind == 'note' ? row.read<String>('title') : '';
    final body = row.read<String>('body');
    final created = DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('created_at'),
      isUtc: true,
    ).toLocal();
    final date = kind == 'diary'
        ? row.read<String>('date_key')
        : '${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
    return RecallSource(
      kind: kind,
      id: row.read<String>('id'),
      title: title,
      text: title.isEmpty ? body : '$title\n\n$body',
      date: date,
      revision: row.read<int>('revision'),
    );
  }

  Future<bool> current(RecallSource source) async {
    final value = await read(source.kind, source.id);
    return value?.revision == source.revision && value?.hash == source.hash;
  }
}
