# Working in Redkeep

- Read [MIGRATION_PLAN.md](MIGRATION_PLAN.md) and the applicable guide under
  [docs](docs/architecture-testing.md) before changing code. The migration plan
  defines the agreed architecture, prerequisites, exclusions, and acceptance.
- Implement only the phase selected by the user. Finish its checks, update its
  progress row, append an evidence record, and stop at that phase boundary.
  M01 completion does not authorize M02.
- Inspect repository status and existing files first. Preserve unrelated changes,
  native configuration, and the mobile path `redkeep/`.
- Leave `raw_assets/` untouched. It is the user's local artwork/audio work area,
  ignored by Git and outside application bundles.
- Use `website/public/art/` as the canonical local image source and reference for
  shared website/mobile artwork, hosted at `https://redkeep.lewiseman.com/art/`.
  Read these files before fetching URLs for UI/reference/test work. Do not create
  duplicate reference copies for images already there. Tests use local files and
  never download them. Preserve existing `assets/reference/` material as historical
  evidence or references not yet available in the website; do not refresh Firebase
  copies for website-hosted images. App catalogs still need reviewed paths,
  revisions, sizes and hashes; local website files do not enter Flutter bundles
  automatically. Keep any remaining token-bearing configuration ignored.
- Legacy projects under `/Users/lewis/Dev/Projects/Journal/` are read-only
  references. Inspect them only when the selected phase needs them; copy only
  specifically approved behavior/assets. Never bulk-import code or manifests.
- Use feature-first organization with Riverpod composition and go_router. Create
  directories, abstractions, and dependencies only for real current consumers.
  Inject external boundaries and time/ID sources when used; keep tests isolated
  and deterministic. Avoid mutable global services and broad barrel imports.
- Keep routine tests independent of accounts, network, real writing, models, and
  user databases. Use fresh provider containers and small consumed test helpers.
  Do not seed production writing with fixtures or register future feature pages.
- Keep new presentation usable on narrow screens, with large text, safe areas,
  reduced motion, and simpler effects. Record unavailable native/device evidence
  honestly; do not treat widget tests as physical-device verification.
- Run the commands in [README.md](README.md) for changed behavior. Keep the app
  lockfile reproducible. Verify official APIs/compatibility before adding a
  dependency, and remove obsolete dependencies and experiments.
- Follow the selected phase without routine approval requests. Do not perform
  remote Git operations, publish, or expand into later phases without user scope.

The current shell contracts and test locations are documented in
[docs/architecture-testing.md](docs/architecture-testing.md). Add a short feature
guide when an implemented feature introduces new contracts or recovery behavior.
