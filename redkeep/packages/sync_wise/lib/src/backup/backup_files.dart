import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup_storage.dart';

/// A folder of user files backed up next to the database, e.g. photos.
///
/// Files are stored once per content hash, so renames and repeat backups
/// upload nothing new. Only the folders in [include] are scanned.
class BackupFileSet {
  /// Stable name used in the manifest, e.g. `photos`.
  final String name;
  final Directory root;

  /// Folders below [root] to include, e.g. `['diary_photos']`.
  final List<String> include;

  /// Return false to skip a file (e.g. temporary `.partial` files).
  final bool Function(String relativePath)? filter;

  const BackupFileSet({
    required this.name,
    required this.root,
    required this.include,
    this.filter,
  });

  Future<Map<String, BackupFileEntry>> scan(BackupHashCache cache) async {
    final result = <String, BackupFileEntry>{};
    for (final folder in include) {
      final directory = Directory(p.join(root.path, folder));
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p.posix.joinAll(
          p.split(p.relative(entity.path, from: root.path)),
        );
        if (filter?.call(relative) == false) continue;
        final entry = await cache.hash(entity, relative);
        if (entry != null) result[relative] = entry;
      }
    }
    return result;
  }
}

class BackupFileEntry {
  final String sha256;
  final int size;
  const BackupFileEntry(this.sha256, this.size);
  Map<String, Object> toJson() => {'sha256': sha256, 'size': size};
}

/// Remembers hashes by size and modification time so unchanged files are
/// not read again on every backup.
class BackupHashCache {
  final File file;
  Map<String, dynamic> _entries = {};
  BackupHashCache(this.file);

  Future<void> load() async {
    _entries = Map.of((await readJsonFile(file))?['files'] as Map? ?? {})
        .cast<String, dynamic>();
  }

  Future<void> save() => writeJsonFile(file, {'files': _entries});

  Future<BackupFileEntry?> hash(File file, String key) async {
    try {
      final stat = await file.stat();
      final cached = _entries[key];
      if (cached is Map &&
          cached['size'] == stat.size &&
          cached['modified'] == stat.modified.millisecondsSinceEpoch &&
          cached['sha256'] is String) {
        return BackupFileEntry(cached['sha256'] as String, stat.size);
      }
      final digest = await sha256.bind(file.openRead()).first;
      _entries[key] = {
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
        'sha256': '$digest',
      };
      return BackupFileEntry('$digest', stat.size);
    } on FileSystemException {
      // Deleted while scanning: it is simply not part of this backup.
      return null;
    }
  }
}

/// The manifest uploaded with a backup: which file content belongs where.
class BackupFilesManifest {
  final Map<String, Map<String, BackupFileEntry>> sets;
  const BackupFilesManifest(this.sets);

  List<int> encode() => utf8.encode(
    jsonEncode({
      'format': 1,
      'sets': {
        for (final set in sets.entries)
          set.key: {
            for (final file in set.value.entries) file.key: file.value.toJson(),
          },
      },
    }),
  );

  static BackupFilesManifest decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map || json['format'] != 1 || json['sets'] is! Map) {
      throw const FormatException('Unsupported files manifest.');
    }
    final sets = <String, Map<String, BackupFileEntry>>{};
    for (final set in (json['sets'] as Map).entries) {
      final files = <String, BackupFileEntry>{};
      for (final file in (set.value as Map).entries) {
        final path = '${file.key}';
        final value = file.value as Map;
        if (!isSafeRelativePath(path) ||
            value['sha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sha256'] as String) ||
            value['size'] is! int) {
          throw const FormatException('Unsafe files manifest entry.');
        }
        files[path] = BackupFileEntry(
          value['sha256'] as String,
          value['size'] as int,
        );
      }
      sets['${set.key}'] = files;
    }
    return BackupFilesManifest(sets);
  }

  Set<String> get hashes => {
    for (final set in sets.values)
      for (final entry in set.values) entry.sha256,
  };
}

/// Rejects absolute paths and `..` so a manifest cannot write outside a root.
bool isSafeRelativePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains('\\')) return false;
  return !p.posix.split(path).any((part) => part == '..' || part == '.');
}
