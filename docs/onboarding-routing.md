# Onboarding and navigation

**UI01 correction — 3 November 2026:** the user requested the legacy full book
presentation and persisted name entry, superseding the earlier cropped-card/
completion-only design. See [the current book guide](onboarding-ui-migration.md).

## Responsibility and persistence

The five manually navigated chapters fold into the original name-entry cover.
**Let's begin** changes presentation only. **Save** requires a nonblank name and
waits for commit before routing. Chapter/cover state and uncommitted input are
transient; **Back to chapters** retains the name within that page instance.

Schema **8** adds nullable `name` to the existing constrained singleton
`onboarding_completion` row (`id=1`). `readName()` returns a trimmed, nonblank
name, and `isComplete()` derives from it. `complete(name)` commits the validated
name in one statement. Reading never seeds a row. A missing/blank name means
incomplete, including earlier completion-only installations: migration preserves
the old row with a null name and the user supplies their own name on onboarding.
No writing/settings are reset and no fake name is backfilled. Versions 1–7
upgrade to schema 8; snapshots and generated helpers remain in the repository.
There is no account, legacy-data importer or competing store.

`OnboardingController.load` runs through the bootstrap coordinator after the
settings/database read and before asset inspection. All local work shares the
existing five-second aggregate deadline, coalesced retries and splash release.
A failed/slow onboarding read uses **Retry local checks**; it cannot grant entry.
Required artwork downloads still occur only after the splash is released and
must finish before onboarding appears. Complete installations need no network.

The completion button disables during a save. Only a committed name save changes
routing. Failure retains the cover and continuation, reports a safe live-region
message and offers **Try again**. Leaving the app before completing does not mark
it complete. SQLite interruption leaves the name either committed or absent;
relaunch reads that actual state. Disposal ignores late UI updates, without
pretending an already committed transaction was canceled.

## Navigation boundary

`app/navigation_destination.dart` owns the currently accepted application
locations: `/`, `/settings`, `/notes`, `/notes/:id` and `/notes/:id/edit`, plus
the Diary/calendar/day/entry/editor/search routes listed in the [Diary guide](diary-writing.md), and
`/unavailable` for the real fallback page. M06 validates 32-character lowercase
hex note IDs and handles missing/deleted sources in the reader/editor. See
[Notes writing and recovery](notes-writing.md). M09 adds `/flow`, `/flow/:id`, `/flow/:id/edit` and `/more`; see
[Flow and the implemented shell](flow-writing.md). Brain and task routes remain
unregistered.

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
2. Ready startup without a saved name uses `/onboarding`.
3. Ready startup with a committed nonblank name opens the requested destination.

The gate URI carries exactly one `continue` parameter containing only `/`,
`/settings`, the implemented Notes/Diary/Flow/More destinations or the canonical `/unavailable` fallback. For example,
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
normal screen to pop into. Root system back can leave during the tour. On the naming cover, back first
dismisses input focus/keyboard, then reopens the book as in the legacy workflow;
back from the tour can exit. An in-flight save retains normal root-exit behavior. Completion does not leave onboarding in back
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

Book, save-error and startup screens use safe areas, scrolling bounded
content, wrapping text and accessible actions. UI01 restores the original
bottom legal links and uses page taps/swipes, keyboard arrows and semantic
chapter actions instead of added navigation buttons. The user-selected
`grand_maestar.png` is bundled; Allura uses Google Fonts runtime fetching/caching
without a bundled font binary. Other typography uses system fonts. UI01 adds nine
required presentation files through the existing catalog/repair gate. The book preserves its original facing-page geometry at ordinary sizes, adds
scrolling live text and name entry when constrained, and uses immediate flat/
static presentation with reduced motion or simpler effects. No startup or
route-selection logic lives inside book widgets.

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
trashed-source restore/deletion actions on the existing reader. M08 adds the
Diary calendar, civil dates and entry routes. M09 adds Flow and a shared
Diary/Notes/Flow/More shell. More contains Appearance; the `/settings` route and
its home back stack remain supported. UI01 does not authorize a further phase.

Official APIs checked alongside the locally resolved source:

- [go_router redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [MaterialPage](https://api.flutter.dev/flutter/material/MaterialPage-class.html)
  and [PageTransitionsTheme](https://api.flutter.dev/flutter/material/PageTransitionsTheme-class.html)
- [Drift migration verification](https://drift.simonbinder.eu/migrations/tests/)


M08 makes the home experience the Diary calendar and adds validated civil-date
Diary/calendar/entry/editor/search destinations. These use the same startup and
onboarding continuation boundary. Valid but wrong-date/deleted entry IDs show a
safe feature fallback; non-canonical or invalid dates use `/unavailable`.
See [Diary routes and dates](diary-writing.md#dates-and-routes).
