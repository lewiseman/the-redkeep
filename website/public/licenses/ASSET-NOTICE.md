# Redkeep website asset notice

This local W01 rebuild reuses only the specifically selected presentation files
from the user's Journal website, under the user's 3 November 2026 instruction
to copy the UI and rename Journal to Redkeep. No general artwork or source-code
license is inferred or granted by this notice.

- Book papers/textures use the exact existing `assets/reference/` originals.
  Generated-project provenance is recorded in the mobile project's
  `tool/assets/PROVENANCE.md` and the legacy onboarding `ARTWORK.md` and
  `CURRENT_ARTWORK.md`.
- Stationery/navigation icons, pin and sun/moon artwork have original image_gen
  provenance in the legacy `journal/assets/images/ARTWORK.md` and
  `navigation/ARTWORK.md`.
- The night sky (`night.jpg`), More icon and six screenshot JPEGs are retained
  project presentation assets authorized for this local preview. The legacy
  website README identifies their sources. Resolve outstanding public
  redistribution provenance before publishing; no stock/open license is inferred.
- `j.png` now contains the user-selected Grand Maester original from mobile
  branding, byte-for-byte matching the indexed `branding/grand_maestar.png`.
  The old J mascot remains only in the historical reference library. No
  generation, recoloring or recompression was performed for this replacement.
- The six screenshot files are unmodified, synthetic legacy Journal captures;
  they are not screenshots or promises of the current Redkeep implementation.
- Lora, Caveat and Nunito are distributed with their SIL Open Font License
  notices in this directory. No font provider is contacted at runtime.

The root reference manifest indexes exact SHA-256 copies and source paths.
Original reference raster files remain unchanged. The website cover now uses a
separate built-in imagegen edit of the original lavender cover, with a centered
“The” / “Redkeep” title and small gold castle. The prompt, exact master and
JPEG derivative are indexed in the local reference library. The CSS cover-title
patch was removed; live name text still uses the clear original writing area.
The site wordmark is live text and chapter labels remain HTML/CSS overlays. The favicon
uses a separate 48 × 48 PNG resized from the Grand Maester original (`j.png`) on every
page. The full-size original remains unchanged. Publication is outside W01.
