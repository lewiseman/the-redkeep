# Redkeep website

React / TypeScript / Vite rebuild of the selected Journal website UI.
Original screenshots stay unchanged. The user
explicitly removed Simpler view and reduced-motion handling.

```sh
npm ci
npm run dev
npm run typecheck
npm run lint
npm run build
npm test
```

Use Node 22.12+ or 24+. Tests use installed Chrome, isolated profiles and local
assets. Production output is in `dist/`.

`public/art/` is the canonical local reference for shared website/mobile images.
Vite copies `public/` into `dist/`, including images absent from its chunk size
table. The build runs TypeScript, Vite and prerendering. There is no custom asset
checker, duplicate-reference requirement or whole-site size gate. The mobile
catalog and runtime retain their own download integrity checks.

## App downloads

Both download links use the permanent GitHub Releases URL:

<https://github.com/lewiseman/the-redkeep/releases/latest/download/redkeep-arm64-v8a.apk>

Downloads support Android 11+ on ARM64 phones. Version and download size come
from `src/release.json`, generated from the verified signed APK. The footer links
to the latest release's installation instructions and checksum. Downloads are
ordinary links and work without JavaScript or a GitHub API call in the browser.

From `../redkeep`, run `python3 scripts/release_android.py` to prepare an APK, or
add `--publish` to publish it after committing and pushing the app source. Deploy
the website only after the matching GitHub release is published. Keep the existing
Vercel project and hosting configuration. See
[the release guide](../redkeep/docs/android-release.md) for the complete flow.
