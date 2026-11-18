import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../network/network_service.dart';
import 'backup_config.dart';
import 'backup_files.dart';
import 'backup_models.dart';
import 'backup_remote.dart';
import 'backup_settings.dart';
import 'backup_source.dart';
import 'backup_storage.dart';
import 'restore_recovery.dart';

/// Runs before a new snapshot is captured, e.g. a one-time data migration.
/// Throwing stops the backup without committing anything.
typedef BackupHook = Future<void> Function();

/// Shows backup progress outside the app, e.g. as a system notification.
abstract interface class BackupNotifier {
  /// [fraction] is null for indeterminate progress.
  Future<void> progress({required String title, double? fraction});
  Future<void> clear();
  Future<void> failed({required String title, required String body});
}

/// Text the engine passes to [BackupNotifier].
class BackupNotices {
  final String preparing;
  final String uploading;
  final String downloading;
  final String restoring;
  final String failedTitle;
  final String failedBody;

  /// A scheduled backup that keeps failing for this long notifies once.
  final Duration failureNoticeAfter;
  const BackupNotices({
    this.preparing = 'Preparing backup',
    this.uploading = 'Backing up',
    this.downloading = 'Downloading backup',
    this.restoring = 'Restoring backup',
    this.failedTitle = "Backup didn't finish",
    this.failedBody = 'Open the app to back up your data.',
    this.failureNoticeAfter = const Duration(days: 3),
  });
}

/// Pauses backups while an account reset runs.
abstract interface class BackupLifecycle {
  Future<void> suspendForReset({bool requireIdle = false});
  Future<void> resumeAfterReset({required bool completed});
}

class RestoreResult {
  final bool databaseRestored;

  /// Set when the database was restored but some files were not (yet).
  final BackupException? filesError;
  const RestoreResult({required this.databaseRestored, this.filesError});
}

/// Backs up one [BackupSource] (and optional [BackupFileSet]s) to a
/// [BackupBackend], one verified snapshot at a time.
///
/// Every step is journaled under [BackupConfig.stateDirectory]: a run that is
/// cancelled, loses its connection or is killed continues from the same
/// staged snapshot and the same resumable upload session. A new snapshot is
/// only marked committed after the provider's checksum matches, and older
/// snapshots are removed only after that, so a good backup always exists.
class BackupEngine implements BackupLifecycle {
  final BackupConfig config;
  final BackupSource source;
  final BackupBackend backend;
  final SyncNetwork? network;
  final BackupNotifier? notifier;
  final BackupNotices notices;
  final BackupCipher cipher;
  final List<BackupFileSet> fileSets;
  final List<BackupHook> beforeBackup;
  final String? deviceName;

  /// Checked before every run, e.g. "no account reset is pending". Needed
  /// because background isolates do not share in-memory state.
  final Future<bool> Function()? canRun;

  /// True when there is no user data. Scheduled and automatic runs skip an
  /// empty source; manual runs still back it up.
  final Future<bool> Function()? isEmpty;
  final DateTime Function() now;

  final _states = StreamController<BackupState>.broadcast();
  var _state = const BackupState();
  Future<BackupState>? _active;
  Future<RestoreResult>? _restoring;
  var _cancelled = false;
  var _suspended = false;
  DateTime? _lastNotice;
  double? _lastNoticeFraction;

  BackupEngine({
    required this.config,
    required this.source,
    required this.backend,
    this.network,
    this.notifier,
    this.notices = const BackupNotices(),
    this.cipher = const PlainBackupCipher(),
    this.fileSets = const [],
    this.beforeBackup = const [],
    this.deviceName,
    this.canRun,
    this.isEmpty,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  BackupState get state => _state;
  Stream<BackupState> get states => _states.stream;

  File get _journal => File(config.path('job.json'));
  File get _historyFile => File(config.path('history.json'));
  BackupSettingsStore get settingsStore =>
      BackupSettingsStore(File(config.path('settings.json')));

  void _emit(BackupState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// Reads the last result and any unfinished job from disk.
  Future<BackupState> load() async {
    final history = await readHistory();
    final job = BackupJob.fromJson(await readJsonFile(_journal));
    BackupException? error;
    if (history.lastErrorKind != null) {
      error = BackupException(
        BackupErrorKind.values.asNameMap()[history.lastErrorKind] ??
            BackupErrorKind.remote,
        history.lastErrorMessage ?? 'The last backup did not finish.',
      );
    }
    if (!_state.busy) {
      _emit(
        BackupState(
          lastSuccess: history.lastSuccess,
          lastSize: history.lastSize,
          error: error,
          suspended: _suspended,
          resumable: job != null,
        ),
      );
    }
    return _state;
  }

  Future<BackupHistory> readHistory() async =>
      BackupHistory.fromJson(await readJsonFile(_historyFile));

  Future<BackupSettings> readSettings() => settingsStore.read();
  Future<void> writeSettings(BackupSettings settings) =>
      settingsStore.write(settings);

  /// Whether the schedule says a backup should run now.
  Future<bool> isDue() async =>
      (await readSettings()).isDue((await readHistory()).lastSuccess, now());

  /// Stops after the current chunk. The job resumes on the next run.
  void cancel() => _cancelled = true;

  /// Backs up now, or joins a run already in progress in this isolate.
  /// Never throws: failures are reported in [BackupState.error].
  Future<BackupState> backUpNow({
    BackupTrigger trigger = BackupTrigger.manual,
  }) {
    if (_suspended) {
      return Future.value(
        _state.copyWith(
          error: const BackupException(
            BackupErrorKind.busy,
            'Finish the account reset before backing up.',
          ),
        ),
      );
    }
    return _active ??= _backup(trigger).whenComplete(() => _active = null);
  }

  Future<BackupState> _backup(BackupTrigger trigger) async {
    _cancelled = false;
    final lock = _lock();
    if (_restoring != null || !await lock.tryAcquire()) {
      return _state.copyWith(
        error: const BackupException(
          BackupErrorKind.busy,
          'A backup or restore is already running.',
        ),
      );
    }
    BackupSession? session;
    BackupJob? job;
    try {
      if (canRun != null && !await canRun!()) {
        throw const BackupException(
          BackupErrorKind.busy,
          'Finish the account reset before backing up.',
        );
      }
      _emit(
        _state.copyWith(
          activity: BackupActivity.preparing,
          bytesDone: 0,
          bytesTotal: 0,
          clearError: true,
        ),
      );
      await _notify(notices.preparing, null, force: true);
      await _checkNetwork(trigger);
      session = await backend.open();
      if (session == null) {
        throw const BackupException(
          BackupErrorKind.auth,
          'Sign in to back up.',
        );
      }
      final remote = session.remote;
      job = await _resumableJob();
      if (job == null) {
        if (trigger != BackupTrigger.manual &&
            isEmpty != null &&
            await isEmpty!()) {
          throw const BackupException(
            BackupErrorKind.empty,
            'Nothing to back up yet.',
          );
        }
        for (final hook in beforeBackup) {
          await hook();
        }
        job = await _capture();
      }
      if (fileSets.isNotEmpty &&
          job.phase == BackupJobPhase.captured &&
          job.filesManifestId == null) {
        job = await _uploadFiles(remote, job);
      }
      if (job.phase == BackupJobPhase.captured) {
        job = await _uploadSnapshot(remote, job);
      }
      _emit(_state.copyWith(activity: BackupActivity.finishing));
      if (job.phase == BackupJobPhase.uploaded) {
        job = await _commit(remote, job);
      }
      await _prune(remote, job);
      final finished = now();
      await writeJsonFile(
        _historyFile,
        BackupHistory(
          lastSuccess: finished,
          lastSize: job.length,
          lastAttempt: finished,
        ).toJson(),
      );
      await _discardJob(job);
      await RestoreRecovery.discardPrevious(source.databasePath);
      await notifier?.clear();
      final done = BackupState(lastSuccess: finished, lastSize: job.length);
      _emit(done);
      return done;
    } on Object catch (error) {
      final failure = classify(error);
      await _recordFailure(failure, trigger);
      final failed = BackupState(
        lastSuccess: _state.lastSuccess,
        lastSize: _state.lastSize,
        error: failure,
        suspended: _suspended,
        resumable: await _journal.exists(),
      );
      _emit(failed);
      return failed;
    } finally {
      session?.close();
      await lock.release();
    }
  }

  BackupLock _lock() => BackupLock(
    File(config.path('lock.json')),
    heartbeat: config.lockHeartbeat,
    staleAfter: config.lockStaleAfter,
  );

  Future<void> _checkNetwork(BackupTrigger trigger) async {
    final network = this.network;
    if (network == null) return;
    if (!await network.isOnline()) {
      throw const BackupException(
        BackupErrorKind.offline,
        'No internet connection.',
      );
    }
    if (trigger != BackupTrigger.manual &&
        !(await readSettings()).allowCellular &&
        !await network.isUnmeteredConnection()) {
      throw const BackupException(
        BackupErrorKind.offline,
        'Waiting for Wi-Fi.',
      );
    }
  }

  Future<void> _recordFailure(
    BackupException failure,
    BackupTrigger trigger,
  ) async {
    if (failure.kind == BackupErrorKind.busy ||
        failure.kind == BackupErrorKind.empty) {
      return;
    }
    await notifier?.clear();
    if (failure.kind == BackupErrorKind.cancelled) return;
    final history = await readHistory();
    final at = now();
    final since = history.failingSince ?? at;
    var notified = history.failureNotified;
    final last = history.lastSuccess;
    if (trigger != BackupTrigger.manual &&
        !notified &&
        at.difference(last ?? since) >= notices.failureNoticeAfter &&
        at.difference(since) >= notices.failureNoticeAfter) {
      await notifier?.failed(
        title: notices.failedTitle,
        body: notices.failedBody,
      );
      notified = true;
    }
    await writeJsonFile(
      _historyFile,
      BackupHistory(
        lastSuccess: history.lastSuccess,
        lastSize: history.lastSize,
        lastAttempt: at,
        failingSince: since,
        lastErrorKind: failure.kind.name,
        lastErrorMessage: failure.message,
        failureNotified: notified,
      ).toJson(),
    );
  }

  /// Maps provider, network and file errors to a [BackupException].
  static BackupException classify(Object error) {
    if (error is BackupException) return error;
    final text = '$error';
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        text.contains('ClientException')) {
      return BackupException(
        BackupErrorKind.offline,
        'The connection dropped. The backup will continue from where it stopped.',
        error,
      );
    }
    if (text.contains('storageQuotaExceeded')) {
      return BackupException(
        BackupErrorKind.storageFull,
        'Your Google storage is full.',
        error,
      );
    }
    if (text.contains('(401') ||
        text.contains('(403') ||
        text.contains('different sync account') ||
        text.contains('account changed')) {
      return BackupException(
        BackupErrorKind.auth,
        error is StateError
            ? error.message
            : 'Reconnect your account to continue backing up.',
        error,
      );
    }
    if (error is FileSystemException) {
      return BackupException(
        BackupErrorKind.local,
        'Could not read or write backup files on this device.',
        error,
      );
    }
    return BackupException(
      BackupErrorKind.remote,
      'The backup could not be completed. It will try again.',
      error,
    );
  }

  Future<void> _notify(
    String title,
    double? fraction, {
    bool force = false,
  }) async {
    final notifier = this.notifier;
    if (notifier == null) return;
    final at = now();
    if (!force &&
        _lastNotice != null &&
        at.difference(_lastNotice!) < const Duration(milliseconds: 700) &&
        (fraction == null ||
            _lastNoticeFraction == null ||
            (fraction - _lastNoticeFraction!).abs() < .05)) {
      return;
    }
    _lastNotice = at;
    _lastNoticeFraction = fraction;
    try {
      await notifier.progress(title: title, fraction: fraction);
    } on Object {
      // Notifications are optional; never fail a backup because of them.
    }
  }

  void _progress(BackupActivity activity, int done, int total, String title) {
    _emit(
      _state.copyWith(activity: activity, bytesDone: done, bytesTotal: total),
    );
    unawaited(_notify(title, total <= 0 ? null : done / total));
  }

  // ---- Job ------------------------------------------------------------------

  Future<void> _saveJob(BackupJob job) => writeJsonFile(_journal, job.toJson());

  Future<void> _discardJob(BackupJob? job) async {
    await deleteIfExists(_journal);
    await deleteIfExists(config.staging);
  }

  Future<BackupJob?> _resumableJob() async {
    final job = BackupJob.fromJson(await readJsonFile(_journal));
    if (job == null) {
      await _discardJob(null);
      return null;
    }
    if (job.phase != BackupJobPhase.captured) {
      if (job.fileId != null) return job;
    } else {
      final staged = File(job.stagedPath);
      final fresh =
          now().difference(job.startedAt) <= config.jobMaxAge &&
          !now().isBefore(job.startedAt.subtract(const Duration(hours: 1)));
      if (fresh &&
          job.schemaVersion == source.schemaVersion &&
          job.cipher == cipher.id &&
          p.isWithin(config.staging.path, staged.path) &&
          await staged.exists() &&
          await staged.length() == job.length) {
        return job;
      }
    }
    await _discardJob(job);
    return null;
  }

  Future<BackupJob> _capture() async {
    final staging = config.staging;
    await deleteIfExists(staging);
    await staging.create(recursive: true);
    final id = const Uuid().v4();
    final raw = File(p.join(staging.path, 'capture.sqlite'));
    await source.capture(raw);
    final compressed = File(p.join(staging.path, '$id.gz'));
    await _gzip(raw, compressed);
    await deleteIfExists(raw);
    var stored = compressed;
    if (cipher is! PlainBackupCipher) {
      stored = File(p.join(staging.path, '$id.bin'));
      await cipher.encode(compressed.openRead()).pipe(stored.openWrite());
      await deleteIfExists(compressed);
    }
    final digests = await _digests(stored);
    final job = BackupJob(
      id: id,
      startedAt: now(),
      schemaVersion: source.schemaVersion,
      stagedPath: stored.path,
      length: await stored.length(),
      sha256: digests.sha256,
      md5: digests.md5,
      cipher: cipher.id,
    );
    await _saveJob(job);
    return job;
  }

  static Future<void> _gzip(File input, File output) {
    final from = input.path, to = output.path;
    return Isolate.run(
      () =>
          File(from)
              .openRead()
              .transform(GZipCodec(level: 6).encoder)
              .pipe(File(to).openWrite()),
    );
  }

  static Future<void> _gunzip(File input, File output) {
    final from = input.path, to = output.path;
    return Isolate.run(
      () =>
          File(from)
              .openRead()
              .transform(gzip.decoder)
              .pipe(File(to).openWrite()),
    );
  }

  static Future<({String sha256, String md5})> _digests(File file) {
    final path = file.path;
    return Isolate.run(() async {
      final shaSink = _DigestSink(), md5Sink = _DigestSink();
      final shaInput = sha256.startChunkedConversion(shaSink);
      final md5Input = md5.startChunkedConversion(md5Sink);
      await for (final chunk in File(path).openRead()) {
        shaInput.add(chunk);
        md5Input.add(chunk);
      }
      shaInput.close();
      md5Input.close();
      return (sha256: '${shaSink.value}', md5: '${md5Sink.value}');
    });
  }

  // ---- Upload ---------------------------------------------------------------

  Future<BackupJob> _uploadSnapshot(BackupRemote remote, BackupJob job) async {
    final file = File(job.stagedPath);
    _progress(BackupActivity.uploading, 0, job.length, notices.uploading);
    RemoteObject? uploaded;
    for (var attempt = 0; uploaded == null; attempt++) {
      var session = job.sessionUri;
      if (session == null) {
        session = await remote.createUploadSession(
          name:
              '${config.appId}-${job.startedAt.toUtc().millisecondsSinceEpoch}.gz',
          length: job.length,
          mimeType: 'application/gzip',
          properties: {
            BackupProperties.format: '$backupFormatVersion',
            BackupProperties.kind: BackupProperties.snapshot,
            BackupProperties.state: BackupProperties.uploading,
            BackupProperties.sha256: job.sha256,
            BackupProperties.schema: '${job.schemaVersion}',
            BackupProperties.created:
                '${job.startedAt.toUtc().millisecondsSinceEpoch}',
            BackupProperties.cipher: cipher.id,
            if (deviceName != null)
              BackupProperties.device: _limit(deviceName!, 60),
            if (job.filesManifestId != null)
              BackupProperties.files: job.filesManifestId!,
          },
        );
        job = job.copyWith(sessionUri: session);
        await _saveJob(job);
      }
      try {
        uploaded = await remote.upload(
          session: session,
          file: file,
          length: job.length,
          onProgress: (sent) => _progress(
            BackupActivity.uploading,
            sent,
            job.length,
            notices.uploading,
          ),
          isCancelled: () => _cancelled,
        );
      } on UploadSessionExpired {
        job = job.copyWith(clearSession: true);
        await _saveJob(job);
        if (attempt >= 1) {
          throw const BackupException(
            BackupErrorKind.remote,
            'The upload session expired. The backup will try again.',
          );
        }
      }
    }
    if (uploaded.md5 != job.md5 || uploaded.size != job.length) {
      try {
        await remote.delete(uploaded.id);
      } on Object {
        // An uncommitted leftover is pruned by a later backup.
      }
      await _discardJob(job);
      throw const BackupException(
        BackupErrorKind.corrupt,
        'The uploaded backup did not match this device. It will be made again.',
      );
    }
    job = job.copyWith(fileId: uploaded.id, phase: BackupJobPhase.uploaded);
    await _saveJob(job);
    return job;
  }

  Future<BackupJob> _commit(BackupRemote remote, BackupJob job) async {
    final uploaded = await remote.get(job.fileId!);
    if (uploaded == null) {
      await _discardJob(job);
      throw const BackupException(
        BackupErrorKind.remote,
        'The uploaded backup disappeared. It will be made again.',
      );
    }
    await remote.updateProperties(job.fileId!, {
      BackupProperties.state: BackupProperties.committed,
    });
    job = job.copyWith(phase: BackupJobPhase.committed);
    await _saveJob(job);
    return job;
  }

  static String _limit(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);

  // ---- Files ----------------------------------------------------------------

  Future<BackupJob> _uploadFiles(BackupRemote remote, BackupJob job) async {
    final cache = BackupHashCache(File(config.path('files-cache.json')));
    await cache.load();
    final sets = <String, Map<String, BackupFileEntry>>{
      for (final set in fileSets) set.name: await set.scan(cache),
    };
    await cache.save();
    final stored = <String>{
      for (final object in await remote.list(kind: BackupProperties.file))
        if (object.properties[BackupProperties.state] ==
            BackupProperties.committed)
          object.properties[BackupProperties.sha256] ?? '',
    };
    final pending = <String, File>{};
    for (final set in fileSets) {
      for (final entry in sets[set.name]!.entries) {
        if (!stored.contains(entry.value.sha256)) {
          pending[entry.value.sha256] = File(
            p.joinAll([set.root.path, ...p.posix.split(entry.key)]),
          );
        }
      }
    }
    var total = 0, done = 0;
    for (final file in pending.values) {
      total += await file.length();
    }
    for (final MapEntry(key: hash, value: file) in pending.entries) {
      if (_cancelled) {
        throw const BackupException(
          BackupErrorKind.cancelled,
          'Backup paused. It will continue from here.',
        );
      }
      final length = await file.length();
      final digests = await _digests(file);
      if (digests.sha256 != hash) {
        throw const BackupException(
          BackupErrorKind.local,
          'A file changed during backup. It will try again.',
        );
      }
      final session = await remote.createUploadSession(
        name: 'file-$hash',
        length: length,
        properties: {
          BackupProperties.format: '$backupFormatVersion',
          BackupProperties.kind: BackupProperties.file,
          BackupProperties.state: BackupProperties.uploading,
          BackupProperties.sha256: hash,
        },
      );
      final base = done;
      final object = await remote.upload(
        session: session,
        file: file,
        length: length,
        onProgress: (sent) => _progress(
          BackupActivity.uploading,
          base + sent,
          total,
          notices.uploading,
        ),
        isCancelled: () => _cancelled,
      );
      if (object.md5 != digests.md5) {
        await remote.delete(object.id);
        throw const BackupException(
          BackupErrorKind.corrupt,
          'A file did not upload correctly. It will try again.',
        );
      }
      await remote.updateProperties(object.id, {
        BackupProperties.state: BackupProperties.committed,
      });
      done += length;
    }
    final manifest = File(p.join(config.staging.path, 'files.json'));
    await manifest.writeAsBytes(
      BackupFilesManifest(sets).encode(),
      flush: true,
    );
    final length = await manifest.length();
    final session = await remote.createUploadSession(
      name: '${config.appId}-files-${job.id}.json',
      length: length,
      mimeType: 'application/json',
      properties: {
        BackupProperties.format: '$backupFormatVersion',
        BackupProperties.kind: BackupProperties.filesManifest,
        BackupProperties.state: BackupProperties.committed,
      },
    );
    final object = await remote.upload(
      session: session,
      file: manifest,
      length: length,
    );
    job = job.copyWith(filesManifestId: object.id);
    await _saveJob(job);
    return job;
  }

  Future<BackupFilesManifest?> _manifest(BackupRemote remote, String id) async {
    final file = File(p.join(config.restoring.path, 'manifest-$id.json'));
    await deleteIfExists(file);
    try {
      await remote.download(id, file);
      return BackupFilesManifest.decode(await file.readAsBytes());
    } finally {
      await deleteIfExists(file);
    }
  }

  // ---- Retention ------------------------------------------------------------

  Future<void> _prune(BackupRemote remote, BackupJob job) async {
    try {
      // Objects written by a newer format belong to a newer app: never touch.
      final snapshots = [
        for (final s in await remote.list(kind: BackupProperties.snapshot))
          if (_format(s) <= backupFormatVersion) s,
      ];
      final committed =
          snapshots
              .where(
                (s) =>
                    s.properties[BackupProperties.state] ==
                    BackupProperties.committed,
              )
              .toList()
            ..sort((a, b) => _created(b).compareTo(_created(a)));
      final keep = <String>{
        job.fileId!,
        ...committed
            .where((s) => s.id != job.fileId)
            .take(config.keepGenerations - 1)
            .map((s) => s.id),
      };
      final cutoff = now().subtract(const Duration(hours: 24));
      for (final snapshot in snapshots) {
        if (keep.contains(snapshot.id)) continue;
        final isCommitted =
            snapshot.properties[BackupProperties.state] ==
            BackupProperties.committed;
        if (isCommitted || _created(snapshot).isBefore(cutoff)) {
          await remote.delete(snapshot.id);
        }
      }
      if (fileSets.isEmpty) return;
      final manifests = {
        for (final s in snapshots)
          if (keep.contains(s.id) &&
              s.properties[BackupProperties.files] != null)
            s.properties[BackupProperties.files]!,
        ?job.filesManifestId,
      };
      final hashes = <String>{};
      for (final id in manifests) {
        hashes.addAll((await _manifest(remote, id))?.hashes ?? const {});
      }
      for (final object in await remote.list(
        kind: BackupProperties.filesManifest,
      )) {
        if (!manifests.contains(object.id) &&
            _created(object).isBefore(cutoff)) {
          await remote.delete(object.id);
        }
      }
      for (final object in await remote.list(kind: BackupProperties.file)) {
        final hash = object.properties[BackupProperties.sha256];
        if (!hashes.contains(hash) && _created(object).isBefore(cutoff)) {
          await remote.delete(object.id);
        }
      }
    } on Object {
      // Cleanup is retried after the next backup; the new backup is safe.
    }
  }

  static int _format(RemoteObject object) =>
      int.tryParse(object.properties[BackupProperties.format] ?? '') ?? 1;

  static DateTime _created(RemoteObject object) {
    final ms = int.tryParse(object.properties[BackupProperties.created] ?? '');
    return ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        : object.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ---- Restore --------------------------------------------------------------

  /// Committed backups, newest first. Null when not signed in.
  Future<List<RemoteBackup>?> listBackups() async {
    final session = await backend.open();
    if (session == null) return null;
    try {
      final snapshots = await session.remote.list(
        kind: BackupProperties.snapshot,
      );
      final backups = [
        for (final s in snapshots)
          if (s.properties[BackupProperties.state] ==
                  BackupProperties.committed &&
              _format(s) <= backupFormatVersion &&
              s.md5 != null &&
              RegExp(r'^[a-f0-9]{64}$')
                  .hasMatch(s.properties[BackupProperties.sha256] ?? ''))
            RemoteBackup(
              id: s.id,
              createdAt: _created(s).toLocal(),
              size: s.size,
              sha256: s.properties[BackupProperties.sha256]!,
              md5: s.md5!,
              schemaVersion:
                  int.tryParse(s.properties[BackupProperties.schema] ?? '') ??
                  0,
              deviceName: s.properties[BackupProperties.device],
              filesManifestId: s.properties[BackupProperties.files],
              cipherId: s.properties[BackupProperties.cipher] ?? 'plain',
            ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } finally {
      session.close();
    }
  }

  Future<RemoteBackup?> latestBackup() async =>
      (await listBackups())?.firstOrNull;

  /// Downloads, verifies and swaps in [backup].
  ///
  /// [closeDatabase] must close every connection to the live database;
  /// [reopenDatabase] runs afterwards whether or not the swap succeeded.
  /// Interrupted downloads resume on the next call.
  Future<RestoreResult> restore(
    RemoteBackup backup, {
    required Future<void> Function() closeDatabase,
    required Future<void> Function() reopenDatabase,
  }) {
    if (_restoring != null) return _restoring!;
    return _restoring = _restore(
      backup,
      closeDatabase,
      reopenDatabase,
    ).whenComplete(() => _restoring = null);
  }

  Future<RestoreResult> _restore(
    RemoteBackup backup,
    Future<void> Function() closeDatabase,
    Future<void> Function() reopenDatabase,
  ) async {
    _cancelled = false;
    final lock = _lock();
    if (_active != null || !await lock.tryAcquire()) {
      throw const BackupException(
        BackupErrorKind.busy,
        'A backup or restore is already running.',
      );
    }
    BackupSession? session;
    var restored = false;
    try {
      if (backup.cipherId != cipher.id) {
        throw const BackupException(
          BackupErrorKind.incompatible,
          'This backup needs a different app setting to restore.',
        );
      }
      if (backup.schemaVersion > source.schemaVersion) {
        throw const BackupException(
          BackupErrorKind.incompatible,
          'This backup was made by a newer version. Update the app to restore it.',
        );
      }
      session = await backend.open();
      if (session == null) {
        throw const BackupException(
          BackupErrorKind.auth,
          'Sign in to restore.',
        );
      }
      final directory = config.restoring;
      await directory.create(recursive: true);
      // Leftovers of other backups are dropped; this one's part file resumes.
      await for (final entity in directory.list()) {
        if (p.basename(entity.path) != '${backup.id}.part') {
          await deleteIfExists(entity);
        }
      }
      final part = File(p.join(directory.path, '${backup.id}.part'));
      _progress(
        BackupActivity.downloading,
        0,
        backup.size,
        notices.downloading,
      );
      await session.remote.download(
        backup.id,
        part,
        expectedLength: backup.size,
        onProgress: (received) => _progress(
          BackupActivity.downloading,
          received,
          backup.size,
          notices.downloading,
        ),
        isCancelled: () => _cancelled,
      );
      if ((await _digests(part)).sha256 != backup.sha256) {
        await deleteIfExists(part);
        throw const BackupException(
          BackupErrorKind.corrupt,
          'The downloaded backup was damaged. Try again.',
        );
      }
      _emit(
        _state.copyWith(
          activity: BackupActivity.restoring,
          bytesDone: 0,
          bytesTotal: 0,
        ),
      );
      await _notify(notices.restoring, null, force: true);
      var compressed = part;
      if (cipher is! PlainBackupCipher) {
        compressed = File(p.join(directory.path, 'decoded.gz'));
        await cipher.decode(part.openRead()).pipe(compressed.openWrite());
      }
      final candidate = File(p.join(directory.path, 'candidate.sqlite'));
      await deleteIfExists(candidate);
      await _gunzip(compressed, candidate);
      await source.validate(candidate);
      await closeDatabase();
      try {
        await RestoreRecovery.swap(
          stateDirectory: config.stateDirectory,
          databasePath: source.databasePath,
          candidate: candidate,
        );
        restored = true;
      } finally {
        await reopenDatabase();
      }
      await deleteIfExists(directory);
      // The restored data is the newest backup; nothing local is pending.
      await deleteIfExists(_journal);
      await deleteIfExists(config.staging);
      await writeJsonFile(
        _historyFile,
        BackupHistory(
          lastSuccess: backup.createdAt,
          lastSize: backup.size,
        ).toJson(),
      );
      BackupException? filesError;
      if (backup.filesManifestId != null && fileSets.isNotEmpty) {
        try {
          await _restoreFiles(session.remote, backup.filesManifestId!);
        } on Object catch (error) {
          filesError = classify(error);
        }
      }
      await notifier?.clear();
      _emit(
        BackupState(
          lastSuccess: backup.createdAt,
          lastSize: backup.size,
          error: filesError,
        ),
      );
      return RestoreResult(databaseRestored: true, filesError: filesError);
    } on Object catch (error) {
      await notifier?.clear();
      final failure = classify(error);
      _emit(
        BackupState(
          lastSuccess: _state.lastSuccess,
          lastSize: _state.lastSize,
          error: failure,
        ),
      );
      if (restored) {
        return RestoreResult(databaseRestored: true, filesError: failure);
      }
      throw failure;
    } finally {
      session?.close();
      await lock.release();
    }
  }

  /// Downloads files of [manifestId] that are missing or differ locally.
  /// Safe to call again: files already in place are skipped.
  Future<void> _restoreFiles(BackupRemote remote, String manifestId) async {
    final manifest = await _manifest(remote, manifestId);
    if (manifest == null) return;
    final objects = <String, RemoteObject>{
      for (final object in await remote.list(kind: BackupProperties.file))
        if (object.properties[BackupProperties.state] ==
            BackupProperties.committed)
          object.properties[BackupProperties.sha256] ?? '': object,
    };
    final cache = BackupHashCache(File(config.path('files-cache.json')));
    await cache.load();
    var missing = 0;
    for (final set in fileSets) {
      for (final entry in (manifest.sets[set.name] ?? const {}).entries) {
        final target = File(
          p.joinAll([set.root.path, ...p.posix.split(entry.key)]),
        );
        if (!p.isWithin(set.root.path, target.path)) continue;
        if (await target.exists() &&
            (await cache.hash(target, entry.key))?.sha256 ==
                entry.value.sha256) {
          continue;
        }
        final object = objects[entry.value.sha256];
        if (object == null) {
          missing++;
          continue;
        }
        final partial = File('${target.path}.restore-partial');
        await remote.download(
          object.id,
          partial,
          expectedLength: entry.value.size,
          isCancelled: () => _cancelled,
        );
        if ((await _digests(partial)).sha256 != entry.value.sha256) {
          await deleteIfExists(partial);
          missing++;
          continue;
        }
        await partial.rename(target.path);
      }
    }
    await cache.save();
    if (missing > 0) {
      throw BackupException(
        BackupErrorKind.remote,
        '$missing ${missing == 1 ? 'file was' : 'files were'} not restored.',
      );
    }
  }

  // ---- Reset ----------------------------------------------------------------

  @override
  Future<void> suspendForReset({bool requireIdle = false}) async {
    if (requireIdle && (_active != null || _restoring != null)) {
      throw StateError('Wait for the backup to finish, then try again.');
    }
    _suspended = true;
    cancel();
    await _active;
    _emit(_state.copyWith(suspended: true));
  }

  @override
  Future<void> resumeAfterReset({required bool completed}) async {
    if (completed) {
      await deleteIfExists(_journal);
      await deleteIfExists(_historyFile);
      await deleteIfExists(config.staging);
      await deleteIfExists(config.restoring);
      await deleteIfExists(File(config.path('files-cache.json')));
      _suspended = false;
      _emit(const BackupState());
      return;
    }
    _suspended = false;
    _emit(_state.copyWith(suspended: false));
  }

  Future<void> dispose() async {
    cancel();
    await _states.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
