# Worklog

## Session Summary
- Created a full MVP two-way sync CLI (`scripts/mvp_sync.swift`) for a single Reminders list and Vikunja project.
- Added a deterministic seed harness (`scripts/seed_test_data.swift` + `scripts/seed_tasks.json`) to create repeatable test data.
- Captured platform behavior in docs and refined mapping/compatibility rules across Reminders and Vikunja.
- Implemented conflict handling, mapping persistence, and safety rules around deletes and completed items.

## Key Changes
- Added data-model docs: `docs/apple-reminders-model.md`, `docs/vikunja-model.md`, `docs/common-schema.md`, and `docs/translation-rules.md`.
- Implemented sync metadata storage design in `docs/sync-metadata-storage.md`.
- Built EventKit probe scripts and list helpers in `scripts/`.
- Added `AGENTS.md` contributor guide and updated `PROJECT_PLAN.md` with MVP scope.

## MVP Sync Features
- Two-way create/update/delete with dry-run and apply mode.
- SQLite mapping (`sync.db`) with last-seen timestamps, date-only flags, and inferred due handling.
- Alarms and basic recurrence support in both directions.
- Conflict detection based on last-seen timestamps.
- Delete policy: only delete unmapped missing items if uncompleted; completed items are preserved.

## Test Harness
- `scripts/seed_test_data.swift` seeds both systems from `scripts/seed_tasks.json`.
- `--reset` cleans existing `seed:` data in both systems before reseeding.
- Dry-run/Apply flow verified end-to-end.

## Current State
- Dry-run shows clean sync after apply for seeded datasets.
- Remaining optional enhancements: seed-only filter, richer recurrence support, conflict detail output options.

## Latest Updates
- Added iOS app scaffolding in `ios/LomindraApp` with login, list selection, and sync UI.
- Implemented Vikunja login fallbacks for token creation and response decoding in the iOS client.
- Filtered Reminders lists to standard, writable lists and added per-list sync toggles with project mapping.
- Added `scripts/login_probe.swift` for API login checks using env vars.
- Updated `PROJECT_PLAN.md` to mark iOS app startup and login progress; added build-validation note in `AGENTS.md`.

## 2026-01-23: Issue Tracking & Bug Fixes
- Created `issues/` directory with 8 tracked issues from sync testing
- Performed comprehensive field audit (`issues/000-field-audit.md`)
- **Fixed Issue 004: Recurrence not syncing**
  - Root cause: Guard required both `repeat_after` AND `repeat_mode` to be non-nil
  - Vikunja often returns `repeat_mode: null` for time-based recurrence
  - Added `parseVikunjaRecurrence()` function to `SyncLib.swift` with nil-defaulting to 0
  - Added 8 unit tests covering all recurrence scenarios
  - Updated `SyncRunner.swift` and `scripts/mvp_sync.swift` to use the new function
- **Fixed Issue 003: Alerts not syncing to Reminders**
  - Root cause: EventKit may discard alarms added before first save
  - Implemented save-fetch-modify-save pattern in `createReminder()`
  - Save reminder first, re-fetch by ID, add alarms, save again
