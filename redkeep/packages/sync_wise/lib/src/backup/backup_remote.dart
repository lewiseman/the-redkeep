import 'dart:io';

import '../auth/sync_auth.dart';
import 'backup_models.dart';

/// Cloud storage for backups. Implementations scope every object to one app
/// and must refuse to read or delete objects they do not own.
abstract interface class BackupRemote {
  /// Owned objects, optionally of one [BackupProperties.kind].
  Future<List<RemoteObject>> list({String? kind});

  /// An owned object, or null when it is missing or belongs to someone else.
  Future<RemoteObject?> get(String id);

  /// Starts a resumable upload and returns a session that survives restarts.
  Future<String> createUploadSession({
    required String name,
    required int length,
    required Map<String, String> properties,
    String mimeType = 'application/octet-stream',
  });

  /// Sends [file] to [session], continuing from what the server already has.
  /// Throws [UploadSessionExpired] when the session must be recreated.
  Future<RemoteObject> upload({
    required String session,
    required File file,
    required int length,
    void Function(int sent)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> updateProperties(String id, Map<String, String> properties);

  /// Downloads into [target], resuming a partial file when the server allows.
  Future<void> download(
    String id,
    File target, {
    int? expectedLength,
    void Function(int received)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> delete(String id);

  /// Deletes everything this app stored, including legacy namespaces.
  Future<void> deleteAll({void Function(int done, int total)? onProgress});
}

class UploadSessionExpired implements Exception {
  const UploadSessionExpired();
}

/// One authenticated connection to a provider.
abstract interface class BackupSession {
  BackupRemote get remote;
  void close();
}

/// A provider: its sign-in and how to open sessions.
abstract interface class BackupBackend {
  String get id;
  String get displayName;
  SyncAuth get auth;

  /// Null when no account is signed in.
  Future<BackupSession?> open();
  void dispose();
}
