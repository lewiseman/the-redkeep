# UI01 — Legacy onboarding and name entry

**Current engineering instruction — 3 November 2026:** Redkeep is a new app. Do
not copy or port further legacy code. The renderer/layout adaptation described
below is existing earlier UI01 work, not permission for additional imports. The
asset/config cleanup does not rewrite or disguise that existing provenance.

**User correction — 3 November 2026:** restore the previous app's visual design
and take/persist the user's name. This supersedes the first UI01 implementation's
cropped illustration cards, neutral replacement cover, completion-marker-only
gate and prohibition on a schema change. The user confirmed **onboarding and
name only**; other product features remain separately scoped.

The subsequent visual correction also requires the original bottom Terms and
Privacy policy links, mascot, script caption, spacing and colors. Added visible
Previous/Next, chapter counter and Back controls are removed. The earlier prompt
requirements for those controls and metadata-only/system-font presentation are
superseded by this explicit request to copy the legacy screen.

**Latest resource choice:** use `google_fonts` as in the old app, with no font
binary bundled, and use the user's `assets/branding/grand_maestar.png` as the
onboarding mascot. This supersedes the previous fixed-font/legacy-mascot choice.

## Restored presentation

The book now retains the selected legacy `book_paper.dart` and `book_fold.dart`
geometry: curved facing leaves, page blocks, sewn cloth binding, fixed case,
64-band page bends, cover hinge, shadows, and final centering. The five supplied
spreads are displayed whole at the original 4:3 geometry rather than cropped
into cards. The ink-paper background uses bundled
`assets/branding/ink-paper.webp` in
both normal and constrained layouts. The lavender Redkeep castle cover, paper
edge and binding textures use the existing verified-file resolver. The lavender pill
action and name field on the cover restore the original composition.
`onboarding_content.dart` retains the original view layout directly, including
the user-selected Grand Maester mascot and Allura caption. The button uses the original
`0xFF161658` ink and lavender gradient, with its original disabled appearance.

The supplied spreads retain their printed Journal/AI wording
and Appearance artwork, as requested for visual parity; the cover now matches the
website's selected Redkeep artwork. Other source pixels are not
edited or regenerated. Current accessible descriptions identify Grand Maester as
optional on-device help with separately downloaded models and describe the
implemented appearance controls. This visual restoration does not implement
font selection, People, Sync, cloud accounts, voice/vision or other deferred
features. No new claim about those services is added in live functional copy.

The chapter order remains Notes → Diary → Grand Maester → Flow → Appearance.
The original dots and “Tap a page or swipe to turn.” hint remain. Page taps and
finger-following swipes work manually; a canceled drag returns to the current
chapter. Keyboard arrows and semantic increase/decrease actions provide access
without swiping, with chapter position announced through semantics. There is no
visible Previous/Next button, numeric counter or Back button, and no autoplay.
**Let's begin** folds the actual cover and reveals **Your name**. **Save** stays
disabled for blank/whitespace input. System back dismisses input focus first,
then reopens the book while retaining the typed name; Escape also reopens it.
Back from the tour can exit. Failures keep the cover, name, safe error and
**Save** for retry; all competing actions disable while saving.

The original inline Terms and Privacy policy footer sits below the primary
action inside the bottom safe area and hides while the keyboard is open.
It opens `https://journal.lewiseman.com/terms.html` and
`https://journal.lewiseman.com/privacy.html` through an injected external launcher.
False/failed launches show “Could not open this page. Please try again.”; a late
result after disposal is ignored. Tests inject this boundary and open no browser.

Normal phone/tablet layouts preserve the open-book presentation. A tall-text or
very constrained/keyboard viewport adds a scrollable live reading layout and
an unconstrained name field, rather than trapping text in a small cover region.
Both app themes use readable ink against the original ivory artwork. Functional
text/focus/semantics remain available without swiping.

## Name and routing contract

Schema **8** adds a nullable `name` to the existing singleton
`onboarding_completion` row. There is no account or separate profile store.
`OnboardingRepository.readName()` returns a normalized nonblank name;
`isComplete()` derives from it. `complete(name)` validates and commits the name
in one row write before its future completes. The controller/router unlock only
after this committed save.

**A user without a saved name now opens onboarding**, including an installation
with the earlier completion-only row. Migration keeps that row and adds a null
name; it does not invent a name, clear settings, or delete writing. Versions 1–7
upgrade to 8 with all other tables retained. A committed name survives ordinary
relaunch and bypasses onboarding. Leaving before save leaves onboarding
incomplete. The database version/snapshots and generated helpers are retained.

Local startup/asset checks still run first. All required artwork must verify
before onboarding or normal entry. Validated continuations remain in the router
URI across startup, repair, failed name save and successful entry. Presentation
widgets do not select routes or initialize models. See
[onboarding and navigation](onboarding-routing.md).

## Optimizations and policy

The selected legacy renderer is adapted directly rather than importing its old
services, storage, timers or dependency manifest. Both leaves share one bounded
file-image provider. At rest only the visible chapter resolves; a turn can retain
the immediate destination. Only the chosen cover is warmed when beginning the
close. Its decode width stays stable through closing and keyboard changes,
avoiding a second blank decode after the fold. There is no all-chapter precache.

The two small texture streams own/dispose their image handles and report cached
or asynchronous decoder failures through the existing repair gate. Page-band
painting retains the legacy single-recorded-face approach. The cover retains
the original settling camera transform for visual parity. Provider
caches evict on departure and same-path repair. No physical performance claim
follows from these changes.

`RenderingPolicy` controls animation. Reduced motion, simpler effects,
inactivity and offscreen routes settle to the chosen page/cover. Simpler effects
use a flat static spread/cover without page bends, perspective, layered shadows
or animated lighting. Controllers, focus, scroll resources and streams dispose
with the page.

## Artwork and build configuration

`presentation-website-v1` contains **12 images / 2,800,992 bytes** from the shared
website image directory. `website/public/art/` is the canonical local source for
current image inspection/tests. The app now uses the website's Redkeep castle
cover (`cover-redkeep-castle-v1.jpg`), revision `v2`, instead of the old Journal
cover. Its dimensions and reserved name area fit the existing folding renderer.
The other eleven images retain their bytes and installed identities.

The user-provided `assets/branding/grand_maestar.png` and `ink-paper.webp` remain
bundled, unchanged, for startup and both onboarding layouts. They match the
website's `j.png` and `ink-paper.webp`; neither needs a download URL.

Both layouts retain `GoogleFontsLite.getFont('Allura', fontSize: 30,
fontWeight: FontWeight.w600)` from pinned `google_fonts` 9.0.0. No TTF or
`flutter.fonts` entry is bundled. Font loading remains independent of startup,
name entry and Save, and the OFL notice remains registered. The existing archived
Allura reference preloads the font in offline tests.

From `redkeep/`, run `flutter run --dart-define-from-file=env.json`. The env file
contains only `ASSET_BASE_URL`; a tracked one-key example is provided. There is
no Firebase source map or preparation step. A full stop/rerun compiles changed
configuration. See [asset setup](onboarding-assets-setup.md),
[startup](assets-startup.md) and [provenance](../redkeep/tool/assets/PROVENANCE.md).

## Verification and stopping point

Run the README formatting/analyzer/full offline suite and optional local
website-source validator.
Tests cover real local artwork, original spread aspect/geometry, manual navigation,
cover folds, required/trimmed Unicode names, failed/duplicate saves, commit timing,
interruption/relaunch, missing-name migration, version 1–7 data preservation,
continuations/repair, both themes, 320px/3× text, landscape/keyboard/safe areas,
reduced/simpler/live/lifecycle/offscreen modes, texture/cover decoder errors and
disposal. Footer regression tests check its placement, original hint/mascot,
absence of invented controls, script caption, keyboard hiding, exact link
destinations, safe failures and disposal. Current visual review artifacts are
under [`docs/evidence/ui01/resources/`](evidence/ui01/resources/).
The preceding [`parity/`](evidence/ui01/parity/) captures and zero-pixel comparison
describe the earlier legacy-mascot/bundled-font variant, before the user's new
resource choice. They remain historical evidence of the restored composition,
not a current mascot screenshot or a device claim.

Current website-host byte checks and packaging results are recorded in the
selected asset-simplification migration record. Native fresh-install downloads,
physical-device qualification and public redistribution rights remain release
inputs. Historical UI01 captures above predate the shared website cover choice.
