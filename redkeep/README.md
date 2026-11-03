# Redkeep mobile

The Flutter shell uses Riverpod and go_router for a Diary-first home, Notes, Flow, More/appearance settings,
a persisted welcome flow, and unavailable-page recovery. Diary, Notes, Flow and settings share the primary Drift database; system
fonts and programmatic paper surfaces need no downloads.
Required Appearance and Notes create artwork is downloaded separately. Fresh installations
are gated until the pack is verified; complete installations work offline. A
host is intentionally unconfigured by default. Use the controlled local fixture
instructions in [assets and startup](../docs/assets-startup.md) for development.

UI01 restores the legacy full illustrated book and folding name-entry cover.
**Save** requires and commits the user's name before routing; no name means
onboarding. Schema 8 upgrades existing data without clearing writing/settings.
`presentation-ui01-v3` contains eight supplied originals plus four retained
PNGs: 12 images / 2,658,676 bytes. The selected Grand Maester mascot, Allura caption, dots and
bottom Terms/Privacy links are restored; the added navigation buttons are gone.
The user-provided `grand_maestar.png` and `ink-paper.webp` ship unchanged under
`assets/branding/`. Startup uses the paper background, mascot and download
progress bar; both onboarding layouts also use the bundled background. Allura uses
`google_fonts` runtime fetching/caching, with no bundled font binary; its local
reference keeps tests offline. Downloaded artwork remains outside the bundle. See
[the current book guide](../docs/onboarding-ui-migration.md).

Prepare the ignored sources and run from this directory:

```sh
dart run tool/prepare_asset_sources.dart onboarding-downloads.local.json env.json
flutter run --dart-define-from-file=env.json
```

The command serializes the consumed source map as the string define
`ASSET_SOURCE_URLS_JSON`, preserving `ASSET_BASE_URL` and all unrelated entries.
Keep complete Firebase object URLs and tokens in ignored inputs/configuration.
All 12 required downloads have supplied HTTPS sources in ignored build
configuration. Live Firebase/fresh-install verification remains unperformed. See
[asset setup](../docs/onboarding-assets-setup.md) for exact contracts and offline
checks. References remain outside the app bundle and are never fetched by tests.

M05 redirects through startup and onboarding while preserving validated
requested destinations. See [onboarding and navigation](../docs/onboarding-routing.md)
for completion, back behavior, parameter validation and retry contracts.
M06 adds plain-text note creation, reading, editing, deletion and persistent
recovery drafts with source revision checks. M07 adds local search/tag/pin filters,
Trash/restore, typed permanent deletion and safe Markdown preview in schema 4. See [Notes writing and recovery](../docs/notes-writing.md).

M08 adds civil-date Diary entries, calendar/day/entry routes, local keyword
search, independent day headings and durable recovery in schema 5. See
[Diary writing and recovery](../docs/diary-writing.md).

M09 adds quick capture, durable composer/edit drafts, ID-based thought reading/
editing/deletion and newest-first Flow in schema 6. The shell now offers Diary,
Notes, Flow and More. See [Flow capture and recovery](../docs/flow-writing.md).

See the [workspace README](../README.md) for setup/run/check commands and
[architecture/testing guide](../docs/architecture-testing.md) for contracts,
test coverage, and limitations. The selected implementation phase is governed by
[MIGRATION_PLAN.md](../MIGRATION_PLAN.md) and [AGENTS.md](../AGENTS.md).
See [appearance and persistence](../docs/appearance-persistence.md) for storage,
rendering policy, schema generation, and failure recovery.
See [AI feasibility](../docs/ai-feasibility.md) for the explicit synthetic native
harness. The regular app entry point neither loads models nor initializes AI.

M10 adds optional device Brain settings at `/settings/brain`, assignments in schema 7,
verified model downloads/removal and explicitly requested synthetic tests. See
[Brain](../docs/brain.md). No model loads during ordinary writing startup.

M11 adds contextual Grand Maester assistance. See
[the feature guide](../docs/grand-maester.md) for explicit actions, proposal review,
source/selection guards and the opt-in synthetic native harness.
