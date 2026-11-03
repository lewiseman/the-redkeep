# Redkeep website

Local-only React / TypeScript / Vite rebuild of the selected Journal website UI.
Original screenshots stay unchanged. Downloads have no destination. The user
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
