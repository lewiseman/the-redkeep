# Sync Wise — Redkeep host

Migrated from the user-selected Journal package for GS01. The directory structure,
engine, provider boundary, Google Drive backend, account binding, device identity
and reset lifecycle are retained. The original LICENSE placeholder is unchanged.

The host owns models and persistence. `SyncCollection` persistence and
`SyncKeyValueStore` operations support asynchronous adapters; `SyncStateStore`
methods must be awaited. Await `SyncEngine.ready` before relying on cached roles.
Memory implementations remain available for tests. Production Drift adapters and
transactional outbox triggers live in Redkeep's `features/sync/data/`.

The first device claims primary. Primary startup/manual sync performs a full
round trip; later automatic runs upload pending changes. Secondary devices are
add-only, with guarded Diary-day appends. Manual reclaim transfers the registry
and restores full sync. Requests serialize, debounce for 300ms, use a one-minute
automatic cooldown and bounded retry/backoff. Uploads use detached snapshots and
conditional writes; exact acknowledgement must not clear newer local changes.

The Google adapter exclusively uses `redkeepNamespace=redkeep-v1`. It verifies
ownership before content reads, updates and reset deletion. Journal cloud data
is not enumerated or imported. Redkeep wire payloads are schema 1; the package's
registry/conditional-write protocol remains version 2.

`DeviceIdentityService.load()` is scoped by the host FutureProvider rather than a
global singleton. Keep identity across account reset. `AccountResetController`
pauses the engine, durably records intent, removes owned cloud data, invokes
idempotent host cleanup, signs out and clears binding. The host must block access
and expire old writing sessions while reset is pending. `resumeAfterReset` is
awaitable. Do not directly invoke Notifier build/dispose methods.

Run `flutter pub get --enforce-lockfile`, `flutter analyze` and `flutter test`
here.
