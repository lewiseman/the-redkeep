import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_database.dart';

/// Immutable app-owned copies. The primary database journals every staged file
/// before it exists, so a crash between file and entry commits is recoverable.
class DiaryPhotoStore {
  DiaryPhotoStore({this.db, Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
      _generation = db?.writingGeneration;
  static const folder = 'diary_photos';
  final AppDatabase? db;
  final int? _generation;
  final Future<Directory> Function() _supportDirectory;
  final _staged = <String>{};
  Future<Directory>? _support;
  Future<void> _tail = Future.value();
  bool _closed = false;
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<Directory> get _root => _support ??= _supportDirectory();
  void _check() {
    if (_closed ||
        db?.writingBlocked == true ||
        db != null && db!.writingGeneration != _generation) {
      throw StateError('Media session expired');
    }
  }

  static bool isOwned(String path) =>
      RegExp(r'^diary_photos/[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,5}$').hasMatch(path);
  Future<File?> _file(String path) async {
    if (!isOwned(path)) return null;
    final root = await _root;
    final directory = p.join(root.path, folder);
    if (await FileSystemEntity.type(directory, followLinks: false) ==
        FileSystemEntityType.link) {
      return null;
    }
    final file = File(p.join(root.path, path));
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.link) {
      return null;
    }
    return file;
  }

  Future<File?> resolve(String path, {String? expectedHash}) async {
    final file = await _file(path);
    if (file == null ||
        !await file.exists() ||
        await file.length() > 40 * 1024 * 1024) {
      return null;
    }
    final hash =
        expectedHash ?? RegExp(r'-([0-9a-f]{64})\.').firstMatch(path)?[1];
    if (hash != null &&
        sha256.convert(await file.readAsBytes()).toString() != hash) {
      return null;
    }
    return file;
  }

  Future<Uint8List?> read(String path, {String? expectedHash}) async {
    try {
      final file = await _file(path);
      if (file == null ||
          !await file.exists() ||
          await file.length() > 40 * 1024 * 1024) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty ||
          expectedHash != null && await digest(bytes) != expectedHash) {
        return null;
      }
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  Future<String> write(
    String id,
    Uint8List bytes, {
    String extension = '',
    String owner = '',
  }) => _serial(() async {
    _check();
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(id) ||
        bytes.isEmpty ||
        bytes.length > 40 * 1024 * 1024) {
      throw const FormatException('Invalid photo');
    }
    final ext = RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension.toLowerCase())
        ? extension.toLowerCase()
        : '.jpg';
    final path = '$folder/$id-${await digest(bytes)}$ext';
    final file = await _file(path);
    if (file == null) throw const FormatException('Invalid photo path');
    _staged.add(path);
    if (db != null) {
      await db!
          .into(db!.diaryMediaOps)
          .insertOnConflictUpdate(
            DiaryMediaOpsCompanion.insert(
              path: path,
              action: 'stage',
              owner: owner,
              created: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
    try {
      await file.parent.create(recursive: true);
      final partial = File('${file.path}.partial');
      await partial.writeAsBytes(bytes, flush: true);
      _check();
      await partial.rename(file.path);
      _check();
      return path;
    } catch (_) {
      _staged.remove(path);
      rethrow;
    }
  });
  void releaseStaged(Iterable<String> paths) => _staged.removeAll(paths);
  Future<void> _delete(String path) async {
    final file = await _file(path);
    if (file == null) {
      if (db != null) {
        await (db!.delete(
          db!.diaryMediaOps,
        )..where((r) => r.path.equals(path))).go();
      }
      return;
    }
    if (await file.exists()) await file.delete();
    final partial = File('${file.path}.partial');
    if (await partial.exists()) await partial.delete();
    if (db != null) {
      await (db!.delete(
        db!.diaryMediaOps,
      )..where((r) => r.path.equals(path))).go();
    }
  }

  Future<void> delete(Iterable<String> paths) => _serial(() async {
    _check();
    final live = db == null
        ? []
        : await (db!.select(
            db!.diaryEntries,
          )..where((r) => r.deletedAt.isNull())).get();
    final references = {
      for (final entry in live)
        for (final photo in (jsonDecode(entry.photos) as List).whereType<Map>())
          photo['path'],
    };
    for (final path in paths) {
      _staged.remove(path);
      if (!references.contains(path)) await _delete(path);
    }
  });
  Future<void> reconcile() => _serial(() async {
    _check();
    final database = db;
    if (database == null) return;
    final rows = await database.select(database.diaryMediaOps).get();
    final live = await (database.select(
      database.diaryEntries,
    )..where((r) => r.deletedAt.isNull())).get();
    final references = <String>{
      for (final entry in live)
        for (final photo in (jsonDecode(entry.photos) as List).whereType<Map>())
          if (photo['path'] is String) photo['path'] as String,
    };
    for (final row in rows) {
      _check();
      if (_staged.contains(row.path)) continue;
      if (references.contains(row.path)) {
        await (database.delete(
          database.diaryMediaOps,
        )..where((r) => r.path.equals(row.path))).go();
      } else {
        await _delete(row.path);
      }
    }
  });
  Future<void> clearAll() async {
    _closed = true;
    await _tail;
    final directory = Directory(p.join((await _root).path, folder));
    if (await directory.exists()) await directory.delete(recursive: true);
    _staged.clear();
  }

  static Future<String> digest(Uint8List bytes) async =>
      sha256.convert(bytes).toString();
}
