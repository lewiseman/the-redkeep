# Redkeep

The mobile Flutter app lives in `redkeep/`. The Riverpod/go_router shell has light/dark paper themes,
saved appearance settings, and a reactive motion/effects policy. The agreed roadmap and phase
evidence live in [MIGRATION_PLAN.md](MIGRATION_PLAN.md); architecture and test
contracts live in [docs/architecture-testing.md](docs/architecture-testing.md).
See [appearance and persistence](docs/appearance-persistence.md) for settings,
database, rendering-policy, and recovery contracts.
M03 adds an opt-in local inference adapter and synthetic verification entry
point. See [AI feasibility](docs/ai-feasibility.md) for pinned artifacts, native
setup, reproduction commands, evidence, and remaining hardware gaps. Normal
startup does not initialize AI or require a model.
M04 adds bounded local bootstrap, a required-artwork download/repair gate, and
an injectable persistent asset resolver. See [assets and startup](docs/assets-startup.md)
for the media inventory, provenance, local fixture setup and release host checks.
The default build has no configured host: a fresh installation stops at the
artwork gate until run with the documented controlled fixture configuration.
Complete installations reopen offline without a catalog/network check.
M05 adds a minimal welcome, persisted completion in schema 2, validated startup/
onboarding redirects and platform back behavior. See [onboarding and navigation](docs/onboarding-routing.md)
for destination validation, recovery and interruption contracts.
M06 adds local plain-text Notes, stable ID-based readers/editors, committed-save
feedback and persistent recovery drafts in schema 3 of the same database. See
[Notes writing and recovery](docs/notes-writing.md) for revision protection,
deletion retention, failure behavior and offline verification. M07 extends Notes
with local keyword/tag/pin filters, Trash/restore, typed permanent deletion and
safe Markdown preview. Schema 4 preserves all existing writing and settings;
the required pack adds the single Notes create illustration.

Use Flutter 3.47.5 / Dart 3.13.4 (the verified local baseline). From the workspace
root:

```sh
cd redkeep
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack
```

Run the shell on an available mobile device or emulator:

```sh
cd redkeep
flutter devices
flutter run -d <device-id>
```

To apply formatting during development, run `dart format lib test tool` from `redkeep/`.
The fast suite needs no accounts, presentation downloads, models, or user data.
Widget tests inject repositories; persistence tests use disposable SQLite
databases, including background execution and close/reopen checks.
Dependency resolution needs pub.dev access on a fresh machine; tests use the
resolved local packages. Keep `redkeep/pubspec.lock` under version control.

After changing Drift tables, regenerate code and a versioned schema snapshot:

```sh
cd redkeep
dart run build_runner build
dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/
mkdir -p test/core/storage/generated
dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/
dart format lib test
```

M02 establishes schema version 1; M05 migrates to schema 2 while retaining
appearance settings. M06 extends it to schema 3 for Notes and recovery drafts,
preserving settings and onboarding. M07 adds pins and tags in schema 4 and tests
upgrades from versions 1–3. Each subsequent schema change needs a version
bump and migration/data-preservation tests. Preserve historical snapshots after
shipping that version. Keep generated Drift code and schema helpers with source.
For Android packaging verification, run
`flutter build apk --debug --target-platform android-arm64` from
`redkeep/`.

This is one local Git repository at the workspace root. Existing platform files
remain in the mobile app; the starter's macOS runner is preserved, without a new
desktop app. `raw_assets/` remains untouched local source material, ignored by
Git and excluded from application assets. Build caches, local configuration, and
signing credentials are ignored; generated Flutter/native files retain the
starter's platform-specific ignore rules.
