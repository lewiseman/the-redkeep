import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where and how one app keeps its backups.
class BackupConfig {
  /// Identifies this app's objects in the cloud, e.g. `redkeep`.
  final String appId;

  /// Private local state: job journal, settings, staging and restore files.
  final Directory stateDirectory;

  /// Committed backups kept in the cloud. The newest is never removed until a
  /// newer one is committed.
  final int keepGenerations;

  /// An unfinished job older than this is captured again.
  final Duration jobMaxAge;

  /// Upload chunk size. Google Drive requires multiples of 256 KiB.
  final int chunkSize;

  /// Consecutive failed network attempts before a run gives up.
  final int retryAttempts;
  final Duration retryBaseDelay;
  final Duration lockHeartbeat;
  final Duration lockStaleAfter;

  BackupConfig({
    required this.appId,
    required this.stateDirectory,
    this.keepGenerations = 2,
    this.jobMaxAge = const Duration(hours: 24),
    this.chunkSize = 2 * 1024 * 1024,
    this.retryAttempts = 5,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.lockHeartbeat = const Duration(seconds: 15),
    this.lockStaleAfter = const Duration(minutes: 2),
  }) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,39}$').hasMatch(appId)) {
      throw ArgumentError.value(
        appId,
        'appId',
        'Use lowercase a-z, 0-9, _ or -',
      );
    }
    if (keepGenerations < 1) {
      throw ArgumentError.value(keepGenerations, 'keepGenerations');
    }
    if (chunkSize <= 0 || chunkSize % (256 * 1024) != 0) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'Use multiples of 256 KiB',
      );
    }
  }

  /// `<application support>/sync_wise/<appId>`, shared by every isolate.
  static Future<Directory> defaultStateDirectory(String appId) async =>
      Directory(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'sync_wise',
          appId,
        ),
      );

  String path(String name) => p.join(stateDirectory.path, name);
  Directory get staging => Directory(path('staging'));
  Directory get restoring => Directory(path('restore'));
}

/// Exponential backoff with jitter for transient network failures.
class BackupRetry {
  final int attempts;
  final Duration base;
  final Future<void> Function(Duration) sleep;
  final Random _random;
  BackupRetry({
    this.attempts = 5,
    this.base = const Duration(seconds: 1),
    Future<void> Function(Duration)? sleep,
    Random? random,
  }) : sleep = sleep ?? Future<void>.delayed,
       _random = random ?? Random();

  Duration delay(int failure) {
    final ms = base.inMilliseconds * (1 << failure.clamp(0, 8));
    return Duration(milliseconds: ms + _random.nextInt(ms ~/ 2 + 1));
  }
}
