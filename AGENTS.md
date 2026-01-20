# Repository Guidelines

## Project Structure & Module Organization
- `scripts/` contains Swift and shell utilities for local probes and the MVP sync CLI:
  - `scripts/mvp_sync.swift` (dry-run diff between Reminders and Vikunja)
  - `scripts/ekreminder_probe.swift` (EventKit behavior probe)
  - `scripts/list_reminders_lists.swift` (list Reminders lists + identifiers)
- `docs/` holds design references: common schema, translation rules, API notes, and storage design.
- `apple_details.txt` and `vikunja_details.txt` hold local config and secrets (do not commit changes with real tokens).

## Build, Test, and Development Commands

### Swift Package (preferred)
- Build: `swift build`
- Run tests: `swift test`
- Run sync (dry-run): `swift run mvp_sync`
- Run sync (apply): `swift run mvp_sync --apply`

### Legacy script compilation
- Build/run the MVP sync (dry-run only):
  ```bash
  swiftc -o /tmp/mvp_sync scripts/sync_lib.swift scripts/mvp_sync.swift
  /tmp/mvp_sync
  ```
- Apply changes (two-way create/update/delete):
  ```bash
  /tmp/mvp_sync --apply
  ```
- Run unit tests:
  ```bash
  swiftc -o /tmp/sync_tests scripts/sync_lib.swift scripts/sync_tests.swift
  /tmp/sync_tests
  ```
- List Reminders lists to find identifiers:
  ```bash
  swiftc -o /tmp/list_reminders_lists scripts/list_reminders_lists.swift
  /tmp/list_reminders_lists
  ```
- Run the EventKit probe (creates and cleans a temp list + reminders):
  ```bash
  bash scripts/run_reminders_probe.sh
  /tmp/RemindersProbe.app/Contents/MacOS/RemindersProbe
  ```
- Seed deterministic test data:
  ```bash
  swiftc -o /tmp/seed_test_data scripts/seed_test_data.swift
  /tmp/seed_test_data --reset
  ```

## Coding Style & Naming Conventions
- Swift: 4-space indentation, `camelCase` for variables/functions, `UpperCamelCase` for types.
- Keep helper scripts small and single-purpose; prefer pure functions for parsing/mapping.
- Avoid logging secrets (tokens/URLs with credentials).

## Testing Guidelines
- HIGH IMPORTANCE / UNMISSABLE: You MUST run the relevant build locally before asking the user to test or run builds. Do not ask the user to test if you have not verified the build yourself.
- HIGH IMPORTANCE / UNMISSABLE: If a build fails, you must investigate and locate the failure details yourself; do not ask the user to provide error output. You will find the information you need.
- Unit tests in `Tests/VikunjaSyncLibTests/` (XCTest) and `scripts/sync_tests.swift` (standalone).
- Run tests with: `swift test` (preferred) or legacy: `swiftc -o /tmp/sync_tests scripts/sync_lib.swift scripts/sync_tests.swift && /tmp/sync_tests`
- Manual validation uses the probe scripts in `scripts/` for EventKit behavior.
- When adding features, write tests first (TDD approach preferred).
- Do not assume builds succeed after changes; run the relevant build locally before asking the user to do so.

## Commit & Pull Request Guidelines
- No commit message convention established (only a single `first` commit).
- For PRs, include: a short summary, manual test steps (commands + results), and any config changes.

## Security & Configuration Tips
- `vikunja_details.txt` contains a token; treat it as sensitive.
- The Vikunja instance uses a self-signed cert; current scripts accept it explicitly.
- Reminders access requires macOS permission prompts; run probes locally, not in CI.
