## 1.0.0 — 17 November 2026

- First stable storage format (`swFormat` 1). Unmarked backups read as format
  1; newer formats are left untouched.
- Removed `legacyNamespaces`/`DriveNamespace`: account reset deletes only the
  objects this package writes.

## 0.1.0 — 17 November 2026

- Replaced per-document sync, device roles and the Drive document registry with
  whole-database backups: `BackupEngine`, `SqliteBackupSource`,
  `GoogleDriveBackupRemote` (resumable Drive v3 uploads and ranged downloads),
  `RestoreRecovery`, optional `BackupFileSet`s and a `BackupCipher` hook.
- Android scheduling (`package:sync_wise/workmanager.dart`) and progress
  notifications (`package:sync_wise/notifications.dart`).
- Generic Google sign-in (`GoogleAuthService` takes client ids, scopes and the
  backend id) and account reset over `BackupLifecycle`/`BackupBackend`.

## GS01 — 3 November 2026

- Selected package/UI migration into Redkeep; awaitable Drift boundaries, scoped device identity, Redkeep-only Drive ownership and no Journal cloud import.
- Existing scheduling, account binding, guarded writes, recovery and resumable reset retained.

## 0.0.1

* TODO: Describe initial release.
