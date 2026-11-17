import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Reads a small JSON object. Missing or unreadable files read as null so a
/// torn write can never block backups; callers treat null as "start over".
Future<Map<String, dynamic>?> readJsonFile(File file) async {
  try {
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    return value is Map<String, dynamic> ? value : null;
  } on Object {
    return null;
  }
}

/// Write-to-temp, flush, rename: readers see the old or the new file only.
Future<void> writeJsonFile(File file, Map<String, Object?> value) async {
  await file.parent.create(recursive: true);
  final pending = File('${file.path}-pending');
  await pending.writeAsString(jsonEncode(value), flush: true);
  await pending.rename(file.path);
}

Future<void> deleteIfExists(FileSystemEntity entity) async {
  try {
    if (await entity.exists()) await entity.delete(recursive: true);
  } on FileSystemException {
    // Best effort: a leftover temp file is harmless and retried next run.
  }
}

enum BackupJobPhase { captured, uploaded, committed }

/// The durable state of one backup. It is written after every step so a
/// killed process resumes instead of starting again.
class BackupJob {
  final String id;
  final DateTime startedAt;
  final int schemaVersion;
  final String stagedPath;
  final int length;
  final String sha256;
  final String md5;
  final String? cipher;
  final String? filesManifestId;
  final String? sessionUri;
  final String? fileId;
  final BackupJobPhase phase;

  const BackupJob({
    required this.id,
    required this.startedAt,
    required this.schemaVersion,
    required this.stagedPath,
    required this.length,
    required this.sha256,
    required this.md5,
    this.cipher,
    this.filesManifestId,
    this.sessionUri,
    this.fileId,
    this.phase = BackupJobPhase.captured,
  });

  BackupJob copyWith({
    String? sessionUri,
    bool clearSession = false,
    String? fileId,
    String? filesManifestId,
    BackupJobPhase? phase,
  }) => BackupJob(
    id: id,
    startedAt: startedAt,
    schemaVersion: schemaVersion,
    stagedPath: stagedPath,
    length: length,
    sha256: sha256,
    md5: md5,
    cipher: cipher,
    filesManifestId: filesManifestId ?? this.filesManifestId,
    sessionUri: clearSession ? null : sessionUri ?? this.sessionUri,
    fileId: fileId ?? this.fileId,
    phase: phase ?? this.phase,
  );

  Map<String, Object?> toJson() => {
    'format': 1,
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'schema': schemaVersion,
    'staged': stagedPath,
    'length': length,
    'sha256': sha256,
    'md5': md5,
    'cipher': cipher,
    'files_manifest': filesManifestId,
    'session': sessionUri,
    'file_id': fileId,
    'phase': phase.name,
  };

  static BackupJob? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['format'] != 1) return null;
    try {
      return BackupJob(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        schemaVersion: json['schema'] as int,
        stagedPath: json['staged'] as String,
        length: json['length'] as int,
        sha256: json['sha256'] as String,
        md5: json['md5'] as String,
        cipher: json['cipher'] as String?,
        filesManifestId: json['files_manifest'] as String?,
        sessionUri: json['session'] as String?,
        fileId: json['file_id'] as String?,
        phase: BackupJobPhase.values.byName(json['phase'] as String),
      );
    } on Object {
      return null;
    }
  }
}

/// Outcome of finished runs, written only by the run holding the lock.
class BackupHistory {
  final DateTime? lastSuccess;
  final int? lastSize;
  final DateTime? lastAttempt;
  final DateTime? failingSince;
  final String? lastErrorKind;
  final String? lastErrorMessage;
  final bool failureNotified;
  const BackupHistory({
    this.lastSuccess,
    this.lastSize,
    this.lastAttempt,
    this.failingSince,
    this.lastErrorKind,
    this.lastErrorMessage,
    this.failureNotified = false,
  });

  Map<String, Object?> toJson() => {
    'last_success': lastSuccess?.toUtc().toIso8601String(),
    'last_size': lastSize,
    'last_attempt': lastAttempt?.toUtc().toIso8601String(),
    'failing_since': failingSince?.toUtc().toIso8601String(),
    'error_kind': lastErrorKind,
    'error_message': lastErrorMessage,
    'failure_notified': failureNotified,
  };

  static BackupHistory fromJson(Map<String, dynamic>? json) {
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    if (json == null) return const BackupHistory();
    return BackupHistory(
      lastSuccess: date(json['last_success']),
      lastSize: json['last_size'] is int ? json['last_size'] as int : null,
      lastAttempt: date(json['last_attempt']),
      failingSince: date(json['failing_since']),
      lastErrorKind: json['error_kind'] as String?,
      lastErrorMessage: json['error_message'] as String?,
      failureNotified: json['failure_notified'] == true,
    );
  }
}

/// An exclusive lock shared by the UI isolate and background workers.
///
/// The holder refreshes a heartbeat; a lock whose heartbeat is older than
/// [staleAfter] belonged to a killed process and is taken over.
class BackupLock {
  final File file;
  final Duration heartbeat;
  final Duration staleAfter;
  final DateTime Function() now;
  final String _token =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
  Timer? _timer;

  BackupLock(
    this.file, {
    this.heartbeat = const Duration(seconds: 15),
    this.staleAfter = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  bool get held => _timer != null;

  Future<bool> tryAcquire() async {
    if (held) return true;
    await file.parent.create(recursive: true);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await file.create(exclusive: true);
        await _beat();
        _timer = Timer.periodic(heartbeat, (_) => _beat());
        return true;
      } on FileSystemException {
        final current = await readJsonFile(file);
        final beat = DateTime.tryParse('${current?['beat']}');
        final stale =
            beat == null && await _olderThan(file, staleAfter) ||
            beat != null && now().difference(beat) > staleAfter;
        if (!stale) return false;
        await deleteIfExists(file);
      }
    }
    return false;
  }

  Future<bool> _olderThan(File file, Duration age) async {
    try {
      return now().difference(await file.lastModified()) > age;
    } on FileSystemException {
      return true;
    }
  }

  Future<void> _beat() async {
    try {
      // Written in place: the file must keep existing for exclusivity.
      await file.writeAsString(
        jsonEncode({'owner': _token, 'beat': now().toUtc().toIso8601String()}),
        flush: true,
      );
    } on FileSystemException {
      // The next beat retries; staleness allows two missed beats.
    }
  }

  Future<void> release() async {
    _timer?.cancel();
    _timer = null;
    final current = await readJsonFile(file);
    if (current == null || current['owner'] == _token) {
      await deleteIfExists(file);
    }
  }
}
