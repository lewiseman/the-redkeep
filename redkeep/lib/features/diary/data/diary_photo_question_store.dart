import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/storage_providers.dart';
import '../../../core/storage/app_database.dart';
import '../domain/diary_photo_question_contract.dart';

final diaryPhotoQuestionStoreProvider = Provider<DiaryPhotoQuestionStore>(
  (ref) => DiaryPhotoQuestionStore(ref.watch(appDatabaseProvider)),
);

class DiaryPhotoQuestionStore {
  DiaryPhotoQuestionStore(
    this.db, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _supportDirectory;
  final AppDatabase db;
  Future<void> _writes = Future.value();
  bool _closed = false;
  Future<Directory> get _root async =>
      Directory('${(await _supportDirectory()).path}/diary_photo_uploads');
  Future<File> _upload(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(id)) {
      throw ArgumentError('id');
    }
    return File('${(await _root).path}/$id.png');
  }

  Future<DiaryPhotoQuestions?> read(
    String key, {
    String? prefix,
    DateTime? now,
  }) async {
    final rows =
        await (db.select(db.photoQuestionCache)
              ..where(
                (r) =>
                    prefix == null ? r.key.equals(key) : r.key.like('$prefix%'),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.created)])
              ..limit(1))
            .get();
    final row = rows.firstOrNull;
    if (row == null ||
        row.created <
            (now ?? DateTime.now())
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch) {
      return null;
    }
    try {
      return DiaryPhotoQuestions.parse(row.value);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, DiaryPhotoQuestions value, {DateTime? now}) {
    final generation = db.writingGeneration;
    final next = _writes.then((_) async {
      if (_closed || db.writingBlocked || db.writingGeneration != generation) {
        throw StateError('Reset in progress');
      }
      await db
          .into(db.photoQuestionCache)
          .insertOnConflictUpdate(
            PhotoQuestionCacheCompanion.insert(
              key: key,
              value: jsonEncode(value.toJson()),
              created: (now ?? DateTime.now()).millisecondsSinceEpoch,
            ),
          );
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> remove(String key) async {
    await (db.delete(
      db.photoQuestionCache,
    )..where((r) => r.key.equals(key))).go();
  }

  Future<void> writeUpload(String id, Uint8List bytes) {
    final next = _writes.then((_) => _writeUpload(id, bytes));
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _writeUpload(String id, Uint8List bytes) async {
    final generation = db.writingGeneration;
    if (_closed || db.writingBlocked) throw StateError('Reset in progress');
    final file = await _upload(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (db.writingBlocked || db.writingGeneration != generation) {
      if (await file.exists()) await file.delete();
      throw StateError('Expired upload');
    }
  }

  Future<Uint8List?> readUpload(String id) async {
    final file = await _upload(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> deleteUpload(String id) async {
    await _writes;
    final file = await _upload(id);
    if (await file.exists()) await file.delete();
  }

  Future<void> prune({String? active, DateTime? now}) async {
    final root = await _root;
    if (await root.exists()) {
      await for (final file in root.list(followLinks: false)) {
        if (file is File &&
            file.uri.pathSegments.last != '$active.png' &&
            (await file.stat()).modified.isBefore(
              (now ?? DateTime.now()).subtract(const Duration(hours: 24)),
            )) {
          await file.delete();
        }
      }
    }
    await (db.delete(db.photoQuestionCache)..where(
          (r) => r.created.isSmallerThanValue(
            (now ?? DateTime.now())
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch,
          ),
        ))
        .go();
  }

  Future<void> clearAll() async {
    _closed = true;
    await _writes;
    final root = await _root;
    if (await root.exists()) await root.delete(recursive: true);
  }
}
