# Local copies of remote presentation assets

This directory is the tracked, byte-for-byte reference library for approved
remote asset handoffs. Keep the real downloaded files and `manifest.json` in
Git alongside the code so agents, reviewers and future tests can inspect assets
offline. The directory is outside the Flutter app and is not included in
`redkeep/pubspec.yaml` or shipped in the application bundle.
The latest resource correction also indexes the user-selected Grand Maester
mascot and the Allura font reference used by offline tests. The mascot and
ink-paper background have separate exact bundled image copies; reference paths
remain outside the bundle. The app always uses these two bundled images.

## Find an image without downloading

Read `manifest.json` and locate an asset by its stable key. Its `path` is relative
to this directory. Onboarding media mirrors the remote prefix `redkeep/assets/`:

```text
assets/reference/images/onboarding/cover.webp
assets/reference/images/onboarding/notes.webp
assets/reference/images/onboarding/diary.webp
assets/reference/images/onboarding/ai.webp
assets/reference/images/onboarding/flow.jpg
assets/reference/images/onboarding/appearance.jpg
assets/reference/images/onboarding/ink-paper.webp
assets/reference/images/onboarding/paper-edge.webp
assets/reference/images/onboarding/binding-cloth.webp
```

The manifest records the key, local relative path, actual bytes, SHA-256, image
or font type, and remote bucket/object identity or explicit source provenance.
It deliberately omits token-bearing
download URLs. Full URLs stay in ignored `redkeep/onboarding-downloads.local.json`.
The `onboarding.chapter.maester` key currently points to the supplied `ai.webp`;
the key describes intended use and does not assert that the image is rebranded
or approved for the new UI.

## Populate or refresh intentionally

From the workspace root, download supplied assets that are missing or whose
recorded local copy no longer matches:

```sh
python3 tools/sync_asset_references.py --download
```

To explicitly fetch all current remote bytes after a remote replacement:

```sh
python3 tools/sync_asset_references.py --download --refresh
```

Default invocation is offline and lists the manifest only:

```sh
python3 tools/sync_asset_references.py
```

The current tool consumes Firebase object URLs for PNG, JPEG and WebP images,
mirroring paths below `redkeep/assets/`. It preserves bytes and extensions,
limits an image to 10 MiB, rejects redirects/unrecognized image headers, writes
through temporary files, and records completed downloads individually. It never
edits `raw_assets/`, removes unrelated references, updates the runtime catalog,
or uploads anything. Changing a remote object without changing its identity
requires an explicit refresh; normal inspection does not contact Firebase.

## Current onboarding reference inventory

Downloaded from the user's completed URL handoff on 3 November 2026: nine images,
**2,520,638 bytes** total. Sizes below were read from the local files without
re-encoding them. The manifest is authoritative for bytes and hashes.

| Asset key | File below `images/onboarding/` | Dimensions |
| --- | --- | --- |
| `onboarding.cover` | [cover.webp](images/onboarding/cover.webp) | 1122 × 1402 |
| `onboarding.chapter.notes` | [notes.webp](images/onboarding/notes.webp) | 1448 × 1086 |
| `onboarding.chapter.diary` | [diary.webp](images/onboarding/diary.webp) | 1448 × 1086 |
| `onboarding.chapter.maester` | [ai.webp](images/onboarding/ai.webp) | 1448 × 1086 |
| `onboarding.chapter.flow` | [flow.jpg](images/onboarding/flow.jpg) | 1448 × 1086 |
| `onboarding.chapter.appearance` | [appearance.jpg](images/onboarding/appearance.jpg) | 1448 × 1086 |
| `onboarding.background.ink` | [ink-paper.webp](images/onboarding/ink-paper.webp) | 1024 × 1536 |
| `onboarding.material.paper` | [paper-edge.webp](images/onboarding/paper-edge.webp) | 1024 × 341 |
| `onboarding.material.binding` | [binding-cloth.webp](images/onboarding/binding-cloth.webp) | 192 × 576 |

Visual inspection of the local cover, AI and Appearance images confirms printed
Journal/AI labels; Appearance also says "Colors, themes and fonts." These are
the supplied reference originals, not the text-free Redkeep replacements in
the UI01 brief. Preserve these bytes. Any approved rebranding happens as a
separately selected asset change, with updated remote/local bytes and metadata.

Existing files in this library must not be edited/recompressed as a way to
change the remote image. Update the remote source deliberately, refresh, review
the binary/manifest diff, and update the shipping catalog separately when
authorized. Do not overwrite an old path with new bytes and leave its old
runtime revision/hash in place. Project asset provenance still needs review;
user-provided URLs do not establish a license or a successful UI migration.

## Tests and deployment

Future asset-dependent tests must read these local files or smaller derived
fixtures and injected local resolvers. Tests must never refresh this library or
make network requests. Reading the manifest/images needs no URL list or token.
No test hook, startup hook, CI fetch, or bundled fallback is added here.

UI01 extends the separate deployment fixture under
`redkeep/tool/assets/pack/` with eight byte-for-byte copies: five full illustration
spreads, two book textures and the original folding name-entry cover. The ink-paper
original stays here; its app copy ships under `assets/branding/ink-paper.webp`
alongside the Grand Maester mascot and is excluded from the download fixture.
All nine original files and manifest rows remain unchanged. The runtime now supports
PNG/WebP/JPEG and pins the exact copied metadata; see the
[book guide](../../docs/onboarding-ui-migration.md). Installed-app downloads
remain independent of this reference library. No test refreshes it.

## Selected mascot and offline font reference

Two additional manifest entries support the selected onboarding screen:

- `branding/grand_maestar.png`: exact user-provided
  `redkeep/assets/branding/grand_maestar.png`, 1,842,097 bytes, tagged
  `bundled-branding`; source path and hash are indexed. The superseded original
  J mascot copies were removed.
- `fonts/Allura-Regular.ttf`: exact 109,228-byte Allura file identified by the
  legacy Google Fonts mapping, acquired once from the manifest's pinned public
  URL, tagged `test-reference`. `fonts/Allura-OFL.txt` retains the Google Fonts
  OFL notice.

The app's mascot copy is byte-for-byte identical. The app has no bundled font
binary: `google_fonts` fetches/caches Allura on demand, while tests preload this
exact local font reference with runtime fetching disabled. The license-only
copy under `redkeep/assets/licenses/` ships and is registered with Flutter.
The mascot/font references are separate from the 12-image download pack and
Firebase refresh input; the unchanged ink-paper remote reference remains indexed
for deliberate refresh, with an exact separate bundled app copy. The
refresh tool retains these additional rows without fetching or replacing them.
