# Redkeep migration plan and implementation prompts

Agreed on 2 November 2026. Workspace: `/Users/lewis/Dev/Projects/The Redkeep`.

## 1. Purpose and how to use this guide

Rebuild the mobile writing app first, then its Flutter desktop AI companion, then the marketing website. Preserve the journal, paper, artwork, and book identity while improving architecture, accessibility, performance, and testability.

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

Use `Not started`, `In progress`, `Complete`, or `Partial`. A partial result must identify the missing acceptance evidence and any dependent work it prevents. Do not mark a phase complete merely because its code exists.

| Phase | Status | Completed work / evidence | Limitations / next action |
| --- | --- | --- | --- |
| Documentation | Complete | Agreed architecture, roadmap, standalone prompts, and deferred planning prompts recorded in this file. | No application phase has been executed. |
| M01 — Foundations | Complete | Root local Git repository, ignore rules, AGENTS/command/architecture guides, Riverpod composition, neutral go_router shell; formatting, analysis, and all 6 shell/DI/routing tests pass. | Native builds and physical-device behavior unverified; next eligible phase is M02. |
| M02 — Design and accessibility | Complete | Light/dark tokens and system typography, shared paper surfaces, saved appearance settings in background Drift schema 1, reactive OS/app rendering policy; formatting, analysis, all 26 tests, Android debug build, and emulator restart persistence pass. | iOS, physical-device accessibility/keyboard behavior, and release performance unverified; next eligible phase is M03 (M04 is also eligible independently under its prerequisite rules). |
| M03 — AI feasibility | Partial | Pinned core 2.5.5 / LiteRT-LM engine 1.19.1, minimal injected adapter and synthetic harness, 40 passing tests, Android ARM64/API 30 packaging, iOS simulator and unsigned device builds; pinned Qwen3 0.6B streaming/cancel/reuse/cleanup/failure checks pass on physical Galaxy S24 Ultra CPU/GPU and iOS simulator CPU. | Physical iOS/Metal, minimum-OS and low-end hardware, release/sustained resource evidence remain unverified and block corresponding AI release claims. M04 may proceed independently; see M03 record and docs/ai-feasibility.md. |
| M04 — Assets and startup | Complete | Reachable-media inventory/provenance, pinned three-image pack, catalog/publishing validator, injected persistent resolver, verified atomic installs/repair, bounded bootstrap/splash gate; all 88 tests, analysis/formatting, Android and iOS simulator debug builds pass. Android local HTTP download → offline restart and missing-file gating; iOS fresh gate and offline staged-pack recovery verified. | Real HTTPS hosting/publication and physical/minimum-OS/low-end release evidence remain prerequisites; iOS HTTP download and native failure/ENOSPC drills unverified. M03's AI gaps remain unchanged. Next eligible phase is M05. |
| M05 — Onboarding and routing | Complete | Minimal welcome, committed schema-2 completion with migration preservation, validated bootstrap/onboarding continuations and safe fallback, framework back gestures; all 111 tests, formatting/analysis, Android and iOS simulator debug builds pass. Android interruption → requested settings → back/restart and iOS welcome render verified. | Physical accessibility/gestures, native iOS completion/restart, OS link registration/restoration and release/minimum-OS evidence unverified. M04 host and M03 AI gaps unchanged. Next eligible phase is M06. |
| M06 — Notes vertical slice | Not started | — | Requires M05. |
| M07 — Notes organization | Not started | — | Requires M06. |
| M08 — Diary | Not started | — | Requires M07. |
| M09 — Flow | Not started | — | Requires M08. |
| M10 — Brain | Not started | — | Requires M09 and the M03 adapter; native acceptance evidence remains mandatory. |
| M11 — Grand Maester | Not started | — | Requires M10. |
| M12 — Mobile release preparation | Not started | — | Requires M01–M11; production media hosting is a release prerequisite. |
| D01 — Flutter desktop foundation | Not started | — | Starts after mobile acceptance in M12. |
| D02 — Companion connection | Not started | — | Requires D01. |
| D03 — Desktop release preparation | Not started | — | Requires D02 and platform packaging evidence. |
| W01 — Marketing website | Not started | — | Starts after D03. |

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

The first desktop release is an **AI companion**, not a desktop journal. Target macOS Apple Silicon and Windows x64. Linux and other desktop architectures are deferred.

Use React, TypeScript, and Vite for the later marketing website, following the applicable Sites workflow at implementation time. The website advertises implemented behavior; it is not a browser version of the writing app.

Defer third-party API backends, tasks/alarms/notifications, People and P2P note sharing, collaborative text editing, semantic search/embeddings, advanced attachments/media, voice, and cloud sync. Their planning prompts appear later in this guide. The desktop AI transport does not constitute P2P note sharing or journal synchronization.

The new product uses **Grand Maester**, with no QVAC branding, QVAC runtime, Electron dependency, JavaScript inference bridge, or JavaScript P2P implementation. Historical references in this guide are allowed; new runtime code and user-facing branding must follow the new direction.

## 3. Architecture and behavior contracts

### 3.1 Workspace and code organization

Use one repository rooted at `/Users/lewis/Dev/Projects/The Redkeep`. Keep the current mobile location. Add sibling `desktop` and `website` apps only in their phases. Extract shared Dart packages when the desktop app becomes a real second consumer; do not create a speculative package hierarchy now. Preserve `raw_assets` as source material outside application asset bundles.

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

Download all assets required by the currently implemented release, not every old file or all future media. Inventory media required by planned first-release features so the initial complete release has a coherent pack. On later launches, validate catalog-key/revision mappings against real local files and the installation ledger; a key in a database is not proof the file exists. Verify size and hash before atomic installation. Avoid rehashing every large file on every launch without evidence that it is needed; validate suspicious files and failures, repair invalid installations, and test same-path replacement scenarios.

Use persistent app-owned storage rather than a purgeable image cache as the authoritative asset location. Keep completed valid downloads across retries, reject partial/corrupt files as installed assets, prevent writes outside the asset directory, and surface interruption/storage/network failures with actionable retry UI. Required missing artwork blocks normal entry, including on an offline first launch. Existing writing must never be deleted to repair assets.

Routine startup with complete local assets needs no internet and must not fetch a remote catalog before opening. New media catalogs are versioned with releases initially. Production hosting is not yet chosen: use configurable locations and controlled local fixtures during development, and require a real HTTPS asset host before release. Never ship a placeholder URL or a localhost production default.

AI model downloads are separate and optional. Future videos and notification sounds use the media delivery boundary only after their own feature is authorized. Validate platform sound-location, format, and scheduling rules then; do not assume every downloaded sound can directly serve as a system notification sound.

### 3.5 Motion, visual effects, and performance

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

The first desktop app provides model management, capability assignments, phone pairing, and AI jobs. Add the device-to-companion backend only in D02. Use established Dart/native dependencies for authenticated encrypted communication, reviewed pairing/trust primitives, and tested protocol versioning. Do not recreate the old JavaScript transport or invent cryptography.

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

### M12 — Mobile release preparation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement M12 only.

Prerequisite: M01–M11; audit actual completion/evidence instead of assuming tracker labels prove readiness.
Scope: complete end-to-end startup/writing/AI journeys, accessibility review, representative low-end Android/iOS profiling, asset-pack validation, dependency/dead-code cleanup, release configuration, and available release builds. Verify compatible ABI/minimum-OS settings and absence of obsolete bridges/runtime branding. Configure the production HTTPS asset location only from real provided hosting details; document publishing and fresh-install download verification.
Exclusions: no new product features, hosting purchases, fabricated URLs/device results, store submission, public release, cloud credentials, or signing secrets committed to Git.
Acceptance: fast suite and relevant integration/build checks pass; verify complete offline launches and all core writing without an installed model. Record exact devices/builds/models, performance measurements, licenses, signing/host prerequisites, and any release blockers. Missing external prerequisites leave release readiness partial.
Finish: update the M12 progress row and append a phase record covering release readiness, exact evidence, limitations, and next phase. Stop; D01 begins only after mobile acceptance. Do not publish anything.
```

### D01 — Flutter desktop foundation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D01 only.

Prerequisite: M12 mobile acceptance is recorded.
Scope: create /Users/lewis/Dev/Projects/The Redkeep/desktop as a Flutter AI companion targeting macOS Apple Silicon and Windows x64. Recheck current runtime/platform requirements, implement model management and capability assignments, and extract proven shared Dart contracts/runtime code now that both apps consume them. Keep independent app composition and lifecycles. Reuse the asset/rendering policy where appropriate without importing the entire mobile application.
Exclusions: no Electron/JS bridge, phone pairing yet, desktop journal editing/sync, API providers, P2P notes, Linux support, or broad speculative package splitting.
Acceptance: test shared packages and both affected apps, verify synthetic local-model execution/cleanup on available supported hardware, and run native builds where supported. Record exact platform floors and unverified Windows/macOS evidence rather than assuming cross-platform Flutter compilation proves runtime behavior.
Finish: update the D01 progress row and desktop/shared-package guides, and append a phase record with commands, evidence, limitations, and next phase. Stop after D01.
```

### D02 — Companion connection

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D02 only.

Prerequisite: D01 is complete, with model/platform evidence recorded.
Scope: implement Dart-based phone pairing, authenticated encrypted transport using established primitives, trust revocation, capability/readiness discovery, and versioned AI job requests/results. Add the real companion backend to mobile Brain. Document the protocol and trust lifecycle, use stable job IDs and idempotent handling, and define explicit cancel/timeout/interrupted/reconnect states. A lost connection must not silently replay an accepted source modification or switch execution location.
Exclusions: no JavaScript transport, invented cryptography, P2P note sharing, journal sync, API providers, or public internet relay service.
Acceptance: test protocol compatibility, pairing approval and invalid/expired requests, unauthorized clients, revocation, duplicate jobs/results, cancellation, disconnect/reconnect, app restarts, interrupted jobs, stale source revisions, and unavailable models. Perform a synthetic end-to-end paired-device check where hardware permits; keep fast tests isolated.
Finish: update the D02 progress row and protocol/feature guides, and append a phase record with exact evidence, limitations, and next phase. Stop after D02.
```

### D03 — Desktop release preparation

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement D03 only.

Prerequisite: D02 is implemented and its paired-device evidence is recorded.
Scope: finish companion model/assignment management, phone connection status/revocation, useful diagnostics without private content or credentials, lifecycle cleanup, packaging configuration, and supported-platform acceptance. Verify packaged runtime/native libraries and model paths, not just debug builds. Record install/update/signing requirements and the production asset configuration.
Exclusions: no desktop writing features, platform expansion, auto-updater service, store submission, signing purchases, public publication, or unrelated product additions.
Acceptance: run affected mobile/shared/desktop checks and synthetic packaged inference/pairing journeys on available macOS Apple Silicon and Windows x64 systems. Verify restart, disconnect, cancellation, reduced motion, and resource cleanup. Missing hardware/signing evidence remains an explicit release limitation.
Finish: update the D03 progress row and append a phase record with packaged artifacts/evidence, limitations, and the next eligible phase. Stop without publishing; W01 follows desktop acceptance.
```

### W01 — Marketing website

```text
Read /Users/lewis/Dev/Projects/The Redkeep/MIGRATION_PLAN.md and applicable AGENTS.md instructions. Implement W01 only.

Prerequisite: D03 desktop acceptance is recorded; inspect actual mobile/desktop release availability.
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
| Desktop support | macOS Apple Silicon and Windows x64. Record current minimum OS/runtime requirements in D01. |
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
