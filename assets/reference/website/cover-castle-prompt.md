# Website castle cover — 3 November 2026

Tool: built-in `image_gen.imagegen`; no CLI/API fallback.
Edit target: the unchanged local `onboarding.cover` reference.
Selected generation: `exec-58437d30-6cda-449a-91be-03ff76af10ad.png`.
The preceding burgundy variant was rejected by the user; it is not imported.

## Final prompt

Use case: precise-object-edit.
Asset type: revised production journal cover for the existing website.
Input image 1 is the EDIT TARGET: the original lavender linen Journal cover. Preserve its exact muted lavender/lilac cloth palette, fine woven texture, delicate antique-gold double border and botanical corner ornaments, sage ribbon, soft flat lighting, portrait proportions, and quiet elegant style. Do not use burgundy, crimson, wine red, brown leather, a dramatic fantasy-poster look, or a new color scheme.
Change only the brand title and central small decorative motif:
Replace the large "Journal" title with exactly TWO CENTERED LINES:
The
Redkeep
The first line "The" is smaller, the second line "Redkeep" larger. Both use elegant embossed muted-plum lettering in the style of the original cover, with generous breathing room, occupying only roughly the upper 14–30% of the cover. Accurate spelling R-e-d-k-e-e-p. There must be exactly these two title lines.
Replace the little botanical ornament immediately beneath the old title with a SMALL refined castle/keep emblem in delicate antique gold, centered in roughly the 32–43% height region. A tasteful tiny medieval keep with crenellations, integrated with a little botanical ornament, not a huge castle illustration and not a specific franchise castle.
CRITICAL SPACE INVARIANTS: retain the original "A JOURNAL BY" text centered near 48% height, retain the original fine horizontal name-writing line near 75% height, retain the bottom "ONE OF A KIND. JUST LIKE YOU." text near 88% height. Leave the full region from 52% to 74% height CLEAR LAVENDER LINEN with no castle, ornaments, lettering, shadow or objects: the website needs this empty area for its own user/name text. Do NOT bake in "you" or any personal name. Keep that space empty and uncluttered just like the source. This name area is essential.
Composition: same flat straight-on edge-to-edge rectangular cover surface as the reference. No perspective, tabletop, spine, page stack, external shadows, surrounding scene or UI. The final image must read like a very close, carefully edited sibling of the supplied original, with only the two-line title and small castle motif changed.

## Export and integration

The exact PNG master is indexed under `website.cover.castle.master`, outside
bundles. The runtime/reference JPEGs are identical exports made with macOS
`sips -s format jpeg -s formatOptions 88`. No crop, recolor or compositing was
applied. The source image's existing portrait proportions are mapped by the
website's existing cover geometry, as before. Both the book and hero handoff use
this image; the old CSS wordmark patch is removed. The separate name overlay
and clear space for it remain. No screenshots or mobile assets changed.
