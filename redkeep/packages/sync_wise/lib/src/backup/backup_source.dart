import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'backup_models.dart';

/// What a backup contains. Implementations must be usable from a background
/// isolate while the app may also have the data open.
abstract interface class BackupSource {
  /// The version this app writes. Backups from newer versions are refused.
  int get schemaVersion;

  /// The live file a restore replaces.
  String get databasePath;

  /// Writes a consistent copy of the data to [target], which does not exist.
  Future<void> capture(File target);

  /// Checks a downloaded copy and returns its schema version.
  /// Throws [BackupException] when it is damaged or too new.
  Future<int> validate(File candidate);
}

/// Backs up one SQLite database.
///
/// Uses a separate read-only connection and `VACUUM INTO`, which produces a
/// compact, transactionally consistent copy while other connections keep
/// writing. Works for Drift, sqflite or raw sqlite3 databases.
class SqliteBackupSource implements BackupSource {
  @override
  final String databasePath;
  @override
  final int schemaVersion;
  final Duration busyTimeout;
  const SqliteBackupSource({
    required this.databasePath,
    required this.schemaVersion,
    this.busyTimeout = const Duration(seconds: 15),
  });

  @override
  Future<void> capture(File target) async {
    if (!await File(databasePath).exists()) {
      throw const BackupException(
        BackupErrorKind.local,
        'There is nothing to back up yet.',
      );
    }
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    final source = databasePath, out = target.path;
    final timeout = busyTimeout.inMilliseconds;
    try {
      await Isolate.run(() {
        final db = sqlite3.open(source, mode: OpenMode.readOnly);
        try {
          db.execute('PRAGMA busy_timeout = $timeout');
          db.execute('VACUUM INTO ?', [out]);
        } finally {
          db.close();
        }
      });
    } on Object catch (error) {
      throw BackupException(
        BackupErrorKind.local,
        'Could not copy the database for backup.',
        error,
      );
    }
  }

  @override
  Future<int> validate(File candidate) async {
    final path = candidate.path;
    final (String check, int version) result;
    try {
      result = await Isolate.run(() {
        final db = sqlite3.open(path, mode: OpenMode.readOnly);
        try {
          final check = db.select('PRAGMA integrity_check').first.values.first;
          final version = db.select('PRAGMA user_version').first.values.first;
          return ('$check', version is int ? version : 0);
        } finally {
          db.close();
        }
      });
    } on Object catch (error) {
      throw BackupException(
        BackupErrorKind.corrupt,
        'The backup could not be opened.',
        error,
      );
    }
    if (result.$1 != 'ok') {
      throw const BackupException(
        BackupErrorKind.corrupt,
        'The backup is damaged and was not restored.',
      );
    }
    if (result.$2 > schemaVersion) {
      throw const BackupException(
        BackupErrorKind.incompatible,
        'This backup was made by a newer version. Update the app to restore it.',
      );
    }
    return result.$2;
  }
}

/// Optional transformation of stored bytes, e.g. password encryption.
abstract interface class BackupCipher {
  /// Recorded with each backup; restore refuses an unknown id.
  String get id;
  Stream<List<int>> encode(Stream<List<int>> plain);
  Stream<List<int>> decode(Stream<List<int>> stored);
}

/// Stores bytes as they are. Cloud app folders are private to the app.
class PlainBackupCipher implements BackupCipher {
  const PlainBackupCipher();
  @override
  String get id => 'plain';
  @override
  Stream<List<int>> encode(Stream<List<int>> plain) => plain;
  @override
  Stream<List<int>> decode(Stream<List<int>> stored) => stored;
}
