# Onboarding assets: build configuration and local pack

UI01 integrates the supplied originals without downloading them again or
changing their formats. The canonical reference library remains under
[`assets/reference/`](../assets/reference/README.md), outside Flutter's bundle.
The revised download pack contains eight exact copies plus the four retained
PNGs: `presentation-ui01-v3`, **12 images / 2,658,676 bytes**. Ink paper and the
Grand Maester mascot ship under `assets/branding/` and render offline at startup
and in onboarding; their exact reference originals are retained. The original cover now
has a real consumer: the restored folding name-entry cover. See [the book guide](onboarding-ui-migration.md)
for the restored full-spread presentation and name workflow.

## Prepare the supplied Firebase sources

Run from `/Users/lewis/Dev/Projects/The Redkeep/redkeep`:

```sh
dart run tool/prepare_asset_sources.dart onboarding-downloads.local.json env.json
flutter run --dart-define-from-file=env.json
```

For a new checkout, first copy `env.example.json` to ignored `env.json` and
`onboarding-downloads.example.json` to ignored
`onboarding-downloads.local.json`, then fill the real HTTPS sources locally.
Add `-d <device-id>` to `flutter run` when needed. Use the same define-file flag
for separately authorized builds. Hot reload does not replace compile-time
values; stop and rerun after preparing changed source URLs.

The preparation command performs **no requests**. It validates cataloged keys
and complete per-image HTTPS URLs for current catalog consumers, and
serializes the consumed map as the **string** define `ASSET_SOURCE_URLS_JSON`
inside `env.json`. It atomically replaces that file while preserving
`ASSET_BASE_URL`, `ASSET_ALLOW_LOCAL_FIXTURE` and all unrelated values. It prints
only a count or safe error, never URLs. `env.json.pending` is ignored too. The
runtime reads compile-time defines, never repository/configuration files.

Keep each Firebase URL intact, including the encoded object path and original
`?alt=media&token=...` query. Do not reuse a token for other files, use `&amp;`
in JSON, strip queries, or paste an object URL into `ASSET_BASE_URL`. Runtime
keys describe purpose independently of remote filenames; the Maester key maps
to the user's `ai.webp`. No Firebase SDK or dotenv dependency is needed.

The handoff supplies all twelve required download source keys:

```text
appearance.theme.system
appearance.theme.light
appearance.theme.dark
notes.add
onboarding.cover
onboarding.chapter.notes
onboarding.chapter.diary
onboarding.chapter.maester
onboarding.chapter.flow
onboarding.chapter.appearance
onboarding.material.paper
onboarding.material.binding
```

The input includes `onboarding.cover`; preparation now includes it because the
original cover is consumed. It accepts reviewed sources for current catalog keys. Empty input
values are omitted and use the directory fallback. The retired
`onboarding.background.ink` entry is accepted and omitted from prepared maps;
runtime also ignores it in older compiled maps, so no background is downloaded.
Other unknown keys and invalid consumed sources reject preparation without
modifying the previous env file.

## Supplied sources and directory fallback

The user supplied the four existing PNG URLs after the initial UI01 check.
Together with the eight remaining onboarding URLs, **all 12 required catalog
entries have explicit HTTPS sources**. Preparation writes those 12 entries,
including the now-consumed original cover. Existing onboarding URLs and every unrelated
env value are preserved.

The user's `ASSET_BASE_URL` directory template remains unchanged. This configured
pack uses explicit sources for every required path, so it no longer selects that
placeholder fallback. Source URLs are configuration input, not proof of live
availability or matching remote bytes; no live requests were performed for this
follow-up. Fully stop and rerun the app with the env define file to compile the
updated map, then use **Retry download** if needed.

The four additional keys map to these unchanged local/catalog payloads:

| Key | Path under the directory base |
| --- | --- |
| `appearance.theme.system` | `appearance/theme-system-v1.png` |
| `appearance.theme.light` | `appearance/theme-light-v1.png` |
| `appearance.theme.dark` | `appearance/theme-dark-v1.png` |
| `notes.add` | `notes/add-v1.png` |

`ASSET_BASE_URL` remains the normal directory host, ending in `/`, without
credentials, query or fragment. Explicit object URLs take precedence only for
their cataloged paths. Directory-only builds still work without a source map.
The HTTP adapter retains identity bytes, HTTP 200/no redirects, deadlines and
safe failures. No source URL is stored in the installation ledger.

## Offline verification and controlled local fixture

From `redkeep/`:

```sh
flutter pub get --enforce-lockfile --offline
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack
```

The validator reads local payloads only: actual format/extension, still-image
decode and dimensions ≤2048×2048, exact size/SHA-256, provenance and exact pack
inventory. Runtime inspection/install/resolution uses the same decoder
qualification off the UI isolate when files need verification. The byte/hash,
symlink, atomic rename, repair and independent-writing guarantees remain.

The controlled pack is under `redkeep/tool/assets/pack/`; its onboarding paths
preserve the original `.webp`/`.jpg` extensions. Neither the pack nor the
reference library is bundled. The user-selected `grand_maestar.png` mascot and
`ink-paper.webp` background have separate exact bundled copies; Allura uses
Google Fonts with no bundled font binary. Branding needs no Firebase URL and is
excluded from required downloads and repair checks.

If a future explicitly selected native smoke check needs directory-only local
hosting, follow [the controlled fixture instructions](assets-startup.md#local-fixture-and-host-setup)
and pass only the loopback/base flags there, **without** the token-bearing env
file, so the source overrides do not select Firebase instead. Do not clear user
app data to force onboarding; use an isolated incomplete test installation.

UI01's checks use injected local resolvers/clients and disposable stores. No
live Firebase request, reference refresh, native launch, device install, upload
or host publication was performed. A complete verified installation still opens
offline. Missing files use the preserved splash/local checks and Flutter repair
screen while retaining completion, writing and the validated continuation.

The earlier dummy-config, partial-source and reference-acquisition steps are
recorded chronologically in [the migration plan](../MIGRATION_PLAN.md). They
are superseded by this implementation. Public redistribution rights, real host
verification and physical-device evidence remain release prerequisites.
