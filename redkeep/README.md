# Redkeep mobile

The Flutter shell uses Riverpod and go_router for home, Notes, appearance settings,
a persisted welcome flow, and unavailable-page recovery. Notes and settings share the primary Drift database; system
fonts and programmatic paper surfaces need no downloads.
M04's required Appearance artwork is downloaded separately. Fresh installations
are gated until the pack is verified; complete installations work offline. A
host is intentionally unconfigured by default. Use the controlled local fixture
instructions in [assets and startup](../docs/assets-startup.md) for development.

M05 redirects through startup and onboarding while preserving validated
requested destinations. See [onboarding and navigation](../docs/onboarding-routing.md)
for completion, back behavior, parameter validation and retry contracts.
M06 adds plain-text note creation, reading, editing, deletion and persistent
recovery drafts with source revision checks. See [Notes writing and recovery](../docs/notes-writing.md).

See the [workspace README](../README.md) for setup/run/check commands and
[architecture/testing guide](../docs/architecture-testing.md) for contracts,
test coverage, and limitations. The selected implementation phase is governed by
[MIGRATION_PLAN.md](../MIGRATION_PLAN.md) and [AGENTS.md](../AGENTS.md).
See [appearance and persistence](../docs/appearance-persistence.md) for storage,
rendering policy, schema generation, and failure recovery.
See [AI feasibility](../docs/ai-feasibility.md) for the explicit synthetic native
harness. The regular app entry point neither loads models nor initializes AI.
