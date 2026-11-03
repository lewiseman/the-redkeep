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
