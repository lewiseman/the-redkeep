# Mobile shell: architecture and testing

## Responsibility and contracts

`redkeep/lib/main.dart` initializes bindings, preserves the native splash and
starts `ProviderScope` and `RedkeepApp`.
`app/redkeep_app.dart` composes `MaterialApp.router`, light/dark themes, committed
appearance state, and the rendering-policy host. `app/app_router.dart` creates
one GoRouter per scope and disposes it with that scope. Appearance rebuilds keep
the same router. Tests override it using
`createAppRouter(ref, initialLocation: ...)`; production validates and preserves
the supported Flutter platform initial location. A route-information adapter
validates warm platform input and handles malformed encoded queries safely.

The router redirects through `/startup` for local checks/downloads/retries and
`/onboarding` for the onboarding book, carrying a validated continuation in its URI.
Its five-second aggregate local limit and splash lifecycle are documented in
[assets and startup](assets-startup.md). Persisted onboarding, URI/parameter
validation, continuation/relaunch semantics, history and recovery are defined in
[onboarding and navigation](onboarding-routing.md).

Normal destinations are `/` (Diary-first home), `/settings` (appearance), `/notes`,
`/notes/:id` and `/notes/:id/edit`. Notes and settings are nested under home;
readers/editors have Notes beneath them. See [Notes writing and recovery](notes-writing.md)
for the document boundary, revisions, deletion retention and failure recovery.
M08 adds `/diary`, `/diary/calendar/:date`, `/diary/:date`,
`/diary/:date/entries/:id`, its `/edit` child, and `/diary/search`.
See [Diary writing and recovery](diary-writing.md) for civil dates, separate day
metadata, entry deletion and recovery. M09 adds `/flow`, `/flow/:id`, `/flow/:id/edit` and `/more`. A shared
`WritingShell` wraps the normal route navigator and provides Diary/Notes/Flow/More,
with Appearance and Brain under More. M10 adds `/settings/brain`. Labels wrap at large text; the bar hides while the
keyboard is open. The existing feature scaffolds keep their safe scroll viewports.
See [Flow capture and recovery](flow-writing.md); no future destinations are registered.
Invalid/unmatched input uses `/unavailable` with **Return home**, replacing the
unavailable route. Incoming URL content and raw errors are never displayed.
Material pages use central 180ms platform transitions or immediate reduced-motion
presentation, including live reduction and framework back gestures.

`app/app_shell.dart` supplies a scaffold, safe area, keyboard-resizing scroll
viewport, and bounded content width. `core/presentation` contains consumed theme,
paper-surface, and rendering-policy primitives. They use system fonts and
programmatic surfaces. Appearance consumes three downloaded static theme images
through the injectable resolver. UI01 bundles the user-selected Grand Maester
mascot and ink-paper background for startup and both onboarding layouts, and
uses `GoogleFontsLite.getFont('Allura')` for its caption, without
bundling a font binary. Google Fonts fetches/caches it on demand;
the remaining required 12-image pack is downloaded and verified. Bundled branding
never uses the required-file resolver or network. Stale ink-paper URL overrides
are ignored during build preparation and runtime configuration. Only implemented
destinations are registered; there are no future feature pages
or production writing fixtures.

`app/storage_providers.dart` composes the primary database and repository.
Feature domain types have no Flutter/database/plugin dependencies. Data adapters
map rows; controllers observe authoritative snapshots and coordinate saves. See
[appearance and persistence](appearance-persistence.md) for ownership, schema,
recovery, lifecycle, and generation contracts. M06 extends this same database to
schema 3 for Notes and recovery drafts; M07 adds pins/tags in schema 4. M08 adds
Diary entries, drafts and independent day headings in schema 5. M09 adds Flow
thoughts and capture/edit recovery drafts in schema 6; composition lives in
`features/flow/application/flow_providers.dart`. Diary composition
lives in `features/diary/application/diary_providers.dart`. Notes repository/clock/ID composition
lives in `features/notes/application/notes_providers.dart`.

## Tests and commands

Shared website/mobile images now use `website/public/art/` as their canonical
local reference, per the user's 3 November 2026 simplification. New shared images
need no duplicate under `assets/reference/`. The website build checks exact
copies from `public/` into `dist/`. Existing mobile catalog/source configuration
and tests have not yet migrated; the UI01 cover/font references described below
remain available for their current consumers. See [the website guide](website.md).

Remote presentation media also has a versioned reference library at
[`assets/reference/`](../assets/reference/README.md), outside the Flutter bundle.
Use its manifest and files for image inspection and future asset-dependent test
inputs. Tests must not invoke the refresh tool or fetch remote URLs. UI01 uses
eight exact onboarding copies in the separate deployment pack while retaining
all nine originals and four existing runtime files. Ink paper now has a separate
exact bundled copy. The two new
manifest entries index the selected mascot (`bundled-branding`) and the exact
font used by offline tests (`test-reference`). The mascot and ink paper have
bundled image copies; font licensing is retained separately.

`test/flutter_test_config.dart` disables Google Fonts runtime fetching and
preloads the consumed Allura from its local reference through a temporary
in-memory test asset response. The handler is removed and the root asset cache
cleared before test registration, then the real manifest is loaded outside
widget fake-async zones so application assets resolve independently of prior tests.
Tests need no font network request, device cache or font binary in the app bundle.

Run from `redkeep/`:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

Focused suites:

```sh
flutter test test/app
flutter test test/features/appearance
flutter test test/features/onboarding
flutter test test/features/notes
flutter test test/features/diary
flutter test test/features/flow
flutter test test/core
flutter test test/features/ai
flutter test test/features/brain
flutter test test/features/maester
flutter test test/features/assets
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack
```

- `test/app` checks app-scope composition, unknown initial/subsequent routes,
  recovery, independent routers, and home/fallback at 320×480 with 3× text,
  reduced motion, safe padding, and simulated keyboard insets.
- `test/features/appearance` checks controller isolation, failed loads/saves and
  recovery, overlapping saves, disposal, repository streams/defaults, singleton
  settings, and real background SQLite close/reopen. UI tests check themes,
  live system/app changes, mid-transition reduction, back, flat paper, contrast,
  and narrow/large-text/inset layouts in both themes.
- `test/core` checks schema 8 against its snapshot, upgrades from versions 1–7,
  appearance/writing preservation, missing-name gating for older completion rows, empty writing tables, SQL constraints,
  retained source/draft tokens and tombstones, all OS/app/lifecycle combinations, both OS flags live, inactive/offscreen
  ticker gating, resumption, and disposal.
- `test/support/pump_app.dart` creates a fresh scope with a small observable fake
  appearance repository, fake onboarding repository and fake required-assets
  boundary, keeping widget tests independent of path-provider and app-owned
  databases. Overridden routers retain production disposal ownership. Controller
  containers are fresh; repository tests clean up disposable files.
- `test/features/onboarding` checks commit timing, save/load failure, isolated
  controllers, disposal, incomplete/complete background-database reopen,
  interruption/relaunch, continuation preservation and the accessible five-chapter book/cover UI.
  UI01 adds real local reference decodes, manual page taps/swipes, keyboard and
  semantic chapter navigation/boundaries,
  no autoplay, skipped tour, repeated saves, cover/back, themes, landscape,
  live reduced/simpler/OS/inactive/offscreen behavior and ticker disposal.
  Footer tests guard the original layout/mascot/script, absence of added visible
  controls, safe-area/keyboard placement, exact external URLs, safe launch
  failures and disposal through an injected launcher; they open no browser.
  `test/app` also checks URI validation, readiness/loop combinations, malformed
  cold/warm platform input, latest/duplicate requests, Android back-channel
  cancellation/commit and iOS edge-swipe cancellation/completion in both motion modes.
- `test/features/assets` verifies catalog/path/host constraints, HTTP response and
  redirect handling/cleanup through injected transport, real disposable file
  integrity and atomic-install recovery, missing/suspicious files, restart/retry,
  symlink rejection, storage failure and separate database preservation. The
  publishing check decodes selected local PNG/WebP/JPEG files and rejects
  wrong extensions, animation, invalid dimensions and bad packs. Source-config
  tests preserve full object queries and unrelated env values atomically;
  real-reference store tests prove upgrade/repair/offline reopen without URLs.
- `test/app/bootstrap_test.dart` checks splash release before network, timeout,
  coalesced slow retries, local errors, disposal and progress. Startup widget
  checks cover required offline gating, preserved direct destinations, retry,
  reduced motion and narrow/large-text/inset layouts in both themes.
- `test/features/diary` checks empty/multiple-entry days, metadata separation,
  source/draft revision protection, failed transactions/recovery, copy/discard,
  close/reopen persistence, deletion, selected calendar/date routes, wrong-date
  IDs, Gregorian/DST/offset boundaries, literal keyword search, full long writing,
  accessible calendar activation and both themes/rendering modes at 320px/3×
  text/safe areas/keyboard. See the Diary guide for explicit timezone commands.
- `test/features/flow` checks rapid/repeated capture, commit-before-clear, duplicate
  prevention, failed writes/cleanup, single composer slot, deterministic time/ID
  ordering, background reopen, source/draft tokens, copy/discard, deleted routes,
  bounded previews/lazy collections, all shell destinations and narrow/large-text/
  keyboard/rendering combinations.
- `test/features/notes` checks CRUD, transactional rollback, failed saves and
  recovery, Unicode/large bodies, background close/reopen, stale source/draft
  tokens, copy/discard, navigation and ID switching, missing/deleted IDs and
  both rendering modes. M07 adds 120 filter combinations, persisted tags/pins,
  trash/restore/typed permanent deletion with draft-token protection, safe/failed
  external launches, malformed/long Markdown, omitted images, 2,000-record
  queries/lazy lists, bounded artwork decoding and scrollable large-text dialogs.
  Widget tests use disposable SQLite and a small
  failure/commit-gate decorator, disposed before database teardown.

The [README](../README.md) documents schema generation and native build commands.
Brain tests use injected files/network/models, fresh containers and disposable
SQLite. They cover assignment reopen/failure, verified installs/removal,
corruption/interruption, cancellation/resource races, readiness and writing with
unavailable AI storage, including narrow/large-text/keyboard layouts.
The AI adapter suite uses injected fake models/sessions, including setup and
teardown races. The [AI feasibility guide](ai-feasibility.md) documents its
contracts and the separate opt-in synthetic native harness under `tool/`.
Generated Drift code, snapshots, and verification helpers are retained with source. Future
schema upgrades require migration/data-preservation checks. Routine tests need
no account, network, private writing, or model.

## Limitations and phase boundary

Fast checks validate Dart/widgets and host SQLite. Android debug packaging and
emulator smoke evidence are recorded in M02. Neither establishes physical-device
accessibility, real keyboards, release performance, signing, or iOS execution.
M03 adds an explicit inference adapter/harness without changing app composition
or routes. Physical Android CPU/GPU and iOS simulator CPU evidence are separate
from routine tests. Physical iOS, low-end phones, OS-floor hardware, and release
qualification remain gaps. M04 adds local fixture assets/bootstrap with native
debug evidence and production-host prerequisites recorded separately. M05 adds
onboarding and routing, with framework gesture checks and native build evidence recorded in its phase record. Physical-device accessibility and
gesture qualification remain unverified. M06 adds Notes and native Android
emulator offline creation, draft recovery after force-stop, committed edits and
deletion evidence. Physical-device accessibility, native iOS writing journeys,
release/minimum-OS and power-loss/storage-failure qualification remain gaps.
M07 adds Notes organization and preview; its native evidence and remaining gaps
are recorded separately. M08 adds civil-date Diary writing, metadata separation,
calendar/search/routes, recovery and static notebook presentation. Its exact
native evidence and remaining gaps are recorded separately. M09 adds Flow and
the complete implemented shell, with native/offline evidence in its record.
M10 adds the lazy Brain controller and device executor. Schema 7 stores only
capability/model/source assignments; optional model files live outside required
media. No model loads at startup. See [Brain](brain.md) for installation,
readiness, cancellation and resource ownership. M11 adds feature-owned contextual
adapters and an ephemeral Grand Maester controller/dialog, guarded editor
acceptance and copy-only results. See [Grand Maester](grand-maester.md) for its
source/selection, lifecycle, recovery and separate native smoke contracts.

## References

- [Riverpod testing](https://riverpod.dev/docs/how_to/testing)
- [go_router setup](https://pub.dev/documentation/go_router/latest/topics/Get%20started-topic.html)
- [Appearance API references](appearance-persistence.md#verification-and-api-references)

Resolved versions, exact checks, and evidence gaps are in the migration plan.
