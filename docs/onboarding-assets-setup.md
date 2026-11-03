# Adding and serving app artwork

`website/public/art/` is the canonical local image source. Deploying the website
serves those files at `https://redkeep.lewiseman.com/art/`. The mobile app uses
the HTTPS image directory passed through `redkeep/env.json`:

```json
{
  "ASSET_BASE_URL": "https://redkeep.lewiseman.com/art/"
}
```

On a new checkout, copy tracked `env.example.json` to ignored `env.json` in
`redkeep/`. From that directory run:

```sh
flutter run --dart-define-from-file=env.json
```

Debug/Profile/Release editor configurations pass the same file. Use the same
flag for builds. Keep the `/art/` image directory and trailing `/`; source
filenames resolve relative to it. This is build-time configuration, not a bundled
file read at runtime. Fully stop and rerun after changing the value.

There is no Firebase URL map, token list, env-file preparation step, duplicate
download pack or automatic website asset checker. Tests read the local website
files and never download images. Existing `assets/reference/` files remain
historical material; the Allura font reference still serves offline font tests.

## Add or replace an image

1. Add the final still PNG, WebP or JPEG to `website/public/art/`. Keep its true
   extension. Current app limits are 2048 × 2048 and 10 MiB per image.
2. Add a real consumer and an entry in
   `redkeep/assets/catalog/presentation-v1.json`: stable purpose key, revision,
   installed `path`, website `sourcePath`, exact byte count, SHA-256, license and
   provenance. `sourcePath` is relative to the image directory, for example
   `notes.webp`. `path` identifies its persistent file on the device; retain it
   for unchanged images so upgrades reuse them.
3. Record provenance in `redkeep/tool/assets/PROVENANCE.md`. Changes to image
   bytes need a new revision, size and hash; use a versioned filename for new
   artwork so older app releases can still fetch their original file.
4. Run the relevant feature tests. The optional offline catalog check, from
   `redkeep/`, is:

   ```sh
   dart run tool/validate_assets.dart assets/catalog/presentation-v1.json ../website/public/art
   ```

5. Deploy the website and ship the updated app catalog/consumer. Confirm hosted
   bytes match the catalog. A website deployment alone does not change the
   catalog compiled into existing app releases.

Every catalog entry is required by startup; do not add unused future artwork.
The website can contain additional images absent from the mobile catalog.

## Current images

`presentation-website-v1` pins **12 images / 2,800,992 bytes**:

| Key | Website filename |
| --- | --- |
| `appearance.theme.system` | `theme_system.png` |
| `appearance.theme.light` | `theme_light.png` |
| `appearance.theme.dark` | `theme_dark.png` |
| `notes.add` | `notes_add.png` |
| `onboarding.cover` | `cover-redkeep-castle-v1.jpg` |
| `onboarding.chapter.notes` | `notes.webp` |
| `onboarding.chapter.diary` | `diary.webp` |
| `onboarding.chapter.maester` | `ai.webp` |
| `onboarding.chapter.flow` | `flow.jpg` |
| `onboarding.chapter.appearance` | `appearance.jpg` |
| `onboarding.material.paper` | `paper-edge.webp` |
| `onboarding.material.binding` | `binding-cloth.webp` |

The eleven unchanged images retain their existing installed paths/revisions.
The cover uses revision `v2` and a new JPEG path. The selected mascot and ink
paper remain bundled separately and are not required downloads. Old installed
cover files are harmless; do not clear app data to update artwork.

## Host and recovery

The sole asset define is `ASSET_BASE_URL`, compiled from `env.json`. There are
no per-image URL lists or HTTP fixture modes. Routine tests inject clients and
read `website/public/art/`; they do not need the ignored env file or a live host.

Missing/damaged files go through the existing download/repair gate. Verified
files survive retries and reopen offline. Repair does not access writing or
reset app storage. See [assets and startup](assets-startup.md) for store and
bootstrap contracts. Live-host byte checks do not establish native fresh-install,
physical accessibility, minimum-OS or low-end device qualification.
