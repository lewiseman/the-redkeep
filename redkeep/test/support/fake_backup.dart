import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:sync_wise/sync_wise.dart';

/// Sign-in without Google: starts signed in as `owner` unless told otherwise.
class FakeBackupAuth implements SyncAuth {
  FakeBackupAuth({bool signedIn = true})
    : user = signedIn ? owner : null;
  static const owner = SyncAccount(id: 'owner', email: 'owner@example.test');
  SyncAccount? user;
  final _changes = StreamController<SyncAccount?>.broadcast();
  @override
  SyncAccount? get currentUser => user;
  @override
  bool get isSignedIn => user != null;
  @override
  Stream<SyncAccount?> get onAuthStateChanged => _changes.stream;
  @override
  Future<SyncAccount?> signIn() async {
    user = owner;
    _changes.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(null);
  }

  @override
  Future<SyncAccount?> trySilentSignIn() async => user;
}

/// A provider with no cloud: sessions come from [session] when set.
class FakeBackupBackend implements BackupBackend {
  FakeBackupBackend({bool signedIn = true, this.session})
    : auth = FakeBackupAuth(signedIn: signedIn);
  @override
  final FakeBackupAuth auth;
  BackupSession? Function()? session;
  var deletedAll = 0;
  var failDeleteAll = false;
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Google Drive';
  @override
  Future<BackupSession?> open() async =>
      auth.user == null ? null : (session?.call() ?? _EmptySession(this));
  @override
  void dispose() {}
}

class _EmptySession implements BackupSession {
  _EmptySession(this.backend);
  final FakeBackupBackend backend;
  @override
  BackupRemote get remote => _EmptyRemote(backend);
  @override
  void close() {}
}

class _EmptyRemote extends Fake implements BackupRemote {
  _EmptyRemote(this.backend);
  final FakeBackupBackend backend;
  @override
  Future<List<RemoteObject>> list({String? kind}) async => const [];
  @override
  Future<void> deleteAll({void Function(int, int)? onProgress}) async {
    if (backend.failDeleteAll) throw StateError('Remote deletion interrupted');
    backend.deletedAll++;
  }
}

class QuietNetwork extends Fake implements NetworkService {
  @override
  Stream<NetworkType> get onConnectivityChanged => const Stream.empty();
  @override
  Future<bool> isOnline() async => true;
  @override
  Future<bool> isUnmeteredConnection() async => true;
}

class FixedBackupState extends BackupStateNotifier {
  FixedBackupState(this.value);
  final BackupState value;
  @override
  BackupState build() => value;
}

class FixedBackupSettings extends BackupSettingsController {
  FixedBackupSettings([this.initial = const BackupSettings()]);
  final BackupSettings initial;
  final saved = <BackupSettings>[];
  @override
  Future<BackupSettings> build() async => initial;
  @override
  Future<void> save(BackupSettings next) async {
    saved.add(next);
    state = AsyncData(next);
  }
}

class RecordingSchedule implements BackupSchedule {
  final applied = <(BackupSettings, bool)>[];
  @override
  Future<void> apply(BackupSettings settings, {required bool signedIn}) async =>
      applied.add((settings, signedIn));
}

/// A real engine over a temporary state folder and [databasePath].
BackupEngine testBackupEngine(
  Directory state,
  BackupBackend backend, {
  String? databasePath,
  Future<bool> Function()? isEmpty,
  Future<bool> Function()? canRun,
}) => BackupEngine(
  config: BackupConfig(appId: 'redkeep', stateDirectory: state),
  source: SqliteBackupSource(
    databasePath: databasePath ?? '${state.path}/missing.sqlite',
    schemaVersion: AppDatabase.currentSchemaVersion,
  ),
  backend: backend,
  isEmpty: isEmpty ?? () async => false,
  canRun: canRun,
);
