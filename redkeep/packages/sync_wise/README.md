# sync_wise

WhatsApp-style backups for Flutter apps. Your app's SQLite database (and,
optionally, folders of files such as photos) is backed up as **one verified
snapshot** to the user's Google Drive, on a schedule or on demand, and
restored on a new phone.

- **Fast:** one compressed file instead of one request per record.
- **Resumable:** every step is journaled. A dropped connection, a killed app or
  a reboot continues from the same staged snapshot and the same Drive upload
  session; downloads resume with HTTP ranges.
- **Verified:** a backup only counts once Drive's MD5 matches the local file.
  Older backups are removed only after that, so a good backup always exists.
  Restores check SHA-256, `PRAGMA integrity_check` and the schema version
  before swapping files.
- **Crash-safe restore:** the database swap is journaled and finished (or rolled
  back) on the next launch, before the app opens its database.
- **Private:** Drive's hidden `appDataFolder`, readable only by your app. Every
  object carries your `appId`; objects of other apps are never read or deleted.
- **Background:** Android WorkManager runs it overnight on Wi-Fi (or any
  network, if the user allows mobile data) with enough battery. A cross-isolate
  lock keeps the app and the background job from running together.

## Setup

```yaml
dependencies:
  sync_wise:
    path: packages/sync_wise
```

Google sign-in needs an OAuth client for your Android package. Pass the web
client id with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`, or give
`GoogleAuthService(serverClientId: ...)`. Only the `drive.appdata` scope is
requested.

## Build an engine

Build it the same way in the app and in the background isolate:

```dart
Future<BackupEngine> createEngine() async {
  final config = BackupConfig(
    appId: 'myapp', // never change it: it names your backups
    stateDirectory: await BackupConfig.defaultStateDirectory('myapp'),
  );
  return BackupEngine(
    config: config,
    source: SqliteBackupSource(
      databasePath: '<app support>/myapp.sqlite',
      schemaVersion: 7, // backups from newer versions are refused
    ),
    backend: GoogleDriveBackend.fromConfig(config),
    network: NetworkService(),
    notifier: LocalNotificationsBackupNotifier(icon: 'ic_notification'),
    deviceName: 'Android device',
    // Scheduled runs never replace a cloud backup with an empty database.
    isEmpty: () async => await countRows() == 0,
  );
}
```

`SqliteBackupSource` copies the database with `VACUUM INTO` over its own
read-only connection, so it works while your app (Drift, sqflite, …) keeps the
database open, and from a background isolate.

## Back up

```dart
final engine = await createEngine();
await engine.load();                  // last result, unfinished job
engine.states.listen(render);         // activity, bytes, last backup, error
final state = await engine.backUpNow(); // never throws; see state.error
engine.cancel();                      // pause after this chunk; resumes later
```

`BackupState.error.kind` tells the UI what to say: `offline` (including "Waiting
for Wi-Fi"), `auth`, `storageFull`, `corrupt`, `incompatible`, `cancelled`,
`busy` or `empty`.

## Schedule (Android)

```dart
@pragma('vm:entry-point')
void backupDispatcher() {
  Workmanager().executeTask(
    (task, _) => runScheduledBackup(createEngine),
  );
}

// At startup:
await Workmanager().initialize(backupDispatcher);
// When settings or sign-in change:
await BackupScheduler(stateFile: File('<state>/schedule.json'))
    .apply(await engine.readSettings(), signedIn: auth.isSignedIn);
```

`BackupSettings` holds the interval (daily, weekly, monthly, or only manual)
and whether mobile data may be used. Keep a foreground fallback too: call
`engine.isDue()` when the app goes to the background and back up then.

## Restore

```dart
// Before opening the database, on every launch:
await RestoreRecovery.finish(
  stateDirectory: config.stateDirectory,
  databasePath: databasePath,
);

final backup = await engine.latestBackup();
if (backup != null) {
  await engine.restore(
    backup,
    closeDatabase: () => db.close(),
    reopenDatabase: () async => reopen(),
  );
}
```

The replaced database is kept as `<database>.before-restore` until the next
successful backup.

## Files (optional)

```dart
BackupEngine(
  // ...
  fileSets: [
    BackupFileSet(
      name: 'photos',
      root: supportDirectory,
      include: ['photos'],
      filter: (path) => !path.endsWith('.partial'),
    ),
  ],
);
```

Files are stored once per SHA-256, so unchanged and renamed files upload
nothing. A small manifest is uploaded with each snapshot, and a restore
downloads only the files that are missing or different.

## Account reset

`AccountResetController` (Riverpod) pauses backups, deletes every object the
app stored, clears local data through your `AccountResetLocalData`, and signs
out. It is durable:
an interrupted reset continues on the next launch.

## Storage format (version 1)

Format 1 is stable. In the app folder each object carries appProperties:

| Key | Value |
|---|---|
| `swApp` | your `appId` |
| `swFormat` | `1` (objects without it are format 1) |
| `swKind` | `snapshot`, `files-manifest` or `file` |
| `swState` | `uploading` or `committed` |
| `swSha256`, `swSchema`, `swCreated`, `swDevice`, `swFiles`, `swCipher` | snapshot details |

A snapshot is the gzip-compressed SQLite file (`VACUUM INTO`), passed through
the cipher. Only `committed` snapshots are restored. Objects in a newer format
are never listed, restored or deleted by this version.

## Encryption

Stored bytes go through a `BackupCipher`. The default `PlainBackupCipher`
relies on Drive's app-private folder. Plug in your own cipher for
password-protected backups; restores refuse a backup made with another cipher.
