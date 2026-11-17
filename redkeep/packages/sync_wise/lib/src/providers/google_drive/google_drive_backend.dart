import 'package:http/http.dart' as http;

import '../../backup/backup_config.dart';
import '../../backup/backup_remote.dart';
import 'google_auth_service.dart';
import 'google_drive_backup_remote.dart';

/// Google sign-in plus Drive `appDataFolder` storage.
class GoogleDriveBackend implements BackupBackend {
  @override
  final GoogleAuthService auth;
  final String appId;
  final int chunkSize;

  /// Older formats of this app's data, removed by account reset.
  final List<DriveNamespace> legacyNamespaces;
  final BackupRetry? retry;
  final bool _ownsAuth;

  GoogleDriveBackend({
    required this.appId,
    GoogleAuthService? auth,
    this.chunkSize = 2 * 1024 * 1024,
    this.legacyNamespaces = const [],
    this.retry,
  }) : auth = auth ?? GoogleAuthService(),
       _ownsAuth = auth == null;

  /// Uses [config]'s app id, chunk size and retry policy.
  factory GoogleDriveBackend.fromConfig(
    BackupConfig config, {
    GoogleAuthService? auth,
    List<DriveNamespace> legacyNamespaces = const [],
  }) => GoogleDriveBackend(
    appId: config.appId,
    auth: auth,
    chunkSize: config.chunkSize,
    legacyNamespaces: legacyNamespaces,
    retry: BackupRetry(
      attempts: config.retryAttempts,
      base: config.retryBaseDelay,
    ),
  );

  @override
  String get id => GoogleAuthService.defaultBackendId;
  @override
  String get displayName => 'Google Drive';

  @override
  Future<BackupSession?> open() async {
    final client = await auth.authenticatedClient();
    if (client == null) return null;
    return GoogleDriveSession(
      client,
      GoogleDriveBackupRemote(
        client,
        appId: appId,
        chunkSize: chunkSize,
        legacyNamespaces: legacyNamespaces,
        retry: retry,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsAuth) auth.dispose();
  }
}

class GoogleDriveSession implements BackupSession {
  /// The signed-in Drive client, for host-specific reads such as migrations.
  final http.Client client;
  @override
  final GoogleDriveBackupRemote remote;
  GoogleDriveSession(this.client, this.remote);

  @override
  void close() => client.close();
}
