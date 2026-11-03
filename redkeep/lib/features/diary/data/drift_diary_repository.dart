import 'dart:convert';

import '../../sync/data/drift_sync_store.dart';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/diary_document.dart';
import '../domain/diary_repository.dart';
import '../domain/diary_day_details.dart';
import '../domain/civil_date.dart';

class DriftDiaryRepository implements DiaryRepository {
  DriftDiaryRepository(this._db, {required this._clock})
    : _generation = _db.writingGeneration;
  final AppDatabase _db;
  final int _generation;
  final DateTime Function() _clock;

  void _validate(String id) {
    if (!isDiaryId(id)) throw const DiaryException(DiaryFailure.unavailable);
  }

  @override
  Stream<List<DiaryListing>> watchEntries({
    CivilDate? date,
    String search = '',
  }) {
    final conditions = <String>['deleted_at IS NULL'];
    final variables = <Variable>[];
    if (date != null) {
      conditions.add('date_key = ?');
      variables.add(Variable.withString(date.key));
    }
    for (final token
        in search.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
      conditions.add(
        '(instr(lower(title), lower(?)) > 0 OR instr(lower(body), lower(?)) > 0)',
      );
      variables.addAll([
        Variable.withString(token),
        Variable.withString(token),
      ]);
    }
    return _db
        .customSelect(
          'SELECT id, date_key, title FROM diary_entries WHERE ${conditions.join(' AND ')} ORDER BY date_key DESC, created_at, id',
          variables: variables,
          readsFrom: {_db.diaryEntries},
        )
        .watch()
        .map((rows) => rows.map(_listing).toList());
  }

  @override
  Stream<DiaryDay> watchDay(CivilDate date) =>
      (_db.select(
        _db.diaryDays,
      )..where((r) => r.dateKey.equals(date.key))).watchSingleOrNull().map(
        (r) => DiaryDay(
          date: date,
          heading: r?.heading ?? '',
          mood: DiaryMood.tryParse(r?.mood),
          themes: r == null
              ? const []
              : (jsonDecode(r.themes) as List).cast<String>(),
          revision: r?.revision ?? 0,
        ),
      );
  @override
  Future<void> renameDay(DiaryDay day, String heading) => saveDay(
    DiaryDay(
      date: day.date,
      heading: heading,
      mood: day.mood,
      themes: day.themes,
      revision: day.revision,
    ),
  );

  @override
  Future<void> saveDay(DiaryDay day) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      if (day.heading.length > 160) {
        throw const DiaryException(DiaryFailure.invalidHeading);
      }
      final themes = normalizeDiaryThemes(day.themes);

      final old = await (_db.select(
        _db.diaryDays,
      )..where((r) => r.dateKey.equals(day.date.key))).getSingleOrNull();
      if ((old?.revision ?? 0) != day.revision) {
        throw const DiaryException(DiaryFailure.staleRevision);
      }
      await _db
          .into(_db.diaryDays)
          .insertOnConflictUpdate(
            DiaryDaysCompanion.insert(
              dateKey: day.date.key,
              heading: day.heading,
              mood: Value(day.mood?.name),
              themes: Value(jsonEncode(themes)),
              revision: day.revision + 1,
            ),
          );
    });
  }

  DiaryListing _listing(QueryRow row) => DiaryListing(
    id: row.read<String>('id'),
    date: CivilDate.tryParse(row.read<String>('date_key'))!,
    title: row.read<String>('title'),
  );

  @override
  Stream<OpenDiaryEntry> watchDocument(String id) {
    _validate(id);
    // Observe tokens before loading one transactional document snapshot.
    return _db
        .customSelect(
          'SELECT (SELECT revision FROM diary_entries WHERE id = ?) AS source_revision',
          variables: [Variable.withString(id)],
          readsFrom: {_db.diaryEntries},
        )
        .watch()
        .asyncMap((_) => openDocument(id));
  }

  @override
  Future<OpenDiaryEntry> openDocument(String id) async {
    _validate(id);
    return _db.transaction(() async {
      final entry = await (_db.select(
        _db.diaryEntries,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      return OpenDiaryEntry(entry: entry == null ? null : _entry(entry));
    });
  }

  @override
  Future<DiaryEntry> save({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int expectedRevision,
  }) async {
    return _db.transaction(() async {
      await checkWritingAccess(
        _db,
        _generation,
        creating:
            (await (_db.select(
              _db.diaryEntries,
            )..where((r) => r.id.equals(id))).getSingleOrNull()) ==
            null,
        diaryDate: date.key,
        now: _clock(),
      );
      _validate(id);

      final snapshot = await openDocument(id);
      if (text.isEmpty) throw const DiaryException(DiaryFailure.empty);
      final old = snapshot.entry;
      if (old != null && old.date != date) {
        throw const DiaryException(DiaryFailure.unavailable);
      }
      if (old?.deletedAt != null || (old?.revision ?? 0) != expectedRevision) {
        throw const DiaryException(DiaryFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = expectedRevision + 1;
      if (old == null) {
        await _db
            .into(_db.diaryEntries)
            .insert(
              DiaryEntriesCompanion.insert(
                id: id,
                dateKey: date.key,
                title: text.title,
                body: text.body,
                revision: revision,
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      } else {
        final count =
            await (_db.update(_db.diaryEntries)..where(
                  (r) =>
                      r.id.equals(id) &
                      r.revision.equals(expectedRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  DiaryEntriesCompanion(
                    title: Value(text.title),
                    body: Value(text.body),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) {
          throw const DiaryException(DiaryFailure.staleRevision);
        }
      }
      return DiaryEntry(
        id: id,
        date: date,
        text: text,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteEntry(String id, int expectedRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);
      final now = _clock().toUtc().millisecondsSinceEpoch;
      final count =
          await (_db.update(_db.diaryEntries)..where(
                (r) =>
                    r.id.equals(id) &
                    r.revision.equals(expectedRevision) &
                    r.deletedAt.isNull(),
              ))
              .write(
                DiaryEntriesCompanion(
                  deletedAt: Value(now),
                  title: const Value(''),
                  body: const Value(''),
                  updatedAt: Value(now),
                  revision: Value(expectedRevision + 1),
                ),
              );
      if (count != 1) throw const DiaryException(DiaryFailure.staleRevision);
    });
  }

  DiaryEntry _entry(DiaryEntryRow r) => DiaryEntry(
    id: r.id,
    date: CivilDate.tryParse(r.dateKey)!,
    text: DiaryText(title: r.title, body: r.body),
    revision: r.revision,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    deletedAt: r.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAt!, isUtc: true),
  );
}
