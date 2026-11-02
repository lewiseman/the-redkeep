# Appearance and persistence

## Contracts and ownership

`features/appearance/domain` owns immutable `AppearancePreferences` and the
`AppearanceRepository` contract, without Flutter/Drift/plugin types. Preferences
are system/light/dark theme and independent Reduce motion / Simpler effects
choices. Defaults are system theme and both switches off. `watch` emits saved
domain snapshots; `save` completes after a whole snapshot commits.

`app/storage_providers.dart` owns one `AppDatabase` per app scope and closes it
on disposal. The production factory lazily resolves the application-support
directory and opens `redkeep.sqlite` with `NativeDatabase.createInBackground`.
SQLite executes on Drift's managed isolate, off the UI isolate. Tests can inject
a `QueryExecutor` or override the repository provider. No mutable global service,
clock, ID source, or interim preference store is needed.

Schema **1** contains only `appearance_settings`. The primary key/check permits
one row (`id = 1`); theme and boolean values have SQL constraints. A missing row
means defaults and does not seed a record. Saving upserts the full snapshot.
`drift_schemas/drift_schema_v1.json` and generated schema helpers preserve the
initial structure. M06 and other consumers must extend this same database with
a version bump and tested migrations. Never reset/delete storage to repair
preferences. Generation commands are in the [README](../README.md).

## Failure and recovery

The controller observes repository snapshots for its scope. Controls are disabled
until the initial read succeeds and during a save. One save runs at a time to
prevent overlapping stale-snapshot writes. The old choices remain until commit;
there is no optimistic success. Independent repository changes also apply live.

A read failure shows **Retry loading** and blocks writes; retry resubscribes
without replacing saved data. A save failure retains committed choices and shows
a live-region message; the user can try the control again. Save completion after
disposal cannot mutate disposed controller state. The policy stays static until
the first saved snapshot arrives; system theme is the temporary theme during that
read. M04 owns future bounded bootstrap checks and splash coordination.

## Rendering and accessibility

`RenderingPolicyHost` observes Android `disableAnimations`, iOS `reduceMotion`,
and lifecycle changes. `RenderingPolicyScope` combines these with saved choices:

- Reduced motion = either OS flag **or** the user's motion reduction.
- Simpler effects = reduced motion **or** the user's simpler effects choice.
- Motion is permitted only while active and without effective reduction.

The app cannot disable OS reduction. Switches show saved user intent; status text
explains the effective result. Clearing an OS request restores the app choice.
System theme follows live brightness; explicit light/dark selections stay fixed.

Routes share a 180ms fade or immediate transition, including policy changes in
flight. Theme changes are immediate. Shared sheet/ink/accent/edge tokens and
system typography supply headings, section titles, body copy, and labels. Paper
has a border and one small shadow; simpler mode removes the shadow and preserves
functionality. A local Material layer keeps focus/ink feedback visible.

The host disables widget-aware tickers outside resumed lifecycle state (a null
initial state permits startup). Navigator route TickerModes suppress covered
routes; offscreen consumers must respect ancestor TickerMode. M02 introduces no
decorative loops, timers, video, or expensive renderers. Future media must pause
and dispose its external resources explicitly; TickerMode does not pause video or
arbitrary timers. No hardware grading or performance guarantee is implied.

Safe areas, a keyboard-resizing scroll viewport, wrapping labels, and bounded
width keep settings usable. Widget checks cover 320×480, 3× text, safe padding,
and a 180px simulated keyboard in both themes. These are not physical-device
keyboard or screen-reader verification.

## Verification and API references

Run the checks in the [README](../README.md). Tests mirror production under
`redkeep/test/features/appearance`, `test/core`, and `test/app`. Widget/controller
tests use fresh scopes and fake repositories, never app-owned storage. Repository
tests use synthetic preferences and disposable SQLite files, including background
executor close/reopen. Version 1 has no predecessor; fresh creation is compared
against the saved snapshot. Every future upgrade needs migration and preserved
data checks.

Official references checked for adoption:

- [Drift background execution](https://drift.simonbinder.eu/platforms/vm/),
  [schema export](https://drift.simonbinder.eu/migrations/exports/), and
  [verification](https://drift.simonbinder.eu/migrations/tests/).
- [Drift](https://pub.dev/packages/drift), [drift_dev](https://pub.dev/packages/drift_dev),
  [build_runner](https://pub.dev/packages/build_runner), and
  [path_provider](https://pub.dev/packages/path_provider).
- [Android disableAnimations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html),
  [iOS reduceMotion](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/reduceMotion.html),
  and [TickerMode](https://api.flutter.dev/flutter/widgets/TickerMode-class.html).

Drift 2.35.3 uses sqlite3 native assets without `sqlite3_flutter_libs`.
path_provider 2.1.6 supports Android SDK 24+ / iOS 13+, compatible with the plan's
later Android 11 / iOS 15 floors. Android debug packaging and emulator smoke
evidence are in the M02 record; iOS and physical-device behavior remain unverified.
