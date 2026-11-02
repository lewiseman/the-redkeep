# Presentation assets and startup

## Inventory and selection

M04 inspected the reachable legacy path `journal/lib/main.dart` →
`OnboardingPage` / `RootLayout` → Notes, Diary, Flow and Appearance; their actual
image references and artwork notes were read. Notes' top artwork is a painter,
not a downloadable image. The website path `bookflip/src/main.jsx` → `App.jsx`
→ `Book` / `BookPages` reuses the former Journal book. The desktop companion
does not supply required mobile presentation media and was not imported.

The inventory below covers the planned mobile first release. Candidate names
reserve intent in this document only; future phases must verify their real
consumer and add them to a release catalog when implemented.

| Surface | Reachable legacy reference | Selection for Redkeep |
| --- | --- | --- |
| Current Appearance themes | `assets/images/theme_{system,light,dark}.png`; `ARTWORK.md`; Appearance page | Selected: three original generated 384×384 transparent PNGs. Current required keys `appearance.theme.system`, `.light`, `.dark`, revision `v1`. Individually copied unchanged; 434,116 bytes total. |
| Onboarding cover/spreads | `onboarding_book.dart`, `onboarding/ARTWORK.md`, `CURRENT_ARTWORK.md`; website book | Excluded: baked-in Journal / former AI branding and chapters promising People, Sync, Tasks, Movies or other deferred behavior. M05 must use accessible live Redkeep copy and re-evaluate any art it needs. |
| Onboarding material textures | `onboarding/{paper-edge,binding-cloth,ink-paper}.webp`, book materials | Documented original generated candidates; neutral textures are usable if M05's chosen design consumes them. No texture needed by the current shell. Do not import the book implementation. |
| Primary navigation | `root_layout.dart` / `bottom_navbar.dart`; `navigation/ARTWORK.md` | Original generated Diary, Notes and Flow active/inactive PNGs are candidates for M05's real navigation consumers. More's keepsake box depends on the selected navigation design. No inactive tabs registered in M04. |
| Notes add artwork | `notes/views/pages/notes_page.dart:483`; `images/ARTWORK.md` | Original generated `notes_add.png` candidate for M06 if chosen. Suggested future key `notes.add`. Current Notes top artwork needs no external media. |
| Diary | `diary_page.dart`, `diary_calendar.dart` | Original generated `diary_calendar_pin.png` is a candidate for M08 (`diary.calendar.pin`). `diary_top_bg.png` has no provenance note found; excluded until ownership/use is established. Paper surfaces can remain code based. |
| Flow | `flow_page.dart` / `flow_reflection.dart`; `FLOW_REFLECT_ARTWORK.md` | Original generated `flow_reflect.png` is a candidate when the reflection action is implemented. `reflecting.mp4` is excluded: video is outside first-release delivery scope. |
| Grand Maester / Brain | Legacy assistant references `more_local_qvac.png`; AI studio artwork notes | Former AI branding excluded. The four current raw artwork drafts are unassigned and still being edited. Use accessible native controls until a later authorized consumer selects approved Redkeep art. No required models, audio, or video in this catalog. |
| Fonts | `assets/fonts/README.md`, Lora/Caveat OFL files | License/provenance exists, but M02 deliberately uses system typography. No current font consumer, so fonts and font loaders are excluded. |
| Other legacy website media | Branding, screenshots, feature spreads, duplicate `public/art` files | Excluded from the mobile pack. Marketing is W01; old product claims/screenshots are not current feature evidence. |
| `raw_assets/` | Four PNGs, six WAVs, `.DS_Store` | Read-only inspection: three cutout variants of an elder, one green castle/window scene, six unassigned audio files. No license/assignment record accompanies them. Nothing copied, renamed, edited, decoded for playback, bundled or published. Before/after SHA-256 baseline confirms originals unchanged. |

Selected source media have documented original image_gen provenance in the
user's legacy project, without third-party license requirements. The user's
M04 migration authorizes reuse. `LicenseRef-Project-Generated` records that
provenance, rather than asserting an open-source license for the artwork.
Preserved source notes/prompts and individual source filenames are in
[`PROVENANCE.md`](../redkeep/tool/assets/PROVENANCE.md). No stock-license or
copyright ownership claims are inferred for undocumented files.

## Runtime contracts

`features/assets/domain/asset_catalog.dart` owns immutable release metadata,
safe failures, `RequiredAssets`, and the injectable `AssetResolver`. The current
catalog is `assets/catalog/presentation-v1.json`, bundled as JSON only. All
catalog entries are required for the implemented release; there are no optional
future entries. Keys describe purpose and stay stable. Changes to bytes require
a new revision and pinned SHA-256/size; prefer a new versioned path. The ledger
also detects a revision/hash change at the same path.

The parser rejects missing metadata, invalid schema, duplicate keys/paths,
unsafe paths (absolute paths, traversal, links at the file boundary, percent
encoding, queries, backslashes), empty packs, non-PNG entries, reserved temporary
names and excessive payloads. Current bounds: 100 files, 10 MiB per file and
50 MiB total. Publishing additionally verifies still-image decode, dimensions
up to 2048×2048, reviewed provenance and an exact payload inventory. These are
intentional limits for the current image consumer, not future audio/video APIs.

`FileRequiredAssets` owns `application-support/required-artwork/`, separate from
`redkeep.sqlite`. `ledger.json` maps keys to revision, path, hash, size and file
modified/changed times. Every launch checks real files and metadata. Missing or
changed mappings/files require hash verification; unchanged verified records
avoid redundant rehashing. Explicit repair verifies every file. The resolver
rechecks availability and suspicious metadata; image/resolve errors close the
startup gate and offer local recheck/repair. Automatic async provider retries are
disabled at these boundaries so required-file failures surface immediately;
explicit user retry refreshes failed store initialization. FileImage's path-only memory cache
is evicted when resolving artwork so replacement files can render correctly.

Downloads are sequential streams to sibling `-pending.png` files. Size is
bounded while receiving, then SHA-256 is checked, output flushed/closed, and the
file renamed in the same directory before committing the ledger by another
flushed sibling rename. A crash after payload rename is recovered by local
verification without a download. Incomplete streams are never resolved as
installed assets. Handled failures remove the pending file; process-killed
pending files are ignored and overwritten on retry. Completed valid files stay
installed across failures and restarts. Operations serialize within the single
app-scope store. Symlinks at root, directory, target, ledger and temporary paths
are rejected. There is no database reset, database deletion, recursive repair
delete, account dependency or writing access in this adapter.

The HTTP adapter requests identity encoding, rejects redirects and non-200
responses, uses 15-second connection/response/idle deadlines, and force-closes
its client on success, failure or stream cancellation. Each asset additionally
has a two-minute receive limit checked as chunks arrive. HTTPS is required;
explicit debug fixtures permit HTTP only to loopback. Empty host configuration
is deliberate and yields a safe actionable download error. No placeholder or
localhost production default exists. Catalogs are release pinned, with no
online catalog fetch during launch. Models remain separate and optional.

## Bootstrap, recovery and accessibility

`main` initializes bindings, immediately preserves `flutter_native_splash`, and
runs the Riverpod app. Its runtime dependency is pinned to **2.4.8**, compatible
with the local Flutter/Dart baseline. Existing native splash/launcher artwork,
storyboards, identities, ABI/floors and signing are retained; no splash generator
was run over that native configuration.

`BootstrapCoordinator` bounds the aggregate local work at five seconds through
the controller: existing Appearance repository first read (which opens/migrates
the existing background Drift database), pinned catalog/storage initialization,
and local asset inspection. Slow checks are coalesced so a retry cannot start
overlapping storage work. Timeout/error goes to a recoverable Flutter screen.
The controller releases the splash on success, error, timeout or disposal,
without waiting for a deferred first frame. Download actions are enabled only
after release. No model initialization or network transfer runs under the splash.

M05 adds its persisted onboarding read through this coordinator under the same
aggregate limit. The router now redirects through a real `/startup` page with
a validated continuation, so a direct `/settings` destination survives local
checks, download/retry and onboarding. See [onboarding and navigation](onboarding-routing.md)
for validation, history and interruption semantics. Missing required artwork blocks entry,
including offline first launch. Complete installations open offline. Startup
database/settings failures have a local retry; saved settings are reloaded after
a successful recovery. Asset failures explain connection, storage, integrity,
catalog or service setup issues without exposing raw errors or local paths.

The gate uses system fonts, safe areas, a scrolling narrow-screen layout, large
buttons, status semantics and determinate progress. It adds no decorative motion
or indeterminate spinner. Appearance images are static and decorative beside
live accessible theme labels. Existing reduced-motion/simpler-effects behavior
continues to apply. Widget checks at 320×480, 3× text, safe padding and keyboard
insets are distinct from physical accessibility verification.

## Local fixture and host setup

From `redkeep/`, validate the controlled, unbundled payload pack:

```sh
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack
python3 -m http.server 8765 --bind 127.0.0.1 --directory tool/assets/pack
```

In another terminal, use a debug mobile build. For Android, reverse the selected
emulator/device port; the same loopback URL works in the iOS simulator:

```sh
adb -s <android-id> reverse tcp:8765 tcp:8765
flutter run -d <device-id> --dart-define=ASSET_BASE_URL=http://127.0.0.1:8765/ --dart-define=ASSET_ALLOW_LOCAL_FIXTURE=true
```

Tap **Download artwork**. Stop the fixture server and restart the app to check
complete offline entry. Remove only one named file under `required-artwork/`
in a disposable test installation to check detection/retry. Never clear app data
or remove `redkeep.sqlite` to reset this test. Stop the local server and remove
the selected `adb reverse` mapping when finished. Debug manifest permits local
HTTP; the adapter still requires explicit fixture opt-in and loopback. Release
ignores that opt-in and retains HTTPS validation. No iOS ATS exception was added.

Production hosting is unselected. Before a separately authorized release:

1. Select a real public HTTPS base ending in `/`, with an immutable pack prefix.
   Publish the exact verified relative payloads and retain the provenance notice
   alongside the distribution. Configure raw 200 responses, no authentication,
   redirects, signed expiring URLs or content mutation. Do not publish this pack
   as part of M04.
2. Set `REDKEEP_ASSET_BASE_URL` in the release environment to that actual base.
   Run the read-only publishing check and pass the same base into the build:

   ```sh
   dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack "$REDKEEP_ASSET_BASE_URL"
   flutter build apk --release --target-platform android-arm64 --dart-define=ASSET_BASE_URL="$REDKEEP_ASSET_BASE_URL"
   ```

3. The validator checks host syntax and rejects local/example addresses; it does
   not contact or publish to the host. Independently GET every hosted file and
   verify exact size/hash, then prove fresh install → progress → verified pack →
   restart offline on supported Android/iOS hardware. Qualify disk-full, process
   termination, minimum OS and low-end devices before release claims. An
   unconfigured build deliberately cannot enter on a fresh install.
4. As M05–M11 add actual first-release consumers, select only the relevant
   inventory candidates, preserve their provenance/licenses, revise this pinned
   catalog, run validation and repeat fresh/migrated installation checks. Do not
   broaden it to models, unassigned audio, videos or the entire legacy bundle.

## Verification and limits

Run the README commands and `flutter test test/features/assets test/app`.
Catalog, transport, disk, controller and widget tests use injected fixtures,
fresh scopes and disposable directories/databases. Synthetic bytes used by
integrity tests are never production artwork. Publishing tests decode the
reviewed PNG pack. Cases cover fresh/complete offline startup, missing files
despite saved keys, changed revision/same path, same-size replacement with
restored mtime, corrupt/short/oversized streams, interruption, orphan temporary
files, rename-before-ledger crash recovery, malformed ledger, symlink escape,
storage/ledger failure, retries, explicit verification, deadlines and splash
release, direct destinations, progress and accessible layouts.

Native evidence and exact commands are in the M04 migration record. Emulator or
simulator evidence does not establish physical screen-reader/keyboard behavior,
release timing, ENOSPC handling on hardware or power-loss durability. Atomic
rename is scoped to app-owned files on one filesystem; directory fsync and
cross-process writers are not claimed. No new writing schema exists in M04.

Official APIs/compatibility checked for adoption:

- [flutter_native_splash lifecycle and runtime dependency](https://pub.dev/packages/flutter_native_splash/versions/2.4.8),
  plus its resolved package source (`deferFirstFrame` / `allowFirstFrame`).
- [Dart File.rename](https://api.dart.dev/dart-io/File/rename.html) and
  [HttpClient](https://api.dart.dev/dart-io/HttpClient-class.html).
- [image 4.12.0](https://pub.dev/packages/image/versions/4.12.0) and
  [decodePng](https://pub.dev/documentation/image/4.12.0/image/decodePng.html).
  `image` is a development-only publishing validator dependency, already required
  transitively by splash tooling; no image-editing pipeline or runtime decoder
  dependency was added to the application.
