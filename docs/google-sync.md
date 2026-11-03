# Google sync (GS01)

GS01 migrates the selected `sync_wise` package and account UI into Redkeep.
The original projects remain read-only. The user selected the original primary /
add-only secondary behavior, separate Redkeep cloud data, and Android focus.
iOS Google sign-in is deferred until its own OAuth client and URL scheme exist.

## Boundaries and stored data

`redkeep/packages/sync_wise/` keeps its provider-neutral engine, Google Drive
adapter, authentication, device identity, binding and resumable reset structure.
Its storage/collection persistence is now awaitable for background Drift. The
engine owns cancellation, serialization, four upload workers, guarded revisions,
300ms debounce, one-minute automatic cooldown and bounded retries. First-session
and manual primary sync download then upload; later automatic primary attempts
upload only. Secondary devices send new creations, reading only an affected
Diary day when appending. Explicit primary reclaim preserves the cloud registry.

`features/sync/` supplies handwritten Riverpod composition, new Drift adapters,
and the selected account presentation. No ObjectBox, legacy repository, native
configuration, desktop, People or media feature is imported. The original package
LICENSE file is preserved verbatim (it contains a placeholder, not a new license
grant). Source hashes and visual comparison methodology are in
[evidence](evidence/gs01/provenance.json).

Schema **9** adds `sync_records`, `sync_operations` and `sync_values` to the same
primary database. SQLite triggers queue authoritative changes in the transaction
that commits writing, including tags and permanent deletion. The v8 upgrade
queues existing committed writing; drafts remain private. Older schema upgrades
and their data remain supported. No new sync database or synchronous SQLite
connection is created. Coordination watches committed table updates, not full
journal payloads.

Wire schema **1** uses Redkeep IDs and detached JSON:

- `note/<32-hex-id>`: title/body, creation/update/deletion times, pin and tags.
- `thought/<32-hex-id>`: body and creation/update/deletion times.
- `diary/<civil-date>`: day heading and entries with stable IDs and tombstones.

Local revisions/draft tokens never travel. Remote changes increment local
revisions, so stale saves fail while recovery drafts survive. Dirty primary
records win their fields; dirty Diary days also merge unseen secondary entries.
Exact snapshot acknowledgement is checked again inside a transaction so an edit
during upload remains pending. Permanent note removal retains a sync tombstone.
Artwork, downloads/models, Brain assignments, settings, names and drafts are not
synced. Sync has no attachment or Journal-data importer.

## Ownership, permissions and recovery

All Drive files carry `redkeepNamespace=redkeep-v1`. Every listing filters this
property and independently discards foreign results; direct reads, conditional
updates, reclaim registry writes and deletion verify ownership before access.
Unsupported payload/registry protocols fail without replacing their data. Reset
rechecks only this namespace; it never wipes the entire app-data space.

Local account binding prevents another account/provider from receiving this
writing. Signing out retains local writing and cached role. A known secondary
cannot modify existing committed writing; it can create Notes/Flow and append
Diary entries for today. Repository transactions enforce this independently of
UI controls. Private recovery drafts may still be written after a role change,
so an open editor cannot lose text typed immediately before it becomes read-only.
Pending committed edits become local-only when resolving as secondary. Reclaim
primary explicitly to resume editing; unknown devices continue working locally.

Reset requires the same account, an idle engine and typed `DELETE`. The order is:
pause sync → persist account/provider intent → delete owned cloud files → persist
remote-deleted checkpoint → clear local writing/drafts/outbox → sign out → clear
binding and intent. Each step can resume after process death. A pending reset
blocks ordinary access before silent sign-in. Local cleanup never selects files
from remote paths and keeps name, appearance, Brain assignments, models, artwork
and device identity. Other devices retain their local data and could re-upload;
the existing confirmation explains this.

The reset gate removes the route subtree, changes the router epoch, cancels any
Brain executor, and expires old repository generations. Late editor/helper
callbacks cannot recreate cleared writing. Failure after durable intent leaves
the progress/retry screen; failure before intent allows ordinary local use again.

## UI and configuration

More keeps Appearance/Brain and adds the original ownership card: the same
bookcloth, identity, status/actions, sizing, pinned collapse and expand behavior.
The account sheet, primary reclaim, disconnect, typed reset and progress screens
keep their original composition; unsupported legacy-feature copy is removed.
App rendering policy controls reduced-motion transitions. Safe areas, scrolling
and 320px / 3x text are covered offline. The six card/sheet goldens use Flutter's
pinned local Roboto and MaterialIcons fonts. Four card and two sheet baseline
renders came from the selected original widgets with only host adapters; the
production widgets match those baseline pixels in both themes.

Ignored `redkeep/env.json` retains `ASSET_BASE_URL` and the user's
`GOOGLE_SERVER_CLIENT_ID`. The tracked example contains placeholders, never an
actual OAuth ID. Existing editor launch modes already pass that file:

```sh
cd redkeep
flutter run --dart-define-from-file=env.json
```

Android needs the Redkeep package/signing certificate registered in the relevant
Google OAuth project, a Web OAuth server client ID, Drive API enabled and consent
for `email` / `drive.appdata`. This phase does not create or modify cloud resources.
No Firebase configuration/native manifest was copied. Android Google sign-in uses
resolved `google_sign_in` **6.3.0**, preserving the selected package API generation.

Without an iOS OAuth client, iOS silently stays signed out and an explicit connect
shows a setup message. Future iOS setup requires `GOOGLE_CLIENT_ID` and the
corresponding reversed-client-ID URL scheme in Redkeep's own Info.plist. Do not
reuse a Web server client ID as the iOS client. The simulator build proves
packaging compatibility only, not working iOS sign-in.

Official references: [Google Sign-In 6.3.0](https://pub.dev/packages/google_sign_in/versions/6.3.0),
[iOS setup](https://pub.dev/packages/google_sign_in_ios/versions/5.9.0),
[Drive app-data storage](https://developers.google.com/workspace/drive/api/guides/appdata).

## Verification

From `redkeep/` run the root README checks, plus:

```sh
flutter test test/features/sync
cd packages/sync_wise
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

The package suite covers scheduling, cooldown/backoff, disposal, account binding,
identity, resumable reset and HTTP ownership boundaries. App suites cover atomic
queue rollback/reopen, upload races, tags/trash/tombstones, stale drafts, primary
reclaim, secondary appends, account changes, reset generations, migration and UI.
Goldens use fonts in the installed Flutter SDK; no font or artwork download is
performed. `flutter test test/features/sync/sync_ui_test.dart
--dart-define=RECORD_SYNC_SCREENSHOTS=true` also writes review PNGs under the GS01
evidence directory. Goldens should only be updated after reviewing an intentional
UI change against the selected original.

Exact results and native build evidence are recorded in
[verification.json](evidence/gs01/verification.json). Live Android sign-in/consent,
real Drive ETags, fresh install/reinstall and real two-device/reset behavior remain
unverified. Tests use disposable SQLite, fake services and synthetic writing;
no user account or private journal is accessed. M12 and later features remain
outside GS01.
