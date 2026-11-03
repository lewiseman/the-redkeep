# W01 website

The user explicitly reopened W01 on 3 November 2026, then selected copying the
legacy Journal UI and renaming it to Redkeep. The sibling `website/` is a local
React 19 / TypeScript / Vite 8 static website. The legacy `Journal/bookflip/`
checkout remains read-only. The user subsequently selected
`https://redkeep.lewiseman.com/` as the shared website/image host and publishes
it externally. Desktop rebuilds, mobile source migration and agent-run publication
remain separately scoped.

**Current asset source — 3 November 2026:** `website/public/art/` is the canonical
local reference for shared website/mobile images. No additional reference copy
is required. The build verifies every `public/` file against its `dist/` copy,
including images not displayed by the website or listed in Vite's chunk table.
The current reviewed whole-output budget is 7.5 MB after the four shared app
images were added; the output is 7,297,375 bytes. The previous reference-library
descriptions below record historical work. Existing archives remain intact.

## Current selected behavior

The night-sky hero, pinned paper note, Grand Maester mascot, floating stationery, sun-to-book
handoff, 3D page turns, chapter rail, phone coverflow, ruled feature index and
paper legal pages retain the legacy visual language. The new wordmark is live
Redkeep text. The current website cover is a generated lavender-linen edit with
“The” / “Redkeep” centered on two lines and a small gold castle emblem. It
retains the original gold border, sage ribbon and clear name area. The CSS
wordmark patch is removed; the editable name field and shared personalization are restored. Spread labels still
use HTML/CSS overlays, and the original source references remain unchanged.
The book describes the five implemented mobile chapters.
No People, sync, tasks, voice, semantic search, photo tools or companion support
is promised as a Redkeep capability.

All six legacy screenshot JPEGs are retained byte-for-byte at the user's explicit
request. The gallery identifies them as Journal visual references and explains
where a pictured capability is outside the current Redkeep scope. Do not replace
or regenerate them without a new user instruction.

The user's subsequent directions supersede the historical W01 prompt in two
places:

- No release section or download destination. The original-style Download
  buttons have no URL or handler and remain disabled. The small availability
  status below the header Download button was removed at the user’s request.
- No Simpler view control and no reduced-motion handling on the website. The
  original animated presentation remains active even when the OS requests
  reduced motion. This is a deliberate user-selected accessibility limitation,
  not a verified reduced-motion alternative. Mobile's rendering policy is unchanged.

Ordinary scroll, chapter links/rail, arrow keys, gallery buttons and horizontal
pointer swipes work without accounts. The added book Previous/Next buttons and
counter are removed. The carousel has its original stacked entrance, fan-out
and 4.8-second autoplay until interaction; feature cards use the original
animated demos. There is no browser journal, analytics or remote font request. The
cover name is the sole input and is stored only in this browser. SSR at build time renders real product content into HTML;
JavaScript progressively adds the decorative interaction. Product information
and the separate Privacy/Terms pages remain readable without JavaScript.

## Commands

Use Node 22.12+ or 24+ and run from `website/`:

```sh
npm ci
npm run typecheck
npm run lint
npm run build
npm test
npm run dev
```

`npm run preview -- --port 4173` serves the production `dist/` output.
The Playwright suite uses installed Google Chrome by default, in isolated test
profiles. Alternatively run `npx playwright install chromium`, then
`PLAYWRIGHT_CHANNEL=chromium npm test`. No user browser profile or journal data
is used. Tests block non-local HTTP requests; dependency installation and optional
browser installation are separate network operations.

`npm run build` checks TypeScript, builds all three HTML pages, prerenders the
React landing page and validates metadata, static content, local assets, the
7.5 MB reviewed output budget, exact copies from `public/`, the selected mascot,
original screenshot hashes and the absence of release/download links. It never
registers a Site or publishes. A build succeeds only after the final
`Build integrity ... passed` line, after Vite and prerendering have completed.

## Files and boundaries

- `src/site.ts`: current product copy and chapter order.
- `src/components/Hero.tsx`, `Book.tsx`, `BookPages.tsx`, `BookFaces.tsx`: selected
  legacy geometry/GSAP behavior with typed components and native scroll.
- `src/components/Screens.tsx`: unchanged screenshot sources, manual gallery.
- `src/components/Features.tsx`: readable feature descriptions outside the book.
- `src/components/Buttons.tsx`: deliberately unavailable Download control.
- `privacy.html`, `terms.html`: static, current-scope content, matching paper UI.
- `scripts/prerender.mjs`, `check-build.mjs`: static HTML and artifact checks.
- `tests/website.spec.ts`: meaningful production-browser behavior/axe checks.
- `public/licenses/`: OFL notices and the selected asset provenance notice.

Fonts and artwork are served locally. Exact canonical image references were read
before copying; the root reference manifest retains every prior row unchanged
and now indexes 34 exact references. Existing canonical chapter art is reused;
23 additional website/font/license/generated-cover rows were added. The exact
new cover master stays outside bundles, while the runtime uses an identical
indexed 477,330-byte JPEG export. The replaced cover/binding runtime files were
removed; canonical originals remain in the reference library. The reference
library, legacy app/runtime dependencies, Firebase tokens, native configurations
and raw artwork work area are not bundled. Unconsumed legacy libraries and
modules (Lenis, runtime release metadata and old feature demos) were not
imported. Cover-name behavior is restored with site-scoped React state rather
than the legacy module-level mutable store. Only real website dependencies were selected and locked.

## Verification and limitations

See [`evidence/w01/verification.json`](evidence/w01/verification.json) and the
adjacent captures. TypeScript, lint, production build and 17 Google Chrome
156.0.8078.80 browser checks passed on macOS arm64. Coverage includes keyboard
skip/navigation, chapter rail/keyboard navigation, gallery navigation, touch emulation at
390×844, 320×568 and 844×390, root text at 300%, three axe WCAG A/AA scans,
local-resource loading, metadata, no destination for downloads, static content with JavaScript disabled,
cover-name typing/caret keys, reload persistence, legacy-name preservation and
blocked-storage behavior. The browser was also inspected through the
in-app preview; browser emulation is not physical-device or screen-reader evidence.

The complete reviewed static output is about 6.96 MB; the measured first-page
encoded resource payload is about 6.64 MB including retained artwork and fonts.
Those assets dominate the weight. No low-end-device, slow-network, battery,
frame-rate, Safari/Firefox or physical touch/assistive-technology performance
claim is made. No universal WCAG conformance claim is made, particularly given
the user-directed removal of motion reduction. The 300% check establishes
wrapping/scrollable text and control access, not parity with every browser zoom mode.

`npm audit --omit=dev` reports zero findings. Full audit reports 11 moderate
findings in the development ESLint/minimatch dependency graph; these tools do
not ship in the static browser bundle. Do not apply its suggested ESLint 4
rollback. Revisit upstream compatible fixes before publishing/building untrusted
sources. This does not affect the passing requested checks.

## Release revalidation and publishing prerequisites

On 3 November 2026 the public GitHub releases API returned HTTP 200 with an
empty array for `lewiseman/the-redkeep`. The legacy repository lists the actual
`v0.1.3+5` Journal Android APK; it is a separate product and is not linked as a
Redkeep download. The desktop README describes an unsigned local preview; no
public Redkeep or Journal desktop artifact appears in those releases. No stores,
accounts or private release endpoints were inspected. Local debug/verification
builds in the mobile workspace are not public releases. No binaries were downloaded.

Before separately authorized publication: confirm final product copy and the
retained screenshot treatment; resolve the night-sky/mascot public redistribution
provenance recorded in the asset notice; review final publisher/contact/privacy
and terms against the chosen host; select the real hostname and add canonical,
absolute social-image/URL metadata; configure hosting/cache/security policy;
qualify target browsers/devices; review development dependency advisories. Keep
Download disabled until the user selects real verified Redkeep distribution URLs.
Registration, source synchronization, remote Git, deployment and analytics were
not performed. W01 ends here. No next phase is automatically authorized; M12 or
another mobile/UI phase still requires explicit selection, and D01–D03 stay parked.

## W01 cover correction

On 3 November 2026 the user selected a real castle-themed image with the title
“The” / “Redkeep” on two centered lines, replacing the CSS title patch. After
the first generated concept changed the palette and filled the writing area,
the user required the previous color/style and clear space for the name. Only
the corrected lavender version is imported.

Built-in image generation edited the existing canonical cover reference.
`assets/reference/website/cover-castle-prompt.md` records the exact final prompt,
generation and JPEG export. The master is
`assets/reference/website/generated/cover-redkeep-castle-v1.png`; the runtime is
`website/public/art/cover-redkeep-castle-v1.jpg`. Both are indexed by SHA-256.
The shared `CoverArt` renders the new image in the book and the hero handoff.
The original “A JOURNAL BY”, line and bottom inscription remain in the image;
“you” remains live text with clear space around it. Old mobile/onboarding art,
all six screenshots, download behavior and the chosen motion behavior remain
unchanged.

TypeScript, lint, production build, the 12 existing browser/accessibility checks
and all 34 reference hashes pass after this correction. Cover captures are
`evidence/w01/castle-cover-desktop.png` and `castle-cover-mobile.png`; detailed
follow-up evidence is `evidence/w01/cover-verification.json`. No new dependency,
publication or device qualification was introduced.

## Editable cover name

On 3 November 2026 the user requested restoration of the original name-entry
behavior. The name line is again an accessible text input with the original
“write your name” placeholder, 24-character limit and live updates. The inside
cover, hero handoff and final book page share that name. Arrow keys in the input
move its caret; page navigation handles arrows outside the field. The generated
lavender castle cover and its reserved writing space are unchanged.

`src/cover-name.tsx` owns state in a provider for each rendered site, without
mutable global visitor state. Static HTML starts with an empty name; storage is
read only after browser hydration. Updates use `redkeep-cover-name` in local
storage. If it is absent, the original `journal-owner` value on the same origin
is read without deleting it. A deliberately saved empty name takes precedence
over that legacy value, so clearing the field does not resurrect an old name.
Browser storage is origin-specific: different domains/ports do not share names.

If reads or writes are blocked, input and shared in-memory personalization still
work for that visit; persistence is unavailable after reload. No name is sent
over the network. The privacy page describes this storage honestly. The build
check permits exactly this one decorative input while excluding journal fields.

The final 15 browser checks include direct name edits, the original limit, caret
arrows, personalization on all consumers, reload, legacy-key recovery, deliberate
clearing and blocked storage. Existing 390px touch checks now type on the cover.
Evidence uses synthetic names in isolated test profiles; the real user's browser
name was not overwritten. See `evidence/w01/name-verification.json` and
`editable-name.png`. A direct in-app automation attachment was unavailable for
this follow-up; production Chrome checks and captured screenshots passed. The
existing user-owned dev server at port 5173 remained running; no publication or
physical-device/IME qualification is claimed.

## Website mascot and Download cleanup

On 3 November 2026 the user selected the exact mobile branding original
`redkeep/assets/branding/grand_maestar.png` to replace `website/public/art/j.png`.
The source and its already indexed canonical reference match byte-for-byte; the
website file is an unchanged 1,842,097-byte copy, including transparency. The
hero image’s intrinsic dimensions are now the correct 1254×1254. Every existing
`j.png` consumer (hero, book faces, feature icon, footer and social metadata)
therefore uses Grand Maester. The source mobile file and all reference rows stay
unchanged; the small old J remains only as an archived website reference.

The small “Not available yet” status under header Download is removed, along
with its wrapper, description IDs and unused compact prop/styles. The native
disabled button and no-download destination remain. The separate final-page
availability sentence is unchanged.

The selected original PNG adds 1,777,859 bytes relative to the old 64,238-byte
J. The reviewed total static budget is deliberately revised from 6.5 MB to
7 MB for this exact user-selected asset, without recompression or changes to
other artwork. The build also verifies the website mascot against its canonical
original. Current evidence is `evidence/w01/mascot-verification.json`; previous
cover/name evidence remains historical. No new dependency or publication is
introduced, and the user-owned dev preview at port 5173 remains running.

The hero mascot no longer translates or rotates in response to mouse movement
(user correction, 3 November 2026). Its existing intro, tap and scroll animations
remain. TypeScript, lint and production build pass for this six-line removal.

## Restore original section animations

The user requested the original presentation on 3 November 2026: removed the
added book Previous/Next controls and numeric counter, restored the screenshot
carousel animation, and restored the animated feature-card demos. Scroll,
contents, desktop chapter rail and keyboard navigation remain available. The
mascot's mouse-follow behavior stays removed as previously selected.

Selected animation code/CSS was copied from the legacy Screens/Features and
`useReveal` implementations, with TypeScript and cleanup retained. The carousel
starts stacked, fans out at the original 0.35 intersection threshold and rotates
every 4800ms until hover/focus or navigation/swipe interaction stops it. Mobile
selector layout also follows the original. The feature cards again have hover
prints, scan beam/typed text, typing prompts/caret, drifting paper thoughts,
waveform bars and working theme/accent preview, plus the original 0.9-second
staggered scroll reveal. Descriptions remain accurate to current Redkeep; no
photo scanning, voice or semantic-search implementation is claimed. The existing
Notes artwork replaces the unselected People print in the decorative stack.
No additional asset or dependency was imported.

All 17 browser/accessibility checks pass, including autoplay/interaction stop,
restored CSS animations/theme controls, touch/manual navigation and the absence
of the removed book controls. TypeScript, lint and the 7 MB artifact check pass.
Static content remains visible without JavaScript; scroll reveals are applied
after hydration. See `evidence/w01/animation-verification.json` and
`restored-gallery.png` / `restored-feature-animations.png`. Native/device and
publication qualifications remain unchanged. Stop at this W01 follow-up.
