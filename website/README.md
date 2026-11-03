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
assets; see the [website guide](../docs/website.md) for browser setup, contracts,
asset notices, evidence and publishing prerequisites. Production output is in
`dist/`. W01 does not register or publish a Site.

`public/art/` is the canonical local reference for shared website/mobile images.
Vite copies all `public/` files into `dist/`, even images absent from its chunk
size table. The final build check verifies every copy against its local source;
no duplicate under `assets/reference/` is required. The reviewed 7.5 MB static
output budget includes the four shared app images added on 3 November 2026.
Deploy only after the final `Build integrity ... passed` line; successful Vite
chunk rendering alone does not mean the complete build command succeeded.
