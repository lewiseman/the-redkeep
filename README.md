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
The configured image directory is `https://redkeep.lewiseman.com/art/`, passed
through the single `ASSET_BASE_URL` value in ignored `redkeep/env.json`.
Complete installations reopen offline without a remote catalog/network check.
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

M08 adds a Diary-first calendar, date-addressable day and entry readers, text
entry editing/deletion, recovery drafts and local keyword search in schema 5.
Entries use civil dates and live separately from optional day headings. See
[Diary writing and recovery](docs/diary-writing.md) for date, save and deletion
contracts, accessible notebook presentation and evidence.

M09 adds quick text capture, newest-first thoughts, ID readers/editors and durable
capture/edit drafts in schema 6. The shared shell now offers Diary, Notes, Flow
and More, with Appearance and Brain under More. See [Flow capture and recovery](docs/flow-writing.md).

M10 adds optional Brain settings, persisted device capability assignments in
schema 7, verified model install/removal, cancellable synthetic tests and bounded
resource lifetime. Normal writing opens without AI. See [Brain](docs/brain.md)
for contracts, recovery, available native evidence and remaining hardware gaps.
M11 adds the contextual Grand Maester helper, streamed proposals, copy-only
summaries/reflections and guarded Note rewrite acceptance into recovery drafts.
See [Grand Maester](docs/grand-maester.md) for source/selection protection and
separate native smoke commands.

UI01 restores the legacy full illustrated book, curved paper, binding, manual
turns and original folding cover. **Let's begin** reveals name entry; **Save**
commits the name before opening the validated router continuation. A user
without a saved name opens onboarding, including an earlier completion-only
installation. Schema 8 preserves all writing/settings while adding the name.
See [the current book guide](docs/onboarding-ui-migration.md). Desktop and M12 remain separately scoped.
The user hosts the shared website and artwork at `https://redkeep.lewiseman.com/`.

The user-selected Grand Maester mascot, script caption, page dots and bottom Terms/Privacy links
are restored. Navigation uses page taps/swipes, keyboard and semantics, with no
added Previous/Next, Back button or visible counter.

`presentation-website-v1` contains **12 images / 2,800,992 bytes**, including the
website's Redkeep castle cover. `website/public/art/` is the canonical local image
source for both apps and offline tests. The mobile app receives one HTTPS image
base through `env.json`. Per-image URL maps, tokens, HTTP fixture flags and
preparation commands remain removed. The eleven unchanged installed images are reused during upgrades.

`grand_maestar.png` and `ink-paper.webp` remain bundled for immediate startup and
onboarding. Allura uses Google Fonts fetching/caching; its existing local font
reference keeps tests offline. Historical reference files remain outside bundles.

From `redkeep/`, copy `env.example.json` to ignored `env.json` on a new checkout,
then run:

```sh
flutter run --dart-define-from-file=env.json
```

To add an image: put it in `website/public/art/`, add its key/source filename and
reviewed metadata to the mobile catalog, connect its consumer, deploy the website
and ship the updated app. See [asset setup](docs/onboarding-assets-setup.md).
The website build runs TypeScript, Vite and prerendering with no custom asset
checker or whole-site size gate.

Use Flutter 3.47.5 / Dart 3.13.4 (the verified local baseline). From the workspace
root:

```sh
cd redkeep
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json ../website/public/art
```

Run the shell on an available mobile device or emulator:

```sh
cd redkeep
flutter devices
flutter run -d <device-id> --dart-define-from-file=env.json
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
upgrades from versions 1–3. M08 adds separate Diary entries, drafts and day
headings in schema 5, preserving versions 1–4. M09 adds Flow thoughts and recovery
drafts in schema 6, preserving versions 1–5. M10 adds unseeded Brain assignments
in schema 7, preserving versions 1–6. UI01 adds the saved onboarding name in
schema 8 and preserves versions 1–7; completion now requires that name. Each subsequent schema change needs a version
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

## Website (W01, local only)

The sibling `website/` retains the selected Journal UI and unchanged screenshots,
with Redkeep naming and current product copy. Download buttons have no
destination. The user removed Simpler view and website reduced-motion handling.
See [the website guide](docs/website.md) for contracts, evidence and publishing
prerequisites. From `website/` with Node 22.12+ or 24+:

```sh
npm ci
npm run typecheck
npm run lint
npm run build
npm test
npm run dev
```

Tests use installed Google Chrome in isolated profiles and local assets only.
`npm run preview -- --port 4173` serves the production output. No website
registration, remote source operation or publication is part of W01.
