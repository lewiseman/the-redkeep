# Selected presentation media provenance

`LicenseRef-Project-Generated` identifies original image_gen outputs created for
the user's own legacy Journal project, reused under the user's M04 migration
authorization. It is a project provenance notice, not a third-party open-source
license grant. These outputs carry no third-party license in the source project.
No external stock images, marks, screenshots, or former branding are included.
Retain this notice with the published pack and the application source.

The three unmodified files are copied individually from
`/Users/lewis/Dev/Projects/Journal/journal/assets/images/theme_{system,light,dark}.png`
to `pack/appearance/theme-{system,light,dark}-v1.png`. The bundled catalog pins
their exact sizes and SHA-256 digests. They are 384 × 384 transparent PNGs.
Only catalog JSON is in the application bundle; this pack is a controlled local
fixture and source for eventual separately authorized hosting.

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
