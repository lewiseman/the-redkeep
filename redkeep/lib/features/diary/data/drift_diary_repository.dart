import '../domain/diary_media_validation.dart';
import '../domain/diary_ai_contract.dart';
import '../domain/diary_photo.dart';
import '../domain/diary_ai_conversation.dart';

import 'dart:convert';

import '../../sync/data/drift_sync_store.dart';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/diary_document.dart';
import '../domain/diary_repository.dart';
import '../domain/diary_day_details.dart';
import '../domain/diary_period.dart';

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
  Stream<Set<DiaryPeriod>> watchSavedPeriods() => _db
      .customSelect(
        '''SELECT period_key FROM diary_entries
       WHERE deleted_at IS NULL AND (length(trim(body)) > 0 OR photos <> '[]' OR conversation IS NOT NULL)
       UNION SELECT period_key FROM diary_days
       WHERE length(trim(heading)) > 0 OR mood IS NOT NULL OR themes <> '[]' ''',
        readsFrom: {_db.diaryEntries, _db.diaryDays},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            ?DiaryPeriod.tryParse(row.read<String>('period_key')),
        },
      );

  @override
  Stream<List<DiaryListing>> watchEntries({
    DiaryPeriod? date,
    String search = '',
  }) {
    final conditions = <String>['deleted_at IS NULL'];
    final variables = <Variable>[];
    if (date != null) {
      conditions.add('period_key = ?');
      variables.add(Variable.withString(date.key));
    }
    for (final token
        in search.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
      conditions.add('instr(lower(body), lower(?)) > 0');
      variables.add(Variable.withString(token));
    }
    return _db
        .customSelect(
          'SELECT id, period_key FROM diary_entries WHERE ${conditions.join(' AND ')} ORDER BY period_key DESC, created_at, id',
          variables: variables,
          readsFrom: {_db.diaryEntries},
        )
        .watch()
        .map((rows) => rows.map(_listing).toList());
  }

  @override
  Stream<DiaryDay> watchDay(DiaryPeriod date) =>
      (_db.select(
        _db.diaryDays,
      )..where((r) => r.periodKey.equals(date.key))).watchSingleOrNull().map(
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
  Future<void> saveDay(DiaryDay day, {String? expectedEntries}) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      if (day.heading.length > 160) {
        throw const DiaryException(DiaryFailure.invalidHeading);
      }
      final themes = normalizeDiaryThemes(day.themes);
      if (expectedEntries != null) {
        final rows =
            await (_db.select(_db.diaryEntries)..where(
                  (e) =>
                      e.periodKey.equals(day.date.key) & e.deletedAt.isNull(),
                ))
                .get();
        final actual = DiarySuggestionSource.fromEntries(
          day.date,
          rows.map(_entry),
        ).encode();
        if (actual != expectedEntries) {
          throw const DiaryException(DiaryFailure.staleRevision);
        }
      }

      final old = await (_db.select(
        _db.diaryDays,
      )..where((r) => r.periodKey.equals(day.date.key))).getSingleOrNull();
      if ((old?.revision ?? 0) != day.revision) {
        throw const DiaryException(DiaryFailure.staleRevision);
      }
      await _db
          .into(_db.diaryDays)
          .insertOnConflictUpdate(
            DiaryDaysCompanion.insert(
              periodKey: day.date.key,
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
    date: DiaryPeriod.tryParse(row.read<String>('period_key'))!,
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
    required DiaryPeriod date,
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
      if (old?.photos.isNotEmpty == true) {
        throw const DiaryException(DiaryFailure.unavailable);
      }
      if (old != null && old.date != date) {
        throw const DiaryException(DiaryFailure.unavailable);
      }
      if (old?.deletedAt != null || (old?.revision ?? 0) != expectedRevision) {
        throw const DiaryException(DiaryFailure.staleRevision);
      }
      final now = DateTime.fromMillisecondsSinceEpoch(
        _clock().millisecondsSinceEpoch,
        isUtc: true,
      );
      final revision = expectedRevision + 1;
      if (old == null) {
        await _db
            .into(_db.diaryEntries)
            .insert(
              DiaryEntriesCompanion.insert(
                id: id,
                periodKey: date.key,
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
        photos: old?.photos ?? const [],
        conversation: old?.conversation,
      );
    });
  }

  @override
  Future<DiaryEntry> savePhotoStory({
    required String id,
    required DiaryPeriod date,
    required List<DiaryPhoto> photos,
    required int expectedRevision,
  }) => _saveRich(
    id: id,
    date: date,
    expectedRevision: expectedRevision,
    photos: photos,
  );

  @override
  Future<DiaryEntry> saveConversation({
    required String id,
    required DiaryPeriod date,
    required DiaryAiConversation conversation,
    required int expectedRevision,
    String? body,
  }) => _saveRich(
    id: id,
    date: date,
    expectedRevision: expectedRevision,
    conversation: conversation,
    body: body,
  );

  Future<DiaryEntry> _saveRich({
    required String id,
    required DiaryPeriod date,
    required int expectedRevision,
    List<DiaryPhoto>? photos,
    DiaryAiConversation? conversation,
    String? body,
  }) => _db.transaction(() async {
    _validate(id);
    final old = (await openDocument(id)).entry;
    await checkWritingAccess(
      _db,
      _generation,
      creating: old == null,
      diaryDate: date.key,
      now: _clock(),
    );
    if (old != null &&
            (old.date != date ||
                old.deletedAt != null ||
                old.revision != expectedRevision) ||
        old == null && expectedRevision != 0) {
      throw const DiaryException(DiaryFailure.staleRevision);
    }
    if (photos != null && (photos.isEmpty || old?.conversation != null) ||
        conversation != null &&
            (!conversation.hasUserTurn || old?.photos.isNotEmpty == true)) {
      throw const DiaryException(DiaryFailure.empty);
    }
    validateDiaryMedia(photos ?? const [], conversation);
    final now = DateTime.fromMillisecondsSinceEpoch(
      _clock().millisecondsSinceEpoch,
      isUtc: true,
    );
    final newPhotos = photos ?? const <DiaryPhoto>[];
    final text = photos != null
        ? DiaryPhoto.composeContent(photos)
        : body ?? old?.text.body ?? '';
    await _db
        .into(_db.diaryEntries)
        .insertOnConflictUpdate(
          DiaryEntriesCompanion.insert(
            id: id,
            periodKey: date.key,
            body: text,
            photos: Value(
              jsonEncode([for (final photo in newPhotos) photo.toJson()]),
            ),
            conversation: Value(
              conversation == null ? null : jsonEncode(conversation.toJson()),
            ),
            revision: expectedRevision + 1,
            createdAt: (old?.createdAt ?? now).millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    final kept = newPhotos.map((p) => p.path).toSet();
    for (final photo in old?.photos ?? const <DiaryPhoto>[]) {
      if (!kept.contains(photo.path)) {
        await _db
            .into(_db.diaryMediaOps)
            .insertOnConflictUpdate(
              DiaryMediaOpsCompanion.insert(
                path: photo.path,
                action: 'delete',
                owner: id,
                created: now.millisecondsSinceEpoch,
              ),
            );
      }
    }
    return (await openDocument(id)).entry!;
  });

  @override
  Future<void> deleteEntry(String id, int expectedRevision) async {
    return _db.transaction(() async {
      await checkWritingAccess(_db, _generation);
      _validate(id);
      final now = _clock().toUtc().millisecondsSinceEpoch;
      final previous = (await openDocument(id)).entry;
      for (final photo in previous?.photos ?? const <DiaryPhoto>[]) {
        await _db
            .into(_db.diaryMediaOps)
            .insertOnConflictUpdate(
              DiaryMediaOpsCompanion.insert(
                path: photo.path,
                action: 'delete',
                owner: id,
                created: now,
              ),
            );
      }
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
                  body: const Value(''),
                  // Rich metadata travels with the tombstone so an append or
                  // merge cannot erase the record's kind and source history.
                  // Owned image bytes are removed through the file journal.
                  updatedAt: Value(now),
                  revision: Value(expectedRevision + 1),
                ),
              );
      if (count != 1) throw const DiaryException(DiaryFailure.staleRevision);
    });
  }

  List<DiaryPhoto> _photos(String raw) {
    try {
      return [
        for (final p in jsonDecode(raw) as List)
          DiaryPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  DiaryAiConversation? _conversation(String? raw) {
    try {
      return raw == null ? null : DiaryAiConversation.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  DiaryEntry _entry(DiaryEntryRow r) => DiaryEntry(
    id: r.id,
    date: DiaryPeriod.tryParse(r.periodKey)!,
    text: DiaryText(body: r.body),
    photos: _photos(r.photos),
    conversation: _conversation(r.conversation),
    revision: r.revision,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    deletedAt: r.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.deletedAt!, isUtc: true),
  );
}
