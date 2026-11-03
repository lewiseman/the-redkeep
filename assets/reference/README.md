# Local asset references

Tracked original artwork and the offline Allura test font live here, outside
Flutter bundles. `manifest.json` records their paths, source identities, sizes,
and hashes. Keep original bytes and license notices.

Current artwork is in `../../website/public/art/`; inspect it before downloading
or creating another copy. The mobile catalog is
`../../redkeep/assets/catalog/presentation-v1.json`. Runtime downloads use the
asset base URL in ignored `redkeep/env.json`.

Tests read local files and never download assets. `fonts/Allura-Regular.ttf`
is loaded by `redkeep/test/flutter_test_config.dart` for offline widget tests.
