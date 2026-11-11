# Redkeep mobile

- We are migrating selected UI and behavior into the Flutter app in `redkeep/`.
- Previous app: `/Users/lewis/Dev/Projects/Journal/journal`. Use it as a read-only
  reference for the migration the user requests; keep Redkeep's current architecture.
- Implement only the user's requested change.
- Inspect Git status and relevant code first. Preserve unrelated changes, native
  configuration, existing writing, and `raw_assets/` (do not inspect or change it).
- Keep feature-first Riverpod, go_router, and Drift patterns. Honor reduced motion,
  simpler effects, narrow screens, and large text.
- Reuse existing local artwork. Keep `redkeep/env.json` and credentials ignored.
- Migrated images must use the existing asset catalog and download/verification
  flow, then load from local downloaded storage. Do not bundle them or add them
  to Flutter's `pubspec.yaml` assets.
- Run focused checks for changed behavior. Keep tests offline; add or update tests
  for meaningful behavior, not cosmetic edits. Avoid unrelated suites and builds.
- The app targets Android only. Do not build for iOS or use the iOS Simulator;
  verify on an Android emulator/device or with offline tests.
