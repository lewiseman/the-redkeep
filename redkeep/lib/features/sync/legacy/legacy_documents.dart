// Remove with the legacy sync helper.
//
// Before whole-database backups, Redkeep synced one Drive file per note,
// diary day and watchlist item. This reads those documents (wire schema 1 for
// notes and the watchlist, 3 for diary days) and adds the ones this device
// does not have. It never changes or removes local writing: on a single
// device the local copy is always the newest.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../diary/domain/diary_day_details.dart';
import '../../diary/domain/diary_document.dart';
import '../../diary/domain/diary_period.dart';
import '../../diary/domain/diary_photo.dart';
import '../../notes/domain/note_details.dart';
import '../../watchlist/data/watchlist_sync.dart';

/// The document types the old sync stored.
const legacyDocumentTypes = ['note', 'diary', 'watch', 'watchlist', 'watchtaste'];

class LegacyDocuments {
  LegacyDocuments(this.db);
  final AppDatabase db;

  /// Validates a stored document. Throws [FormatException] when it is not a
  /// Redkeep document this version understands.
  static Map<String, dynamic> decode(String type, Map<String, dynamic> input) {
    var payload = input;
    final id = payload['id'];
    if (!legacyDocumentTypes.contains(type) ||
        !(type == 'diary' ? {3} : {1}).contains(payload['schema']) ||
        id is! String ||
        (type == 'diary'
            ? DiaryPeriod.tryParse(id) == null
            : !RegExp(r'^[a-f0-9]{32}$').hasMatch(id))) {
      throw const FormatException('Unsupported Redkeep document.');
    }
    if (payload['removed'] == true) return payload;
    if (type == 'diary') {
      if (payload['heading'] is! String ||
          (payload['heading'] as String).length > 160 ||
          payload['entries'] is! List) {
        throw const FormatException('Invalid diary day.');
      }
      if ((payload['mood'] != null &&
              (payload['mood'] is! String ||
                  DiaryMood.tryParse(payload['mood'] as String) == null)) ||
          (payload['themes'] != null &&
              (payload['themes'] is! List ||
                  (payload['themes'] as List).any((t) => t is! String)))) {
        throw const FormatException('Invalid diary day details.');
      }
      payload = {
        ...payload,
        'themes': normalizeDiaryThemes(
          (payload['themes'] as List? ?? const []).cast<String>(),
        ),
        'entries': [
          for (final item in payload['entries'] as List)
            {
              ...Map<String, dynamic>.from(item as Map),
              'photos': item['photos'] ?? [],
            },
        ],
      };
      final ids = <String>{};
      for (final item in payload['entries'] as List) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(item['id'] as String) ||
            !ids.add(item['id'] as String)) {
          throw const FormatException('Invalid diary entry.');
        }
        _validateText(item, title: false);
        _validateDiaryMedia(item);
      }
    } else if (watchlistTables.containsKey(type)) {
      validateWatchlistPayload(type, payload);
    } else {
      _validateText(payload, title: true);
      if (payload['details'] != null) {
        if (payload['details'] is! String) {
          throw const FormatException('Invalid note details.');
        }
        NoteDetails.decode(payload['details'] as String);
      }
      if (payload['pinned'] != 0 && payload['pinned'] != 1 ||
          payload['tags'] is! List ||
          (payload['tags'] as List).any(
            (t) => t is! String || t.isEmpty || t.length > 40,
          )) {
        throw const FormatException('Invalid note metadata.');
      }
    }
    return payload;
  }

  static void _validateDiaryMedia(Map<String, dynamic> item) {
    final photos = item['photos'];
    if (photos is! List ||
        photos.length > 100 ||
        jsonEncode(photos).length > 1000000) {
      throw const FormatException('Invalid diary photos.');
    }
    final ids = <String>{};
    for (final raw in photos) {
      final photo = DiaryPhoto.fromJson(Map<String, dynamic>.from(raw as Map));
      if (!ids.add(photo.id) ||
          !RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(photo.id) ||
          !RegExp(
            r'^diary_photos/[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,5}$',
          ).hasMatch(photo.path) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(photo.sha256)) {
        throw const FormatException('Invalid photo reference.');
      }
    }
    if (photos.isNotEmpty &&
        item['deleted_at'] == null &&
        item['body'] !=
            DiaryPhoto.composeContent([
              for (final p in photos)
                DiaryPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
            ])) {
      throw const FormatException('Photo writing does not match the story.');
    }
  }

  static void _validateText(Map<String, dynamic> p, {required bool title}) {
    if (p['body'] is! String ||
        (title && p['title'] is! String) ||
        p['created_at'] is! int ||
        p['updated_at'] is! int ||
        (p['deleted_at'] != null && p['deleted_at'] is! int)) {
      throw const FormatException('Invalid writing payload.');
    }
  }

  /// Adds the document's writing when this device does not have it.
  /// Returns how many notes, entries or items were added.
  Future<int> insertMissing(String type, Map<String, dynamic> raw) =>
      db.transaction(() async {
        final p = decode(type, raw);
        if (p['removed'] == true) return 0;
        final id = p['id'] as String;
        if (type == 'note') {
          final exists = await (db.select(
            db.notes,
          )..where((r) => r.id.equals(id))).getSingleOrNull();
          if (exists != null || p['deleted_at'] != null) return 0;
          await db
              .into(db.notes)
              .insert(
                NotesCompanion.insert(
                  id: id,
                  title: p['title'] as String,
                  body: p['body'] as String,
                  details: Value(p['details'] as String? ?? '{}'),
                  revision: 1,
                  createdAt: p['created_at'] as int,
                  updatedAt: p['updated_at'] as int,
                  pinned: Value(p['pinned'] == 1),
                ),
              );
          for (final tag in (p['tags'] as List).cast<String>().toSet()) {
            await db
                .into(db.noteTags)
                .insert(NoteTagsCompanion.insert(noteId: id, tag: tag));
          }
          return 1;
        }
        if (type == 'diary') {
          final day = await (db.select(
            db.diaryDays,
          )..where((r) => r.periodKey.equals(id))).getSingleOrNull();
          if (day == null &&
              ((p['heading'] as String).isNotEmpty ||
                  p['mood'] != null ||
                  (p['themes'] as List).isNotEmpty)) {
            await db
                .into(db.diaryDays)
                .insert(
                  DiaryDaysCompanion.insert(
                    periodKey: id,
                    heading: p['heading'] as String,
                    mood: Value(p['mood'] as String?),
                    themes: Value(jsonEncode(p['themes'])),
                    revision: 1,
                  ),
                );
          }
          var added = 0;
          for (final item
              in (p['entries'] as List).cast<Map<String, dynamic>>()) {
            if (item['deleted_at'] != null) continue;
            final exists = await (db.select(
              db.diaryEntries,
            )..where((r) => r.id.equals(item['id'] as String))).getSingleOrNull();
            if (exists != null) continue;
            await db
                .into(db.diaryEntries)
                .insert(
                  DiaryEntriesCompanion.insert(
                    id: item['id'] as String,
                    periodKey: id,
                    body: item['body'] as String,
                    photos: Value(jsonEncode(item['photos'] ?? [])),
                    revision: 1,
                    createdAt: item['created_at'] as int,
                    updatedAt: item['updated_at'] as int,
                    kind: Value(DiaryEntryKind.decode(item['kind']).name),
                  ),
                );
            added++;
          }
          return added;
        }
        final table = watchlistTables[type]!;
        final exists = await db
            .customSelect(
              'SELECT 1 FROM $table WHERE id = ?',
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        if (exists != null || p['deleted_at'] != null) return 0;
        await putWatchlistDocument(db, type, p);
        return 1;
      });
}
