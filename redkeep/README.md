# Redkeep mobile

The Flutter shell uses Riverpod and go_router for home, appearance settings,
and unavailable-page recovery. Settings use the primary Drift database; system
fonts and programmatic paper surfaces need no downloads.

See the [workspace README](../README.md) for setup/run/check commands and
[architecture/testing guide](../docs/architecture-testing.md) for contracts,
test coverage, and limitations. The selected implementation phase is governed by
[MIGRATION_PLAN.md](../MIGRATION_PLAN.md) and [AGENTS.md](../AGENTS.md).
See [appearance and persistence](../docs/appearance-persistence.md) for storage,
rendering policy, schema generation, and failure recovery.
See [AI feasibility](../docs/ai-feasibility.md) for the explicit synthetic native
harness. The regular app entry point neither loads models nor initializes AI.
