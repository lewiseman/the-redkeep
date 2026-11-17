import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_storage.dart';

/// Swaps a validated database into place so that a crash at any point leaves
/// either the old or the restored database, never neither.
///
/// Call [finish] before the app opens its database on every launch.
abstract final class RestoreRecovery {
  static const _journal = 'restore.json';
  static const previousSuffix = '.before-restore';
  static const _sideFiles = ['-journal', '-wal', '-shm'];

  /// Replaces [databasePath] with [candidate]. The database must be closed.
  /// The previous file is kept as `<database>.before-restore`.
  static Future<void> swap({
    required Directory stateDirectory,
    required String databasePath,
    required File candidate,
  }) async {
    final journal = File(p.join(stateDirectory.path, _journal));
    await writeJsonFile(journal, {
      'phase': 'swapping',
      'database': databasePath,
      'candidate': candidate.path,
    });
    await _complete(databasePath, candidate.path);
    await deleteIfExists(journal);
  }

  /// Completes or rolls back an interrupted [swap].
  static Future<void> finish({
    required Directory stateDirectory,
    required String databasePath,
  }) async {
    final journal = File(p.join(stateDirectory.path, _journal));
    final state = await readJsonFile(journal);
    if (state == null) {
      await deleteIfExists(journal);
      return;
    }
    if (state['database'] == databasePath && state['candidate'] is String) {
      await _complete(databasePath, state['candidate'] as String);
    }
    await deleteIfExists(journal);
  }

  /// Removes the copy kept by the last restore, e.g. after a new backup.
  static Future<void> discardPrevious(String databasePath) async {
    for (final suffix in ['', ..._sideFiles]) {
      await deleteIfExists(File('$databasePath$previousSuffix$suffix'));
    }
  }

  static Future<void> _complete(String database, String candidatePath) async {
    final live = File(database);
    final candidate = File(candidatePath);
    final previous = File('$database$previousSuffix');
    if (await candidate.exists()) {
      // The journal is only written after validation, so moving forward is
      // always what the user asked for.
      if (await live.exists()) {
        await RestoreRecovery.discardPrevious(database);
        // Side files move first: a journal must never be left beside a
        // database it does not belong to.
        for (final suffix in _sideFiles) {
          final side = File('$database$suffix');
          if (await side.exists()) {
            await side.rename('${previous.path}$suffix');
          }
        }
        await live.rename(previous.path);
      } else {
        for (final suffix in _sideFiles) {
          await deleteIfExists(File('$database$suffix'));
        }
      }
      await candidate.rename(database);
    } else if (!await live.exists() && await previous.exists()) {
      // The candidate vanished before it was moved: put the old data back.
      await previous.rename(database);
    }
  }
}
