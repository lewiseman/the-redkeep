/// Why a backup or restore stopped. Hosts map these to their own copy.
enum BackupErrorKind {
  /// No network, or not the network the user allowed (e.g. Wi-Fi only).
  offline,

  /// Not signed in, or the account no longer grants access.
  auth,

  /// The cloud account is out of space.
  storageFull,

  /// The cloud provider failed or rejected the request.
  remote,

  /// Local files or the database could not be read or written.
  local,

  /// Downloaded or uploaded bytes did not match their checksum.
  corrupt,

  /// The backup was made by a newer app version.
  incompatible,

  /// Stopped by the user or the platform. Progress is kept.
  cancelled,

  /// Another backup or restore is already running.
  busy,

  /// A scheduled run found no user data. It never replaces a cloud backup
  /// with an empty one, e.g. right after a reinstall before restoring.
  empty,
}

class BackupException implements Exception {
  final BackupErrorKind kind;
  final String message;
  final Object? cause;
  const BackupException(this.kind, this.message, [this.cause]);

  /// Whether trying again later can succeed without user action.
  bool get retryable => switch (kind) {
    BackupErrorKind.offline ||
    BackupErrorKind.remote ||
    BackupErrorKind.busy ||
    BackupErrorKind.cancelled ||
    BackupErrorKind.local => true,
    _ => false,
  };

  @override
  String toString() => message;
}

/// What started a backup. Scheduled and automatic runs respect the
/// mobile-data setting; manual runs use any connection.
enum BackupTrigger { manual, scheduled, automatic }

enum BackupActivity {
  idle,

  /// Copying and compressing the database, or running hooks.
  preparing,
  uploading,

  /// Verifying, committing and removing older backups.
  finishing,
  downloading,
  restoring,
}

class BackupState {
  final BackupActivity activity;
  final int bytesDone;
  final int bytesTotal;
  final DateTime? lastSuccess;

  /// Compressed size of the newest backup, in bytes.
  final int? lastSize;
  final BackupException? error;
  final bool suspended;

  /// A job was interrupted and will resume where it stopped.
  final bool resumable;

  const BackupState({
    this.activity = BackupActivity.idle,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.lastSuccess,
    this.lastSize,
    this.error,
    this.suspended = false,
    this.resumable = false,
  });

  bool get busy => activity != BackupActivity.idle;

  /// Null while the total is unknown (indeterminate progress).
  double? get fraction =>
      bytesTotal <= 0 ? null : (bytesDone / bytesTotal).clamp(0.0, 1.0);

  BackupState copyWith({
    BackupActivity? activity,
    int? bytesDone,
    int? bytesTotal,
    DateTime? lastSuccess,
    int? lastSize,
    BackupException? error,
    bool clearError = false,
    bool? suspended,
    bool? resumable,
  }) => BackupState(
    activity: activity ?? this.activity,
    bytesDone: bytesDone ?? this.bytesDone,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    lastSuccess: lastSuccess ?? this.lastSuccess,
    lastSize: lastSize ?? this.lastSize,
    error: clearError ? null : error ?? this.error,
    suspended: suspended ?? this.suspended,
    resumable: resumable ?? this.resumable,
  );
}

/// A committed backup in the cloud.
class RemoteBackup {
  final String id;
  final DateTime createdAt;

  /// Stored (compressed) size in bytes.
  final int size;
  final String sha256;
  final String md5;
  final int schemaVersion;
  final String? deviceName;
  final String? filesManifestId;

  /// The [BackupCipher.id] the stored bytes were written with.
  final String cipherId;
  const RemoteBackup({
    required this.id,
    required this.createdAt,
    required this.size,
    required this.sha256,
    required this.md5,
    required this.schemaVersion,
    this.deviceName,
    this.filesManifestId,
    this.cipherId = 'plain',
  });
}

/// A provider object with the properties this package wrote.
class RemoteObject {
  final String id;
  final String name;
  final int size;
  final String? md5;
  final DateTime? createdTime;
  final Map<String, String> properties;
  const RemoteObject({
    required this.id,
    required this.name,
    required this.size,
    this.md5,
    this.createdTime,
    this.properties = const {},
  });
}

/// The storage format this version writes and reads. Objects without a
/// format were written by format 1. Restores skip backups in newer formats.
const backupFormatVersion = 1;

/// Property keys and values stored on remote objects.
abstract final class BackupProperties {
  static const format = 'swFormat';
  static const kind = 'swKind';
  static const state = 'swState';
  static const sha256 = 'swSha256';
  static const schema = 'swSchema';
  static const created = 'swCreated';
  static const device = 'swDevice';
  static const files = 'swFiles';
  static const cipher = 'swCipher';

  static const snapshot = 'snapshot';
  static const filesManifest = 'files-manifest';
  static const file = 'file';

  static const uploading = 'uploading';
  static const committed = 'committed';
}
