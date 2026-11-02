# Onboarding and navigation

## Responsibility and persistence

M05 adds one accessible welcome page with live Redkeep text and **Enter Redkeep**.
It describes the implemented appearance, accessibility and offline artwork
behavior. It introduces no additional media, feature tabs or unavailable feature
claims. `features/onboarding/domain/OnboardingRepository` exposes `isComplete`
and `complete`; the Drift adapter uses the same background primary database as
Appearance. `app/storage_providers.dart` owns its composition.

Schema **2** adds only `onboarding_completion`. Its constrained singleton row
(`id = 1`) means completion; no row means incomplete. Reading never seeds it.
Completion is idempotent and the repository future resolves after commit.
Migration 1 → 2 creates that table and preserves all appearance values. Both
schema snapshots and generated migration helpers remain in the repository.
There is no onboarding reset, account, old-data importer or competing store.

`OnboardingController.load` runs through the bootstrap coordinator after the
settings/database read and before asset inspection. All local work shares the
existing five-second aggregate deadline, coalesced retries and splash release.
A failed/slow onboarding read uses **Retry local checks**; it cannot grant entry.
Required artwork downloads still occur only after the splash is released and
must finish before onboarding appears. Complete installations need no network.

The completion button disables during a save. Only a committed save changes
routing. Failure retains the page and continuation, reports a safe live-region
message and offers **Try again**. Leaving the app before completing does not mark
it complete. SQLite interruption leaves the marker either committed or absent;
relaunch reads that actual state. Disposal ignores late UI updates, without
pretending an already committed transaction was canceled.

## Navigation boundary

`app/navigation_destination.dart` owns the currently accepted application
locations: `/`, `/settings`, `/notes`, `/notes/:id` and `/notes/:id/edit`, plus
`/unavailable` for the real fallback page. M06 validates 32-character lowercase
hex note IDs and handles missing/deleted sources in the reader/editor. See
[Notes writing and recovery](notes-writing.md). Diary, Flow, Brain and task
routes remain unregistered.

Internal controls use `AppDestination` locations. Pass any untrusted string
through `validatedNavigationLocation` **before** calling go_router; do not hand
raw external text to `go`/`push`. Application destinations are absolute paths
within the app, case-sensitive, with no scheme, authority, query or fragment.
Dart URI normalization happens first (for example, an encoded unreserved letter
can normalize to `/settings`). External URLs, extra path segments, trailing
slashes, query parameters and fragments are rejected. Unsupported or malformed
input becomes `/unavailable`; incoming content, paths and exceptions are never
shown as UI text or retained in the fallback destination.

`createAppRouter(ref, initialLocation: ...)` creates one scope-owned router,
uses the validated explicit or Flutter platform initial location, and disposes
with its scope. Provider listeners refresh redirects without recreating the
router when bootstrap, onboarding or appearance state changes.
`NavigationRouteInformation` validates subsequent platform route information
before the parser. It forwards listeners to the router-owned provider. For a
malformed UTF-8 query it replaces the bad history entry using the public
`neglect` reporting mode: go_router 18.1.2 otherwise decodes its old query during
comparison and throws even after rejection. Review this small adapter when
upgrading go_router. Normal history reporting is forwarded unchanged.

`navigationRedirect` is a pure, tested policy:

1. Local checks, errors, missing artwork and downloads use `/startup`.
2. Ready startup with incomplete onboarding uses `/onboarding`.
3. Ready startup with committed completion opens the requested destination.

The gate URI carries exactly one `continue` parameter containing only `/`,
`/settings`, the implemented Notes destinations or the canonical `/unavailable` fallback. For example,
`/startup?continue=%2Fsettings` becomes `/onboarding?continue=%2Fsettings`, then
`/settings`. Gate links without a query default home. Extra/duplicate parameters,
empty values, nested gates, double-encoded destinations, external continuations,
fragments and invalid encoded text resolve to the fallback. No arbitrary query
content is copied. Repeated refreshes and duplicate destinations settle without
redirect loops. A new incoming destination replaces the pending one.

The pending destination lives in the route URI, not another preference or a
mutable global queue. It survives checking, timeout, download/save failure,
repair and onboarding in that navigation session. Reopening with the same gate
URI resumes its validated continuation. A new process with no restored or
redelivered URI starts at home after onboarding; M05 does not add a durable link
inbox or OS process-restoration guarantee. Completion itself is durable across
ordinary launches.

## Back behavior, rendering and recovery

Startup and onboarding replace the normal route stack. They have no hidden
normal screen to pop into. Root system back can leave the app; no PopScope or
back interception traps the user. Completion does not leave onboarding in back
history. `/settings` is a child of home, so direct entry as well as the home
Appearance control has a real home route underneath. Toolbar back, Android
system back and iOS edge swipe return home. The fallback has a **Return home**
replacement; it never retries an invalid URL.

Material pages use the central rendering-policy host's transition builders:
180ms framework Android predictive-back/fade transitions and iOS Cupertino
transitions while motion is allowed, or immediate changes when reduced/inactive.
iOS retains its edge-swipe detector with stationary animations under reduction.
Android reduced motion commits system back normally without predictive effects.
Live OS/app reduction removes visible transition motion, and the existing
lifecycle/TickerMode policy remains in force. No widget performs route selection
or startup work, and no custom gesture recognizer overrides framework behavior.

Welcome, save-error and startup screens use safe areas, scrolling bounded
content, system fonts, wrapping text, accessible buttons and simple paper.
Neither the welcome page nor navigation needs a new downloaded asset.

## Verification and limitations

Run the [README](../README.md) checks, including:

```sh
flutter test test/app test/features/onboarding test/features/appearance test/core
flutter test
```

Tests use fresh scopes, small fake boundaries, synthetic settings and disposable
background SQLite databases. They cover incomplete/complete close/reopen,
version-1 migration/data preservation, idempotent writes, commit timing, failed
loads/saves, overlap/disposal, interruption/relaunch, cold/warm invalid links,
malformed UTF-8 platform input, all readiness combinations, no redirect loops,
continuations through checks/download retry/onboarding/repair, latest/duplicate
requests, and normal back history. Framework iOS swipe cancellation/completion
and Android back-channel cancellation/commit are tested in normal/reduced modes.
Layout tests exercise both themes at 320×480 with 3× text, safe-area padding and
simulated keyboard insets; policy tests also cover live reduction mid-transition.

Widget gestures and channel events are not physical-device gesture,
screen-reader, OS link-registration or keyboard evidence. Universal/app-link
hosting and native URL registrations are not introduced. Release performance,
minimum-OS and low-end hardware qualifications remain outstanding. M04's real
HTTPS asset-host prerequisite and M03's AI hardware gaps remain unchanged.
M06 extends these contracts for Notes. M07 keeps the same routes and adds
trashed-source restore/deletion actions on the existing reader. M08 is next.

Official APIs checked alongside the locally resolved source:

- [go_router redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [MaterialPage](https://api.flutter.dev/flutter/material/MaterialPage-class.html)
  and [PageTransitionsTheme](https://api.flutter.dev/flutter/material/PageTransitionsTheme-class.html)
- [Drift migration verification](https://drift.simonbinder.eu/migrations/tests/)
