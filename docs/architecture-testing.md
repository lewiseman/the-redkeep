# Mobile shell: architecture and testing

## Responsibility and contracts

`redkeep/lib/main.dart` initializes bindings, preserves the native splash and
starts `ProviderScope` and `RedkeepApp`.
`app/redkeep_app.dart` composes `MaterialApp.router`, light/dark themes, committed
appearance state, and the rendering-policy host. `app/app_router.dart` creates
one GoRouter per scope and disposes it with that scope. Appearance rebuilds keep
the same router. Tests override it using
`createAppRouter(initialLocation: ...)`; production preserves platform initial
location behavior.
The bootstrap gate wraps the router and preserves that destination while local
checks, downloads and retries run. Its five-second aggregate local limit and
splash lifecycle are documented in [assets and startup](assets-startup.md).

Registered destinations are `/` (welcome) and `/settings` (appearance). Home pushes
settings so back returns home; settings can also open directly. Unmatched routes
show a readable fallback with **Return home**, replacing the unavailable route.
Incoming URL content and raw errors are never displayed. Routes use the central
180ms fade/immediate policy, including live changes during a transition.

`app/app_shell.dart` supplies a scaffold, safe area, keyboard-resizing scroll
viewport, and bounded content width. `core/presentation` contains consumed theme,
paper-surface, and rendering-policy primitives. They use system fonts and
programmatic surfaces. Appearance consumes three downloaded static theme images
through the injectable resolver; bootstrap requires only bundled metadata and
system fonts. No feature tabs or production writing fixtures are registered.

`app/storage_providers.dart` composes the primary database and repository.
Feature domain types have no Flutter/database/plugin dependencies. Data adapters
map rows; controllers observe authoritative snapshots and coordinate saves. See
[appearance and persistence](appearance-persistence.md) for ownership, schema,
recovery, lifecycle, and generation contracts. Future phases extend this database.

## Tests and commands

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
flutter test test/core
flutter test test/features/ai
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
- `test/core` checks version 1 against its saved snapshot, SQL constraints,
  all OS/app/lifecycle combinations, both OS flags live, inactive/offscreen
  ticker gating, resumption, and disposal.
- `test/support/pump_app.dart` creates a fresh scope with a small observable fake
  appearance repository and fake required-assets boundary, keeping widget tests independent of path-provider and app-owned
  databases. Overridden routers retain production disposal ownership. Controller
  containers are fresh; repository tests clean up disposable files.
- `test/features/assets` verifies catalog/path/host constraints, HTTP response and
  redirect handling/cleanup through injected transport, real disposable file
  integrity and atomic-install recovery, missing/suspicious files, restart/retry,
  symlink rejection, storage failure and separate database preservation. The
  publishing check decodes the selected local PNGs and rejects bad packs.
- `test/app/bootstrap_test.dart` checks splash release before network, timeout,
  coalesced slow retries, local errors, disposal and progress. Startup widget
  checks cover required offline gating, preserved direct destinations, retry,
  reduced motion and narrow/large-text/inset layouts in both themes.

The [README](../README.md) documents schema generation and native build commands.
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
debug evidence and production-host prerequisites recorded separately. Onboarding
and writing features remain unstarted; M05 is next.

## References

- [Riverpod testing](https://riverpod.dev/docs/how_to/testing)
- [go_router setup](https://pub.dev/documentation/go_router/latest/topics/Get%20started-topic.html)
- [Appearance API references](appearance-persistence.md#verification-and-api-references)

Resolved versions, exact checks, and evidence gaps are in the migration plan.
