# Presentation assets and startup

The app downloads required artwork from the HTTPS image directory configured by
`ASSET_BASE_URL` in ignored `redkeep/env.json`, currently
`https://redkeep.lewiseman.com/art/`.
The canonical local files are `website/public/art/`; local tests use those files
without network access. The website's standard TypeScript/Vite/prerender build
copies `public/` into `dist/`. It has no custom image checker or total-size gate.
See [adding artwork](onboarding-assets-setup.md) for the short authoring workflow.

## Catalog and storage

The bundled JSON `redkeep/assets/catalog/presentation-v1.json` pins
`presentation-website-v1`: **12 images / 2,800,992 bytes**. Its keys identify
purpose, independent of filenames. Each entry carries revision, installed `path`,
website `sourcePath`, size, SHA-256, license and provenance. The eleven unchanged
images retain their installed paths and hashes. The Redkeep castle cover replaces
the old Journal cover with revision `v2` and a new JPEG path.

`sourcePath` resolves against the one configured image directory. It does not
change local file identity or enter the installation ledger. The parser defaults
it to `path` for older catalog inputs. Both paths must be safe relative PNG,
WebP or JPEG paths. Duplicate keys/installed paths, traversal, queries, percent
encoding, temporary names and missing metadata are rejected. Limits remain 100
images, 10 MiB each and 50 MiB total. A real still-image decode must match the
extension and fit within 2048 × 2048 pixels.

`FileRequiredAssets` owns application-support `required-artwork/`, separate from
`redkeep.sqlite`. `ledger.json` records key, revision, installed path, SHA-256,
size, modified/changed times and image-verification version. Each launch checks
real files and metadata; cold or suspicious files receive hash/decode checks,
while unchanged verified files avoid repeated hashing. Explicit repair verifies
every required file. Old ledger versions can be rebuilt from valid local files.

Downloads stream sequentially into sibling `-pending` files, verify exact size,
SHA-256 and real image format, flush/close, and rename before committing the
ledger. Partial files are never resolved. Retries retain completed files; an
interruption after payload rename can recover by local verification without
redownloading. Directory/target/ledger/temporary symlinks are rejected. Operations
serialize in the app-scope store. Asset repair has no database or writing access.

The injected resolver returns local file URIs for semantic keys. Presentation
uses file images with bounded decode sizes. Resolver/decode errors close normal
entry and offer recheck/repair; cached same-path images are evicted on resolution.

## Host and startup

`ASSET_BASE_URL` is the only asset define, supplied by
`flutter run --dart-define-from-file=env.json` from `redkeep/`. The tracked
`env.example.json` has this one key; the real `env.json` stays ignored. There is
no hardcoded fallback or runtime read of that file. The image directory must
use HTTPS, end in `/`, and contain no credentials, query or fragment.
Per-image URL maps, token lists, preparation commands and HTTP fixture modes
remain removed. Tests inject clients/local files and do not require the ignored
env file. No online catalog fetch is part of normal startup.

The HTTP client requests identity bytes, rejects redirects/non-200 responses,
and has 15-second connection/response/idle deadlines plus a two-minute receive
limit per image checked as chunks arrive. Completed files open offline without
any host lookup. Missing required artwork blocks a fresh offline launch.

`main` preserves the native splash immediately. `BootstrapCoordinator` bounds
aggregate local database/preferences/onboarding and asset checks at five seconds.
Success, failure, timeout or disposal releases the splash so Flutter can show
normal navigation, onboarding, a recoverable local error, or download/retry.
No download or model initialization runs under the native splash. Direct route
continuations survive checks, downloads and onboarding.

The Grand Maester mascot and ink-paper background remain bundled for immediate
startup and both onboarding layouts. They match `public/art/j.png` and
`public/art/ink-paper.webp`; they never enter the required-file store. Google
Fonts owns Allura fetching/caching independently of the artwork gate. The exact
archived Allura font reference keeps font tests offline without bundling a TTF.
Models are separate and optional; audio/video delivery is outside this scope.

## Checks and evidence

Run the README commands. Asset tests use disposable directories, injected
clients, fresh scopes and real local website artwork. They cover installation,
all eleven reused files and the changed cover, offline reopen, repair, size/hash
and image failures, symlinks, storage errors, timeouts and interruption. UI tests
retain startup/onboarding continuation, safe-area, narrow/large-text, keyboard,
theme, reduced-motion and simpler-effects checks. They use no account, real
writing, model, host request or production database.

The optional developer-only command validates cataloged sources without copying
or uploading files and permits unrelated website artwork:

```sh
cd redkeep
dart run tool/validate_assets.dart assets/catalog/presentation-v1.json ../website/public/art
```

All twelve hosted images returned HTTP 200 without redirects and matched the
local website bytes during the selected 3 November 2026 source migration.
Exact current checks and limitations are in the migration record. Earlier M04
native fixture evidence remains historical; it does not prove a fresh native
installation from the new HTTPS host. Physical accessibility, minimum-OS/low-end
hardware, release behavior, native disk-full/power-loss durability and public
redistribution rights remain separate qualification work. No app data is cleared
or device installation performed to force onboarding.
