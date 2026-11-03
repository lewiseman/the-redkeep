# Redkeep

The Flutter mobile app is in `redkeep/`. It uses Riverpod, go_router, and Drift.

Copy `redkeep/env.example.json` to ignored `redkeep/env.json` and fill in the
asset base URL and Google OAuth client ID. From `redkeep/`:

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define-from-file=env.json
```

For an edit, format changed Dart files, run `flutter analyze`, and run the relevant
test file or feature directory, for example `flutter test test/features/onboarding`.
Tests use local assets, fakes, and disposable databases; no accounts or downloads.
Run `flutter test` when a full regression check is needed. The sync package has
its own tests under `redkeep/packages/sync_wise/test/`.

After changing Drift tables, bump the schema version, add the migration, and run
from `redkeep/`:

```sh
dart run build_runner build
dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/core/storage/generated/
```

Keep schema snapshots, generated code, and migration/data-preservation tests.
