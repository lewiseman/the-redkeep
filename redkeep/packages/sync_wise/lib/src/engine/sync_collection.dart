import 'dart:async';

import '../models/sync_status.dart';
import '../storage/sync_state_store.dart';
import 'sync_client.dart';

class SyncDocument {
  final String id;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  const SyncDocument({
    required this.id,
    required this.payload,
    this.status = SyncStatus.synced,
  });
}

abstract interface class SyncCollection {
  String get type;
  String get label;

  /// True when creations append into a shared document, such as a diary day.
  bool get requiresRemoteForCreation;
  FutureOr<List<String>> get allIds;
  FutureOr<List<String>> get pendingIds;
  FutureOr<SyncDocument?> read(String id);
  SyncDocument decode(Map<String, dynamic> payload);

  /// Read latest local data and commit synchronously. True means some fields
  /// were protected and must wait for another full sync before being replaced.
  FutureOr<bool> mergeRemote(SyncDocument document, {required DateTime now});
  SyncDocument appendCreations(
    SyncDocument? remote,
    List<PendingCreation> operations,
  );
  List<SyncDocument> migrateLegacy(
    List<RemoteDocument> documents,
    String primaryDeviceId,
  );
  FutureOr<void> markPending(String id);
  FutureOr<void> acknowledgeUpload(SyncDocument document);
  FutureOr<void> acknowledgeCreations(
    List<PendingCreation> operations,
    SyncDocument uploaded,
  );
  FutureOr<void> restrictToSecondary();
}
