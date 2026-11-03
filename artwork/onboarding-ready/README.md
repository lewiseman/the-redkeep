# Ready onboarding artwork

The supplied remote onboarding originals now have canonical local copies in
[`assets/reference/`](../../assets/reference/README.md). Inspect those files
offline; no duplicate handoff copy or re-download is needed for the current
nine references. This directory remains available for future finished
replacement artwork, separate from the exact remote originals.

Place finished onboarding PNGs in this directory. This is a local handoff area;
the Flutter app does not load or download from this folder. Keep the README out
of the final payload pack.

Firebase follow-up: put each full hosted image URL in
`redkeep/onboarding-downloads.local.json` at the mobile app root. The supplied
Diary URL is filled in there; eight entries remain. The WebP example needs
explicit format support during integration; do not rename WebP bytes to PNG to
match the initial artwork brief. See the Firebase section of the setup guide.

The six new text-free artwork files are:

```text
cover-v1.png
notes-v1.png
diary-v1.png
grand-maester-v1.png
flow-v1.png
appearance-v1.png
```

The complete onboarding set also needs three neutral textures. Individual PNG
copies can be prepared from the documented legacy sources when the actual assets
are integrated; no original or `raw_assets/` file is changed automatically:

```text
ink-paper-v1.png
paper-edge-v1.png
binding-cloth-v1.png
```

See [the image brief](../../docs/onboarding-ui-migration.md#1-images-to-prepare)
for sizes, layout, and runtime keys. See
[the download setup](../../docs/onboarding-assets-setup.md) for `env.json`, upload
paths, catalog integration, and the later run command.

Only this README has been created. No dummy images, hashes, or catalog rows are
provided. Once the real images and base URL are supplied, catalog integration
and download verification are the next selected step.
