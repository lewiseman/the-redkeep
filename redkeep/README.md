# Redkeep mobile

The Flutter app uses Riverpod and go_router for Diary, Notes, Flow, More/settings,
onboarding and recovery. Writing and settings share the primary Drift database.

Required artwork downloads from the `ASSET_BASE_URL` image directory in ignored
`env.json`, currently `https://redkeep.lewiseman.com/art/`.
`website/public/art/` is its canonical local source and the image input for offline
tests. `presentation-website-v1` pins 12 images / 2,800,992 bytes, including the
website's Redkeep castle cover. Existing installations reuse the eleven unchanged
images. Downloads are verified and installed into persistent app-owned storage;
a complete installation opens offline.

From this directory, copy `env.example.json` to ignored `env.json` on a new
checkout. It contains only `ASSET_BASE_URL`. Run:

```sh
flutter run --dart-define-from-file=env.json
```

The editor's Debug/Profile/Release configurations pass the same env file. There is
no Firebase source list, token map, HTTP fixture flag or preparation command.
See [asset setup](../docs/onboarding-assets-setup.md) for adding artwork and the
single base-URL configuration. Changing it requires a full stop and rerun.

The Grand Maester mascot and ink-paper background remain bundled for startup and
both onboarding layouts. Allura uses Google Fonts fetching/caching without a
bundled font binary; the retained local font reference keeps tests offline.
**Save** commits the onboarding name before continuing. Schema 8 and existing
writing/settings are unchanged. See [the book guide](../docs/onboarding-ui-migration.md).

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
