# Selected presentation media provenance

`LicenseRef-Project-Generated` identifies original image_gen outputs created for
the user's own legacy Journal project, reused under the user's M04 migration
authorization. It is a project provenance notice, not a third-party open-source
license grant. These outputs carry no third-party license in the source project.
No external stock images are included. The later UI01 correction deliberately
retains the original printed artwork and mascot, as recorded below.
Retain this notice with the published pack and the application source.

The three unmodified files are copied individually from
`/Users/lewis/Dev/Projects/Journal/journal/assets/images/theme_{system,light,dark}.png`
to `pack/appearance/theme-{system,light,dark}-v1.png`. The bundled catalog pins
their exact sizes and SHA-256 digests. They are 384 × 384 transparent PNGs.
This pack is a controlled local fixture and source for eventual separately
authorized hosting; none of its payloads are bundled. The later UI01 fixed
mascot/font exception is recorded separately below.

The following source provenance and generation prompts were preserved verbatim
from that project's `assets/images/ARTWORK.md` (read-only reference).

## Appearance theme selectors

`theme_light.png`, `theme_dark.png`, and `theme_system.png` are original transparent illustrations generated with the built-in `image_gen` tool on 26 October 2026. No CLI/API fallback was used. All three use `navigation/notes_active.png` as a material and style reference to match the app's gouache and tactile cut-paper artwork.

The sun indicates light mode, the indigo crescent and ivory star indicate dark mode, and the combined daytime/nighttime emblem indicates system mode. Each production asset is a 384 × 384 RGBA PNG, downsampled with macOS `sips` while preserving alpha. `AppearancePage` displays them in its existing 89-pixel-high theme preview slots without tinting; the card labels and selection check remain separate widgets. The existing `assets/images/` bundle entry includes all three images.

### Source masters

The generated originals remain under `/Users/lewis/.codex/generated_images/01a17771-2ba1-75f2-9fdf-aef5721f8276/`:

- `theme_light.png`: `exec-2f8eb177-9f3a-4517-865f-f482d316f80c.png`
- `theme_dark.png`: `exec-60374748-e0fa-4ed1-8fc3-f1a6fe0cb8b6.png`
- `theme_system.png`: `exec-83529766-eb1c-4837-9a87-a12ca1870538.png`

### Exact generation prompt set

#### theme_light.png

```text
Use case: stylized-concept.
Asset type: ONE production UI illustration replacing an icon placeholder in a personal journaling Flutter app's Appearance theme selector, rendered at about 80 by 80 logical pixels.
Input image role: the attached existing Notes illustration is a STYLE AND MATERIAL reference only. Create the celestial subject below; do not reproduce the stationery objects.
Style/medium: match the reference's refined hand-painted gouache on tactile cut paper, softly sculptural 2.5D paper collage, rounded handmade edges, delicate natural paper fiber texture, gentle layered depth, soft upper-left illumination. Warm, calm premium journal aesthetic.
Composition/framing: square canvas, one isolated centered compact celestial emblem filling 80 percent of the canvas, consistent 10 percent transparent padding on each side, entire silhouette uncropped, near-frontal view. Few broad clear shapes readable at small size. Soft contained edge shading only.
Palette: restrained warm ivory #f4ead4, honey gold #cfaa62, muted indigo #65618c, lilac #b4abd3. Medium-value silhouettes and ivory highlights so the illustration reads on both off-white #faf8fc and near-black #17151d. Full-color opaque paper shapes.
Constraints: genuinely transparent RGBA background in all negative space. No text, letters, numbers, labels, watermark, surrounding scene, notebook, pencil, UI screenshot, button tile, enclosing badge, checkerboard, glossy plastic, photorealism, thick black outlines, facial features, broad cast shadow, or additional props. One image only, not a sprite sheet.
Primary request: LIGHT MODE. One beautiful warm honey-gold SUN made of layered textured cut paper. A round golden central disc with a subtle lighter ivory-gold inset highlight, surrounded by eight short broad tapered golden rays evenly arranged in a radial silhouette. Delicate ochre paper edge shading gives quiet tactile depth. Plain sun with no face. Sun rays must be clearly distinct and robust at 80px. Overall silhouette roughly circular, no extra celestial objects.
```

#### theme_dark.png

```text
Use case: stylized-concept.
Asset type: ONE production UI illustration replacing an icon placeholder in a personal journaling Flutter app's Appearance theme selector, rendered at about 80 by 80 logical pixels.
Input image role: the attached existing Notes illustration is a STYLE AND MATERIAL reference only. Create the celestial subject below; do not reproduce the stationery objects.
Style/medium: match the reference's refined hand-painted gouache on tactile cut paper, softly sculptural 2.5D paper collage, rounded handmade edges, delicate natural paper fiber texture, gentle layered depth, soft upper-left illumination. Warm, calm premium journal aesthetic.
Composition/framing: square canvas, one isolated centered compact celestial emblem filling 80 percent of the canvas, consistent 10 percent transparent padding on each side, entire silhouette uncropped, near-frontal view. Few broad clear shapes readable at small size. Soft contained edge shading only.
Palette: restrained warm ivory #f4ead4, honey gold #cfaa62, muted indigo #65618c, lilac #b4abd3. Medium-value silhouettes and ivory highlights so the illustration reads on both off-white #faf8fc and near-black #17151d. Full-color opaque paper shapes.
Constraints: genuinely transparent RGBA background in all negative space. No text, letters, numbers, labels, watermark, surrounding scene, notebook, pencil, UI screenshot, button tile, enclosing badge, checkerboard, glossy plastic, photorealism, thick black outlines, facial features, broad cast shadow, or additional props. One image only, not a sprite sheet.
Primary request: DARK MODE. One beautiful broad INDIGO CRESCENT MOON made of layered textured cut paper, gently curved thick crescent opening toward the upper right. Main moon paper muted indigo #65618c with lilac and warm-ivory edge highlights and subtle curved layered edge shading for depth. Include exactly ONE small warm-ivory four-point star nestled close inside the crescent's opening, so the overall compact footprint is roughly circular and centered. Moon has no face. Bold simple crescent silhouette, no scattered tiny stars or extra objects.
```

#### theme_system.png

```text
Use case: stylized-concept.
Asset type: ONE production UI illustration replacing an icon placeholder in a personal journaling Flutter app's Appearance theme selector, rendered at about 80 by 80 logical pixels.
Input image role: the attached existing Notes illustration is a STYLE AND MATERIAL reference only. Create the celestial subject below; do not reproduce the stationery objects.
Style/medium: match the reference's refined hand-painted gouache on tactile cut paper, softly sculptural 2.5D paper collage, rounded handmade edges, delicate natural paper fiber texture, gentle layered depth, soft upper-left illumination. Warm, calm premium journal aesthetic.
Composition/framing: square canvas, one isolated centered compact celestial emblem filling 80 percent of the canvas, consistent 10 percent transparent padding on each side, entire silhouette uncropped, near-frontal view. Few broad clear shapes readable at small size. Soft contained edge shading only.
Palette: restrained warm ivory #f4ead4, honey gold #cfaa62, muted indigo #65618c, lilac #b4abd3. Medium-value silhouettes and ivory highlights so the illustration reads on both off-white #faf8fc and near-black #17151d. Full-color opaque paper shapes.
Constraints: genuinely transparent RGBA background in all negative space. No text, letters, numbers, labels, watermark, surrounding scene, notebook, pencil, UI screenshot, button tile, enclosing badge, checkerboard, glossy plastic, photorealism, thick black outlines, facial features, broad cast shadow, or additional props. One image only, not a sprite sheet.
Primary request: SYSTEM MODE, automatic light and dark appearance. ONE cohesive circular DAY-AND-NIGHT cut-paper emblem, vertically divided into a honey-gold daytime left half and a muted-indigo nighttime right half. The left half has four short broad honey-gold sun rays extending from its outer curved edge, and a restrained warm-ivory curved highlight. The right half contains one broad warm-ivory crescent moon cut-paper inlay and exactly one simple little ivory four-point star. The straight central seam joins the two halves into a single tactile disc, no gap. A simple clean equal split sun-and-moon composition, readable immediately at 80px. No arrows, monitor, device, gears, facial features, or extra elements.
```

## M07 selected Notes artwork

The user’s M07 scope authorizes this single unmodified `notes_add.png` copy to
`pack/notes/add-v1.png`, key `notes.add`. It serves the live Create note control
through the existing resolver, at 40 logical pixels with a 120-pixel decode bound.
Its original source provenance follows. No navigation/onboarding artwork or raw
work-in-progress media is included.

## Notes add control

`notes_add.png` is an original 192 × 192 transparent RGBA PNG generated with the built-in `image_gen` tool on 26 October 2026, using `navigation/notes_active.png` as a style reference. No CLI/API fallback was used. The production image was downsampled with macOS `sips`, preserving alpha; the generated master remains at `/Users/lewis/.codex/generated_images/01a17521-1f18-7500-9d77-6a612c7a1ec0/exec-597e27ab-e029-4101-a3a7-f96f4893ec6a.png`.

The cream folded paper, indigo pencil and inked plus form the floating Add note control. The same full-color cutout renders at 64 × 64 logical pixels in a 72 × 72 tap target, 24 pixels from the bottom and 16 from the right of the Notes page. Pressing scales the illustration to 94% over 70 ms; release restores it over 140 ms. Reduced-motion and accessible-navigation preferences remove the animation. There is no permanent background tile; keyboard focus uses a transient accent highlight. Tooltip and button semantics retain the label `Add note`.

### Exact generation prompt

```text
Use case: style-transfer. Asset type: one production transparent-background illustration for the floating ADD NOTE control in a personal journaling Flutter app, displayed at 64 by 64 pixels. Input image role: reference for the hand-painted stationery style, materials, lighting and palette ONLY; create a new composition distinct from this existing Notes navigation icon. Primary request: ONE fresh blank cream paper sheet with a softly folded upper-right corner, a short muted-indigo wooden pencil resting diagonally along its lower-right edge, and ONE clearly readable small indigo inked plus sign on the paper to mean create a new note. The paper is warm ivory #f4ead4; the folded corner may have a restrained sage underside #8c9b81; the pencil is muted indigo #65618c with warm wood and a tiny honey-gold ferrule #cfaa62. Keep the paper mostly blank except for the single plus, no writing lines, words or letters. Match the reference's refined hand-painted gouache on tactile cut paper, softly sculptural 2.5D handmade stationery look, delicate natural fiber texture, softly rounded irregular paper edges, and soft upper-left illumination. Near-frontal three-quarter view from slightly above; compact roughly square silhouette, gentle tilt, simple readable large shapes. The paper is the dominant shape, with medium-value lilac/indigo edge shading and ivory highlights so the same full-color cutout reads on both off-white #faf8fc and near-black #17151d. Restrained contained contact shadow under the paper and pencil only. Square canvas, object centered and filling about 85 percent, consistent modest transparent padding, nothing clipped. Genuine transparent RGBA background, including all negative space. No surrounding scene, no colored button surface, no enclosing circle or tile or badge, no background, no baked checkerboard, no watermark, no text except the plus symbol, no notebook/book binding, no stack of sage notes, no flowers or extra decorative objects, no photorealism or glossy plastic. Produce one illustration, not a sprite sheet.
```

## UI01 supplied onboarding originals — 3 November 2026

`LicenseRef-Project-Supplied` records the user's explicit UI01 authorization to
reuse the supplied local onboarding originals. This is a project-use provenance
record, not a claim that these files are newly generated, public domain, or
licensed by Firebase. The input is the user's completed Firebase handoff,
mirrored byte-for-byte in `assets/reference/` at the repository root. That
manifest records bucket/object identity, media type, bytes and SHA-256; secret
source URLs remain in ignored configuration. No source image was edited,
recompressed, regenerated, or copied from the user's raw work directory.

Only these eight originals join `presentation-ui01-v1`, unchanged:

| Key suffix below `onboarding.` | Pack path | Original dimensions | Presentation use |
| --- | --- | --- | --- |
| `chapter.notes` | `onboarding/notes.webp` | 1448×1086 | Bulb, paper and foliage crop |
| `chapter.diary` | `onboarding/diary.webp` | 1448×1086 | Window and coffee crop |
| `chapter.maester` | `onboarding/ai.webp` | 1448×1086 | Pen and lavender crop |
| `chapter.flow` | `onboarding/flow.jpg` | 1448×1086 | Pencil and flowers crop |
| `chapter.appearance` | `onboarding/appearance.jpg` | 1448×1086 | Neutral paper swatches crop |
| `background.ink` | `onboarding/ink-paper.webp` | 1024×1536 | Ivory ink background |
| `material.paper` | `onboarding/paper-edge.webp` | 1024×341 | Page block edge |
| `material.binding` | `onboarding/binding-cloth.webp` | 192×576 | Binding and neutral cloth cover |

Source images contain old printed copy; explicit per-image source rectangles
in `onboarding_chapter.dart` keep it outside the visible viewport. All current
functional copy is live Flutter text. The supplied `cover.webp` says Journal
and has no runtime consumer, so it remains reference-only. The four existing
PNG entries, their payloads, provenance, keys, revisions and hashes are retained.

The reference handoff does not establish a third-party redistribution license.
The M12 publication audit must confirm distribution rights with the project
owner before public release. No publication or live-host verification is part
of UI01.


## UI01 visual-parity and name correction — 3 November 2026

The user explicitly requested the legacy visuals as-is and persisted name entry,
superseding the earlier crop-only/reference-only-cover policy. The previously
supplied `cover.webp` is now consumed by the folding editable cover, so
`presentation-ui01-v2` adds key `onboarding.cover`, revision `v1`, path
`onboarding/cover.webp`. It is an exact copy from the canonical reference manifest:
1122×1402 WebP, 335,014 bytes,
SHA-256 `4208bb6602284ad78d3378595b2ecacbcf3b2f387ac5d41a8974de4e46a09698`.
Its existing supplied URL is prepared in ignored configuration. No new image or
remote source was invented, fetched, regenerated or edited. Full original
printed artwork is retained under the user's visual instruction; the app's
current functional/accessible descriptions remain separate.

Selected book-paper/fold geometry and composition were adapted from the user's
legacy Flutter renderer under that same specific authorization. Its global
services, storage, timers, unrelated features and package manifests were not
imported. This iteration did not yet restore the original mascot/font; that
omission is superseded by the exact-layout correction below.
The four existing PNG entries remain untouched. This supersedes the preceding
UI01 paragraph that excluded the original cover; earlier records describe the
initial implementation. Public distribution-rights and native-device evidence
remain separately unverified.

## UI01 exact layout, mascot and script caption — 3 November 2026

The later resource choice below supersedes this iteration's old mascot and
bundled font. This record describes the intermediate visual-parity version.

The user explicitly requested the same visual screen, including its omitted
bottom Terms/Privacy links, and rejected the added Previous/Next controls.
The original composition, primary-button colors, dots, hint, mascot and caption
are now restored. This authorizes only the following narrow fixed resources,
not a bulk asset or font import:

- `assets/branding/onboarding-mascot.png`: exact legacy
  `journal/assets/images/j.png`, 638×617 PNG, 64,238 bytes, SHA-256
  `acca16b0754653de5140fc4bb16eaeace75a8b62900c007fec9a0f0df02e0f1a`.
  Reused under the user's instruction to copy this onboarding screen.
- `assets/fonts/Allura-Regular.ttf`: the legacy caption's Allura Regular,
  109,228 bytes, SHA-256
  `7e712992f9e6ecb3eab1eb7e0b0dc5903ea40467147f930e8e3728832e42080b`.
  The legacy installed Google Fonts mapping identifies this exact font digest;
  it was acquired once from the pinned `fonts.gstatic.com` URL in the manifest.
  Its unmodified OFL notice is retained as `assets/fonts/Allura-OFL.txt`, copied
  from [Google Fonts' official Allura source](https://github.com/google/fonts/blob/main/ofl/allura/OFL.txt).
  Flutter's license registry includes this notice. No `google_fonts` runtime
  dependency or network font loader is added.

Both have byte-for-byte copies under the top-level `assets/reference/`, indexed
in two additional `bundled-branding` manifest rows with their source identities.
The original nine rows and bytes stay unchanged. The reference directory itself
is not bundled. The small fixed app copies are outside `presentation-ui01-v2`;
that pack stays at 13 images / 3,000,554 bytes with the same 13 supplied URLs.
No Firebase reference was refreshed or new Firebase source invented.

## UI01 user-selected Grand Maester and Google Fonts — 3 November 2026

The user supplied `redkeep/assets/branding/grand_maestar.png` and explicitly
selected it as the onboarding mascot. The exact 1,842,097-byte PNG is used
without editing/recompression; the existing display height is retained and its
decode height is bounded by device pixel ratio. A byte-for-byte reference copy
at `assets/reference/branding/grand_maestar.png` is indexed by the existing
`onboarding.brand.mascot` key with its current SHA-256 and local source identity.
The unused original J mascot app/reference copies are removed.

The user also selected the old app's Google Fonts approach instead of asset
fonts. Pinned `google_fonts` 9.0.0 uses `GoogleFontsLite.getFont('Allura')` for
both caption layouts, matching the old app's API and typography. The former
bundled TTF and `flutter.fonts` declaration are removed. Only the OFL notice
remains at `assets/licenses/Allura-OFL.txt` and in Flutter's license registry.
The package owns runtime fetching/caching; no font fetch joins bootstrap or
required-artwork verification. The local reference TTF remains outside bundles,
tagged `test-reference`, to preload the exact font in offline test isolates.

Verified the [official package usage/SDK requirements](https://pub.dev/packages/google_fonts/versions/9.0.0)
and installed source against Flutter 3.47.5 / Dart 3.13.4 before adding the
dependency. Only `google_fonts` was added; all other resolved versions remain
unchanged. The 13-image pack, source URLs and nine Firebase reference rows stay
unchanged. No image regeneration or Firebase request was performed.


## UI01 bundled startup branding — 3 November 2026

The user explicitly selected `assets/branding/grand_maestar.png` and
`assets/branding/ink-paper.webp` as permanent bundled app resources. Startup now
uses the paper background, centered Grand Maester logo and determinate progress
bar. Normal and constrained onboarding use the same bundled paper; the mascot
continues to use its existing bundled copy. Neither image is downloaded.

The exact ink-paper WebP is 1024×1536, 341,878 bytes, SHA-256
`461bd93693da157da5f80651ee1a15c2537fd6c1d7bf6a5b2f28da4e947b2e57`.
The Grand Maester PNG remains 1,842,097 bytes, SHA-256
`5e698de4f5ab0413e36094c45ee16a67e11bcbc7408a9a7fb558c391a9be10e5`.
Both are identical to the existing indexed references; all nine original remote
reference rows and bytes are unchanged. No remote refresh or image edit occurred.

`presentation-ui01-v3` removes `onboarding.background.ink` and its redundant
deployment payload, leaving 12 downloads / 2,658,676 bytes. Every remaining
key/revision/path/hash/byte size is unchanged. Existing compiled source maps may
retain the retired key; runtime ignores it, and preparation omits it while
preserving all consumed source values and unrelated configuration. This section
supersedes earlier 13-image delivery statements, without changing the preceding
Google Fonts choice, supplied-source identity or distribution-rights limits.


## Shared website image host — 3 November 2026

The user selected `website/public/art/` as the canonical local image source and
`https://redkeep.lewiseman.com/art/` as the default download directory. Current
catalog `presentation-website-v1` keeps the eleven unchanged images with their
prior hashes and installed paths. `sourcePath` names the corresponding website
file. No duplicate pack/reference files are created; earlier records above are
historical and their provenance remains retained.

`onboarding.cover`, revision `v2`, uses the selected website export
`cover-redkeep-castle-v1.jpg`, 477,330 bytes, SHA-256
`b4c92633c2bc035b51bc57c90eaa9f455afe673c0f55ff17659cf4432928d5e8`.
It is a 1122×1402 project-generated Redkeep castle cover. The exact PNG master
and JPEG export remain indexed in `assets/reference/manifest.json`.
Its project-generated provenance does not assert a new third-party license. Public redistribution qualification
remains separate. Website image bytes and bundled startup branding are unchanged.

## Legacy bottom navigation migration — 3 November 2026

The four active navigation images reuse the existing `diary.png`, `notes.png`,
`flow.png`, and `more.png` in `website/public/art/`; their bytes match the legacy
active images exactly. Only the four inactive 192 × 192 PNGs were copied into
`website/public/art/navigation/` from the previous app's
`assets/images/navigation/`. Its original generation record is retained in
`website/public/art/navigation/ARTWORK.md`.
They are pinned in the existing presentation catalog and resolved through the
same verified download/cache path as the app's other artwork. No new artwork
or fonts are bundled. Both navigation states stay mounted for the original
crossfade; full-color artwork stays untinted while labels and the edge glow
follow the app accent. Reduced motion stops animations, and simpler effects
removes the gradient and glow.

Font selections use the existing Google Fonts package's download/cache path,
with the legacy 10-second request timeout and load-before-save behavior.
