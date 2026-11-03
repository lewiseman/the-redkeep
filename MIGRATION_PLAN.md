# Redkeep migration plan and implementation prompts

Agreed on 2 November 2026. Workspace: `/Users/lewis/Dev/Projects/The Redkeep`.

## 1. Purpose and how to use this guide

**Latest engineering instruction — 3 November 2026:** Redkeep is a new app. Do
not copy, port or import additional legacy code, manifests, services or native
configuration. Older phase prompts do not grant current permission to do so.
Earlier UI01 onboarding renderer/layout adaptation and W01 website copying
remain recorded honestly as existing work; the current asset/config cleanup
does not rewrite those components. Redkeep's own database schema upgrades are
separate from importing an old app or its user data.

Focus on the mobile writing app and selected legacy page UI migrations. As agreed on 3 November 2026, retain the existing desktop app; its rebuild track is parked. Later that day the user explicitly reopened W01 as a local-only website copy/rename, preserving the legacy UI and screenshots. The user subsequently selected `https://redkeep.lewiseman.com/` as the shared image host and publishes externally. `website/public/art/` is now the canonical local image reference, without additional reference copies. Agent-run publication remains separately scoped. Preserve the journal, paper, artwork, and book identity while improving architecture, accessibility, performance, and testability.

**Current direction:** UI01 retains the book/folding name cover, primary action,
dots/hint, bottom Terms/Privacy links and selected Grand Maester/Allura identity.
Missing name means onboarding; schema 8 preserves writing/settings. The selected
asset simplification now uses `https://redkeep.lewiseman.com/art/` by default,
with `website/public/art/` as the canonical local image source and offline test
input. `presentation-website-v1` pins 12 images / 2,800,992 bytes, including the
website's Redkeep castle cover. All eleven unchanged installed images are reused;
startup mascot/ink paper remain bundled. Firebase URL maps/preparation, the
duplicate payload pack and custom website build checker/size gate are removed.
The latest user choice passes only `ASSET_BASE_URL` through ignored
`redkeep/env.json`, with a tracked one-key example and matching editor arguments.
Per-image maps, preparation and HTTP fixture flags remain removed. The old
download list stays deleted; the new env file contains only the image-directory URL.
All 12 live images returned HTTP 200 and
match local bytes. Formatting, analysis, 361 offline mobile tests, 17 website
browser checks, website build/lint, optional catalog validation and Android debug
packaging pass; see `docs/evidence/assets-website/verification.json`. Native fresh
install/download from this host, physical-device and AI release qualifications
remain unverified. M12, desktop work and agent-run publication remain separately
scoped.

The documentation task creates this file only. It does not initialize Git, create `AGENTS.md`, install packages, migrate assets, or change application code. Those actions belong to the selected implementation phases below.

To begin development, copy the complete **M01** prompt into a new or existing chat with this workspace open. After a phase is finished, use the next eligible prompt. Each prompt is self-contained and instructs the implementing agent to read this guide, honor its boundaries, run relevant checks, update progress, and stop at the phase boundary.

### Working rules for every implementation phase

- Inspect the current workspace and applicable `AGENTS.md` instructions first. Preserve unrelated user changes.
- Implement only the phase the user selected. Do not continue into another phase automatically.
- Treat legacy projects as read-only references. Inspect their actual behavior and reachable entry points; documentation alone is not proof a feature works.
- Carry over only behavior, assets, and dependencies needed by an approved feature. Do not bulk-copy modules, tests, generated code, native bridges, or package manifests.
- Add dependencies when they acquire a real consumer. Verify current official documentation and compatibility; keep application lockfiles reproducible. Do not copy version numbers blindly from old projects or this guide.
- Use the simplest implementation that respects the agreed boundaries. No empty future-feature scaffolding, unimplemented production adapters, sample user data, or inactive controls masquerading as features.
- Every new visual behavior must work with reduced motion, simpler effects, large text, and narrow screens.
- Run meaningful checks for changed behavior. Routine checks must not need private accounts, real journal data, external services, or model downloads.
- Never claim that an unavailable device, platform, native build, or model has been verified. Record the gap and its impact while completing work that can be verified.
- Remove superseded implementations, imports, dependencies, and temporary experiments made obsolete by the phase. Keep useful verification harnesses under documented commands.
- Update the progress row and append a phase record before stopping. Summarize what changed, what passed, what remains unverified, and the next eligible phase.

### Progress tracker

Use `Not started`, `In progress`, `Complete`, `Partial`, or `Deferred`. A partial result must identify the missing acceptance evidence and any dependent work it prevents. A deferred track requires the user to reopen its scope explicitly. Do not mark a phase complete merely because its code exists.

| Phase | Status | Completed work / evidence | Limitations / next action |
| --- | --- | --- | --- |
| Documentation | Complete | Agreed architecture, roadmap, standalone prompts, and deferred planning prompts recorded in this file. | No application phase has been executed. |
| M01 — Foundations | Complete | Root local Git repository, ignore rules, AGENTS/command/architecture guides, Riverpod composition, neutral go_router shell; formatting, analysis, and all 6 shell/DI/routing tests pass. | Native builds and physical-device behavior unverified; next eligible phase is M02. |
| M02 — Design and accessibility | Complete | Light/dark tokens and system typography, shared paper surfaces, saved appearance settings in background Drift schema 1, reactive OS/app rendering policy; formatting, analysis, all 26 tests, Android debug build, and emulator restart persistence pass. | iOS, physical-device accessibility/keyboard behavior, and release performance unverified; next eligible phase is M03 (M04 is also eligible independently under its prerequisite rules). |
| M03 — AI feasibility | Partial | Pinned core 2.5.5 / LiteRT-LM engine 1.19.1, minimal injected adapter and synthetic harness, 40 passing tests, Android ARM64/API 30 packaging, iOS simulator and unsigned device builds; pinned Qwen3 0.6B streaming/cancel/reuse/cleanup/failure checks pass on physical Galaxy S24 Ultra CPU/GPU and iOS simulator CPU. | Physical iOS/Metal, minimum-OS and low-end hardware, sustained resources and production signing remain unverified and block corresponding AI release claims. M10 adds short Galaxy release-mode CPU checks; see M03/M10 records and docs/ai-feasibility.md. |
| M04 — Assets and startup | Complete | Reachable-media inventory/provenance, pinned three-image pack, catalog/publishing validator, injected persistent resolver, verified atomic installs/repair, bounded bootstrap/splash gate; all 88 tests, analysis/formatting, Android and iOS simulator debug builds pass. Android local HTTP download → offline restart and missing-file gating; iOS fresh gate and offline staged-pack recovery verified. | Real HTTPS hosting/publication and physical/minimum-OS/low-end release evidence remain prerequisites; iOS HTTP download and native failure/ENOSPC drills unverified. M03's AI gaps remain unchanged. Next eligible phase is M05. |
| M05 — Onboarding and routing | Complete | Minimal welcome, committed schema-2 completion with migration preservation, validated bootstrap/onboarding continuations and safe fallback, framework back gestures; all 111 tests, formatting/analysis, Android and iOS simulator debug builds pass. Android interruption → requested settings → back/restart and iOS welcome render verified. | Physical accessibility/gestures, native iOS completion/restart, OS link registration/restoration and release/minimum-OS evidence unverified. M04 host and M03 AI gaps unchanged. Next eligible phase is M06. |
| M06 — Notes vertical slice | Complete | Same primary database upgraded to schema 3; plain-text Notes CRUD, stable ID routes, revision/token checks, committed-save feedback and persistent recovery drafts. All 139 tests, analysis/formatting, Android/iOS simulator debug builds pass; Android airplane-mode create/recover/edit/save/delete and force-stop/reopen verified. See docs/notes-writing.md and docs/evidence/m06/verification.json. | Physical-device accessibility/IME, native iOS writing, minimum-OS/low-end/release and native disk-full/power-loss evidence unverified. M04 host and M03 AI gaps unchanged. Next eligible phase is M07. |
| M07 — Notes organization | Complete | Schema 4 with local keyword/tag/pin filters, Trash/restore, typed permanent deletion, safe bounded Markdown preview and resolver-backed Notes artwork. All 155 tests, formatting/analysis, asset validation and Android/iOS simulator debug builds pass; Android offline reopen/filter/restore/delete and external browser launch verified. See docs/notes-writing.md and docs/evidence/m07/verification.json. | Native iOS writing/browser, physical accessibility/IME, minimum-OS/low-end/release and native storage-failure evidence unverified. Preview/search bounds documented; M04 host and M03 AI gaps unchanged. Next eligible phase is M08. |
| M08 — Diary | Complete | Schema 5 separates civil-date Diary entries, recovery drafts and day headings; calendar/day/entry routes, CRUD, local keyword search and static/simpler notebook presentation. All 185 tests, formatting/analysis, four timezone suites, asset validation and Android/iOS simulator debug builds pass; Android offline draft recovery, committed reopen/search and deletion verified. See docs/diary-writing.md and docs/evidence/m08/verification.json. | Physical accessibility/IME, native iOS Diary writing, minimum-OS/low-end/release and native storage-failure evidence unverified. No expensive visual effect introduced or physical performance claim. M04 host and M03 AI gaps unchanged. Next eligible phase is M09. |
| M09 — Flow | Complete | Schema 6 with quick capture committed before composer clearing, durable capture/edit drafts, newest-first thoughts, ID CRUD and complete Diary/Notes/Flow/More shell. All 213 tests, analysis/formatting, asset validation and Android/iOS simulator debug builds pass; Android offline capture/recovery/edit/delete/restart verified. See docs/flow-writing.md and docs/evidence/m09/verification.json. | Physical accessibility/IME, native iOS Flow writing, minimum-OS/low-end/release and native storage-failure evidence unverified. M04 host and M03 AI gaps unchanged. Next eligible phase is M10. |
| M10 — Brain | Partial | Brain settings, schema-7 device assignments, optional verified model install/remove/progress/readiness, bounded session/resource ownership and cancellation; 266 tests, analysis/formatting and Android/iOS simulator builds pass. Physical Galaxy CPU/GPU debug, Galaxy CPU release and iOS simulator CPU checks pass with the pinned artifact; see docs/brain.md and docs/evidence/m10/verification.json. | Implementation and available checks finished. Physical iOS/Metal, minimum-OS/low-end, sustained resource/thermal/energy and native storage-failure qualification remain gaps blocking corresponding AI release claims. Helper integration is recorded in M11; these AI qualification gaps remain. |
| M11 — Grand Maester | Complete | Contextual floating helper, Brain setup/readiness, streamed review/copy-only results and revision/selection-guarded Note rewrite acceptance into recovery drafts. 322 tests, analysis/formatting and native builds pass; separate 10-check Galaxy CPU and iOS simulator CPU smoke reports. See docs/grand-maester.md and docs/evidence/m11/verification.json. | Physical iOS/low-end/minimum-OS, sustained resources, native helper touch acceptance/OS-background inference and physical accessibility remain unverified; M03/M10 limits and M04 production-host prerequisite remain. UI01 artwork handoff and onboarding UI are next; M12 follows selected mobile UI work. |
| UI01 planning — Onboarding image handoff | Complete | Current standalone execution prompt is docs/prompts/ui01-onboarding.md, updated for nine local WebP/JPEG originals, Firebase source configuration, live copy and usable illustration regions. Earlier PNG-only handoff prompt superseded. | Prompt preparation only. Original reference pixels remain unchanged; implement UI01 only when the user selects the execution prompt. |
| UI01 asset configuration | Partial | One default website image directory; cataloged website filenames retain eleven installed identities and adopt the Redkeep castle cover. All twelve live files match local bytes; 361 offline tests, catalog validation and Android debug packaging pass. | Fresh native install/download/offline restart from the new HTTPS host and redistribution/device qualification remain unverified. Earlier Firebase configuration is retired. |
| UI01 local asset references | Complete | Current image consumers/tests use website/public/art directly without a duplicate pack. Existing reference archives remain intact; the separate Allura font reference still serves offline font tests. | No routine test downloads; bundled mascot/ink paper remain required startup resources. |
| UI01 — Onboarding book UI | Complete | Restored book/folding name cover, Grand Maester, Allura, primary action, dots/hint and bottom links; manual/keyboard/semantic navigation with no added controls. Schema 8 preserves writing/settings and requires a committed name. Shared website sources now supply the Redkeep castle cover and twelve required downloads; bundled startup branding remains unchanged. Current 361 offline tests and Android debug packaging pass; see docs/evidence/assets-website/verification.json. | Prior visual-parity screenshots describe earlier cover/branding variants. Live font/native fresh-install, physical performance/accessibility and M12 qualification remain separate. |
| Asset simplification — Website delivery | Complete | Canonical website artwork and integrity-pinned installs/offline tests. Only ASSET_BASE_URL is passed through ignored env.json; one-key example and Debug/Profile/Release wiring restored. Old URL lists, HTTP fixture flags, duplicate pack and website checker remain removed. See docs/evidence/assets-website/env-base-url.json. | Single-setting follow-up only; no additional legacy code imports. Native fresh-install qualification and M12 remain separate. |
| M12 — Mobile release preparation | Not started | — | Requires M01–M11 plus UI01 and any further individually selected mobile UI phases; production media hosting and recorded device qualification remain prerequisites. |
| D01 — Flutter desktop foundation | Deferred | Existing desktop app retained by user decision on 3 November 2026. | Parked; not a gate for mobile acceptance and never automatic. Requires explicit user rescoping. |
| D02 — Companion connection | Deferred | No new mobile-to-old-desktop compatibility work selected. | Parked with D01; retaining the old app does not establish protocol compatibility. |
| D03 — Desktop release preparation | Deferred | — | Parked with the desktop rebuild. |
| W01 — Marketing website | Complete | Selected React/TypeScript/Vite website retains Grand Maester, castle cover, name typing, original animations and all six screenshots. Build is TypeScript → Vite → prerendering; custom checker and size gate removed. Build, lint and 17 browser/axe tests pass; see docs/evidence/assets-website/verification.json. | User publishes the selected host externally. Download remains disabled; no website simpler/reduced-motion mode. Rights/metadata/browser/device qualification and agent-run publication remain separately scoped. |

For each executed phase, append a record under **Phase records** with: date, phase ID, changed behavior and contracts, exact commands and results, device/build/model identifiers where relevant, remaining limitations, and the next eligible prompt. Never include API keys, pairing credentials, or private writing in evidence.

## 2. Current state and product boundaries

### Current workspace

- The mobile starter already exists at `/Users/lewis/Dev/Projects/The Redkeep/redkeep`.
- During planning on 2 November 2026 it was the Flutter counter starter, with Flutter 3.47.5 / Dart 3.13.4 observed locally. `flutter analyze` and the starter smoke test passed then. This is starter evidence, not evidence for future features; M01 must establish a fresh baseline.
- No existing workspace `AGENTS.md`, migration guide, or Git repository was found during inspection. Recheck before M01 because the workspace may change.
- `/Users/lewis/Dev/Projects/The Redkeep/raw_assets` contains unreviewed artwork and audio source files. Dont touch that folder its for the user to store assets still being worked on eg editing.

### Legacy references — read only

| Previous project | Location | Reference value |
| --- | --- | --- |
| Flutter mobile app | `/Users/lewis/Dev/Projects/Journal/journal` | Writing journeys, visual identity, accessibility pitfalls, and behavior to evaluate. |
| Electron desktop companion | `/Users/lewis/Dev/Projects/Journal/desktop` | Companion purpose, model management, pairing, and job behavior. |
| Marketing website | `/Users/lewis/Dev/Projects/Journal/bookflip` | Brand presentation, book interactions, artwork, and content structure. |

### First release and explicit deferrals

The first mobile release contains Notes, Diary, Flow, appearance/accessibility settings, required-asset startup handling, and basic on-device Grand Maester assistance. Start with a fresh database and retain the new app identity, currently `com.lewiseman.redkeep`. No legacy data importer, in-place upgrade, or old cloud-account migration is included.

The existing desktop app and hosted marketing website continue unchanged. The user later reopened W01 for a local-only website sibling, retaining the legacy UI and screenshots; publication remains excluded. Desktop applications, shared-package extraction and connection work remain outside the active scope. Compatibility between Redkeep mobile and the old desktop protocol has not been established or selected by this UI planning step.

The historical D01–D03 prompts remain parked reference material. W01 was explicitly reopened and its release/product assumptions revalidated on 3 November 2026; the later phase record documents the user-selected exceptions. If the user explicitly reopens desktop work, revisit its assumptions against the then-current apps before execution. They are not prerequisites for mobile completion or deferred mobile feature planning.

Defer third-party API backends, tasks/alarms/notifications, People and P2P note sharing, collaborative text editing, semantic search/embeddings, advanced attachments/media, voice, and cloud sync. Their planning prompts appear later in this guide. The desktop AI transport does not constitute P2P note sharing or journal synchronization.

The new product uses **Grand Maester**, with no QVAC branding, QVAC runtime, Electron dependency, JavaScript inference bridge, or JavaScript P2P implementation. Historical references in this guide are allowed; new runtime code and user-facing branding must follow the new direction.

## 3. Architecture and behavior contracts

### 3.1 Workspace and code organization

Use one repository rooted at `/Users/lewis/Dev/Projects/The Redkeep`. Keep the current mobile location. Creating a sibling `desktop` app is parked. W01 now creates only the explicitly reopened `website/` React sibling; no shared Dart package extraction is justified. If that scope is explicitly reopened later, extract shared code only for a real second consumer. Preserve `raw_assets` as source material outside application asset bundles and do not access it.

Within mobile, use feature-first organization with MVVM-style presentation:

- `app`: composition, router, bootstrap integration, and the app shell.
- `core`: genuinely shared infrastructure and UI primitives, not a catch-all business-logic folder.
- `features/<feature>/domain`: immutable models and repository contracts without plugin or database types.
- `features/<feature>/data`: persistence, mapping, and external-service implementations.
- `features/<feature>/application`: Riverpod controllers and orchestration.
- `features/<feature>/presentation`: views and feature widgets.

This is a convention, not a command to generate all directories in advance. Widgets handle presentation and interactions; controllers coordinate actions; repositories own authoritative application data. Add separate use-case classes when substantial shared orchestration warrants them, rather than one per CRUD method.

Use Riverpod for state and dependency injection, Drift/SQLite for primary persistence, `go_router` for navigation, and `flutter_edge_ai` with a LiteRT-LM engine adapter for initial local inference. Prefer immutable domain state and explicit results/errors. Inject external boundaries, clocks, and ID generators; avoid mutable globally accessible services and broad barrel imports. Use generation where it pays for itself, initially Drift, rather than requiring generators for every provider/model.

**Phase dependency clarification:** M02 creates the first Drift database for real persisted settings. M06 extends that same database for Notes. This avoids a temporary production preference store and makes the existing-database checks in M04 meaningful. Each subsequent schema change gets a tested migration.

### 3.2 Primary persistence and document editing

Use background database execution, versioned schemas, and migration snapshots/tests. Keep database rows and generated types inside data implementations. Repositories expose domain models and observable state, and accept test database connections.

Notes begin with plain text and Markdown preview. Stable IDs and explicit source revisions support draft recovery, stale-write protection, AI proposals, and later indexing. Put document reads/edits behind an application-owned boundary so views are not coupled to a database string or a future CRDT implementation. Do not build a custom collaborative engine now or promise migration-free CRDT adoption.

Notes support manual saves, persisted recovery drafts, deletion, and later trash/restore. Successful save feedback must correspond to committed data. Unsaved writing and failed saves must remain recoverable. AI replacements must check the captured revision and, for selected-text operations, the original selection/text context before acceptance.

Diary stores text entries separately from day presentation metadata. A diary date is a civil calendar date, not an instant that shifts when converted between timezones. Flow persists captured text before clearing its composer. Never seed production writing collections with fixtures.

### 3.3 Vector embeddings and semantic search — deferred implementation

| Store | Contents and ownership |
| --- | --- |
| Main Drift-managed SQLite database | Authoritative writing, settings, revisions, and durable indexing work/status once semantic search exists. |
| Separate vector SQLite database | Rebuildable chunks, embeddings, source references, and embedding-profile metadata, owned by the vector provider. |

Use `flutter_edge_ai_rag` with `flutter_edge_ai_sqlite` and its `sqlite-vec` search implementation when the semantic-search milestone is authorized. Drift does not manage the vector provider's tables or migrations. Keep retrieval behind an application-owned repository contract so an embedded Qdrant provider can be evaluated if benchmarks justify it; do not install two vector backends initially.

The future indexing flow is:

1. Commit writing and its indexing work item in one main-database transaction.
2. A separate worker loads the source snapshot, chunks within the embedder's limits, and generates document embeddings without blocking writing.
3. Install indexed chunks with source type/ID, chunk ID, source revision/content hash, and the embedding profile identity.
4. Recheck source state before acknowledging indexing; an edit during processing must remain pending for the latest revision.
5. Embed a query with the matching query pipeline, retrieve candidates, and reload/revalidate sources from Drift before display or AI context assembly. Deleted or stale chunks cannot become current answers.

The stores do not share a transaction. Durable work, idempotent updates, read-time validation, deletion processing, and reconciliation handle interruption between their writes. Losing or rebuilding the vector database must never delete writing. Keyword search remains usable without an embedding model or a ready index.

Version the model weights, tokenizer, dimensions, normalization/pooling, document/query prefixes, and chunking contract. A change that makes an index incompatible requires a new versioned location and rebuilding; equal vector dimensions alone do not imply compatible embeddings. Retire old indexes only after the replacement is usable. Tests must cover edits/deletes during indexing, restart recovery, stale results, unavailable models, and profile changes.

Do not add vector packages, placeholder indexing tables, or an indexing worker before the later semantic-search phase is selected.

### 3.4 Startup and downloadable presentation assets

Preserve the native splash immediately after initializing Flutter bindings:

```dart
final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
```

Use `flutter_native_splash` as a runtime dependency because the app calls its lifecycle methods. The preserved splash covers bounded local checks only: preferences, existing database initialization/migrations, onboarding state, and asset availability. Bound the overall check phase and route slow or failed work into a Flutter loading/error state. Coordinate splash removal so Flutter can draw; do not wait for a first frame while its delivery remains deferred by splash preservation.

After local checks, show the appropriate Flutter screen and remove the native splash: download/retry, onboarding, a recoverable startup error, or normal navigation. Network downloads and model initialization do not run under the preserved splash. Add future local checks through the bootstrap coordinator rather than enlarging `main` with feature-specific work.

Use a release-pinned catalog containing stable asset keys, revisions, expected size/hash, safe relative locations, and configurable download URLs/base location. Catalog metadata may be bundled; presentation media is downloaded. Preserve selected media licenses and provenance. Bootstrap screens can use system fonts. Only required native launcher/splash and minimal bootstrap resources are bundled as exceptions.

The user's UI01 resource choice adds two permanent bundled presentation assets:
`grand_maestar.png` and `ink-paper.webp` ship unchanged with exact indexed
references. Startup and both onboarding layouts use these bundled images,
including before any download. The paper is removed from the required catalog
and deployment fixture; Firebase source maps are now retired. Allura uses
`google_fonts` runtime fetching/caching instead
of bundled font binaries; its OFL notice ships separately. Font loading and
these branding images remain outside required-artwork downloads. The remaining
`presentation-website-v1` catalog contains 12 images / 2,800,992 bytes.

Download all assets required by the currently implemented release, not every old file or all future media. Inventory media required by planned first-release features so the initial complete release has a coherent pack. On later launches, validate catalog-key/revision mappings against real local files and the installation ledger; a key in a database is not proof the file exists. Verify size and hash before atomic installation. Avoid rehashing every large file on every launch without evidence that it is needed; validate suspicious files and failures, repair invalid installations, and test same-path replacement scenarios.

Use persistent app-owned storage rather than a purgeable image cache as the authoritative asset location. Keep completed valid downloads across retries, reject partial/corrupt files as installed assets, prevent writes outside the asset directory, and surface interruption/storage/network failures with actionable retry UI. Required missing artwork blocks normal entry, including on an offline first launch. Existing writing must never be deleted to repair assets.

The user's latest source decision uses `website/public/art/` as the canonical
local reference for shared website/mobile images, deployed under
`https://redkeep.lewiseman.com/art/`. Read these files first and use them offline
in tests; do not create additional reference copies for images already there.
Existing `assets/reference/` files remain historical evidence or support current
font consumers, including the Allura offline tests. These local
references do not become Flutter bundles or installed-app fallbacks automatically.
Review app catalog paths, revisions, sizes and hashes separately. The website
uses normal Vite public-file copying and prerendering, without a custom asset
checker or size gate. Mobile image tests and optional catalog
validation now read the website artwork directly. The app preserves installed
paths separately from website source filenames to reuse valid existing files.

Routine startup with complete local assets needs no internet and must not fetch a remote catalog before opening. New media catalogs are versioned with releases initially. The selected image host is `https://redkeep.lewiseman.com/`; mobile source migration and host byte checks are complete; verified native fresh-install downloads remain outstanding. Controlled local fixtures still support offline development. Never ship a placeholder URL or a localhost production default.

AI model downloads are separate and optional. Future videos and notification sounds use the media delivery boundary only after their own feature is authorized. Validate platform sound-location, format, and scheduling rules then; do not assume every downloaded sound can directly serve as a system notification sound.

### 3.5 Motion, visual effects, and performance

This remains the mobile contract. For W01 only, the user explicitly removed the website Simpler view control and all reduced-motion handling; see the W01 record and website guide.

Create one reactive rendering policy combining platform accessibility with saved app preferences. Effective reduced motion is true when the OS requests it or the user enables additional reduction. An app preference cannot override an OS reduction request. Effective simpler effects is true under reduced motion or when explicitly selected by the user. Changes apply while the app is running and persist across restart.

Provide shared duration/transition behavior and static alternatives for expensive paper effects. Stop decorative tickers, animation, and video when offscreen or the app is inactive. Simpler presentation retains full functionality. Use bounded image decode sizes, lazy lists, and stable layout; avoid rebuilding expensive painters for unrelated state changes. Do not introduce speculative hardware classification or promise that a setting alone guarantees low-end performance.

Test small screens, large text, themes, OS preference changes, keyboard/safe areas, and both rendering modes. Profile representative low-end Android hardware and actual iOS hardware before performance claims. Record device, refresh rate, build mode, collection size, and frame/memory evidence. An emulator or the development Mac is not evidence of physical low-end-phone performance.

### 3.6 Navigation and future notification destinations

Adopt `go_router` in the first shell, then add onboarding/bootstrap redirects and feature destinations incrementally. Use addressable entity IDs rather than passing live models as the only route input. Planned destinations include `/notes/:id`, `/diary/:date`, `/flow/:id`, `/settings`, and `/settings/brain`; register them only once their screens exist. Preserve platform back behavior and apply the effective motion policy to transitions.

Preserve a requested destination through bootstrap, required downloads, and onboarding. Validate parameters and show a useful fallback for deleted/missing records. Keep route selection and lifecycle-sensitive work outside widgets where it can be tested. Add final Diary/Notes/Flow/More navigation as each feature becomes available, without fake feature pages. Match the existing diary-first main experience once Diary is implemented.

When notifications are added, validate their versioned payload, resolve it to the same application destination, and queue it until startup is ready. Test cold/warm launches, duplicate taps, missing entities, and interrupted startup then. Do not add notification plugins, task routes, or payload implementations now.

### 3.7 Grand Maester and Brain

Brain maps capabilities to model assignments and execution locations: device, desktop companion, or API provider. Only device execution is implemented/selectable in the first mobile release; future targets remain documented extension points, not fake working adapters.

Wrap `flutter_edge_ai` and its separately registered LiteRT-LM engine in an application-owned adapter. M03 verifies current platform requirements, formats, ABI limits, compatible packages, and real inference. The agreed initial platform floor is Android 11+ ARM64 and iOS 15+. Begin qualification with a small ungated model such as Qwen3 0.6B in the supported format. Pin the actual model revision/checksum and document license, size, backend, settings, and observed quality. Do not treat a sample name as proof it works on each device.

Brain owns installation/removal state, capability assignments, readiness, optional model downloads, and resource/session lifetime. No model is required or automatically loaded for normal writing startup. Handle insufficient resources, missing files, download failures, cancellation, and interrupted runs. Never silently route content to another execution location.

Initial operations are note rewriting, note/diary text summarization, and an optional short Flow reflection. The floating helper presents contextual actions for available content and can open Brain when setup is needed. Results are proposals, with explicit review and acceptance for any source modification. Summaries/reflections may be viewed or copied without silently changing writing. Prevent late or stale results from modifying another record, a newer revision, or a changed selection. Closing a screen, canceling, and backgrounding need explicit lifecycle handling.

The desktop rebuild and D02 connection backend are parked. The existing desktop app is retained without an implied guarantee of Redkeep protocol compatibility. Any later companion-integration scope must be explicitly selected and planned against that real desktop implementation. Use established Dart/native dependencies and reviewed trust primitives rather than recreating a JavaScript bridge or inventing cryptography.

### 3.8 Testing and AI-friendly maintenance

Mirror production feature boundaries under `test`, use `test/support` for reusable fixtures/fakes, and `integration_test` for full journeys. Keep helpers small and behavior-oriented; do not require a mega-fixture that starts every service. Use Riverpod overrides and fresh containers, deterministic clocks/IDs, and real temporary SQLite databases for repository behavior. Test close/reopen persistence as well as in-memory queries, and retain schema snapshots for migrations.

Routine tests run without network, downloaded models, private credentials, or existing user databases. Inject controlled file/network/AI boundaries. Separate opt-in real-device/native/model verification from the fast suite. Use synthetic writing in evidence. Prefer observable behavior and contract tests over source-text searches or tests that restate the implementation.

For each application phase run formatting checks, `flutter analyze`, and relevant Flutter tests; include package checks once shared packages exist. Broaden testing for the touched boundaries, schema changes, regressions, and release gates. Formatting commands may be used during implementation; for this documentation-only task no app checks need rerunning. Later website checks include TypeScript, lint, tests where meaningful, and production build.

Each implemented feature gets a short guide covering its responsibility, public contracts, failure/recovery behavior, relevant tests/commands, and limitations. Root `AGENTS.md`, created in M01, should point agents to this file and feature guides, enforce one selected phase, and preserve read-only legacy boundaries without introducing routine approval requests.

## 4. Ordered implementation prompts

These are execution prompts. Copy a complete block. Their scope is limited by the architecture above even when they summarize it.

### M01 — Foundations

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M01 only.

Prerequisites: this agreed guide exists; inspect the mobile starter and unrelated user changes. Re-establish the local tool/test baseline.
Scope: establish one repository at the workspace root if none exists, appropriate ignore rules, root AGENTS.md, and documented commands. Preserve the current mobile path and raw_assets. Introduce Riverpod composition and a minimal go_router shell, remove the counter demo, and add deterministic boundary/test helpers only where used. Create a short architecture/testing guide. Keep a runnable neutral shell without fake feature tabs.
Exclusions: no asset downloads, persistent database, AI packages, future apps, legacy imports, remote Git operations, or later-feature implementations.
Acceptance: formatting check, flutter analyze, and meaningful shell/DI/routing tests pass. Existing workspace material remains intact; no copied unused dependencies or sample writing exists.
Finish: update the M01 progress row and append a phase record with changes, exact checks/results, limitations, and next eligible phase. Stop after M01; do not start M02.
```

### M02 — Design and accessibility

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M02 only.

Prerequisite: M01 is complete.
Scope: build light/dark theme tokens, typography roles, usable shared paper surfaces, and appearance settings. Introduce Drift for actual saved preferences behind a repository, with schema snapshots and background execution. Implement the central reactive motion/effects policy; OS reduced motion always wins and user reduction can go further. Use system fonts and simple programmatic surfaces until downloaded assets exist.
Exclusions: no artwork bundling, model loading, Notes/Diary/Flow data, speculative device grading, or expensive decorative renderers.
Acceptance: verify preferences after database close/reopen, isolated controller/repository behavior, OS/app setting combinations, live changes, inactive animation handling, themes, narrow layouts, large text, and keyboard/safe areas. Run formatting, analysis, and relevant tests.
Finish: update the M02 progress row and append a phase record with evidence, limitations, and next eligible phase. Stop after M02.
```

### M03 — AI feasibility

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M03 only.

Prerequisites: M01–M02; inspect available Android/iOS tooling and hardware without assuming devices exist.
Scope: verify current official flutter_edge_ai/LiteRT-LM APIs, compatible package versions, native setup, and the agreed Android 11+ ARM64/iOS 15+ floors. Build an isolated synthetic-text verification harness and a minimal application-owned adapter with fake-backed tests. Start qualification with a small ungated Qwen3 0.6B artifact in a supported format; record its immutable revision/hash, license, backend, size, settings, timing, and output limitations. Exercise streaming, cancellation, repeated use, cleanup, and failure behavior.
Exclusions: no production Brain/helper UI, automatic startup inference, semantic search, API providers, companion backend, or JavaScript bridge.
Acceptance: run available native builds and real inference; report each platform honestly as verified or unverified. Unavailable hardware remains a recorded acceptance gap, not fabricated evidence. Keep ordinary app startup independent of AI.
Finish: update the M03 progress row and append a phase record, including evidence gaps and what they block. Stop; independent M04 work may proceed with documented gaps.
```

### M04 — Assets and startup

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M04 only.

Prerequisites: M01–M02. Read M03's findings; missing AI device evidence need not prevent this non-AI phase.
Scope: inventory required first-release presentation media from reachable legacy references and inspect raw_assets without changing originals. Select only relevant, usable, licensed media; exclude former branding and unassigned audio. Build catalog/publishing validation, stable keys, configurable locations, verified atomic downloads, persistent storage, repair/retry/progress UI, and an injectable asset resolver. Add flutter_native_splash preservation and bounded local bootstrap checks using the existing settings/database. Release the splash before network work. Use controlled local fixtures until a real host is configured.
Exclusions: no production hosting purchase/publication, AI model downloads as required assets, future sound/video features, online catalog check on every launch, or offline bypass of required downloads.
Acceptance: test fresh and complete offline launches, missing files despite saved keys, interrupted/corrupt downloads, bad catalog/paths, disk/network failures, restart/retry, and splash exit on errors. Existing writing is never cleared for asset repair.
Finish: update the M04 progress row and append a phase record with evidence, catalog/host setup instructions, release prerequisites, and next phase. Stop after M04.
```

### M05 — Onboarding and routing

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M05 only.

Prerequisite: M04 is complete.
Scope: implement minimal onboarding, persisted completion, and go_router bootstrap/onboarding redirects. Preserve validated requested destinations through local checks, required downloads, and onboarding. Define the navigation boundary, parameter validation, and useful error/fallback behavior without registering screens that do not exist. Respect platform back gestures and the central rendering policy.
Exclusions: no authentication, cloud sync, notification plugins, task routes, future-feature placeholder screens, or legacy account import.
Acceptance: test first/repeated launch, onboarding interruption, no redirect loops, invalid destinations, pending-destination preservation, back behavior, narrow/large-text layouts, and reduced-motion transitions. Run formatting, analysis, and relevant tests.
Finish: update the M05 progress row and append a phase record with exact verification, limitations, and next eligible phase. Stop after M05.
```

### M06 — Notes vertical slice

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M06 only.

Prerequisite: M05 is complete; extend the existing settings database rather than creating a competing primary store.
Scope: implement note models, repository, controllers, ID-based routes, list/read/edit/create/delete journeys, explicit committed-save feedback, and persistent recovery drafts. Use plain text through the document-editing boundary, stable IDs, revisions, and stale-write protection. Saving must not clear recoverable writing on failure. Deletion keeps enough data for M07 trash/restore without implementing collaboration. Add only currently usable shell navigation and asset-backed presentation.
Exclusions: no CRDT runtime, sync, embeddings/index queues, attachments, rich-text editor, AI UI, or legacy data migration.
Acceptance: test the database migration, create/edit/delete, close/reopen recovery, failed saves, drafts/navigation, stale revisions, Unicode, large text bodies, invalid/deleted IDs, rendering modes, and real offline writing. No production fixtures.
Finish: update the M06 progress row and feature guide, and append a phase record with exact checks, limitations, and next phase. Stop after M06.
```

### M07 — Notes organization

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M07 only.

Prerequisite: M06 is complete.
Scope: add local keyword search, tags, pinning, trash/restore and deliberate permanent deletion, Markdown preview, and selected note artwork through the existing asset resolver. Keep editing plain text, use the current document/repository boundaries, and provide consistent empty/loading/error states. Handle external Markdown links through a safe platform launcher; do not introduce executable HTML previews.
Exclusions: no embeddings, AI-generated websites, collaboration, cloud sync, new media types, or replacement navigation/storage frameworks.
Acceptance: verify search/filter combinations, tag/pin persistence, trash exclusion/restoration/deleted routes, malformed Markdown, long content, large collections, bounded image decoding, and normal/simplified rendering. Test schema migrations if changed; run relevant checks.
Finish: update the M07 progress row and feature guide, and append a phase record with verification, limitations, and next phase. Stop after M07.
```

### M08 — Diary

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M08 only.

Prerequisite: M07 is complete.
Scope: implement text diary entries, a day reader, calendar/date routes, entry creation/editing/deletion, and local keyword search. Store entries separately from day-level presentation metadata. Treat date keys as civil dates; keep timestamps for audit/order rather than shifting the diary day on timezone conversion. Refine the notebook identity with accessible static/simplified alternatives and add the now-available Diary shell destination.
Exclusions: no photo stories, voice conversations, generated daily questions, embeddings, sync, or old JSON-day model import.
Acceptance: test empty days, multiple entries/day, migration and close/reopen persistence, failed saves/drafts, selected-date navigation, timezone/DST boundaries, deleted entries, long content, large text, and both rendering modes. Profile any newly introduced expensive effects rather than assuming they are smooth.
Finish: update the M08 progress row and Diary feature guide, and append a phase record with exact evidence, limitations, and next phase. Stop after M08.
```

### M09 — Flow

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M09 only.

Prerequisite: M08 is complete.
Scope: implement quick text capture, durable drafts, newest-first thoughts, ID-based reading, editing/deletion, and usable empty/error states. Commit a captured thought before clearing the composer. Add the Flow destination and finish the currently implemented Diary/Notes/Flow/More shell navigation without future-feature placeholders.
Exclusions: no AI reflection UI yet, voice/media capture, semantic search, P2P, collaboration, or cloud sync.
Acceptance: test fast/repeated capture, failed writes, duplicate-submit prevention, ordering with deterministic time/IDs, database migrations, restart/draft recovery, offline behavior, deleted routes, keyboard and large-text layouts, and reduced motion/simpler effects. Run relevant checks.
Finish: update the M09 progress row and feature guide, and append a phase record with verification, limitations, and next phase. Stop after M09.
```

### M10 — Brain

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M10 only.

Prerequisites: M09 and the M03 adapter/findings. Resolve AI-specific acceptance gaps where hardware is available; never relabel missing evidence as verified.
Scope: add Brain settings and persisted capability/model assignments, model install/remove/progress/readiness, sessions/resource lifetime, cancellation, and useful failures using the qualified flutter_edge_ai adapter. Initial capabilities support rewriting, summarizing, and short reflection. Device execution is the only working backend; document how companion/API sources will extend the boundary. Keep model downloads optional and separate from required media.
Exclusions: no floating helper yet, no API-key fields without a provider, companion transport, embeddings, automatic startup model loading, or dummy backend adapters.
Acceptance: use fake-backed routine tests for assignment persistence, missing/corrupt files, interrupted downloads, incompatible capabilities, resource failures, cancellation/disposal, and normal writing without AI. Repeat available native model checks and record exact artifacts/platforms.
Finish: update the M10 progress row and Brain guide, and append a phase record with evidence, remaining hardware gaps, and next phase. Stop after M10.
```

### M11 — Grand Maester

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M11 only.

Prerequisite: M10 is implemented with its evidence/limitations recorded.
Scope: add the Grand Maester floating helper and contextual actions for saved/current text: note rewrite, note/diary summary, and optional short Flow reflection. Connect Brain readiness/setup, streaming, cancel/retry, and explicit proposal review. Summaries/reflections can be viewed/copied without silently editing writing. Replacements require acceptance against the captured source revision and selection; late results cannot affect a different/currently edited record.
Exclusions: no silent AI writes, continuous background inference, third-party fallback, companion execution, voice/vision, semantic retrieval, or legacy branding/artwork.
Acceptance: test contextual availability, no-model setup, streaming/cancel/failure, source edits/deletes, selection changes, screen switching, background lifecycle, rejected/accepted proposals, large text, keyboard/safe areas, and reduced motion. Use synthetic native smoke checks separately from fast tests.
Finish: update the M11 progress row and feature guides, and append a phase record with checks, evidence limits, and next phase. Stop after M11.
```

### UI01 — Onboarding book UI

UI01 and its explicit user corrections are implemented. The current
[book guide](docs/onboarding-ui-migration.md) documents the five original full
spreads, actual folding cover, persisted required name, original view layout,
bottom legal links, selected Grand Maester mascot, Google Fonts caption and
manual interactions. Added visible controls
are removed. Native/device and live hosting evidence remains unverified.

The correction notices in [docs/prompts/ui01-onboarding.md](docs/prompts/ui01-onboarding.md)
supersede its historical crop-only/neutral-cover/no-name and Previous/Next
requirements. Do not revive the rejected layout or expand beyond onboarding and
name. Required downloaded assets are the 12-image `presentation-ui01-v3` pack;
the mascot and paper background are bundled and no font binary is bundled.
The explicitly selected startup follow-up uses that branding and a progress bar.

Further page UI migrations are individually selectable; none are authorized by UI01. M12 audits the resulting mobile app after the selected UI work. The existing M03/M10 hardware and M04 hosting gaps continue to apply.

### M12 — Mobile release preparation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M12 only.

Prerequisite: M01–M11, UI01, and any further explicitly selected mobile UI migration phases; audit actual completion/evidence instead of assuming tracker labels prove readiness. The desktop/website rebuilds are parked and are not prerequisites.
Scope: complete end-to-end startup/writing/AI journeys, accessibility review, representative low-end Android/iOS profiling, asset-pack validation, dependency/dead-code cleanup, release configuration, and available release builds. Verify compatible ABI/minimum-OS settings and absence of obsolete bridges/runtime branding. Configure the production HTTPS asset location only from real provided hosting details; document publishing and fresh-install download verification.
Exclusions: no new product features, hosting purchases, fabricated URLs/device results, store submission, public release, cloud credentials, or signing secrets committed to Git.
Acceptance: fast suite and relevant integration/build checks pass; verify complete offline launches and all core writing without an installed model. Record exact devices/builds/models, performance measurements, licenses, signing/host prerequisites, and any release blockers. Missing external prerequisites leave release readiness partial.
Finish: update the M12 progress row and append a phase record covering release readiness, exact evidence, limitations, and next eligible work. Stop. Do not auto-start parked desktop/website work or deferred product features, and do not publish anything.
```

### Parked desktop and website rebuild prompts

D01–D03 and W01 are retained for reference. The user parked these tracks on 3 November 2026 and will keep using the existing apps. Copying or reading a historical prompt does not remove that scope decision; execution needs the user to explicitly reopen the relevant rebuild.

### D01 — Flutter desktop foundation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D01 only.

Prerequisite: the user has explicitly reopened this parked desktop rebuild and its assumptions have been revalidated; M12 mobile acceptance is recorded. Otherwise do not execute this historical prompt.
Scope: create /Users/lewis/Dev/Projects/The Redkeep/desktop as a Flutter AI companion targeting macOS Apple Silicon and Windows x64. Recheck current runtime/platform requirements, implement model management and capability assignments, and extract proven shared Dart contracts/runtime code now that both apps consume them. Keep independent app composition and lifecycles. Reuse the asset/rendering policy where appropriate without importing the entire mobile application.
Exclusions: no Electron/JS bridge, phone pairing yet, desktop journal editing/sync, API providers, P2P notes, Linux support, or broad speculative package splitting.
Acceptance: test shared packages and both affected apps, verify synthetic local-model execution/cleanup on available supported hardware, and run native builds where supported. Record exact platform floors and unverified Windows/macOS evidence rather than assuming cross-platform Flutter compilation proves runtime behavior.
Finish: update the D01 progress row and desktop/shared-package guides, and append a phase record with commands, evidence, limitations, and next phase. Stop after D01.
```

### D02 — Companion connection

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D02 only.

Prerequisite: the user has explicitly reopened the parked companion connection scope; D01 is complete with model/platform evidence recorded. Otherwise do not execute this historical prompt. Any integration with the retained old desktop instead needs its own selected compatibility plan.
Scope: implement Dart-based phone pairing, authenticated encrypted transport using established primitives, trust revocation, capability/readiness discovery, and versioned AI job requests/results. Add the real companion backend to mobile Brain. Document the protocol and trust lifecycle, use stable job IDs and idempotent handling, and define explicit cancel/timeout/interrupted/reconnect states. A lost connection must not silently replay an accepted source modification or switch execution location.
Exclusions: no JavaScript transport, invented cryptography, P2P note sharing, journal sync, API providers, or public internet relay service.
Acceptance: test protocol compatibility, pairing approval and invalid/expired requests, unauthorized clients, revocation, duplicate jobs/results, cancellation, disconnect/reconnect, app restarts, interrupted jobs, stale source revisions, and unavailable models. Perform a synthetic end-to-end paired-device check where hardware permits; keep fast tests isolated.
Finish: update the D02 progress row and protocol/feature guides, and append a phase record with exact evidence, limitations, and next phase. Stop after D02.
```

### D03 — Desktop release preparation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D03 only.

Prerequisite: the user has explicitly reopened the parked desktop release scope; D02 is implemented and its paired-device evidence is recorded. Otherwise do not execute this historical prompt.
Scope: finish companion model/assignment management, phone connection status/revocation, useful diagnostics without private content or credentials, lifecycle cleanup, packaging configuration, and supported-platform acceptance. Verify packaged runtime/native libraries and model paths, not just debug builds. Record install/update/signing requirements and the production asset configuration.
Exclusions: no desktop writing features, platform expansion, auto-updater service, store submission, signing purchases, public publication, or unrelated product additions.
Acceptance: run affected mobile/shared/desktop checks and synthetic packaged inference/pairing journeys on available macOS Apple Silicon and Windows x64 systems. Verify restart, disconnect, cancellation, reduced motion, and resource cleanup. Missing hardware/signing evidence remains an explicit release limitation.
Finish: update the D03 progress row and append a phase record with packaged artifacts/evidence, limitations, and the next eligible phase. Stop without publishing; W01 follows desktop acceptance.
```

### W01 — Marketing website

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement W01 only.

Prerequisite: the user has explicitly reopened this parked website rebuild and its assumptions have been revalidated. Otherwise do not execute this historical prompt. Inspect actual mobile/desktop release availability; the existing website is retained until this scope is reopened.
Scope: read and follow the applicable Sites skill/workflow, then create the sibling website using React, TypeScript, and Vite. Use the legacy site as a read-only reference for a refined journal/book identity. Implement accurate product pages, accessible static content, progressive decorative book interactions, responsive layout, metadata, and real available download destinations. Honor prefers-reduced-motion and provide simpler presentation. Reuse only selected licensed assets.
Exclusions: no QVAC claims/branding, unimplemented-feature promises, placeholder release links, browser journal app, framework migration, production publication, or analytics/accounts not requested by the user.
Acceptance: TypeScript, lint, relevant behavior/accessibility checks, and production build pass. Verify keyboard/touch use, large text, mobile layout, reduced motion, initial content usability, asset weight, metadata, and download URLs. If releases are unavailable, show honest availability text without fake download buttons.
Finish: update the W01 progress row and website guide, and append a phase record with preview/build evidence, limitations, publishing prerequisites, and next eligible work. Stop without publishing.
```

## 5. Deferred work: separate planning prompts

These prompts authorize research and a decision-complete plan, not runtime implementation. Their displayed order is a backlog, not an instruction to execute all of them. Before choosing a feature, check the current apps, dependencies, and user priorities. Append a new progress row for the selected planning milestone and record its output/gaps. Subsequent implementation requires a selected, scoped implementation prompt.

### P01 — Semantic search and embeddings

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P01 only; do not implement runtime code or install packages.

Prerequisites: inspect the current writing repositories, revisions, keyword search, Brain, and verified device capabilities.
Scope: turn section 3.3 into a decision-complete semantic-search plan using flutter_edge_ai_rag and flutter_edge_ai_sqlite initially. Specify a qualified embedder/profile, chunking contract, separate index ownership, durable transactional work queue, idempotency/reconciliation, edit/delete races, stale-result rejection, rebuild/model-change behavior, lifecycle/resource limits, and optional user controls. Specify synthetic low-end performance/quality benchmarks and evidence thresholds for considering embedded Qdrant.
Acceptance: include interfaces, migrations, phased prompts, tests for crash/reopen/edits/deletes/profile changes, keyword fallback, and an explicit separation between index repair and primary writing. No embedding model loads during ordinary startup.
Finish: save the plan as planning documentation, add/update P01 progress and a phase record with findings/unresolved external prerequisites, and stop. Do not begin indexing implementation.
```

### P02 — Third-party AI providers and secure keys

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P02 only; do not implement providers or make paid API calls.

Prerequisites: inspect current Brain capability/source contracts and model/proposal behavior. Discover existing provider preferences before asking the user for missing product choices.
Scope: select the first provider and supported capabilities, secure platform key storage, user-supplied-key setup/removal, explicit execution-location selection, content disclosure, streaming/cancellation/error handling, and testable adapter contracts. Preserve source-revision checks and prohibit silent transfer/fallback to remote execution. Address endpoint configuration, credential redaction, rate limits, and key persistence/removal without inventing a backend service.
Acceptance: produce scoped prompts, compatibility/migration notes, fake-network tests, and a separate optional live verification procedure that never records keys/private writing.
Finish: save planning documentation, add/update P02 progress and a phase record with decisions/gaps, and stop. Do not add unused API-key fields or adapters.
```

### P03 — Tasks, alarms, and notification destinations

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P03 only; do not install notification packages or schedule notifications.

Prerequisites: inspect current routing/bootstrap, Drift migrations, platforms, and downloaded-media contracts. Clarify the intended task/reminder/alarm behavior where it is not discoverable.
Scope: specify task CRUD/completion, reminder recurrence/timezone/DST behavior, notification permissions, OS alarm/background constraints, rescheduling/reboot recovery, and downloadable-sound feasibility. Select maintained Dart/Flutter packages from current official platform guidance. Define validated versioned payloads resolving to existing app destinations, including cold/warm launches, duplicate taps, startup downloads, deleted targets, and unsupported payloads.
Acceptance: produce scoped implementation prompts, data/permission migrations, deterministic scheduling tests, device acceptance cases, and honest platform limitations. Separate ordinary reminders from exact-alarm behavior and ask only for unresolved material product decisions.
Finish: save the plan, add/update the P03 progress row, append a phase record with decisions/evidence/limitations and next eligible work, and stop before runtime implementation.
```

### P04 — Dart P2P note sharing

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P04 only; do not implement sharing or add transport dependencies.

Prerequisites: inspect current companion protocol, note document/repository boundaries, and platform constraints. Establish whether the desired feature is sending a snapshot or another explicitly requested sharing behavior; do not infer collaboration from sharing.
Scope: evaluate maintained Dart/native alternatives to the old JS P2P library, discovery/connectivity, identity/pairing/trust, transfer/content semantics, offline/network limits, retries, duplicate delivery, cancellation, and recipient persistence/privacy expectations. Reuse proven transport concepts only where the trust model fits; keep journal sync and collaborative edits separate.
Acceptance: provide package/platform evidence, protocol/versioning decisions, scoped implementation prompts, isolated transport tests, device/network scenarios, and clear unsupported cases. Do not revive old People/disappearing-note semantics without explicit product agreement.
Finish: save the plan, add/update P04 progress and its phase record, and stop before sending data or implementing transport.
```

### P05 — Collaborative text CRDTs

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P05 only; do not install a CRDT runtime or change stored documents.

Prerequisites: inspect current document edits, drafts, revisions, persistence, and any approved P2P transport. Resolve collaborative editing intent and supported platforms before selecting a library.
Scope: evaluate maintained Flutter/Dart/native text CRDT candidates, distinguishing text-operation merging from record-level conflict resolution. Specify editor/Unicode/IME/selection compatibility, local durability, document format/migration, actor identity, collaboration membership/permissions, offline edits, deletion/restore semantics, transport independence, and AI-proposal behavior under concurrent edits. Preserve explicit review of generated replacements.
Acceptance: deliver a library qualification spike plan, compatibility risks, scoped implementation prompts, migration/recovery strategy, and convergence/reordering/duplicate/partition/restart tests. Do not claim a CRDT alone supplies networking, authentication, or a migration-free editor.
Finish: save planning documentation, add/update the P05 progress row, append a phase record with findings/gaps and next eligible work, and stop before runtime/schema changes.
```

### P06 — Advanced media and voice

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P06 only; do not add media/voice packages or modify source assets.

Prerequisites: inspect current Notes/Diary/Flow, media catalog, Brain capabilities, raw_assets, and actual platform/device evidence. Choose a bounded first media/voice feature with the user where priorities are unknown.
Scope: distinguish app presentation downloads from user attachments and optional model downloads. Specify capture/import permissions, private file ownership, thumbnails/playback/transcription lifecycle, interruption recovery, storage limits, deletion/references, and reduced-motion/static alternatives. Validate runtime/model support for any voice/vision capability rather than inheriting old preview behavior.
Acceptance: produce scoped prompts, repository/file contracts and migrations, synthetic fixture tests, device checks, accessibility/performance criteria, and honest unsaved-preview versus persisted-content semantics. Keep unrelated media types out of the first implementation.
Finish: save the plan, add/update P06 progress and its phase record with decisions/gaps, and stop before runtime implementation.
```

### P07 — Cloud backup and synchronization

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Plan P07 only; do not sign in, provision cloud resources, or upload writing.

Prerequisites: inspect current primary storage, attachment ownership, document/CRDT state, and existing user provider preferences. Clarify backup/restore versus multi-device synchronization goals before choosing a service.
Scope: specify account binding, supported data and attachment bytes, local-first writes, conflicts, deletion propagation, retry/recovery, restore/import behavior, export format, credentials, and platform limits. Keep rebuildable embeddings separate from authoritative writing; versioned primary data should remain recoverable without a vector index. Do not copy the old primary/secondary-device role scheme unless explicitly required.
Acceptance: deliver provider/package evidence, data/protocol/migration contracts, scoped prompts, fake-service/offline/concurrency/restore tests, and user-visible recovery behavior. Any destructive account reset needs its own deliberate UX, outside a generic sync command.
Finish: save the plan, add/update P07 progress and the phase record with external prerequisites, and stop before runtime/cloud changes.
```

## 6. Acceptance checklist and release prerequisites

### Documentation acceptance

- Every agreed requirement maps to an implementation phase or explicit deferred planning prompt.
- Every prompt includes prerequisites, scope, exclusions or equivalent boundaries, acceptance checks, progress/evidence updates, and a stopping point.
- Main writing storage and rebuildable vector storage have separate ownership and recovery contracts.
- No application implementation is implied by completing this documentation task.

### Required behavior coverage across implementation phases

| Area | Required scenarios |
| --- | --- |
| Bootstrap/assets | First install, complete offline launch, missing keys/files, corrupt/partial files, interruption/retry, disk/network failures, local initialization failures, bounded checks, and splash release. |
| Writing/persistence | Committed saves, failed saves, drafts, reopen recovery, schema upgrades, Unicode/large content, stable IDs, and stale revisions. |
| Navigation | Preserved startup destinations, onboarding, invalid/deleted targets, back behavior, and later validated notification entry points. |
| Presentation | Themes, narrow screens, large text, keyboard/safe areas, live OS/app motion changes, simplified effects, offscreen/inactive cleanup, and bounded media decoding. |
| AI | No-model writing, failed install/load, resource limits, streaming/cancel, cleanup, malformed output, stale/deleted source, and explicit acceptance. |
| Future retrieval | Durable indexing work, crash/restart between stores, edit/delete races, stale-result rejection, profile changes/rebuilds, and keyword fallback. |
| Companion | Pairing/trust/revocation, compatibility, job identity, duplicate messages, cancellation, disconnect/reconnect, and interrupted processes. |

### External prerequisites and explicit defaults

| Item | Default / required evidence |
| --- | --- |
| Legacy data | Fresh start. No importer or old account migration. |
| Mobile support | Android 11+ ARM64 and iOS 15+, revalidated against the qualified engine versions. |
| Desktop support | Rebuild parked on 3 November 2026; existing desktop app retained. Historical macOS Apple Silicon/Windows x64 assumptions need revalidation only if D01 is explicitly reopened. |
| Media hosting | Unselected. A real HTTPS host, published verified pack, and fresh-install download evidence are prerequisites to mobile release. |
| Missing required media offline | Download/retry screen; no automatic basic-writing bypass. |
| AI | Optional on-device model initially. Qualified artifacts and physical-device evidence required; writing remains available without AI. |
| Hardware/performance | Physical low-end Android and iOS evidence required before corresponding claims. Missing devices remain explicit verification gaps. |
| Signing/distribution | Use real available signing configuration without committing secrets. Document missing credentials; do not fabricate successful signed releases. No store submission/publication is authorized by these prompts. |
| Website release links | Use actual available releases. Otherwise show truthful availability text without placeholder download actions. |
| Future services | No paid service setup, cloud provisioning, public publishing, or automatic data transfer is authorized by a research prompt. |

### Primary technical references

These links support the agreed direction. Recheck current APIs/versions during the phase that adopts them.

- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Riverpod testing and provider overrides](https://riverpod.dev/docs/how_to/testing)
- [Drift native database execution](https://drift.simonbinder.eu/platforms/vm/)
- [Drift tests](https://drift.simonbinder.eu/testing/) and [migration verification](https://drift.simonbinder.eu/migrations/tests/)
- [go_router](https://pub.dev/packages/go_router)
- [flutter_native_splash lifecycle](https://pub.dev/packages/flutter_native_splash)
- [Flutter Edge AI installation/platform requirements](https://flutteredge.ai/docs/installation), [models](https://flutteredge.ai/docs/models), and [desktop](https://flutteredge.ai/docs/desktop)
- [SQLite vector provider](https://pub.dev/documentation/flutter_edge_ai_sqlite/latest/) and [embedding profiles/RAG storage](https://flutteredge.ai/docs/embeddings-and-rag)

## 7. Phase records

No application implementation phases have been executed as part of this documentation deliverable. Append phase records here as selected prompts are completed; do not rewrite historical evidence as if it covered later changes.

### 2 November 2026 — M01: Foundations

**Changes and contracts**

- Rechecked the workspace and its ancestors: no applicable `AGENTS.md`, parent
  Git repository, or nested repository existed. Initialized one local repository
  at the workspace root on `main`; no commit, remote configuration, or remote Git
  operation was performed. With no prior Git history, historical user changes
  could not be classified by a diff; pre-existing files were inspected and
  snapshotted before implementation.
- Added root ignore rules, `AGENTS.md`, root/mobile READMEs, and
  `docs/architecture-testing.md`. The existing mobile path, platform ignore rules,
  analyzer configuration, app identity, native configuration, and customized
  launcher assets were preserved. `raw_assets/` remains untouched on disk and is
  explicitly ignored as the user's local work area, outside application bundles.
- Replaced the counter demo with `ProviderScope` → `RedkeepApp` →
  `MaterialApp.router`. A scope-owned Riverpod provider creates and disposes the
  GoRouter. Only `/` is registered; unmatched destinations show a readable
  fallback with a working **Return home** replacement. Production retains
  go_router's platform initial-location behavior. Both pages use immediate
  transitions, safe areas, scrollable content, and bounded content width.
- Added only consumed direct dependencies: `flutter_riverpod` 3.4.3 and
  `go_router` 18.1.2, checked against current official documentation and resolved
  into the application lockfile. Removed unused `cupertino_icons`. Added one
  consumed test helper for fresh scopes and deterministic initial destinations;
  no clocks, IDs, external adapters, or generators are needed by this shell.
- Removed the starter counter test. Six tests cover the real entry point,
  router-provider overrides, initial/subsequent unknown destinations and recovery,
  independent provider scopes, and both pages at 320×480 with 3× text, reduced
  motion, safe-area padding, and simulated keyboard insets. No production writing,
  feature tabs, speculative feature folders, database, AI packages, asset
  downloads, legacy imports, or future apps were introduced.

**Exact checks and results**

All Flutter/Dart commands below ran in
`/Users/lewis/Dev/Projects/The Redkeep/redkeep`; Git commands ran at the workspace
root. Commands exited 0 unless explicitly described as initial inspection.

| Command | Result |
| --- | --- |
| `git rev-parse --show-toplevel` / `git -C redkeep status --short` (initial inspection) | Reported no repository; root and nested `.git` inspection also found none. |
| `command -v flutter` / `command -v dart` / `flutter --version` | `/Users/lewis/develop/flutter/bin/{flutter,dart}`; Flutter 3.47.5 stable, framework `6a19cca564`, engine revision `af7e796e16`, Dart 3.13.4. |
| `dart format --output=none --set-exit-if-changed lib test` (starter baseline) | 2 files checked, 0 changed. |
| `flutter analyze` (starter baseline) | No issues found. |
| `flutter test` (starter baseline) | 1 counter smoke test passed. |
| `git init -b main` | Created the sole repository at the workspace root. |
| `flutter pub get` | Resolved Riverpod 3.4.3 and go_router 18.1.2; removed unused icon dependency; updated lockfile. |
| `dart format lib test` | 9 files formatted; 3 changed during implementation. |
| `flutter pub get --enforce-lockfile` | Passed; lockfile accepted without dependency changes. Pub reported four newer transitive versions incompatible with current constraints; no unrelated upgrades made. |
| `dart format --output=none --set-exit-if-changed lib test` (M01) | 9 files checked, 0 changed. |
| `flutter analyze` (M01) | No issues found. |
| `flutter test` (M01) | All 6 tests passed. |
| `git check-ignore -v raw_assets/ redkeep/build/ redkeep/.dart_tool/ redkeep/android/local.properties .DS_Store` | Confirmed local assets, generated output, local Android configuration, and OS metadata are ignored. |
| `git ls-files --others --exclude-standard` / `git status --short` | Reviewed repository candidates; source, native project files, lockfile, tests, and documentation remain available for the initial commit, without caches or raw assets. |
| `git remote -v` | Empty; no remotes configured. |

Preservation evidence: an inline Python SHA-256 snapshot/compare checked 138
pre-existing files, excluding generated/cache directories. Only the expected
mobile README, pubspec, lockfile, and `lib/main.dart` changed; only the obsolete
counter test was removed. The subsequent migration-plan update is intentional.
All 11 pre-existing files under `raw_assets/` (including OS metadata) and all
snapshotted native/configuration files remain byte-for-byte unchanged. The
temporary snapshot is outside the repository at `/tmp/redkeep-m01-baseline.json`;
it is session evidence, not a required test fixture.

**Limitations and next eligible phase**

Native Android/iOS builds, physical-device launches, platform-link registration,
real keyboard behavior, release signing, and device performance were not verified
in M01. The passing fast suite establishes shell/DI/routing behavior only. No
later-phase or release-readiness claims are made.

M01 acceptance is complete. **M02 — Design and accessibility** is the next
eligible prompt, requiring a separate user-selected phase. M02 was not started.

### 2 November 2026 — M02: Design and accessibility

**Changes and contracts**

- Read the migration plan, root `AGENTS.md`, architecture/testing guide, existing
  shell, tests, and manifests before changes. M01 was recorded complete. The
  repository still has no initial commit and all project material is untracked;
  no commit, remote Git operation, publishing, or later-phase work was performed.
- Added light/dark sheet, ink, accent, and edge tokens with system typography
  roles. Home, fallback, and settings consume shared programmatic paper surfaces.
  Standard paper uses a border and one small shadow; simpler paper removes the
  shadow. A local Material layer preserves control focus/ink feedback.
- Added the implemented `/settings` appearance destination, reachable from home
  with platform back support. System/light/dark theme, additional motion
  reduction, and simpler effects save automatically. Settings distinguish stored
  user intent from effective OS policy and include loading, failed-read retry,
  pending-save, and failed-save feedback. Layout remains scrollable within safe
  areas and the keyboard-resized viewport.
- Introduced the real primary Drift database, schema version **1**, lazily opened
  at application-support `redkeep.sqlite` with managed background execution.
  One constrained appearance row is mapped behind the domain repository. Missing
  preferences read as defaults without seeding a row. Whole-snapshot upserts
  commit before save completion. Future phases extend this database rather than
  replacing it. Initial schema JSON and generated verification helpers are kept
  with source; version 1 has no prior application schema to migrate.
- Scope-owned providers compose the database/repository and dispose resources.
  The isolated controller follows observable committed preferences, blocks
  overlapping saves, retains prior choices on failure, and ignores completion
  after disposal. Widget tests inject a small fake repository and never resolve
  app-owned paths; the former main-entry smoke test now exercises the equivalent
  fresh app-scope composition with this boundary override.
- Added one reactive rendering policy observing both Android `disableAnimations`
  and iOS `reduceMotion`, saved preferences, and lifecycle. OS reduction always
  wins; effective reduction also enables simpler effects. Shared route fades use
  180ms or zero duration and respond to changes in flight. Theme changes are
  immediate. Inactive lifecycle states mute widget-aware tickers, while ancestor
  TickerModes retain offscreen gating. No decorative loop, video, media decoder,
  expensive painter, or speculative device grading was introduced.
- Adopted consumed runtime dependencies `drift` **2.35.3** and `path_provider`
  **2.1.6**, plus `drift_dev` **2.35.2** and `build_runner` **2.17.1** for generation
  and schema verification. The lockfile resolves `sqlite3` **3.5.2** with native
  assets; no obsolete SQLite helper library is needed. Official API/platform
  sources were checked and linked in `docs/appearance-persistence.md`.
  Updated both READMEs and the architecture/testing guide with current contracts,
  recovery behavior, focused suites, and reproducible generation commands.

**Exact checks and results**

Flutter/Dart commands ran in
`/Users/lewis/Dev/Projects/The Redkeep/redkeep` using Flutter **3.47.5** stable
(`6a19cca564`, engine revision `af7e796e16`) and Dart **3.13.4**. Successful final
commands exited 0. The baseline shell suite passed all 6 tests before changes.

| Command | Result |
| --- | --- |
| `flutter pub add drift path_provider` / `flutter pub add --dev drift_dev build_runner` | Added only consumed dependencies and generated a resolved application lockfile. |
| `dart run build_runner build` | Generated database implementation; final regeneration completed successfully without source changes. |
| `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/` | Exported the initial `drift_schema_v1.json`. |
| `mkdir -p test/core/storage/generated` / `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Generated both schema-verification helper files. |
| `dart format lib test` | Formatted implementation and tests during development. |
| `flutter pub get --enforce-lockfile` | Passed without changing the lockfile. Pub reported 11 newer incompatible dependency versions; no unrelated upgrades made. |
| `dart format --output=none --set-exit-if-changed lib test` | 29 files checked, 0 changed. |
| `flutter analyze` | No issues found. |
| `flutter test test/features/appearance/appearance_page_test.dart` | All 8 focused UI tests passed, including a live mid-transition policy change. |
| `flutter test` | All **26** tests passed. |
| `flutter build apk --debug` | Passed; generated `build/app/outputs/flutter-apk/app-debug.apk`. Gradle emitted native-access and Android SDK XML tooling warnings; they did not fail packaging. |
| `flutter devices` | Android 17/API 37 ARM64 emulator (`sdk gphone16k arm64`, `emulator-5554`), development macOS, and Chrome available; no physical mobile target listed. |
| `flutter run -d emulator-5554 --debug --no-resident` | Built, installed, and launched `com.lewiseman.redkeep`; the app used Impeller/OpenGLES and loaded real saved settings successfully. |
| `adb -s emulator-5554 install -r redkeep/build/app/outputs/flutter-apk/app-debug.apk` (from workspace root) | Installed the final debug artifact while retaining the emulator's saved preferences. |
| `adb -s emulator-5554 shell am force-stop com.lewiseman.redkeep` / `adb -s emulator-5554 shell am start -n com.lewiseman.redkeep/.MainActivity` | Full process restart retained dark theme and additional motion reduction. |
| `adb -s emulator-5554 exec-out run-as com.lewiseman.redkeep cat files/redkeep.sqlite > /tmp/redkeep-m02-emulator.sqlite` / `sqlite3 /tmp/redkeep-m02-emulator.sqlite 'SELECT id, theme, reduce_motion, simpler_effects FROM appearance_settings;'` | Saved row was `1\|dark\|1\|0`, matching the visible dark theme, selected motion reduction, and effective flat paper after restart. Only synthetic preferences existed. |
| `adb -s emulator-5554 exec-out screencap -p > /tmp/redkeep-m02-reopened-settings.png` | Inspected light/dark settings and restarted app screenshots visually; controls and status text rendered correctly. Temporary screenshots are outside the repository. |
| `git check-ignore -v raw_assets/ redkeep/build/ redkeep/.dart_tool/` / `git status --short` | Confirmed ignored source assets/build caches and reviewed final repository candidates. |

Coverage includes real background SQLite close/reopen for every theme with
different boolean combinations; repository defaults/streams/singleton isolation;
controller isolation, commit timing, overlapping edits, failed reads/saves,
retry, and disposal; schema snapshot/constraints; all 16 OS/app/lifecycle policy
combinations; both platform flags changing live; tickers stopping/resuming under
inactive/offscreen gates and cleaning up; system/app themes; control and text
contrast; live flat surfaces and route changes; settings at 320×480 with 3× text,
safe padding and a 180px simulated keyboard in both themes; and existing shell
routing/layout regressions.

Implementation checks initially caught constant-initializer/Drift companion
typing issues, a missing parent directory for schema-helper generation, hidden
ListTile ink under a painted surface, and test assumptions about asynchronous
reload and go_router imperative URL reporting. These were corrected before the
final checks above. No test failures remain.

Preservation evidence: a SHA-256 snapshot of 132 pre-existing mobile files was
kept at `/tmp/redkeep-m02-baseline.json`, excluding generated/cache directories.
Only the intended manifests, READMEs, shell/pump tests, shell implementation, and
automatically generated Android plugin registrant changed. All 115 other
snapshotted native files, including configuration and launcher/splash artwork,
remain byte-for-byte unchanged. `raw_assets/` was neither entered nor modified;
legacy projects were not inspected. No new artwork, fonts, models, writing data,
or future-feature routes were bundled or seeded.

**Limitations and next eligible phase**

No iOS build/run, physical-device accessibility or screen-reader check, real
keyboard check, release signing, or performance profiling was performed. The
Android emulator/debug build and host SQLite tests do not establish low-end
physical Android or iOS performance, platform accessibility behavior, or release
readiness. No model, asset/download, or native-splash behavior is claimed. Future
video/timer consumers must explicitly manage their own resources; TickerMode
alone does not stop those external resources.

M02 acceptance is complete within this phase's scope. **M03 — AI feasibility** is
the next ordered eligible prompt; **M04 — Assets and startup** is also eligible
independently under its documented prerequisite/gap rules. Neither was started.

### 2 November 2026 — M03: AI feasibility (Partial)

**Changes and contracts**

- Re-read the plan, root `AGENTS.md`, and architecture/testing guide; no further
  parent/nested guidance was present. M01–M02 were complete. The repository still
  has no commits and all existing project material is untracked, so preservation
  was checked against a fresh SHA-256 baseline rather than a historical diff.
- Verified official package/platform/model documentation and the published
  package source before adding exact `flutter_edge_ai` **2.5.5** and
  `flutter_edge_ai_litertlm` **1.19.1** dependencies. This engine requires core
  ^2.5.5, Flutter ≥3.44 and Dart ≥3.12 <4, compatible with the local baseline.
  Native Assets fetches checksum-verified **native-v0.18.0-h / LiteRT-LM 0.18.0**.
  Added consumed artifact hashing (`crypto`, resolved 3.0.8) and retained the
  reproducible app lockfile. Archive hashes and official references are in
  [AI feasibility](docs/ai-feasibility.md).
- Set Android minimum SDK **30** and restricted native packaging to
  **arm64-v8a**. APK inspection caught that adding ARM64 without clearing
  Flutter's existing ABI defaults retained other libraries; clearing the defaults
  fixed it. The final APK advertises only ARM64 and API 30. Existing iOS **15.0**
  target, Swift Package Manager setup, app identities, native artwork, Gradle,
  Kotlin, and signing configuration are preserved. No Podfile, large-model
  entitlement, network/file-sharing permission, JNI, or JavaScript bridge was
  introduced.
- Added plugin-free local model/session boundaries and an application-owned
  adapter under `features/ai`. Models are explicitly loaded/injected; requests
  are serialized with fresh sessions, native streaming/stop, late-chunk
  suppression, cleanup, and terminal/idempotent close. Failed teardown prevents
  unsafe reuse. Safe errors omit raw native paths/text. The data adapter opts
  into the separately registered LiteRT-LM engine, installs an existing local
  path without activating a global model, and opens `installation.spec` with
  backend fallback disabled. The plugin's internal registry is contained at this
  boundary; no application-owned global service or automatic AI initialization
  was added.
- Added the explicit `tool/verify_ai.dart` alternate entry point, immutable model
  metadata, and an opt-in download/hash script. The harness accesses no writing
  database and uses synthetic prompts only. It records case progress and final
  JSON, selected/actual backend, settings, timings, outputs, and failures. The
  ordinary `main.dart`, providers, database schema, navigation, and production
  presentation are unchanged. No Brain/helper UI, model requirement for startup,
  semantic search, API backend, companion, or later-phase scaffolding exists.
- Added 14 fake-backed tests (40 total app tests), including repeat/session
  isolation, overlap rejection, explicit/subscription cancel, late chunks,
  cancel/close before subscription and during session creation, generation
  failures/retry, poisoned teardown, model-close failure, and invalid requests.
  Updated READMEs/testing guidance and added a feature/recovery/reproduction
  guide. Native runs remain separate from routine tests.

**Tooling and hardware actually available**

- Host: ARM64 macOS 26.6.2; Flutter **3.47.5**, Dart **3.13.4**; Android SDK
  build tools 36.0.0 and platform 37; Android Studio JDK 25.0.2; AGP 9.1.0,
  Kotlin 2.4.0, Java target 17. Both Homebrew and SDK adb binaries are present;
  all device commands below consistently used the Homebrew adb connection.
- Physical Android: **Samsung SM-S928B / Galaxy S24 Ultra**, SoC **SM8650**,
  `arm64-v8a`, **Android 17 / API 37**, build
  **CP2A.260605.016.S928BXXS6EZJ1**, reported MemTotal **11,350,576 KiB**.
  This is flagship hardware, not low-end evidence. Existing phone data was not
  cleared. The attached ARM64 emulator was **sdk gphone16k arm64**, Android 17.
- Apple: **Xcode 27.2 (27B52)**, CocoaPods 1.17.0 available; SPM was used.
  `xctrace`/`simctl` reported no physical iPhone/iPad. The **iPhone 17 Pro iOS
  26.5 (23F77) ARM64 simulator** was available and ran the harness. Doctor warns
  the 27.2 simulator runtime is absent; the installed 26.5 runtime built/ran.

**Pinned model and observed inference**

Ungated **litert-community/Qwen3-0.6B**, file **Qwen3-0.6B.litertlm**, immutable
revision **722a0a54c1301a4b07a9856a9590d56362f0969b**, **613,722,264 bytes**,
SHA-256 **c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108**,
**Apache-2.0**. This is the dynamic INT8 / float KV artifact with the repaired
tokenizer, not the newer dynamic INT4 export requiring LiteRT-LM 0.19 GPU support.
The downloaded bytes and each device's staged file passed hash/size checks.

All retained runs used debug builds, a 2048-token context, 96-token output cap,
temperature 0, top-k 1, top-p 1, seed 42, thinking off, bundle/runtime activation
defaults, no multimodal/tools, and system instruction “Follow the instruction.
Answer briefly.” CPU/GPU were requested explicitly with no backend fallback;
actual backend matched. Timings below are single-run Stopwatch observations,
with existing device load and cache state; they are not sustained benchmarks.

| Run | First load / reload | Arithmetic first chunk / whole request | Cancel to session cleanup | Model close 1 / 2 |
| --- | --- | --- | --- | --- |
| Physical Galaxy CPU (XNNPACK) | 2296 / 397 ms | 1234 / 1883 ms | 72 ms | 88 / 86 ms |
| Physical Galaxy GPU (OpenCL) | 3811 / 3373 ms | 1013 / 1458 ms | 50 ms | 200 / 194 ms |
| iOS 26.5 simulator CPU | 250 / 128 ms | 1180 / 1631 ms | 45 ms | 27 / 19 ms |

Each report has **12 passing cases** and `completed: true`: integrity;
missing/corrupt model failure; load; streaming; cancel after first non-empty
chunk; reuse after cancellation; another independent request; close; reload;
inference after reload; final close. Native Android logs also showed conversation
closure and engine deletion. Reports retain full synthetic prompts/outputs:
[CPU](docs/evidence/m03/android-s24-ultra-cpu.json),
[GPU](docs/evidence/m03/android-s24-ultra-gpu.json),
[simulator](docs/evidence/m03/ios-simulator-cpu.json).

Output limits: arithmetic was correct (`17 + 25 = 42`) but did not obey the
“just the result” format; emoji copying and a tiny one-sentence tree summary
worked. Keyword checks are advisory, not general correctness tests. No broad
rewriting/quality/factuality, long-context, multilingual, sustained thermal,
battery, or OOM claim follows. One post-close CPU process sample reported
**1,297,509 KiB PSS**; a separate GPU sample reported **398,338 KiB PSS**.
These are post-run samples, not peaks or a controlled comparison. Handle cleanup
does not prove immediate return of allocator/cached process memory.

**Commands and results**

Flutter/Python commands ran in `redkeep/` unless noted. Final checks exited 0.

| Command / observation | Result |
| --- | --- |
| `flutter --version`, `flutter doctor -v`, `flutter devices`, `adb devices -l`, `xcode-select -p`, `xcrun xctrace list devices`, `xcrun simctl list devices`, SDK `emulator -list-avds` | Tooling and hardware inventory above; no physical iOS device. The emulator binary is outside PATH, so its full SDK path was used. |
| `flutter pub get --enforce-lockfile` | Passed with exact core/engine pins and retained lockfile. |
| `dart format --output=none --set-exit-if-changed lib test tool` | Passed; 34 Dart files unchanged by final formatting check. |
| `flutter analyze` | Passed, no issues. |
| `flutter test test/features/ai` / `flutter test` | All 14 adapter tests / all 40 app tests passed. No model or native inference called by these tests. |
| `python3 tool/ai/download_model.py /tmp/redkeep-m03-model` | Existing downloaded artifact verified at pinned size/hash; no authentication. Model remains outside repository/bundles. |
| `flutter build apk --debug --target-platform android-arm64 -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json` | Android CPU harness built and ran on physical Galaxy. |
| Same build with `--dart-define=AI_BACKEND=gpu` appended | Android GPU harness built and ran; final ARM64 filter verified and run repeated. |
| `adb -s R5CX530XFAX install -r ...`, `exec-in run-as ... sh -c 'cat > files/m03-verification/Qwen3-0.6B.litertlm' < /tmp/redkeep-m03-model/Qwen3-0.6B.litertlm`, `am force-stop` / `am start -n com.lewiseman.redkeep/.MainActivity` | Installed/staged/launched without clearing app data; complete CPU/GPU reports exported with `exec-out run-as ... cat files/m03-verification/report-<backend>.json`. Full repeatable commands are in the feature guide. |
| `flutter build ios --simulator --debug -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json` | Passed; installed with `xcrun simctl install`, staged under its app support directory, launched with `simctl launch --terminate-running-process`, and exported CPU report. |
| `flutter build ios --no-codesign --debug` | Passed: `build/ios/iphoneos/Runner.app`. Unsigned build only, no physical iOS deployment/signing claim. |
| `flutter build apk --debug --target-platform android-arm64` | Final ordinary app build passed. `aapt dump badging` reports `sdkVersion:'30'` and `native-code: 'arm64-v8a'`. |
| `flutter build ios --simulator --debug` | Final ordinary simulator app build passed; reinstalled and launched. |
| Restore ordinary Android build on Galaxy/emulator; remove only the staged Galaxy model and its three specifically named Qwen cache files | Normal home rendered on both; screenshots inspected. Physical app files contain `redkeep.sqlite` and reports, with staged weights/caches removed. Native app PID log shows Flutter startup without AI initialization. Simulator restored after removing its staged model/identified caches. No database/app data clear used. |
| Root `git check-ignore -v raw_assets/ redkeep/build/ redkeep/.dart_tool/` and baseline comparison | Source assets/caches remain ignored. Of 157 snapshotted mobile files, 151 unchanged; changes are intended Android floor/ABI configuration, generated Android/iOS/macOS plugin registrants, and ignored generated iOS environment files. Other native configuration/artwork and all pre-existing lib/test files unchanged. |

Initial checks exposed the current install API's `InferenceInstallation.spec`
return wrapper, Python 3.9 lacking `hashlib.file_digest`, and the ABI-default
union described above. They were corrected and final checks pass. No unresolved
test/build failure remains. `raw_assets/` and read-only legacy projects were
neither entered nor modified. No remote Git operation, publication, model
bundling, fixture writing, new application route, or later-phase work occurred.

**Acceptance gaps and next eligible phase**

M03 remains **Partial**, with Android physical CPU/GPU inference verified only
for this artifact/configuration/device and iOS CPU inference verified only in
the simulator. **Physical iOS/Metal remains unverified** and blocks iOS AI
release qualification. Android 11/iOS 15 execution, representative low-end
hardware, release signing/optimization, sustained resource/thermal behavior,
and broader output qualification remain unverified; newer-OS builds and widget
tests cannot fill these gaps. They block corresponding compatibility,
performance, and AI release claims, not ordinary writing or non-AI work.

**M04 — Assets and startup** may proceed independently with these gaps recorded.
M10 can later consume this adapter and must revisit available AI device/resource
evidence before release claims. M04 and every later phase remain unstarted.

### 2 November 2026 — M04: Assets and startup

**Changes and contracts**

- Started from clean Git status at `fb2e91f` (`M03 — AI feasibility`). Read the
  root `AGENTS.md`, migration architecture/acceptance, architecture/testing and
  appearance guides, and M03 findings. No additional parent/nested guidance was
  found. M01–M02 are complete; M03 remains Partial with its existing AI release
  restrictions. No remote Git operation, publication or later phase was run.
- Inventoried reachable legacy mobile entry points, book/navigation, Notes,
  Diary, Flow and Appearance image consumers, and the website's actual
  App/Book/BookPages path. Inspected the four raw PNG drafts and listed the six
  unassigned WAVs read-only. Documented first-release candidates, provenance and
  exclusions in [assets and startup](docs/assets-startup.md). Former Journal/AI
  branding, obsolete feature spreads, undocumented media, all unassigned audio,
  videos and models are excluded. Legacy files were read-only references.
- Individually copied only the three documented original generated theme PNGs
  required by the existing Appearance screen into `redkeep/tool/assets/pack/`.
  They are unmodified 384×384 cutouts, **434,116 bytes** total, with stable
  `appearance.theme.{system,light,dark}` keys and `v1` revisions. Preserved source
  notes/prompts and rights provenance in
  [PROVENANCE.md](redkeep/tool/assets/PROVENANCE.md). This project-generated
  provenance label does not purport to grant a third-party artwork license.
  The payloads are controlled local fixtures, excluded from the application
  bundle. Only `assets/catalog/presentation-v1.json` metadata is bundled.
- Added a strict, release-pinned catalog, configurable base location, injected
  resolver/download boundaries and serialized app-support file store. Startup
  compares keys/revisions/hashes/paths/sizes to real files and the installation
  ledger. Suspicious files are hashed; unchanged verified metadata avoids
  redundant hashing. Explicit repair verifies all files. Same-path revision and
  file replacement are tested. Broken/missing ledgers are reconstructed locally.
- Streams go to sibling temporary files, with bounded size, receive deadlines,
  SHA-256 verification, flush/close, rename and a separately committed atomic
  ledger. Completed files survive failure/retry; orphan partials are never
  installed. Rename-before-ledger interruption is locally recoverable. Root,
  directory, target, ledger and temporary symlinks are rejected. The asset
  adapter has no primary-database reference or database deletion/reset path.
  Its only delete removes its own failed pending payload. No schema bump or
  production writing fixture was introduced; Drift remains schema 1.
- Added `flutter_native_splash` **2.4.8** as a runtime dependency after checking
  official lifecycle docs and resolved source/SDK compatibility. Bindings are
  initialized and the splash immediately preserved. The bootstrap coordinator
  checks the existing settings/database and local pack under an aggregate
  **five-second** deadline. Slow retries coalesce; errors/timeouts show Flutter
  recovery UI. Splash release occurs on success, error, timeout or disposal,
  without waiting for a deferred first frame. Downloads start only after release.
  No model or network catalog work runs at startup. M05 owns future onboarding
  state and must add its real check through this coordinator.
- The router retains its destination behind the startup gate. Missing required
  assets, including on a fresh offline launch, block entry. Complete installs
  reopen offline. Download, progress, connection/storage/integrity retry and
  local-check recovery are accessible, scrollable and static under reduced
  motion. Appearance consumes the injected local resolver; decoder/resolve errors
  close the gate and file-image caches are evicted for path replacement.
- Preserved native identity, launcher/splash artwork, storyboards, signing,
  Android ARM64/API 30 and iOS 15 targets. Added main Android INTERNET permission
  for actual downloads and debug-only cleartext capability for controlled
  loopback fixtures. The adapter independently requires explicit debug opt-in;
  release still requires HTTPS. No iOS ATS exception was added. Native splash
  generation was deliberately not run over existing native configuration.
- Added the read-only publishing validator, using the same catalog parser plus
  still-PNG decoding, dimensions, exact inventory, size/hash/provenance and host
  checks. `image` **4.12.0** is a direct development consumer (already splash's
  transitive dependency); official APIs/compatibility were checked. Existing
  lockfile pins were retained; only these consumed dependencies/their transitives
  were added. No former manifests/code were imported.

**Commands and results**

Flutter commands ran in `redkeep/` unless noted. Final checks exited 0.

| Command / check | Evidence |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed with reproducible lockfile. |
| `dart format --output=none --set-exit-if-changed lib test tool` | Passed; 51 Dart files unchanged by final check. |
| `flutter analyze` | Passed, no issues. |
| `flutter test test/features/assets test/app` and `flutter test` | Focused suites passed; final full suite **88 tests** passed. Routine tests use fake transport, fresh containers and disposable storage, with no accounts, network, models or user writing. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Verified `presentation-m04-v1`: 3 decodable still PNGs, 434,116 bytes, exact pinned digests and payload inventory. No publication performed. Negative publisher cases run in the test suite. |
| `flutter build apk --debug --target-platform android-arm64 --dart-define=ASSET_BASE_URL=http://127.0.0.1:8765/ --dart-define=ASSET_ALLOW_LOCAL_FIXTURE=true` | Controlled Android fixture build passed. |
| `python3 -m http.server 8765 --bind 127.0.0.1 --directory tool/assets/pack`; `adb -s emulator-5554 reverse tcp:8765 tcp:8765`; `adb ... install -r build/app/outputs/flutter-apk/app-debug.apk`; `am force-stop` / `am start -n com.lewiseman.redkeep/.MainActivity` | **sdk gphone16k ARM64 emulator, Android 17/API 37**, debug. Fresh required gate rendered after splash; download produced exactly three HTTP 200 GETs, installed files/ledger and reached home. Fixture server was stopped before complete offline restart; home rendered. Removing only `files/required-artwork/appearance/theme-light-v1.png` caused the next launch to gate despite prior saved installation keys. |
| `adb -s emulator-5554 shell uiautomator dump /sdcard/redkeep-m04.xml`; `adb ... exec-out screencap -p` | Readback and screenshots inspected: [fresh gate](docs/evidence/m04/android-fresh-gate.png), [complete offline](docs/evidence/m04/android-complete-offline.png), [missing-file gate](docs/evidence/m04/android-missing-file-gate.png). |
| `flutter build ios --simulator --debug --dart-define=ASSET_BASE_URL=http://127.0.0.1:8765/ --dart-define=ASSET_ALLOW_LOCAL_FIXTURE=true`; `xcrun simctl install booted .../Runner.app`; `simctl launch --terminate-running-process booted com.lewiseman.redkeep` | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77) simulator**, Xcode 27.2, debug. [Fresh gate](docs/evidence/m04/ios-fresh-gate.png) rendered after splash. The UI connector cannot attach to Simulator, so no iOS HTTP-button flow is claimed. |
| Stage only the three exact pack files under simulator app support `required-artwork/appearance/`; restore ordinary build and launch without fixture server | Local verification adopted the files and reached [offline home](docs/evidence/m04/ios-complete-offline-staged.png) with no configured host. This proves local restart/adoption, not an iOS HTTP download. Re-queried the container with `xcrun simctl get_app_container booted com.lewiseman.redkeep data` after reinstall because its UUID changed. |
| `flutter build apk --debug --target-platform android-arm64`; `flutter build ios --simulator --debug` | Final ordinary builds passed (9.0s Gradle / 13.0s Xcode in the last run). Existing JDK native-access warning is informational. Fixture defines are absent. Ordinary app restored on emulator and simulator. No physical-device, signed-release or unsigned iOS-device build is claimed for M04. |
| Native readback SHA-256/size comparison against pinned catalog; primary database digest before/after | All three files match on Android and iOS. Android primary DB remains `3807d2e41251aa1eb7996e2ade7fb3117cefa32af32d08bd98ffbeaec5a233fa`; iOS remains `0e53288d5395375782aae2746258487d19c397f62a1e3e605d59070dc8a825ec`. No data clear, database deletion, private-writing read or settings change was used. |
| Root `git diff --check`, native/raw SHA-256 baseline | Passed. All **11 raw directory files** (four PNGs, six WAVs and `.DS_Store`) unchanged. Of 111 baseline raw/native files, only the two intended Android manifests changed. Native artwork/storyboards/other configuration preserved. |

The final structured evidence is
[verification.json](docs/evidence/m04/verification.json). Tests cover fresh and
complete offline launches, missing files despite ledger keys, corrupt/short/
oversized streams, interruption, orphan pending files, restart/retry, same-path
revision/replacement, malformed catalogs/ledger, traversal and symlinks, storage
and ledger-commit failures, overlong transfers via injected monotonic time,
separate database preservation, splash errors/timeout/disposal, direct routes,
progress and narrow/large-text/inset layouts in both themes. Failure/retry UI is
widget-tested; native download retry and native ENOSPC/process-kill/power-loss
were not exercised. The Android missing file was restored only from the verified
fixture, then locally adopted; completed files were never cleared.

Initial checks caught a settings-retry expectation changed by bootstrap gating,
canonical `/private/var` temp paths, POSIX trailing-slash symlink behavior,
invalid-UTF8 ledger recovery, a relative-path assumption in a publishing
test, and Riverpod automatic async retry delaying a required-file error. Required
asset initialization/resolution now fails immediately; explicit retry refreshes
a failed store initialization. They were corrected; final checks pass. No unresolved failure remains.
The controlled server is stopped and the `adb reverse` mapping removed.

**Catalog/host setup and release prerequisites**

Follow the [asset guide](docs/assets-startup.md#local-fixture-and-host-setup) for
exact local commands and the read-only release validator. Production has **no
host default**. Set `ASSET_BASE_URL` only to the actual verified HTTPS pack base
at build time. Keep stable keys, bump revisions/hashes for changed bytes, prefer
immutable versioned paths, retain provenance, and expand the catalog only as
M05–M11 introduce real first-release consumers from the inventory. A separately
authorized real host, published exact pack, hosted-byte checks and fresh-install
Android/iOS download/offline evidence are mandatory before release. Nothing was
purchased, provisioned or published in M04.

Physical iOS, physical/low-end/minimum-OS accessibility, native disk-full and
power-loss behavior, real HTTP retry on iOS, release timing and signing remain
unverified release qualifications. Widget tests are not physical-device evidence.
Atomic same-directory rename is implemented; directory-fsync power-loss durability
and simultaneous cross-process writers are not claimed. M03's AI evidence gaps
remain unchanged and do not invalidate this independent non-AI phase.

**M04 is complete within its agreed scope. Next eligible phase: M05 — Onboarding
and routing. M05 and every later phase remain unstarted. Stop at this boundary.**


### 2 November 2026 — M05: Onboarding and routing

**Changes and contracts**

- Read the migration plan, root `AGENTS.md`, architecture/testing, assets/startup
  and appearance/persistence guides, and existing implementation before edits.
  M04 is recorded complete; existing M04 work was preserved. No legacy project
  or `raw_assets/` access, remote Git operation, publication or M06 work occurred.
- Added one scrolling, accessible welcome page with live Redkeep copy about
  implemented appearance, accessibility and local artwork behavior. It uses
  system fonts and existing programmatic paper; no new artwork, pack entry,
  dependency, feature tab or future-feature promise was needed.
- Added an injected plugin-free onboarding repository and controller. The same
  primary background Drift database now uses schema **2**, with only a constrained
  singleton `onboarding_completion` marker added. No row means incomplete;
  reads do not seed a row. Completion is idempotent and becomes authoritative
  only after commit. Version 1 → 2 preserves all appearance choices, with both
  snapshots and generated verification helpers retained.
- Added the real onboarding read to the bootstrap coordinator under its existing
  aggregate five-second local deadline, splash lifecycle and coalesced retries.
  Load/timeout failures remain in Flutter startup recovery. Missing required
  artwork still gates entry before onboarding; downloads start after splash
  release. Save failures retain onboarding and the continuation with an actionable
  retry; overlapping completion is blocked and disposed UI ignores late results.
- Replaced the outer startup widget gate with go_router redirects to real
  `/startup` and `/onboarding` screens. A canonical `continue` value carries only
  home, settings or the actual fallback through local checks, timeout, download
  failure/retry, onboarding/save failure and artwork repair. The router stays
  scope-owned and stable while provider listeners refresh readiness.
- Defined the application navigation boundary for currently implemented `/` and
  `/settings`. URI normalization precedes validation. Schemes/authorities,
  unsupported paths, query/fragment input on normal destinations, duplicate/extra
  gate parameters, empty/nested/double-encoded/external continuations and malformed
  encoded text resolve to `/unavailable`. The fallback explains availability and
  replaces itself with home; it never displays raw input/errors. Added no Notes,
  Diary, Flow, Brain, task, authentication, notification or placeholder routes.
- Validated both explicit and Flutter platform initial locations, plus warm
  platform route information. A small forwarding adapter also replaces malformed
  UTF-8 history entries without go_router 18.1.2 re-decoding their invalid old
  query during comparison. Public `validatedNavigationLocation` is the boundary
  for future untrusted strings before calling `go`/`push`.
- Settings is nested under home, giving direct and in-app entry the same real
  back destination. Startup/onboarding have root stacks, allow platform exit and
  disappear from back history on completion. Material pages retain framework
  iOS edge swipes and Android system/predictive back. The central host supplies
  180ms platform transitions while allowed and immediate/stationary presentation
  under OS/app reduction or inactivity, including live reduction. No custom back
  recognizer or interception was introduced.
- Added [onboarding and navigation](docs/onboarding-routing.md) and updated both
  READMEs and current architecture/assets/appearance contracts. Pending intent
  lives in the route URI: the same restored/redelivered URI resumes its validated
  continuation; a new process with no URI starts home after durable completion.
  No separate durable link inbox or OS restoration guarantee is claimed.

**Exact verification and results**

Flutter/Dart commands ran in `redkeep/` with Flutter **3.47.5** (`6a19cca564`,
engine revision `af7e796e16`) and Dart **3.13.4**. Git commands ran at the root.
Final commands exited 0. Structured results and screenshot hashes are in
[verification.json](docs/evidence/m05/verification.json).

| Command | Result |
| --- | --- |
| `dart run build_runner build` | Generated schema-2 database code successfully. An initial invocation from the repository root found no pubspec; reran from `redkeep/` as documented. |
| `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/` | Added `drift_schema_v2.json`; historical version 1 retained. |
| `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Generated version-2 schema helper and updated dispatcher; version-1 helper unchanged. |
| `flutter pub get --enforce-lockfile` | Passed; pubspec and application lockfile unchanged. No dependency added/upgraded. |
| `dart format lib test tool` (during implementation); `dart format --output=none --set-exit-if-changed lib test tool` (final) | Final check: **66 files, 0 changed**. |
| `flutter analyze` | **No issues found**. |
| `flutter test test/app test/features/onboarding test/features/appearance test/core` | Focused implementation check passed all **60** tests at that point. Subsequent malformed-input and platform-initial checks are included in the final full suite. |
| `flutter test --machine > /tmp/redkeep-m05-full.jsonl` | Final suite: **111 tests passed**, terminal `success: true`. No network, account, model or user database used. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Existing pack verified: 3 PNGs, 434,116 bytes. No publication or payload/catalog change. |
| `flutter build apk --debug --target-platform android-arm64` | Passed; final Gradle build 6.9s. Existing JDK native-access warning remains informational. |
| `flutter build ios --simulator --debug` | Passed; final Xcode build 11.7s. No signed device/release build claimed. |
| `flutter devices`; `xcrun simctl list devices booted` | Android ARM64/API 37 emulator and iPhone 17 Pro iOS 26.5 simulator available. Attached Galaxy S24 Ultra was not used for M05. |
| `adb -s emulator-5554 install -r redkeep/build/app/outputs/flutter-apk/app-debug.apk` (root); `adb ... shell am force-stop com.lewiseman.redkeep`; `adb ... shell am start -n com.lewiseman.redkeep/.MainActivity --es route /settings` | Existing M04 pack and saved appearance retained; schema upgraded without clearing data. Requested settings entered [onboarding](docs/evidence/m05/android-onboarding.png). A force-stop before completion and relaunch with the same requested route showed onboarding again. |
| `adb -s emulator-5554 shell uiautomator dump /sdcard/redkeep-m05.xml`; XML readback; `adb ... shell input tap 540 1748`; `adb ... exec-out screencap -p` | Observed **Enter Redkeep** button was tapped. Committed completion opened [requested settings](docs/evidence/m05/android-requested-settings.png) with prior dark/reduce-motion choices and downloaded artwork. |
| `adb -s emulator-5554 shell input keyevent KEYCODE_BACK`; hierarchy/screenshot; force-stop/start without `--es route` | Back returned [home](docs/evidence/m05/android-back-home.png); ordinary [repeated launch](docs/evidence/m05/android-repeated-launch.png) skipped onboarding and opened home. Native back check was a key event, not a predictive gesture. |
| `xcrun simctl install booted redkeep/build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep`; `xcrun simctl io booted screenshot docs/evidence/m05/ios-onboarding.png` | iPhone 17 Pro ARM64 / iOS 26.5 simulator, debug: [onboarding rendered](docs/evidence/m05/ios-onboarding.png) using the existing M04 local pack. Screenshot inspected. No native iOS completion/restart/swipe journey claimed. |
| Root `git diff --check`; SHA-256 comparison with `/tmp/redkeep-m05-baseline.json` | Passed. All snapshotted native configuration/artwork, catalog, tool payloads, pubspec and lockfile remain unchanged. Historical schema helper unchanged. `raw_assets/` was not accessed; no raw-file hash claim is made in M05. |

Tests cover first/repeated launch, background SQLite incomplete/complete reopen,
version-1 migration/data preservation, idempotent completion, delayed commit,
failed reads/saves/retry, overlap/disposal, interruption, all readiness states,
redirect convergence, invalid cold/warm links and malformed UTF-8 platform input,
preserved destinations through checking/download retry/onboarding/repair,
latest/duplicate requests, and platform initial location. Framework iOS edge
swipes cancel/complete in normal and reduced modes; Android back-channel gestures
cancel/commit, with normal system back under reduction. Both themes work at
320×480, 3× text, safe padding and simulated keyboard insets. Existing live
OS/app changes, mid-transition reduction, lifecycle and appearance regressions
also pass.

Initial checks caught a non-const Semantics constructor, a missing test extension
import, an obsolete fade-count assertion, a retry button requiring scroll into
view, cached-theme platform test setup, and the malformed-query comparison issue
above. These were corrected and final checks pass. No unresolved test/build
failure remains.

**Limitations and next eligible phase**

No physical-device accessibility, screen-reader, real-keyboard or gesture
qualification was performed. Widget gesture/channel checks are not physical
Android predictive-back or iOS swipe evidence. iOS native completion/restart,
minimum-OS/low-end hardware, release timing/performance and signing remain
unverified. Native URL registrations/universal links and OS process restoration
were not introduced or qualified. No fixture server, download host, AI model or
primary-database reset was needed for M05 native checks. M04's production HTTPS
host prerequisite and M03's AI qualification gaps remain unchanged.

**M05 is complete within its selected scope. Next eligible phase: M06 — Notes
vertical slice. M06 and every later implementation phase remain unstarted. Stop
at this boundary.**

### 2 November 2026 — M06: Notes vertical slice

**Changes and contracts**

- Read the root instructions, migration plan and architecture, persistence,
  routing and asset guides; confirmed M05 complete and the initial working tree
  clean. Extended the same background `redkeep.sqlite` to schema **3** with
  `notes` and `note_drafts`. Migrations from versions 1 and 2 preserve appearance
  and onboarding; reads seed no writing. Retained historical snapshots/helpers.
- Added immutable domain documents and repository contracts, a Drift adapter,
  Riverpod composition/controllers, and an application-owned plain-text editing
  boundary. Injected secure 128-bit ID generation and time. Notes have stable
  lowercase hex IDs, positive source revisions, full title/body and timestamps.
  Lists select metadata without bodies and render lazily. Unicode is stored
  exactly, with no application body limit or text transformation.
- Added real list/create/read/edit/delete journeys at `/notes`, `/notes/:id` and
  `/notes/:id/edit`; only Notes and Appearance are linked from home. Validated
  IDs/paths cross the existing startup/onboarding continuation boundary. Missing
  and deleted sources show actionable recovery; invalid IDs use the safe shared
  fallback. Nested routes retain home/list/reader back destinations. Parameter
  changes key editor presentation by ID, preventing reuse of another buffer.
- Creation persists a recovery draft before opening the editor. Each change
  queues a serial, coalescing recovery write. Drafts capture the base source
  revision and an AUTOINCREMENT compare-and-swap token; tokens cannot be reused
  after discard/commit. Reopening prefers recovered writing. Notes lists expose
  drafts for both new and existing/deleted sources.
- Manual save first flushes recovery, then checks source revision and draft
  token, writes the note and removes precisely that draft in one transaction.
  Success feedback names the committed revision only after the transaction
  resolves. Failed writes/cleanup and stale sources roll back with the draft
  intact. A changed draft token also preserves the current working buffer for
  explicit **Save a copy** recovery under a new ID. A failed copy commit leaves
  any successfully persisted copy draft available. Original writing is retained.
- Back waits for pending recovery, and recovery failure blocks unsafe back with
  retry/copy guidance. Failed buffers remain in their scope across new platform
  navigation. Explicit draft discard and note deletion each require a concrete
  confirmation and token/revision check. Deletion increments the revision and
  retains full source text/timestamps/deletion time for M07; it never clears an
  outstanding draft. No restore or permanent-delete control is implemented.
- Applied existing paper/theme/rendering policy, selectable reading text, input
  labels, wrapping controls, safe areas and keyboard-resizing scroll views.
  Markdown preview and selected note artwork are explicitly M07 scope, so no new
  media/catalog entry, legacy import, dependency or inactive navigation was added.
  No CRDT, sync, embedding/index queue, attachment, rich-text editor or AI UI.
- Added [Notes writing and recovery](docs/notes-writing.md), updated current
  README/architecture/navigation/persistence contracts, and retained structured
  [verification evidence](docs/evidence/m06/verification.json). `raw_assets/` and
  legacy projects were not accessed. No remote Git operation or publication.

**Exact checks and results**

Flutter/Dart commands ran in `redkeep/`; Git/native install commands ran at the
workspace root. Toolchain: Flutter **3.47.5** (`6a19cca56475`), engine
`af7e796e161a`, Dart **3.13.4**, Xcode **27.2 / 27B52**. Final checks exited 0.

| Command / check | Result |
| --- | --- |
| `dart run build_runner build` | Generated schema-3 database code successfully. |
| `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/` | Added version-3 snapshot; versions 1 and 2 unchanged. |
| `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Added version-3 helper and dispatcher entry; historical helpers unchanged. |
| `flutter pub get --enforce-lockfile` | Passed; pubspec and lockfile unchanged. No dependency added/upgraded. |
| `dart format lib test` (implementation); `dart format --output=none --set-exit-if-changed lib test tool` (final) | Final: **80 files, 0 changed**. |
| `flutter analyze` | Final: **No issues found** (2.8s). |
| `flutter test test/features/notes test/core/storage test/app/navigation_destination_test.dart` | Initial focused verification passed **29 tests**; later navigation/conflict checks are in the final full suite. |
| `flutter test --machine > /tmp/redkeep-m06-full.jsonl` | Final: **139 tests passed**, no errors, terminal `success: true` (6.944s). Tests use fresh scopes, deterministic time/IDs, synthetic writing and disposable databases, without accounts/network/models/user databases. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Existing pack verified: 3 PNGs, 434,116 bytes. No pack/catalog change or publication. |
| `flutter build apk --debug --target-platform android-arm64` | Final ordinary build passed (6.6s Gradle). Existing JDK native-access warning remains informational. |
| `flutter build ios --simulator --debug` | Final ordinary build passed (11.1s Xcode). No device/release/signing claim. |
| `flutter devices`; `xcrun simctl list devices booted` | Android ARM64/API 37 emulator and iPhone 17 Pro iOS 26.5 simulator available. Attached physical Galaxy was not used. |
| `adb -s emulator-5554 install -r redkeep/build/app/outputs/flutter-apk/app-debug.apk` | Installed over M05 without clearing data; saved dark/reduced appearance retained, completed onboarding skipped, empty Notes opened. |
| `adb ... shell cmd connectivity airplane-mode enable`; `adb ... shell svc wifi disable`; `adb ... shell svc data disable` | Offline state read back as airplane **1**, Wi-Fi **0**, mobile data **0** throughout native writing checks. No server, host or AI model used. |
| `adb ... shell am start -n com.lewiseman.redkeep/.MainActivity --es route /notes`; `input tap` at observed UI bounds; `input text 'M06%sOffline%sCheck'` and synthetic body | Created/typed through the actual UI. [Draft kept](docs/evidence/m06/android-offline-draft.png) before manual save; no production fixture loader. |
| `adb ... shell am force-stop com.lewiseman.redkeep`; relaunch `/notes`; observed draft tap | New-note draft survived process termination and [reopened exact text](docs/evidence/m06/android-offline-recovered.png). Manual save showed [committed revision 1](docs/evidence/m06/android-offline-committed.png). |
| Force-stop/relaunch `/notes`; observed saved-note tap | Recovery section became empty; [committed title/body read after reopening](docs/evidence/m06/android-offline-read-reopened.png), with revision 1. |
| UI **Edit note**, type offline; wait for recovery feedback; force-stop/relaunch | [Existing-note recovery from revision 1](docs/evidence/m06/android-offline-edit-draft-reopened.png) and saved revision 1 both remained listed. Opening recovery preserved the exact edited text; manual save showed [revision 2 committed](docs/evidence/m06/android-offline-edit-committed.png). |
| UI **Read committed note → Delete note → Delete**; force-stop/relaunch | [Deleted note excluded after reopening](docs/evidence/m06/android-offline-deleted-reopened.png). Full retained tombstone/draft behavior is also repository-tested. |
| `adb ... shell uiautomator dump /sdcard/redkeep-m06.xml`; XML readback; `adb ... exec-out screencap -p` | Observed controls, exact synthetic text, revision/recovery messages and screenshots; screenshot/build hashes in verification JSON. Native device: **sdk_gphone16k_arm64 / Android 17 / API 37**, emulator, debug. |
| `adb ... shell cmd connectivity airplane-mode disable`; `svc wifi enable`; `svc data enable` | Original emulator state restored and read back: airplane **0**, Wi-Fi **1**, mobile data **1**. Final APK reinstalled and `/notes` reopened; no database reset. |
| `xcrun simctl install booted redkeep/build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep` | Final ordinary build installed/launched on **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator. Existing welcome rendered with local artwork. No native iOS note-writing journey claimed. |
| Root `git diff --check`; `git diff --exit-code -- redkeep/pubspec.yaml redkeep/pubspec.lock redkeep/android redkeep/ios redkeep/macos redkeep/drift_schemas/drift_schema_v1.json redkeep/drift_schemas/drift_schema_v2.json redkeep/test/core/storage/generated/schema_v1.dart redkeep/test/core/storage/generated/schema_v2.dart redkeep/assets redkeep/tool/assets` | Passed. Native configuration, historical schemas/helpers, dependency pins and asset payloads/catalog preserved. No raw-file access/hash claim. |

Tests include fresh schema validation; v1/v2 data preservation and no seeded
notes; create/edit/soft-delete; SQL-triggered note-write and cleanup rollback;
failed recovery/save/copy/retry; commit-gated success feedback; source and draft
revision races, including replacement after save starts; non-reused tokens;
missing/invalid/deleted IDs; deleted-source copy recovery; explicit discard;
pending/failed recovery back navigation; warm platform navigation with failed
in-memory writing; ID switches; and background close/reopen of new/existing
drafts, tombstones and a large multilingual/emoji/combining-character body.
Widget checks read/edit a large document and exercise both themes at 320×480,
3× text, safe padding/keyboard insets, normal and simpler/reduced rendering.
Existing live motion, startup/onboarding, gesture and asset regressions pass.

Initial focused checks exposed widget-test Drift stream cleanup timers and a
duplicate constant-text finder in retry checks; explicit scope teardown/pumping
and selecting the actual retry control fixed these. Static checks also caught
routine braces/context issues. Review identified parameterized editor reuse and
draft-token reuse hazards; ID-keyed views and monotonic draft tokens now have
behavioral regressions. The final suite has no unresolved failure.

**Limitations and next eligible phase**

Recovery writes are asynchronous. If storage cannot accept a write, the latest
buffer remains in memory with an explicit failure message; terminating the
process before successful retry/copy can lose changes newer than the last
durable draft. Native disk-full, power-loss/directory-fsync, real IME/keyboard,
screen-reader, physical-device gestures/accessibility, low-end/minimum-OS and
release/performance/signing qualifications remain unverified. Widget checks are
not physical-device evidence. Native iOS writing/recovery remains unverified;
its build/startup smoke does not substitute for a writing journey. No OS link
registration or process restoration guarantee was added. M04's production HTTPS
host prerequisite and M03's AI hardware gaps remain unchanged.

**M06 is complete within its selected scope. Next eligible phase: M07 — Notes
organization. M07 and every later implementation phase remain unstarted. Stop
at this boundary.**


### 2 November 2026 — M07: Notes organization

**Prerequisites and boundaries.** Read root AGENTS, this migration plan and the
architecture, Notes, asset and persistence guides. M06 was complete; initial
`git status --short` was clean. Implemented M07 only. The current mobile path,
native configuration, earlier schemas and generated historical helpers remain.
No remote Git operation, publication, model work, embeddings, cloud/collaboration,
new media types or replacement navigation/storage framework was introduced.
`raw_assets/` was not accessed. The only legacy inspection was the specifically
selected Notes add artwork and its provenance; one PNG was copied individually.

**Implemented behavior and contracts.**

- Extended the existing primary database to **schema 4**: false-by-default pin
  and normalized note tags, with no fixtures. Source text/revisions/tombstones,
  timestamps, settings, onboarding and recovery tokens survive upgrades from
  versions 1–3. Existing recovery and source compare-and-swap protections remain.
- Keyword tokens are parameterized literal title/body substrings, combined with
  AND alongside tag/pinned-only/Saved-or-Trash filters. ASCII case folds; other
  scripts match exactly. The UI search field accepts 256 UTF-16 code units.
  Pinned-first ordering has deterministic updated-time/ID ties. Queries return
  metadata and lists build lazily; document invalidation observes tokens/tags
  without copying large bodies for every tag. Recovery drafts are explicitly
  separate from saved-note filters. Filter state survives reader navigation in
  the current scope, without a new persistence contract.
- Tags trim/collapse whitespace, lowercase, deduplicate and sort, bounded to 24
  tags of 40 UTF-16 code units. Organization commits atomically with a source
  revision check, preserving exact text. Text commits preserve organization.
  The reader requires existing drafts to be saved/discarded before organizing;
  concurrent stale drafts are retained and can become explicit copies.
- Deletion moves to Trash, preserving text, metadata and recovery. Saved search
  and tag choices exclude Trash; Trash has its own filters. Ordinary deleted-ID
  routes hide the source; the existing reader offers restore/permanent deletion.
  Restore checks/advances revision and retains metadata. **Delete forever**
  requires exact `DELETE` plus **Delete permanently**, and atomically removes
  the trashed source/tags and only the reviewed draft. A changed source/draft or
  failure keeps everything. Old routes remain unavailable. Application deletion
  is not a forensic-erasure guarantee.
- Added **Markdown preview** of committed text and return to complete plain text.
  `flutter_markdown_plus` **1.0.12** renders Flutter widgets, without executable
  HTML/WebView. Image syntax becomes alt-text placeholders, never network/file
  reads. Preview has an explicit complete-plain-text fallback above 32,000 code
  units or 1,000 lines. The application validates absolute credential-free
  HTTP(S) links before injected `url_launcher` **6.3.3** external-application
  launch; blocked schemes, false returns and plugin exceptions have safe feedback.
- Selected documented original generated `notes_add.png` (192×192 transparent,
  45,800 bytes) for the live Create note control, key `notes.add`. It uses the
  existing persistent resolver at 40 logical pixels / 120-pixel decode width.
  Catalog format remains 1; pinned pack is now `presentation-m07-v1`, **4 PNGs /
  479,916 bytes**. Old files keep their exact keys/paths/hashes/revisions. Required
  download/repair behavior and the unconfigured production host remain intact.
- Added textual loading, empty/no-match/error/retry states and reload after
  failed actions. Dialog content AND actions scroll at narrow widths/large text
  with the keyboard present; filters/dialogs add no transition animation. Both
  paper/rendering policies retain the same functionality. Updated the feature
  guide, README, architecture, asset, persistence and routing documentation.

**Dependency/API evidence.** Checked the maintained
[Markdown package documentation](https://pub.dev/packages/flutter_markdown_plus/versions/1.0.12)
and [official url_launcher documentation](https://pub.dev/packages/url_launcher/versions/6.3.3)
before adding exact runtime versions and reproducible lockfile entries. The
launcher supports Android SDK 24+/iOS 13+ and Flutter 3.41/Dart 3.11; existing
app floors Android 30/iOS 15 and Flutter 3.47.5/Dart 3.13.4 satisfy those bounds.
Inspected resolved package builder/link APIs. No native query permission changes
were needed; generated macOS registration gained the actual launcher plugin.

**Verification and evidence.** Full machine-readable results, screenshot and
final build SHA-256 digests are in
[verification.json](docs/evidence/m07/verification.json). Routine tests used fresh
scopes, disposable databases, synthetic writing and injected external boundaries.

| Command / check | Result |
| --- | --- |
| `cd redkeep; dart run build_runner build`; `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/`; `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Generated current Drift code and schema 4 snapshot/helper; historical snapshots/helpers unchanged. |
| `flutter pub get --enforce-lockfile` | Passed with exact new renderer/launcher dependencies; reproducible resolved lockfile. |
| `dart format --output=none --set-exit-if-changed lib test tool` | Passed: **88 files, 0 changed**. |
| `flutter analyze` | **No issues found**. |
| `flutter test` | **155 tests passed**, including 120 keyword/tag/pin/trash combinations, literal SQL/wildcard characters, Unicode, stale metadata/drafts, rollback, background reopen, 2,000-note queries/lazy lists, complete-body editing, malformed Markdown/HTML, blocked/failed links, omitted images, long preview fallback, deleted routes and 120-pixel artwork decoding. Both themes/normal/simpler modes pass at 320×480, 3× text, safe areas and keyboard insets, including Notes organization/deletion dialogs. |
| Fresh schema 4 and upgrades from 1/2/3 | Passed structural validation and preservation, including populated v3 active/trashed sources, exact Unicode text, source revisions and AUTOINCREMENT draft sequence. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | **4 PNGs, 479,916 bytes**, exact payload inventory/provenance/decode validation; no publication. |
| `flutter build apk --debug --target-platform android-arm64 --dart-define=ASSET_BASE_URL=http://127.0.0.1:8765/ --dart-define=ASSET_ALLOW_LOCAL_FIXTURE=true` | Passed; final Gradle run **6.6s**. Explicit debug fixture configuration only; source production default remains unconfigured. |
| `flutter build ios --simulator --debug` | Passed; Xcode **27.2 / 27B52**, **20.0s**. |
| `python3 -m http.server 8765 --bind 127.0.0.1 --directory tool/assets/pack`; `adb -s emulator-5554 reverse tcp:8765 tcp:8765`; `adb ... install -r .../app-debug.apk`; force-stop/start and `uiautomator`/`input` | Existing **sdk gphone16k ARM64, Android 17/API 37**, debug installation gated on the new missing file; server saw exactly **one GET `/notes/add-v1.png` → 200**. Existing appearance/onboarding and M06 tombstone retained without a reset. |
| Android UI synthetic writing/organization/preview | Created and committed a synthetic note, pinned and tagged it (revision 3). [Preview](docs/evidence/m07/android-preview.png) displayed heading/bold and omitted-image text. With airplane mode on, tapping its web link resumed **Chrome IntentDispatcher** via external launcher; no network page-load claim. |
| Stop fixture; `cmd connectivity airplane-mode enable`; `svc wifi disable`; `svc data disable`; force-stop/start | Complete installation opened offline. [Combined filters](docs/evidence/m07/android-offline-filters.png) found the reopened note using keyword `lak`, normalized `travel` tag and pinned-only. [Trashed reader](docs/evidence/m07/android-trash-reader.png) hid the body; [restore](docs/evidence/m07/android-offline-restored.png) retained exact text, tags and pin (revision 5). |
| Android deliberate delete and reopen | Trashed again, [typed `DELETE`](docs/evidence/m07/android-delete-confirmation.png), pressed Delete permanently, force-stopped/reopened offline. New synthetic note absent from Saved and Trash; [older M06 tombstone remains](docs/evidence/m07/android-offline-deleted-reopened.png), proving no collection reset. Network restored to airplane=0, Wi-Fi=1, data=1; reverse mapping removed and fixture server stopped. |
| `xcrun simctl install booted .../Runner.app`; `xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep` | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator: [required gate](docs/evidence/m07/ios-required-artwork-gate.png) detected missing new artwork. Staged only the exact Notes PNG in app support, then relaunched without fixture server; [local verification/adoption reached welcome](docs/evidence/m07/ios-local-pack-adopted.png). This is not an iOS HTTP-download or writing/browser journey claim. |
| Root `git diff --check`; native/historical-schema `git diff --exit-code` | Passed. Native configuration/artwork and historical v1–3 snapshots/helpers unchanged; only expected generated macOS launcher registration changed. `raw_assets/` not accessed; no raw hash claim. |

**Limitations and boundary.** Search/preview bounds are explicit above and in the
feature guide. Host/emulator collection and widget checks do not establish
physical low-end frame/memory performance. Physical-device accessibility/IME,
minimum-OS hardware, native iOS note writing/browser interaction, release/signing,
native full-disk/power-loss/directory-fsync and OS process restoration remain
unverified. Recovery during failed storage writes remains subject to M06's
in-memory limitation. M04's real production HTTPS hosting/publication prerequisite
and M03's AI qualification gaps are unchanged.

**M07 is complete within its selected scope. Next eligible phase: M08 — Diary.
M08 and every later implementation phase remain unstarted. Stop here.**


### M08 — Diary — 2 November 2026

**Status: Complete within the selected text Diary scope.** M07 was complete and
the initial working tree was clean. Read root AGENTS.md, this plan, architecture,
writing/recovery, persistence and routing guidance before changing code. No
legacy project, `raw_assets/`, native configuration, dependency manifest or
lockfile was changed. No later-phase feature or excluded capability was added.

**Behavior and contracts.**

- Added feature-owned immutable civil dates, entries, drafts, metadata and an
  injected repository/clock/ID boundary. The same background database is schema
  **5**, with separate `diary_entries`, `diary_drafts` and `diary_days` tables and
  a date/creation/ID index. Fresh and upgraded writing remains unseeded.
  Populated schema 4 migration retains Notes exact text/audit/revisions, pins,
  tags, tombstones, recovery drafts and AUTOINCREMENT tokens; versions 1–3 also
  retain their existing preservation checks. Historical snapshots are unchanged.
- Diary is now the home experience. Added calendar/month/date routes, previous/
  next dates, today, empty-day reading, multiple entries per day, focused full
  entry reading, manual create/edit/save, confirmed deletion, independent day
  headings and local keyword search. Diary/Notes/Appearance are usable shell
  destinations. Canonical civil dates and stable IDs survive startup/onboarding;
  invalid dates and missing/deleted/wrong-date IDs have safe fallback behavior.
- A diary date stays a Gregorian `YYYY-MM-DD` civil value even across timezone
  travel, DST, repeated hours and skipped local days. UTC audit/order instants
  never derive or move a stored date. Revision checks determine freshness.
- New entry drafts are durable before navigation. Serialized/coalesced recovery,
  captured source/draft tokens, atomic commit/cleanup, explicit commit feedback,
  guarded back, failed in-memory buffer retention, copy and confirmed discard
  protect unfinished text. A failed storage write can still leave newer bytes
  only in memory; process termination can lose those bytes. Day headings use
  revision-checked metadata saves and have no writing recovery draft.
- Diary deletion clears committed title/body and retains an ID/date/audit
  tombstone to reject stale writes. Lists/search hide it; any independent draft
  remains recoverable as a new entry. The dialog explains irreversible committed
  deletion and retained drafts. No Diary trash/restore or forensic-erasure claim.
- Search ANDs literal whitespace-separated title/body substrings, with SQLite
  ASCII folding and a 256-code-unit UI query bound. Queries run locally on the
  database isolate. Lists are lazy/body-free; day cards show up to 12 lines and
  full selectable text remains available unchanged in the focused reader/editor.
- Notebook identity uses existing paper surfaces and a static binding accent,
  removed under simpler effects. Compact calendars have full-date semantics and
  activation actions; narrow/large-text layouts use a date list. Dialog content
  and actions scroll together. No new expensive visual effect, shader, blur,
  page-fold renderer or ticker was introduced, so M08 has no such effect to
  profile. Neither static UI nor host checks establish physical frame performance.
  Updated the [Diary guide](docs/diary-writing.md), READMEs and architecture/
  persistence/routing contracts. No new dependency or presentation asset required.

**Exact verification.** Commands ran from `redkeep/` except root Git/native
commands. Flutter **3.47.5** (`6a19cca564`), engine `af7e796e16`, Dart **3.13.4**;
Xcode **27.2 / 27B52**. Final successful checks exited 0. Machine-readable
commands, observed synthetic text, native control coordinates, limitations and
SHA-256 digests are in [verification.json](docs/evidence/m08/verification.json).

| Command / check | Result |
| --- | --- |
| `dart run build_runner build`; `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/`; `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Passed; current Drift code, schema 5 snapshot and verification helper generated. Historical v1–4 snapshots/helpers unchanged. |
| `flutter pub get --enforce-lockfile` | Passed; existing lockfile and dependencies unchanged. |
| `dart format --output=none --set-exit-if-changed lib test tool` | **108 files, 0 changed**. |
| `flutter analyze` | **No issues found**, final run **3.0s**. |
| `flutter test` | **185 tests passed**, **8s**, no failed tests, exceptions or interaction warnings in final log. Includes 28 Diary tests, populated v4 migration and Diary destination/gate validation. |
| `TZ=America/New_York flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart` | **9 passed**. |
| `TZ=Pacific/Apia flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart` | **9 passed**. |
| `TZ=Pacific/Kiritimati flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart` | **9 passed**. |
| `TZ=Etc/GMT+12 flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart` | **9 passed**. |
| Host persistence/recovery tests | Real background close/reopen preserves 24,000 repetitions of multilingual Unicode text, metadata and unfinished drafts. Source-insert/cleanup trigger failures roll back; stale/deleted-source and replacement-draft saves cannot overwrite writing. Coalescing, delayed commit feedback, failed recovery/commit/copy, retry/copy/discard and scoped failed buffers pass. |
| Widget/date acceptance | Empty/multiple-entry days, metadata independence/conflicts, selected-month/day/today routes, leap/year limits, +14/−12 audit offsets, DST dates/skipped Samoa date, literal keyword combinations, deleted/wrong-date IDs and accessible calendar activation pass. Full 5,000-line Unicode reader/editor remains exact. Calendar/day/search/reader/editor/dialogs pass at 320×480, 3× text, safe padding, 180px keyboard insets, both themes and both rendering modes. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Unchanged `presentation-m07-v1`: **4 PNGs, 479,916 bytes**, no publication. |
| `flutter build apk --debug --target-platform android-arm64` | Passed; final Gradle **7.8s**. No host define required by the existing complete installation. |
| `flutter build ios --simulator --debug` | Passed; final Xcode **11.6s**. |
| `adb -s emulator-5554 install -r redkeep/build/app/outputs/flutter-apk/app-debug.apk`; force-stop/start with `--es route /diary/2024-02-29`; `uiautomator`, observed `input tap/text`, `exec-out screencap -p` | **sdk_gphone16k_arm64, Android 17/API 37**, emulator/debug. Existing M07 installation upgraded without reset; [empty leap day](docs/evidence/m08/android-empty-day.png) rendered correctly with saved dark/simpler preferences. |
| `adb -s emulator-5554 shell cmd connectivity airplane-mode enable`; `svc wifi disable`; `svc data disable`; force-stop/start `/diary`; reopen observed draft | Offline state read back **1/0/0**. UI entered synthetic writing, reported [durable draft](docs/evidence/m08/android-offline-draft.png), and [recovered exact observed writing/date](docs/evidence/m08/android-offline-recovered.png) after force-stop. ADB dropped the first `O` during body input; evidence records actual `ffline words for a leap day.` rather than claiming different text. |
| Native Save entry → Read committed entry; force-stop/start `/diary/search`; observed keyword input/tap | [Commit feedback revision 1](docs/evidence/m08/android-offline-committed.png), [complete reader](docs/evidence/m08/android-offline-reader.png), and [reopened local search result](docs/evidence/m08/android-offline-search-reopened.png) on original **2024-02-29** verified offline. Search input observed as `eap` after ADB's dropped initial character. No server, account or model used. |
| Native Delete entry → Delete committed entry; force-stop/start original date; final APK reinstall/reopen | [Confirmation](docs/evidence/m08/android-delete-confirmation.png) and [empty original day after restart](docs/evidence/m08/android-offline-deleted-reopened.png) verified. [Final build reinstall](docs/evidence/m08/android-final-build-reopened.png) retained date/absence without reset. Original network state restored/read back: airplane **0**, Wi-Fi **1**, mobile data **1**. |
| `xcrun simctl install booted redkeep/build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep`; `xcrun simctl io booted screenshot docs/evidence/m08/ios-simulator-launch.png` | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator: existing local artwork installation reached [welcome](docs/evidence/m08/ios-simulator-launch.png). Final build installed again. No native iOS Diary writing or onboarding-completion claim. |
| `git diff --check`; `git diff --exit-code` over native configuration, manifests/lockfile and v1–4 schema snapshots/helpers (exact paths in JSON) | Passed. No remote Git operation or publication; `raw_assets/` and legacy projects not accessed. |

**Limitations and phase boundary.** Physical-device accessibility/IME,
minimum-OS/low-end hardware, native iOS Diary writing, release/signing and sustained
frame/memory evidence remain unverified. Native full-disk/power-loss/fsync and OS
process restoration are not established. Entry recovery's in-memory storage
failure limitation and search/display bounds are explicit above and in the guide.
M04's real production HTTPS hosting prerequisite and M03's AI qualification gaps
are unchanged. These gaps do not imply physical-device verification from widgets.

**M08 is complete within its selected scope. Next eligible phase: M09 — Flow.
M09 and all later implementation phases remain unstarted. Stop here.**

### M09 — Flow — 2 November 2026

**Status: Complete within the selected text Flow scope.** M08 was complete and
initial Git status was clean. Read root AGENTS.md, the migration plan and the
architecture, persistence, writing/recovery and routing guidance. No legacy
project, `raw_assets/`, native configuration, dependency manifest or lockfile
was changed. M10 and all excluded capabilities remain unimplemented.

**Behavior and contracts.**

- Added immutable feature-owned thoughts, capture/edit drafts, bounded list
  metadata and a repository with injected clock/IDs. Schema **6** extends the
  existing background primary database with `flow_thoughts`, `flow_drafts`, a
  creation/ID order index and a single-capture partial unique index. Fresh Flow
  is empty. Versions 1–5 preserve all prior tables, text, timestamps, metadata,
  tombstones, source revisions and AUTOINCREMENT sequences.
- Quick capture persists/coalesces recovery immediately and restores its single
  composer draft on restart. Atomic revision/token-checked commit and cleanup
  complete before clearing text or showing success. In-flight submission and
  editing are locked; intentional successive captures use separate stable IDs.
  Failed recovery, writes and cleanup retain writing and offer safe retry/copy.
- Added newest-first thought lists, full ID readers/editors, explicit committed
  revision feedback, independent edit drafts, guarded editor back, copy and
  confirmed discard. Lists load only 160-character previews and build lazily;
  complete Unicode text is never truncated in storage/read/edit. Creation UTC
  milliseconds then ID descending determine order; editing does not reorder.
- Confirmed deletion clears committed text and retains a revision/ID/audit
  tombstone to reject resurrection. Independent recovery drafts remain. Missing/
  deleted IDs use useful feature fallbacks; malformed routes use the existing
  global fallback. Flow/More continuations cross startup and onboarding safely.
- A shared normal-route shell provides **Diary / Notes / Flow / More**, with only
  implemented **Appearance** under More. `/settings` and framework back behavior
  remain supported. Labels wrap and expose selected semantics; the bar hides
  during keyboard input. Existing feature viewports keep safe areas/scrolling.
  No new animation, expensive effect, asset or dependency was introduced.
  Updated [Flow guide](docs/flow-writing.md), READMEs and architecture/persistence/
  routing contracts. Existing shell tests now follow More and scroll the reduced
  Notes viewport with settled, hittable controls.

**Exact verification.** Commands ran in `redkeep/` unless root/native paths are
shown. Flutter **3.47.5** (`6a19cca564`), engine `af7e796e16`, Dart **3.13.4**;
Xcode **27.2 / 27B52**. Machine-readable evidence, native control coordinates,
synthetic text and artifact SHA-256 digests are in
[verification.json](docs/evidence/m09/verification.json).

| Command / check | Result |
| --- | --- |
| `dart run build_runner build`; `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/`; `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Passed; schema 6 and generated verification helper retained. Historical v1–5 snapshots/helpers unchanged. |
| `flutter pub get --enforce-lockfile` | Passed; manifest/lockfile unchanged, no new dependencies. |
| `dart format --output=none --set-exit-if-changed lib test tool` | **126 files, 0 changed**. |
| `flutter analyze` | **No issues found**, final **2.9s**. |
| `flutter test test/features/flow test/core/storage test/app` | **67 passed**, **3s**. Includes populated v5 preservation, earlier migrations and gate/ID validation. |
| `flutter test` | **213 passed**, **9s**, no failed tests, exceptions or interaction warnings in final log. Includes **26 Flow tests** and all prior Notes/Diary/Appearance/onboarding/back checks. |
| Capture/recovery/repository checks | 50 rapid edits coalesce; 20 intentional identical-text captures remain distinct; duplicate submissions during delayed writes/commit cannot duplicate or clear early. Failed insert/update/draft cleanup rolls back, stale source/draft tokens cannot overwrite, deleted drafts recover as copies, copy failure retains recovery, and background close/reopen keeps 24,000 repetitions of exact Unicode plus composer/edit drafts. Ordering, 160-character previews and lazy 2,001-thought queries pass. |
| Layout/rendering checks | Composer/reader/editor/confirmations work at **320×480, 3× text, safe areas, 180px keyboard**, both themes and standard/reduced/simpler modes. All four shell controls remain hittable without keyboard at 3× text. Existing Android predictive-back and iOS swipe checks pass in both motion modes. No newly expensive visual effect was introduced; no physical performance claim. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Unchanged **4 PNGs, 479,916 bytes**, no publication. |
| `flutter build apk --debug --target-platform android-arm64` | Passed, Gradle **7.5s**; nonfatal JDK native-access warning. |
| `flutter build ios --simulator --debug` | Passed, Xcode **14.9s**. |
| `adb -s emulator-5554 install -r redkeep/build/app/outputs/flutter-apk/app-debug.apk`; airplane/Wi-Fi/data controls; `am force-stop` / `am start ... --es route /flow`; `uiautomator`, `input`, `exec-out screencap -p` | **sdk_gphone16k_arm64, Android 17/API 37**, existing installation upgraded without reset. Offline state read back **1/0/0**. Empty Flow, exact synthetic draft, force-stop recovery, committed capture/composer clearing, reopened list/reader, offline edit/save and confirmed deletion/reopen verified. Screens and observed controls are recorded in JSON. Original network state restored/read back **0/1/1**. |
| `xcrun simctl install booted redkeep/build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch --terminate-running-process booted com.lewiseman.redkeep`; `xcrun simctl io booted screenshot docs/evidence/m09/ios-simulator-launch.png` | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator reached the existing welcome using locally installed artwork. No native iOS Flow writing claim. |
| Root `git diff --check`; `git diff --exit-code` over native configuration, manifests/lockfile and historical v1–5 snapshots/helpers | Passed. No remote Git operation/publication; legacy projects and `raw_assets/` not accessed. |

**Limitations and boundary.** Newer bytes can remain only in memory if recovery
storage fails; process termination can lose those bytes. Copy/conflict and draft
recovery behavior and bounded list previews are explicit in the feature guide.
Physical-device accessibility/IME, native iOS Flow writing, minimum-OS/low-end
hardware, release/signing/frame/memory performance, native full-disk/power-loss/
fsync and OS process restoration remain unverified. Host/widget/emulator checks
are not physical-device evidence. M04's production HTTPS asset-host prerequisite
and M03's AI qualification gaps remain unchanged.

**M09 is complete within its selected scope. Next eligible phase: M10 — Brain.
M10 and every later implementation phase remain unstarted. Stop here.**

### M10 — Brain — 2–3 November 2026

**Status: Partial for remaining hardware qualification; implementation and all
available checks finished.** M09 was complete and M03's qualified adapter/pin
was retained. Initial Git status was clean. Read root AGENTS.md, architecture,
AI feasibility, startup/routing and persistence contracts. During a pause the
user changed Android release signing and added `.vscode/`; those unrelated
changes were preserved. No native configuration, dependency/lockfile, legacy
project or `raw_assets/` was changed by this phase.

**Behavior and contracts.**

- Added **More → Brain**, canonical `/settings/brain` and validated startup/
  onboarding continuation. Schema **7** of the same background database stores
  capability/model/source assignments with device-only constraints. Fresh Brain
  is unassigned; populated versions 1–6 retain all writing, settings, day metadata,
  draft/source revisions, tombstones and AUTOINCREMENT sequences. Assignment
  feedback follows committed writes; failed saves retain the prior selection.
- The only catalog entry is the exact M03 Apache-2.0 **Qwen3 0.6B INT8** artifact:
  revision `722a0a54c1301a4b07a9856a9590d56362f0969b`, **613,722,264 bytes**,
  SHA-256 `c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108`.
  No weights are bundled/committed. Downloads are optional and independent of
  required artwork/bootstrap. Core **2.5.5** / LiteRT-LM **1.19.1** remain pinned.
- Added injected HTTPS transport with bounded HTTPS-only CDN redirects,
  connection/body/total-transfer limits, progress and cancellation; app-private
  model files use complete-size/hash verification on a worker isolate and
  sibling partial → atomic rename. Missing, interrupted, corrupt and verified
  states are distinct. Partial files never load or become trusted resume points.
  Recheck before every native load detects same-size replacement; retries start
  fresh. Storage/link failures never repair by deleting writing or artwork.
- Model removal waits for resource cancellation, preserves assignments and
  writing, and removes weights/partials plus only precisely matched model-specific
  LiteRT caches. Unknown cache names and plugin registration metadata are retained.
  Assignments may be saved before installation; unknown/incompatible assignments
  cannot execute. File readiness does not establish hardware readiness.
- A lazy device-only executor supports rewriting, summarizing and short
  reflection. Each explicit request verifies files, loads CPU with fallback off,
  validates the active backend, uses a fresh session, streams deltas and releases
  weights before reporting success. Bounds are 1–2,000 input UTF-16 code units,
  2,048 context tokens, 96 output tokens, 16,000 output code units and a 90-second
  cooperative deadline. Character bounds do not guarantee tokenizer fit.
- Cancel, route disposal, inactive/hidden/paused lifecycle and scope disposal
  suppress late output, stop native generation and wait for cleanup. A late
  native load closes without prompting. No automatic resume or startup loading.
  Failed teardown poisons the executor until app restart; load/resource failures
  provide safe memory/device/retry guidance. Deadlines cannot forcibly kill hung
  native code. Allocator/driver memory may remain after successful close.
- Brain's explicit tests use only its displayed synthetic tree paragraph. No
  writing is read/changed and output stays ephemeral. Added the [Brain guide](docs/brain.md),
  updated command/architecture references and documented explicit companion/API
  source migrations and dispatch semantics for their future phases. No floating
  helper, proposal-edit flow, provider/key field, companion transport, embeddings,
  startup model loading, automatic fallback or dummy backend was introduced.

**Exact verification.** Commands ran from `redkeep/` unless root/native paths
are shown. Flutter **3.47.5** (`6a19cca564`), engine `af7e796e16`, Dart **3.13.4**;
Xcode **27.2 / 27B52**. Reports, artifact hashes, native actions, interrupted
attempts and evidence limits are in [verification.json](docs/evidence/m10/verification.json).
All final checks below exited 0.

| Command / check | Result |
| --- | --- |
| `dart run build_runner build`; `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/`; `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/` | Passed; schema 7/current generated code retained. Historical v1–6 snapshots/helpers unchanged. |
| `flutter pub get --enforce-lockfile` | Passed; no dependency or lockfile changes. |
| `dart format --output=none --set-exit-if-changed lib test tool`; `flutter analyze` | **144 files, 0 changed**; **No issues found**. |
| `flutter test` | **266 passed**, final **11s**. Includes **52 Brain tests**, all prior writing/shell tests and populated v6 preservation. No accounts/network/models/user databases used. |
| `flutter test test/features/brain test/features/ai test/core/storage test/app` | **107 passed** before the final additional deterministic download-deadline case; the final full suite includes it. |
| Fake/file/database acceptance | Background assignment close/reopen; delayed/failed saves; missing/same-size corrupt/replaced files; orphan/full-looking partials; short/long/hash/network/redirect/storage/link failures; cancelled stalled transfer; total/decode deadlines; incompatible capabilities; failed native load/create/prompt/stream/stop/session/model close; cancellation during load, scope/route/background disposal and no automatic resume; cache deletion isolation and normal Flow capture with unavailable AI storage all pass. |
| Widget acceptance | Brain, assignment/test controls and removal confirmation work at **320×480, 3× text, safe areas, 180px keyboard**, both themes and standard/reduced/simpler presentation. The entire removal dialog scrolls with its actions; an initial overflow was fixed and final checks pass. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Unchanged **4 PNGs, 479,916 bytes**, no publication. |
| CPU harness: `flutter build apk --debug --target-platform android-arm64 -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json --dart-define=VERIFY_BRAIN=true` | Physical **Galaxy S24 Ultra / SM-S928B**, ARM64, Android 17/API 37: **16/16** checks passed, including three Brain capabilities and cancel-after-first-delta. Exact pin/hash/backend/settings and output in [CPU report](docs/evidence/m10/android-s24-ultra-cpu.json). Brain rewrite/summary/reflection/cancel took **7,881 / 7,664 / 8,638 / 6,842 ms**. |
| GPU harness: same M03 build without `VERIFY_BRAIN`, with `--dart-define=AI_BACKEND=gpu` | Same physical Galaxy: **12/12** M03 streaming/cancel/reuse/reload/missing/corrupt/cleanup checks passed, fallback disabled; [GPU report](docs/evidence/m10/android-s24-ultra-gpu.json). GPU is qualification-only; production Brain selects CPU. |
| `flutter build ios --simulator --debug -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json --dart-define=VERIFY_BRAIN=true`; install/stage/relaunch | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator: **16/16** CPU checks passed; [report](docs/evidence/m10/ios-simulator-cpu.json). Brain rewrite/summary/reflection/cancel **4,854 / 4,987 / 5,146 / 4,065 ms**. Not physical iOS/Metal evidence. |
| `flutter build apk --release --target-platform android-arm64 -t tool/verify_ai.dart --dart-define-from-file=tool/ai/qwen3-0.6b.json --dart-define=VERIFY_BRAIN=true`; separately debug-sign verification copy; `adb -s R5CX530XFAX install -r ...` | Physical Galaxy release-mode CPU: **16/16** passed, including Brain **7,034 / 6,880 / 7,220 / 5,788 ms**. [Release report](docs/evidence/m10/android-s24-ultra-release-cpu.json) explicitly records release mode. Used a separate debug-signed verification APK to retain the installed app's data/certificate; preserved the user's new release signing config. No production signing/distribution claim. |
| `adb ... shell dumpsys meminfo com.lewiseman.redkeep` after harness completion | Single uncontrolled post-close samples: GPU debug **407,097 KiB PSS / 522,540 KiB RSS**; release CPU **1,103,177 KiB PSS / 1,226,720 KiB RSS**. Raw samples retained. Successful native close does not prove return of all memory; neither sample is a peak/sustained benchmark. |
| Ordinary Android Brain, emulator **sdk_gphone16k_arm64 / Android 17/API 37** | Real immutable HTTPS download: cancel → partial absent → explicit retry → observed **239.9 MiB** progress → verified **613,722,264-byte** installed file. [Ready screen](docs/evidence/m10/android-model-ready.png). Interrupted/cancelled partials were not reported installed. This run preceded a user-initiated app-data/build change during the pause; later checks are recorded separately. |
| Current emulator installation; staged only approved presentation files and exact pinned optional model | Saved rewrite assignment; force-stop/reopen showed **Device · Qwen3 0.6B · INT8 · File ready**; model readback SHA-256 matches the pin. Confirmed model removal and restart preserve the assignment while reporting missing weights. Normal writing remains available. Screens/actions and current-installation staging are distinguished from the prior real-download run in JSON. |
| `flutter build apk --debug --target-platform android-arm64`; `flutter build ios --simulator --debug` | Final ordinary app builds passed; installed/restored on physical Galaxy, emulator and iOS simulator without clearing app data. Removed only specifically staged harness weights/known caches. No harness is left as the normal app. |
| `git diff --check`; `git diff --exit-code` over unchanged native iOS/macOS, manifests/lockfile and historical schema files | Passed. The user's unrelated Android signing and `.vscode/` changes remain preserved. No remote Git operation, publication, legacy access or `raw_assets/` change. |

**Limitations and boundary.** Physical iOS/Metal, Android 11/iOS 15 hardware,
low-end devices, sustained release latency/thermal/energy/peak memory, native
OOM/OS-kill recovery and native disk-full/power-loss/fsync remain unverified.
Short high-end release inference closes part of M03's evidence gap; it does not
qualify sustained release behavior or production signing. Reflection invented
emotion absent from the source; bounded output can also truncate. No broad
quality, factuality or safety guarantee follows from functional capability tests.
Hung native calls remain cooperative-cancellation limits. M04's production
HTTPS artwork-host prerequisite is unchanged. These gaps block corresponding
AI release claims and keep the M10 tracker **Partial**, without relabeling
missing evidence as verified.

**M10 implementation and available checks are finished. Next eligible phase:
M11 — Grand Maester, with these limits carried forward. M11 and every later
phase remain unstarted. Stop here.**


### M11 — Grand Maester — 3 November 2026

**Status: Complete within the selected contextual helper scope, with inherited
hardware qualification limits carried forward.** M10's implementation and
available evidence were finished; its Partial label continues to describe the
recorded hardware gaps. Initial Git status was clean. Read root AGENTS.md, the
migration plan and architecture/Brain/writing/recovery guidance. No legacy code
or artwork was used. `raw_assets/`, native configuration, dependency manifests,
lockfile, schema 7 and historical schema/generated helpers remain unchanged.

**Behavior and contracts.**

- Added the floating **Grand Maester** on Notes/Diary readers and editors and
  saved/current Flow, including quick capture. Saved Notes offer summary and
  **Rewrite in editor**; the editor opens current/recovered text without running
  inference. Note editors offer rewrite/summary; Diary offers summary; Flow has
  an explicit optional short reflection. Empty/missing/deleted/wrong-date/stale
  contexts cannot execute. Longer Notes/Diary bodies use a selected passage;
  input is bounded to 1–2,000 UTF-16 code units without silently truncating writing.
- Opening the helper checks Brain assignments/files; ordinary writing never
  creates its controller or initializes AI. Every action/retry is explicit,
  device-only and re-resolves committed assignments. Missing/incompatible models
  lead to **Open Brain**. The existing pinned CPU executor supplies streaming,
  input/output/time bounds and per-request session/model release.
- Streaming is incomplete until successful cleanup and source validation.
  Completed summaries/reflections can be read/copied and cannot edit writing.
  Copy failure retains output. Closing/rejecting discards temporary results.
  A rewrite shows the original captured passage with the generated replacement
  in its scrollable review. **Accept replacement** changes only the Note editor's
  working/recovery buffer; a separate **Save note** commits it.
- Captured provenance includes feature, stable ID, source revision, current body,
  title/editor version and exact selection. Change counters and live guards catch
  edits or selection changes undone before the next frame. Feature adapters
  validate authoritative source and recovery tokens before generation, after
  cleanup and before acceptance. Acceptance checks again after async recovery/
  source reads before replacing the captured range; title/surrounding text remain.
  A later concurrent source change is still rejected by the repository's atomic
  manual-commit check, leaving independent recovery instead of overwriting it.
- Cancel, helper close/reject, route/ID changes, source edits/deletes, selection
  changes, scope disposal and inactive/hidden/paused lifecycle invalidate the
  generation. Late output/load completions cannot publish a proposal or affect
  current writing. No automatic resume. Added executor request-owner checks so
  stale helper/settings cancellation cannot stop a newer caller; explicit model
  removal and executor disposal retain resource-owner global stop authority.
- The source route owns the dialog and subscription, including parent readers
  beneath editors. Immediate dialogs and a tooltip-labelled, non-hero floating
  control work with scrollable actions, safe areas and keyboard insets. Notes/
  Diary preserve keyboard/selection and scroll content reserves bottom space.
  No new animation, artwork, database table, dependency or later-phase route.
  Added [Grand Maester guide](docs/grand-maester.md) and updated Brain, writing,
  architecture and README contracts.

**Exact verification.** Commands ran in `redkeep/` unless root/native paths are
shown. Flutter **3.47.5** (`6a19cca564`), engine `af7e796e16`, Dart **3.13.4**;
Xcode **27.2 / 27B52**. Reports, synthetic text/actions and artifact SHA-256s are
in [verification.json](docs/evidence/m11/verification.json).

| Command / check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Passed; manifests/lockfile unchanged. No dependency added. |
| `dart format --output=none --set-exit-if-changed lib test tool`; `flutter analyze` | **155 files, 0 changed**; **No issues found**. |
| `flutter test test/features/maester`; `flutter test` | **56 contextual/proposal tests**, **322 total**, all passing. Fresh scopes/disposable SQLite and injected files/models; no accounts/network/models/user databases in fast tests. |
| Source/editor/proposal checks | Context restrictions, unassigned/missing/corrupt/interrupted readiness, streaming/cancel/failure/retry/cleanup, new and saved text, source edits/deletes, draft-token replacement, changed/undone selections, same-frame acceptance, source/ID switching, backgrounding and disposal pass. Rejection/generation never write; accepted selected rewrites retain surrounding Unicode/title and require manual commit. A source change after acceptance blocks Save. Copy-only summaries/reflections and copy failure pass. |
| Shared executor ownership checks | A helper encountering a busy executor cannot cancel its owner. Completion while authoritative validation waits, a subsequent request, stale owner cancellation and disposal/backgrounding of previously used Brain settings cannot interrupt the newer caller. |
| Widget/layout checks | **320×480, 3× text, safe padding, 180px keyboard**, both themes and standard/reduced/simpler modes. All review/copy/reject/accept actions remain hittable by scrolling. Long complete Unicode writing is retained; a bounded passage can be accepted without truncating the rest. Existing shell/back/routing/writing suites pass. Initial readiness subscription and disposal-notification failures were corrected before final checks. |
| `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack` | Unchanged **4 PNGs, 479,916 bytes**; no publication. |
| `flutter build apk --debug --target-platform android-arm64 -t tool/verify_maester.dart`; install/stage/relaunch | Physical **Galaxy S24 Ultra / SM-S928B**, ARM64, Android 17/API 37: **10/10** separate synthetic CPU checks. Setup/readiness, rewrite review/reject, accept → independent recovery → manual save, view-only summary/reflection, cancel/source/selection/controller-lifecycle interruption after a delta. [Report](docs/evidence/m11/android-s24-ultra-cpu.json). Only isolated in-memory writing; exact M03/M10 Qwen3 artifact and fallback-off CPU settings retained. |
| `flutter build ios --simulator --debug -t tool/verify_maester.dart`; `xcrun simctl install/launch`; stage exact pin | **iPhone 17 Pro ARM64 / iOS 26.5 (23F77)** simulator: **10/10** same CPU integration checks. [Report](docs/evidence/m11/ios-simulator-cpu.json). Not physical iOS/Metal or native helper touch/OS-lifecycle evidence. |
| Ordinary Android emulator UI: `adb ... install -r`, `input`, `uiautomator`, `exec-out screencap -p`, `am force-stop/start` | **sdk_gphone16k_arm64 / Android 17/API 37**: manually created only `M11 synthetic. Mira planted a tree.` in a new draft. [Helper with actual keyboard open](docs/evidence/m11/android-current-no-model-keyboard.png) showed disabled contextual actions and enabled setup. [Open Brain](docs/evidence/m11/android-open-brain.png) showed retained rewrite assignment/missing weights. Force-stop → Notes → recovery [retained exact writing](docs/evidence/m11/android-recovered-after-setup.png). Explicitly discarded only this synthetic draft afterwards; observed **No unfinished drafts**. No network setting changed or model downloaded for this UI run. |
| `flutter build apk --debug --target-platform android-arm64`; `flutter build ios --simulator --debug`; native `install -r` / `simctl install/launch` | Final ordinary builds passed and were restored on Galaxy, emulator and simulator without clearing app data. Only staged harness weights/precisely pinned runtime caches were removed. Simulator [ordinary welcome](docs/evidence/m11/ios-ordinary-restored.png) restored; no native iOS writing journey claimed. |
| `git diff --check`; `git diff --exit-code -- redkeep/android redkeep/ios redkeep/macos redkeep/pubspec.yaml redkeep/pubspec.lock redkeep/drift_schemas redkeep/lib/core/storage redkeep/test/core/storage/generated` | Passed; no native/configuration/schema/dependency changes, remote Git operation or publication. |

**Evidence limits and phase boundary.** Native harness Diary/Flow cases exercise
capabilities over synthetic text; actual feature UI adapters use isolated widget
checks. Harness lifecycle interruption calls the production controller method,
not the OS background API. Native helper proposal acceptance by touch, actual
OS-background inference, physical accessibility/IME, native iOS writing journeys,
physical iOS/Metal, minimum-OS/low-end phones, sustained release latency/thermal/
energy/peak-memory and native OOM/storage/power-loss/fsync qualification remain
unverified. The small model still invents emotions absent from the source and
can truncate; no broad quality/safety claim follows from functional checks.
Hung native calls cannot be forcibly killed. Accepted bytes can remain only in
memory when recovery storage fails; the existing recovery/copy path applies.
M03/M10 qualification limits and M04's production HTTPS artwork-host prerequisite
remain release concerns and are not relabelled as verified by widget/simulator
checks.

**M11 is complete within its selected scope. Next eligible phase: M12 — Mobile
release preparation, including its explicit completion/evidence audit. M12 and
all later implementation phases remain unstarted. Stop here.**

### 3 November 2026 — Mobile focus and UI01 onboarding planning

**User scope.** After M11, the user parked the desktop and website rebuilds,
chose to retain the existing apps, and selected onboarding as the first mobile
page UI migration before deferred product work. When asked whether to implement
immediately or prepare the prompt/image list first, the user selected **Prepare
prompt and image list first**. This record supersedes the previous automatic
M11 → M12 → desktop/website sequencing; it does not rewrite earlier evidence.

**Documentation delivered.** Added
[UI01: onboarding book prompt and artwork handoff](docs/onboarding-ui-migration.md),
with five relevant chapters, nine proposed PNGs and exact keys/paths/dimensions,
six new text-free image briefs, three reusable neutral texture sources, safe
staging/catalog handoff instructions, accessible rendering/interaction behavior,
and a standalone UI01 implementation prompt. Updated the active roadmap,
progress rows, README and onboarding/asset guides. UI01 implementation remains
**Not started**; M12 follows UI01 and further individually selected mobile UI
work. D01–D03/W01 are **Deferred**, with copied historical prompts guarded against
automatic execution.

**Inspection and verification.** Initial `git status --porcelain=v1` was clean.
Read current migration/architecture/onboarding/asset contracts and the relevant
runtime/tests/validator; inspected only the legacy onboarding widgets and their
artwork records. Read dimensions of the relevant legacy images with `sips`, and
visually inspected the old AI spread to confirm its printed JOURNAL / AI copy.
No legacy file was modified; `raw_assets/` was not accessed.

- `git diff --check` passed.
- Documentation checks verified the nine unique PNG keys/paths, proposed image
  dimensions within current limits, local links/fences, UI01 prompt boundaries,
  parked rebuild rows, and UI01's unstarted implementation status.
- The runtime catalog is still `presentation-m07-v1`, with four images and no
  placeholder onboarding entries. No media was copied/converted/published.
- SHA-256 comparison of all **282 tracked files under `redkeep/`** matched the
  pre-edit aggregate fingerprint
  `2a1eefad3fa11d881cae9f838fb928f0258697776db9be518ecbe4a1bac8fa5a`.
  App source/tests, schema, native configuration, dependencies, catalog and pack
  are unchanged. No Flutter/native tests were rerun for documentation-only work.

**Remaining handoff and stopping point.** The six replacement images need user
handoff outside `raw_assets/`. The three listed neutral legacy textures can be
converted as individual copies during UI01. No startup requirement is added
until real reviewed media and matching pinned metadata are ready. The existing
M04 production-host and M03/M10 device/resource qualification gaps remain.
Next eligible implementation: the linked **UI01** prompt after artwork handoff,
not M12, another page, deferred product features, desktop or website. Stop here.

### 3 November 2026 — UI01 onboarding asset configuration: dummy env.json

**Selected follow-up.** The user requested the asset base URL in `env.json`, a
dummy file, and concrete placement/download instructions, scoped to onboarding.
The user explicitly deferred tests until actual values are supplied. Existing
uncommitted UI01 planning changes were preserved.

**Changes.** Created local ignored `redkeep/env.json` and tracked
`redkeep/env.example.json`, each with dummy
`ASSET_BASE_URL = https://your-asset-host.invalid/redkeep/` and
`ASSET_ALLOW_LOCAL_FIXTURE = false`. The existing compile-time configuration
already consumes these keys through Flutter's
`--dart-define-from-file=env.json`; no dotenv package or runtime loader was added.
The local file is not bundled or uploaded. Existing IDE launch configurations
remain unchanged and do not implicitly load the file.

Created `artwork/onboarding-ready/README.md` as the actual handoff directory and
added [Onboarding assets: env.json and download handoff](docs/onboarding-assets-setup.md).
The guide distinguishes local input, hosted `onboarding/` paths, final pack
files, bundled catalog metadata, and device-installed storage. Updated related
README/asset/UI01 documentation and the progress row. The six new PNGs and three
texture copies remain pending; no dummy image, size, digest, or catalog entry
was fabricated. A fresh installation still needs the existing four media files
at the shared base; an upgraded installation retains valid installed copies.

**Verification intentionally deferred.** Inspected current configuration and
reviewed Git changes only. Per the user's instruction, no tests, analyzers,
validators, builds, app launches, HTTP requests, uploads, or downloads were run.
There is no claim that the dummy URL or download flow has been tested. Dart
runtime code, dependency pins, database/schema, current catalog/pack, native
configuration, legacy sources, and `raw_assets/` were not modified; `raw_assets/`
was not accessed.

**Next handoff and boundary.** The user fills in the actual base URL and provides
the finished PNGs outside `raw_assets/`. Once selected, integrate their real
catalog metadata and hosting layout, then test downloads/repair/offline reopen.
The book UI remains unstarted. No other page, deferred feature, desktop or
website work is included in this configuration-only step. Stop here.

### 3 November 2026 — UI01 Firebase Storage URL handoff

**New source information.** The user provided one Firebase Storage download
link for `redkeep/assets/images/onboarding/diary.webp` in bucket
`mypple.firebasestorage.app`, and stated that the media will be under the assets
folder. The encoded object endpoint and per-object query parameters are not
compatible with treating it as the current generic directory base. The user
has not yet requested download testing; the earlier no-test instruction remains.

**Concrete handoff.** Created ignored `redkeep/onboarding-downloads.local.json`
with the supplied Diary URL and eight empty onboarding URL values, and a tracked
empty `onboarding-downloads.example.json`. Actual token-bearing links are not
copied into tracked examples or documentation. Updated the setup/UI01/handoff
guides and READMEs to retain the real Firebase layout and copy full URLs intact,
rather than reusing one file's token or concatenating paths through the query.
The local list is preparation input, not a runtime-readable feature. The prior
dummy `env.json` remains unchanged as the directory-host fallback template.

**Implementation boundary.** Explicit per-image HTTPS source URLs in the asset
metadata/resolver, preserving Firebase query parameters, still need integration.
The provided WebP example also requires real WebP catalog/publisher support;
the existing PNG-only catalog is not modified and no extension is faked. Stable
runtime keys need not equal remote filenames. Existing required artwork is
preserved; no bucket access rules, Firebase project setup, SDK dependencies,
source assets, profile data, book UI or other features are changed.

**Evidence and limits.** Inspected the local directory resolver, bootstrap
composition, catalog and relevant tests. Read official Firebase download-URL
documentation; that is research, not asset verification. No request was sent
to the user's asset URL, and no tests, validators, analyzers, builds, asset
downloads, uploads, metadata measurements or image edits were performed.
`raw_assets/` and legacy files were not accessed in this follow-up. No download
success or format qualification is claimed.

**Next action.** The user fills the eight remaining complete Firebase download
URLs and supplies/reviews final media. Integrate source URLs, supported formats
and real catalog metadata in a subsequent selected step before testing. Stop
at this onboarding-only handoff; desktop, website and other features stay parked.

### 3 November 2026 — UI01 exact local copies of supplied remote assets

**User scope.** The user filled all nine Firebase URLs and requested permanent
local duplicates for reference/testing, included in the GitHub repository.
Downloading those exact reference copies is explicitly authorized by this new
request; the earlier pause on app/download tests remains in effect. No book UI,
runtime asset pipeline, desktop/website or deferred feature was selected.

**Delivered.** Added `assets/reference/images/onboarding/` with all nine original
downloaded files, preserving remote filenames/extensions and bytes. Added
`assets/reference/manifest.json`, recording stable key, relative path, source
bucket/object identity, byte size, SHA-256 and media type without token-bearing
URLs. Full download URLs remain in the user's ignored local input, unchanged.
The total is **2,520,638 bytes**, comprising seven WebPs and two JPEGs.

Added `tools/sync_asset_references.py`, a standard-library image mirror tool.
The default mode lists the local manifest without reading URLs or contacting
the network. `--download` fetches missing/changed source identities or mismatched
local copies; `--download --refresh` deliberately refetches the supplied sources
after remote replacement. It preserves successful downloads, writes files and
metadata atomically, bounds image transfers, checks actual image signatures,
omits token URLs from diagnostics, and never changes runtime assets or raw work.
No automatic test/startup/CI network hook was added.

Updated root `AGENTS.md` to make the local-copy policy persistent, plus the
reference README, architecture/testing, asset/UI01 guides and READMEs. Future
asset-dependent tests must consume local copies or derived fixtures through
injected boundaries. The reference folder is outside Flutter's bundle; existing
runtime/deployment requirements and the four-image fixture remain unchanged.

**Acquisition and inspection evidence.**

- `python3 tools/sync_asset_references.py --download` completed with **9 recorded
  references, 0 failed inputs**. This was the requested file acquisition, not an
  installed-app download test or app-suite run. Actual response bytes were
  hashed while saving and their PNG/WebP/JPEG signature/extension checked.
- Read dimensions from the nine saved files using `sips -g pixelWidth -g
  pixelHeight`; recorded them in the reference README. Inspected the local
  cover, AI and Appearance images visually. The cover still says Journal, the
  AI spread says JOURNAL / AI, and Appearance mentions fonts. No artwork was
  re-encoded/rebranded or silently approved for the new product.
- `git add -- assets/reference tools/sync_asset_references.py AGENTS.md` placed
  the references, manifest, README, refresh tool and agent policy in the Git
  index. Reviewed staged file statistics; no commit, push or remote Git
  operation was performed. Other pending planning/configuration changes remain
  outside that staging scope.
- No Flutter tests, analyzers, builds, shipping-catalog validator or installed-app
  startup/repair checks were run. No private writing, model, runtime Dart/schema/
  native configuration, source URL values, `raw_assets/` or legacy files were
  changed. `raw_assets/` was not accessed.

**Next boundary.** Assets can now be identified and inspected offline. Review
their approved UI01 content/rebranding, then explicitly select source-URL/
format/catalog integration and book UI work. Mirror acquisition does not make
the new files required at startup or prove their runtime download flow. Stop
after this local-reference task; all other phase boundaries remain in place.

### 3 November 2026 — Current UI01 implementation prompt prepared

**Selected task.** The user requested a prompt for migrating onboarding UI,
not execution. Read current progress, agent/architecture/onboarding/asset guides,
the existing welcome implementation and the local nine-asset manifest. No new
asset fetch, reference refresh, native launch or test was required.

**Delivered.** Added the authoritative standalone prompt at
[docs/prompts/ui01-onboarding.md](docs/prompts/ui01-onboarding.md), with a short
copyable launcher in the onboarding guide. Updated the active UI01 section,
planning row and README links. The old six-new-PNG prerequisite is superseded
by the real local WebP/JPEG handoff. Existing reference files stay unchanged;
the prompt uses neutral book surfaces, live current copy and usable unbranded
illustration regions rather than displaying old product claims or silently
editing the supplied bitmaps. Only actual runtime consumers become required
assets; the original cover can remain reference-only.

The prompt covers the relevant legacy book presentation and manual navigation,
committed completion/continuation preservation, optional-AI messaging, existing
rendering policy, narrow/large-text presentation, Firebase source configuration,
actual image formats and pinned metadata, local-fixture verification, failure/
repair behavior, and a strict UI01 boundary. It identifies the existing four
images' production-source gap without inventing URLs or removing requirements.
Offline implementation checks are specified for when the user selects execution;
live Firebase/native operations remain outside that default verification scope.

**Evidence and stopping point.** Documentation prepared and inspected only. No
application code, asset bytes, runtime catalog, dependency, native configuration,
database, local source URLs, `raw_assets/` or legacy file changed in this step.
No tests, analyzers, validators, builds, downloads or remote Git operations were
run. Existing staged asset-reference work was preserved. UI01 remains **Not
started**. Next action is to copy/select the prepared prompt; stop here.


### 3 November 2026 — UI01: Onboarding book UI and consumed assets

**Selected scope and baseline.** The user selected
`docs/prompts/ui01-onboarding.md` for implementation, superseding the earlier
handoff-only no-test restriction and six-new-PNG prerequisite. Read the agent,
migration, architecture, onboarding and asset guides, current controller/router/
bootstrap/policy/resolver/publisher and tests. Inspected only the requested
legacy onboarding widgets/material renderer as read-only references and the
nine canonical local images. Initial Git status contained staged reference/
agent/sync-tool work, unstaged planning/docs and untracked handoff files. Those
changes were retained; no reset, unstaging, commit or remote Git action occurred.

**Presentation delivered.** Replaced the minimal welcome with Notes → Diary →
Grand Maester → Flow → Appearance. Current headings/descriptions remain live,
scalable Flutter text, including optional on-device help with separately
downloaded models. Added chapter position, Previous/Next, swipe navigation,
manual perspective turns, and a neutral material Redkeep cover. There is no
autoplay or requirement to visit every chapter. **Let's begin** only shows the
cover; **Back to chapters** returns to the chosen chapter. **Enter Redkeep**
uses the unchanged completion controller, disables competing actions while
saving, retains the cover/safe error/**Try again** on failure and permits the
existing validated continuation only after commit.

Used the local spreads only through five explicit, visually inspected source
rectangles recorded in `docs/onboarding-ui-migration.md`. Printed Journal/AI
headers, conflicting left-page copy and font promises are outside every crop.
The original cover remains unchanged/reference-only. Neutral ink, page-edge and
cloth textures plus Flutter paper/case/border/title/ornament primitives provide
the book composition. No replacement art, bitmap text, name input or future
feature claim was added. Removed the superseded welcome body; no legacy renderer
or dependencies were imported.

The rendering policy permits motion only when active, visible and using full
effects. Reduced/simpler modes settle immediately with static flat presentation.
Live app/OS reduction, inactivity/offscreen and disposal settle/stop the turn.
Safe scrolling and a single column handle narrow widths, landscape, large text,
safe areas and keyboard constraints; a portrait tablet can show facing pages.
Ivory pages use dark ink in both themes. Functional semantics/focus follow the
live reading order; decorative art is excluded. Artwork resolves only for the
visible face/current outgoing neighbor, with quantized bounded decode sizes,
repaint boundaries and eviction on departure/repair, not an all-image precache.

**Asset boundary delivered.** Advanced the pinned pack to
`presentation-ui01-v1`: four untouched PNG rows/payloads plus eight exact copies
from the manifest, **12 images / 2,665,540 bytes** (4 PNG, 6 WebP, 2 JPEG).
All nine reference images and the token-free manifest remain unchanged. The
reference-only original cover is not a required download. The runtime parser,
publisher and persistent resolver now accept real PNG/WebP/JPEG and share still
format/extension, pre-allocation dimension (≤2048×2048) and real decode
qualification. Retained byte limits, SHA-256, safe paths, symlink rejection,
sequential transfers, same-directory atomic install, repair/retry and ledger
stat verification. Verification decodes cold/suspicious files off the UI isolate;
an image-verification ledger version safely requalifies existing installations.
Pending files preserve their actual extension. The already resolved `image`
4.12.0 package was promoted to a pinned runtime dependency; no package version
or other lockfile resolution changed. Public installed APIs and the official
package/Flutter sources were checked; no mutable decoder-global policy was used.

Added complete per-image HTTPS source overrides while preserving query strings
and encoded Firebase object names; safe catalog paths remain separate. Missing
overrides still use the existing directory base. Added the explicit offline
`tool/prepare_asset_sources.dart` command, which filters unused cover input,
validates catalog keys/URLs and atomically serializes the map as the string
`ASSET_SOURCE_URLS_JSON` define into ignored `env.json`. Ran it for the eight
supplied consumed sources, verifying that the existing directory fallback and
all unrelated entries were preserved. The full original input list is unchanged.
No real URL/token was written to tracked files or logs; interrupted env pending
output is ignored. The app reads compile-time defines, never repository files.

**Verification, from `redkeep/`.**

- `flutter pub get --enforce-lockfile --offline` — passed against installed
  packages; exact versions retained.
- `dart format --output=none --set-exit-if-changed lib test tool` — passed,
  163 files checked with no remaining formatting changes.
- `flutter analyze` — passed, no issues.
- `flutter test --reporter expanded` — **346 tests passed**. Focused development
  runs also passed for onboarding, assets and the Brain continuation consumer.
  New checks cover manual boundaries/buttons/swipes/canceled drag/no autoplay,
  skipped tour/cover/back/repeated taps, save/retry/commit timing, cover
  interruption/relaunch, completed bypass, continuation/repair, actual local
  decodes, bounded image providers and semantic copy. Layout/policy coverage
  includes both themes, 320px/3×, landscape, safe areas/keyboard, facing pages,
  normal/reduced/simpler modes, live app/OS reduction, inactivity/offscreen and
  ticker disposal. Real-reference file tests cover format mismatch, malformed/
  animated/oversized media, atomic WebP/JPEG install, corruption/repair/offline
  reopen and an M07→UI01 upgrade that transfers only the eight missing files
  while retaining the four existing payloads and a writing/settings sentinel.
  Existing schema-7, persistence, back/navigation and writing suites also pass.
- `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack`
  — passed: `Verified presentation-ui01-v1: 12 images (PNG/WebP/JPEG), 2665540 bytes.`
  No publication performed.
- `dart run tool/prepare_asset_sources.dart onboarding-downloads.local.json env.json`
  — prepared **8** consumed sources with no requests; all unrelated configuration
  values compared equal before/after. Tests additionally prove failure leaves
  the previous env intact and source queries stay complete.
- SHA-256/size verification against the local manifest — all **9** originals
  match; comparison with `HEAD` — all **4** old catalog entries identical.
  `git diff --check` — passed.
- Used a temporary offline widget capture with injected local resolver and
  locally loaded SDK Roboto for legible visual review; inspected all five
  chapter crops, cover, portrait spread and dark presentation. Retained four
  representative widget PNGs and a machine-readable record under
  `docs/evidence/ui01/`. Removed the temporary capture helper and other temporary
  repository work. These are widget renders, not native-device evidence.

**Preserved contracts and honest limits.** The completion controller/repository,
router destinations/continuations, bootstrap/splash ownership, schema 7,
writing/settings and native/signing configuration are unchanged. No user
writing/database was opened or reset. No raw work directory access, legacy
writes, model/AI initialization, native build, device install/smoke, live Firebase
request/reference refresh, upload, publication or remote Git operation occurred.
The authorized tests are fully offline and use fresh scopes/disposable files.

The existing four required PNGs still have no supplied usable production URLs;
the preserved dummy directory fallback does not solve that gap. Their source
locations or a real HTTPS directory host are the specific remaining hosting
input. Even the supplied onboarding URLs have not been live-verified by UI01.
Fresh production download, native interruption/repair/storage-failure drills,
physical accessibility/gestures, release frame/memory/energy, low-end/minimum-OS
and actual iOS hardware evidence remain unverified. Public redistribution rights
for project-supplied originals remain an M12 audit input, not inferred from
Firebase hosting. Existing M03/M10 AI hardware limits remain. None of those
unverified release claims is marked accepted by the offline UI01 result.

**Stopping point.** UI01 implementation and its selected offline checks are
complete. M12 is the next eligible mobile audit only after separate user
selection; any further page UI also needs its own selection. No M12, deferred
feature, desktop/website work or publication was started.

### 3 November 2026 — UI01 follow-up: remaining artwork source URLs supplied

**Selected scope.** The user supplied complete Firebase URLs for the three
existing theme icons and Notes add icon to resolve the known source-configuration
gap. Integrated those four values into ignored
`redkeep/onboarding-downloads.local.json` under `appearance.theme.system`,
`appearance.theme.light`, `appearance.theme.dark` and `notes.add`. Preserved all
nine preceding input values, including the reference-only cover, and the user's
existing launcher changes. Tokens remain solely in ignored input/build config.

**Delivered and checks.** Ran
`dart run tool/prepare_asset_sources.dart onboarding-downloads.local.json env.json`
from `redkeep/`: **12 cataloged sources prepared, no requests performed**.
Compared the generated map against the supplied values and catalog: every
required key has an explicit HTTPS source with its original full query, and the
unused cover is excluded. Compared all unrelated env values, including the
directory fallback, before/after: unchanged. No required image now selects the
placeholder fallback when this configuration is compiled into the app. Updated
the blank source example, current setup/feature guides, progress row and evidence
to distinguish provided sources from verified live downloads.

`flutter test test/features/assets/asset_source_configuration_test.dart` passed
(2 tests); local pinned-pack validation passed (12 images / 2,665,540 bytes).
`git diff --check` passed. A scan confirmed supplied URLs/tokens do not appear in
Git-visible text files. Catalog entries, payload/reference bytes, completion,
writing/schema and native/signing configuration are unchanged.

**Limits and stopping point.** No live Firebase request, reference refresh,
native rebuild/install/relaunch, upload, remote Git operation or later phase was
performed. Live endpoint status and remote bytes still need separate evidence.
The current app must be fully stopped and rerun with
`--dart-define-from-file=env.json`; hot reload does not compile new values. After
startup successfully verifies every required file, an incomplete user reaches
onboarding. Stop at this configuration follow-up; M12 remains separately selected.

### 3 November 2026 — UI01 correction: legacy visual parity and persisted name

This iteration's added controls, wordmark and substituted caption typography
are superseded by the subsequent exact-layout correction below. Its schema,
name and verified-asset contracts remain current.

**Explicit scope change.** The user rejected the cropped-card/neutral-cover
result, requested the original onboarding visuals (copy the selected renderer
as-is if optimization would change them), and required the user's name. The user
then confirmed **just onboarding and name for now**. This supersedes UI01's
initial restrictions on full printed artwork, copying the book renderer, name
persistence and schema changes. No other feature or phase is selected.

**Delivered.** Adapted the specific legacy paper/fold/material/book renderer
into the feature: full 4:3 illustrated spreads, curved leaves, page blocks,
stitched binding, 64-band bending pages, stationary case, perspective/shadows,
folding original lavender cover and the original-style lavender action. Retained
five implemented chapters with manual buttons/taps/finger-following swipes and
canceled-turn recovery; no autoplay or
unavailable route was added. The ordinary presentation uses the exact supplied
original artwork; constrained/large-text views add live current descriptions
and an unconstrained name field. The external wordmark remains Redkeep rather
than adding an unprovided old mascot/font asset. Original printed Journal/AI
artwork is retained under the user's visual instruction.

**Name contract.** Schema 8 adds nullable `name` to the existing completion row.
The repository normalizes/validates and commits it atomically; the controller
unlocks the existing validated continuation only after that commit. System back dismisses input focus and reopens the book before tour/root exit. Blank input
cannot save; failure retains the typed name/cover and safe retry. A user with no
saved name now sees onboarding, including an older completion-only row. No fake
name is backfilled; migration preserves the row, every writing/recovery table,
settings and tokens. Committed Unicode names survive background database
close/reopen. Generated code, the v8 snapshot and migration helpers are retained.

**Optimizations.** Both leaves share bounded file-image providers;
only current/turning-adjacent artwork resolves. Only the selected cover warms on
Begin, and its decode size stays stable through folding/keyboard changes. No
all-chapter precache was restored. Texture streams own/dispose handles and
cached/asynchronous errors use repair. Final cover camera settles to identity
for stable editable text/caret composition. Reduced/simpler/live/inactive/
offscreen modes settle promptly and simple presentation removes expensive
perspective/bends/shadows. No physical performance improvement is claimed.

**Artwork/configuration.** Added the exact already-local cover to the pinned
`presentation-ui01-v2` pack: now **13 images / 3,000,554 bytes**. The four original
PNG rows/payloads and all nine reference bytes/manifest remain unchanged. The
original cover's source URL was already supplied; preparation now includes all
13 catalog consumers while preserving prior URLs, queries, fallback and unrelated
env settings. No token appears in tracked files. No new artwork, remote URL,
font/model dependency or bundled presentation fallback was introduced.

**Commands/evidence, from `redkeep/`.**

- `dart run build_runner build` — passed; regenerated current Drift adapter.
- `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/`
  and `dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/`
  — passed; v8 snapshot/helper added, historical versions retained.
- `dart format --output=none --set-exit-if-changed lib test tool` and
  `flutter analyze` — passed; no remaining formatting/analyzer issues.
- `flutter test --reporter expanded` — **355 tests passed**. New/updated coverage
  includes original spread geometry, manual navigation/cover/name input,
  blank/trimmed Unicode names, duplicate/failed/retry/commit timing, real failed
  SQLite writes, close/reopen, migrations 1–7 with writing/settings preservation,
  missing-name gating, continuation/interruption, current/adjacent decode bounds,
  cover/texture decoder repair, both themes, narrow/3×/landscape/safe/keyboard,
  live reduction while turning/folding, simpler/inactive/offscreen and disposal.
- Local pack validator — passed for `presentation-ui01-v2`, 13 actual still
  PNG/WebP/JPEG images, 3,000,554 bytes. No publication performed.
- Source preparation — **13** supplied catalog URLs prepared with no requests;
  prior 12 source values and unrelated env values compared unchanged.
- Manifest size/SHA-256 check — all nine references match. The first four
  catalog rows still equal their original `HEAD` rows. `git diff --check` and
  supplied-token scan passed.
- Temporary offline widget captures reviewed the full spreads, folding original
  cover, name entry, portrait tablet and simpler presentation. Current artifacts
  and a machine-readable record are under `docs/evidence/ui01/revision/`.
  The capture helper was removed; original cropped-card evidence remains
  historical. These are widget renders with locally loaded preview fonts, not
  physical/native or pixel-identical font/logo evidence.

**Preservation and limits.** Existing staged/unstaged work and user launcher/URL
changes were preserved. No raw-work directory access, legacy write, remote Git,
publication, live Firebase request, reference refresh, model initialization,
native build/install/smoke or actual user database access occurred. A full app
stop/restart with the env define file is required for schema/catalog/defines.
Startup still verifies required artwork before the name gate; a complete local
pack and saved name reopen offline. Physical accessibility/gestures, low-end/
minimum-OS/release frame/resource evidence, remote-byte agreement and public
redistribution rights remain unverified.

**Boundary.** Onboarding and name are complete within the authorized offline
scope. No additional old-app feature, other page UI, M12, desktop/website or
deferred feature was implemented. M12 remains separately selectable.

### 3 November 2026 — UI01 correction: original layout and bottom legal links

The latest resource choice below supersedes this iteration's original J mascot
and bundled Allura binary; its layout, footer and name behavior remain current.

**Selected task.** The user required the same legacy visual screen, identified
its missing bottom Terms of Service footer and rejected the added Previous/Next
buttons. Scope remains **onboarding and name only**. This supersedes conflicting
historical prompt requirements and the prior wordmark/extra-control revision.

**Delivered.** Retained the original onboarding view composition directly,
including its mascot, page dots, tap/swipe hint, lavender primary action, exact
ink/spacing, original Allura caption and bottom inline Terms/Privacy policy
footer. Removed visible Previous/Next, numeric counter and Back buttons. The
single visible primary action is **Let's begin**, then **Save** on the original
name-entry cover; **Save** also retries a failed committed-name write. Keyboard
arrows, semantic chapter actions, page taps/swipes and system back/Escape retain
access without extra visible controls. The settled cover uses its original
camera transform. Safe areas, keyboard footer hiding, reduced/simpler effects,
large-text scrolling and repair/navigation/name persistence remain intact.

The restored inline links use the original
`https://journal.lewiseman.com/terms.html` and
`https://journal.lewiseman.com/privacy.html` destinations through an injected
external launcher. False/throwing launches show the original safe message;
late results after disposal are ignored. Tests invoke injected launchers only.

**Resources and preservation.** The exact 64,238-byte legacy mascot and the exact
109,228-byte Allura font have separate bundled copies and indexed local
references. Allura was acquired once from the public pinned Google Fonts source
identified by the legacy font mapping; its unmodified OFL notice is retained
and registered with Flutter. This narrow fixed-resource exception avoids new
runtime downloads or unprovided Firebase URLs. No font package/dependency was
added. The original nine manifest rows/image bytes, 13-image catalog/pack and
13 supplied source values stay unchanged. Unrelated staged/unstaged edits,
launcher/env values, native/signing files and writing/settings were preserved.
Legacy sources were read-only; `raw_assets/` was not accessed.

**Verification.** From `redkeep/`:

- `flutter pub get --enforce-lockfile --offline` — passed, no new dependency/version.
- `dart format --output=none --set-exit-if-changed lib test tool` — passed,
  172 files, zero changes.
- `flutter analyze` — passed, no issues.
- `flutter test --reporter expanded` — **all 360 tests passed**. The five new
  footer tests cover exact semantic link actions/destinations, false/throwing
  launches, late disposal, original visual elements/absent added controls,
  bottom safe-area placement and keyboard hiding.
- `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack`
  — passed, **13 images / 3,000,554 bytes**, no publication.
- Offline manifest/hash/copy checks — original nine indexed rows unchanged;
  all eleven reference hashes valid; bundled/reference/legacy mascot and font
  copies identical. All thirteen compiled sources match ignored local input;
  supplied tokens are absent from Git-visible files. `git diff --check` passed.

A separate adapted render of the original legacy view/button composition was
compared against the actual new page at **390×844, pixel ratio 1**, for the tour
and named cover. Both had **zero differing pixels out of 329,160**. These renders
share the selected migrated book renderer, local artwork and controlled preview
fonts; they establish composition parity for those scenes, not universal
font/device or independently verified renderer parity. Byte-identical PNGs and
the method/results are retained under
[`docs/evidence/ui01/parity/`](docs/evidence/ui01/parity/). Temporary comparison
helpers were removed. Prior UI01 screenshots remain historical.

**Limitations and boundary.** No Firebase request or refresh of the nine original
images, native build/install/smoke, real-browser launch, physical-device or
release-performance qualification was performed. Fully restart with the
existing `env.json` defines to see the fixed resources; no data reset is needed.
The authorized onboarding/name work stops here. M12, other page UIs, product
features, desktop/website, publication and remote Git remain separately scoped.

### 3 November 2026 — UI01 resource choice: Google Fonts and Grand Maester mascot

**Selected task.** The user explicitly chose the previous app's Google Fonts
approach, without asset fonts, and supplied
`redkeep/assets/branding/grand_maestar.png` as the onboarding mascot. This is a
resource-only follow-up within UI01; the restored layout and name workflow stay
in scope and no additional page or feature is selected.

**Delivered.** Both normal and constrained name-cover captions now use
`GoogleFontsLite.getFont('Allura', fontSize: 30, fontWeight: FontWeight.w600)`,
the legacy entry point. Added pinned `google_fonts` 9.0.0 after checking its
[official usage/API documentation](https://pub.dev/packages/google_fonts/versions/9.0.0)
and installed SDK constraints against Flutter 3.47.5 / Dart 3.13.4. Only this
package was added; all other resolved dependency versions remain unchanged.
Removed the app's Allura TTF and `flutter.fonts` declaration. The OFL notice
remains as a license-only asset under `assets/licenses/` and in Flutter's license
registry. Google Fonts owns on-demand fetching/caching; font loading does not
join startup checks or block the name/Save gate.

The exact 1,842,097-byte user-supplied `grand_maestar.png` replaces the old J
mascot, retaining the original placement and display height. Its decode height
is bounded by the display height/device pixel ratio. The user file was not
edited/recompressed; a byte-for-byte reference and its current source/hash are
indexed under the stable mascot key. Removed the unused old J app/reference
copies. The local Allura reference remains outside the bundle as `test-reference`.
The original nine Firebase manifest rows and bytes, 13-image pack and supplied
source values remain unchanged. The footer, manual navigation, committed name,
schema 8, route continuation and asset repair contracts are preserved.

**Offline isolation.** `test/flutter_test_config.dart` disables Google Fonts
runtime fetching and preloads the exact local Allura through a temporary
in-memory asset response. It then removes that response, clears the temporary
manifest and primes the real asset manifest outside widget fake-async zones.
Book tests clear their image cache between cases, avoiding unfinished earlier
decodes of the larger mascot. No routine test uses a real font network/cache,
font-storage writes, account, model or user database.

**Checks and evidence.** From `redkeep/`:

- `flutter pub get --enforce-lockfile --offline` — passed, reproducible lock.
- `dart format --output=none --set-exit-if-changed lib test tool` — passed,
  173 files, zero changes.
- `flutter analyze` — passed, no issues.
- `flutter test --reporter expanded` — **all 360 tests passed**.
- `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack`
  — passed, unchanged **13 images / 3,000,554 bytes**, no publication.
- Original-row/hash/exact-copy checks — all nine original rows unchanged, all
  eleven references valid, selected mascot and license copies identical, no
  app font binary/declaration, no changed existing lock versions, all thirteen
  compiled source values preserved/ignored and no supplied token in Git-visible
  files. `git diff --check` passed.

Current actual-page widget previews and machine-readable evidence are under
[`docs/evidence/ui01/resources/`](docs/evidence/ui01/resources/). They use local
artwork/font references and controlled body/icon preview fonts at 390×844; the
temporary capture helper was removed. Prior `parity/` captures describe the
preceding J-mascot/bundled-font variant, not the current resource choice.

**Boundary and remaining evidence.** No live Google Fonts runtime download/cache,
Firebase request/reference refresh, native build/install/smoke, physical-device
or release-performance check was performed. No unrelated staged/unstaged work,
launcher/env values, native/signing configuration or writing/settings were
changed; legacy projects stayed read-only and `raw_assets/` was not accessed.
Stop at UI01. Other feature/UI work, M12, desktop/website, publication and remote
Git remain separately selectable.


### 3 November 2026 — UI01 follow-up: bundled branding and artwork startup

**Selected task.** The user explicitly chose
`redkeep/assets/branding/grand_maestar.png` and
`redkeep/assets/branding/ink-paper.webp` as permanent shipped assets, with the
paper background, mascot logo and progress bar on the asset-loading page.
This follow-up covers startup branding and existing uses of these two images.

**Delivered.** Added ink paper to Flutter's asset manifest; the mascot was
already bundled. Startup now has the full paper background, centered mascot,
readable ink/plum text and buttons, rounded determinate progress, percentage and
KB/MB totals. Safe-area scrolling supports narrow screens, large text and
keyboard insets; no decorative animation or indeterminate ticker was added.
Existing download/retry/local repair and validated continuation behavior stays
in place. Both normal and constrained onboarding use bundled ink paper.

`presentation-ui01-v3` removes the paper key and redundant deployment payload,
leaving **12 downloads / 2,658,676 bytes**. All remaining metadata is unchanged.
Runtime ignores the exact retired `onboarding.background.ink` source key in
older maps; offline preparation omits it and preserves consumed URLs/queries
and unrelated env values. Other unknown keys still fail validation. No ignored
local configuration was rewritten. Existing installed paper files are harmless
and no app storage is cleared. Both branding files match their reference hashes;
all eleven reference hashes and the original manifest remain unchanged.

**Checks.** Commands run from `redkeep/` unless stated otherwise:

- `flutter pub get --enforce-lockfile --offline` — passed; lockfile unchanged.
- `dart format --output=none --set-exit-if-changed lib test tool` — passed,
  173 files and zero changes.
- `flutter analyze` — passed, no issues.
- `flutter test --reporter expanded` — all **361 tests passed**. Coverage includes
  fresh startup/retry, actual progress, narrow/3× text/insets in both themes,
  both onboarding layouts, exact local bytes and old full source maps.
- `dart run tool/validate_assets.dart assets/catalog/presentation-v1.json tool/assets/pack`
  — passed, **12 images / 2,658,676 bytes**, no publication.
- `flutter build apk --debug --target-platform android-arm64` — passed.
- Local Python ZIP/hash checks — both exact branding binaries present in the
  debug APK, the current twelve-entry catalog packaged, no reference/deployment
  fixture bundled, all eleven reference hashes valid and manifest unchanged.
- `git diff --check` — passed.

Actual `StartupPage` widget captures at 390×844 with safe insets, local images,
synthetic progress and a locally loaded preview body font are under
[`docs/evidence/ui01/startup/`](docs/evidence/ui01/startup/), alongside the
machine-readable evidence. The temporary capture helper was removed.

**Boundary.** No live Firebase/font requests, reference refresh, model load,
device installation, physical accessibility/performance qualification or iOS
build was performed. Existing native configuration, writing/settings, user
artwork bytes and unrelated staged work are preserved; `raw_assets/` and legacy
projects were not accessed. M03/M10 hardware and M04 hosting gaps remain. Stop
at this selected startup/onboarding follow-up; further UI or M12 requires selection.


### 3 November 2026 — W01: local website copy and Redkeep rename

**Reopening and current scope.** The user explicitly reopened the parked website
rebuild, asked to mostly copy/rename Journal to Redkeep with the same UI, and
then directed: keep screenshots unchanged; leave out releases and use an empty
Download button; remove Simpler view; remove all website reduced-motion handling.
These instructions supersede the historical W01 prompt's motion/download UI
requirements for this website only. Desktop rebuilds, mobile paths and production
publication remain excluded. No routine approval was requested after reopening.

**Assumptions revalidated.** Read the plan, AGENTS, architecture guide, reference
manifest and applicable Sites local-only/design/preview workflow. Inspected only
the selected legacy website files, asset provenance/fonts and desktop release
guidance read-only. Public release APIs returned HTTP 200: Redkeep has no listed
release; the existing Journal Android APK is a separate product. The desktop
README documents an unsigned local preview, not a Redkeep download. No old
release URL is repurposed, no store/account/private release is claimed verified,
and no binary was downloaded. Official React/TypeScript, Vite, GSAP, Tailwind,
Playwright and typescript-eslint APIs/compatibility were checked before selecting
dependencies; a new reproducible npm lockfile belongs only to `website/`.

**Delivered.** Local sibling React 19 / strict TypeScript / Vite 8 website, with
the legacy night hero, pinned note, mascot/stationery, sun-to-book handoff,
page-turning book, chapter rail, phone carousel, ruled index and paper legal
pages. Live Redkeep wordmarks and CSS labels preserve the original image bytes.
Current copy covers only implemented Notes, Diary, Flow, Appearance and optional
Grand Maester behavior, with qualification limits. All six screenshot JPEGs
remain byte-for-byte, visibly identified as legacy references with accurate
capability captions. Download buttons are disabled with no href/handler; there
is no release section. No simpler/reduced-motion code, browser writing, owner
storage, analytics, accounts, remote fonts, retired-brand asset or future route
was added. Static prerendering keeps product/legal text readable without JS.
Native scroll and manual keyboard/touch controls work independently of scroll
decoration. The hero spacer no longer intercepts underlying book input.

**Assets.** Read existing canonical local copies first. Original 11 manifest rows
and hashes remain unchanged; the manifest now indexes 32 exact references, with
21 selected website/font/license entries. All six old screenshot files match
read-only sources. Existing book references have separate website runtime copies;
the reference library is outside bundles. OFL notices and selected-asset public
redistribution review gaps are preserved. No Firebase refresh, token-bearing URL,
raw-work directory access, mobile bundle change or bulk legacy import occurred.

**Validation.** Commands from `website/` unless stated otherwise:

- `npm run typecheck` — passed strict TypeScript, including browser tests/config.
- `npm run lint` — passed with zero warnings.
- `npm run build` — passed Vite production build, static prerender and local
  content/metadata/reference/asset-budget/screenshot/download integrity checks.
- `npm test` — all **12 checks passed** in isolated Google Chrome 156.0.8078.80
  (Playwright 1.64.1), including keyboard skip/rail/arrows, manual gallery,
  touch emulation at 390×844, 320×568 and 844×390, 320px with 300% root text,
  zero axe WCAG A/AA findings on landing/privacy/terms, local resources and
  metadata, disabled downloads and production content without JavaScript.
  The first test requests OS reduction and verifies the user's chosen animated
  presentation still has both pins and no Simpler view control.
- `npm audit --omit=dev` — zero findings. Full audit reports 11 moderate
  ESLint/minimatch development findings; no blind downgrade/force fix applied.
- Root reference/hash/source comparison — all 32 hashes valid, original rows
  unchanged, all six screenshot bytes unchanged. Scoped whitespace checks pass.
  Whole-repo `git diff --check` reports the user's pre-existing mobile trailing
  whitespace; that unrelated edit was preserved.

Production/browser screenshots and measured first-page resource bytes are in
[`docs/evidence/w01/`](docs/evidence/w01/), with machine-readable verification.
Local production preview served successfully at `http://127.0.0.1:4173/` and was
inspected in-app. The full static output is about 5.08 MB; the observed first-page
encoded resource payload is 4,768,724 bytes, dominated by retained art/fonts.
No physical-device or universal speed/accessibility claim follows from those
checks. See [the website guide](docs/website.md) for exact reproduction commands.

**Limitations and next work.** No physical touch/screen reader, Safari/Firefox,
slow-network/low-end frame/energy qualification or production-host check was
performed. Reduced-motion accommodation is intentionally absent by user choice;
axe checks do not establish universal WCAG conformance. Before any separately
authorized publishing, resolve selected art public redistribution provenance,
review publisher/contact/privacy/terms, choose the real hostname and absolute
canonical/social metadata, configure hosting, review dev dependency advisories
and qualify intended browsers/devices. Downloads remain disconnected until the
user supplies/selects real verified destinations. No Site registration, remote
Git, source synchronization or publication was performed. Stop at W01. No next
phase is automatically authorized; M12/further mobile UI requires selection and
D01–D03 remain Deferred.


### 3 November 2026 — W01 follow-up: castle cover in the original palette

**User scope.** Replace the website's cover-title patch with a real image: “The”
and “Redkeep” on two centered lines, castle themed. The user corrected the first
generated concept because it changed the original palette and left no writing
space. The selected replacement retains lavender linen, muted-plum lettering,
gold border/botanical details, sage ribbon and the blank name region. Only W01
cover art is changed; prior download/motion choices remain in force.

**Delivered.** Used the built-in imagegen tool to edit the already inspected
canonical cover reference. The two-line title and small gold castle are in the
image itself. The original “A JOURNAL BY”, name line and bottom inscription stay;
the live “you” overlay has clear space. Removed the CSS title patch. Both book
and hero handoff use the shared new cover. The rejected burgundy concept was not
imported. Saved the exact 1122×1402 PNG master under the reference library and
exported a 477,330-byte JPEG with macOS sips at quality 88, without crop/recolor/
compositing. Prompt/export provenance is in
`assets/reference/website/cover-castle-prompt.md`. The runtime JPEG is indexed
byte-for-byte, outside the mobile path; the master stays outside bundles.

**Checks.** TypeScript, lint, production build/integrity and the existing 12
browser/accessibility checks pass. In-app inspection and new desktop/mobile
cover captures verify the two title lines, original palette, castle motif and
clear name area at the existing geometry. All 34 local references have valid
hashes; the previous rows and all six screenshot hashes are unchanged. No new
dependency/lockfile change was needed. The full static output remains under the
6.5 MB budget (about 5.18 MB). See
`docs/evidence/w01/cover-verification.json`.

**Boundary.** No mobile/legacy/raw-asset file, screenshot, release destination,
motion policy, account, hosting or publication changed. Physical-device and
production/browser qualification gaps remain as previously recorded. W01 stays
Complete within the user's revised scope; stop at this cover follow-up. No next
phase or publication is authorized.


### 3 November 2026 — W01 correction: restore typing on the book cover

**User request.** Restore the original editable name line, which the website
rebuild had replaced with a static “you”. Inspected only the legacy name store
and relevant book faces read-only; no legacy file or mobile path was changed.

**Delivered.** Restored the original placeholder, controlled text input and
24-character limit. Shared site-scoped React state mirrors edits on the inside
cover, hero transition and personalized final page. Arrow keys inside the field
move the caret rather than turn pages. The current lavender castle image and
its writing area remain unchanged. Browser-only persistence uses the namespaced
`redkeep-cover-name` key, with read-only fallback to the original `journal-owner`
on the same origin. Clearing the field persists an empty value; unavailable
storage keeps the name usable in memory until reload. Static prerendering never
reads or contains a visitor's saved name. No mutable global visitor store,
external account, network transmission, journal composer or new dependency
was introduced. Updated the privacy description and bounded input build check.

**Checks.** `npm run typecheck`, `npm run lint`, production/prerender/integrity
build and all **15 browser/accessibility checks** pass. The three new checks
cover typing/caret/length/personalization/reload, preservation and deliberate
clearing of legacy stored names, and blocked reads/writes. Existing 390px touch
coverage now enters a synthetic name in an isolated profile. The name evidence
and screenshot are under `docs/evidence/w01/name-verification.json` and
`editable-name.png`; all reference/screenshot integrity checks still pass.

**Boundary.** Existing browser names were not overwritten during manual work.
Direct in-app attachment was unavailable during this follow-up; isolated
production Chrome checks passed. The user-owned dev preview at port 5173 remains
running. No physical keyboard/IME, device, remote Git or publication claim is
made. Prior download and motion choices stay intact. W01 remains Complete; stop
at this restoration. No later phase is authorized.


### 3 November 2026 — W01 follow-up: Grand Maester mascot and Download label

**User scope and change.** Replace `website/public/art/j.png` with the selected
`redkeep/assets/branding/grand_maestar.png`, and remove the “Not available yet”
status below header Download while leaving the button disabled. Read the indexed
local mascot reference first and verified it matches the supplied mobile source.
Copied all 1,842,097 bytes unchanged to the existing website filename, so hero,
book faces, feature/footer images and social metadata now share Grand Maester.
Corrected the hero image's intrinsic size to 1254×1254. Removed the status text,
its wrapper/description IDs and obsolete compact prop/styles; no download URL
or handler was added. The original cover, name editing, screenshots and motion
behavior remain unchanged.

**Validation.** Strict TypeScript, zero-warning lint, production/prerender/asset
checks and all **15 browser/accessibility checks** pass. Existing initial-page
coverage verifies the disabled control and absence of the removed header status.
The build explicitly verifies the mascot against its canonical bytes. All
34 reference hashes and all six original screenshot hashes remain valid; no
reference row or mobile file was changed. Updated hero/touch captures and
`docs/evidence/w01/mascot-verification.json` record the selected presentation.

**Weight and boundary.** The selected unchanged PNG replaces a 64,238-byte image,
adding 1,777,859 asset bytes. Deliberately revised the whole-site build budget
from 6.5 MB to 7 MB for this user-selected original; the result is about 6.96 MB.
No recompression, new dependency, source mutation, native/device performance
qualification, remote Git or publication occurred. Existing publishing/device
limitations remain. The user-owned preview at port 5173 stays running. Stop at
this W01 follow-up; no later phase is authorized.

### 3 November 2026 — W01: remove mascot mouse-follow

Removed only the hero mascot's three pointer-driven GSAP setters and calls
(six lines). Intro, tap and scroll behavior is preserved. `npm run typecheck`,
`npm run lint` and `npm run build` pass. No new tests/dependencies, browser/device
qualification, staging changes or publication. W01 remains Complete; stop here.

### 3 November 2026 — W01: restore legacy carousel/card animations

At the user's request, removed the added book arrows/counter and their styles.
Copied back the selected legacy carousel fan entrance and 4800ms autoplay until
interaction, and feature-card prints/scan/typewriter/drift/wave/theme demos with
the original scroll-reveal timing. Kept current truthful product descriptions,
existing local artwork, working name entry, disabled Download and the previous
removal of mascot mouse-follow. No new asset, library, motion preference mode or
future feature was introduced. Legacy files stayed read-only.

`npm run typecheck`, zero-warning lint, production/prerender/artifact build and
all **17 browser/accessibility checks** pass. Two new checks verify timed carousel
rotation/interaction stop and restored demo animations/theme controls; existing
checks now use retained keyboard navigation and assert no added book controls.
New captures and `docs/evidence/w01/animation-verification.json` record the
result. Static output is about 6.97 MB, within the existing 7 MB limit. All 34
reference hashes and original screenshot bytes remain unchanged. Existing
physical-device/browser/publication limitations persist. W01 stays Complete;
stop here without publishing or changing the user's staged work.


### 3 November 2026 — W01: build shared app artwork from the website source

**Selected scope and cause.** The user selected the existing website as the
image host, replaced the duplicate-reference requirement with
`website/public/art/`, added four missing images, and supplied the Vite chunk
output while diagnosing their unavailable public URLs. Reproduced the complete
`npm run build` failure immediately after Vite/prerendering:
`Unindexed asset: dist/art/notes_add.png`. The four files existed locally, but
the earlier build output lacked them. A fresh output also exceeds the old
7 MB whole-site limit by including their additional 327,851 bytes.

**Delivered.** The final build checker verifies every `public/` file against its
exact output copy, including images with no website UI consumer. Images/fonts
in the output must have a public source. It no longer reads duplicate files or
the manifest under `assets/reference/`. Preserved the existing mascot and six
original screenshot SHA-256 guards as metadata in the checker. Revised the
reviewed whole-output limit to 7.5 MB for these user-added images. Updated AGENTS
and current guides to make the website folder the canonical shared image
reference; historical archives remain intact.

**Evidence.** `npm run build` passes TypeScript, Vite, prerendering, source-copy,
metadata/content, mascot/screenshot and output-budget checks. The output is
7,297,375 bytes and includes all four added files under `dist/art/`.
`npm run lint` passes with zero warnings; all 17 existing Chrome/browser/axe
checks pass. See `docs/evidence/w01/asset-host-build-verification.json`.
Routine regenerated captures were restored because presentation did not change.

**Boundary.** This is a local build correction, not a deployment or remote Git
operation. The mobile catalog, compiled Firebase source configuration, tests,
startup behavior and cover selection are unchanged; their migration to the
selected host remains outstanding. No source artwork, raw/legacy files,
dependencies or native configuration changed. W01 remains Complete at this
boundary; no other phase is selected automatically.


### 3 November 2026 — Selected asset simplification: shared website delivery

**User selection.** After selecting the website as the image host and its public
art folder as the sole current local reference, the user confirmed the missing
images were live and requested simplification. Scope covers the mobile artwork
source boundary, offline image inputs, obsolete Firebase/pack tooling, website
build checker removal and current guides. It does not select M12, device data
reset/installation, publication, remote Git or another UI feature.

**Delivered.** Default image directory is
`https://redkeep.lewiseman.com/art/`; ordinary and editor Debug/Profile/Release
runs need no env file. Catalog `presentation-website-v1` keeps twelve required
images / 2,800,992 bytes. A safe relative `sourcePath` selects the website file;
installed `path` remains unchanged for all eleven byte-identical existing images.
This avoids needless redownloads. The cover adopts the website's selected
Redkeep castle JPEG at revision v2/new path, with reviewed bytes/hash/provenance.
The provider/resolver, verified atomic installation, repair, startup gate,
continuations, writing storage and bundled startup branding remain intact.

Removed per-image URL-map parsing, source preparation script/example inputs and
its tests, Firebase refresh tool, duplicate payload pack, website checker and
whole-site size gate. Ignored old token/env inputs remain untouched and ignored.
Image widget fakes, real-file tests and optional catalog validation now read
`website/public/art/`. The validator accepts unrelated website images and never
copies or fetches them. Historical references and the consumed Allura font
reference remain intact. No source image was edited or copied into a new library.

**Verification.** Live HTTPS GETs for all twelve selected files returned 200
without redirects and matched local source bytes. The source check is explicit
verification, outside routine tests. `flutter pub get --enforce-lockfile --offline`
passes without a lockfile change; formatting and analysis pass. All 43 focused
asset checks and all 361 offline mobile tests pass, including eleven reused files,
only-new-cover transfer, repair/offline reopen and writing preservation. Website
TypeScript/build/prerender, zero-warning lint and all 17 Chrome/browser/axe checks
pass. Android ARM64 debug APK builds and packages the exact new catalog and
bundled branding without a payload pack, image reference library or Allura TTF.
See `docs/evidence/assets-website/verification.json` for commands and source hashes.
Routine generated website captures were restored; there is no website UI change.

**Boundary and remaining evidence.** No device installation/launch, real writing
access, asset upload/deployment, remote Git operation, dependency/native/schema
change or raw/legacy access occurred. Existing system/native font-host behavior
and AI qualification gaps remain separate. Fresh Android/iOS download/offline
journeys from the new host, physical/minimum-OS/low-end checks and distribution
rights are not inferred from unit/widget tests or APK packaging. The selected
simplification is complete; UI01 native-host qualification remains Partial and
M12 remains Not started. Stop here.


### 3 November 2026 — Asset config cleanup and legacy-code audit

**User clarification.** Redkeep is a new app; no further legacy code should be
copied or ported. The user identified the remaining local download-list file
and asset fixture/config flags after the source simplification. Preserve the
existing UI and prior work while removing those setup leftovers; do not disguise
existing code provenance or import from a legacy checkout.

**Cleanup.** Deleted the actual ignored `onboarding-downloads.local.json` and
asset-only `env.json` from disk without printing or backing up their contents.
The pending env file was absent. Removed their obsolete ignore entries. Removed
all asset compile-time defines and the HTTP fixture switch; production composition
uses the built-in HTTPS image directory directly. Asset locations reject HTTP.
Tests keep injected clients/local website files. Removed local-server/flag setup
instructions and recorded the no-further-legacy-import rule in AGENTS/current
plan/prompt guidance. Historical evidence retains its dated setup descriptions.

**Provenance findings.** Git history places the fixture flag in Redkeep's own
M04 commit `310cd12`; its presence was extra setup code, not evidence of a Journal
service import. Existing UI01 source comments and phase records explicitly
identify adaptation of onboarding fold/paper/book geometry and view composition.
W01 records copying the legacy website UI. Those earlier adapted components
remain; this cleanup neither rewrites them nor claims the codebase has zero
legacy-derived UI. No legacy checkout was read and no additional code imported.
Redkeep's own schema upgrade tests are not an old-app data importer.

**Checks.** Formatting checks 171 files with zero changes; analysis finds no
issues; all 361 mobile tests pass; Android ARM64 debug packaging passes. A local
source/file audit confirms zero asset-flag references in runtime/asset tests/
editor configuration and absence of the obsolete local files. See
`docs/evidence/assets-website/config-cleanup.json`. No website behavior changed,
so the earlier passing website build/browser checks were not repeated.

**Boundary.** Existing pending source simplification work remains intact. No
source artwork, writing/database schema, dependency, native configuration, raw
work area or legacy checkout was changed. No device installation, deployment,
remote Git operation or wider UI rewrite occurred. The config cleanup is complete;
existing legacy-derived UI remains disclosed and further imports are prohibited.
M12 and native host/device qualification remain separately scoped.


### 3 November 2026 — One base URL through env.json

**Latest user selection.** Restore passing the image base URL through `env.json`
while keeping the removed per-image configuration and fixture modes retired.
This narrowly supersedes the preceding no-env decision, not the prohibition
on additional legacy code imports.

**Delivered.** The ignored local `redkeep/env.json` and tracked
`redkeep/env.example.json` contain only `ASSET_BASE_URL`, set to
`https://redkeep.lewiseman.com/art/`. Bootstrap reads that compile-time string;
there is no hardcoded fallback or runtime file reader. Debug/Profile/Release
editor configurations pass the file using Flutter `toolArgs`, verified against
Dart Code's official launch guidance. CLI runs/builds use
`--dart-define-from-file=env.json`. Current guides/AGENTS record this one-setting
contract and the full stop/rerun needed after changing compiled configuration.

**Checks.** Formatting checks 171 files with zero changes; analysis finds no
issues; all 361 routine mobile tests pass without requiring an env define.
Android ARM64 debug build with the env-file flag passes. APK inspection confirms
the configured URL is compiled into its Dart kernel and `env.json` is not bundled.
Local checks confirm the file is ignored, both JSON files have exactly one key,
all three editor tool configurations match and old source maps/fixture flags
remain absent. See `docs/evidence/assets-website/env-base-url.json`.

**Boundary.** No new dependency, legacy import, website behavior, artwork,
writing storage/schema or native source change. No manual IDE/device launch,
deployment or remote Git operation. Existing native host/device qualification
limits remain; the selected one-setting configuration follow-up is complete.
