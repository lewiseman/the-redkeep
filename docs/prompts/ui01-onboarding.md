# UI01 — Migrate the onboarding book UI

**Legacy-code permission superseded — 3 November 2026:** Redkeep is a new app;
do not copy or port legacy application code. Earlier adaptation instructions
below are historical. Use the current repository and approved artwork; preserve
honest provenance for the renderer/layout code already adapted during UI01.

**Asset setup superseded — 3 November 2026:** current shared artwork lives in
`website/public/art/` and the app downloads from the website's `/art/` directory,
configured by only `ASSET_BASE_URL` in `env.json`. The current cover is the
website's Redkeep castle JPEG. Firebase
URL maps, reference-copy acquisition and the duplicate payload pack are retired.
Use [asset setup](../onboarding-assets-setup.md); asset instructions in the
historical prompt below do not override the selected simplification.

**Superseded in part by the user's 3 November 2026 correction.** Restore the
legacy full-spread book/cover presentation and persist/require the user's name.
The user confirmed onboarding and name only. The current implementation contract
is [the book guide](../onboarding-ui-migration.md): it authorizes adapting the
selected legacy renderer directly, consuming the original cover, schema 8 and
name-based completion. The earlier crop-only, neutral-cover, no-name/no-schema
instructions below are historical and do not override that user correction.

**Further visual correction:** copy the original layout, bottom Terms/Privacy
links, mascot, Allura caption, colors and primary action. Remove the added visible
Previous/Next, chapter counter and Back controls. Page taps/swipes, keyboard and
semantics provide navigation. The latest user choice replaces the original
mascot with `redkeep/assets/branding/grand_maestar.png` and uses `google_fonts`
for the Allura caption, with no bundled font binary. Indexed local copies remain
available for offline tests; the 13-image downloaded pack and supplied URLs stay
unchanged. This also supersedes conflicting instructions
in the historical prompt below.


Copy the complete prompt below into the implementation chat. Preparing this
prompt does not start UI01. The supplied local originals are available; no new
asset download is required to inspect them.

```text
Work in /Users/lewis/Dev/Projects/The Redkeep. Implement UI01 — Onboarding book UI only. Do not start M12, another page UI, deferred features, desktop, or website work.

READ AND INSPECT FIRST
- Read AGENTS.md, MIGRATION_PLAN.md, README.md, and docs/architecture-testing.md.
- Read docs/onboarding-routing.md, docs/assets-startup.md, docs/onboarding-assets-setup.md, docs/onboarding-ui-migration.md, and assets/reference/README.md plus manifest.json. This prompt supersedes the older UI01 prerequisite that six new PNGs must arrive before any implementation.
- Inspect Git status and preserve unrelated staged/unstaged changes, signing/native configuration, URL/config values, and existing data. Never access raw_assets/.
- Inspect the current onboarding feature, completion controller/repository, go_router/bootstrap gate, rendering policy, verified asset resolver, publishing validator, and their tests.
- Use /Users/lewis/Dev/Projects/Journal/journal/lib/modules/root/views/widgets/onboarding_body.dart, onboarding_content.dart, onboarding_ink_background.dart, and onboarding_book/ as READ-ONLY behavioral/visual references. Inspect only what this phase needs; do not bulk-copy the old renderer or its dependencies.

AVAILABLE ARTWORK
The exact remote originals are already in assets/reference/images/onboarding/: cover.webp, notes.webp, diary.webp, ai.webp, flow.jpg, appearance.jpg, ink-paper.webp, paper-edge.webp, and binding-cloth.webp. Their stable keys, actual bytes, and hashes are in the local manifest. The onboarding.chapter.maester key maps to ai.webp. Full Firebase download URLs are in ignored redkeep/onboarding-downloads.local.json.

Inspect the local images rather than downloading or refreshing them. Preserve those exact reference bytes and keep them versioned outside Flutter's bundle. The originals contain printed Journal/AI labels, and Appearance mentions fonts. They are source references, not permission to advertise old branding or unimplemented features.

UI AND WORKFLOW
- Recreate the legacy tactile book composition: ivory paper/ink background, open illustrated chapters, visible binding/page edges, manual page turns, and a closing-cover state. Match the old visual identity while using small, consumed components in the existing feature structure.
- Present five chapters in order: Notes, Diary, Grand Maester, Flow, Appearance. Exclude People, Sync, Tasks, Birthdays, Movies, and unavailable voice/vision or desktop/API claims.
- Keep functional copy as live, scalable Flutter text with a correct semantic reading order. Use the chapter headings/descriptions already specified in the UI01 guide; describe AI as optional on-device assistance with separately downloaded models.
- Render book/page/cover surfaces using the neutral textures and Flutter primitives. Use only unbranded illustration regions from the supplied spreads when their printed headers or left-page copy conflict with current content. Determine explicit per-image crops from inspection. Do not bake new text into a bitmap, paint old claims into the new screen, edit reference files, generate replacement artwork, or add an unpersisted name input. A live Redkeep title over a neutral cover avoids the original printed Journal title; unused original cover pixels remain a reference only.
- Provide Previous/Next controls, current chapter position, manual swipe navigation, and Let's begin without forcing the user to view every chapter. No timed/autoplay page turning.
- Let's begin moves to the closing-cover presentation without persisting completion. Enter Redkeep calls the existing completion controller. Disable competing actions while saving; retain the cover, safe error message, and Try again after failure. Only a committed save unlocks the existing validated router continuation.
- Preserve interruption/relaunch behavior and already-complete bypass. Do not reset onboarding, add profile/account persistence, change the database schema, or put route selection/startup checks inside the book widgets. Do not introduce AI/model initialization on this screen.

MOTION, ACCESSIBILITY, AND PERFORMANCE
- Consume the existing RenderingPolicy. Reduced motion settles page/cover changes immediately; simpler effects use flat/static presentation without expensive perspective, layered shadows, or animated material lighting. Live reduction during a turn must settle to a valid state; inactive/offscreen routes stop animation work.
- Keep all actions reachable without swiping. Handle semantic labels, focus order, safe areas, theme contrast, landscape, and large text. At narrow widths or large text, use a scrollable single-column layout instead of scaling text down inside a fixed spread.
- Decode only the current/adjacent artwork at bounded display-appropriate sizes. Do not precache all full-resolution spreads, re-decode on each animation frame, or rebuild unrelated expensive content.

ASSET INTEGRATION REQUIRED FOR THIS UI
- Extend the current PNG-only catalog/publisher/resolver boundary to support the actual consumed PNG/WebP/JPEG files, including real format/decode/dimension verification. Preserve original formats; never rename WebP/JPEG bytes as PNG. Reuse installed dependencies if sufficient and verify official APIs before adding any dependency.
- Add reviewed per-image HTTPS source URLs with Firebase query parameters intact. Preserve safe local paths, byte limits, hashes, atomic installs, retry/repair behavior, and the normal directory-base fallback.
- Keep ASSET_BASE_URL in redkeep/env.json as its existing directory-host fallback. Feed the ignored per-image URL list through build-time configuration, not a runtime read of repository files. A small explicit preparation command may serialize that map as the string define ASSET_SOURCE_URLS_JSON into env.json while preserving every unrelated entry; never write real token-bearing URLs into tracked examples/catalogs/logs or add a dotenv/Firebase SDK solely for these already supplied URLs. Document the exact preparation and flutter run --dart-define-from-file=env.json commands.
- Populate the next pinned catalog/pack using exact approved local reference bytes and manifest hashes. Preserve the four existing runtime entries and installed writing/settings. Add only assets the new UI actually consumes; an original kept solely for visual reference must not become an unused required startup download.
- Keep reference files outside pubspec.yaml. The production app uses the verified downloaded-file resolver, with local checks under the preserved native splash and network transfer on the Flutter download screen. Missing/failed artwork must use the existing repair gate without losing the continuation or completion state.
- If the existing four required files lack usable production URLs, record that fresh-install hosting gap rather than inventing URLs or removing existing requirements. This must not prevent building the UI and exercising it through injected local fixtures. Do not silently declare live production downloads verified.

VERIFICATION AND STOPPING POINT
- Build focused offline tests from the actual local reference files and injected repositories/resolvers. Cover chapter boundaries, buttons/swipes, cover state, repeated taps, save/retry/commit timing, interruption, completed-user bypass, continuation preservation, actual image formats, and missing/corrupt-asset repair. Cover both themes, narrow/large-text/landscape layouts, normal/reduced/simpler modes, live preference changes and lifecycle disposal. No routine test fetches URLs or refreshes reference files.
- The earlier no-test instruction was for the asset-handoff setup. When this implementation prompt is selected, run the applicable README formatting/analyzer/offline test and local pack-validation checks for the implemented changes. Do not perform live Firebase requests, reference refreshes, device installs, or native smoke checks unless the user explicitly includes those in the implementation request. Record any unavailable/omitted evidence honestly; no physical-device performance claims follow from widget tests.
- Remove superseded onboarding widgets, imports, temporary work and unused dependencies. Update the feature/asset guides and the UI01 progress row; append a dated phase record with exact changes, commands/results, preserved contracts and remaining artwork/hosting/device gaps. Do not mark unverified acceptance complete.
- Finish with the implemented behavior, verification results, any specific remaining input needed, and next eligible work. Stop after UI01; no automatic further phase, publication, remote Git operation, or unrelated migration.
```
