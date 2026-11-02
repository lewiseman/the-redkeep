import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/diary_document.dart';
import '../domain/diary_repository.dart';
import '../domain/civil_date.dart';

class DriftDiaryRepository implements DiaryRepository {
  DriftDiaryRepository(this._db, {required this._clock});
  final AppDatabase _db;
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
          revision: r?.revision ?? 0,
        ),
      );
  @override
  Future<void> renameDay(DiaryDay day, String heading) async {
    if (heading.length > 160) {
      throw const DiaryException(DiaryFailure.invalidHeading);
    }
    await _db.transaction(() async {
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
              heading: heading,
              revision: day.revision + 1,
            ),
          );
    });
  }

  @override
  Stream<List<DiaryListing>> watchDrafts() => _db
      .customSelect(
        'SELECT id, date_key, title FROM diary_drafts ORDER BY updated_at DESC, id',
        readsFrom: {_db.diaryDrafts},
      )
      .watch()
      .map((rows) => rows.map((r) => _listing(r)).toList());

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
          'SELECT (SELECT revision FROM diary_entries WHERE id = ?) AS source_revision, '
          '(SELECT draft_revision FROM diary_drafts WHERE id = ?) AS draft_revision',
          variables: [Variable.withString(id), Variable.withString(id)],
          readsFrom: {_db.diaryEntries, _db.diaryDrafts},
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
      final draft = await (_db.select(
        _db.diaryDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      return OpenDiaryEntry(
        entry: entry == null ? null : _entry(entry),
        draft: draft == null ? null : _draft(draft),
      );
    });
  }

  @override
  Future<DiaryDraft> putDraft({
    required String id,
    required CivilDate date,
    required DiaryText text,
    required int baseRevision,
    required int? expectedDraftRevision,
  }) async {
    _validate(id);
    return _db.transaction(() async {
      final old = await (_db.select(
        _db.diaryDrafts,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (old?.draftRevision != expectedDraftRevision ||
          (old != null && old.baseRevision != baseRevision)) {
        throw const DiaryException(DiaryFailure.draftChanged);
      }
      final source = await openDocument(id);
      if (source.date != null && source.date != date) {
        throw const DiaryException(DiaryFailure.unavailable);
      }
      final now = _clock().toUtc().millisecondsSinceEpoch;
      if (old != null) await discardDraft(id, old.draftRevision);
      final version = await _db
          .into(_db.diaryDrafts)
          .insert(
            DiaryDraftsCompanion.insert(
              id: id,
              dateKey: date.key,
              title: text.title,
              body: text.body,
              baseRevision: baseRevision,
              updatedAt: now,
            ),
          );
      return DiaryDraft(
        id: id,
        date: date,
        text: text,
        baseRevision: baseRevision,
        draftRevision: version,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      );
    });
  }

  @override
  Future<DiaryEntry> commitDraft(String id, int expectedDraftRevision) async {
    _validate(id);
    return _db.transaction(() async {
      final snapshot = await openDocument(id);
      final draft = snapshot.draft;
      if (draft == null || draft.draftRevision != expectedDraftRevision) {
        throw const DiaryException(DiaryFailure.draftChanged);
      }
      final old = snapshot.entry;
      if (old?.deletedAt != null ||
          (old?.revision ?? 0) != draft.baseRevision) {
        throw const DiaryException(DiaryFailure.staleRevision);
      }
      final now = _clock().toUtc();
      final revision = draft.baseRevision + 1;
      if (old == null) {
        await _db
            .into(_db.diaryEntries)
            .insert(
              DiaryEntriesCompanion.insert(
                id: id,
                dateKey: draft.date.key,
                title: draft.text.title,
                body: draft.text.body,
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
                      r.revision.equals(draft.baseRevision) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  DiaryEntriesCompanion(
                    title: Value(draft.text.title),
                    body: Value(draft.text.body),
                    revision: Value(revision),
                    updatedAt: Value(now.millisecondsSinceEpoch),
                  ),
                );
        if (count != 1) throw const DiaryException(DiaryFailure.staleRevision);
      }
      await discardDraft(id, expectedDraftRevision);
      return DiaryEntry(
        id: id,
        date: draft.date,
        text: draft.text,
        revision: revision,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteEntry(String id, int expectedRevision) async {
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
  }

  @override
  Future<void> discardDraft(String id, int expectedDraftRevision) async {
    _validate(id);
    final count =
        await (_db.delete(_db.diaryDrafts)..where(
              (r) =>
                  r.id.equals(id) &
                  r.draftRevision.equals(expectedDraftRevision),
            ))
            .go();
    if (count != 1) throw const DiaryException(DiaryFailure.draftChanged);
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
  DiaryDraft _draft(DiaryDraftRow r) => DiaryDraft(
    id: r.id,
    date: CivilDate.tryParse(r.dateKey)!,
    text: DiaryText(title: r.title, body: r.body),
    baseRevision: r.baseRevision,
    draftRevision: r.draftRevision,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
