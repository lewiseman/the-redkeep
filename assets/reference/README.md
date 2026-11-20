# Local asset references

Tracked original artwork and the offline Allura test font live here, outside
Flutter bundles. `manifest.json` records their paths, source identities, sizes,
and hashes. Keep original bytes and license notices.

Current artwork is in `../../website/public/art/`; inspect it before creating
another copy. The app bundles the images it uses under
`../../redkeep/assets/images/`, listed by key in
`../../redkeep/lib/features/assets/domain/app_artwork.dart`.

Tests read local files and never download assets. `fonts/Allura-Regular.ttf`
is loaded by `redkeep/test/flutter_test_config.dart` for offline widget tests.
